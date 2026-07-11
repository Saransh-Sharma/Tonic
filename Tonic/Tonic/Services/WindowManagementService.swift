//
//  WindowManagementService.swift
//  Tonic
//
//  Accessibility-backed focused-window placement with before/after proof and restore.
//

import AppKit
import ApplicationServices
import Foundation

@MainActor
@Observable
final class WindowManagementService {
    static let shared = WindowManagementService()

    struct Display: Identifiable {
        let id: String
        let name: String
        let frame: CGRect
        let visibleFrame: CGRect
        let scale: CGFloat
        let isMain: Bool
    }

    private struct RestorableWindow {
        let element: AXUIElement
        let frame: CGRect
        let appName: String
        let receiptID: UUID
    }

    /// Cycling state: repeat-pressing the same action advances the frame variant.
    private struct CycleState {
        let action: WindowAction
        let window: AXUIElement
        var index: Int
        var appliedFrame: CGRect
    }

    private(set) var isAccessibilityGranted = AXIsProcessTrusted()
    private(set) var displays: [Display] = []
    private(set) var focusedAppName: String?
    private(set) var focusedWindowTitle: String?
    private(set) var focusedFrame: CGRect?
    private(set) var lastError: String?
    private(set) var previewAction: WindowAction?
    private(set) var lastReceipt: ActionReceipt?
    private var restorableWindow: RestorableWindow?
    private var cycleState: CycleState?
    /// Display names present at the last screen-parameters check, so rule
    /// evaluation fires only for newly connected displays.
    private var knownDisplayNames: Set<String> = Set(NSScreen.screens.map(\.localizedName))
    private var screenObserver: NSObjectProtocol?

    var canRestore: Bool { restorableWindow != nil }

