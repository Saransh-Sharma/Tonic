//
//  SnapDragController.swift
//  Tonic
//
//  Drag-to-edge window snapping. Global mouse monitors watch left-drags; when
//  the user drags a window's cursor into a screen-edge zone, a glass overlay
//  previews the target frame and releasing the mouse places the window there.
//  Requires Accessibility; gated by WindowWorkspaceStore.snapEnabled.
//

import AppKit
import SwiftUI

@MainActor
final class SnapDragController {
    static let shared = SnapDragController()

    /// Zone geometry: how close (pt) the cursor must be to an edge, and the
    /// square size that turns an edge hit into a corner (quarter) hit.
    private enum Zone {
        static let edgeThreshold: CGFloat = 12
        static let cornerSize: CGFloat = 140
    }

    private var monitors: [Any] = []
    private var overlayPanel: NSPanel?

    /// Drag session state.
    private var draggedWindow: AXUIElement?
    private var dragStartLocation: CGPoint?
    private var dragStartWindowFrame: CGRect?
    private var dragConfirmed = false
    private var activeAction: WindowAction?
    private var activeScreen: NSScreen?

    private init() {}

    var isRunning: Bool { !monitors.isEmpty }

    /// Start or stop to match the preference + permission state.
    func refresh() {
        let wanted = WindowWorkspaceStore.shared.snapEnabled && AXIsProcessTrusted()
        if wanted, !isRunning { start() }
        if !wanted, isRunning { stop() }
    }

    private func start() {
        let dragged = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged) { event in
            MainActor.assumeIsolated {
                SnapDragController.shared.handleDrag(event)
            }
        }
        let up = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { _ in
            MainActor.assumeIsolated {
                SnapDragController.shared.handleMouseUp()
            }
        }
        monitors = [dragged, up].compactMap(\.self)
    }

    private func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
        endSession()
    }

    // MARK: - Drag handling

    private func handleDrag(_ event: NSEvent) {
        let location = NSEvent.mouseLocation

        // First drag event of a session: find the window under the cursor.
        if dragStartLocation == nil {
            dragStartLocation = location
            draggedWindow = WindowManagementService.shared.window(atAppKitPoint: location)
            dragStartWindowFrame = draggedWindow.flatMap {
                WindowManagementService.shared.frame(of: $0)
            }
            return
        }

        guard let window = draggedWindow,
              let startLocation = dragStartLocation,
              let startFrame = dragStartWindowFrame else { return }

        // Confirm this is a window MOVE (not a resize or in-window drag):
        // the window's origin must be tracking the cursor.
        if !dragConfirmed {
            let cursorDelta = hypot(location.x - startLocation.x, location.y - startLocation.y)
            guard cursorDelta > 20 else { return }
            guard let current = WindowManagementService.shared.frame(of: window) else { return }
            let originDelta = hypot(current.minX - startFrame.minX, current.minY - startFrame.minY)
            let sizeDelta = abs(current.width - startFrame.width) + abs(current.height - startFrame.height)
            guard originDelta > 10, sizeDelta < 4 else { return }
            dragConfirmed = true
        }

        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(location) })
            ?? NSScreen.main else { return }
        let action = zoneAction(for: location, on: screen)
        updateOverlay(action: action, on: screen)
    }

    private func handleMouseUp() {
        defer { endSession() }
        guard dragConfirmed,
              let action = activeAction,
              let screen = activeScreen,
              let window = draggedWindow else { return }
        WindowManagementService.shared.performSnap(action, window: window, on: screen)
    }

    private func endSession() {
        draggedWindow = nil
        dragStartLocation = nil
        dragStartWindowFrame = nil
        dragConfirmed = false
        activeAction = nil
        activeScreen = nil
        hideOverlay()
    }

    // MARK: - Zones

    /// Zone for a cursor location: corners → quarters, left/right edges →
    /// halves, top edge → maximize. Bottom edge is left to the Dock.
    private func zoneAction(for location: CGPoint, on screen: NSScreen) -> WindowAction? {
        let frame = screen.frame
        let nearLeft = location.x <= frame.minX + Zone.edgeThreshold
        let nearRight = location.x >= frame.maxX - Zone.edgeThreshold
        let nearTop = location.y >= frame.maxY - Zone.edgeThreshold
        let inTopBand = location.y >= frame.maxY - Zone.cornerSize
        let inBottomBand = location.y <= frame.minY + Zone.cornerSize

        if nearLeft {
            if inTopBand { return .topLeft }
            if inBottomBand { return .bottomLeft }
            return .leftHalf
        }
        if nearRight {
            if inTopBand { return .topRight }
            if inBottomBand { return .bottomRight }
            return .rightHalf
        }
        if nearTop { return .maximize }
        return nil
    }

    // MARK: - Overlay

    private func updateOverlay(action: WindowAction?, on screen: NSScreen) {
        guard action != activeAction || screen != activeScreen else { return }
        activeAction = action
        activeScreen = screen

        guard let action else {
            hideOverlay()
            return
        }

        let target = action.frame(in: screen.visibleFrame).insetBy(dx: 6, dy: 6)
        let panel = overlayPanel ?? makeOverlayPanel()
        panel.setFrame(target, display: true)
        panel.contentView = NSHostingView(rootView: SnapZoneHighlight())
        if !panel.isVisible { panel.orderFrontRegardless() }
        TonicFeedback.alignment()
    }

    private func hideOverlay() {
        overlayPanel?.orderOut(nil)
    }

    private func makeOverlayPanel() -> NSPanel {
        let panel = NSPanel(contentRect: .zero,
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered,
                            defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        overlayPanel = panel
        return panel
    }
}

/// The glass zone preview: a quiet washed panel with a hairline rim — chrome,
/// not data, so no status or brand color.
private struct SnapZoneHighlight: View {
    var body: some View {
        RoundedRectangle(cornerRadius: TonicDS.Radius.md, style: .continuous)
            .fill(TonicDS.Colors.rowHover(0.12))
            .overlay(
                RoundedRectangle(cornerRadius: TonicDS.Radius.md, style: .continuous)
                    .strokeBorder(TonicDS.Colors.glassStroke, lineWidth: 1.5)
            )
            .background(
                TonicGlassPolicy.shared.isGlassEnabled
                    ? AnyView(RoundedRectangle(cornerRadius: TonicDS.Radius.md, style: .continuous)
                        .fill(.ultraThinMaterial))
                    : AnyView(EmptyView())
            )
            .ignoresSafeArea()
    }
}
