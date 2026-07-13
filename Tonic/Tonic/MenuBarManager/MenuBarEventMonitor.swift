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
    private var scrollMonitor: Any?
    private var hoverTimer: Timer?
    private var hoverDelay: Double = 0.2
    private var lastMoveHandled = Date.distantPast
    private var lastGestureHandled = Date.distantPast
    private var suppressInFullScreen = true

    init(manager: MenuBarManager) {
        self.manager = manager
    }

    func apply(_ settings: MenuBarManagerSettings) {
        hoverDelay = settings.hoverDelaySeconds
        suppressInFullScreen = settings.suppressInFullScreen
        settings.showOnHover ? startHoverMonitor() : stopHoverMonitor()
        settings.showOnClickEmptyMenuBar ? startClickMonitor() : stopClickMonitor()
        settings.showOnScroll ? startScrollMonitor() : stopScrollMonitor()
    }

    func stop() {
        stopHoverMonitor()
        stopClickMonitor()
        stopScrollMonitor()
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

        guard let manager, manager.isActive, !manager.isExpanded, !shouldSuppressReveal else { return }

        if Self.isInMenuBarBand(NSEvent.mouseLocation) {
            guard hoverTimer == nil else { return }
            hoverTimer = Timer.scheduledTimer(withTimeInterval: max(0.05, hoverDelay), repeats: false) { _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.hoverTimer = nil
                    guard let manager = self.manager, manager.isActive, !manager.isExpanded,
                          !self.shouldSuppressReveal,
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
        guard let manager, manager.isActive, !shouldSuppressReveal else { return }
        let location = NSEvent.mouseLocation
        guard Self.isInMenuBarBand(location) else { return }

        // Fresh frames — the scanner may be idle while the UI is closed.
        manager.refreshScan()
        if let activated = Self.item(at: location, items: manager.items) {
            MenuBarUpdateWatchStore.shared.acknowledge(activated.stableKey)
            return
        }
        guard Self.isEmptyMenuBarPoint(location, items: manager.items) else { return }
        manager.toggle()
        manager.scheduleRehide()
    }

    // MARK: - Scroll / two-finger swipe

    private func startScrollMonitor() {
        guard scrollMonitor == nil else { return }
        scrollMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.scrollWheel]) { [weak self] event in
            Task { @MainActor in self?.handleScroll(event) }
        }
    }

    private func stopScrollMonitor() {
        if let monitor = scrollMonitor {
            NSEvent.removeMonitor(monitor)
            scrollMonitor = nil
        }
    }

    private func handleScroll(_ event: NSEvent) {
        guard let manager, manager.isActive, !shouldSuppressReveal,
              Self.isInMenuBarBand(NSEvent.mouseLocation),
              abs(event.scrollingDeltaX) + abs(event.scrollingDeltaY) >= 1 else { return }
        let now = Date()
        guard now.timeIntervalSince(lastGestureHandled) >= 0.45 else { return }
        lastGestureHandled = now
        manager.isExpanded ? manager.scheduleRehide() : manager.expand()
    }

    private var shouldSuppressReveal: Bool {
        suppressInFullScreen && NSApp.presentationOptions.contains(.fullScreen)
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
        guard let (_, displayBounds, cgPoint) = quartzPoint(for: point) else { return false }

        let onScreenItems = items.filter { $0.isOnScreen && $0.frame.intersects(displayBounds) }

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
        let statusRegionStart = onScreenItems.map(\.frame.minX).min() ?? displayBounds.midX
        guard cgPoint.x >= statusRegionStart - 24 else { return false }

        return true
    }

    static func item(at point: NSPoint, items: [MenuBarItemInfo]) -> MenuBarItemInfo? {
        guard let (_, displayBounds, cgPoint) = quartzPoint(for: point) else { return nil }
        return items.first { $0.frame.intersects(displayBounds) && $0.frame.insetBy(dx: -2, dy: 0).contains(cgPoint) }
    }

    private static func quartzPoint(for point: NSPoint) -> (NSScreen, CGRect, CGPoint)? {
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(point, $0.frame, false) }),
              let number = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
        else { return nil }
        let bounds = CGDisplayBounds(number)
        let localX = point.x - screen.frame.minX
        let localYFromTop = screen.frame.maxY - point.y
        return (screen, bounds, CGPoint(x: bounds.minX + localX, y: bounds.minY + localYFromTop))
    }
}

/// Public-API-only display geometry. It identifies status items that are
/// outside both usable top regions (including the notch) without mutating the
/// user's globally mirrored physical placement.
public struct MenuBarDisplayGeometry: Sendable {
    public let displayFrame: CGRect
    public let usableTopRegions: [CGRect]

    public init(displayFrame: CGRect, usableTopRegions: [CGRect]) {
        self.displayFrame = displayFrame
        self.usableTopRegions = usableTopRegions
    }

    @MainActor
    public init(screen: NSScreen) {
        let number = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
        let quartzFrame = CGDisplayBounds(number)
        displayFrame = quartzFrame
        let auxiliary = [screen.auxiliaryTopLeftArea, screen.auxiliaryTopRightArea]
            .compactMap { $0 }.filter { !$0.isEmpty }
        if !auxiliary.isEmpty {
            usableTopRegions = auxiliary.map { area in
                CGRect(x: quartzFrame.minX + area.minX - screen.frame.minX, y: quartzFrame.minY,
                       width: area.width, height: max(area.height, NSStatusBar.system.thickness))
            }
        } else {
            let insets = screen.safeAreaInsets
            usableTopRegions = [CGRect(x: quartzFrame.minX + insets.left, y: quartzFrame.minY,
                                       width: screen.frame.width - insets.left - insets.right,
                                       height: NSStatusBar.system.thickness)]
        }
    }

    public func isOverflow(_ item: MenuBarItemInfo) -> Bool {
        guard item.isOnScreen, item.frame.midX >= displayFrame.minX, item.frame.midX <= displayFrame.maxX else {
            return true
        }
        return !usableTopRegions.contains { region in
            item.frame.midX >= region.minX && item.frame.midX <= region.maxX
        }
    }

    @MainActor
    public static func active() -> MenuBarDisplayGeometry? {
        let point = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) } ?? NSScreen.main
        return screen.map(MenuBarDisplayGeometry.init)
    }
}
