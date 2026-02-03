//
//  BackgroundActivityManager.swift
//  Tonic
//
//  Service for reading app background activity permissions from macOS
//

import Foundation
import AppKit

/// Manager for fetching app background activity permissions
@MainActor
@Observable
final class BackgroundActivityManager: @unchecked Sendable {
    public static let shared = BackgroundActivityManager()

    private init() {}

    // MARK: - Published Properties

    public private(set) var backgroundActivities: [BackgroundActivityItem] = []
    public var isLoading = false
    public var errorMessage: String?

    // MARK: - Fetch Background Activities

    /// Fetch all apps with background activity permissions
    public func fetchBackgroundActivities() async {
        isLoading = true
        errorMessage = nil

        var activities: [BackgroundActivityItem] = []

        // Try multiple sources for background activity data

        // Source 1: com.apple.backgroundtaskmanagement.plist
        activities.append(contentsOf: await fetchFromBackgroundTaskManagement())

        // Source 2: Scan apps and check their Info.plist for background modes
        activities.append(contentsOf: await fetchFromAppInfoPlists())

        // Remove duplicates based on bundle identifier
        var seenIDs = Set<String>()
        let uniqueActivities = activities.filter { activity in
            if seenIDs.contains(activity.bundleIdentifier) {
                return false
            }
            seenIDs.insert(activity.bundleIdentifier)
            return true
        }

        await MainActor.run {
            self.backgroundActivities = uniqueActivities
            self.isLoading = false
        }
    }

    // MARK: - Background Task Management plist

    private func fetchFromBackgroundTaskManagement() async -> [BackgroundActivityItem] {
        var items: [BackgroundActivityItem] = []

        // This plist contains background task permissions
        let path = NSHomeDirectory() + "/Library/Preferences/com.apple.backgroundtaskmanagement.plist"

        guard let data = FileManager.default.contents(atPath: path),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return items
        }

        // The plist structure typically contains:
        // - "BGTaskSchedulerPermittedIdentifiers" - dict mapping bundle IDs to permitted identifiers
        // - "com.apple.BackgroundTasks.backgroundUploadURL" - etc.

        if let permittedIds = plist["BGTaskSchedulerPermittedIdentifiers"] as? [String: [String]] {
            for (bundleID, identifiers) in permittedIds {
                if !identifiers.isEmpty {
                    // Find the app path
                    if let appPath = findAppBundle(for: bundleID) {
                        let appName = (appPath.lastPathComponent as NSString).deletingPathExtension

                        items.append(BackgroundActivityItem(
                            appName: appName,
                            bundleIdentifier: bundleID,
                            path: appPath,
                            isEnabled: true,
                            permissionCount: identifiers.count,
                            permissions: identifiers.map { identifier in
                                BackgroundPermission(
                                    type: .backgroundRefresh,
                                    isEnabled: true,
                                    description: identifier
                                )
                            }
                        ))
                    }
                }
            }
        }

