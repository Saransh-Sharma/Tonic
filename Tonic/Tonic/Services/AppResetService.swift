//
//  AppResetService.swift
//  Tonic
//
//  Handles complete app reset: clears preferences, data, helper, and triggers onboarding
//

import Foundation
import AppKit

/// Manages the complete app reset process
@MainActor
@Observable
public final class AppResetService {
    public static let shared = AppResetService()

    // MARK: - Types

    public enum ResetStep: Int, CaseIterable {
        case stoppingWidgets
        case clearingCache
        case removingAppData
        case resettingPreferences
        case preparingOnboarding

        var displayName: String {
            switch self {
            case .stoppingWidgets: return "Stopping widgets"
            case .clearingCache: return "Clearing cache files"
            case .removingAppData: return "Removing app data"
            case .resettingPreferences: return "Resetting preferences"
            case .preparingOnboarding: return "Preparing fresh start"
            }
        }

        var icon: String {
            switch self {
            case .stoppingWidgets: return "square.grid.2x2"
            case .clearingCache: return "trash"
            case .removingAppData: return "folder"
            case .resettingPreferences: return "gearshape"
            case .preparingOnboarding: return "sparkles"
            }
        }
    }

    public enum ResetState: Equatable {
        case idle
        case inProgress(step: ResetStep, progress: Double)
        case completed(warnings: [String])
        case failed(error: String)

        public static func == (lhs: ResetState, rhs: ResetState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle):
                return true
            case let (.inProgress(s1, p1), .inProgress(s2, p2)):
                return s1 == s2 && p1 == p2
            case let (.completed(w1), .completed(w2)):
                return w1 == w2
            case let (.failed(e1), .failed(e2)):
                return e1 == e2
            default:
                return false
            }
        }
    }

    // MARK: - State

    public private(set) var state: ResetState = .idle
    public private(set) var completedSteps: Set<ResetStep> = []

    private init() {}

    // MARK: - Size Calculations

    /// Calculate cache directory size
    public var cacheSize: Int64 {
        guard let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("com.tonic.Tonic") else { return 0 }
        return directorySize(at: cacheURL)
    }

    /// Calculate app data directory size
    public var appDataSize: Int64 {
        guard let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Tonic") else { return 0 }
        return directorySize(at: appSupportURL)
    }

    // MARK: - Reset Operations

    /// Perform the complete app reset
    public func performReset() async {
        var warnings: [String] = []
        completedSteps = []

        // Step 1: Stop widgets
        state = .inProgress(step: .stoppingWidgets, progress: 0.0)
        await stopWidgets()
        completedSteps.insert(.stoppingWidgets)

        // Step 2: Clear cache
        state = .inProgress(step: .clearingCache, progress: 0.17)
        await clearCacheFiles(warnings: &warnings)
        completedSteps.insert(.clearingCache)

        // Step 3: Remove app data
        state = .inProgress(step: .removingAppData, progress: 0.33)
        await clearAppData(warnings: &warnings)
        completedSteps.insert(.removingAppData)

        // Step 4: Uninstall helper
        state = .inProgress(step: .uninstallingHelper, progress: 0.50)
        await uninstallHelperGracefully(warnings: &warnings)
        completedSteps.insert(.uninstallingHelper)

        // Step 5: Reset preferences
        state = .inProgress(step: .resettingPreferences, progress: 0.67)
        resetAllUserDefaults()
        completedSteps.insert(.resettingPreferences)

        // Step 6: Reset singletons and prepare onboarding
        state = .inProgress(step: .preparingOnboarding, progress: 0.83)
        resetSingletonStates()
        completedSteps.insert(.preparingOnboarding)

        // Brief pause for final animation
        try? await Task.sleep(nanoseconds: 300_000_000)

        state = .completed(warnings: warnings)
    }

    /// Reset state back to idle
    public func resetState() {
        state = .idle
        completedSteps = []
    }

    // MARK: - Individual Operations

    private func stopWidgets() async {
        WidgetCoordinator.shared.stop()
        // Brief delay for UI cleanup
        try? await Task.sleep(nanoseconds: 200_000_000)
    }

    private func clearCacheFiles(warnings: inout [String]) async {
        let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("com.tonic.Tonic")

        if let cacheURL, FileManager.default.fileExists(atPath: cacheURL.path) {
            do {
                try FileManager.default.removeItem(at: cacheURL)
            } catch {
                warnings.append("Could not fully clear cache: \(error.localizedDescription)")
            }
        }
        try? await Task.sleep(nanoseconds: 150_000_000)
    }

    private func clearAppData(warnings: inout [String]) async {
        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Tonic")

        if let appSupportURL, FileManager.default.fileExists(atPath: appSupportURL.path) {
            do {
                try FileManager.default.removeItem(at: appSupportURL)
            } catch {
                warnings.append("Could not fully remove app data: \(error.localizedDescription)")
            }
        }
        try? await Task.sleep(nanoseconds: 150_000_000)
    }

    private func uninstallHelperGracefully(warnings: inout [String]) async {
        guard PrivilegedHelperManager.shared.isHelperInstalled else {
            try? await Task.sleep(nanoseconds: 100_000_000)
            return
        }

        do {
            try await PrivilegedHelperManager.shared.uninstallHelper()
        } catch {
            warnings.append("Helper tool could not be removed: \(error.localizedDescription)")
        }
        try? await Task.sleep(nanoseconds: 150_000_000)
    }

    private func resetAllUserDefaults() {
        let defaults = UserDefaults.standard
        let bundleId = Bundle.main.bundleIdentifier ?? "com.tonic.Tonic"

        // Remove all keys for this app's domain
        defaults.removePersistentDomain(forName: bundleId)

        // Also explicitly remove known keys that might persist
        let knownKeys = [
            "hasSeenOnboarding",
            "hasCompletedWidgetOnboarding",
            "hasSeenFeatureTour",
            "tonic.widget.hasCompletedOnboarding",
            "tonic.widget.configs",
            "tonic.widget.updateInterval",
            "tonic.appearance.themeMode",
            "tonic.appearance.accentColor",
            "tonic.appearance.iconStyle",
            "tonic.appearance.reduceTransparency",
            "tonic.appearance.reduceMotion",
            "launchAtLogin",
            "automaticallyChecksForUpdates",
            "allowBetaUpdates",
            "firstLaunch",
            "scanEnabled",
            "notificationsEnabled",
            "autoCleanEnabled",
            "themePreference"
        ]

        for key in knownKeys {
            defaults.removeObject(forKey: key)
        }
        defaults.synchronize()
    }

    private func resetSingletonStates() {
        // Reset appearance to defaults
        AppearancePreferences.shared.setThemeMode(.system)
        AppearancePreferences.shared.setAccentColor(.blue)
        AppearancePreferences.shared.setIconStyle(.filled)
        AppearancePreferences.shared.setReduceTransparency(false)
        AppearancePreferences.shared.setReduceMotion(false)

        // Reset widget preferences
        WidgetPreferences.shared.resetToDefaults()
        WidgetPreferences.shared.setHasCompletedOnboarding(false)

        // Reset app appearance to follow system
        NSApp.appearance = nil
    }

    // MARK: - Helpers

    private func directorySize(at url: URL) -> Int64 {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else { return 0 }

        var totalSize: Int64 = 0
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                  values.isRegularFile == true else { continue }
            totalSize += Int64(values.fileSize ?? 0)
        }
        return totalSize
    }

    /// Format bytes into human-readable string
    public static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
