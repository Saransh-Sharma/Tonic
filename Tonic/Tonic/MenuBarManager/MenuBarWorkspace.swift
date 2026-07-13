//
//  MenuBarWorkspace.swift
//  Tonic
//
//  Versioned, transactional state for the Menu Bar workspace. Foreign status
//  items and Tonic-owned items share one draft and are materialized only when
//  the user explicitly applies it.
//

import Foundation

public struct MenuBarCapabilities: Equatable, Sendable {
    public var canDiscover: Bool
    public var canPreview: Bool
    public var canCreateOwnedItems: Bool
    public var canRunSafeActions: Bool
    public var canStyle: Bool
    public var canUsePresets: Bool
    public var canMoveForeignItems: Bool
    public var canActivateForeignItems: Bool
    public var canRunScripts: Bool
    public var canUsePrivilegedHelper: Bool

    public static var current: Self {
        #if TONIC_STORE
        Self(canDiscover: true, canPreview: true, canCreateOwnedItems: true,
             canRunSafeActions: true, canStyle: true, canUsePresets: true,
             canMoveForeignItems: false, canActivateForeignItems: false,
             canRunScripts: false, canUsePrivilegedHelper: false)
        #else
        Self(canDiscover: true, canPreview: true, canCreateOwnedItems: true,
             canRunSafeActions: true, canStyle: true, canUsePresets: true,
             canMoveForeignItems: true, canActivateForeignItems: true,
             canRunScripts: true, canUsePrivilegedHelper: true)
        #endif
    }
}

public enum MenuBarLayoutMode: String, Codable, CaseIterable, Sendable {
    case onDemand
    case live

    public var title: String { self == .onDemand ? "On-Demand" : "Live" }
}

public enum MenuBarLayoutNode: Codable, Hashable, Sendable {
    case foreign(stableKey: String)
    case spacer(UUID)
    case group(UUID)
    case customItem(UUID)

    public var stableID: String {
        switch self {
        case .foreign(let key): "foreign:\(key)"
        case .spacer(let id): "spacer:\(id.uuidString)"
        case .group(let id): "group:\(id.uuidString)"
        case .customItem(let id): "custom:\(id.uuidString)"
        }
    }
}

public struct MenuBarLayoutDraft: Codable, Equatable, Sendable {
    public var baselineRevision: UUID
    public var orderedNodes: [MenuBarLayoutNode]
    public var foreignAssignments: [String: MenuBarSection]
    public var spacers: [MenuBarSpacer]
    public var groups: [MenuBarItemGroup]
    public var customItems: [CustomMenuBarItem]

    public init(baselineRevision: UUID = UUID(), orderedNodes: [MenuBarLayoutNode] = [],
                foreignAssignments: [String: MenuBarSection] = [:],
                spacers: [MenuBarSpacer] = [], groups: [MenuBarItemGroup] = [],
                customItems: [CustomMenuBarItem] = []) {
        self.baselineRevision = baselineRevision
        self.orderedNodes = orderedNodes
        self.foreignAssignments = foreignAssignments
        self.spacers = spacers
        self.groups = groups
        self.customItems = customItems
    }

    public mutating func normalizeOrder() {
        let owned = spacers.map { MenuBarLayoutNode.spacer($0.id) }
            + groups.map { MenuBarLayoutNode.group($0.id) }
            + customItems.map { MenuBarLayoutNode.customItem($0.id) }
        let valid = Set(foreignAssignments.keys.map { MenuBarLayoutNode.foreign(stableKey: $0) } + owned)
        orderedNodes = orderedNodes.filter(valid.contains)
        for node in foreignAssignments.keys.sorted().map({ MenuBarLayoutNode.foreign(stableKey: $0) }) + owned
        where !orderedNodes.contains(node) {
            orderedNodes.append(node)
        }
    }
}

public struct MenuBarLayoutChange: Equatable, Sendable {
    public enum Kind: Equatable, Sendable { case create, update, remove, move, reorder }
    public let kind: Kind
    public let node: MenuBarLayoutNode
    public let stableKey: String
    public let from: MenuBarSection
    public let to: MenuBarSection

    public init(stableKey: String, from: MenuBarSection, to: MenuBarSection) {
        kind = .move
        node = .foreign(stableKey: stableKey)
        self.stableKey = stableKey
        self.from = from
        self.to = to
    }
}

public struct MenuBarApplyTransaction: Sendable {
    public let baseline: MenuBarLayoutDraft
    public let proposed: MenuBarLayoutDraft
    public let changes: [MenuBarLayoutChange]
}

public struct MenuBarLayoutUndoToken: Codable, Equatable, Sendable {
    public let foreignSections: [String: MenuBarSection]
    public let ownedSnapshot: MenuBarLayoutDraft
}

