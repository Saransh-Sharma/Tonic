//
//  WidgetConfiguration.swift
//  Tonic
//
//  Menu bar widget configuration data models
//  Task ID: fn-2.1
//

import SwiftUI

// MARK: - Notifications

extension Notification.Name {
    /// Posted when widget configuration changes
    /// UserInfo contains: "widgetType" -> WidgetType
    static let widgetConfigurationDidUpdate = Notification.Name("tonic.widgetConfigurationDidUpdate")
}

// MARK: - Widget Type

/// Widget types available in the menu bar monitoring system
public enum WidgetType: String, CaseIterable, Identifiable, Codable {
    case cpu = "cpu"
    case gpu = "gpu"
    case memory = "memory"
    case disk = "disk"
    case network = "network"
    case weather = "weather"
    case battery = "battery"
    case sensors = "sensors"
    case bluetooth = "bluetooth"
    case clock = "clock"

    public var id: String { rawValue }

    /// Display name for the widget
    public var displayName: String {
        switch self {
        case .cpu: return "CPU"
        case .gpu: return "GPU"
        case .memory: return "Memory"
        case .disk: return "Disk"
        case .network: return "Network"
        case .weather: return "Weather"
        case .battery: return "Battery"
        case .sensors: return "Sensors"
        case .bluetooth: return "Bluetooth"
        case .clock: return "Clock"
        }
    }

    /// SF Symbol icon for the widget
    public var icon: String {
        switch self {
        case .cpu: return "cpu"
        case .gpu: return "cpu.fill" // Will use GPU-specific icon in view
        case .memory: return "memorychip"
        case .disk: return "internaldrive"
        case .network: return "wifi"
        case .weather: return "cloud.sun"
        case .battery: return "battery.100"
        case .sensors: return "thermometer"
        case .bluetooth: return "wave.3.right"
        case .clock: return "clock"
        }
    }

    /// Whether this widget is platform-specific (auto-hide on certain Macs)
    public var isPlatformSpecific: Bool {
        switch self {
        case .gpu: return true // Apple Silicon only
        case .battery: return true // Portable Macs only
        case .sensors: return true // Depends on SMC availability
        case .bluetooth: return true // Depends on Bluetooth availability
        default: return false
        }
    }
}

// MARK: - Widget Display Mode

/// Display mode options for each widget
public enum WidgetDisplayMode: String, CaseIterable, Identifiable, Codable {
    case compact = "compact"
    case detailed = "detailed"

    public var id: String { rawValue }

    /// Display name for the mode
    public var displayName: String {
        switch self {
        case .compact: return "Compact"
        case .detailed: return "Detailed"
        }
    }

    /// Short label for tags
    public var shortLabel: String {
        switch self {
        case .compact: return "Compact"
        case .detailed: return "Detailed"
        }
    }

    /// Approximate width in points for this mode
    public var estimatedWidth: CGFloat {
        switch self {
        case .compact: return 70
        case .detailed: return 130
        }
    }
}

// MARK: - Widget Value Format

/// How to display the value (percentage vs absolute with unit)
public enum WidgetValueFormat: String, CaseIterable, Identifiable, Codable {
    case percentage = "percentage"
    case valueWithUnit = "valueWithUnit"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .percentage: return "Percentage (%)"
        case .valueWithUnit: return "Value with Unit"
        }
    }

    public var shortLabel: String {
        switch self {
        case .percentage: return "%"
        case .valueWithUnit: return "Value"
        }
    }
}

// MARK: - Widget Accent Color

/// Color options for widgets (30+ options matching Stats Master PRD)
/// Categories: automatic, system, primary, secondary, grays, special
public enum WidgetAccentColor: String, CaseIterable, Identifiable, Codable, Sendable {
    // MARK: Automatic Colors (Calculated)
    case system = "system"              // Auto - default color per widget type
    case utilization = "utilization"    // Based on utilization (green->yellow->orange->red)
    case pressure = "pressure"          // Based on memory pressure
    case cluster = "cluster"            // Based on CPU cluster (E/P cores)

    // MARK: System Colors
    case systemAccent = "systemAccent"  // macOS accent color
    case monochrome = "monochrome"      // Adapts to light/dark mode

    // MARK: Primary Colors
    case red = "red"
    case green = "green"
    case blue = "blue"
    case yellow = "yellow"
    case orange = "orange"
    case purple = "purple"
    case brown = "brown"
    case cyan = "cyan"
    case magenta = "magenta"
    case pink = "pink"
    case teal = "teal"
    case indigo = "indigo"

    // MARK: Secondary Colors (System variants)
    case secondRed = "secondRed"
    case secondGreen = "secondGreen"
    case secondBlue = "secondBlue"
    case secondYellow = "secondYellow"
    case secondOrange = "secondOrange"
    case secondPurple = "secondPurple"
    case secondBrown = "secondBrown"

    // MARK: Gray Colors
    case gray = "gray"
    case secondGray = "secondGray"
    case darkGray = "darkGray"
    case lightGray = "lightGray"

