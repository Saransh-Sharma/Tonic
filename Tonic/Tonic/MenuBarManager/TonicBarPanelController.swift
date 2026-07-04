//
//  TonicBarPanelController.swift
//  Tonic
//
//  The "Tonic Bar" — a floating strip under the menu bar that shows hidden
//  items as app icons (Bartender Bar equivalent). Clicking an icon opens that
//  item's menu via Accessibility. Direct build only (activation is gated).
//

#if !TONIC_STORE

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
        MenuBarManager.shared.refreshScan()
        let panel = panel ?? makePanel()
        self.panel = panel
        resizeAndPosition(panel)
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
        MenuBarManager.shared.items.filter {
            !$0.isSystemControlled && ($0.section == .hidden || $0.section == .alwaysHidden)
        }
    }

    private func resizeAndPosition(_ panel: NSPanel) {
        let items = hiddenItems()
        let iconWidth: CGFloat = 30
        let padding: CGFloat = 12
        let width = max(120, CGFloat(items.count) * iconWidth + padding * 2)
        let height: CGFloat = 34

        let root = TonicBarView(items: items) { [weak self] item in
            self?.hide()
            Task { await MenuBarManager.shared.activate(item) }
        }
        panel.contentView = NSHostingView(rootView: root)

        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) } ?? NSScreen.main
        guard let frame = screen?.frame, let visible = screen?.visibleFrame else { return }
        // Just under the menu bar, right-aligned.
        let origin = NSPoint(
            x: frame.maxX - width - 8,
            y: visible.maxY - height - 2
        )
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

#endif
