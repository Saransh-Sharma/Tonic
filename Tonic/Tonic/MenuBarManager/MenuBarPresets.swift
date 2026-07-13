//
//  MenuBarPresets.swift
//  Tonic
//
//  Named menu bar layouts (work / home / recording). A preset records which
//  section each item belongs in, keyed by stableKey so it survives relaunches.
//

import Foundation

public struct MenuBarPreset: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var symbolName: String
    /// stableKey → section. Items absent from the map are left where they are.
    public var layout: [String: MenuBarSection]
    public var groups: [MenuBarItemGroup]
    public var capturesLayout: Bool
    public var capturesGroups: Bool
    public var appearance: MenuBarStyling?
    public var revealBehavior: MenuBarRevealBehaviorSnapshot?

    public init(id: UUID = UUID(), name: String, symbolName: String = "rectangle.stack",
                layout: [String: MenuBarSection], groups: [MenuBarItemGroup] = [],
                capturesLayout: Bool = true, capturesGroups: Bool = true,
                appearance: MenuBarStyling? = nil, revealBehavior: MenuBarRevealBehaviorSnapshot? = nil) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.layout = layout
        self.groups = groups
        self.capturesLayout = capturesLayout
        self.capturesGroups = capturesGroups
        self.appearance = appearance
        self.revealBehavior = revealBehavior
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, symbolName, layout, groups, capturesLayout, capturesGroups, appearance, revealBehavior
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID(),
                  name: try container.decode(String.self, forKey: .name),
                  symbolName: try container.decodeIfPresent(String.self, forKey: .symbolName) ?? "rectangle.stack",
                  layout: try container.decodeIfPresent([String: MenuBarSection].self, forKey: .layout) ?? [:],
                  groups: try container.decodeIfPresent([MenuBarItemGroup].self, forKey: .groups) ?? [],
                  capturesLayout: try container.decodeIfPresent(Bool.self, forKey: .capturesLayout) ?? true,
                  capturesGroups: try container.decodeIfPresent(Bool.self, forKey: .capturesGroups) ?? true,
                  appearance: try container.decodeIfPresent(MenuBarStyling.self, forKey: .appearance),
                  revealBehavior: try container.decodeIfPresent(MenuBarRevealBehaviorSnapshot.self, forKey: .revealBehavior))
    }
}

public struct MenuBarRevealBehaviorSnapshot: Codable, Equatable, Sendable {
    public var showOnHover: Bool
    public var showOnClickEmptyMenuBar: Bool
    public var showOnScroll: Bool
    public var autoRehide: Bool
    public var quickShelfPresentation: QuickShelfPresentation
}

public enum MenuBarPresetPlanner {
    /// Only the keys whose current section differs from the target — the moves
    /// a preset apply actually needs to perform.
    public static func layoutDiff(
        current: [String: MenuBarSection],
        target: [String: MenuBarSection]
    ) -> [String: MenuBarSection] {
        var diff: [String: MenuBarSection] = [:]
        for (key, section) in target where current[key] != section {
            diff[key] = section
        }
        return diff
    }
}

@MainActor
public enum MenuBarPresetApplicator {
    @discardableResult
    public static func apply(_ preset: MenuBarPreset, manager: MenuBarManager = .shared) async -> Bool {
        let workspace = MenuBarWorkspaceStore.shared
        if preset.capturesGroups {
            workspace.groups = preset.groups
            let failures = MenuBarOwnedItemCoordinator.shared.apply(workspace.envelope.draft)
            workspace.commit(successfulForeignKeys: [], commitOwnedItems: failures.isEmpty)
        }
        var settings = MenuBarManagerSettingsStore.shared.settings
        if let appearance = preset.appearance { settings.styling = appearance }
        if let reveal = preset.revealBehavior {
            settings.showOnHover = reveal.showOnHover
            settings.showOnClickEmptyMenuBar = reveal.showOnClickEmptyMenuBar
            settings.showOnScroll = reveal.showOnScroll
            settings.autoRehide = reveal.autoRehide
            settings.quickShelfPresentation = reveal.quickShelfPresentation
        }
        MenuBarManagerSettingsStore.shared.settings = settings
        guard preset.capturesLayout, !preset.layout.isEmpty else { return true }
        guard MenuBarCapabilities.current.canMoveForeignItems else { return true }
        return await manager.applyLayout(preset.layout)
    }
}

@Observable
public final class MenuBarPresetStore: @unchecked Sendable {
    public static let shared = MenuBarPresetStore()
    private static let defaultsKey = "tonic.menuBarPresets"

    public private(set) var presets: [MenuBarPreset] {
        didSet { persist() }
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
           let decoded = try? JSONDecoder().decode([MenuBarPreset].self, from: data) {
            presets = decoded
        } else {
            presets = [
                MenuBarPreset(name: "Focus", symbolName: "scope", layout: [:]),
                MenuBarPreset(name: "Everyday", symbolName: "sun.max", layout: [:]),
                MenuBarPreset(name: "Everything Visible", symbolName: "eye", layout: [:])
            ]
        }
    }

    /// Snapshot the current section of every discovered item into a new preset.
    @MainActor
    public func captureCurrent(name: String, symbolName: String = "rectangle.stack",
                               items: [MenuBarItemInfo], capturesLayout: Bool = true,
                               capturesGroups: Bool = true, capturesAppearance: Bool = false,
                               capturesRevealBehavior: Bool = false) -> MenuBarPreset {
        var layout: [String: MenuBarSection] = [:]
        for item in items where !item.isSystemControlled {
            if let section = item.section {
                layout[item.stableKey] = section
            }
        }
        let settings = MenuBarManagerSettingsStore.shared.settings
        let preset = MenuBarPreset(name: name, symbolName: symbolName,
            layout: capturesLayout ? layout : [:],
            groups: capturesGroups ? MenuBarWorkspaceStore.shared.envelope.committed.groups : [],
            capturesLayout: capturesLayout, capturesGroups: capturesGroups,
            appearance: capturesAppearance ? settings.styling : nil,
            revealBehavior: capturesRevealBehavior ? MenuBarRevealBehaviorSnapshot(showOnHover: settings.showOnHover,
                showOnClickEmptyMenuBar: settings.showOnClickEmptyMenuBar, showOnScroll: settings.showOnScroll,
                autoRehide: settings.autoRehide, quickShelfPresentation: settings.quickShelfPresentation) : nil)
        presets.append(preset)
        return preset
    }

    public func add(_ preset: MenuBarPreset) {
        presets.append(preset)
    }

    public func update(_ preset: MenuBarPreset) {
        guard let index = presets.firstIndex(where: { $0.id == preset.id }) else { return }
        presets[index] = preset
    }

    public func rename(_ preset: MenuBarPreset, to name: String) {
        guard let index = presets.firstIndex(where: { $0.id == preset.id }) else { return }
        presets[index].name = name
    }

    public func delete(_ preset: MenuBarPreset) {
        presets.removeAll { $0.id == preset.id }
    }

    public func duplicate(_ preset: MenuBarPreset) {
        var copy = preset
        copy.id = UUID()
        copy.name = "\(preset.name) Copy"
        presets.append(copy)
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }
}