    // MARK: Special Colors
    case white = "white"
    case black = "black"
    case clear = "clear"

    public var id: String { rawValue }

    /// Display name for the color
    public var displayName: String {
        switch self {
        // Automatic
        case .system: return "Auto"
        case .utilization: return "Based on utilization"
        case .pressure: return "Based on pressure"
        case .cluster: return "Based on cluster"
        // System
        case .systemAccent: return "System accent"
        case .monochrome: return "Monochrome"
        // Primary
        case .red: return "Red"
        case .green: return "Green"
        case .blue: return "Blue"
        case .yellow: return "Yellow"
        case .orange: return "Orange"
        case .purple: return "Purple"
        case .brown: return "Brown"
        case .cyan: return "Cyan"
        case .magenta: return "Magenta"
        case .pink: return "Pink"
        case .teal: return "Teal"
        case .indigo: return "Indigo"
        // Secondary
        case .secondRed: return "Second red"
        case .secondGreen: return "Second green"
        case .secondBlue: return "Second blue"
        case .secondYellow: return "Second yellow"
        case .secondOrange: return "Second orange"
        case .secondPurple: return "Second purple"
        case .secondBrown: return "Second brown"
        // Grays
        case .gray: return "Gray"
        case .secondGray: return "Second gray"
        case .darkGray: return "Dark gray"
        case .lightGray: return "Light gray"
        // Special
        case .white: return "White"
        case .black: return "Black"
        case .clear: return "Clear"
        }
    }

    /// Whether this color is automatic (calculated from values)
    public var isAutomatic: Bool {
        switch self {
        case .system, .utilization, .pressure, .cluster:
            return true
        default:
            return false
        }
    }

    /// The NSColor value for this color option (for fixed colors)
    public var nsColor: NSColor? {
        switch self {
        // Automatic colors return nil (need value to calculate)
        case .system, .utilization, .pressure, .cluster:
            return nil
        // System
        case .systemAccent: return .controlAccentColor
        case .monochrome: return .textColor
        // Primary
        case .red: return .red
        case .green: return .green
        case .blue: return .blue
        case .yellow: return .yellow
        case .orange: return .orange
        case .purple: return .purple
        case .brown: return .brown
        case .cyan: return .cyan
        case .magenta: return .magenta
        case .pink: return .systemPink
        case .teal: return .systemTeal
        case .indigo: return .systemIndigo
        // Secondary
        case .secondRed: return .systemRed
        case .secondGreen: return .systemGreen
        case .secondBlue: return .systemBlue
        case .secondYellow: return .systemYellow
        case .secondOrange: return .systemOrange
        case .secondPurple: return .systemPurple
        case .secondBrown: return .systemBrown
        // Grays
        case .gray: return .gray
        case .secondGray: return .systemGray
        case .darkGray: return .darkGray
        case .lightGray: return .lightGray
        // Special
        case .white: return .white
        case .black: return .black
        case .clear: return .clear
        }
    }

    /// The actual Color value (for fixed colors, uses system default for automatic)
    public func colorValue(for widgetType: WidgetType) -> Color {
        switch self {
        case .system:
            // Return default color for each widget type when in Auto mode
            return defaultColor(for: widgetType)
        case .utilization, .pressure, .cluster:
            // These need a value to calculate - return system accent as fallback
            return Color(nsColor: .controlAccentColor)
        default:
            if let nsColor = nsColor {
                return Color(nsColor: nsColor)
            }
            return defaultColor(for: widgetType)
        }
    }

    /// Calculate color based on a utilization value (0-100%)
    /// For .utilization color mode
    public func colorValue(forUtilization percentage: Double) -> Color {
        switch self {
        case .utilization:
            return UtilizationColorHelper.color(forPercentage: percentage)
        default:
            if let nsColor = nsColor {
                return Color(nsColor: nsColor)
            }
            return Color(nsColor: .controlAccentColor)
        }
    }

    /// Calculate NSColor based on a utilization value (0-100%)
    public func nsColorValue(forUtilization percentage: Double) -> NSColor {
        switch self {
        case .utilization:
            return UtilizationColorHelper.nsColor(forPercentage: percentage)
        default:
            return nsColor ?? .controlAccentColor
        }
    }

    /// Calculate color based on memory pressure
    public func colorValue(forPressure pressure: MemoryPressureLevel) -> Color {
        switch self {
        case .pressure:
            return WidgetColorPalette.pressureColor(for: pressure)
        default:
            if let nsColor = nsColor {
                return Color(nsColor: nsColor)
            }
            return Color(nsColor: .controlAccentColor)
        }
    }

    /// Calculate color for CPU cluster (E-core vs P-core)
    public func colorValue(isEfficiencyCore: Bool) -> Color {
        switch self {
        case .cluster:
            return isEfficiencyCore
                ? WidgetColorPalette.ClusterColor.eCores
                : WidgetColorPalette.ClusterColor.pCores
        default:
            if let nsColor = nsColor {
                return Color(nsColor: nsColor)
            }
            return Color(nsColor: .controlAccentColor)
        }
    }

