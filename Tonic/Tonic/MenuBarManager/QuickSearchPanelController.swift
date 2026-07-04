//
//  QuickSearchPanelController.swift
//  Tonic
//
//  Floating keyboard-first palette for finding and opening any menu bar item.
//  A nonactivating panel so the frontmost app keeps focus; opening an item
//  activates its menu via Accessibility.
//

import AppKit
import SwiftUI

@MainActor
final class QuickSearchPanelController {
    static let shared = QuickSearchPanelController()

    private var panel: NSPanel?
    private var localMonitor: Any?
    private var globalMonitor: Any?

    private init() {}

    var isVisible: Bool { panel?.isVisible ?? false }

    func toggle() {
        isVisible ? hide() : show()
    }

    func show() {
        // Fresh scan so the palette reflects the current bar.
        MenuBarManager.shared.refreshScan()

        let panel = panel ?? makePanel()
        self.panel = panel
        positionPanel(panel)

        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        installDismissMonitors()
    }

    func hide() {
        panel?.orderOut(nil)
        removeDismissMonitors()
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 420),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear
        panel.hasShadow = true

        let root = QuickSearchView(
            onActivate: { [weak self] item in
                self?.hide()
                Task { await MenuBarManager.shared.activate(item) }
            },
            onClose: { [weak self] in self?.hide() }
        )
        panel.contentView = NSHostingView(rootView: root)
        return panel
    }

    private func positionPanel(_ panel: NSPanel) {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
            ?? NSScreen.main
        guard let frame = screen?.visibleFrame else { return }
        let size = panel.frame.size
        let origin = NSPoint(
            x: frame.midX - size.width / 2,
            y: frame.maxY - size.height - frame.height * 0.12
        )
        panel.setFrameOrigin(origin)
    }

    private func installDismissMonitors() {
        removeDismissMonitors()
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.hide() }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let panel = self?.panel, event.window != panel {
                self?.hide()
            }
            return event
        }
    }

    private func removeDismissMonitors() {
        if let monitor = globalMonitor { NSEvent.removeMonitor(monitor); globalMonitor = nil }
        if let monitor = localMonitor { NSEvent.removeMonitor(monitor); localMonitor = nil }
    }
}
