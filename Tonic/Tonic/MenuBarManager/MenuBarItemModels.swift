//
//  MenuBarItemModels.swift
//  Tonic
//
//  Models + pure classification logic for third-party menu bar items.
//  Discovery uses CGWindowList *metadata only* (owner, frame, layer) — no
//  window names or images, so no Screen Recording permission is involved.
//

import CoreGraphics
import CryptoKit
import Foundation

/// Which side of Tonic's separators an item sits on.
public enum MenuBarSection: String, Sendable, Codable, CaseIterable {
    case visible
    case hidden
    case alwaysHidden

    public var displayName: String {
        switch self {
        case .visible: return "Visible"
        case .hidden: return "On Demand"
        case .alwaysHidden: return "Quiet"
        }
    }
}

public struct MenuBarSpacer: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var label: String
    public var width: Double
    public var section: MenuBarSection
    public var isHidden: Bool

    public init(id: UUID = UUID(), label: String = "Spacer", width: Double = 12,
                section: MenuBarSection = .visible, isHidden: Bool = false) {
        self.id = id
        self.label = label
        self.width = min(max(width, 4), 96)
        self.section = section
        self.isHidden = isHidden
    }
}

public struct MenuBarItemGroup: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var itemKeys: [String]
    public var symbolName: String
    public var accentHex: String?
    public var isPinned: Bool
    public var presentationOverride: QuickShelfPresentation?

    public init(id: UUID = UUID(), name: String, itemKeys: [String] = [],
                symbolName: String = "square.grid.2x2", accentHex: String? = nil,
                isPinned: Bool = false, presentationOverride: QuickShelfPresentation? = nil) {
        self.id = id
        self.name = name
        self.itemKeys = itemKeys
        self.symbolName = symbolName
        self.accentHex = accentHex
        self.isPinned = isPinned
        self.presentationOverride = presentationOverride
    }
}

public enum CustomMenuBarDataSource: Codable, Equatable, Sendable {
    case staticLabel(String)
    case date(format: String)
    case battery
    case cpu
    case memory
    case network
    case weather
    case formatted(template: String)
    case provider(String)
}

public enum CustomMenuBarSafeAction: Codable, Equatable, Sendable {
    case openApplication(bundleIdentifier: String)
    case openFile(bookmark: Data)
    case openURL(URL)
    case openTonicDestination(String)
    case runShortcut(name: String)
    #if !TONIC_STORE
    case runScript(UUID)
    #endif
}

#if !TONIC_STORE
public struct CustomMenuBarScript: Codable, Identifiable, Equatable, Sendable {
    public enum Source: Codable, Equatable, Sendable {
        case inline(String)
        case securityScopedBookmark(Data)
    }

    public var id: UUID
    public var source: Source
    public var executable: String
    public var arguments: [String]
    public var workingDirectoryBookmark: Data?
    public var environmentAllowlist: [String: String]
    public var timeoutSeconds: Double
    public var mapsFirstOutputLineToLabel: Bool
    public var failureCount: Int
    public var isPaused: Bool

    public init(id: UUID = UUID(), source: Source, executable: String,
                arguments: [String] = [], workingDirectoryBookmark: Data? = nil,
                environmentAllowlist: [String: String] = [:], timeoutSeconds: Double = 15,
                mapsFirstOutputLineToLabel: Bool = false, failureCount: Int = 0,
                isPaused: Bool = false) {
        self.id = id
        self.source = source
        self.executable = executable
        self.arguments = arguments
        self.workingDirectoryBookmark = workingDirectoryBookmark
        self.environmentAllowlist = environmentAllowlist
        self.timeoutSeconds = min(max(timeoutSeconds, 1), 300)
        self.mapsFirstOutputLineToLabel = mapsFirstOutputLineToLabel
        self.failureCount = max(0, failureCount)
        self.isPaused = isPaused || failureCount >= 3
    }
}
#endif

public struct CustomMenuBarItem: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var symbolName: String
    public var imageBookmark: Data?
    public var dataSource: CustomMenuBarDataSource
    public var actions: [CustomMenuBarSafeAction]
    public var section: MenuBarSection

    public init(id: UUID = UUID(), name: String, symbolName: String = "sparkles",
                imageBookmark: Data? = nil, dataSource: CustomMenuBarDataSource,
                actions: [CustomMenuBarSafeAction] = [], section: MenuBarSection = .visible) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.imageBookmark = imageBookmark
        self.dataSource = dataSource
        self.actions = actions
        self.section = section
    }
}

