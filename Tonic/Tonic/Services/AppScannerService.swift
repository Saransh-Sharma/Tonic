//
//  AppScannerService.swift
//  Tonic
//
//  Persistent app cache and background scanner for app discovery.
//

import Foundation

// MARK: - App Cache

/// Persistent cache for app scan results
@Observable
final class AppCache: Sendable {
    private let cacheURL: URL

    static let shared = AppCache()

    private init() {
        let fileManager = FileManager.default
        let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.cacheURL = cacheDir.appendingPathComponent("com.pretonic.tonic/appcache.json")
    }

    func loadCachedApps() -> [CachedAppData] {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: cacheURL.path),
              let data = try? Data(contentsOf: cacheURL),
              let cached = try? JSONDecoder().decode([CachedAppData].self, from: data) else {
            return []
        }
        // Filter out apps that no longer exist
        return cached.filter { cached in
            fileManager.fileExists(atPath: cached.path)
        }
    }

    func saveApps(_ apps: [AppMetadata]) {
        let cachedData = apps.map { CachedAppData(from: $0) }
        guard let data = try? JSONEncoder().encode(cachedData) else { return }
        try? data.write(to: cacheURL)
    }
}

/// Lightweight cached app data
struct CachedAppData: Codable, Sendable {
    let id: UUID
    let name: String
    let path: String
    let bundleIdentifier: String
    let version: String
    let icon: Data?
    let totalSize: Int64
    let category: String
    let installDate: Date
    let lastUsed: Date?
    let itemType: String

    init(from app: AppMetadata) {
        self.id = app.id
        self.name = app.appName
        self.path = app.path.path
        self.bundleIdentifier = app.bundleIdentifier
        self.version = app.version ?? "Unknown"
        self.icon = nil
        self.totalSize = app.totalSize
        self.category = app.category.rawValue
        self.installDate = app.installDate ?? Date()
        self.lastUsed = app.lastUsed
        self.itemType = app.itemType
    }

    func toAppMetadata() -> AppMetadata? {
        guard let url = URL(string: path) else { return nil }
        return AppMetadata(
            bundleIdentifier: bundleIdentifier,
            appName: name,
            path: url,
            version: version,
            totalSize: totalSize,
            category: AppMetadata.AppCategory(rawValue: category) ?? .other,
            itemType: itemType
        )
    }
}

// MARK: - Background App Scanner

/// Background scanner for apps without blocking UI
final class BackgroundAppScanner: @unchecked Sendable {
    private let fileManager = FileManager.default
    private var scanTask: Task<Void, Never>?

    func cancelScan() {
        scanTask?.cancel()
    }

    /// Fast scan - just discovers apps without calculating sizes
    func scanAppsFast() async -> [FastAppData] {
        let appDirectories = [
            "/Applications",
            NSHomeDirectory() + "/Applications"
        ]

        let prefPaneDirectories = [
            "/Library/PreferencePanes",
            NSHomeDirectory() + "/Library/PreferencePanes"
        ]

        let libraryDirectories = [
            "/Library",
            NSHomeDirectory() + "/Library"
        ]

        let loginItemPaths = [
            NSHomeDirectory() + "/Library/LaunchAgents",
            "/Library/LaunchAgents",
            "/Library/LaunchDaemons"
        ]

        var apps: [FastAppData] = []
        var seenPaths = Set<String>()

        // Scan for .app bundles
        for directory in appDirectories {
            if Task.isCancelled { break }
            if let result = await scanDirectory(directory, extensions: ["app"], seenPaths: &seenPaths) {
                apps.append(contentsOf: result)
            }
        }

        // Scan for preference panes
        for directory in prefPaneDirectories {
            if Task.isCancelled { break }
            if let result = await scanDirectory(directory, extensions: ["prefPane"], seenPaths: &seenPaths) {
                apps.append(contentsOf: result)
            }
        }

        // Scan for frameworks and other library items
        for directory in libraryDirectories {
            if Task.isCancelled { break }
            let frameworkPaths = [
                directory + "/Frameworks",
                directory + "/Application Support",
                directory + "/Spotlight"
            ]
            for path in frameworkPaths {
                if Task.isCancelled { break }
                if fileManager.fileExists(atPath: path) {
                    if let result = await scanDirectory(path, extensions: ["framework", "mdimporter", "qlgenerator"], seenPaths: &seenPaths) {
                        apps.append(contentsOf: result)
                    }
                }
            }
        }

        // Scan for login items and background agents
        for path in loginItemPaths {
            if Task.isCancelled { break }
            if fileManager.fileExists(atPath: path) {
                if let result = await scanDirectory(path, extensions: ["app"], seenPaths: &seenPaths, forceType: .loginItems) {
                    apps.append(contentsOf: result)
                }
                if let plistContents = try? fileManager.contentsOfDirectory(atPath: path) {
                    for item in plistContents where item.hasSuffix(".plist") {
                        if Task.isCancelled { break }
                        let fullPath = (path as NSString).appendingPathComponent(item)
                        if !seenPaths.contains(fullPath) {
                            seenPaths.insert(fullPath)
                            let itemName = (item as NSString).deletingPathExtension
                            let appData = FastAppData(
                                name: itemName,
                                path: fullPath,
                                bundleIdentifier: itemName,
                                version: "1.0",
                                installDate: Date(),
                                category: .other,
                                totalSize: 0,
                                itemType: .loginItems
                            )
                            apps.append(appData)
                        }
                    }
                }
            }
        }

        // Scan for app extensions inside .app bundles
        let extensions = await scanAppExtensions(in: appDirectories, seenPaths: &seenPaths)
        apps.append(contentsOf: extensions)

        return apps
    }

