//
//  ClockConfiguration.swift
//  Tonic
//
//  Clock widget configuration models
//  Task ID: fn-6-i4g.16
//

import Foundation

// MARK: - Clock Entry

/// A single clock entry representing a timezone
public struct ClockEntry: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var name: String                   // Display name (e.g., "Tokyo", "London")
    public var timezoneIdentifier: String     // TimeZone identifier (e.g., "America/New_York")
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        timezoneIdentifier: String,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.timezoneIdentifier = timezoneIdentifier
        self.isEnabled = isEnabled
    }

    /// The TimeZone for this entry
    public var timezone: TimeZone {
        TimeZone(identifier: timezoneIdentifier) ?? .current
    }

    /// Common preset timezones
    public static let presets: [ClockEntry] = [
        ClockEntry(name: "Local", timezoneIdentifier: TimeZone.current.identifier, isEnabled: true),
        ClockEntry(name: "UTC", timezoneIdentifier: "UTC", isEnabled: false),
        ClockEntry(name: "New York", timezoneIdentifier: "America/New_York", isEnabled: false),
        ClockEntry(name: "London", timezoneIdentifier: "Europe/London", isEnabled: false),
        ClockEntry(name: "Paris", timezoneIdentifier: "Europe/Paris", isEnabled: false),
        ClockEntry(name: "Tokyo", timezoneIdentifier: "Asia/Tokyo", isEnabled: false),
        ClockEntry(name: "Sydney", timezoneIdentifier: "Australia/Sydney", isEnabled: false),
        ClockEntry(name: "Los Angeles", timezoneIdentifier: "America/Los_Angeles", isEnabled: false),
    ]

    /// Create a copy with modified properties
    public func with(name: String? = nil, timezoneIdentifier: String? = nil, isEnabled: Bool? = nil) -> ClockEntry {
        ClockEntry(
            id: id,
            name: name ?? self.name,
            timezoneIdentifier: timezoneIdentifier ?? self.timezoneIdentifier,
            isEnabled: isEnabled ?? self.isEnabled
        )
    }
}

// MARK: - Clock Time Format

/// Time format options for clock display
public enum ClockTimeFormat: String, CaseIterable, Identifiable, Codable, Sendable {
    case auto = "auto"                     // Use system 12/24 hour setting
    case twelveHour = "twelveHour"         // Force 12-hour format (h:mm a)
    case twentyFourHour = "twentyFourHour" // Force 24-hour format (HH:mm)

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .auto: return "System Default"
        case .twelveHour: return "12-Hour (h:mm a)"
        case .twentyFourHour: return "24-Hour (HH:mm)"
        }
    }
}

// MARK: - Clock Data

/// Current time data for a specific timezone
public struct ClockTimeData: Identifiable, Sendable {
    public let id: UUID
    public let entry: ClockEntry
    public let timeString: String          // Formatted time
    public let dateString: String          // Formatted date
    public let utcOffsetString: String     // UTC offset (e.g., "+05:00", "-08:00")
    public let isDST: Bool                 // Daylight Saving Time active
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        entry: ClockEntry,
        timeString: String,
        dateString: String,
        utcOffsetString: String,
        isDST: Bool,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.entry = entry
        self.timeString = timeString
        self.dateString = dateString
        self.utcOffsetString = utcOffsetString
        self.isDST = isDST
        self.timestamp = timestamp
    }
}

// MARK: - Clock Preferences

/// User preferences for clock widget
@MainActor
@Observable
public final class ClockPreferences: Sendable {
    public static let shared = ClockPreferences()

    /// List of configured timezone entries
    public var entries: [ClockEntry]

    /// Time format to use for display
    public var timeFormat: ClockTimeFormat

    /// Whether to show seconds in time display
    public var showSeconds: Bool

    /// Maximum number of timezones to show in compact view
    public var maxCompactEntries: Int

    private enum Keys {
        static let entries = "tonic.clock.entries"
        static let timeFormat = "tonic.clock.timeFormat"
        static let showSeconds = "tonic.clock.showSeconds"
        static let maxCompactEntries = "tonic.clock.maxCompactEntries"
    }

    private init() {
        self.timeFormat = .auto
        self.showSeconds = false
        self.maxCompactEntries = 3

        // Load saved entries or use defaults
        if let data = UserDefaults.standard.data(forKey: Keys.entries),
           let decoded = try? JSONDecoder().decode([ClockEntry].self, from: data) {
            self.entries = decoded
        } else {
            // Default: Local + UTC + 2 common zones
            self.entries = [
                ClockEntry(name: "Local", timezoneIdentifier: TimeZone.current.identifier, isEnabled: true),
                ClockEntry(name: "UTC", timezoneIdentifier: "UTC", isEnabled: true),
                ClockEntry(name: "New York", timezoneIdentifier: "America/New_York", isEnabled: true),
                ClockEntry(name: "London", timezoneIdentifier: "Europe/London", isEnabled: false),
            ]
        }

        // Load other preferences
        if let formatRaw = UserDefaults.standard.string(forKey: Keys.timeFormat),
           let format = ClockTimeFormat(rawValue: formatRaw) {
            self.timeFormat = format
        }

        self.showSeconds = UserDefaults.standard.bool(forKey: Keys.showSeconds)

        if let maxVal = UserDefaults.standard.object(forKey: Keys.maxCompactEntries) as? Int {
            self.maxCompactEntries = max(1, min(4, maxVal))
        }
    }

    // MARK: - Public Methods

    /// Get enabled entries only
    public var enabledEntries: [ClockEntry] {
        entries.filter { $0.isEnabled }
    }

    /// Update an entry
    public func updateEntry(_ entry: ClockEntry) {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = entry
            saveEntries()
        }
    }

    /// Add a new entry
    public func addEntry(_ entry: ClockEntry) {
        entries.append(entry)
        saveEntries()
    }

    /// Remove an entry
    public func removeEntry(id: UUID) {
        entries.removeAll { $0.id == id }
        saveEntries()
    }

    /// Reorder entries
    public func reorderEntries(from source: IndexSet, to destination: Int) {
        entries.move(fromOffsets: source, toOffset: destination)
        saveEntries()
    }

    /// Set time format
    public func setTimeFormat(_ format: ClockTimeFormat) {
        timeFormat = format
        UserDefaults.standard.set(format.rawValue, forKey: Keys.timeFormat)
    }

    /// Toggle show seconds
    public func toggleShowSeconds() {
        showSeconds.toggle()
        UserDefaults.standard.set(showSeconds, forKey: Keys.showSeconds)
    }

    private func saveEntries() {
        if let encoded = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(encoded, forKey: Keys.entries)
        }
    }
}