    /// Default color for each widget type when in Auto mode
    private func defaultColor(for widgetType: WidgetType) -> Color {
        switch widgetType {
        case .cpu: return Color(nsColor: .systemBlue)
        case .memory: return Color(nsColor: .systemGreen)
        case .disk: return Color(nsColor: .systemOrange)
        case .network: return Color(nsColor: .systemCyan)
        case .gpu: return Color(nsColor: .systemPurple)
        case .battery: return Color(nsColor: .systemGreen)
        case .weather: return Color(nsColor: .systemYellow)
        case .sensors: return Color(nsColor: .systemOrange)
        case .bluetooth: return Color(nsColor: .systemBlue)
        case .clock: return Color(nsColor: .systemPurple)
        }
    }

    // MARK: - Color Categories for Picker

    /// All fixed colors (excluding automatic ones)
    public static var fixedColors: [WidgetAccentColor] {
        allCases.filter { !$0.isAutomatic }
    }

    /// Automatic color options
    public static var automaticColors: [WidgetAccentColor] {
        [.system, .utilization, .pressure, .cluster]
    }

    /// System colors
    public static var systemColors: [WidgetAccentColor] {
        [.systemAccent, .monochrome]
    }

    /// Primary colors
    public static var primaryColors: [WidgetAccentColor] {
        [.red, .green, .blue, .yellow, .orange, .purple, .brown, .cyan, .magenta, .pink, .teal, .indigo]
    }

    /// Secondary colors
    public static var secondaryColors: [WidgetAccentColor] {
        [.secondRed, .secondGreen, .secondBlue, .secondYellow, .secondOrange, .secondPurple, .secondBrown]
    }

    /// Gray colors
    public static var grayColors: [WidgetAccentColor] {
        [.gray, .secondGray, .darkGray, .lightGray]
    }

    /// Special colors
    public static var specialColors: [WidgetAccentColor] {
        [.white, .black, .clear]
    }
}

// MARK: - Module Settings

/// Per-module settings for widget-specific configuration options
/// Based on Stats Master's module settings pattern
public struct ModuleSettings: Codable, Sendable, Equatable {
    public var cpu: CPUModuleSettings
    public var disk: DiskModuleSettings
    public var network: NetworkModuleSettings
    public var memory: MemoryModuleSettings
    public var sensors: SensorsModuleSettings
    public var battery: BatteryModuleSettings

    /// Default module settings
    public static let `default` = ModuleSettings()

    public init(
        cpu: CPUModuleSettings = CPUModuleSettings(),
        disk: DiskModuleSettings = DiskModuleSettings(),
        network: NetworkModuleSettings = NetworkModuleSettings(),
        memory: MemoryModuleSettings = MemoryModuleSettings(),
        sensors: SensorsModuleSettings = SensorsModuleSettings(),
        battery: BatteryModuleSettings = BatteryModuleSettings()
    ) {
        self.cpu = cpu
        self.disk = disk
        self.network = network
        self.memory = memory
        self.sensors = sensors
        self.battery = battery
    }

    /// Convenience initializer with default values
    public init() {
        self.cpu = CPUModuleSettings()
        self.disk = DiskModuleSettings()
        self.network = NetworkModuleSettings()
        self.memory = MemoryModuleSettings()
        self.sensors = SensorsModuleSettings()
        self.battery = BatteryModuleSettings()
    }
}

// MARK: - CPU Module Settings

public struct CPUModuleSettings: Codable, Sendable, Equatable {
    public var showEPCores: Bool
    public var showFrequency: Bool
    public var showTemperature: Bool
    public var showLoadAverage: Bool

    public init(
        showEPCores: Bool = false,
        showFrequency: Bool = false,
        showTemperature: Bool = true,
        showLoadAverage: Bool = true
    ) {
        self.showEPCores = showEPCores
        self.showFrequency = showFrequency
        self.showTemperature = showTemperature
        self.showLoadAverage = showLoadAverage
    }
}

// MARK: - Disk Module Settings

public struct DiskModuleSettings: Codable, Sendable, Equatable {
    public var selectedVolume: String
    public var showSMART: Bool

    public init(
        selectedVolume: String = "Auto",
        showSMART: Bool = true
    ) {
        self.selectedVolume = selectedVolume
        self.showSMART = showSMART
    }
}

// MARK: - Network Module Settings

public struct NetworkModuleSettings: Codable, Sendable, Equatable {
    public var selectedInterface: String
    public var showPublicIP: Bool
    public var showWiFiDetails: Bool

    public init(
        selectedInterface: String = "Auto",
        showPublicIP: Bool = false,
        showWiFiDetails: Bool = true
    ) {
        self.selectedInterface = selectedInterface
        self.showPublicIP = showPublicIP
        self.showWiFiDetails = showWiFiDetails
    }
}