public struct MenuBarApplyFailure: Codable, Equatable, Sendable {
    public let nodeID: String
    public let reason: String
}

public struct MenuBarApplyResult: Sendable {
    public let successfulNodeIDs: [String]
    public let failures: [MenuBarApplyFailure]
    public let committedDraft: MenuBarLayoutDraft
    public let undoToken: MenuBarLayoutUndoToken
    public var isPartial: Bool { !failures.isEmpty && !successfulNodeIDs.isEmpty }
}

public struct MenuBarWorkspaceEnvelope: Codable, Equatable, Sendable {
    public static let currentVersion = 2
    public var schemaVersion: Int
    public var committed: MenuBarLayoutDraft
    public var draft: MenuBarLayoutDraft
    public var layoutMode: MenuBarLayoutMode
    public var hasCompletedSetup: Bool
    public var revealMigrationVersion: Int

    public init(schemaVersion: Int = Self.currentVersion,
                committed: MenuBarLayoutDraft = .init(), draft: MenuBarLayoutDraft? = nil,
                layoutMode: MenuBarLayoutMode = .onDemand, hasCompletedSetup: Bool = false,
                revealMigrationVersion: Int = 1) {
        self.schemaVersion = schemaVersion
        self.committed = committed
        self.draft = draft ?? committed
        self.layoutMode = layoutMode
        self.hasCompletedSetup = hasCompletedSetup
        self.revealMigrationVersion = revealMigrationVersion
    }
}

@Observable
@MainActor
public final class MenuBarWorkspaceStore {
    public static let shared = MenuBarWorkspaceStore()
    static let defaultsKey = "tonic.menuBarWorkspace.v2"
    static let legacyDefaultsKey = "tonic.menuBarWorkspace.v1"

    private struct LegacyOwnedContent: Codable {
        var spacers: [MenuBarSpacer]
        var groups: [MenuBarItemGroup]
        var customItems: [CustomMenuBarItem]
    }

    public private(set) var envelope: MenuBarWorkspaceEnvelope
    private let defaults: UserDefaults

    public var baseline: [String: MenuBarSection] { envelope.committed.foreignAssignments }
    public var draft: [String: MenuBarSection] { envelope.draft.foreignAssignments }
    public var layoutMode: MenuBarLayoutMode {
        get { envelope.layoutMode }
        set { envelope.layoutMode = newValue; persist() }
    }
    public var hasCompletedSetup: Bool { envelope.hasCompletedSetup }
    public var spacers: [MenuBarSpacer] {
        get { envelope.draft.spacers }
        set { envelope.draft.spacers = newValue; normalizeAndPersist() }
    }
    public var groups: [MenuBarItemGroup] {
        get { envelope.draft.groups }
        set { envelope.draft.groups = newValue; normalizeAndPersist() }
    }
    public var customItems: [CustomMenuBarItem] {
        get { envelope.draft.customItems }
        set { envelope.draft.customItems = newValue; normalizeAndPersist() }
    }

    public var changes: [MenuBarLayoutChange] {
        envelope.draft.foreignAssignments.compactMap { key, target in
            guard let source = envelope.committed.foreignAssignments[key], source != target else { return nil }
            return MenuBarLayoutChange(stableKey: key, from: source, to: target)
        }.sorted { $0.stableKey < $1.stableKey }
    }
    public var isDirty: Bool { envelope.draft != envelope.committed }
    public var stagedChangeCount: Int {
        changes.count
            + symmetricDifferenceCount(envelope.committed.spacers.map(\.id), envelope.draft.spacers.map(\.id))
            + symmetricDifferenceCount(envelope.committed.groups.map(\.id), envelope.draft.groups.map(\.id))
            + symmetricDifferenceCount(envelope.committed.customItems.map(\.id), envelope.draft.customItems.map(\.id))
            + zip(envelope.committed.spacers, envelope.draft.spacers).filter { $0.0 != $0.1 }.count
            + zip(envelope.committed.groups, envelope.draft.groups).filter { $0.0 != $0.1 }.count
            + zip(envelope.committed.customItems, envelope.draft.customItems).filter { $0.0 != $0.1 }.count
    }

