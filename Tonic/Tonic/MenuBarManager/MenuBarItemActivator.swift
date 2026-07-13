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

        let child = try Self.statusElement(for: fresh)

        guard AXUIElementPerformAction(child, kAXPressAction as CFString) == .success else {
            throw ActivationError.pressFailed
        }
        logger.info("Activated menu bar item for \(fresh.ownerName)")
    }

    /// Resolves a foreign status item without activating it. The returned AX
    /// element is used only on the main actor and is never persisted.
    static func statusElement(for item: MenuBarItemInfo) throws -> AXUIElement {
        let appElement = AXUIElementCreateApplication(item.ownerPID)
        var extrasRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, "AXExtrasMenuBar" as CFString, &extrasRef) == .success,
              let extras = extrasRef, CFGetTypeID(extras) == AXUIElementGetTypeID() else {
            throw ActivationError.axUnavailable
        }
        // swiftlint:disable:next force_cast
        let extrasBar = extras as! AXUIElement
        let children = axChildren(extrasBar)
        guard !children.isEmpty else { throw ActivationError.noMatch }
        return children.count == 1 ? children[0]
            : bestMatch(children: children, frame: item.frame) ?? children[0]
    }

    /// Reads the currently open menu using Accessibility metadata only. Text
    /// and element paths live for the proxy session and are never persisted.
    static func openMenuItems(for item: MenuBarItemInfo) -> [ForeignMenuProxyItem] {
        let application = AXUIElementCreateApplication(item.ownerPID)
        guard let menu = firstDescendant(of: application, role: kAXMenuRole as String,
                                         maximumDepth: 5) else { return [] }
        var result: [ForeignMenuProxyItem] = []
        collectMenuItems(menu, path: [], depth: 0, into: &result)
        return Array(result.prefix(ForeignMenuProxySession.maximumItems))
    }

    /// Re-resolves the transient menu path immediately before forwarding a
    /// deliberate activation. Ambiguous or changed trees fail closed.
    static func performOpenMenuPath(for item: MenuBarItemInfo, path: [Int]) -> Bool {
        let application = AXUIElementCreateApplication(item.ownerPID)
        guard let menu = firstDescendant(of: application, role: kAXMenuRole as String,
                                         maximumDepth: 5) else { return false }
        var current = menu
        for index in path {
            let children = axChildren(current)
            guard children.indices.contains(index) else { return false }
            current = children[index]
        }
        guard axBoolean(current, kAXEnabledAttribute as String) ?? true else { return false }
        return AXUIElementPerformAction(current, kAXPressAction as CFString) == .success
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

    private static func axChildren(_ element: AXUIElement) -> [AXUIElement] {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &ref) == .success else {
            return []
        }
        return ref as? [AXUIElement] ?? []
    }

    private static func axString(_ element: AXUIElement, _ attribute: String) -> String? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &ref) == .success else { return nil }
        return ref as? String
    }

    private static func axBoolean(_ element: AXUIElement, _ attribute: String) -> Bool? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &ref) == .success else { return nil }
        return ref as? Bool
    }

    private static func firstDescendant(of element: AXUIElement, role: String,
                                        maximumDepth: Int) -> AXUIElement? {
        guard maximumDepth >= 0 else { return nil }
        if axString(element, kAXRoleAttribute as String) == role { return element }
        guard maximumDepth > 0 else { return nil }
        for child in axChildren(element) {
            if let match = firstDescendant(of: child, role: role, maximumDepth: maximumDepth - 1) {
                return match
            }
        }
        return nil
    }

    private static func collectMenuItems(_ element: AXUIElement, path: [Int], depth: Int,
                                         into result: inout [ForeignMenuProxyItem]) {
        guard depth <= 5, result.count < ForeignMenuProxySession.maximumItems else { return }
        for (index, child) in axChildren(element).enumerated() {
            guard result.count < ForeignMenuProxySession.maximumItems else { return }
            let childPath = path + [index]
            let role = axString(child, kAXRoleAttribute as String)
            if role == (kAXMenuItemRole as String) {
                let title = axString(child, kAXTitleAttribute as String)
                    ?? axString(child, kAXDescriptionAttribute as String) ?? ""
                if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let subrole = axString(child, kAXSubroleAttribute as String)?.lowercased() ?? ""
                    let secure = subrole.contains("secure") || subrole.contains("password")
                    result.append(ForeignMenuProxyItem(
                        title: title,
                        isEnabled: axBoolean(child, kAXEnabledAttribute as String) ?? true,
                        isSecure: secure,
                        path: childPath
                    ))
                }
            }
            collectMenuItems(child, path: childPath, depth: depth + 1, into: &result)
        }
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
