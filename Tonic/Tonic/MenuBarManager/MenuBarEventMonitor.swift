//
//  MenuBarEventMonitor.swift
//  Tonic
//
//  Global NSEvent monitors for hover-to-show and click-empty-bar-to-toggle.
//  Mouse-event global monitors do not require Accessibility trust (unlike key
//  monitors); if a managed Mac blocks them, the management UI's permission row
//  points users at the Accessibility pane.
//

import AppKit

@MainActor
final class MenuBarEventMonitor {

    private weak var manager: MenuBarManager?
    private var mouseMoveMonitor: Any?
    private var clickMonitor: Any?
    private var hoverTimer: Timer?
    private var hoverDelay: Double = 0.2
    private var lastMoveHandled = Date.distantPast

    init(manager: MenuBarManager) {
        self.manager = manager
    }

    func apply(_ settings: MenuBarManagerSettings) {
        hoverDelay = settings.hoverDelaySeconds
        settings.showOnHover ? startHoverMonitor() : stopHoverMonitor()
        settings.showOnClickEmptyMenuBar ? startClickMonitor() : stopClickMonitor()
    }

    func stop() {
        stopHoverMonitor()
        stopClickMonitor()
    }

    // MARK: - Hover to show

    private func startHoverMonitor() {
        guard mouseMoveMonitor == nil else { return }
        mouseMoveMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            Task { @MainActor in self?.handleMouseMoved() }
        }
    }

    private func stopHoverMonitor() {
        if let monitor = mouseMoveMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMoveMonitor = nil
        }
        hoverTimer?.invalidate()
        hoverTimer = nil
    }

    private func handleMouseMoved() {
        // ~10 Hz is plenty for a dwell check.
        let now = Date()
        guard now.timeIntervalSince(lastMoveHandled) > 0.1 else { return }
        lastMoveHandled = now

        guard let manager, manager.isActive, !manager.isExpanded else { return }

        if Self.isInMenuBarBand(NSEvent.mouseLocation) {
            guard hoverTimer == nil else { return }
            hoverTimer = Timer.scheduledTimer(withTimeInterval: max(0.05, hoverDelay), repeats: false) { _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.hoverTimer = nil
                    guard let manager = self.manager, manager.isActive, !manager.isExpanded,
                          Self.isInMenuBarBand(NSEvent.mouseLocation) else { return }
                    manager.expand()
                }
            }
        } else {
            hoverTimer?.invalidate()
            hoverTimer = nil
        }
    }

    // MARK: - Click empty menu bar

    private func startClickMonitor() {
        guard clickMonitor == nil else { return }
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.handleGlobalClick() }
        }
    }

    private func stopClickMonitor() {
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
    }

    private func handleGlobalClick() {
        guard let manager, manager.isActive else { return }
        let location = NSEvent.mouseLocation
        guard Self.isInMenuBarBand(location) else { return }

        // Fresh frames — the scanner may be idle while the UI is closed.
        manager.refreshScan()
        guard Self.isEmptyMenuBarPoint(location, items: manager.items) else { return }
        manager.toggle()
        manager.scheduleRehide()
    }

    // MARK: - Geometry

    static func isInMenuBarBand(_ point: NSPoint) -> Bool {
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(point, $0.frame, false) }) else {
            return false
        }
        let bandHeight = max(NSStatusBar.system.thickness,
                             screen.frame.maxY - screen.visibleFrame.maxY)
        return point.y >= screen.frame.maxY - bandHeight
    }

    /// True when the click hits neither a status-item window nor the app-menu
    /// region on the left (menu titles aren't windows, so approximate their
    /// extent as "left of the leftmost status item").
    static func isEmptyMenuBarPoint(_ point: NSPoint, items: [MenuBarItemInfo]) -> Bool {
        guard let primary = NSScreen.screens.first else { return false }
        // AppKit (bottom-left origin) → CG global (top-left origin).
        let cgPoint = CGPoint(x: point.x, y: primary.frame.maxY - point.y)

        let onScreenItems = items.filter { $0.frame.minX > 0 }

        // Inside any third-party item?
        if onScreenItems.contains(where: { $0.frame.insetBy(dx: -2, dy: 0).contains(cgPoint) }) {
            return false
        }

        // Inside one of Tonic's own status windows (widgets, separator, toggle)?
        for window in NSApp.windows where window.className.contains("NSStatusBarWindow") {
            if NSMouseInRect(point, window.frame, false) {
                return false
            }
        }

        // Left of the status-item region = app menus; don't hijack those clicks.
        let statusRegionStart = onScreenItems.map(\.frame.minX).min() ?? primary.frame.midX
        guard cgPoint.x >= statusRegionStart - 24 else { return false }

        return true
    }
}