/// Privacy-preserving update watch state. Callers provide a nonreversible
/// digest derived from ephemeral local imagery; raw captures are never stored.
@Observable
@MainActor
public final class MenuBarUpdateWatchStore {
    public static let shared = MenuBarUpdateWatchStore()
    private static let defaultsKey = "tonic.menuBarUpdateWatch.v1"

    private struct Envelope: Codable {
        var watchedKeys: Set<String> = []
        var lastDigests: [String: String] = [:]
        var unseenKeys: Set<String> = []
        var changedAt: [String: Date] = [:]
        var thumbnails: [String: Data] = [:]

        init(watchedKeys: Set<String> = [], lastDigests: [String: String] = [:],
             unseenKeys: Set<String> = [], changedAt: [String: Date] = [:],
             thumbnails: [String: Data] = [:]) {
            self.watchedKeys = watchedKeys; self.lastDigests = lastDigests; self.unseenKeys = unseenKeys
            self.changedAt = changedAt; self.thumbnails = thumbnails
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            watchedKeys = try container.decodeIfPresent(Set<String>.self, forKey: .watchedKeys) ?? []
            lastDigests = try container.decodeIfPresent([String: String].self, forKey: .lastDigests) ?? [:]
            unseenKeys = try container.decodeIfPresent(Set<String>.self, forKey: .unseenKeys) ?? []
            changedAt = try container.decodeIfPresent([String: Date].self, forKey: .changedAt) ?? [:]
            thumbnails = try container.decodeIfPresent([String: Data].self, forKey: .thumbnails) ?? [:]
        }
    }

    public private(set) var watchedKeys: Set<String>
    public private(set) var unseenKeys: Set<String>
    private var lastDigests: [String: String]
    public private(set) var changedAt: [String: Date]
    public private(set) var thumbnails: [String: Data]
    private let defaults: UserDefaults

    public var unseenCount: Int { unseenKeys.count }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let envelope: Envelope
        if let data = defaults.data(forKey: Self.defaultsKey),
           let decoded = try? JSONDecoder().decode(Envelope.self, from: data) {
            envelope = decoded
        } else {
            envelope = Envelope()
        }
        watchedKeys = envelope.watchedKeys
        unseenKeys = envelope.unseenKeys
        lastDigests = envelope.lastDigests
        changedAt = envelope.changedAt
        thumbnails = envelope.thumbnails
    }

    public func setWatching(_ watching: Bool, key: String) {
        if watching {
            watchedKeys.insert(key)
        } else {
            watchedKeys.remove(key)
            lastDigests.removeValue(forKey: key)
            unseenKeys.remove(key)
            changedAt.removeValue(forKey: key)
            thumbnails.removeValue(forKey: key)
        }
        persist()
        MenuBarUpdateWatcherCoordinator.shared.refresh()
    }

    /// Returns true only for a changed digest after an initial baseline.
    @discardableResult
    public func recordDigest(_ digest: String, thumbnail: Data? = nil, for key: String) -> Bool {
        guard watchedKeys.contains(key), !digest.isEmpty else { return false }
        let previous = lastDigests.updateValue(digest, forKey: key)
        let changed = previous != nil && previous != digest
        if changed {
            unseenKeys.insert(key)
            changedAt[key] = Date()
            if let thumbnail, thumbnail.count <= 32 * 1_024 { thumbnails[key] = thumbnail }
            MenuBarManager.shared.temporarilyReveal(key, duration: 8)
        }
        persist()
        MenuBarManager.shared.refreshUpdateBadge()
        return changed
    }

    public func acknowledge(_ key: String) {
        guard unseenKeys.remove(key) != nil else { return }
        persist()
        MenuBarManager.shared.refreshUpdateBadge()
    }

    private func persist() {
        let envelope = Envelope(watchedKeys: watchedKeys, lastDigests: lastDigests, unseenKeys: unseenKeys,
                                changedAt: changedAt, thumbnails: thumbnails)
        if let data = try? JSONEncoder().encode(envelope) {
            defaults.set(data, forKey: Self.defaultsKey)
        }
    }
}

/// Raw frames remain caller-owned and are discarded after this actor returns a
/// nonreversible digest and an optional already-downsampled display asset.
public actor MenuBarUpdateCaptureProcessor {
    public init() {}

    public func digest(ephemeralBytes: Data) -> String {
        SHA256.hash(data: ephemeralBytes).map { String(format: "%02x", $0) }.joined()
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