// MARK: - Memory Module Settings

public struct MemoryModuleSettings: Codable, Sendable, Equatable {
    public var showCache: Bool
    public var showWired: Bool

    public init(
        showCache: Bool = true,
        showWired: Bool = true
    ) {
        self.showCache = showCache
        self.showWired = showWired
    }
}

// MARK: - Sensors Module Settings

public struct SensorsModuleSettings: Codable, Sendable, Equatable {
    public var showFanSpeeds: Bool

    public init(
        showFanSpeeds: Bool = true
    ) {
        self.showFanSpeeds = showFanSpeeds
    }
}

// MARK: - Battery Module Settings

public struct BatteryModuleSettings: Codable, Sendable, Equatable {
    public var showOptimizedCharging: Bool
    public var showCycleCount: Bool

    public init(
        showOptimizedCharging: Bool = true,
        showCycleCount: Bool = true
    ) {
        self.showOptimizedCharging = showOptimizedCharging
        self.showCycleCount = showCycleCount
    }
}

// MARK: - Widget Configuration

/// Configuration for a single menu bar widget
public struct WidgetConfiguration: Codable, Identifiable, Sendable {
    public let id: UUID
    public var type: WidgetType
    public var visualizationType: VisualizationType
    public var isEnabled: Bool
    public var position: Int
    public var displayMode: WidgetDisplayMode
    public var showLabel: Bool
    public var valueFormat: WidgetValueFormat
    public var refreshInterval: WidgetUpdateInterval
    public var accentColor: WidgetAccentColor
    public var chartConfig: ChartConfiguration?
    public var moduleSettings: ModuleSettings

    public init(
        id: UUID = UUID(),
        type: WidgetType,
        visualizationType: VisualizationType? = nil,
        isEnabled: Bool = true,
        position: Int,
        displayMode: WidgetDisplayMode,
        showLabel: Bool = false,
        valueFormat: WidgetValueFormat = .percentage,
        refreshInterval: WidgetUpdateInterval = .balanced,
        accentColor: WidgetAccentColor = .system,
        chartConfig: ChartConfiguration? = nil,
        moduleSettings: ModuleSettings = ModuleSettings.default
    ) {
        self.id = id
        self.type = type
        self.visualizationType = visualizationType ?? type.defaultVisualization
        self.isEnabled = isEnabled
        self.position = position
        self.displayMode = displayMode
        self.showLabel = showLabel
        self.valueFormat = valueFormat
        self.refreshInterval = refreshInterval
        self.accentColor = accentColor
        self.chartConfig = chartConfig
        self.moduleSettings = moduleSettings
    }

    /// Default configuration for a given widget type
    public static func `default`(for type: WidgetType, at position: Int) -> WidgetConfiguration {
        WidgetConfiguration(
            type: type,
            visualizationType: type.defaultVisualization,
            isEnabled: type.isDefaultEnabled,
            position: position,
            displayMode: .compact,
            showLabel: false,
            valueFormat: type.defaultValueFormat,
            refreshInterval: .balanced,
            accentColor: .system,
            chartConfig: nil as ChartConfiguration?,
            moduleSettings: ModuleSettings.default
        )
    }
}

extension WidgetType {
    /// Default value format for this widget type
    var defaultValueFormat: WidgetValueFormat {
        switch self {
        case .cpu, .memory, .gpu, .battery:
            return .percentage
        case .disk, .network:
            return .valueWithUnit
        case .weather, .sensors, .bluetooth, .clock:
            return .valueWithUnit
        }
    }
}

extension WidgetType {
    /// Whether this widget should be enabled by default
    var isDefaultEnabled: Bool {
        switch self {
        case .cpu, .memory, .disk: return true
        case .gpu, .network, .weather, .battery, .sensors, .bluetooth, .clock: return false
        }
    }
}

// MARK: - Widget Update Interval

/// Update interval presets based on power mode
public enum WidgetUpdateInterval: String, CaseIterable, Identifiable, Codable {
    case power = "power"       // 5 seconds - power saving
    case balanced = "balanced" // 2 seconds - default
    case performance = "performance" // 1 second - high refresh

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .power: return "Power Saving (5s)"
        case .balanced: return "Balanced (2s)"
        case .performance: return "Performance (1s)"
        }
    }

    /// The time interval in seconds
    public var timeInterval: TimeInterval {
        switch self {
        case .power: return 5.0
        case .balanced: return 2.0
        case .performance: return 1.0
        }
    }
}

// MARK: - Widget Preferences

/// Global preferences for menu bar widgets
@MainActor
@Observable
public final class WidgetPreferences: Sendable {
    public static let shared = WidgetPreferences()

    // MARK: - Migration Version

    /// Current migration version - increment when config structure changes
    private static let currentMigrationVersion = 3

    // MARK: - Properties

    /// Configuration for all available widgets
    public var widgetConfigs: [WidgetConfiguration]

