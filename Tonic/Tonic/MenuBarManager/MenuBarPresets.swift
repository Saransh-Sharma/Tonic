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

    public init(id: UUID = UUID(), name: String, symbolName: String = "rectangle.stack",
                layout: [String: MenuBarSection]) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.layout = layout
    }
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
            presets = []
        }
    }

    /// Snapshot the current section of every discovered item into a new preset.
    public func captureCurrent(name: String, symbolName: String = "rectangle.stack",
                               items: [MenuBarItemInfo]) -> MenuBarPreset {
        var layout: [String: MenuBarSection] = [:]
        for item in items where !item.isSystemControlled {
            if let section = item.section {
                layout[item.stableKey] = section
            }
        }
        let preset = MenuBarPreset(name: name, symbolName: symbolName, layout: layout)
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