    /// Scan for app extensions (.appex) inside application bundles
    private func scanAppExtensions(in directories: [String], seenPaths: inout Set<String>) async -> [FastAppData] {
        var extensions: [FastAppData] = []

        for directory in directories {
            if Task.isCancelled { break }
            guard fileManager.fileExists(atPath: directory) else { continue }
            guard let appContents = try? fileManager.contentsOfDirectory(atPath: directory) else { continue }

            for item in appContents {
                if Task.isCancelled { break }
                guard item.hasSuffix(".app") else { continue }

                let appURL = URL(fileURLWithPath: directory).appendingPathComponent(item)
                let appPath = appURL.path
                if seenPaths.contains(appPath) { continue }

                let extensionDirs = [
                    appURL.appendingPathComponent("Contents/PlugIns"),
                    appURL.appendingPathComponent("Contents/Extensions"),
                    appURL.appendingPathComponent("Contents/Library/Spotlight"),
                    appURL.appendingPathComponent("Contents/Library/QuickLook")
                ]

                for extDirURL in extensionDirs {
                    if Task.isCancelled { break }
                    guard fileManager.fileExists(atPath: extDirURL.path) else { continue }

                    if let extContents = try? fileManager.contentsOfDirectory(atPath: extDirURL.path) {
                        for extItem in extContents {
                            if Task.isCancelled { break }

                            let extURL = extDirURL.appendingPathComponent(extItem)
                            let extPath = extURL.path

                            if seenPaths.contains(extPath) { continue }
                            seenPaths.insert(extPath)

                            guard extURL.pathExtension == "appex" else { continue }

                            if let extData = await readAppExtensionMetadata(extURL) {
                                extensions.append(extData)
                            }
                        }
                    }
                }
            }
        }

        return extensions
    }

    /// Read metadata for an .appex bundle with fallback for when Bundle() fails
    private func readAppExtensionMetadata(_ url: URL) async -> FastAppData? {
        if let bundle = Bundle(url: url),
           let info = bundle.infoDictionary {
            let name = info["CFBundleName"] as? String
                ?? info["CFBundleDisplayName"] as? String
                ?? url.deletingPathExtension().lastPathComponent

            let bundleID = bundle.bundleIdentifier ?? ""
            let version = info["CFBundleVersion"] as? String
                ?? info["CFBundleShortVersionString"] as? String

            let installDate = (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate
            let categoryRaw = info["LSApplicationCategoryType"] as? String ?? "other"
            let category = appCategory(from: categoryRaw)

            return FastAppData(
                name: name,
                path: url.path,
                bundleIdentifier: bundleID.isEmpty ? url.lastPathComponent : bundleID,
                version: version ?? "Unknown",
                installDate: installDate ?? Date(),
                category: category,
                totalSize: 0,
                itemType: .appExtensions
            )
        }

        let name = url.deletingPathExtension().lastPathComponent
        return FastAppData(
            name: name,
            path: url.path,
            bundleIdentifier: name,
            version: "Unknown",
            installDate: (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date(),
            category: .other,
            totalSize: 0,
            itemType: .appExtensions
        )
    }

    /// Scan a directory for items with specific extensions
    private func scanDirectory(_ directory: String, extensions: [String], seenPaths: inout Set<String>, forceType: ItemType? = nil) async -> [FastAppData]? {
        guard fileManager.fileExists(atPath: directory) else { return nil }

        var items: [FastAppData] = []

        if let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: directory),
            includingPropertiesForKeys: [.isApplicationKey],
            options: [.skipsHiddenFiles]
        ) {
            while let url = enumerator.nextObject() as? URL {
                if Task.isCancelled { break }

                let path = url.path
                if seenPaths.contains(path) { continue }
                seenPaths.insert(path)

                if extensions.contains(url.pathExtension) {
                    if let itemData = await readAppMetadataFast(url, forceType: forceType) {
                        items.append(itemData)
                    }
                }
            }
        }

        return items
    }

    /// Calculate sizes for apps using du command (much faster)
    func calculateSizes(for paths: [String]) async -> [String: Int64] {
        var sizes: [String: Int64] = [:]

        await withTaskGroup(of: (String, Int64?).self) { group in
            for path in paths {
                if Task.isCancelled { break }

                group.addTask {
                    return (path, await self.getSizeUsingDu(path))
                }
            }

            for await (path, size) in group {
                if let size = size {
                    sizes[path] = size
                }
            }
        }

        return sizes
    }

