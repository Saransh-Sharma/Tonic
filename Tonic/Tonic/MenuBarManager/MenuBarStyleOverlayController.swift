//
//  MenuBarStyleOverlayController.swift
//  Tonic
//
//  Draws a cosmetic tint/gradient across the menu bar band using one
//  click-through borderless window per screen, sitting just below the status
//  items. Direct build only.
//

#if !TONIC_STORE

import AppKit
import SwiftUI

@MainActor
final class MenuBarStyleOverlayController {
    static let shared = MenuBarStyleOverlayController()

    private var windows: [NSWindow] = []
    private var screenObserver: NSObjectProtocol?
    private var styling: MenuBarStyling = MenuBarStyling()

    private init() {}

    func apply(_ styling: MenuBarStyling) {
        self.styling = styling
        if styling.isEnabled {
            rebuild()
            observeScreenChangesIfNeeded()
        } else {
            teardown()
        }
    }

    private func rebuild() {
        teardownWindows()
        for screen in NSScreen.screens {
            let menuBarHeight = screen.frame.maxY - screen.visibleFrame.maxY
            guard menuBarHeight > 0 else { continue }
            let frame = NSRect(
                x: screen.frame.minX,
                y: screen.frame.maxY - menuBarHeight,
                width: screen.frame.width,
                height: menuBarHeight
            )
            windows.append(makeWindow(frame: frame))
        }
    }

    private func makeWindow(frame: NSRect) -> NSWindow {
        let window = NSWindow(contentRect: frame, styleMask: [.borderless],
                              backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = true
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        // Just beneath the status items so icons stay legible on top.
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) - 1)
        window.contentView = NSHostingView(rootView: MenuBarStyleOverlayView(styling: styling))
        window.orderFrontRegardless()
        return window
    }

    private func observeScreenChangesIfNeeded() {
        guard screenObserver == nil else { return }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { _ in
            Task { @MainActor in
                guard MenuBarStyleOverlayController.shared.styling.isEnabled else { return }
                MenuBarStyleOverlayController.shared.rebuild()
            }
        }
    }

    private func teardownWindows() {
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
    }

    private func teardown() {
        teardownWindows()
        if let observer = screenObserver {
            NotificationCenter.default.removeObserver(observer)
            screenObserver = nil
        }
    }
}

#endif
