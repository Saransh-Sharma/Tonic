//
//  WidgetStore.swift
//  Tonic
//
//  Widget configuration store following Stats Master's Store pattern
//  Provides UserDefaults persistence with in-memory cache and legacy migration
//  Task ID: fn-5-v8r.3
//

import Foundation

/// Widget configuration store following Stats Master's Store pattern
/// Provides UserDefaults persistence with in-memory cache and legacy migration
@Observable
@MainActor
final class WidgetStore {
    static let shared = WidgetStore()

    // MARK: - Properties

    private let defaults = UserDefaults.standard
    private var cache: [String: WidgetConfiguration] = [:]

    private enum Keys {
        static let configs = "tonic.widget.store.configs"
        static let migrationVersion = "tonic.widget.store.migrationVersion"
        static let currentMigrationVersion = 2

        // Legacy key for migration
        static let legacyConfigs = "tonic.widget.configs"
    }

    // MARK: - Initialization

    private init() {
        migrateLegacyConfig()
        _ = loadAllConfigs()
    }

    // MARK: - Public API

    /// Save a widget configuration
    func saveConfig(_ config: WidgetConfiguration) {
        let updatedConfig = config
        cache[config.id.uuidString] = updatedConfig

        let allConfigs = Array(cache.values)
            .sorted { $0.position < $1.position }

        if let encoded = try? JSONEncoder().encode(allConfigs) {
            defaults.set(encoded, forKey: Keys.configs)
        }
    }

    /// Load a specific configuration by ID
    func loadConfig(id: UUID) -> WidgetConfiguration? {
        // Check cache first
        if let cached = cache[id.uuidString] {
            return cached
        }

        // Cache miss - load from UserDefaults
        guard let data = defaults.data(forKey: Keys.configs),
              let configs = try? JSONDecoder().decode([WidgetConfiguration].self, from: data) else {
            return nil
        }

        // Update cache
        configs.forEach { cache[$0.id.uuidString] = $0 }

        return cache[id.uuidString]
    }

    /// Load all configurations
    func loadAllConfigs() -> [WidgetConfiguration] {
        if let data = defaults.data(forKey: Keys.configs),
           let configs = try? JSONDecoder().decode([WidgetConfiguration].self, from: data) {
            // Update cache
            configs.forEach { cache[$0.id.uuidString] = $0 }
            return configs.sorted { $0.position < $1.position }
        }

        return []
    }

    /// Delete a configuration
    func deleteConfig(id: UUID) {
        cache.removeValue(forKey: id.uuidString)

        var remainingConfigs = Array(cache.values)
            .sorted { $0.position < $1.position }

        // Update positions after deletion
        for index in remainingConfigs.indices {
            remainingConfigs[index].position = index
        }

        if let encoded = try? JSONEncoder().encode(remainingConfigs) {
            defaults.set(encoded, forKey: Keys.configs)
        }
    }

    /// Clear all configurations and reset to defaults
    func resetToDefaults() {
        cache.removeAll()
        defaults.removeObject(forKey: Keys.configs)
        defaults.removeObject(forKey: Keys.migrationVersion)

        // Re-run migration to set up defaults
        migrateLegacyConfig()
        _ = loadAllConfigs()
    }

    // MARK: - Migration

    /// Migrate legacy configuration from WidgetPreferences
    private func migrateLegacyConfig() {
        let currentVersion = defaults.integer(forKey: Keys.migrationVersion)
        guard currentVersion < Keys.currentMigrationVersion else {
            return  // Already migrated
        }

        // Try to load legacy WidgetPreferences configs
        guard let data = defaults.data(forKey: Keys.legacyConfigs) else {
            // No legacy data - mark as migrated
            defaults.set(Keys.currentMigrationVersion, forKey: Keys.migrationVersion)
            return
        }

        do {
            // Try current format first
            if let configs = try? JSONDecoder().decode([WidgetConfiguration].self, from: data) {
                // Already in current format - just update migration version
                defaults.set(Keys.currentMigrationVersion, forKey: Keys.migrationVersion)

                // Cache the configs
                configs.forEach { cache[$0.id.uuidString] = $0 }
                return
            }

            // Try legacy format with accentColor migration
            struct LegacyConfig: Codable {
                let id: UUID
                let type: WidgetType
                let isEnabled: Bool
                let position: Int
                let displayMode: WidgetDisplayMode
                let showLabel: Bool
                let valueFormat: WidgetValueFormat
                let refreshInterval: WidgetUpdateInterval
                // accentColor may be missing in legacy format
                private enum CodingKeys: String, CodingKey {
                    case id, type, isEnabled, position, displayMode
                    case showLabel, valueFormat, refreshInterval
                }
            }

            let legacyConfigs = try JSONDecoder().decode([LegacyConfig].self, from: data)

            // Migrate to current format with default accentColor
            let migratedConfigs = legacyConfigs.map { legacy -> WidgetConfiguration in
                WidgetConfiguration(
                    id: legacy.id,
                    type: legacy.type,
                    isEnabled: legacy.isEnabled,
                    position: legacy.position,
                    displayMode: legacy.displayMode,
                    showLabel: legacy.showLabel,
                    valueFormat: legacy.valueFormat,
                    refreshInterval: legacy.refreshInterval,
                    accentColor: .system  // New field with default value
                )
            }

            // Save migrated configs
            if let encoded = try? JSONEncoder().encode(migratedConfigs) {
                defaults.set(encoded, forKey: Keys.configs)
                defaults.set(Keys.currentMigrationVersion, forKey: Keys.migrationVersion)

                // Cache the migrated configs
                migratedConfigs.forEach { cache[$0.id.uuidString] = $0 }
            }
        } catch {
            // Migration failed - log error and continue with defaults
            print("Warning: Failed to migrate legacy widget configs: \(error)")
            defaults.set(Keys.currentMigrationVersion, forKey: Keys.migrationVersion)
        }
    }

    // MARK: - Convenience Methods

    /// Get configuration for a specific widget type
    func config(for type: WidgetType) -> WidgetConfiguration? {
        return loadAllConfigs().first { $0.type == type }
    }

    /// Update configuration for a specific widget type
    func updateConfig(for type: WidgetType, _ update: (inout WidgetConfiguration) -> Void) {
        var allConfigs = loadAllConfigs()
        if let index = allConfigs.firstIndex(where: { $0.type == type }) {
            update(&allConfigs[index])
            saveConfig(allConfigs[index])
        }
    }

    /// Get enabled widgets sorted by position
    var enabledWidgets: [WidgetConfiguration] {
        return loadAllConfigs()
            .filter { $0.isEnabled }
            .sorted { $0.position < $1.position }
    }
}