    /// Global update interval preset
    public var updateInterval: WidgetUpdateInterval

    /// Whether widget system has been onboarded
    public var hasCompletedOnboarding: Bool

    /// Whether to use unified menu bar mode (OneView) instead of individual widgets
    public var unifiedMenuBarMode: Bool

    /// Global temperature unit preference for all widgets (CPU, GPU, Sensors, Battery)
    public var temperatureUnit: TemperatureUnit

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let widgetConfigs = "tonic.widget.configs"
        static let updateInterval = "tonic.widget.updateInterval"
        static let hasCompletedOnboarding = "tonic.widget.hasCompletedOnboarding"
        static let unifiedMenuBarMode = "tonic.widget.unifiedMenuBarMode"
        static let temperatureUnit = "tonic.widget.temperatureUnit"
        static let migrationVersion = "tonic.widget.migrationVersion"
        static let backupConfigs = "tonic.widget.configs.backup"
        static let backupTimestamp = "tonic.widget.configs.backupTimestamp"
    }

    // MARK: - Initialization

    private init() {
        self.updateInterval = .balanced
        self.hasCompletedOnboarding = false
        self.unifiedMenuBarMode = false
        self.temperatureUnit = .celsius

        // Run migration first, before loading configs
        Self.migrateIfNeeded()

        // Load configs (may have been updated by migration)
        self.widgetConfigs = Self.loadConfigsFromUserDefaults() ?? Self.defaultConfigs()

        // Load other preferences
        loadFromUserDefaults()
    }

    // MARK: - Default Configuration

    /// Create default widget configurations
    private static func defaultConfigs() -> [WidgetConfiguration] {
        let allTypes: [WidgetType] = [
            .cpu, .gpu, .memory, .disk, .network, .weather, .battery, .sensors, .bluetooth, .clock
        ]

        return allTypes.enumerated().map { index, type in
            WidgetConfiguration.default(for: type, at: index)
        }
    }

    // MARK: - Migration

    /// Check if migration is needed and perform it if necessary
    /// This is called during init before loading configs
    private static func migrateIfNeeded() {
        let currentVersion = UserDefaults.standard.integer(forKey: Keys.migrationVersion)

        // No migration needed if already on current version
        guard currentVersion < currentMigrationVersion else {
            return
        }

        #if DEBUG
        print("[WidgetPreferences] Migration needed: version \(currentVersion) -> \(currentMigrationVersion)")
        #endif

        // Create backup before migration
        backupConfigs()

        // Perform migration based on current version
        do {
            let migratedConfigs = try performMigration(from: currentVersion)
            if let configs = migratedConfigs {
                // Save migrated configs
                if let encoded = try? JSONEncoder().encode(configs) {
                    UserDefaults.standard.set(encoded, forKey: Keys.widgetConfigs)
                }

                #if DEBUG
                print("[WidgetPreferences] Migration completed successfully")
                #endif
            }

            // Update migration version
            UserDefaults.standard.set(currentMigrationVersion, forKey: Keys.migrationVersion)

        } catch {
            // Log migration failure
            #if DEBUG
            print("[WidgetPreferences] Migration failed: \(error.localizedDescription)")
            #endif

            // Fallback: clear configs to use defaults
            UserDefaults.standard.removeObject(forKey: Keys.widgetConfigs)

            // Still update version to prevent repeated failed migrations
            UserDefaults.standard.set(currentMigrationVersion, forKey: Keys.migrationVersion)
        }
    }

    /// Perform migration from a specific version
    /// - Returns: Migrated configs, or nil if no migration was performed
    private static func performMigration(from version: Int) throws -> [WidgetConfiguration]? {
        guard let data = UserDefaults.standard.data(forKey: Keys.widgetConfigs) else {
            // No existing configs - nothing to migrate
            return nil
        }

        // Version 0 -> 1: Migrate from legacy format (iconOnly/iconWithValue/iconWithValueAndSparkline)
        // Version 1 -> 2: Add visualizationType field
        // Version 2 -> 3: Add moduleSettings field
        if version == 0 {
            return try migrateFromLegacyFormat(data: data)
        } else if version == 1 {
            return try migrateToVersion2(data: data)
        } else if version == 2 {
            return try migrateToVersion3(data: data)
        }

        return nil
    }

    /// Migrate from legacy format (pre-v1) to current format
    private static func migrateFromLegacyFormat(data: Data) throws -> [WidgetConfiguration] {
        // Try legacy format with old display modes
        struct LegacyWidgetConfiguration: Decodable {
            let id: UUID
            var type: WidgetType
            var isEnabled: Bool
            var position: Int
            var displayMode: LegacyDisplayMode
            var showLabel: Bool
            var valueFormat: WidgetValueFormat
            var refreshInterval: WidgetUpdateInterval
        }

        enum LegacyDisplayMode: String, Decodable {
            case iconOnly = "iconOnly"
            case iconWithValue = "iconWithValue"
            case iconWithValueAndSparkline = "iconWithValueAndSparkline"

            func migrate() -> WidgetDisplayMode {
                switch self {
                case .iconOnly, .iconWithValue: return .compact
                case .iconWithValueAndSparkline: return .detailed
                }
            }
        }

        let legacyConfigs = try JSONDecoder().decode([LegacyWidgetConfiguration].self, from: data)

        // Migrate to new format with visualizationType
        return legacyConfigs.map { legacy in
            WidgetConfiguration(
                id: legacy.id,
                type: legacy.type,
                visualizationType: legacy.type.defaultVisualization,
                isEnabled: legacy.isEnabled,
                position: legacy.position,
                displayMode: legacy.displayMode.migrate(),
                showLabel: legacy.showLabel,
                valueFormat: legacy.valueFormat,
                refreshInterval: legacy.refreshInterval,
                accentColor: .system,
                chartConfig: nil as ChartConfiguration?
            )
        }
    }

    /// Migrate from version 1 to version 2 (add visualizationType)
    private static func migrateToVersion2(data: Data) throws -> [WidgetConfiguration] {
        // Version 1 configs don't have visualizationType
        struct PreVisualizationConfig: Decodable {
            let id: UUID
            var type: WidgetType
            var isEnabled: Bool
            var position: Int
            var displayMode: WidgetDisplayMode
            var showLabel: Bool
            var valueFormat: WidgetValueFormat
            var refreshInterval: WidgetUpdateInterval
            var accentColor: WidgetAccentColor
        }

        let preVizConfigs = try JSONDecoder().decode([PreVisualizationConfig].self, from: data)

        // Migrate by adding default visualizationType
        return preVizConfigs.map { config in
            WidgetConfiguration(
                id: config.id,
                type: config.type,
                visualizationType: config.type.defaultVisualization,
                isEnabled: config.isEnabled,
                position: config.position,
                displayMode: config.displayMode,
                showLabel: config.showLabel,
                valueFormat: config.valueFormat,
                refreshInterval: config.refreshInterval,
                accentColor: config.accentColor,
                chartConfig: nil as ChartConfiguration?
            )
        }
    }

    /// Migrate from version 2 to version 3 (add moduleSettings)
    private static func migrateToVersion3(data: Data) throws -> [WidgetConfiguration] {
        // Version 2 configs don't have moduleSettings
        struct PreModuleSettingsConfig: Decodable {
            let id: UUID
            var type: WidgetType
            var isEnabled: Bool
            var position: Int
            var displayMode: WidgetDisplayMode
            var showLabel: Bool
            var valueFormat: WidgetValueFormat
            var refreshInterval: WidgetUpdateInterval
            var accentColor: WidgetAccentColor
            var visualizationType: VisualizationType
            var chartConfig: ChartConfiguration?
        }

        let preModuleConfigs = try JSONDecoder().decode([PreModuleSettingsConfig].self, from: data)

        // Migrate by adding default moduleSettings
        return preModuleConfigs.map { config in
            WidgetConfiguration(
                id: config.id,
                type: config.type,
                visualizationType: config.visualizationType,
                isEnabled: config.isEnabled,
                position: config.position,
                displayMode: config.displayMode,
                showLabel: config.showLabel,
                valueFormat: config.valueFormat,
                refreshInterval: config.refreshInterval,
                accentColor: config.accentColor,
                chartConfig: config.chartConfig,
                moduleSettings: ModuleSettings.default
            )
        }
    }

    /// Create backup of existing configs before migration
    private static func backupConfigs() {
        guard let data = UserDefaults.standard.data(forKey: Keys.widgetConfigs) else {
            return
        }

        // Save backup
        UserDefaults.standard.set(data, forKey: Keys.backupConfigs)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Keys.backupTimestamp)

        #if DEBUG
        let timestamp = Date(timeIntervalSince1970: UserDefaults.standard.double(forKey: Keys.backupTimestamp))
        print("[WidgetPreferences] Backup created at \(timestamp)")
        #endif
    }

    /// Restore configs from backup (for recovery if needed)
    public static func restoreFromBackup() -> Bool {
        guard let backupData = UserDefaults.standard.data(forKey: Keys.backupConfigs) else {
            return false
        }

        UserDefaults.standard.set(backupData, forKey: Keys.widgetConfigs)

        #if DEBUG
        print("[WidgetPreferences] Restored from backup")
        #endif

        return true
    }

    /// Get backup timestamp if available
    public static var backupTimestamp: Date? {
        let timestamp = UserDefaults.standard.double(forKey: Keys.backupTimestamp)
        return timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : nil
    }

    /// Get enabled widgets sorted by position
    public var enabledWidgets: [WidgetConfiguration] {
        widgetConfigs
            .filter { $0.isEnabled }
            .sorted { $0.position < $1.position }
    }

    /// Get configuration for a specific widget type
    public func config(for type: WidgetType) -> WidgetConfiguration? {
        widgetConfigs.first { $0.type == type }
    }

    /// Update configuration for a specific widget type
    public func updateConfig(for type: WidgetType, _ update: (inout WidgetConfiguration) -> Void) {
        if let index = widgetConfigs.firstIndex(where: { $0.type == type }) {
            update(&widgetConfigs[index])
            saveConfigs()

            // Broadcast change immediately for reactive updates
            Task { @MainActor in
                NotificationCenter.default.post(
                    name: .widgetConfigurationDidUpdate,
                    object: nil,
                    userInfo: ["widgetType": type]
                )
            }
        }
    }

    /// Reorder widgets to new positions
    public func reorderWidgets(_ configs: [WidgetConfiguration]) {
        // Update positions based on new order
        for (index, var config) in configs.enumerated() {
            config.position = index
            widgetConfigs[index] = config
        }
        saveConfigs()

        // Broadcast change for reactive updates
        Task { @MainActor in
            NotificationCenter.default.post(
                name: .widgetConfigurationDidUpdate,
                object: nil,
                userInfo: ["widgetType": WidgetType.cpu] // Send any type - triggers full refresh
            )
        }
    }

    /// Reset all configurations to defaults
    public func resetToDefaults() {
        widgetConfigs = Self.defaultConfigs()
        updateInterval = .balanced
        temperatureUnit = .celsius
        saveConfigs()
        saveInterval()
        saveOnboarding()
        saveTemperatureUnit()
    }

    // MARK: - Persistence

    private func loadFromUserDefaults() {
        // Load update interval
        if let intervalString = UserDefaults.standard.string(forKey: Keys.updateInterval),
           let interval = WidgetUpdateInterval(rawValue: intervalString) {
            updateInterval = interval
        }

        // Load onboarding status
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: Keys.hasCompletedOnboarding)

        // Load unified menu bar mode
        unifiedMenuBarMode = UserDefaults.standard.bool(forKey: Keys.unifiedMenuBarMode)

        // Load temperature unit
        if let unitString = UserDefaults.standard.string(forKey: Keys.temperatureUnit),
           let unit = TemperatureUnit(rawValue: unitString) {
            temperatureUnit = unit
        }
    }

    internal func saveConfigs() {
        if let encoded = try? JSONEncoder().encode(widgetConfigs) {
            UserDefaults.standard.set(encoded, forKey: Keys.widgetConfigs)
        }
    }

    private static func loadConfigsFromUserDefaults() -> [WidgetConfiguration]? {
        guard let data = UserDefaults.standard.data(forKey: Keys.widgetConfigs) else {
            return nil
        }

        // First, try to decode with the current struct
        if let configs = try? JSONDecoder().decode([WidgetConfiguration].self, from: data) {
            return configs
        }

        // Second, try to decode without visualizationType (pre-Stats Master parity)
        struct PreVisualizationConfig: Codable {
            let id: UUID
            var type: WidgetType
            var isEnabled: Bool
            var position: Int
            var displayMode: WidgetDisplayMode
            var showLabel: Bool
            var valueFormat: WidgetValueFormat
            var refreshInterval: WidgetUpdateInterval
            var accentColor: WidgetAccentColor
        }

        if let preVizConfigs = try? JSONDecoder().decode([PreVisualizationConfig].self, from: data) {
            // Migrate by adding default visualizationType
            return preVizConfigs.map { config in
                WidgetConfiguration(
                    id: config.id,
                    type: config.type,
                    visualizationType: config.type.defaultVisualization,
                    isEnabled: config.isEnabled,
                    position: config.position,
                    displayMode: config.displayMode,
                    showLabel: config.showLabel,
                    valueFormat: config.valueFormat,
                    refreshInterval: config.refreshInterval,
                    accentColor: config.accentColor,
                    chartConfig: nil as ChartConfiguration?
                )
            }
        }

        // Third, try legacy format with old display modes
        struct LegacyWidgetConfiguration: Codable {
            let id: UUID
            var type: WidgetType
            var isEnabled: Bool
            var position: Int
            var displayMode: LegacyDisplayMode
            var showLabel: Bool
            var valueFormat: WidgetValueFormat
            var refreshInterval: WidgetUpdateInterval
        }

        enum LegacyDisplayMode: String, Codable {
            case iconOnly = "iconOnly"
            case iconWithValue = "iconWithValue"
            case iconWithValueAndSparkline = "iconWithValueAndSparkline"

            func migrate() -> WidgetDisplayMode {
                switch self {
                case .iconOnly, .iconWithValue: return .compact
                case .iconWithValueAndSparkline: return .detailed
                }
            }
        }

        if let legacyConfigs = try? JSONDecoder().decode([LegacyWidgetConfiguration].self, from: data) {
            // Migrate to new format
            return legacyConfigs.map { legacy in
                WidgetConfiguration(
                    id: legacy.id,
                    type: legacy.type,
                    visualizationType: legacy.type.defaultVisualization,
                    isEnabled: legacy.isEnabled,
                    position: legacy.position,
                    displayMode: legacy.displayMode.migrate(),
                    showLabel: legacy.showLabel,
                    valueFormat: legacy.valueFormat,
                    refreshInterval: legacy.refreshInterval,
                    accentColor: .system,
                    chartConfig: nil as ChartConfiguration?
                )
            }
        }

        return nil
    }

    private func saveInterval() {
        UserDefaults.standard.set(updateInterval.rawValue, forKey: Keys.updateInterval)
    }

    private func saveOnboarding() {
        UserDefaults.standard.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding)
    }

    private func saveUnifiedMenuBarMode() {
        UserDefaults.standard.set(unifiedMenuBarMode, forKey: Keys.unifiedMenuBarMode)
    }

    private func saveTemperatureUnit() {
        UserDefaults.standard.set(temperatureUnit.rawValue, forKey: Keys.temperatureUnit)
    }

    // MARK: - Public Setters

    public func setUpdateInterval(_ interval: WidgetUpdateInterval) {
        updateInterval = interval
        saveInterval()
    }

    public func setHasCompletedOnboarding(_ completed: Bool) {
        hasCompletedOnboarding = completed
        saveOnboarding()
    }

    public func toggleWidget(type: WidgetType) {
        updateConfig(for: type) { config in
            config.isEnabled.toggle()
        }
    }

    public func setWidgetEnabled(type: WidgetType, enabled: Bool) {
        updateConfig(for: type) { config in
            config.isEnabled = enabled
        }
    }

    public func setWidgetDisplayMode(type: WidgetType, mode: WidgetDisplayMode) {
        updateConfig(for: type) { config in
            config.displayMode = mode
        }
    }

    public func setWidgetShowLabel(type: WidgetType, show: Bool) {
        updateConfig(for: type) { config in
            config.showLabel = show
        }
    }

    public func setWidgetValueFormat(type: WidgetType, format: WidgetValueFormat) {
        updateConfig(for: type) { config in
            config.valueFormat = format
        }
    }

    public func setWidgetRefreshInterval(type: WidgetType, interval: WidgetUpdateInterval) {
        updateConfig(for: type) { config in
            config.refreshInterval = interval
        }
    }

    public func setWidgetColor(type: WidgetType, color: WidgetAccentColor) {
        updateConfig(for: type) { config in
            config.accentColor = color
        }
    }

    public func setWidgetVisualization(type: WidgetType, visualization: VisualizationType) {
        updateConfig(for: type) { config in
            config.visualizationType = visualization
        }
    }

    public func setWidgetChartConfig(type: WidgetType, chartConfig: ChartConfiguration?) {
        updateConfig(for: type) { config in
            config.chartConfig = chartConfig
        }
    }

    public func setWidgetModuleSettings(type: WidgetType, settings: ModuleSettings) {
        updateConfig(for: type) { config in
            config.moduleSettings = settings
        }
    }

    public func setUnifiedMenuBarMode(_ enabled: Bool) {
        unifiedMenuBarMode = enabled
        saveUnifiedMenuBarMode()
    }

    public func toggleUnifiedMenuBarMode() {
        unifiedMenuBarMode.toggle()
        saveUnifiedMenuBarMode()
    }

    public func setTemperatureUnit(_ unit: TemperatureUnit) {
        temperatureUnit = unit
        saveTemperatureUnit()

        // Broadcast change for reactive updates
        Task { @MainActor in
            NotificationCenter.default.post(
                name: .widgetConfigurationDidUpdate,
                object: nil,
                userInfo: ["widgetType": "temperatureUnit"]
            )
        }
    }
}