    public var changeSummary: String {
        var parts: [String] = []
        if !changes.isEmpty { parts.append("\(changes.count) foreign move\(changes.count == 1 ? "" : "s")") }
        let owned = max(0, stagedChangeCount - changes.count)
        if owned > 0 { parts.append("\(owned) owned-item edit\(owned == 1 ? "" : "s")") }
        return parts.isEmpty ? "No changes" : parts.joined(separator: " · ")
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.defaultsKey),
           let decoded = try? JSONDecoder().decode(MenuBarWorkspaceEnvelope.self, from: data),
           decoded.schemaVersion <= MenuBarWorkspaceEnvelope.currentVersion {
            envelope = decoded
        } else if let data = defaults.data(forKey: Self.legacyDefaultsKey),
                  let legacy = try? JSONDecoder().decode(LegacyOwnedContent.self, from: data) {
            var migrated = MenuBarLayoutDraft(spacers: legacy.spacers, groups: legacy.groups,
                                              customItems: legacy.customItems)
            migrated.normalizeOrder()
            envelope = MenuBarWorkspaceEnvelope(committed: migrated)
        } else {
            envelope = MenuBarWorkspaceEnvelope()
        }
        envelope.draft.normalizeOrder()
        envelope.committed.normalizeOrder()
        migrateRevealMethodsIfNeeded()
        persist()
    }

    public func synchronize(with items: [MenuBarItemInfo], force: Bool = false) {
        guard force || !isDirty else { return }
        // The scanner may observe the same logical status item on more than one
        // display. Stable keys deliberately identify the logical item, so fold
        // duplicate observations instead of asserting that every scan row is
        // unique. Keeping the first observation also prevents display ordering
        // from making a staged section appear to jump between scans.
        let current = items.reduce(into: [String: MenuBarSection]()) { result, item in
            guard result[item.stableKey] == nil, let section = item.section else { return }
            result[item.stableKey] = section
        }
        envelope.committed.foreignAssignments = current
        envelope.draft.foreignAssignments = current
        let observedForeignNodes = items.compactMap { item in
            current[item.stableKey] == nil ? nil : MenuBarLayoutNode.foreign(stableKey: item.stableKey)
        }
        for node in observedForeignNodes {
            if !envelope.committed.orderedNodes.contains(node) { envelope.committed.orderedNodes.append(node) }
            if !envelope.draft.orderedNodes.contains(node) { envelope.draft.orderedNodes.append(node) }
        }
        envelope.committed.normalizeOrder()
        envelope.draft.normalizeOrder()
        persist()
    }

    public func stage(_ item: MenuBarItemInfo, in section: MenuBarSection) {
        guard !item.isSystemControlled else { return }
        if envelope.committed.foreignAssignments[item.stableKey] == nil, let current = item.section {
            envelope.committed.foreignAssignments[item.stableKey] = current
        }
        envelope.draft.foreignAssignments[item.stableKey] = section
        normalizeAndPersist()
    }

    public func section(for item: MenuBarItemInfo) -> MenuBarSection {
        envelope.draft.foreignAssignments[item.stableKey] ?? item.section ?? .visible
    }

    public func discard() { envelope.draft = envelope.committed; persist() }

    public func markApplied() {
        envelope.draft.baselineRevision = UUID()
        envelope.committed = envelope.draft
        persist()
    }

    public func commit(successfulForeignKeys: Set<String>, commitOwnedItems: Bool,
                       failedOwnedNodeIDs: Set<String> = []) {
        for key in successfulForeignKeys {
            if let section = envelope.draft.foreignAssignments[key] {
                envelope.committed.foreignAssignments[key] = section
            }
        }
        if commitOwnedItems {
            envelope.committed.spacers = envelope.draft.spacers
            envelope.committed.groups = envelope.draft.groups
            envelope.committed.customItems = envelope.draft.customItems
            envelope.committed.orderedNodes = envelope.draft.orderedNodes
        } else if !failedOwnedNodeIDs.isEmpty {
            envelope.committed.spacers = mergeOwned(baseline: envelope.committed.spacers,
                proposed: envelope.draft.spacers, failedNodeIDs: failedOwnedNodeIDs) {
                    MenuBarLayoutNode.spacer($0).stableID
                }
            envelope.committed.groups = mergeOwned(baseline: envelope.committed.groups,
                proposed: envelope.draft.groups, failedNodeIDs: failedOwnedNodeIDs) {
                    MenuBarLayoutNode.group($0).stableID
                }
            envelope.committed.customItems = mergeOwned(baseline: envelope.committed.customItems,
                proposed: envelope.draft.customItems, failedNodeIDs: failedOwnedNodeIDs) {
                    MenuBarLayoutNode.customItem($0).stableID
                }
            let failedNodes = Set(envelope.committed.orderedNodes.filter { failedOwnedNodeIDs.contains($0.stableID) })
            envelope.committed.orderedNodes = envelope.draft.orderedNodes.filter { !failedOwnedNodeIDs.contains($0.stableID) }
            for node in failedNodes where !envelope.committed.orderedNodes.contains(node) {
                envelope.committed.orderedNodes.append(node)
            }
            envelope.committed.normalizeOrder()
        }
        envelope.committed.baselineRevision = UUID()
        MenuBarProfileStore.shared.updateGlobalForeignLayout(envelope.committed.foreignAssignments)
        persist()
    }

    public func restore(_ token: MenuBarLayoutUndoToken) {
        envelope.committed = token.ownedSnapshot
        envelope.committed.foreignAssignments = token.foreignSections
        envelope.draft = envelope.committed
        persist()
    }

    public func completeSetup() { envelope.hasCompletedSetup = true; persist() }

    public func makeTransaction() -> MenuBarApplyTransaction {
        MenuBarApplyTransaction(baseline: envelope.committed, proposed: envelope.draft, changes: changes)
    }

    public func addSpacer(_ spacer: MenuBarSpacer = MenuBarSpacer()) {
        envelope.draft.spacers.append(spacer)
        normalizeAndPersist()
    }

    public func addGroup(_ group: MenuBarItemGroup = MenuBarItemGroup(name: "New Group")) {
        envelope.draft.groups.append(group)
        normalizeAndPersist()
    }

    public func saveGroup(_ group: MenuBarItemGroup) {
        if let index = envelope.draft.groups.firstIndex(where: { $0.id == group.id }) {
            envelope.draft.groups[index] = group
        } else { envelope.draft.groups.append(group) }
        normalizeAndPersist()
    }

    public func addCustomItem(_ item: CustomMenuBarItem = CustomMenuBarItem(
        name: "Custom Item", dataSource: .staticLabel("Tonic")
    )) {
        envelope.draft.customItems.append(item)
        normalizeAndPersist()
    }

    public func saveCustomItem(_ item: CustomMenuBarItem) {
        if let index = envelope.draft.customItems.firstIndex(where: { $0.id == item.id }) {
            envelope.draft.customItems[index] = item
        } else {
            envelope.draft.customItems.append(item)
        }
        normalizeAndPersist()
    }

    public func reorder(_ node: MenuBarLayoutNode, before target: MenuBarLayoutNode?) {
        envelope.draft.orderedNodes.removeAll { $0 == node }
        if let target, let index = envelope.draft.orderedNodes.firstIndex(of: target) {
            envelope.draft.orderedNodes.insert(node, at: index)
        } else {
            envelope.draft.orderedNodes.append(node)
        }
        persist()
    }

    public func move(_ node: MenuBarLayoutNode, by offset: Int) {
        guard offset != 0, let source = envelope.draft.orderedNodes.firstIndex(of: node) else { return }
        let destination = min(max(0, source + offset), envelope.draft.orderedNodes.count - 1)
        guard source != destination else { return }
        envelope.draft.orderedNodes.remove(at: source)
        envelope.draft.orderedNodes.insert(node, at: destination)
        persist()
    }

    @discardableResult
    public func stageOwned(_ node: MenuBarLayoutNode, in section: MenuBarSection) -> Bool {
        switch node {
        case .spacer(let id):
            guard let index = envelope.draft.spacers.firstIndex(where: { $0.id == id }) else { return false }
            envelope.draft.spacers[index].section = section
        case .customItem(let id):
            guard let index = envelope.draft.customItems.firstIndex(where: { $0.id == id }) else { return false }
            envelope.draft.customItems[index].section = section
        case .group:
            guard section == .visible else { return false }
        case .foreign:
            return false
        }
        normalizeAndPersist()
        return true
    }

    private func normalizeAndPersist() { envelope.draft.normalizeOrder(); persist() }

    private func symmetricDifferenceCount<T: Hashable>(_ lhs: [T], _ rhs: [T]) -> Int {
        Set(lhs).symmetricDifference(Set(rhs)).count
    }

    private func mergeOwned<Value: Identifiable>(baseline: [Value], proposed: [Value],
                                                   failedNodeIDs: Set<String>,
                                                   nodeID: (Value.ID) -> String) -> [Value] {
        let successful = proposed.filter { !failedNodeIDs.contains(nodeID($0.id)) }
        let failedBaseline = baseline.filter { failedNodeIDs.contains(nodeID($0.id)) }
        return successful + failedBaseline.filter { old in !successful.contains(where: { $0.id == old.id }) }
    }

    private func migrateRevealMethodsIfNeeded() {
        guard envelope.revealMigrationVersion < 2 else { return }
        let key = "tonic.menuBarManager"
        let settings: MenuBarManagerSettings
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode(MenuBarManagerSettings.self, from: data) {
            var migrated = decoded
            migrated.showOnHover = true
            migrated.showOnClickEmptyMenuBar = true
            migrated.showOnScroll = true
            settings = migrated
        } else {
            settings = .default
        }
        if let data = try? JSONEncoder().encode(settings) { defaults.set(data, forKey: key) }
        envelope.revealMigrationVersion = 2
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(envelope) {
            defaults.set(data, forKey: Self.defaultsKey)
        }
    }
}