    private init() {
        refresh()
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                WindowManagementService.shared.handleScreenParametersChange()
            }
        }
    }

    func refresh() {
        isAccessibilityGranted = AXIsProcessTrusted()
        displays = NSScreen.screens.map { screen in
            let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
            return Display(
                id: number?.stringValue ?? screen.localizedName,
                name: screen.localizedName,
                frame: screen.frame,
                visibleFrame: screen.visibleFrame,
                scale: screen.backingScaleFactor,
                isMain: screen == NSScreen.main
            )
        }

        focusedAppName = NSWorkspace.shared.frontmostApplication?.localizedName
        guard isAccessibilityGranted, let window = focusedWindow() else {
            focusedWindowTitle = nil
            focusedFrame = nil
            return
        }
        focusedWindowTitle = copyStringAttribute(kAXTitleAttribute as CFString, from: window)
        focusedFrame = readFrame(of: window)
    }

    func requestAccessibility() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func setPreview(_ action: WindowAction?) {
        guard previewAction != action else { return }
        previewAction = action
        if action != nil { TonicFeedback.alignment() }
    }

    func perform(_ action: WindowAction) {
        lastError = nil
        guard AXIsProcessTrusted() else {
            isAccessibilityGranted = false
            lastError = "Accessibility access is required to move and resize windows."
            return
        }
        guard let window = focusedWindow(), let originalFrame = readFrame(of: window) else {
            lastError = "Tonic could not find a movable window in the frontmost app."
            return
        }

        let screen = screen(containing: originalFrame) ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else {
            lastError = "No active display is available."
            return
        }

        // Repeat-press cycling: the same action on the same, unmoved window
        // advances through its frame variants (½ → ⅓ → ⅔ for the halves).
        let variants = action.cycleFrames(in: screen.visibleFrame).map(\.integral)
        var variantIndex = 0
        if WindowWorkspaceStore.shared.cyclingEnabled,
           variants.count > 1,
           let state = cycleState,
           state.action == action,
           CFEqual(state.window, window),
           framesRoughlyEqual(originalFrame.integral, state.appliedFrame) {
            variantIndex = (state.index + 1) % variants.count
        }
        let targetFrame = variants[variantIndex]
        let startedAt = Date()
        guard writeFrame(targetFrame, to: window) else {
            lastError = "The app did not allow Tonic to resize this window."
            return
        }
        cycleState = CycleState(action: action, window: window,
                                index: variantIndex, appliedFrame: targetFrame)

        let variantSuffix = ["", " (⅓)", " (⅔)"][variantIndex]
        let appName = NSWorkspace.shared.frontmostApplication?.localizedName ?? "Window"
        let receipt = ActionReceipt(
            tool: .windows,
            title: "Placed \(appName)",
            detail: "\(action.title)\(variantSuffix) on \(screen.localizedName)",
            startedAt: startedAt,
            affectedItems: 1,
            impact: dimensions(targetFrame),
            undo: .available(token: UUID().uuidString, expiresAt: nil),
            metadata: [
                "before": frameDescription(originalFrame),
                "after": frameDescription(targetFrame)
            ]
        )
        restorableWindow = RestorableWindow(element: window, frame: originalFrame, appName: appName, receiptID: receipt.id)
        lastReceipt = receipt
        focusedFrame = targetFrame
        ActionReceiptStore.shared.record(receipt)
        TonicFeedback.alignment()
    }

    func restoreLast() {
        guard let restore = restorableWindow else { return }
        guard writeFrame(restore.frame, to: restore.element) else {
            lastError = "The previous frame could not be restored because the window is no longer available."
            return
        }
        ActionReceiptStore.shared.markRestored(
            id: restore.receiptID,
            detail: "Restored \(restore.appName) to \(frameDescription(restore.frame))"
        )
        if var receipt = lastReceipt, receipt.id == restore.receiptID {
            receipt = ActionReceipt(
                id: receipt.id,
                tool: receipt.tool,
                title: receipt.title,
                detail: "Restored to its previous frame",
                status: .restored,
                startedAt: receipt.startedAt,
                affectedItems: receipt.affectedItems,
                impact: dimensions(restore.frame),
                metadata: receipt.metadata
            )
            lastReceipt = receipt
        }
        focusedFrame = restore.frame
        restorableWindow = nil
        TonicFeedback.levelChange()
    }

    // MARK: - Workspaces

    /// Silent snapshot of the current arrangement — no persistence, no receipt.
    /// Used by workspace capture and by automations' restore points.
    func snapshotCurrentArrangement(named name: String) -> WindowWorkspace? {
        guard AXIsProcessTrusted() else { return nil }

        var snapshots: [WorkspaceWindowSnapshot] = []
        for app in NSWorkspace.shared.runningApplications
            where app.activationPolicy == .regular && !app.isHidden {
            guard let bundleID = app.bundleIdentifier else { continue }
            for window in standardWindows(pid: app.processIdentifier) {
                guard let frame = readFrame(of: window),
                      frame.width > 40, frame.height > 40,
                      let screen = screen(containing: frame) else { continue }
                let visible = screen.visibleFrame
                let relative = CGRect(
                    x: (frame.minX - visible.minX) / visible.width,
                    y: (frame.minY - visible.minY) / visible.height,
                    width: frame.width / visible.width,
                    height: frame.height / visible.height
                )
                snapshots.append(WorkspaceWindowSnapshot(
                    bundleIdentifier: bundleID,
                    appName: app.localizedName ?? bundleID,
                    windowTitle: copyStringAttribute(kAXTitleAttribute as CFString, from: window),
                    display: signature(for: screen),
                    relativeFrame: relative
                ))
            }
        }

        guard !snapshots.isEmpty else { return nil }
        return WindowWorkspace(name: name, windows: snapshots)
    }

    /// Capture every standard window of every regular app into a named workspace.
    /// Returns nil (and sets `lastError`) when nothing could be captured.
    @discardableResult
    func captureWorkspace(named name: String) -> WindowWorkspace? {
        lastError = nil
        guard AXIsProcessTrusted() else {
            isAccessibilityGranted = false
            lastError = "Accessibility access is required to capture window arrangements."
            return nil
        }

        guard let workspace = snapshotCurrentArrangement(named: name) else {
            lastError = "No standard windows were found to capture."
            return nil
        }
        let snapshots = workspace.windows
        WindowWorkspaceStore.shared.add(workspace)
        ActionReceiptStore.shared.record(ActionReceipt(
            tool: .windows,
            title: "Captured workspace \u{201C}\(name)\u{201D}",
            detail: "\(snapshots.count) windows across \(workspace.appNames.count) apps",
            affectedItems: snapshots.count,
            impact: "\(snapshots.count) windows"
        ))
        TonicFeedback.alignment()
        return workspace
    }

    /// Re-place every captured window that is still running. Windows are matched
    /// per app by exact title first, then in order; missing apps are skipped.
    func apply(_ workspace: WindowWorkspace) {
        lastError = nil
        guard AXIsProcessTrusted() else {
            isAccessibilityGranted = false
            lastError = "Accessibility access is required to apply workspaces."
            return
        }

        let startedAt = Date()
        var placed = 0
        var missingApps = Set<String>()
        let byBundle = Dictionary(grouping: workspace.windows, by: \.bundleIdentifier)

        for (bundleID, snapshots) in byBundle {
            guard let app = NSWorkspace.shared.runningApplications
                .first(where: { $0.bundleIdentifier == bundleID }) else {
                missingApps.insert(snapshots.first?.appName ?? bundleID)
                continue
            }
            var windows = standardWindows(pid: app.processIdentifier)

            // First pass: exact title matches. Second pass: remaining in order.
            var pairs: [(WorkspaceWindowSnapshot, AXUIElement)] = []
            var unmatched: [WorkspaceWindowSnapshot] = []
            for snapshot in snapshots {
                if let title = snapshot.windowTitle,
                   let index = windows.firstIndex(where: {
                       copyStringAttribute(kAXTitleAttribute as CFString, from: $0) == title
                   }) {
                    pairs.append((snapshot, windows.remove(at: index)))
                } else {
                    unmatched.append(snapshot)
                }
            }
            for snapshot in unmatched {
                guard !windows.isEmpty else { break }
                pairs.append((snapshot, windows.removeFirst()))
            }

            for (snapshot, window) in pairs {
                let screen = screenMatching(snapshot.display) ?? NSScreen.main ?? NSScreen.screens.first
                guard let screen else { continue }
                let visible = screen.visibleFrame
                let target = CGRect(
                    x: visible.minX + snapshot.relativeFrame.minX * visible.width,
                    y: visible.minY + snapshot.relativeFrame.minY * visible.height,
                    width: snapshot.relativeFrame.width * visible.width,
                    height: snapshot.relativeFrame.height * visible.height
                ).integral
                if writeFrame(target, to: window) { placed += 1 }
            }
        }

        var detail = "\(placed) of \(workspace.windows.count) windows placed"
        if !missingApps.isEmpty {
            detail += " · not running: \(missingApps.sorted().joined(separator: ", "))"
        }
        ActionReceiptStore.shared.record(ActionReceipt(
            tool: .windows,
            title: "Applied workspace \u{201C}\(workspace.name)\u{201D}",
            detail: detail,
            startedAt: startedAt,
            affectedItems: placed,
            impact: "\(placed) windows"
        ))
        if placed == 0 {
            lastError = "None of the workspace's windows are currently available."
        }
        refresh()
        TonicFeedback.alignment()
    }

    // MARK: - Snap placement (drag-to-edge)

    /// The window (AX element) currently under a screen point, or nil.
    /// Point is in AppKit global coordinates.
    func window(atAppKitPoint point: CGPoint) -> AXUIElement? {
        guard AXIsProcessTrusted() else { return nil }
        let axPoint = CGPoint(x: point.x, y: mainDisplayHeight - point.y)
        let system = AXUIElementCreateSystemWide()
        var element: AXUIElement?
        guard AXUIElementCopyElementAtPosition(system, Float(axPoint.x), Float(axPoint.y), &element) == .success,
              var current = element else { return nil }

        // Walk up to the containing window.
        for _ in 0..<12 {
            if copyStringAttribute(kAXRoleAttribute as CFString, from: current) == (kAXWindowRole as String) {
                return current
            }
            var parent: CFTypeRef?
            guard AXUIElementCopyAttributeValue(current, kAXParentAttribute as CFString, &parent) == .success,
                  let parentValue = parent else { return nil }
            current = (parentValue as! AXUIElement)
        }
        return nil
    }

    /// AppKit frame of an arbitrary window element (for drag detection).
    func frame(of window: AXUIElement) -> CGRect? {
        readFrame(of: window)
    }

    /// Place a specific window (from a drag-snap) with a receipt + restore point.
    func performSnap(_ action: WindowAction, window: AXUIElement, on screen: NSScreen) {
        guard AXIsProcessTrusted() else { return }
        guard let originalFrame = readFrame(of: window) else { return }
        let targetFrame = action.frame(in: screen.visibleFrame).integral
        guard writeFrame(targetFrame, to: window) else { return }

        var appTitle = "Window"
        var appPID: pid_t = 0
        if AXUIElementGetPid(window, &appPID) == .success,
           let app = NSRunningApplication(processIdentifier: appPID),
           let name = app.localizedName {
            appTitle = name
        }
        let receipt = ActionReceipt(
            tool: .windows,
            title: "Snapped \(appTitle)",
            detail: "\(action.title) on \(screen.localizedName)",
            affectedItems: 1,
            impact: dimensions(targetFrame),
            undo: .available(token: UUID().uuidString, expiresAt: nil),
            metadata: [
                "before": frameDescription(originalFrame),
                "after": frameDescription(targetFrame)
            ]
        )
        restorableWindow = RestorableWindow(element: window, frame: originalFrame,
                                            appName: appTitle, receiptID: receipt.id)
        lastReceipt = receipt
        cycleState = nil
        ActionReceiptStore.shared.record(receipt)
        TonicFeedback.alignment()
        refresh()
    }

    // MARK: - Display rules

    private func handleScreenParametersChange() {
        refresh()
        let current = Set(NSScreen.screens.map(\.localizedName))
        let added = current.subtracting(knownDisplayNames)
        knownDisplayNames = current
        guard !added.isEmpty else { return }

        for name in added {
            for rule in WindowWorkspaceStore.shared.rules(matchingDisplayNamed: name) {
                guard let workspace = WindowWorkspaceStore.shared.workspace(id: rule.workspaceID) else { continue }
                // Give the system a moment to settle window positions after connect.
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(1.5))
                    WindowManagementService.shared.apply(workspace)
                }
            }
        }
    }

    // MARK: - AX helpers

    /// All non-minimized standard windows of a process.
    private func standardWindows(pid: pid_t) -> [AXUIElement] {
        let appElement = AXUIElementCreateApplication(pid)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement] else { return [] }
        return windows.filter { window in
            let subrole = copyStringAttribute(kAXSubroleAttribute as CFString, from: window)
            guard subrole == nil || subrole == (kAXStandardWindowSubrole as String) else { return false }
            var minimized: CFTypeRef?
            if AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimized) == .success,
               let isMinimized = minimized as? Bool, isMinimized {
                return false
            }
            return true
        }
    }

    private func signature(for screen: NSScreen) -> DisplaySignature {
        DisplaySignature(
            name: screen.localizedName,
            width: Int(screen.frame.width),
            height: Int(screen.frame.height),
            scale: Double(screen.backingScaleFactor)
        )
    }

    /// Screen matching a stored signature — by name (stable identity); exact
    /// resolution/scale may legitimately change between connects.
    private func screenMatching(_ signature: DisplaySignature) -> NSScreen? {
        NSScreen.screens.first { $0.localizedName == signature.name }
    }

    private func framesRoughlyEqual(_ lhs: CGRect, _ rhs: CGRect, tolerance: CGFloat = 4) -> Bool {
        abs(lhs.minX - rhs.minX) <= tolerance
            && abs(lhs.minY - rhs.minY) <= tolerance
            && abs(lhs.width - rhs.width) <= tolerance
            && abs(lhs.height - rhs.height) <= tolerance
    }

    private func focusedWindow() -> AXUIElement? {
        let system = AXUIElementCreateSystemWide()
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(system, kAXFocusedWindowAttribute as CFString, &value)
        guard error == .success else { return nil }
        return (value as! AXUIElement)
    }

    private func readFrame(of window: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let positionValue, let sizeValue else { return nil }

        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &position),
              AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) else { return nil }
        return appKitFrame(fromAXPosition: position, size: size)
    }

    private func writeFrame(_ appKitFrame: CGRect, to window: AXUIElement) -> Bool {
        var position = axPosition(fromAppKitFrame: appKitFrame)
        var size = appKitFrame.size
        guard let positionValue = AXValueCreate(.cgPoint, &position),
              let sizeValue = AXValueCreate(.cgSize, &size) else { return false }

        let positionResult = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
        let sizeResult = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        return positionResult == .success && sizeResult == .success
    }

    private func copyStringAttribute(_ attribute: CFString, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else { return nil }
        return value as? String
    }

    private func screen(containing frame: CGRect) -> NSScreen? {
        NSScreen.screens.max { lhs, rhs in
            lhs.frame.intersection(frame).area < rhs.frame.intersection(frame).area
        }
    }

    private var mainDisplayHeight: CGFloat {
        NSScreen.screens.first(where: { $0.frame.origin == .zero })?.frame.height
            ?? NSScreen.main?.frame.height
            ?? 0
    }

    private func appKitFrame(fromAXPosition position: CGPoint, size: CGSize) -> CGRect {
        CGRect(x: position.x, y: mainDisplayHeight - position.y - size.height, width: size.width, height: size.height)
    }

    private func axPosition(fromAppKitFrame frame: CGRect) -> CGPoint {
        CGPoint(x: frame.minX, y: mainDisplayHeight - frame.maxY)
    }

    private func dimensions(_ frame: CGRect) -> String {
        "\(Int(frame.width))×\(Int(frame.height))"
    }

    private func frameDescription(_ frame: CGRect) -> String {
        "\(dimensions(frame)) at \(Int(frame.minX)), \(Int(frame.minY))"
    }
}

private extension CGRect {
    var area: CGFloat { max(0, width) * max(0, height) }
}
