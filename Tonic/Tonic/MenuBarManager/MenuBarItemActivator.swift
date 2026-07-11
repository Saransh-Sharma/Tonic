//
//  MenuBarItemActivator.swift
//  Tonic
//
//  Opens another app's menu bar item programmatically via Accessibility:
//  AXUIElementCreateApplication → AXExtrasMenuBar → child → AXPress. Used by
//  the dashboard, Quick Search, and the Tonic Bar. Direct build only —
//  controlling other apps through AX is not sandbox-compatible.
//

#if !TONIC_STORE

import AppKit
import ApplicationServices
import os

@MainActor
final class MenuBarItemActivator {

    enum ActivationError: LocalizedError {
        case notTrusted
        case axUnavailable
        case noMatch
        case pressFailed

        var errorDescription: String? {
            switch self {
            case .notTrusted: return "Accessibility permission is required to open menu bar items."
            case .axUnavailable: return "That app doesn't expose its menu bar item to Accessibility."
            case .noMatch: return "Couldn't locate the item's control."
            case .pressFailed: return "The item refused the activation."
            }
        }
    }

    private let logger = Logger(subsystem: "com.tonic.app", category: "MenuBarItemActivator")

    /// Open the item's menu. Hidden items are revealed first (the rehide
    /// timer collapses the bar again after the interaction).
    func activate(_ item: MenuBarItemInfo) async throws {
        guard Self.ensureTrust() else { throw ActivationError.notTrusted }

        let manager = MenuBarManager.shared

        // AX positions of collapsed items sit past the screen edge and the
        // press lands nowhere useful — reveal first.
        let needsAlwaysHidden = item.section == .alwaysHidden
        if manager.isActive, item.section != .visible,
           !manager.isExpanded || (needsAlwaysHidden && !manager.isShowingAlwaysHidden) {
            manager.expand(showAlwaysHidden: needsAlwaysHidden)
            try? await Task.sleep(nanoseconds: 450_000_000)
            manager.refreshScan()
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        let fresh = manager.items.first { $0.windowID == item.windowID }
            ?? manager.items.first { $0.stableKey == item.stableKey }
            ?? item

        let appElement = AXUIElementCreateApplication(fresh.ownerPID)

        var extrasRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, "AXExtrasMenuBar" as CFString, &extrasRef) == .success,
              let extras = extrasRef, CFGetTypeID(extras) == AXUIElementGetTypeID() else {
            throw ActivationError.axUnavailable
        }
        // swiftlint:disable:next force_cast
        let extrasBar = extras as! AXUIElement

        var childrenRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(extrasBar, kAXChildrenAttribute as CFString, &childrenRef) == .success,
              let children = childrenRef as? [AXUIElement], !children.isEmpty else {
            throw ActivationError.noMatch
        }

        let child = children.count == 1
            ? children[0]
            : Self.bestMatch(children: children, frame: fresh.frame) ?? children[0]

        guard AXUIElementPerformAction(child, kAXPressAction as CFString) == .success else {
            throw ActivationError.pressFailed
        }
        logger.info("Activated menu bar item for \(fresh.ownerName)")
    }

    static func ensureTrust() -> Bool {
        if AXIsProcessTrusted() { return true }
        // The exported ApplicationServices global is imported as mutable state,
        // which makes it unavailable from Swift 6 isolation domains. Its public
        // CFString value is stable and documented by the Accessibility API.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Child matching

    /// Nearest horizontal midpoint wins — AX positions are global top-left,
    /// the same space as our CGWindowList frames.
    private static func bestMatch(children: [AXUIElement], frame: CGRect) -> AXUIElement? {
        var best: (element: AXUIElement, distance: CGFloat)?
        for child in children {
            guard let position = axPoint(child, kAXPositionAttribute as CFString) else { continue }
            let size = axSize(child, kAXSizeAttribute as CFString) ?? CGSize(width: 30, height: 24)
            let midX = position.x + size.width / 2
            let distance = abs(midX - frame.midX)
            if best == nil || distance < best!.distance {
                best = (child, distance)
            }
        }
        return best?.element
    }

    private static func axPoint(_ element: AXUIElement, _ attribute: CFString) -> CGPoint? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &ref) == .success,
              let value = ref, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        // swiftlint:disable:next force_cast
        guard AXValueGetValue(value as! AXValue, .cgPoint, &point) else { return nil }
        return point
    }

    private static func axSize(_ element: AXUIElement, _ attribute: CFString) -> CGSize? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &ref) == .success,
              let value = ref, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var size = CGSize.zero
        // swiftlint:disable:next force_cast
        guard AXValueGetValue(value as! AXValue, .cgSize, &size) else { return nil }
        return size
    }
}

#endif
