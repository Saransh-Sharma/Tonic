//
//  LoginItemsManager.swift
//  Tonic
//
//  Service for reading macOS login items using ServiceManagement framework
//

import Foundation
import ServiceManagement

/// Manager for fetching and managing macOS login items
@MainActor
@Observable
final class LoginItemsManager: @unchecked Sendable {
    public static let shared = LoginItemsManager()

    private init() {}

    // MARK: - Published Properties

    public private(set) var loginItems: [LoginItem] = []
    public private(set) var launchServices: [LaunchService] = []
    public var isLoading = false
    public var errorMessage: String?

    // MARK: - Fetch Login Items

    /// Fetch all user login items (apps that launch at login)
    public func fetchLoginItems() async {
        isLoading = true
        errorMessage = nil

        var items: [LoginItem] = []

        // Try modern ServiceManagement API first (macOS 13+)
        if #available(macOS 13.0, *) {
            items = await fetchModernLoginItems()
        }

        // Fall back to legacy method if needed
        if items.isEmpty {
            items = await fetchLegacyLoginItems()
        }

        await MainActor.run {
            self.loginItems = items
            self.isLoading = false
        }
    }

    // MARK: - Modern Login Items (macOS 13+)

    @available(macOS 13.0, *)
    private func fetchModernLoginItems() async -> [LoginItem] {
        let _: [LoginItem] = []

        // SMAppService is the modern way to get login items
        // However, we need to use a different approach since SMAppService.loginItemIdentifier
        // requires the app to be registered as a login item

        // Instead, we'll read from the shared file list
        if URL(string: "file:///Library/Managed Preferences/com.apple.loginitems.plist") != nil {
            // This may not exist for all users
        }

        // Use LSSharedFileList approach as fallback
        return await fetchLegacyLoginItems()
    }

    // MARK: - Legacy Login Items

    private func fetchLegacyLoginItems() async -> [LoginItem] {
        var items: [LoginItem] = []

        // Use LSSharedFileList to read login items
        // This requires accessing the LoginItems list via Carbon/CoreServices

        // For now, read from the plist file directly as a fallback
        let loginItemsPath = NSHomeDirectory() + "/Library/Preferences/com.apple.loginitems.plist"

        if let plistData = FileManager.default.contents(atPath: loginItemsPath),
           let plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any] {

            // The structure can vary, but typically contains:
            // - "AutoLaunchedApplicationDictionary" - array of login items
            if let loginItemsArray = plist["AutoLaunchedApplicationDictionary"] as? [[String: Any]] {
                for item in loginItemsArray {
                    if let path = item["Path"] as? String,
                       let hidden = item["Hide"] as? Bool {
                        let url = URL(fileURLWithPath: path)
                        let name = url.lastPathComponent
                        let bundleID = getBundleIdentifier(for: url) ?? name

                        items.append(LoginItem(
                            name: name,
                            path: url,
                            bundleIdentifier: bundleID,
                            isHidden: hidden,
                            itemType: path.hasSuffix(".app") ? .application : .file,
                            isEnabled: true
                        ))
                    }
                }
            }
        }

        // Also scan for .app bundles that might have login items configured
        // This is a fallback for apps that don't appear in the shared file list
        let appDirectories = [
            "/Applications",
            NSHomeDirectory() + "/Applications"
        ]

        for directory in appDirectories {
            if let apps = try? FileManager.default.contentsOfDirectory(atPath: directory) {
                for app in apps where app.hasSuffix(".app") {
                    let appPath = (directory as NSString).appendingPathComponent(app)
                    let appURL = URL(fileURLWithPath: appPath)

                    // Check if this app has a login item flag set
                    if hasLoginItemFlag(for: appURL) {
                        let name = (app as NSString).deletingPathExtension
                        let bundleID = getBundleIdentifier(for: appURL) ?? name

                        // Avoid duplicates
                        if !items.contains(where: { $0.bundleIdentifier == bundleID }) {
                            items.append(LoginItem(
                                name: name,
                                path: appURL,
                                bundleIdentifier: bundleID,
                                isHidden: false,
                                itemType: .application,
                                isEnabled: true
                            ))
                        }
                    }
                }
            }
        }

        return items
    }

    // MARK: - Fetch Launch Services (Agents/Daemons)

    /// Fetch all launch agents and daemons
    public func fetchLaunchServices() async {
        isLoading = true
        errorMessage = nil

        var services: [LaunchService] = []

        // User launch agents
        let userAgentsPath = NSHomeDirectory() + "/Library/LaunchAgents"
        services.append(contentsOf: await scanLaunchServices(at: userAgentsPath, type: .agent))

        // Global launch agents
        let globalAgentsPath = "/Library/LaunchAgents"
        services.append(contentsOf: await scanLaunchServices(at: globalAgentsPath, type: .agent))

        // Global launch daemons
        let daemonsPath = "/Library/LaunchDaemons"
        services.append(contentsOf: await scanLaunchServices(at: daemonsPath, type: .daemon))

        await MainActor.run {
            self.launchServices = services
            self.isLoading = false
        }
    }

    private func scanLaunchServices(at path: String, type: LaunchService.LaunchServiceType) async -> [LaunchService] {
        var services: [LaunchService] = []

        guard FileManager.default.fileExists(atPath: path) else { return services }

        if let contents = try? FileManager.default.contentsOfDirectory(atPath: path) {
            for item in contents where item.hasSuffix(".plist") {
                let fullPath = (path as NSString).appendingPathComponent(item)
                let url = URL(fileURLWithPath: fullPath)

                // Read the plist to get service info
                if let plist = readPlist(at: url) {
                    let label = plist["Label"] as? String ?? (item as NSString).deletingPathExtension
                    let isEnabled = isServiceEnabled(label: label)
                    let runAtLoad = plist["RunAtLoad"] as? Bool ?? false

                    services.append(LaunchService(
                        name: label,
                        path: url,
                        bundleIdentifier: label,
                        serviceType: type,
                        isEnabled: isEnabled,
                        runAtLoad: runAtLoad
                    ))
                }
            }
        }

        return services
    }

    // MARK: - Helper Methods

    private func getBundleIdentifier(for url: URL) -> String? {
        guard let bundle = Bundle(url: url) else { return nil }
        return bundle.bundleIdentifier
    }

    private func hasLoginItemFlag(for url: URL) -> Bool {
        // Check if the app is registered as a login item
        // This is a simplified check - the actual verification requires ServiceManagement APIs

        // For now, return false to avoid false positives
        // The real implementation would use SMAppService
        return false
    }

    private func readPlist(at url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return nil
        }
        return plist
    }

    private func isServiceEnabled(label: String) -> Bool {
        // Check if the service is currently loaded using launchctl
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["list", label]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            // If exit code is 0, the service is loaded
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    // MARK: - Management Actions

    /// Load a launch service
    public func loadLaunchService(_ service: LaunchService) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["load", service.path.path]

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw LoginItemError.failedToLoad
        }
    }

    /// Unload a launch service
    public func unloadLaunchService(_ service: LaunchService) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["unload", service.path.path]

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw LoginItemError.failedToUnload
        }
    }

    /// Delete a launch service plist file
    public func deleteLaunchService(_ service: LaunchService) async throws {
        try FileManager.default.removeItem(at: service.path)
    }
}

// MARK: - Errors

enum LoginItemError: Error, LocalizedError {
    case failedToLoad
    case failedToUnload
    case notFound
    case accessDenied

    var errorDescription: String? {
        switch self {
        case .failedToLoad: return "Failed to load launch service"
        case .failedToUnload: return "Failed to unload launch service"
        case .notFound: return "Login item not found"
        case .accessDenied: return "Access denied - insufficient permissions"
        }
    }
}
