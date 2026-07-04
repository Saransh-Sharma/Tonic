//
//  MenuBarItemModels.swift
//  Tonic
//
//  Models + pure classification logic for third-party menu bar items.
//  Discovery uses CGWindowList *metadata only* (owner, frame, layer) — no
//  window names or images, so no Screen Recording permission is involved.
//

import CoreGraphics
import Foundation

/// Which side of Tonic's separators an item sits on.
public enum MenuBarSection: String, Sendable, Codable, CaseIterable {
    case visible
    case hidden
    case alwaysHidden

    public var displayName: String {
        switch self {
        case .visible: return "Visible"
        case .hidden: return "Hidden"
        case .alwaysHidden: return "Always hidden"
        }
    }
}

/// One third-party status item window in the menu bar.
public struct MenuBarItemInfo: Identifiable, Equatable, Sendable {
    public let windowID: CGWindowID
    public let ownerPID: pid_t
    public let ownerName: String
    /// Global CG coordinates (top-left origin). Hidden items sit far past the
    /// left screen edge while collapsed.
    public let frame: CGRect
    public let isOnScreen: Bool
    /// Control Center / system agents can't be pushed by the separator trick;
    /// the management UI shows them grayed.
    public let isSystemControlled: Bool
    public var section: MenuBarSection?

    public var id: CGWindowID { windowID }
}

/// Pure functions: CGWindowList dict → item, and x-position → section.
/// Kept free of AppKit so XCTest can drive them with fixture dictionaries.
public enum MenuBarItemClassifier {

    /// NSWindow.Level.statusBar — the layer menu bar status items render at.
    public static let statusBarWindowLayer = 25

    /// Menu bar windows live in the primary display's top band (y ≈ 0 in CG
    /// global coordinates); notch Macs run taller, so allow up to this height.
    public static let menuBarBandMaxY: CGFloat = 40

    /// Owners whose items macOS lays out itself (right of all third-party
    /// items) — the separator cannot move them.
    public static let systemOwners: Set<String> = [
        "Control Center", "ControlCenter", "SystemUIServer",
        "TextInputMenuAgent", "Spotlight", "Siri", "Clock"
    ]

    /// Parse one CGWindowList dictionary into an item, filtering to
    /// third-party status-bar windows on the primary display's menu bar band.
    public static func parseWindowInfo(_ dict: [String: Any], ownPID: pid_t) -> MenuBarItemInfo? {
        guard let layer = dict[kCGWindowLayer as String] as? Int,
              layer == statusBarWindowLayer,
              let pid = dict[kCGWindowOwnerPID as String] as? Int32,
              pid != ownPID,
              let windowID = dict[kCGWindowNumber as String] as? UInt32,
              let boundsDict = dict[kCGWindowBounds as String] as? [String: Any],
              let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary)
        else { return nil }

        // Menu bar band on the primary display only: y at the very top, item-sized.
        guard bounds.minY >= -1, bounds.minY < menuBarBandMaxY,
              bounds.height > 0, bounds.height <= menuBarBandMaxY,
              bounds.width > 0, bounds.width < 500
        else { return nil }

        let ownerName = dict[kCGWindowOwnerName as String] as? String ?? "Unknown"
        let isOnScreen = dict[kCGWindowIsOnscreen as String] as? Bool ?? false

        return MenuBarItemInfo(
            windowID: CGWindowID(windowID),
            ownerPID: pid,
            ownerName: ownerName,
            frame: bounds,
            isOnScreen: isOnScreen,
            isSystemControlled: systemOwners.contains(ownerName),
            section: nil
        )
    }

    /// Assign sections by x-position relative to the separators' left edges.
    /// Works identically expanded and collapsed: when a separator inflates to
    /// 10,000 pt, everything left of it shifts off screen but the ordering
    /// `item.midX < separator.minX` is preserved.
    public static func classify(
        items: [MenuBarItemInfo],
        separatorMinX: CGFloat?,
        alwaysHiddenMinX: CGFloat?
    ) -> [MenuBarItemInfo] {
        items.map { item in
            var updated = item
            updated.section = section(for: item,
                                      separatorMinX: separatorMinX,
                                      alwaysHiddenMinX: alwaysHiddenMinX)
            return updated
        }
    }

    static func section(
        for item: MenuBarItemInfo,
        separatorMinX: CGFloat?,
        alwaysHiddenMinX: CGFloat?
    ) -> MenuBarSection {
        guard !item.isSystemControlled else { return .visible }
        if let alwaysX = alwaysHiddenMinX, item.frame.midX < alwaysX {
            return .alwaysHidden
        }
        if let sepX = separatorMinX, item.frame.midX < sepX {
            return .hidden
        }
        return .visible
    }
}