    private func getItemType(for url: URL, info: [String: Any]) -> ItemType {
        let bundleID = (info["CFBundleIdentifier"] as? String) ?? ""
        let pathExtension = url.pathExtension.lowercased()

        if pathExtension == "prefpane" { return .preferencePanes }
        if pathExtension == "appex" || info["NSExtension"] != nil { return .appExtensions }
        if pathExtension == "framework" { return .frameworks }
        if pathExtension == "qlgenerator" { return .quickLookPlugins }
        if pathExtension == "mdimporter" { return .spotlightImporters }

        if pathExtension == "app" {
            let hasMainNib = info["NSMainNibFile"] != nil
            let hasPrincipalClass = info["NSPrincipalClass"] != nil
            let isGUIApp = info["CFBundlePackageType"] as? String == "APPL"

            if hasMainNib || hasPrincipalClass || isGUIApp {
                let name = url.lastPathComponent.lowercased()
                if name.contains("helper") && !name.contains("app") {
                    return .systemUtilities
                }
                return .apps
            }
            return .systemUtilities
        }

        if bundleID.lowercased().contains("spotlight") { return .spotlightImporters }
        if bundleID.lowercased().contains("quicklook") { return .quickLookPlugins }
        if bundleID.lowercased().contains("framework") || bundleID.lowercased().contains("runtime") { return .frameworks }

        let path = url.path.lowercased()
        if path.contains("/launchagents/") || path.contains("/launchdaemons/") { return .loginItems }

        if path.contains("/system/") || path.contains("/library/") {
            if path.contains("/frameworks/") { return .frameworks }
            if path.contains("/preferencepanes/") { return .preferencePanes }
            if path.contains("/spotlight/") { return .spotlightImporters }
            if path.contains("/quicklook/") { return .quickLookPlugins }
        }

        if pathExtension == "app" { return .apps }
        return .systemUtilities
    }

    private func readAppMetadataFast(_ url: URL, forceType: ItemType? = nil) async -> FastAppData? {
        if url.pathExtension.lowercased() == "plist" {
            let name = url.deletingPathExtension().lastPathComponent
            return FastAppData(
                name: name,
                path: url.path,
                bundleIdentifier: name,
                version: "1.0",
                installDate: (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date(),
                category: .other,
                totalSize: 0,
                itemType: forceType ?? .loginItems
            )
        }

        guard let bundle = Bundle(url: url),
              let info = bundle.infoDictionary else {
            return nil
        }

        let name = info["CFBundleName"] as? String
            ?? info["CFBundleDisplayName"] as? String
            ?? url.deletingPathExtension().lastPathComponent

        let bundleID = bundle.bundleIdentifier ?? ""
        let version = info["CFBundleVersion"] as? String
            ?? info["CFBundleShortVersionString"] as? String

        let installDate = (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate
        let categoryRaw = info["LSApplicationCategoryType"] as? String ?? "other"
        let category = appCategory(from: categoryRaw)
        let itemType = forceType ?? getItemType(for: url, info: info)

        return FastAppData(
            name: name,
            path: url.path,
            bundleIdentifier: bundleID,
            version: version ?? "Unknown",
            installDate: installDate ?? Date(),
            category: category,
            totalSize: 0,
            itemType: itemType
        )
    }

    func appCategory(from rawValue: String) -> AppMetadata.AppCategory {
        switch rawValue {
        case "public.app-category.developer-tools": return .development
        case "public.app-category.productivity": return .productivity
        case "public.app-category.creative-software", "public.app-category.photography": return .creativity
        case "public.app-category.social-networking": return .social
        case "public.app-category.games": return .games
        case "public.app-category.entertainment": return .entertainment
        case "public.app-category.utilities": return .utilities
        case "public.app-category.business": return .business
        case "public.app-category.education": return .education
        case "public.app-category.finance": return .finance
        case "public.app-category.health-fitness", "public.app-category.medical": return .health
        case "public.app-category.news": return .news
        case "public.app-category.weather": return .weather
        case "public.app-category.travel": return .travel
        case "public.app-category.lifestyle": return .lifestyle
        case "public.app-category.reference": return .reference
        case "public.app-category.security": return .security
        case "public.app-category.communication": return .communication
        default: return .other
        }
    }

    private func getSizeUsingDu(_ path: String) async -> Int64? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/du")
        process.arguments = ["-sk", path]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let timeoutTask = Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                process.terminate()
            }

            guard let data = try? pipe.fileHandleForReading.readToEnd(),
                  let output = String(data: data, encoding: .utf8) else {
                timeoutTask.cancel()
                return nil
            }

            timeoutTask.cancel()

            let parts = output.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            if let kb = Int64(parts.first ?? "0") {
                return kb * 1024
            }
        } catch {
            return nil
        }

        return nil
    }
}
