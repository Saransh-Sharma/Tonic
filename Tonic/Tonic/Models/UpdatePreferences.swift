//
//  UpdatePreferences.swift
//  Tonic
//
//  User preferences for third-party app update checking: how often Tonic
//  checks automatically, whether to notify, and which apps or specific
//  versions the user has chosen to ignore.
//
//  Ignoring is per-app ("stop telling me about this app") or per-version
//  ("skip 1.4.2, tell me about the next one") — the same split MacUpdater
//  and Sparkle itself use.
//

import Foundation

enum UpdateCheckCadence: String, Codable, CaseIterable, Identifiable {
    case manual
    case daily
    case weekly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .manual: return "Manual"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        }
    }

    /// nil = never auto-check.
    var interval: TimeInterval? {
        switch self {
        case .manual: return nil
        case .daily: return 24 * 3600
        case .weekly: return 7 * 24 * 3600
        }
    }
}

@MainActor
@Observable
final class UpdatePreferences {

    static let shared = UpdatePreferences()

    private enum Keys {
        static let cadence = "tonic.updates.cadence"
        static let notify = "tonic.updates.notify"
        static let ignored = "tonic.updates.ignoredBundleIDs"
        static let pinned = "tonic.updates.pinnedVersions"
        static let lastCheck = "tonic.updates.lastCheckDate"
    }

    var cadence: UpdateCheckCadence {
        didSet { defaults.set(cadence.rawValue, forKey: Keys.cadence) }
    }

    var notifyOnUpdates: Bool {
        didSet { defaults.set(notifyOnUpdates, forKey: Keys.notify) }
    }

    private(set) var ignoredBundleIDs: Set<String> {
        didSet { defaults.set(Array(ignoredBundleIDs), forKey: Keys.ignored) }
    }

    /// bundleID → the specific latest-version string the user chose to skip.
    private(set) var pinnedVersions: [String: String] {
        didSet { defaults.set(pinnedVersions, forKey: Keys.pinned) }
    }

    /// Persisted across launches so cadence works without a resident timer.
    var lastCheckDate: Date? {
        didSet { defaults.set(lastCheckDate, forKey: Keys.lastCheck) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        cadence = UpdateCheckCadence(rawValue: defaults.string(forKey: Keys.cadence) ?? "") ?? .daily
        notifyOnUpdates = defaults.object(forKey: Keys.notify) as? Bool ?? true
        ignoredBundleIDs = Set(defaults.stringArray(forKey: Keys.ignored) ?? [])
        pinnedVersions = (defaults.dictionary(forKey: Keys.pinned) as? [String: String]) ?? [:]
        lastCheckDate = defaults.object(forKey: Keys.lastCheck) as? Date
    }

    // MARK: - Ignore / pin

    func ignore(_ bundleID: String) { ignoredBundleIDs.insert(bundleID) }
    func unignore(_ bundleID: String) { ignoredBundleIDs.remove(bundleID) }
    func isIgnored(_ bundleID: String) -> Bool { ignoredBundleIDs.contains(bundleID) }

    /// Skip exactly this version; the next release surfaces again.
    func skipVersion(_ version: String, for bundleID: String) {
        pinnedVersions[bundleID] = version
    }

    func clearSkippedVersion(for bundleID: String) {
        pinnedVersions[bundleID] = nil
    }

    /// Whether an available update should appear in the Updates list.
    func shouldSurface(_ update: AppUpdate) -> Bool {
        if ignoredBundleIDs.contains(update.bundleIdentifier) { return false }
        if pinnedVersions[update.bundleIdentifier] == update.latestVersion { return false }
        return true
    }

    // MARK: - Cadence

    /// True when an automatic check is due under the current cadence.
    func isAutoCheckDue(now: Date = Date()) -> Bool {
        guard let interval = cadence.interval else { return false }
        guard let last = lastCheckDate else { return true }
        return now.timeIntervalSince(last) >= interval
    }
}
