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

        items = await fetchModernLoginItems()

        await MainActor.run {
            self.loginItems = items
            self.isLoading = false
        }
    }

    // MARK: - Modern Login Items (macOS 13+)

    /// There is no public API to enumerate *other* apps' login items on
    /// modern macOS (the BTM database needs root). What CAN be enumerated
    /// honestly: apps that embed an `SMLoginItemSetEnabled` helper at
    /// `Contents/Library/LoginItems` — the standard mechanism apps use to
    /// run at login.
    private func fetchModernLoginItems() async -> [LoginItem] {
        var items: [LoginItem] = []
        let appDirectories = [
            "/Applications",
            NSHomeDirectory() + "/Applications",
        ]

        for directory in appDirectories {
            guard let apps = try? FileManager.default.contentsOfDirectory(atPath: directory) else { continue }
            for app in apps where app.hasSuffix(".app") {
                let appURL = URL(fileURLWithPath: (directory as NSString).appendingPathComponent(app))
                let helpersDir = appURL.appendingPathComponent("Contents/Library/LoginItems")
                guard let helpers = try? FileManager.default.contentsOfDirectory(atPath: helpersDir.path),
                      helpers.contains(where: { $0.hasSuffix(".app") })
                else { continue }

                let name = (app as NSString).deletingPathExtension
                let bundleID = getBundleIdentifier(for: appURL) ?? name
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
        return items
    }

    // MARK: - Fetch Launch Services (Agents/Daemons)

    /// Fetch all launch agents and daemons
    public func fetchLaunchServices() async {
        isLoading = true
        errorMessage = nil

        var services: [LaunchService] = []

        // One launchctl invocation for the whole pass; per-plist spawning was
        // dozens of process launches on the main actor.
        let loadedLabels = await Self.loadedLaunchdLabels()

        // User launch agents
        let userAgentsPath = NSHomeDirectory() + "/Library/LaunchAgents"
        services.append(contentsOf: await scanLaunchServices(at: userAgentsPath, type: .agent, loadedLabels: loadedLabels))

        // Global launch agents
        let globalAgentsPath = "/Library/LaunchAgents"
        services.append(contentsOf: await scanLaunchServices(at: globalAgentsPath, type: .agent, loadedLabels: loadedLabels))

        // Global launch daemons
        let daemonsPath = "/Library/LaunchDaemons"
        services.append(contentsOf: await scanLaunchServices(at: daemonsPath, type: .daemon, loadedLabels: loadedLabels))

        await MainActor.run {
            self.launchServices = services
            self.isLoading = false
        }
    }

    private func scanLaunchServices(
        at path: String,
        type: LaunchService.LaunchServiceType,
        loadedLabels: Set<String>
    ) async -> [LaunchService] {
        var services: [LaunchService] = []

        guard FileManager.default.fileExists(atPath: path) else { return services }

        if let contents = try? FileManager.default.contentsOfDirectory(atPath: path) {
            for item in contents where item.hasSuffix(".plist") {
                let fullPath = (path as NSString).appendingPathComponent(item)
                let url = URL(fileURLWithPath: fullPath)

                // Read the plist to get service info
                if let plist = readPlist(at: url) {
                    let label = plist["Label"] as? String ?? (item as NSString).deletingPathExtension
                    let isEnabled = loadedLabels.contains(label)
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

    /// All labels currently loaded into the user's launchd session.
    private nonisolated static func loadedLaunchdLabels() async -> Set<String> {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
                process.arguments = ["list"]
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = Pipe()

                do {
                    try process.run()
                    process.waitUntilExit()
                } catch {
                    continuation.resume(returning: [])
                    return
                }

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                guard let output = String(data: data, encoding: .utf8) else {
                    continuation.resume(returning: [])
                    return
                }
                // Format: PID\tStatus\tLabel — label is the third column.
                let labels = output.split(separator: "\n").dropFirst().compactMap { line -> String? in
                    let columns = line.split(separator: "\t")
                    return columns.count >= 3 ? String(columns[2]) : nil
                }
                continuation.resume(returning: Set(labels))
            }
        }
    }

    // MARK: - Helper Methods

    private func getBundleIdentifier(for url: URL) -> String? {
        guard let bundle = Bundle(url: url) else { return nil }
        return bundle.bundleIdentifier
    }

    private func readPlist(at url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return nil
        }
        return plist
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