        return items
    }

    // MARK: - Scan App Info.plists

    private func fetchFromAppInfoPlists() async -> [BackgroundActivityItem] {
        var items: [BackgroundActivityItem] = []

        let appDirectories = [
            "/Applications",
            NSHomeDirectory() + "/Applications",
            "/System/Applications"
        ]

        for directory in appDirectories {
            guard FileManager.default.fileExists(atPath: directory) else { continue }

            if let enumerator = FileManager.default.enumerator(
                at: URL(fileURLWithPath: directory),
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) {
                while let url = enumerator.nextObject() as? URL {
                    // Only process .app bundles
                    guard url.pathExtension == "app" else { continue }

                    // Check for Info.plist inside the app
                    let infoPlistPath = url.appendingPathComponent("Contents/Info.plist")

                    guard let infoData = FileManager.default.contents(atPath: infoPlistPath.path),
                          let infoPlist = try? PropertyListSerialization.propertyList(from: infoData, options: [], format: nil) as? [String: Any],
                          let bundleID = infoPlist["CFBundleIdentifier"] as? String else {
                        continue
                    }

                    // Check for background modes
                    var permissions: [BackgroundPermission] = []

                    // UIBackgroundModes (iOS) or NSBackgroundModes (macOS)
                    if let backgroundModes = infoPlist["UIBackgroundModes"] as? [String] {
                        for mode in backgroundModes {
                            permissions.append(parseBackgroundMode(mode))
                        }
                    } else if let backgroundModes = infoPlist["NSBackgroundModes"] as? [String] {
                        for mode in backgroundModes {
                            permissions.append(parseBackgroundMode(mode))
                        }
                    }

                    // Check for other background activity indicators
                    if infoPlist["NSSupportsSuddenTermination"] as? Bool == true {
                        permissions.append(BackgroundPermission(type: .other, isEnabled: true, description: "Sudden Termination"))
                    }

                    if infoPlist["NSRequiresAquaSystemAppearance"] != nil {
                        // Not a background mode, just skip
                    }

                    // Only add if there are background permissions
                    if !permissions.isEmpty {
                        let appName = (url.lastPathComponent as NSString).deletingPathExtension

                        items.append(BackgroundActivityItem(
                            appName: appName,
                            bundleIdentifier: bundleID,
                            path: url,
                            isEnabled: true,
                            permissionCount: permissions.count,
                            permissions: permissions
                        ))
                    }
                }
            }
        }

        return items
    }

    private func parseBackgroundMode(_ mode: String) -> BackgroundPermission {
        switch mode {
        case "fetch", "processing":
            return BackgroundPermission(type: .backgroundRefresh, isEnabled: true, description: mode)
        case "location":
            return BackgroundPermission(type: .location, isEnabled: true, description: mode)
        case "audio":
            return BackgroundPermission(type: .audio, isEnabled: true, description: mode)
        case "bluetooth-central", "bluetooth-peripheral":
            return BackgroundPermission(type: .bluetooth, isEnabled: true, description: mode)
        case "remote-notification":
            return BackgroundPermission(type: .notifications, isEnabled: true, description: mode)
        default:
            return BackgroundPermission(type: .other, isEnabled: true, description: mode)
        }
    }

    // MARK: - Helper Methods

    private func findAppBundle(for bundleID: String) -> URL? {
        // Use Workspace to find the app
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return appURL
        }

        // Fallback: search in common directories
        let searchPaths = [
            "/Applications",
            NSHomeDirectory() + "/Applications",
            "/System/Applications"
        ]

        for path in searchPaths {
            if let apps = try? FileManager.default.contentsOfDirectory(atPath: path) {
                for app in apps where app.hasSuffix(".app") {
                    let appPath = (path as NSString).appendingPathComponent(app)
                    if let bundle = Bundle(path: appPath),
                       bundle.bundleIdentifier == bundleID {
                        return URL(fileURLWithPath: appPath)
                    }
                }
            }
        }

        return nil
    }

    // MARK: - Management Actions

    /// Toggle background activity permission for an app
    public func setBackgroundActivity(_ item: BackgroundActivityItem, enabled: Bool) async throws {
        // Implementation for toggling background activity
        // This requires modifying the backgroundtaskmanagement plist
        errorMessage = "Toggle not yet implemented"
    }

    /// Remove all background permissions for an app
    public func removeBackgroundPermissions(for bundleID: String) async throws {
        let path = NSHomeDirectory() + "/Library/Preferences/com.apple.backgroundtaskmanagement.plist"

        guard var data = FileManager.default.contents(atPath: path),
              var plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            throw BackgroundActivityError.fileNotFound
        }

        // Remove the bundle ID from permitted identifiers
        if var permittedIds = plist["BGTaskSchedulerPermittedIdentifiers"] as? [String: [String]] {
            permittedIds.removeValue(forKey: bundleID)
            plist["BGTaskSchedulerPermittedIdentifiers"] = permittedIds

            // Write back
            if let newData = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0) {
                try newData.write(to: URL(fileURLWithPath: path))
            }
        }
    }
}

// MARK: - Errors

enum BackgroundActivityError: Error, LocalizedError {
    case fileNotFound
    case accessDenied
    case invalidFormat

    var errorDescription: String? {
        switch self {
        case .fileNotFound: return "Background task management file not found"
        case .accessDenied: return "Access denied - insufficient permissions"
        case .invalidFormat: return "Invalid background activity data format"
        }
    }
}
