//
//  MenuBarManager.swift
//  Tonic
//
//  Coordinates Bartender/Ice-style menu bar management: owns the control
//  status items, expand/collapse state, auto-rehide, event monitors, and the
//  item scanner. Users ⌘-drag third-party icons to the left of the ┃
//  separator to mark them hidden.
//

import AppKit
import os

@MainActor
@Observable
public final class MenuBarManager {

    public static let shared = MenuBarManager()

    private let logger = Logger(subsystem: "com.tonic.app", category: "MenuBarManager")

    // MARK: - State

    /// Whether management is running (separator + toggle exist).
    public private(set) var isActive = false
    /// Whether the hidden section is currently revealed.
    public private(set) var isExpanded = false
    /// Whether the always-hidden section is also revealed (⌥-click peek).
    public private(set) var isShowingAlwaysHidden = false

    /// Discovered third-party items, classified into sections.
    public var items: [MenuBarItemInfo] { scanner.items }
    public var lastScanDate: Date? { scanner.lastScanDate }

    private let scanner = MenuBarItemScanner()
    private var toggleItem: MenuBarControlItem?
    private var separatorItem: MenuBarControlItem?
    private var alwaysHiddenItem: MenuBarControlItem?
    private var eventMonitor: MenuBarEventMonitor?
    private var rehideTimer: Timer?
    private var temporaryRevealTimer: Timer?
    private var settingsObserver: NSObjectProtocol?
    private var focusObserver: NSObjectProtocol?
    private var liveReapplyTask: Task<Void, Never>?

    #if !TONIC_STORE
    private let mover = MenuBarItemMover()
    private let activator = MenuBarItemActivator()
    #endif
    private let triggerEngine = MenuBarTriggerEngine()

    /// Last user-facing move/activate failure — the dashboard shows it as a toast.
    public var lastActionError: String?
    /// True while a synthetic ⌘-drag (or preset apply) is in flight.
    public private(set) var isPerformingMove = false

    private var settings: MenuBarManagerSettings { MenuBarManagerSettingsStore.shared.settings }

    private init() {
        scanner.classify = { [weak self] in self?.classified($0) ?? $0 }
        scanner.onItemsChanged = { [weak self] items in self?.itemsDidChange(items) }
        settingsObserver = NotificationCenter.default.addObserver(
            forName: .menuBarManagerSettingsDidChange, object: nil, queue: .main
        ) { _ in
            Task { @MainActor in MenuBarManager.shared.applySettings() }
        }
    }

    // MARK: - Lifecycle

    /// Called at app launch; a no-op until the user enables management.
    public func start() {
        _ = MenuBarOwnedItemCoordinator.shared.apply(MenuBarWorkspaceStore.shared.envelope.committed)
        MenuBarProfileCoordinator.shared.start()
        TonicRemoteProviderStore.shared.registerPersisted()
        #if !TONIC_STORE
        TonicExecutableProviderStore.shared.registerPersisted()
        ScriptExecutionCoordinator.shared.startSchedules()
        #endif
        Task { await TonicBuiltInProviderBootstrap.registerAll() }
        Task { await TonicMarketplaceRuntime.shared.start() }
        applySettings()
        MenuBarUpdateWatcherCoordinator.shared.refresh()
    }

    /// The management UI drives the scanner's 3-second poll.
    public func setInspectorVisible(_ visible: Bool) {
        scanner.setActive(visible)
    }

    public func refreshScan() {
        scanner.scanNow()
    }

    private func applySettings() {
        if settings.isEnabled, !isActive {
            activate()
        } else if !settings.isEnabled, isActive {
            deactivate()
        }
        guard isActive else { return }

        // Always-hidden section toggled independently.
        if settings.alwaysHiddenSectionEnabled, alwaysHiddenItem == nil {
            alwaysHiddenItem = MenuBarControlItem(kind: .alwaysHiddenSeparator)
        } else if !settings.alwaysHiddenSectionEnabled, let item = alwaysHiddenItem {
            item.remove()
            alwaysHiddenItem = nil
        }

        eventMonitor?.apply(settings)

        #if !TONIC_STORE
        MenuBarStyleOverlayController.shared.apply(settings.styling)
        #endif

        rescanSoon()
    }

