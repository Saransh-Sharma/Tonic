//
//  MenuBarOwnedItemCoordinator.swift
//  Tonic
//
//  Materializes only committed Tonic-owned nodes as stable NSStatusItems.
//

import AppKit
import Foundation

@MainActor
public final class MenuBarOwnedItemCoordinator {
    public static let shared = MenuBarOwnedItemCoordinator()

    @MainActor
    private final class ActionProxy: NSObject {
        let action: @MainActor () -> Void
        init(action: @escaping @MainActor () -> Void) { self.action = action }
        @objc func invoke() { action() }
    }

    private var statusItems: [UUID: NSStatusItem] = [:]
    private var proxies: [UUID: [ActionProxy]] = [:]
    private var refreshTimer: Timer?
    private let formatter = CustomItemFormatter()
    private let provider: any CustomItemDataProvider
    private let executor: CustomItemSafeActionExecutor

    init(provider: any CustomItemDataProvider = WidgetCustomItemDataProvider.shared,
         executor: CustomItemSafeActionExecutor = .shared) {
        self.provider = provider
        self.executor = executor
    }

    public var materializedIDs: Set<UUID> { Set(statusItems.keys) }

    @discardableResult
    public func apply(_ draft: MenuBarLayoutDraft) -> [MenuBarApplyFailure] {
        let desired = Set(draft.spacers.map(\.id) + draft.groups.filter(\.isPinned).map(\.id)
                          + draft.customItems.map(\.id))
        for id in statusItems.keys where !desired.contains(id) { remove(id) }

        for spacer in draft.spacers where !spacer.isHidden { configure(spacer) }
        for spacer in draft.spacers where spacer.isHidden { remove(spacer.id) }
        for group in draft.groups where group.isPinned { configure(group) }

        var failures: [MenuBarApplyFailure] = []
        let snapshot = provider.snapshot()
        for custom in draft.customItems {
            do {
                try formatter.validate(custom, snapshot: snapshot)
                configure(custom, snapshot: snapshot)
            } catch {
                remove(custom.id)
                failures.append(MenuBarApplyFailure(nodeID: MenuBarLayoutNode.customItem(custom.id).stableID,
                                                    reason: error.localizedDescription))
            }
        }
        updateRefreshTimer(hasDynamicItems: draft.customItems.contains { item in
            if case .staticLabel = item.dataSource { return false }
            return true
        }, draft: draft)
        return failures
    }

    public func removeAll() {
        for id in Array(statusItems.keys) { remove(id) }
        refreshTimer?.invalidate(); refreshTimer = nil
    }

    private func statusItem(id: UUID, length: CGFloat = NSStatusItem.variableLength) -> NSStatusItem {
        if let existing = statusItems[id] { existing.length = length; return existing }
        let item = NSStatusBar.system.statusItem(withLength: length)
        item.autosaveName = "TonicOwned.\(id.uuidString)"
        statusItems[id] = item
        return item
    }

    private func configure(_ spacer: MenuBarSpacer) {
        let item = statusItem(id: spacer.id, length: CGFloat(min(max(spacer.width, 4), 96)))
        item.button?.title = ""
        item.button?.image = nil
        item.button?.toolTip = spacer.label
        item.button?.setAccessibilityElement(true)
        item.button?.setAccessibilityLabel(spacer.label)
    }

