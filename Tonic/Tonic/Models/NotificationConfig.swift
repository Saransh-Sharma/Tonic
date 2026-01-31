//
//  NotificationConfig.swift
//  Tonic
//
//  Aggregate notification settings
//  Task ID: fn-6-i4g.3
//

import Foundation

// MARK: - Notification Configuration

/// Global configuration for the notification system
public struct NotificationConfig: Codable, Sendable, Equatable {
    /// All configured threshold notifications
    public var thresholds: [NotificationThreshold]

    /// Whether to respect macOS Do Not Disturb mode
    public var respectDoNotDisturb: Bool

    /// Minimum time interval between notifications (in seconds)
    /// Prevents notification spam for the same threshold
    public var minimumInterval: TimeInterval

    /// Whether notifications are globally enabled
    public var notificationsEnabled: Bool

    public init(
        thresholds: [NotificationThreshold] = [],
        respectDoNotDisturb: Bool = true,
        minimumInterval: TimeInterval = 300, // 5 minutes default
        notificationsEnabled: Bool = true
    ) {
        self.thresholds = thresholds
        self.respectDoNotDisturb = respectDoNotDisturb
        self.minimumInterval = minimumInterval
        self.notificationsEnabled = notificationsEnabled
    }

    /// Default configuration with sensible defaults
    public static let `default` = NotificationConfig()

    /// Get thresholds for a specific widget type
    public func thresholds(for widgetType: WidgetType) -> [NotificationThreshold] {
        thresholds.filter { $0.widgetType == widgetType && $0.isEnabled }
    }

    /// Get enabled thresholds for a specific widget type
    public func enabledThresholds(for widgetType: WidgetType) -> [NotificationThreshold] {
        thresholds.filter { $0.widgetType == widgetType && $0.isEnabled }
    }

    /// Check if any thresholds are configured for a widget type
    public func hasThresholds(for widgetType: WidgetType) -> Bool {
        thresholds.contains(where: { $0.widgetType == widgetType && $0.isEnabled })
    }

    /// Add or update a threshold
    public mutating func setThreshold(_ threshold: NotificationThreshold) {
        if let index = thresholds.firstIndex(where: { $0.id == threshold.id }) {
            thresholds[index] = threshold
        } else {
            thresholds.append(threshold)
        }
    }

    /// Remove a threshold by ID
    public mutating func removeThreshold(id: UUID) {
        thresholds.removeAll { $0.id == id }
    }

    /// Remove all thresholds for a widget type
    public mutating func removeThresholds(for widgetType: WidgetType) {
        thresholds.removeAll { $0.widgetType == widgetType }
    }

    /// Toggle a threshold's enabled state
    public mutating func toggleThreshold(id: UUID) {
        if let index = thresholds.firstIndex(where: { $0.id == id }) {
            thresholds[index].isEnabled.toggle()
        }
    }
}

// MARK: - UserDefaults Keys

extension NotificationConfig {
    private enum Keys {
        static let thresholds = "tonic.notifications.thresholds"
        static let respectDoNotDisturb = "tonic.notifications.respectDND"
        static let minimumInterval = "tonic.notifications.minInterval"
        static let notificationsEnabled = "tonic.notifications.enabled"
    }

    /// Load configuration from UserDefaults
    public static func load() -> NotificationConfig {
        var config = NotificationConfig()

        // Load enabled state
        if UserDefaults.standard.object(forKey: Keys.notificationsEnabled) != nil {
            config.notificationsEnabled = UserDefaults.standard.bool(forKey: Keys.notificationsEnabled)
        }

        // Load respect DND
        if UserDefaults.standard.object(forKey: Keys.respectDoNotDisturb) != nil {
            config.respectDoNotDisturb = UserDefaults.standard.bool(forKey: Keys.respectDoNotDisturb)
        }

        // Load minimum interval
        if let interval = UserDefaults.standard.object(forKey: Keys.minimumInterval) as? TimeInterval {
            config.minimumInterval = interval
        }

        // Load thresholds
        if let data = UserDefaults.standard.data(forKey: Keys.thresholds),
           let decoded = try? JSONDecoder().decode([NotificationThreshold].self, from: data) {
            config.thresholds = decoded
        }

        return config
    }

    /// Save configuration to UserDefaults
    public func save() {
        UserDefaults.standard.set(notificationsEnabled, forKey: Keys.notificationsEnabled)
        UserDefaults.standard.set(respectDoNotDisturb, forKey: Keys.respectDoNotDisturb)
        UserDefaults.standard.set(minimumInterval, forKey: Keys.minimumInterval)

        if let encoded = try? JSONEncoder().encode(thresholds) {
            UserDefaults.standard.set(encoded, forKey: Keys.thresholds)
        }
    }

    /// Reset to default configuration
    public mutating func reset() {
        self = NotificationConfig.default
        save()
    }
}

// MARK: - Preset Intervals

extension NotificationConfig {
    /// Common preset intervals for debouncing
    public enum PresetInterval: String, Codable, Sendable, CaseIterable, Identifiable {
        case oneMinute = "oneMinute"
        case fiveMinutes = "fiveMinutes"
        case fifteenMinutes = "fifteenMinutes"
        case thirtyMinutes = "thirtyMinutes"
        case oneHour = "oneHour"

        public var id: String { rawValue }

        public var displayName: String {
            switch self {
            case .oneMinute: return "1 minute"
            case .fiveMinutes: return "5 minutes"
            case .fifteenMinutes: return "15 minutes"
            case .thirtyMinutes: return "30 minutes"
            case .oneHour: return "1 hour"
            }
        }

        public var timeInterval: TimeInterval {
            switch self {
            case .oneMinute: return 60
            case .fiveMinutes: return 300
            case .fifteenMinutes: return 900
            case .thirtyMinutes: return 1800
            case .oneHour: return 3600
            }
        }
    }
}