    private func activate() {
        logger.info("Activating menu bar management")
        MenuBarControlItem.seedInitialPositionsIfNeeded()

        // Creation order right→left matches the seeded preferred positions.
        toggleItem = MenuBarControlItem(kind: .toggle)
        separatorItem = MenuBarControlItem(kind: .separator)
        if settings.alwaysHiddenSectionEnabled {
            alwaysHiddenItem = MenuBarControlItem(kind: .alwaysHiddenSeparator)
        }

        toggleItem?.onToggle = { [weak self] in self?.toggle() }
        toggleItem?.onToggleAlwaysHidden = { [weak self] in self?.toggleAlwaysHiddenPeek() }
        toggleItem?.onOpenSettings = { [weak self] in self?.openManagementUI() }
        toggleItem?.onDisable = {
            MenuBarManagerSettingsStore.shared.settings.isEnabled = false
        }

        isActive = true
        scanner.setManagementEnabled(true)
        eventMonitor = MenuBarEventMonitor(manager: self)
        eventMonitor?.apply(settings)
        observeFocusChanges()
        collapse()

        triggerEngine.start()
    }

    private func deactivate() {
        logger.info("Deactivating menu bar management")
        triggerEngine.stop()
        #if !TONIC_STORE
        MenuBarStyleOverlayController.shared.apply(MenuBarStyling(isEnabled: false))
        TonicBarPanelController.shared.hide()
        #endif
        rehideTimer?.invalidate()
        rehideTimer = nil
        temporaryRevealTimer?.invalidate()
        temporaryRevealTimer = nil
        eventMonitor?.stop()
        eventMonitor = nil
        if let observer = focusObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            focusObserver = nil
        }
        // Removing keeps the autosaved positions, so re-enabling restores layout.
        [toggleItem, separatorItem, alwaysHiddenItem].forEach { $0?.remove() }
        toggleItem = nil
        separatorItem = nil
        alwaysHiddenItem = nil
        isActive = false
        scanner.setManagementEnabled(false)
        liveReapplyTask?.cancel()
        liveReapplyTask = nil
        isExpanded = false
        isShowingAlwaysHidden = false
        rescanSoon()
    }

    // MARK: - Expand / Collapse

    public func toggle() {
        isExpanded ? collapse() : expand()
    }

    public func expand(showAlwaysHidden: Bool = false) {
        guard isActive else { return }

        // Tonic Bar reveal mode: show the floating icon strip instead of
        // sliding hidden items back onto the menu bar. Always-hidden peek
        // (⌥-click) still uses the real bar so the actual items are reachable.
        if settings.revealMode == .tonicBar, !showAlwaysHidden {
            TonicBarPanelController.shared.show()
            scheduleRehide()
            return
        }

        separatorItem?.setExpanded(true)
        alwaysHiddenItem?.setExpanded(showAlwaysHidden)
        isExpanded = true
        isShowingAlwaysHidden = showAlwaysHidden
        toggleItem?.updateToggleIcon(isExpanded: true)
        refreshUpdateBadge()
        scheduleRehide()
        rescanSoon()
    }

    public func collapse() {
        guard isActive else { return }
        TonicBarPanelController.shared.hide()
        separatorItem?.setExpanded(false)
        alwaysHiddenItem?.setExpanded(false)
        isExpanded = false
        isShowingAlwaysHidden = false
        toggleItem?.updateToggleIcon(isExpanded: false)
        refreshUpdateBadge()
        rehideTimer?.invalidate()
        rehideTimer = nil
        rescanSoon()
    }

    /// Reveals an item long enough to inspect an update, then restores the
    /// prior collapsed state. Used by update watching and automation triggers.
    public func temporarilyReveal(_ stableKey: String, duration: TimeInterval = 8) {
        guard items.contains(where: { $0.stableKey == stableKey }) else { return }
        temporaryRevealTimer?.invalidate()
        expand(showAlwaysHidden: true)
        temporaryRevealTimer = Timer.scheduledTimer(
            withTimeInterval: min(max(duration, 2), 30), repeats: false
        ) { _ in
            Task { @MainActor in MenuBarManager.shared.collapse() }
        }
    }

    private func toggleAlwaysHiddenPeek() {
        if isShowingAlwaysHidden {
            collapse()
        } else {
            expand(showAlwaysHidden: true)
        }
    }

    /// Restart the auto-rehide countdown (also called by the event monitor on
    /// user activity in the bar).
    func scheduleRehide() {
        rehideTimer?.invalidate()
        rehideTimer = nil
        guard settings.autoRehide else { return }
        rehideTimer = Timer.scheduledTimer(withTimeInterval: settings.rehideDelaySeconds, repeats: false) { _ in
            Task { @MainActor in
                MenuBarManager.shared.collapse()
            }
        }
    }

    private func observeFocusChanges() {
        guard focusObserver == nil else { return }
        focusObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { notification in
            let activated = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            Task { @MainActor in
                let manager = MenuBarManager.shared
                guard manager.settings.rehideOnFocusChange, manager.isExpanded,
                      activated?.processIdentifier != ProcessInfo.processInfo.processIdentifier
                else { return }
                manager.collapse()
            }
        }
    }

    // MARK: - Item Control (direct build)

    /// Whether this build can move/activate third-party items (synthetic
    /// events + AX control are not sandbox-compatible).
    public var canControlItems: Bool {
        #if TONIC_STORE
        return false
        #else
        return true
        #endif
    }

    /// Whether synthetic drags/AX presses will actually work right now.
    public var accessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    /// One-click section change — the ⌘-drag, performed by Tonic.
    public func move(_ item: MenuBarItemInfo, to section: MenuBarSection) async {
        #if !TONIC_STORE
        isPerformingMove = true
        defer { isPerformingMove = false }
        do {
            try await mover.move(item: item, to: section)
            lastActionError = nil
        } catch {
            lastActionError = error.localizedDescription
        }
        #endif
    }

    /// Open the item's own menu (Quick Search, Tonic Bar, dashboard clicks).
    public func activate(_ item: MenuBarItemInfo) async {
        #if !TONIC_STORE
        do {
            try await activator.activate(item)
            MenuBarUpdateWatchStore.shared.acknowledge(item.stableKey)
            lastActionError = nil
        } catch {
            lastActionError = error.localizedDescription
        }
        #endif
    }

    /// Apply a stableKey → section layout (preset apply). Returns overall success.
    @discardableResult
    public func applyLayout(_ layout: [String: MenuBarSection]) async -> Bool {
        let results = await applyLayoutDetailed(layout)
        return results.values.allSatisfy { $0 }
    }

    /// Per-item result used by the staged editor so successful foreign moves
    /// commit even when a later item fails and remains dirty for retry.
    public func applyLayoutDetailed(_ layout: [String: MenuBarSection]) async -> [String: Bool] {
        #if !TONIC_STORE
        isPerformingMove = true
        defer { isPerformingMove = false }
        let results = await mover.applyLayout(layout)
        let failed = results.filter { !$0.value }.count
        if failed > 0 {
            lastActionError = "\(failed) item\(failed == 1 ? "" : "s") couldn't be moved. Try ⌘-dragging them manually."
        } else {
            lastActionError = nil
        }
        return results
        #else
        return Dictionary(uniqueKeysWithValues: layout.keys.map { ($0, false) })
        #endif
    }

    /// Separator button-window frames (x axis matches CG global coordinates)
    /// — drag targets for the mover.
    func separatorWindowFrames() -> (separator: CGRect?, alwaysHidden: CGRect?) {
        (separatorItem?.statusItem.button?.window?.frame,
         alwaysHiddenItem?.statusItem.button?.window?.frame)
    }

    // MARK: - Classification

    private func classified(_ items: [MenuBarItemInfo]) -> [MenuBarItemInfo] {
        guard isActive else {
            return items.map { item in
                var updated = item
                updated.section = .visible
                return updated
            }
        }
        return MenuBarItemClassifier.classify(
            items: items,
            separatorMinX: separatorItem?.windowMinX,
            alwaysHiddenMinX: alwaysHiddenItem?.windowMinX
        )
    }

    func refreshUpdateBadge() {
        toggleItem?.updateBadge(unseenCount: MenuBarUpdateWatchStore.shared.unseenCount)
    }

    private func itemsDidChange(_ items: [MenuBarItemInfo]) {
        guard isActive, MenuBarWorkspaceStore.shared.layoutMode == .live,
              MenuBarCapabilities.current.canMoveForeignItems else { return }
        liveReapplyTask?.cancel()
        liveReapplyTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled, let self else { return }
            let knownKeys = Set(items.map(\.stableKey))
            let layout = MenuBarWorkspaceStore.shared.envelope.committed.foreignAssignments
                .filter { knownKeys.contains($0.key) }
            guard !layout.isEmpty else { return }
            _ = await self.applyLayout(layout)
        }
    }

    /// Status item lengths animate over a run-loop tick; scan after they settle.
    private func rescanSoon() {
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            self?.scanner.scanNow()
        }
    }

    private func openManagementUI() {
        MainWindowNavigator.openLiveMonitor()
        NotificationCenter.default.post(name: .openMenuBarManagement, object: nil)
    }
}

extension Notification.Name {
    /// Asks MonitorView to select the Menu Bar tab.
    public static let openMenuBarManagement = Notification.Name("tonic.menuBarManager.openManagement")
}