    private func configure(_ group: MenuBarItemGroup) {
        let item = statusItem(id: group.id)
        guard let button = item.button else { return }
        button.title = ""
        button.image = NSImage(systemSymbolName: group.symbolName, accessibilityDescription: group.name)
            ?? NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: group.name)
        button.contentTintColor = MenuBarAccentPolicy.color(
            hex: group.accentHex,
            increasedContrast: NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        )
        button.toolTip = group.name
        item.menu = nil
        let proxy = ActionProxy { [weak button] in
            TonicBarPanelController.shared.show(group: group, anchoredTo: button)
        }
        proxies[group.id] = [proxy]
        button.target = proxy
        button.action = #selector(ActionProxy.invoke)
    }

    private func configure(_ custom: CustomMenuBarItem, snapshot: CustomItemRuntimeSnapshot) {
        let item = statusItem(id: custom.id)
        guard let button = item.button else { return }
        button.title = formatter.format(custom.dataSource, snapshot: snapshot)
        #if !TONIC_STORE
        if let scriptID = custom.actions.compactMap({ action -> UUID? in
            if case .runScript(let id) = action { return id }
            return nil
        }).first, let mapped = CustomItemScriptStore.shared.mappedLabels[scriptID] {
            button.title = mapped
        }
        #endif
        button.imagePosition = button.title.isEmpty ? .imageOnly : .imageLeading
        button.image = resolvedImage(custom) ?? NSImage(systemSymbolName: custom.symbolName, accessibilityDescription: custom.name)
        button.toolTip = custom.name
        button.setAccessibilityLabel(custom.name)
        item.menu = nil
        proxies[custom.id] = []
        if custom.actions.count > 1 {
            let menu = NSMenu(title: custom.name)
            for action in custom.actions {
                let proxy = actionProxy(action)
                proxies[custom.id, default: []].append(proxy)
                let menuItem = NSMenuItem(title: actionTitle(action),
                                          action: #selector(ActionProxy.invoke), keyEquivalent: "")
                menuItem.target = proxy
                menu.addItem(menuItem)
            }
            item.menu = menu
            button.target = nil
            button.action = nil
        } else if let action = custom.actions.first {
            let proxy = actionProxy(action)
            proxies[custom.id] = [proxy]
            button.target = proxy
            button.action = #selector(ActionProxy.invoke)
        } else {
            button.target = nil
            button.action = nil
        }
        if case .provider(let providerID) = custom.dataSource {
            Task { [weak button] in
                let request = TonicDataSourceRequest(providerID: providerID)
                guard let providerSnapshot = try? await TonicProviderRegistry.shared.snapshot(providerID: providerID, request: request) else { return }
                await MainActor.run {
                    button?.title = providerSnapshot.label ?? custom.name
                    if let symbol = providerSnapshot.symbolName {
                        button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: providerSnapshot.accessibilityText)
                    }
                    button?.setAccessibilityLabel(providerSnapshot.accessibilityText ?? providerSnapshot.label ?? custom.name)
                }
            }
        }
    }

    #if !TONIC_STORE
    public func refreshScriptLabel(scriptID: UUID, label: String) {
        for custom in MenuBarWorkspaceStore.shared.envelope.committed.customItems where custom.actions.contains(where: {
            if case .runScript(let id) = $0 { return id == scriptID }
            return false
        }) {
            statusItems[custom.id]?.button?.title = String(label.prefix(48))
        }
    }
    #endif

    private func actionProxy(_ action: CustomMenuBarSafeAction) -> ActionProxy {
        ActionProxy { [executor] in
            do { try executor.execute(action) }
            catch { NSSound.beep() }
        }
    }

    private func actionTitle(_ action: CustomMenuBarSafeAction) -> String {
        switch action {
        case .openApplication: "Open Application"
        case .openFile: "Open File"
        case .openURL: "Open URL"
        case .openTonicDestination: "Open Tonic"
        case .runShortcut: "Run Shortcut"
        #if !TONIC_STORE
        case .runScript: "Run Script"
        #endif
        }
    }

    private func resolvedImage(_ custom: CustomMenuBarItem) -> NSImage? {
        guard let bookmark = custom.imageBookmark else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope],
                                 relativeTo: nil, bookmarkDataIsStale: &stale), !stale else { return nil }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url), let image = NSImage(data: data) else { return nil }
        image.isTemplate = false
        image.accessibilityDescription = custom.name
        return image
    }

    private func updateRefreshTimer(hasDynamicItems: Bool, draft: MenuBarLayoutDraft) {
        refreshTimer?.invalidate(); refreshTimer = nil
        guard hasDynamicItems else { return }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            Task { @MainActor [weak self] in _ = self?.apply(draft) }
        }
    }

    private func remove(_ id: UUID) {
        guard let item = statusItems.removeValue(forKey: id) else { return }
        NSStatusBar.system.removeStatusItem(item)
        proxies.removeValue(forKey: id)
    }

}

public enum MenuBarAccentPolicy {
    /// Unsafe accents return nil so AppKit uses adaptive template monochrome.
    public static func isSafe(hex: String?, increasedContrast: Bool = false) -> Bool {
        guard let hex else { return false }
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard cleaned.count == 6, let value = UInt64(cleaned, radix: 16) else { return false }
        let red = CGFloat((value >> 16) & 0xff) / 255
        let green = CGFloat((value >> 8) & 0xff) / 255
        let blue = CGFloat(value & 0xff) / 255
        func linear(_ channel: CGFloat) -> CGFloat {
            channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        let luminance = 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
        let threshold: CGFloat = increasedContrast ? 4.5 : 3
        let contrastOnBlack = (luminance + 0.05) / 0.05
        let contrastOnWhite = 1.05 / (luminance + 0.05)
        return contrastOnBlack >= threshold && contrastOnWhite >= threshold
    }

    public static func color(hex: String?, increasedContrast: Bool = false) -> NSColor? {
        guard isSafe(hex: hex, increasedContrast: increasedContrast), let hex else { return nil }
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard let value = UInt64(cleaned, radix: 16) else { return nil }
        let red = CGFloat((value >> 16) & 0xff) / 255
        let green = CGFloat((value >> 8) & 0xff) / 255
        let blue = CGFloat(value & 0xff) / 255
        return NSColor(srgbRed: red, green: green, blue: blue, alpha: 1)
    }
}
