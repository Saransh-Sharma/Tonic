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
import CoreImage
import SwiftUI

@MainActor
final class MenuBarStyleOverlayController {
    static let shared = MenuBarStyleOverlayController()

    private var windows: [NSWindow] = []
    private var screenObserver: NSObjectProtocol?
    private var spaceObserver: NSObjectProtocol?
    private var profileObserver: NSObjectProtocol?
    private var styling: MenuBarStyling = MenuBarStyling()

    private init() {}

    func apply(_ styling: MenuBarStyling) {
        self.styling = styling
        if hasEnabledAppearance {
            rebuild()
            observeScreenChangesIfNeeded()
        } else {
            teardown()
        }
    }

    private func rebuild() {
        teardownWindows()
        for screen in NSScreen.screens {
            let resolved = resolvedStyling(for: screen)
            guard resolved.isEnabled else { continue }
            let menuBarHeight = screen.frame.maxY - screen.visibleFrame.maxY
            guard menuBarHeight > 0 else { continue }
            let frame = NSRect(
                x: screen.frame.minX,
                y: screen.frame.maxY - menuBarHeight,
                width: screen.frame.width,
                height: menuBarHeight
            )
            windows.append(makeWindow(frame: frame, styling: resolved))
        }
    }

    private func makeWindow(frame: NSRect, styling: MenuBarStyling) -> NSWindow {
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
                guard MenuBarStyleOverlayController.shared.hasEnabledAppearance else { return }
                MenuBarStyleOverlayController.shared.rebuild()
            }
        }
        spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
        ) { _ in
            Task { @MainActor in
                guard MenuBarStyleOverlayController.shared.hasEnabledAppearance else { return }
                MenuBarStyleOverlayController.shared.rebuild()
            }
        }
        profileObserver = NotificationCenter.default.addObserver(
            forName: .menuBarPresentationContextDidChange, object: nil, queue: .main
        ) { _ in
            Task { @MainActor in
                guard MenuBarStyleOverlayController.shared.hasEnabledAppearance else { return }
                MenuBarStyleOverlayController.shared.rebuild()
            }
        }
    }

    private var hasEnabledAppearance: Bool {
        styling.isEnabled || MenuBarProfileStore.shared.profiles.contains { $0.values.appearance?.isEnabled == true }
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
        if let observer = spaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            spaceObserver = nil
        }
        if let observer = profileObserver {
            NotificationCenter.default.removeObserver(observer)
            profileObserver = nil
        }
    }

    private func resolvedStyling(for screen: NSScreen) -> MenuBarStyling {
        let profileStore = MenuBarProfileStore.shared
        let values = MenuBarProfileResolver().resolve(profiles: profileStore.profiles,
            display: DisplayIdentity(screen: screen), manualContextID: profileStore.selectedManualContextID)
        let effective = values.appearance ?? styling
        guard effective.matchesWallpaper,
              let url = NSWorkspace.shared.desktopImageURL(for: screen),
              let image = CIImage(contentsOf: url) else { return effective }
        let extent = image.extent
        guard !extent.isEmpty else { return effective }
        let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: image,
                                                                   kCIInputExtentKey: CIVector(cgRect: extent)])
        guard let output = filter?.outputImage else { return effective }
        var pixel = [UInt8](repeating: 0, count: 4)
        CIContext(options: [.workingColorSpace: NSNull()]).render(output, toBitmap: &pixel,
            rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB())
        var resolved = effective
        resolved.tintHex = String(format: "#%02X%02X%02X", pixel[0], pixel[1], pixel[2])
        resolved.gradientEndHex = String(format: "#%02X%02X%02X",
                                         min(255, Int(pixel[0]) + 24),
                                         min(255, Int(pixel[1]) + 24),
                                         min(255, Int(pixel[2]) + 24))
        return resolved
    }
}

#endif