// MARK: - Compatible Visualizations

extension WidgetType {
    /// Returns the visualization types compatible with this data source
    public var compatibleVisualizations: [VisualizationType] {
        switch self {
        case .cpu:
            return [.mini, .lineChart, .barChart, .pieChart, .tachometer]
        case .memory:
            return [.mini, .lineChart, .barChart, .pieChart, .tachometer, .memory]
        case .disk:
            return [.mini, .pieChart, .barChart]
        case .network:
            return [.mini, .speed, .lineChart, .networkChart]
        case .gpu:
            return [.mini, .lineChart, .barChart, .pieChart, .tachometer]
        case .battery:
            return [.mini, .pieChart, .batteryDetails, .battery]
        case .sensors:
            return [.stack, .tachometer, .text, .label]
        case .weather:
            return [.mini, .text, .label]
        case .bluetooth:
            return [.stack, .mini, .state]
        case .clock:
            return [.stack, .text, .label]
        }
    }

    /// Default visualization for this data source type
    public var defaultVisualization: VisualizationType {
        switch self {
        case .sensors, .bluetooth, .clock: return .stack
        default: return .mini
        }
    }

    /// Whether this data source supports chart-based visualizations
    public var supportsCharts: Bool {
        compatibleVisualizations.contains(where: { $0.supportsHistory })
    }
}
