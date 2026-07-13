//
//  TonicBarPanelController.swift
//  Tonic
//
//  Quick Shelf — a floating surface under the menu bar that shows hidden
//  items as app icons (Bartender Bar equivalent). Clicking an icon opens that
//  item's menu via Accessibility when the current edition permits activation.
//

import AppKit
import SwiftUI

@MainActor
final class TonicBarPanelController {
    static let shared = TonicBarPanelController()

    private var panel: NSPanel?
    private var globalMonitor: Any?

    private init() {}

    var isVisible: Bool { panel?.isVisible ?? false }

    func toggle() { isVisible ? hide() : show() }

    func show() {
        guard !shouldSuppressForFullScreen else { return }
        MenuBarManager.shared.refreshScan()
        let panel = panel ?? makePanel()
        self.panel = panel
        resizeAndPosition(panel, items: hiddenItems(), presentation: resolvedPresentation())
        panel.orderFrontRegardless()
        installDismissMonitor()
    }

    func show(group: MenuBarItemGroup, anchoredTo button: NSStatusBarButton?) {
        guard !shouldSuppressForFullScreen else { return }
        MenuBarManager.shared.refreshScan()
        let keys = Set(group.itemKeys)
        let items = MenuBarManager.shared.items.filter { keys.contains($0.stableKey) }
        let presentation = group.presentationOverride
            ?? resolvedPresentation()
        let panel = panel ?? makePanel()
        self.panel = panel
        resizeAndPosition(panel, items: items, presentation: presentation, anchor: button)
        panel.orderFrontRegardless()
        installDismissMonitor()
    }

    func hide() {
        panel?.orderOut(nil)
        removeDismissMonitor()
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 240, height: 36),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isReleasedWhenClosed = false
        return panel
    }

    private func hiddenItems() -> [MenuBarItemInfo] {
        let geometry = MenuBarDisplayGeometry.active()
        let showsOverflow = resolvedValues().showsOverflow ?? true
        return MenuBarManager.shared.items.filter {
            !$0.isSystemControlled && ($0.section == .hidden || $0.section == .alwaysHidden
                                       || (showsOverflow && geometry?.isOverflow($0) == true))
        }
    }

    private func resolvedValues() -> MenuBarPresentationValues {
        let point = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) } ?? NSScreen.main
        let identity = screen.map(DisplayIdentity.init)
        let store = MenuBarProfileStore.shared
        return MenuBarProfileResolver().resolve(profiles: store.profiles, display: identity,
                                                manualContextID: store.selectedManualContextID)
    }

    private var shouldSuppressForFullScreen: Bool {
        MenuBarManagerSettingsStore.shared.settings.suppressInFullScreen
            && NSApp.presentationOptions.contains(.fullScreen)
    }

    private func resolvedPresentation() -> QuickShelfPresentation {
        resolvedValues().quickShelfPresentation ?? MenuBarManagerSettingsStore.shared.settings.quickShelfPresentation
    }

    private func resizeAndPosition(_ panel: NSPanel, items: [MenuBarItemInfo],
                                   presentation: QuickShelfPresentation,
                                   anchor: NSStatusBarButton? = nil) {
        let iconWidth: CGFloat = 30
        let padding: CGFloat = 12
        let width: CGFloat
        let height: CGFloat
        switch presentation {
        case .compactStrip:
            width = max(120, CGFloat(items.count) * iconWidth + padding * 2)
            height = 42
        case .labeledGrid:
            width = 360
            height = min(320, max(92, CGFloat((items.count + 2) / 3) * 52 + 20))
        case .searchableList:
            width = 320
            height = min(380, max(150, CGFloat(items.count) * 36 + 58))
        }

        let root = TonicBarView(items: items, presentation: presentation,
                                canActivate: MenuBarCapabilities.current.canActivateForeignItems) { [weak self] item in
            self?.hide()
            guard MenuBarCapabilities.current.canActivateForeignItems else { return }
            Task { await MenuBarManager.shared.activate(item) }
        }
        panel.contentView = NSHostingView(rootView: root)

        let mouseLocation = NSEvent.mouseLocation
        let activeScreen = NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) } ?? NSScreen.main
        let values = resolvedValues()
        let screen: NSScreen?
        if case .specific(let identity) = values.quickShelfTarget {
            screen = NSScreen.screens.first { identity.matches(DisplayIdentity(screen: $0)) } ?? activeScreen
        } else {
            screen = activeScreen
        }
        guard let frame = screen?.frame, let visible = screen?.visibleFrame else { return }
        // Just under the menu bar, right-aligned.
        let anchorFrame = anchor.flatMap { button in
            button.window?.convertToScreen(button.frame)
        }
        let origin = NSPoint(x: anchorFrame.map { min(max($0.midX - width / 2, frame.minX + 8), frame.maxX - width - 8) }
                             ?? (frame.maxX - width - 8),
                             y: visible.maxY - height - 2)
        panel.setFrame(NSRect(origin: origin, size: CGSize(width: width, height: height)), display: true)
    }

    private func installDismissMonitor() {
        removeDismissMonitor()
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                // Clicking our own icons happens via the local hosting view; a
                // global click outside dismisses.
                self?.hide()
            }
        }
    }

    private func removeDismissMonitor() {
        if let monitor = globalMonitor { NSEvent.removeMonitor(monitor); globalMonitor = nil }
    }
}
