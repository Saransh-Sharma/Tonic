//
//  AppInventory.swift
//  Tonic
//
//  App inventory scanner and manager for discovering installed applications
//  Enhanced with App Manager functionality (fn-1.19) and Update Checker (fn-1.20)
//

import Foundation
import SwiftUI

// MARK: - AppMetadata ActionTableItem Conformance

extension AppMetadata: ActionTableItem {}

// MARK: - App Cache

/// Persistent cache for app scan results
@Observable
final class AppCache: Sendable {
    private let cacheURL: URL
    private let fileManager = FileManager.default

    static let shared = AppCache()

    private init() {
        let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.cacheURL = cacheDir.appendingPathComponent("com.pretonic.tonic/appcache.json")
    }

    func loadCachedApps() -> [CachedAppData] {
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
        self.icon = nil // Icons not stored in current model
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
        // Directories to scan for different item types
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

        // Login items and background agents
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
            // Scan for frameworks in specific subdirectories
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

        // Scan for login items and background agents (.plist files and .app bundles in LaunchAgents/Daemons)
        for path in loginItemPaths {
            if Task.isCancelled { break }
            if fileManager.fileExists(atPath: path) {
                // Scan for .app bundles in launch directories
                if let result = await scanDirectory(path, extensions: ["app"], seenPaths: &seenPaths, forceType: .loginItems) {
                    apps.append(contentsOf: result)
                }
                // Also scan for .plist launch agents/daemons
                if let plistContents = try? fileManager.contentsOfDirectory(atPath: path) {
                    for item in plistContents where item.hasSuffix(".plist") {
                        if Task.isCancelled { break }
                        let fullPath = (path as NSString).appendingPathComponent(item)
                        if !seenPaths.contains(fullPath) {
                            seenPaths.insert(fullPath)

                            // Create metadata for plist-based launch agents
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

            // First, find all .app bundles (non-recursively to avoid deep nesting)
            guard let appContents = try? fileManager.contentsOfDirectory(atPath: directory) else { continue }

            for item in appContents {
                if Task.isCancelled { break }
                guard item.hasSuffix(".app") else { continue }

                let appURL = URL(fileURLWithPath: directory).appendingPathComponent(item)

                // Skip if we've already seen this app
                let appPath = appURL.path
                if seenPaths.contains(appPath) { continue }

                // Look inside the app bundle for extensions in known locations
                let extensionDirs = [
                    appURL.appendingPathComponent("Contents/PlugIns"),
                    appURL.appendingPathComponent("Contents/Extensions"),
                    appURL.appendingPathComponent("Contents/Library/Spotlight"),
                    appURL.appendingPathComponent("Contents/Library/QuickLook")
                ]

                for extDirURL in extensionDirs {
                    if Task.isCancelled { break }
                    guard fileManager.fileExists(atPath: extDirURL.path) else { continue }

                    // Get immediate contents only (non-recursive)
                    if let extContents = try? fileManager.contentsOfDirectory(atPath: extDirURL.path) {
                        for extItem in extContents {
                            if Task.isCancelled { break }

                            let extURL = extDirURL.appendingPathComponent(extItem)
                            let extPath = extURL.path

                            // Skip if already seen
                            if seenPaths.contains(extPath) { continue }
                            seenPaths.insert(extPath)

                            // Only process .appex bundles
                            guard extURL.pathExtension == "appex" else { continue }

                            // Try to read metadata, fall back to basic info if Bundle fails
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
        // Try using Bundle first
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

        // Fallback: Use the filename if Bundle fails
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
            for case let url as URL in enumerator {
                if Task.isCancelled { break }

                let path = url.path
                if seenPaths.contains(path) { continue }
                seenPaths.insert(path)

                // Check if the file has one of the target extensions
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

        // Check by file extension first (most reliable)
        if pathExtension == "prefpane" {
            return .preferencePanes
        }

        if pathExtension == "appex" || info["NSExtension"] != nil {
            return .appExtensions
        }

        if pathExtension == "framework" {
            return .frameworks
        }

        if pathExtension == "qlgenerator" {
            return .quickLookPlugins
        }

        if pathExtension == "mdimporter" {
            return .spotlightImporters
        }

        // For .app bundles, determine if it's a real app or something else
        if pathExtension == "app" {
            // Check if it's actually a GUI application
            let hasMainNib = info["NSMainNibFile"] != nil
            let hasPrincipalClass = info["NSPrincipalClass"] != nil
            let isGUIApp = info["CFBundlePackageType"] as? String == "APPL"

            // Must be a proper GUI app
            if hasMainNib || hasPrincipalClass || isGUIApp {
                // Check if it's a system utility/helper
                let name = url.lastPathComponent.lowercased()
                if name.contains("helper") && !name.contains("app") {
                    return .systemUtilities
                }
                return .apps
            }

            // Not a proper GUI app - likely something else
            return .systemUtilities
        }

        // Check bundle ID patterns for other types
        if bundleID.lowercased().contains("spotlight") {
            return .spotlightImporters
        }

        if bundleID.lowercased().contains("quicklook") {
            return .quickLookPlugins
        }

        if bundleID.lowercased().contains("framework") || bundleID.lowercased().contains("runtime") {
            return .frameworks
        }

        // Check path for login items and background agents FIRST
        let path = url.path.lowercased()
        if path.contains("/launchagents/") || path.contains("/launchdaemons/") {
            return .loginItems
        }

        // Check path for other indicators
        if path.contains("/system/") || path.contains("/library/") {
            // Check if it's in frameworks or other system locations
            if path.contains("/frameworks/") {
                return .frameworks
            }
            if path.contains("/preferencepanes/") {
                return .preferencePanes
            }
            if path.contains("/spotlight/") {
                return .spotlightImporters
            }
            if path.contains("/quicklook/") {
                return .quickLookPlugins
            }
        }

        // Default to apps for .app bundles that made it this far
        if pathExtension == "app" {
            return .apps
        }

        // Default for everything else
        return .systemUtilities
    }

    private func isLaunchableApp(_ url: URL) async -> Bool {
        guard let bundle = Bundle(url: url),
              let info = bundle.infoDictionary else {
            return false
        }

        // Must have a bundle identifier
        guard let bundleID = bundle.bundleIdentifier, !bundleID.isEmpty else {
            return false
        }

        // Must have an executable
        guard let executable = bundle.executablePath,
              fileManager.isExecutableFile(atPath: executable) else {
            return false
        }

        // Must have a display name or executable
        let hasDisplayName = info["CFBundleDisplayName"] != nil ||
                             info["CFBundleName"] != nil ||
                             info["CFBundleExecutable"] != nil

        return hasDisplayName
    }

    private func readAppMetadataFast(_ url: URL, forceType: ItemType? = nil) async -> FastAppData? {
        // For plist files (login items that aren't .app bundles), handle differently
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

        // Get install date (fast check)
        let installDate = (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate

        // Get category
        let categoryRaw = info["LSApplicationCategoryType"] as? String ?? "other"
        let category = appCategory(from: categoryRaw)

        // Determine item type - use forced type if provided, otherwise detect
        let itemType = forceType ?? getItemType(for: url, info: info)

        return FastAppData(
            name: name,
            path: url.path,
            bundleIdentifier: bundleID,
            version: version ?? "Unknown",
            installDate: installDate ?? Date(),
            category: category,
            totalSize: 0, // Will be calculated later
            itemType: itemType
        )
    }

    private func appCategory(from rawValue: String) -> AppMetadata.AppCategory {
        // Map LSApplicationCategoryType to our categories
        switch rawValue {
        case "public.app-category.developer-tools":
            return .development
        case "public.app-category.productivity":
            return .productivity
        case "public.app-category.creative-software", "public.app-category.photography":
            return .creativity
        case "public.app-category.social-networking":
            return .social
        case "public.app-category.games":
            return .games
        case "public.app-category.entertainment":
            return .entertainment
        case "public.app-category.utilities":
            return .utilities
        case "public.app-category.business":
            return .business
        case "public.app-category.education":
            return .education
        case "public.app-category.finance":
            return .finance
        case "public.app-category.health-fitness":
            return .health
        case "public.app-category.news":
            return .news
        case "public.app-category.weather":
            return .weather
        case "public.app-category.travel":
            return .travel
        case "public.app-category.lifestyle":
            return .lifestyle
        case "public.app-category.reference":
            return .reference
        case "public.app-category.medical":
            return .health
        case "public.app-category.security":
            return .security
        case "public.app-category.communication":
            return .communication
        default:
            return .other
        }
    }

    private func getSizeUsingDu(_ path: String) async -> Int64? {
        // Use du command for fast size calculation
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/du")
        process.arguments = ["-sk", path]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let timeoutTask = Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds timeout
                process.terminate()
            }

            guard let data = try? pipe.fileHandleForReading.readToEnd(),
                  let output = String(data: data, encoding: .utf8) else {
                timeoutTask.cancel()
                return nil
            }

            timeoutTask.cancel()

            // Parse output: "12345\tpath"
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

/// Item type classification
enum ItemType: String, CaseIterable, Identifiable {
    case apps = "Apps"
    case appExtensions = "App Extensions"
    case preferencePanes = "Preference Panes"
    case quickLookPlugins = "Quick Look Plugins"
    case spotlightImporters = "Spotlight Importers"
    case frameworks = "Frameworks & Runtimes"
    case systemUtilities = "System Utilities"
    case loginItems = "Login Items & Agents"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .apps: return "app.fill"
        case .appExtensions: return "puzzlepiece.extension"
        case .preferencePanes: return "slider.horizontal.3"
        case .quickLookPlugins: return "eye"
        case .spotlightImporters: return "magnifyingglass"
        case .frameworks: return "cube.box"
        case .systemUtilities: return "wrench.and.screwdriver"
        case .loginItems: return "person.2"
        }
    }
}

/// Quick filter categories for items
enum QuickFilterCategory: String, CaseIterable, Identifiable {
    case all = "All"
    case leastUsed = "Least Used"
    case development = "Development"
    case games = "Games"
    case productivity = "Productivity"
    case utilities = "Utilities"
    case social = "Social"
    case creative = "Creative"
    case other = "Other"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .leastUsed: return "clock.arrow.circlepath"
        case .development: return "hammer"
        case .games: return "gamecontroller"
        case .productivity: return "checkmark.circle"
        case .utilities: return "wrench.and.screwdriver"
        case .social: return "person.2"
        case .creative: return "paintbrush"
        case .other: return "ellipsis"
        }
    }
}

/// Quick filter specifically for login items
enum LoginItemFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case launchAgents = "Launch Agents"
    case daemons = "Daemons"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .launchAgents: return "gear.circle.fill"
        case .daemons: return "gearshape.2.fill"
        }
    }
}

/// Fast app data without size
struct FastAppData: Sendable {
    let name: String
    let path: String
    let bundleIdentifier: String
    let version: String
    let installDate: Date
    let category: AppMetadata.AppCategory
    var totalSize: Int64
    let itemType: ItemType
}

// MARK: - App Inventory Service

@MainActor
class AppInventoryService: ObservableObject {
    @Published var apps: [AppMetadata] = []
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var progress: Double = 0
    @Published var searchText = ""
    @Published var sortOption: SortOption = .sizeDescending
    @Published var selectedTab: ItemType = .apps
    @Published var quickFilterCategory: QuickFilterCategory = .all
    @Published var loginItemFilter: LoginItemFilter = .all
    @Published var selectedAppIDs: Set<UUID> = []
    @Published var isSelecting = false
    @Published var isUninstalling = false
    @Published var uninstallProgress: Double = 0
    @Published var isCheckingUpdates = false
    @Published var availableUpdates: Int = 0
    @Published var appsWithUpdates: Set<String> = []
    @Published var errorMessage: String?
    @Published var lastScanDate: Date?

    // New: Login items and background activities
    @Published var loginItems: [LoginItem] = []
    @Published var launchServices: [LaunchService] = []
    @Published var backgroundActivities: [BackgroundActivityItem] = []

    private let updater = AppUpdater.shared
    let cache = AppCache.shared
    private let scanner = BackgroundAppScanner()
    let fileOps = FileOperations.shared
    private let loginItemsManager = LoginItemsManager.shared
    private let backgroundActivityManager = BackgroundActivityManager.shared

    private var scanTask: Task<Void, Never>?
    private(set) var hasScannedThisSession = false  // Track if we've scanned in this session

    // MARK: - Singleton

    public static let shared = AppInventoryService()

    private init() {
        // Load cached apps immediately on init
        loadCachedApps()
    }

    enum SortOption: String, CaseIterable {
        case nameAscending = "Name (A-Z)"
        case nameDescending = "Name (Z-A)"
        case sizeDescending = "Size (Largest First)"
        case sizeAscending = "Size (Smallest First)"
        case category = "Category"
        case dateInstalled = "Install Date"
        case lastUsed = "Last Used"
        case updateStatus = "Update Status"
    }

    var isSelectionActive: Bool {
        !selectedAppIDs.isEmpty || isSelecting
    }

    var selectedApps: [AppMetadata] {
        apps.filter { selectedAppIDs.contains($0.id) }
    }

    var selectedSize: Int64 {
        selectedApps.reduce(0) { $0 + $1.totalSize }
    }

    // MARK: - Loading

    private func loadCachedApps() {
        let cachedApps = cache.loadCachedApps()
        if !cachedApps.isEmpty {
            apps = cachedApps.compactMap { $0.toAppMetadata() }
            lastScanDate = getCachedScanDate()
            hasScannedThisSession = true  // We have data from cache, consider as scanned
        }
    }

    private func getCachedScanDate() -> Date? {
        let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("com.pretonic.tonic/appcache.json")
        guard let path = cacheURL?.path,
              let attributes = try? FileManager.default.attributesOfItem(atPath: path) else {
            return nil
        }
        return attributes[.modificationDate] as? Date
    }

    // MARK: - Scanning

    func scanApps() async {
        // Cancel any existing scan
        scanTask?.cancel()

        // Show cached apps immediately while scanning
        if apps.isEmpty {
            loadCachedApps()
        }

        scanTask = Task {
            await performFastScan()
        }

        await scanTask?.value
    }

    func refreshSizes() async {
        // Refresh only sizes in background without disrupting UI
        guard !apps.isEmpty else { return }

        isRefreshing = true
        defer { isRefreshing = false }

        let paths = apps.map { $0.path.path }
        let sizes = await scanner.calculateSizes(for: paths)

        // Create new instances with updated sizes
        apps = apps.map { app in
            let size = sizes[app.path.path] ?? app.totalSize
            return AppMetadata(
                bundleIdentifier: app.bundleIdentifier,
                appName: app.appName,
                path: app.path,
                version: app.version,
                totalSize: size,
                installDate: app.installDate,
                category: app.category,
                itemType: app.itemType
            )
        }

        // Save updated cache
        cache.saveApps(apps)
    }

    // Helper to map ItemType to string for storage
    private func mapItemTypeToString(_ type: ItemType) -> String {
        switch type {
        case .apps: return "app"
        case .appExtensions: return "extension"
        case .preferencePanes: return "prefPane"
        case .quickLookPlugins: return "quicklook"
        case .spotlightImporters: return "spotlight"
        case .frameworks: return "framework"
        case .systemUtilities: return "system"
        case .loginItems: return "login"
        }
    }

    func cancelScan() {
        scanTask?.cancel()
        scanner.cancelScan()
        isLoading = false
        isRefreshing = false
        errorMessage = "Scan cancelled"
    }

    private func performFastScan() async {
        isLoading = true
        errorMessage = nil
        progress = 0

        // Phase 1: Fast scan - just discover apps
        let fastApps = await scanner.scanAppsFast()

        guard !Task.isCancelled else {
            isLoading = false
            return
        }

        // Convert to AppMetadata with placeholder sizes
        var tempApps: [AppMetadata] = fastApps.map { fast in
            AppMetadata(
                bundleIdentifier: fast.bundleIdentifier,
                appName: fast.name,
                path: URL(fileURLWithPath: fast.path),
                version: fast.version,
                totalSize: 0,
                installDate: fast.installDate,
                category: fast.category,
                itemType: mapItemTypeToString(fast.itemType)
            )
        }

        progress = 0.5

        // Update UI immediately with discovered apps (no sizes yet)
        apps = tempApps
        isLoading = false
        isRefreshing = true

        // Phase 2: Calculate sizes in background
        let paths = tempApps.map { $0.path.path }
        let sizes = await scanner.calculateSizes(for: paths)

        // Create new instances with updated sizes
        tempApps = tempApps.map { app in
            let size = sizes[app.path.path] ?? 0
            return AppMetadata(
                bundleIdentifier: app.bundleIdentifier,
                appName: app.appName,
                path: app.path,
                version: app.version,
                totalSize: size,
                installDate: app.installDate,
                category: app.category,
                itemType: app.itemType
            )
        }

        guard !Task.isCancelled else {
            isRefreshing = false
            return
        }

        apps = tempApps
        isRefreshing = false
        progress = 1.0
        lastScanDate = Date()
        hasScannedThisSession = true  // Mark that we've completed a scan this session

        // Save to cache
        cache.saveApps(apps)

        // Phase 3: Fetch login items and background activities
        await fetchLoginItemsAndBackgroundActivities()

        // Check for updates
        await checkForUpdates()
    }

    // Fetch login items and background activities
    private func fetchLoginItemsAndBackgroundActivities() async {
        // Fetch login items
        await loginItemsManager.fetchLoginItems()
        await loginItemsManager.fetchLaunchServices()

        // Fetch background activities
        await backgroundActivityManager.fetchBackgroundActivities()

        // Update published properties
        loginItems = loginItemsManager.loginItems
        launchServices = loginItemsManager.launchServices
        backgroundActivities = backgroundActivityManager.backgroundActivities
    }

    // Separate methods to refresh specific sections
    func refreshLoginItems() async {
        await loginItemsManager.fetchLoginItems()
        loginItems = loginItemsManager.loginItems
    }

    func refreshLaunchServices() async {
        await loginItemsManager.fetchLaunchServices()
        launchServices = loginItemsManager.launchServices
    }

    func refreshBackgroundActivities() async {
        await backgroundActivityManager.fetchBackgroundActivities()
        backgroundActivities = backgroundActivityManager.backgroundActivities
    }

    // MARK: - Update Checking

    func checkForUpdates() async {
        isCheckingUpdates = true
        defer { isCheckingUpdates = false }

        let result = await updater.checkUpdates(for: apps)
        appsWithUpdates = Set(result.updates.map { $0.bundleIdentifier })
        availableUpdates = appsWithUpdates.count

        // Update hasUpdate flag - create new instances with updated flag
        apps = apps.map { app in
            var updatedApp = app
            updatedApp.hasUpdate = appsWithUpdates.contains(app.bundleIdentifier)
            return updatedApp
        }
    }

    func hasUpdate(for bundleIdentifier: String) -> Bool {
        appsWithUpdates.contains(bundleIdentifier)
    }

    // MARK: - Selection

    func toggleSelectionMode() {
        isSelecting.toggle()
        if !isSelecting {
            selectedAppIDs.removeAll()
        }
    }

    func selectAll() {
        selectedAppIDs = Set(filteredApps.map { $0.id })
    }

    func deselectAll() {
        selectedAppIDs.removeAll()
    }

    func toggleSelection(for app: AppMetadata) {
        if selectedAppIDs.contains(app.id) {
            selectedAppIDs.remove(app.id)
        } else {
            selectedAppIDs.insert(app.id)
        }
    }

    // MARK: - Filtering & Sorting

    var filteredApps: [AppMetadata] {
        var result = apps

        // Tab filter - filter by item type
        result = result.filter { app in
            switch selectedTab {
            case .apps:
                // Filter out items under 100KB from Apps section (likely junk)
                let isApp = app.itemType == "app" || app.itemType.isEmpty
                let isLargeEnough = app.totalSize >= 100 * 1024 // 100KB minimum
                return isApp && isLargeEnough
            case .appExtensions:
                return app.itemType == "extension" || app.itemType.contains("extension")
            case .preferencePanes:
                return app.itemType == "prefPane" || app.itemType.contains("pref")
            case .quickLookPlugins:
                return app.itemType == "quicklook" || app.itemType.contains("quick")
            case .spotlightImporters:
                return app.itemType == "spotlight" || app.itemType.contains("spot")
            case .frameworks:
                return app.itemType == "framework" || app.itemType.contains("runtime")
            case .systemUtilities:
                return app.itemType == "system" || app.itemType.contains("utility")
            case .loginItems:
                return app.itemType == "login" || app.itemType.contains("login")
            }
        }

        // Quick filter category
        if quickFilterCategory != .all {
            result = result.filter { app in
                switch quickFilterCategory {
                case .all:
                    return true
                case .leastUsed:
                    // Show apps not used in over 90 days
                    let ninetyDaysAgo = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
                    let lastUsed = app.lastUsed ?? .distantPast
                    return lastUsed < ninetyDaysAgo
                case .development:
                    return app.category == .development
                case .games:
                    return app.category == .games
                case .productivity:
                    return app.category == .productivity
                case .utilities:
                    return app.category == .utilities
                case .social:
                    return app.category == .social
                case .creative:
                    return app.category == .creativity
                case .other:
                    return ![
                        .development, .games, .productivity,
                        .utilities, .social, .creativity
                    ].contains(app.category)
                }
            }
        }

        // Search filter
        if !searchText.isEmpty {
            result = result.filter { app in
                app.name.localizedCaseInsensitiveContains(searchText) ||
                app.bundleIdentifier.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Sort
        // When leastUsed is selected, always sort by lastUsed (oldest first)
        if quickFilterCategory == .leastUsed {
            result.sort { ($0.lastUsed ?? .distantPast) < ($1.lastUsed ?? .distantPast) }
        } else {
            switch sortOption {
            case .nameAscending:
                result.sort { $0.name.localizedCompare($1.name) == .orderedAscending }
            case .nameDescending:
                result.sort { $0.name.localizedCompare($1.name) == .orderedDescending }
            case .sizeDescending:
                result.sort { $0.totalSize > $1.totalSize }
            case .sizeAscending:
                result.sort { $0.totalSize < $1.totalSize }
            case .category:
                result.sort { $0.category.rawValue < $1.category.rawValue }
            case .dateInstalled:
                result.sort { ($0.installDate ?? .distantPast) > ($1.installDate ?? .distantPast) }
            case .lastUsed:
                result.sort { ($0.lastUsed ?? .distantPast) > ($1.lastUsed ?? .distantPast) }
            case .updateStatus:
                result.sort { $0.hasUpdate && !$1.hasUpdate }
            }
        }

        return result
    }

    // All apps in the current tab (before quick filter)
    var appsInCurrentTab: [AppMetadata] {
        apps.filter { app in
            switch selectedTab {
            case .apps:
                let isApp = app.itemType == "app" || app.itemType.isEmpty
                let isLargeEnough = app.totalSize >= 100 * 1024
                return isApp && isLargeEnough
            case .appExtensions:
                return app.itemType == "extension" || app.itemType.contains("extension")
            case .preferencePanes:
                return app.itemType == "prefPane" || app.itemType.contains("pref")
            case .quickLookPlugins:
                return app.itemType == "quicklook" || app.itemType.contains("quick")
            case .spotlightImporters:
                return app.itemType == "spotlight" || app.itemType.contains("spot")
            case .frameworks:
                return app.itemType == "framework" || app.itemType.contains("runtime")
            case .systemUtilities:
                return app.itemType == "system" || app.itemType.contains("utility")
            case .loginItems:
                return app.itemType == "login" || app.itemType.contains("login")
            }
        }
    }

    // Available quick filter categories for current tab (based on all apps in tab, not filtered)
    var availableQuickFilters: [QuickFilterCategory] {
        let categoriesInTab = Set(appsInCurrentTab.map { $0.category })

        // Always show "All" and "Least Used"
        var filters: [QuickFilterCategory] = [.all, .leastUsed]

        // Add categories that have items in the current tab
        if categoriesInTab.contains(.development) {
            filters.append(.development)
        }
        if categoriesInTab.contains(.games) {
            filters.append(.games)
        }
        if categoriesInTab.contains(.productivity) {
            filters.append(.productivity)
        }
        if categoriesInTab.contains(.utilities) {
            filters.append(.utilities)
        }
        if categoriesInTab.contains(.social) {
            filters.append(.social)
        }
        if categoriesInTab.contains(.creativity) {
            filters.append(.creative)
        }
        if !categoriesInTab.isSubset(of: [
            .development, .games, .productivity, .utilities, .social, .creativity
        ]) {
            filters.append(.other)
        }

        return filters
    }

    var categorizedApps: [AppMetadata.AppCategory: [AppMetadata]] {
        Dictionary(grouping: filteredApps, by: { $0.category })
    }

    var uniqueCategories: [AppMetadata.AppCategory] {
        Array(Set(filteredApps.map { $0.category })).sorted { $0.rawValue < $1.rawValue }
    }

    // MARK: - Uninstallation

    func uninstallSelectedApps() async -> UninstallResult {
        isUninstalling = true
        uninstallProgress = 0
        defer { isUninstalling = false }

        let appsToDelete = selectedApps
        var successCount = 0
        var bytesFreed: Int64 = 0
        var errors: [UninstallError] = []

        for (index, app) in appsToDelete.enumerated() {
            if Task.isCancelled {
                errors.append(UninstallError(path: app.path.path, message: "Cancelled"))
                break
            }

            // Check if app is protected
            if ProtectedApps.isProtectedFromUninstall(app.bundleIdentifier) {
                errors.append(UninstallError(path: app.path.path, message: "Protected app"))
                uninstallProgress = Double(index + 1) / Double(appsToDelete.count)
                continue
            }

            // Move to trash
            let result = await fileOps.moveFilesToTrash(atPaths: [app.path.path])
            if result.success && result.filesProcessed > 0 {
                apps.removeAll { $0.id == app.id }
                selectedAppIDs.remove(app.id)
                successCount += 1
                bytesFreed += app.totalSize
            } else if let error = result.errors.first {
                errors.append(UninstallError(path: app.path.path, message: error.localizedDescription))
            }

            uninstallProgress = Double(index + 1) / Double(appsToDelete.count)
        }

        // Update cache
        cache.saveApps(apps)

        return UninstallResult(
            success: successCount > 0,
            appsUninstalled: successCount,
            bytesFreed: bytesFreed,
            errors: errors
        )
    }
}

// MARK: - Uninstall Result

struct UninstallResult: Sendable {
    let success: Bool
    let appsUninstalled: Int
    let bytesFreed: Int64
    let errors: [UninstallError]

    var formattedBytesFreed: String {
        ByteCountFormatter.string(fromByteCount: bytesFreed, countStyle: .file)
    }
}

struct UninstallError: Error, Identifiable {
    let id = UUID()
    let path: String
    let message: String
}

// MARK: - App Inventory View

/// Redesigned App Manager with table layout, multi-select, and batch actions.
/// Uses ActionTable component for native macOS table experience.
struct AppInventoryView: View {
    @StateObject private var inventory = AppInventoryService.shared
    @State private var selection: Set<UUID> = []
    @State private var showingDetail = false
    @State private var showingUninstallFlow = false
    @State private var currentAppForDetail: AppMetadata?
    @State private var lastTappedAppID: UUID?
    @State private var lastTapTime: Date = Date.distantPast

    var body: some View {
        HSplitView {
            // Left sidebar with category tabs
            categorySidebar
                .frame(minWidth: 180, maxWidth: 220)

            // Main content area with table
            VStack(spacing: 0) {
                // Header with title, stats, search
                tableHeader

                Divider()

                // Quick filter toolbar
                quickFilterToolbar

                Divider()

                // Main content: Table or empty state
                tableContent
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .sheet(isPresented: $showingDetail) {
            if let app = currentAppForDetail {
                AppDetailView(
                    app: app,
                    onUninstall: {
                        selection = [app.id]
                        showingUninstallFlow = true
                    }
                )
            }
        }
        .sheet(isPresented: $showingUninstallFlow) {
            UninstallFlowSheet(
                inventory: inventory,
                isPresented: $showingUninstallFlow,
                onComplete: {
                    showingUninstallFlow = false
                    selection.removeAll()
                    inventory.selectedAppIDs.removeAll()
                }
            )
        }
        .onChange(of: selection) { _, newValue in
            // Sync selection with inventory for uninstall flow
            inventory.selectedAppIDs = newValue
        }
        .task {
            if !inventory.hasScannedThisSession && inventory.apps.isEmpty {
                await inventory.scanApps()
            }
        }
    }

    // MARK: - Category Sidebar

    private var categorySidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            Text("Categories")
                .font(DesignTokens.Typography.captionEmphasized)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .padding(.horizontal, DesignTokens.Spacing.sm)
                .padding(.top, DesignTokens.Spacing.md)
                .padding(.bottom, DesignTokens.Spacing.xxs)

            // Category list
            ForEach(ItemType.allCases) { tab in
                CategorySidebarRow(
                    tab: tab,
                    isSelected: inventory.selectedTab == tab,
                    itemCount: itemCountForTab(tab)
                ) {
                    withAnimation(DesignTokens.Animation.fast) {
                        inventory.selectedTab = tab
                        inventory.quickFilterCategory = .all
                        inventory.loginItemFilter = .all
                        selection.removeAll()
                    }
                }
            }

            Spacer()

            // Stats footer
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Total Apps")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(DesignTokens.Colors.textTertiary)
                        Text("\(inventory.apps.count)")
                            .font(DesignTokens.Typography.subheadEmphasized)
                            .foregroundColor(DesignTokens.Colors.textPrimary)
                    }

                    Spacer()

                    if inventory.availableUpdates > 0 {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Updates")
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(DesignTokens.Colors.textTertiary)
                            Text("\(inventory.availableUpdates)")
                                .font(DesignTokens.Typography.subheadEmphasized)
                                .foregroundColor(DesignTokens.Colors.success)
                        }
                    }
                }
                .padding(DesignTokens.Spacing.sm)
            }
        }
        .background(DesignTokens.Colors.backgroundSecondary)
    }

    // Helper to get item count for each tab
    private func itemCountForTab(_ tab: ItemType) -> Int {
        switch tab {
        case .apps:
            return inventory.apps.filter { app in
                (app.itemType == "app" || app.itemType.isEmpty) && app.totalSize >= 100 * 1024
            }.count
        case .appExtensions:
            return inventory.apps.filter { $0.itemType == "extension" || $0.itemType.contains("extension") }.count
        case .preferencePanes:
            return inventory.apps.filter { $0.itemType == "prefPane" || $0.itemType.contains("pref") }.count
        case .quickLookPlugins:
            return inventory.apps.filter { $0.itemType == "quicklook" || $0.itemType.contains("quick") }.count
        case .spotlightImporters:
            return inventory.apps.filter { $0.itemType == "spotlight" || $0.itemType.contains("spot") }.count
        case .frameworks:
            return inventory.apps.filter { $0.itemType == "framework" || $0.itemType.contains("runtime") }.count
        case .systemUtilities:
            return inventory.apps.filter { $0.itemType == "system" || $0.itemType.contains("utility") }.count
        case .loginItems:
            let launchAgents = inventory.apps.filter { $0.itemType == "login" || $0.itemType.contains("login") }.count
            return launchAgents + inventory.loginItems.count + inventory.launchServices.count
        }
    }

    // MARK: - Table Header

    private var tableHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: DesignTokens.Spacing.md) {
                // Title and status
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
                    Text("App Manager")
                        .font(DesignTokens.Typography.h2)
                        .foregroundColor(DesignTokens.Colors.textPrimary)

                    // Status line
                    Group {
                        if !selection.isEmpty {
                            HStack(spacing: DesignTokens.Spacing.xxxs) {
                                Circle()
                                    .fill(DesignTokens.Colors.accent)
                                    .frame(width: 6, height: 6)
                                Text("\(selection.count) selected")
                                    .foregroundColor(DesignTokens.Colors.textSecondary)
                                Text("·")
                                    .foregroundColor(DesignTokens.Colors.textTertiary)
                                Text(formatBytes(selectedSize))
                                    .foregroundColor(DesignTokens.Colors.textSecondary)
                            }
                        } else if inventory.isRefreshing {
                            HStack(spacing: DesignTokens.Spacing.xxxs) {
                                ProgressView()
                                    .scaleEffect(0.6)
                                Text("Calculating sizes...")
                                    .foregroundColor(DesignTokens.Colors.textSecondary)
                            }
                        } else if let date = inventory.lastScanDate {
                            HStack(spacing: DesignTokens.Spacing.xxxs) {
                                Image(systemName: "clock")
                                    .font(.system(size: 10))
                                Text("Scanned \(date, style: .relative) ago")
                            }
                            .foregroundColor(DesignTokens.Colors.textTertiary)
                        }
                    }
                    .font(DesignTokens.Typography.caption)
                }

                Spacer()

                // Actions
                HStack(spacing: DesignTokens.Spacing.sm) {
                    if inventory.isLoading {
                        HStack(spacing: DesignTokens.Spacing.xxs) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Button("Cancel") {
                                inventory.cancelScan()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    } else {
                        Button {
                            Task { await inventory.scanApps() }
                        } label: {
                            HStack(spacing: DesignTokens.Spacing.xxxs) {
                                Image(systemName: "arrow.clockwise")
                                Text("Rescan")
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                    }
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)

            // Search bar
            HStack(spacing: DesignTokens.Spacing.sm) {
                HStack(spacing: DesignTokens.Spacing.xxs) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                        .font(.system(size: 13))

                    TextField("Search apps by name or bundle ID...", text: $inventory.searchText)
                        .textFieldStyle(.plain)
                        .font(DesignTokens.Typography.subhead)

                    if !inventory.searchText.isEmpty {
                        Button {
                            inventory.searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(DesignTokens.Colors.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.xs)
                .padding(.vertical, DesignTokens.Spacing.xxs)
                .background(DesignTokens.Colors.backgroundTertiary)
                .cornerRadius(DesignTokens.CornerRadius.medium)

                Spacer()

                // Sort picker
                Menu {
                    ForEach(AppInventoryService.SortOption.allCases, id: \.self) { option in
                        Button {
                            withAnimation(DesignTokens.Animation.fast) {
                                inventory.sortOption = option
                            }
                        } label: {
                            HStack {
                                Text(option.rawValue)
                                if inventory.sortOption == option {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: DesignTokens.Spacing.xxxs) {
                        Image(systemName: "arrow.up.arrow.down")
                        Text(inventory.sortOption.rawValue)
                    }
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .padding(.horizontal, DesignTokens.Spacing.xxs)
                    .padding(.vertical, DesignTokens.Spacing.xxxs)
                    .background(DesignTokens.Colors.backgroundSecondary)
                    .cornerRadius(DesignTokens.CornerRadius.small)
                }
                .menuStyle(.borderlessButton)
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.bottom, DesignTokens.Spacing.sm)
        }
        .background(DesignTokens.Colors.background)
    }

    private var selectedSize: Int64 {
        inventory.filteredApps
            .filter { selection.contains($0.id) }
            .reduce(0) { $0 + $1.totalSize }
    }

    // MARK: - Quick Filter Toolbar

    private var quickFilterToolbar: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            // Quick filter pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignTokens.Spacing.xxs) {
                    if inventory.selectedTab == .loginItems {
                        ForEach(LoginItemFilter.allCases) { filter in
                            FilterPill(
                                title: filter.rawValue,
                                icon: filter.icon,
                                isSelected: inventory.loginItemFilter == filter
                            ) {
                                withAnimation(DesignTokens.Animation.fast) {
                                    inventory.loginItemFilter = filter
                                }
                            }
                        }
                    } else {
                        ForEach(inventory.availableQuickFilters) { filter in
                            FilterPill(
                                title: filter.rawValue,
                                icon: filter.icon,
                                isSelected: inventory.quickFilterCategory == filter
                            ) {
                                withAnimation(DesignTokens.Animation.fast) {
                                    inventory.quickFilterCategory = filter
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.xxxs)
            }

            Spacer()

            // Item count
            Text("\(inventory.filteredApps.count) items")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(DesignTokens.Colors.textTertiary)
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .background(DesignTokens.Colors.backgroundSecondary)
    }

    // MARK: - Table Content (ActionTable)

    /// Main table content using ActionTable for multi-select and batch actions
    private var tableContent: some View {
        Group {
            if inventory.selectedTab == .loginItems {
                loginItemsContentView()
            } else if inventory.filteredApps.isEmpty {
                emptyView
            } else {
                appTableView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// App table view using ActionTable component
    private var appTableView: some View {
        ActionTable(
            items: inventory.filteredApps,
            selection: $selection,
            columns: appTableColumns,
            batchActions: appTableBatchActions,
            contextMenu: { app in
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([app.path])
                } label: {
                    Label("Reveal in Finder", systemImage: "folder")
                }

                Divider()

                Button {
                    currentAppForDetail = app
                    showingDetail = true
                } label: {
                    Label("Show Details", systemImage: "info.circle")
                }

                Divider()

                if !ProtectedApps.isProtectedFromUninstall(app.bundleIdentifier) {
                    Button(role: .destructive) {
                        selection = [app.id]
                        showingUninstallFlow = true
                    } label: {
                        Label("Uninstall", systemImage: "trash")
                    }
                } else {
                    Button {
                        // Protected app - show disabled
                    } label: {
                        Label("Protected App", systemImage: "lock.fill")
                    }
                    .disabled(true)
                }
            },
            onDoubleClick: { app in
                currentAppForDetail = app
                showingDetail = true
            },
            onActivate: { app in
                currentAppForDetail = app
                showingDetail = true
            }
        )
    }

    /// Table columns for the ActionTable
    private var appTableColumns: [ActionTableColumn<AppMetadata>] {
        [
            // App name with icon
            ActionTableColumn(id: "name", title: "Application") { app in
                HStack(spacing: DesignTokens.Spacing.xxs) {
                    // App icon
                    appIconView(for: app)
                        .frame(width: 28, height: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: DesignTokens.Spacing.xxxs) {
                            Text(app.name)
                                .font(DesignTokens.Typography.body)
                                .foregroundColor(DesignTokens.Colors.textPrimary)
                                .lineLimit(1)

                            if ProtectedApps.isProtectedFromUninstall(app.bundleIdentifier) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(DesignTokens.Colors.textTertiary)
                                    .help("Protected app - cannot be uninstalled")
                            }

                            if inventory.hasUpdate(for: app.bundleIdentifier) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(DesignTokens.Colors.success)
                                    .help("Update available")
                            }
                        }

                        Text(app.bundleIdentifier)
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(DesignTokens.Colors.textTertiary)
                            .lineLimit(1)
                    }
                }
            },

            // Size column
            ActionTableColumn(id: "size", title: "Size", width: .fixed(90), alignment: .trailing, isSortable: true) { app in
                Text(ByteCountFormatter.string(fromByteCount: app.totalSize, countStyle: .file))
                    .font(DesignTokens.Typography.monoSubhead)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            },

            // Last used column
            ActionTableColumn(id: "lastUsed", title: "Last Used", width: .fixed(100), alignment: .trailing) { app in
                Text(formatLastUsed(app.lastUsed))
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            },

            // Version column
            ActionTableColumn(id: "version", title: "Version", width: .fixed(80), alignment: .trailing) { app in
                Text(app.version ?? "N/A")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                    .lineLimit(1)
            },

            // Category column
            ActionTableColumn(id: "category", title: "Category", width: .fixed(100)) { app in
                Text(app.category.rawValue)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .lineLimit(1)
            }
        ]
    }

    /// Batch actions for selected items
    private var appTableBatchActions: [ActionTableAction<AppMetadata>] {
        [
            ActionTableAction(
                id: "reveal",
                title: "Reveal",
                icon: "folder",
                style: .secondary,
                isEnabled: { !$0.isEmpty }
            ) { apps in
                let urls = apps.map { $0.path }
                NSWorkspace.shared.activateFileViewerSelecting(urls)
            },

            ActionTableAction(
                id: "uninstall",
                title: "Uninstall",
                icon: "trash",
                style: .destructive,
                isEnabled: { apps in
                    // Only enable if at least one app is not protected
                    apps.contains { !ProtectedApps.isProtectedFromUninstall($0.bundleIdentifier) }
                }
            ) { _ in
                showingUninstallFlow = true
            }
        ]
    }

    /// Helper to create app icon view
    @ViewBuilder
    private func appIconView(for app: AppMetadata) -> some View {
        if let icon = getAppIconSafely(for: app.path) {
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: "app.fill")
                .font(.system(size: 14))
                .foregroundColor(DesignTokens.Colors.textTertiary)
        }
    }

    /// Format last used date
    private func formatLastUsed(_ date: Date?) -> String {
        guard let date = date else { return "Never" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - Content View

    private var contentView: some View {
        Group {
            if inventory.selectedTab == .loginItems {
                // Show login items view (combines filtered apps + loginItems + launchServices)
                loginItemsContentView()
            } else if inventory.filteredApps.isEmpty {
                emptyView
            } else {
                appGridView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // Specialized view for login items that combines all sources
    private func loginItemsContentView() -> AnyView {
        // Get all items first
        let allItems = inventory.filteredApps + loginItemsAsApps

        // Apply login item specific filter
        let filteredItems: [AppMetadata]
        switch inventory.loginItemFilter {
        case .all:
            filteredItems = allItems
        case .launchAgents:
            // Show only launch agents (items with itemType containing "LaunchAgent" or "login")
            filteredItems = allItems.filter { item in
                item.itemType.contains("LaunchAgent") || item.itemType.contains("login")
            }
        case .daemons:
            // Show only daemons (items with itemType containing "LaunchDaemon" or "Daemon")
            filteredItems = allItems.filter { item in
                item.itemType.contains("LaunchDaemon") || item.itemType.contains("Daemon")
            }
        }

        if filteredItems.isEmpty {
            return AnyView(emptyLoginItemsView)
        } else {
            return AnyView(
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 280, maximum: 350), spacing: DesignTokens.Spacing.md)
                    ], spacing: DesignTokens.Spacing.md) {
                        ForEach(filteredItems) { item in
                            LoginItemCard(
                                item: item,
                                onTap: {
                                    // Could show detail sheet here
                                }
                            )
                        }
                    }
                    .padding(DesignTokens.Spacing.lg)
                }
            )
        }
    }

    // Convert LoginItem and LaunchService to displayable format
    private var loginItemsAsApps: [AppMetadata] {
        var result: [AppMetadata] = []

        // Add login items
        for item in inventory.loginItems {
            let app = AppMetadata(
                bundleIdentifier: item.bundleIdentifier,
                appName: item.name,
                path: item.path,
                version: nil,
                totalSize: 0,
                installDate: nil,
                category: .other,
                itemType: "loginItem"
            )
            result.append(app)
        }

        // Add launch services
        for service in inventory.launchServices {
            let app = AppMetadata(
                bundleIdentifier: service.bundleIdentifier,
                appName: service.name,
                path: service.path,
                version: nil,
                totalSize: 0,
                installDate: nil,
                category: .other,
                itemType: service.serviceType.rawValue
            )
            result.append(app)
        }

        return result
    }

    private var emptyLoginItemsView: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Spacer()

            Image(systemName: "person.2")
                .font(.system(size: 64))
                .foregroundColor(DesignTokens.Colors.textSecondary.opacity(0.5))

            if inventory.isLoading {
                Text("Scanning for login items...")
                    .font(DesignTokens.Typography.headlineSmall)
                    .foregroundColor(DesignTokens.Colors.textSecondary)

                ProgressView()
                    .scaleEffect(1.2)
            } else {
                Text("No login items found")
                    .font(DesignTokens.Typography.headlineSmall)
                    .foregroundColor(DesignTokens.Colors.textSecondary)

                Text("Login items are applications and services that launch automatically when you log in.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Button("Scan Again") {
                    Task {
                        await inventory.scanApps()
                    }
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
            }

            Spacer()
        }
    }

    private var emptyView: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Spacer()

            Image(systemName: "app.dashed")
                .font(.system(size: 64))
                .foregroundColor(DesignTokens.Colors.textSecondary.opacity(0.5))

            if inventory.isLoading {
                Text("Scanning for applications...")
                    .font(DesignTokens.Typography.headlineSmall)
                    .foregroundColor(DesignTokens.Colors.textSecondary)

                ProgressView()
                    .scaleEffect(1.2)
            } else if !inventory.searchText.isEmpty || inventory.quickFilterCategory != .all {
                Text("No applications found")
                    .font(DesignTokens.Typography.headlineSmall)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            } else {
                Text("No applications found")
                    .font(DesignTokens.Typography.headlineSmall)
                    .foregroundColor(DesignTokens.Colors.textSecondary)

                Button("Scan Again") {
                    Task {
                        await inventory.scanApps()
                    }
                }
                .buttonStyle(.borderedProminent)
            }

            Spacer()
        }
    }

    private var appGridView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 280, maximum: 350), spacing: DesignTokens.Spacing.md)
            ], spacing: DesignTokens.Spacing.md) {
                ForEach(inventory.filteredApps) { app in
                    AppCard(
                        app: app,
                        isSelected: inventory.selectedAppIDs.contains(app.id),
                        hasUpdate: inventory.hasUpdate(for: app.bundleIdentifier),
                        onTap: {
                            handleAppTap(app)
                        }
                    )
                }
            }
            .padding(DesignTokens.Spacing.lg)
        }
    }

    // MARK: - Actions

    private func handleAppTap(_ app: AppMetadata) {
        let now = Date()
        let isDoubleTap = lastTappedAppID == app.id && now.timeIntervalSince(lastTapTime) < 0.3
        lastTapTime = now
        lastTappedAppID = app.id

        if isDoubleTap {
            // Double-click opens details
            currentAppForDetail = app
            showingDetail = true
        } else {
            // Single-click selects (adds to selection)
            inventory.toggleSelection(for: app)
        }
    }

    private func formatBytes(_ count: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: count, countStyle: .file)
    }

    // MARK: - Selection Sidebar

    private var selectionSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Selected")
                    .font(.headline)
                Spacer()
                Button("Clear") {
                    inventory.deselectAll()
                }
                .buttonStyle(.borderless)
            }
            .padding()

            Divider()

            // Selected apps list
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(inventory.selectedApps) { app in
                        SelectedAppRow(
                            app: app,
                            onRemove: { inventory.toggleSelection(for: app) }
                        )
                    }
                }
                .padding()
            }

            Divider()

            // Footer with total size and uninstall button
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Total Space")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatBytes(inventory.selectedSize))
                        .fontWeight(.semibold)
                }

                Button {
                    showingUninstallFlow = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Uninstall \(inventory.selectedAppIDs.count) App(s)")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
            .padding()
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    struct SelectedAppRow: View {
        let app: AppMetadata
        let onRemove: () -> Void

        var body: some View {
            HStack(spacing: 8) {
                // App icon
                if let icon = loadIconSafely() {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 24, height: 24)
                } else {
                    Image(systemName: "app")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                }

                // App name and size
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                        .font(.body)
                        .lineLimit(1)
                    Text(ByteCountFormatter.string(fromByteCount: app.totalSize, countStyle: .file))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Remove button
                Button {
                    onRemove()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Remove from selection")
            }
            .padding(.vertical, 4)
        }

        private func loadIconSafely() -> NSImage? {
            let semaphore = DispatchSemaphore(value: 0)
            var result: NSImage?

            DispatchQueue.global(qos: .userInitiated).async {
                let icon = NSWorkspace.shared.icon(forFile: app.path.path)
                if icon.isValid && icon.representations.count > 0 {
                    result = icon
                }
                semaphore.signal()
            }

            _ = semaphore.wait(timeout: .now() + 0.5)
            return result
        }
    }

    // Safe icon loading with timeout
    private func getAppIconSafely(for path: URL) -> NSImage? {
        // Run on background thread with timeout to prevent hanging
        let semaphore = DispatchSemaphore(value: 0)
        var result: NSImage?

        DispatchQueue.global(qos: .userInitiated).async {
            let icon = NSWorkspace.shared.icon(forFile: path.path)
            if icon.isValid && icon.representations.count > 0 {
                result = icon
            }
            semaphore.signal()
        }

        // Wait with timeout (0.5 seconds max)
        _ = semaphore.wait(timeout: .now() + 0.5)
        return result
    }
}

// MARK: - App Card

struct AppCard: View {
    let app: AppMetadata
    let isSelected: Bool
    let hasUpdate: Bool
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: DesignTokens.Spacing.sm) {
                // App Icon
                appIcon

                // App Info
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    HStack {
                        Text(app.name)
                            .font(DesignTokens.Typography.bodyMedium)
                            .fontWeight(.medium)
                            .foregroundColor(DesignTokens.Colors.text)
                            .lineLimit(1)

                        Spacer()

                        if hasUpdate {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.caption)
                                .foregroundColor(DesignTokens.Colors.accent)
                        }
                    }

                    Text(app.bundleIdentifier)
                        .font(DesignTokens.Typography.captionMedium)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                        .lineLimit(1)

                    HStack(spacing: DesignTokens.Spacing.xs) {
                        Text(ByteCountFormatter.string(fromByteCount: app.totalSize, countStyle: .file))
                            .font(DesignTokens.Typography.captionSmall)
                            .foregroundColor(DesignTokens.Colors.textSecondary)

                        Text("•")
                            .foregroundColor(DesignTokens.Colors.textSecondary)

                        Text(app.version ?? "Unknown")
                            .font(DesignTokens.Typography.captionSmall)
                            .foregroundColor(DesignTokens.Colors.textSecondary)

                        Text("•")
                            .foregroundColor(DesignTokens.Colors.textSecondary)

                        Text(app.category.rawValue)
                            .font(DesignTokens.Typography.captionSmall)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    }
                }

                // Selection indicator (always shown if selected)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? DesignTokens.Colors.accent : DesignTokens.Colors.textSecondary.opacity(0.3))
            }
            .padding(DesignTokens.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.large)
                    .fill(isSelected ? DesignTokens.Colors.accent.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.large)
                    .stroke(isSelected ? DesignTokens.Colors.accent : Color.clear, lineWidth: 2)
            )
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovered = hovering
            }
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
    }

    private var appIcon: some View {
        Group {
            // Use safe icon loading to prevent hanging
            if let icon = getAppIconSafely(for: app.path) {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "app")
                    .font(.title2)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
        }
        .frame(width: 44, height: 44)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(DesignTokens.Colors.backgroundSecondary)
        )
    }

    // Safe icon loading with timeout (shared with parent view)
    private func getAppIconSafely(for path: URL) -> NSImage? {
        let semaphore = DispatchSemaphore(value: 0)
        var result: NSImage?

        DispatchQueue.global(qos: .userInitiated).async {
            let icon = NSWorkspace.shared.icon(forFile: path.path)
            if icon.isValid && icon.representations.count > 0 {
                result = icon
            }
            semaphore.signal()
        }

        _ = semaphore.wait(timeout: .now() + 0.5)
        return result
    }
}

// MARK: - App Detail View

struct AppDetailView: View {
    let app: AppMetadata
    let onUninstall: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                    appInfoSection
                    sizeSection
                    dangerZone
                }
                .padding(DesignTokens.Spacing.xl)
            }
        }
        .frame(width: 600, height: 500)
    }

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var appInfoSection: some View {
        HStack(spacing: DesignTokens.Spacing.lg) {
            // Use safe icon loading
            if let icon = getAppIconSafely(for: app.path) {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
            } else {
                Image(systemName: "app")
                    .font(.system(size: 64))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .frame(width: 80, height: 80)
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(app.name)
                    .font(DesignTokens.Typography.headlineMedium)
                    .fontWeight(.semibold)

                Text(app.bundleIdentifier)
                    .font(DesignTokens.Typography.bodyMedium)
                    .foregroundColor(DesignTokens.Colors.textSecondary)

                Text("Version \(app.version ?? "Unknown")")
                    .font(DesignTokens.Typography.captionMedium)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }

            Spacer()
        }
    }

    private var sizeSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Size")
                .font(DesignTokens.Typography.headlineSmall)
                .foregroundColor(DesignTokens.Colors.text)

            HStack(spacing: DesignTokens.Spacing.xl) {
                SizeItem(label: "App Bundle", size: app.totalSize)
            }
        }
    }

    // Safe icon loading
    private func getAppIconSafely(for path: URL) -> NSImage? {
        let semaphore = DispatchSemaphore(value: 0)
        var result: NSImage?

        DispatchQueue.global(qos: .userInitiated).async {
            let icon = NSWorkspace.shared.icon(forFile: path.path)
            if icon.isValid && icon.representations.count > 0 {
                result = icon
            }
            semaphore.signal()
        }

        _ = semaphore.wait(timeout: .now() + 0.5)
        return result
    }

    private var dangerZone: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Actions")
                .font(DesignTokens.Typography.headlineSmall)
                .foregroundColor(DesignTokens.Colors.text)

            Button {
                dismiss()
                onUninstall()
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Uninstall App")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
    }
}

struct SizeItem: View {
    let label: String
    let size: Int64

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
            Text(label)
                .font(DesignTokens.Typography.captionMedium)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                .font(DesignTokens.Typography.bodyMedium)
                .fontWeight(.medium)
        }
    }
}

struct LocationRow: View {
    let label: String
    let path: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(DesignTokens.Typography.captionMedium)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            Text(path)
                .font(DesignTokens.Typography.captionSmall)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .lineLimit(1)
        }
    }
}

// MARK: - Uninstall Flow Sheet

/// Unified uninstall flow with confirmation, progress, and summary states
struct UninstallFlowSheet: View {
    @ObservedObject var inventory: AppInventoryService
    @Binding var isPresented: Bool
    let onComplete: () -> Void

    @State private var flowState: UninstallFlowState = .confirmation
    @State private var progressState: UninstallProgressState?
    @State private var resultState: UninstallResult?

    private var appsToDelete: [AppMetadata] {
        inventory.selectedApps.sorted { $0.totalSize > $1.totalSize }
    }

    private var totalSize: Int64 {
        appsToDelete.reduce(0) { $0 + $1.totalSize }
    }

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                header

                Divider()

                // Content based on state
                ScrollView {
                    VStack(spacing: 24) {
                        switch flowState {
                        case .confirmation:
                            confirmationContent
                        case .progress:
                            progressContent
                        case .summary:
                            summaryContent
                        }
                    }
                    .padding(24)
                }

                Divider()

                // Footer
                footer
            }
        }
        .frame(width: 560, height: 600)
        .onAppear {
            // Reset state when sheet appears
            flowState = .confirmation
            progressState = nil
            resultState = nil
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            ZStack {
                Circle()
                    .fill(circleBackgroundColor)
                    .frame(width: 36, height: 36)

                Image(systemName: circleIcon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(circleIconColor)
            }

            Text(headerTitle)
                .font(.headline)

            Spacer()

            if flowState != .progress {
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 18))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var circleBackgroundColor: Color {
        switch flowState {
        case .confirmation:
            return .red.opacity(0.15)
        case .progress:
            return .blue.opacity(0.15)
        case .summary:
            return .green.opacity(0.15)
        }
    }

    private var circleIcon: String {
        switch flowState {
        case .confirmation:
            return "trash.fill"
        case .progress:
            return "arrow.triangle.2.circlepath"
        case .summary:
            return resultState?.success == true ? "checkmark" : "exclamationmark"
        }
    }

    private var circleIconColor: Color {
        switch flowState {
        case .confirmation:
            return .red
        case .progress:
            return .blue
        case .summary:
            return resultState?.success == true ? .green : .orange
        }
    }

    private var headerTitle: String {
        switch flowState {
        case .confirmation:
            return "Confirm Uninstall"
        case .progress:
            return "Uninstalling Apps"
        case .summary:
            return resultState?.success == true ? "Uninstall Complete" : "Uninstall Finished"
        }
    }

    // MARK: - Confirmation Content

    private var confirmationContent: some View {
        VStack(spacing: 24) {
            // Warning message
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 20))

                Text("These apps will be moved to Trash. This action cannot be undone.")
                    .font(.body)
                    .foregroundColor(.secondary)

                Spacer()
            }
            .padding(12)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)

            // Apps list with large icons
            VStack(spacing: 16) {
                ForEach(appsToDelete) { app in
                    UninstallAppRow(app: app)
                }
            }

            // Total summary
            VStack(spacing: 4) {
                Text("Total Space to be Freed")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.red)
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Progress Content

    private var progressContent: some View {
        VStack(spacing: 32) {
            Spacer()

            // Animated progress ring
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 8)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: progressState?.progress ?? 0)
                    .stroke(
                        Color.blue,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: progressState?.progress ?? 0)

                VStack(spacing: 4) {
                    Text("\(Int((progressState?.progress ?? 0) * 100))%")
                        .font(.system(size: 28, weight: .bold))

                    Text("\(progressState?.completed ?? 0) of \(progressState?.total ?? 0)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Current app
            if let progress = progressState, !progress.currentAppName.isEmpty {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)

                        Text("Removing")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }

                    Text(progress.currentAppName)
                        .font(.headline)
                }
            }

            // Apps remaining
            if let progress = progressState {
                VStack(spacing: 4) {
                    Text("\(progress.total - progress.completed) app\(progress.total - progress.completed == 1 ? "" : "s") remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("Freed \(ByteCountFormatter.string(fromByteCount: progress.bytesFreed, countStyle: .file)) so far")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
    }

    // MARK: - Summary Content

    private var summaryContent: some View {
        VStack(spacing: 32) {
            Spacer()

            // Success icon
            ZStack {
                Circle()
                    .fill((resultState?.success == true ? Color.green : Color.orange).opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: resultState?.success == true ? "checkmark" : "exclamationmark")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(resultState?.success == true ? .green : .orange)
            }

            // Stats
            VStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("Space Freed")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(ByteCountFormatter.string(fromByteCount: resultState?.bytesFreed ?? 0, countStyle: .file))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.green)
                }

                HStack(spacing: 32) {
                    VStack(spacing: 4) {
                        Text("Removed")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("\(resultState?.appsUninstalled ?? 0)")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }

                    if let errors = resultState?.errors, !errors.isEmpty {
                        VStack(spacing: 4) {
                            Text("Failed")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text("\(errors.count)")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                        }
                    }
                }
            }

            // Errors if any
            if let errors = resultState?.errors, !errors.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Could not remove these apps:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ForEach(errors) { error in
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)

                            Text((error.path as NSString).lastPathComponent)
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Spacer()

                            Text(error.message)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }

            Spacer()
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 12) {
            if flowState == .confirmation {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)

                Button("Uninstall") {
                    startUninstall()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .frame(maxWidth: .infinity)
            } else if flowState == .summary {
                Button("Done") {
                    onComplete()
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(20)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Uninstall Logic

    private func startUninstall() {
        flowState = .progress

        Task {
            let totalApps = appsToDelete.count
            var bytesFreed: Int64 = 0
            var completed = 0
            var errors: [UninstallError] = []
            var successfullyRemovedIDs: Set<UUID> = []

            for (index, app) in appsToDelete.enumerated() {
                // Update progress
                await MainActor.run {
                    progressState = UninstallProgressState(
                        total: totalApps,
                        completed: index,
                        currentAppName: app.name,
                        bytesFreed: bytesFreed
                    )
                }

                // Check if protected
                if ProtectedApps.isProtectedFromUninstall(app.bundleIdentifier) {
                    errors.append(UninstallError(path: app.path.path, message: "Protected app"))
                    continue
                }

                // Move to trash
                let result = await inventory.fileOps.moveFilesToTrash(atPaths: [app.path.path])
                if result.success && result.filesProcessed > 0 {
                    successfullyRemovedIDs.insert(app.id)
                    bytesFreed += app.totalSize
                } else if let error = result.errors.first {
                    errors.append(UninstallError(path: app.path.path, message: error.errorDescription ?? "Unknown error"))
                }

                completed += 1
            }

            // Update apps array with new instance to trigger UI refresh
            await MainActor.run {
                inventory.apps = inventory.apps.filter { !successfullyRemovedIDs.contains($0.id) }
                inventory.selectedAppIDs.removeAll()
            }

            // Final result
            let finalResult = UninstallResult(
                success: completed > 0,
                appsUninstalled: completed,
                bytesFreed: bytesFreed,
                errors: errors
            )

            // Update cache
            inventory.cache.saveApps(inventory.apps)

            // Small delay before showing summary
            try? await Task.sleep(nanoseconds: 500_000_000)

            await MainActor.run {
                resultState = finalResult
                flowState = .summary
            }
        }
    }

    // MARK: - Flow State

    enum UninstallFlowState {
        case confirmation
        case progress
        case summary
    }

    struct UninstallProgressState {
        let total: Int
        let completed: Int
        let currentAppName: String
        let bytesFreed: Int64

        var progress: Double {
            guard total > 0 else { return 0 }
            return Double(completed) / Double(total)
        }
    }
}

// MARK: - Uninstall App Row

struct UninstallAppRow: View {
    let app: AppMetadata

    var body: some View {
        HStack(spacing: 16) {
            // Large app icon
            if let icon = loadIconSafely(for: app.path) {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.secondary)
                    .frame(width: 48, height: 48)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(10)
            }

            // App info
            VStack(alignment: .leading, spacing: 4) {
                Text(app.name)
                    .font(.body)
                    .fontWeight(.medium)

                Text(app.bundleIdentifier)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Size
            VStack(alignment: .trailing, spacing: 4) {
                Text(ByteCountFormatter.string(fromByteCount: app.totalSize, countStyle: .file))
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }

    private func loadIconSafely(for path: URL) -> NSImage? {
        let semaphore = DispatchSemaphore(value: 0)
        var result: NSImage?

        DispatchQueue.global(qos: .userInitiated).async {
            let icon = NSWorkspace.shared.icon(forFile: path.path)
            if icon.isValid && icon.representations.count > 0 {
                result = icon
            }
            semaphore.signal()
        }

        _ = semaphore.wait(timeout: .now() + 0.5)
        return result
    }
}

// MARK: - Login Item Card

/// Specialized card for login items with type badge
struct LoginItemCard: View {
    let item: AppMetadata
    let onTap: () -> Void

    @State private var isHovered = false

    private var itemTypeDisplay: String {
        switch item.itemType {
        case "loginItem":
            return "Login Item"
        case "LaunchAgent":
            return "Launch Agent"
        case "LaunchDaemon":
            return "Launch Daemon"
        default:
            return "Login Item"
        }
    }

    private var itemIcon: String {
        switch item.itemType {
        case "LaunchAgent", "LaunchDaemon":
            return "gear.circle.fill"
        default:
            return "person.circle.fill"
        }
    }

    private var itemColor: Color {
        switch item.itemType {
        case "LaunchAgent":
            return .blue
        case "LaunchDaemon":
            return .purple
        default:
            return .green
        }
    }

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: DesignTokens.Spacing.sm) {
                // Icon with type badge
                ZStack(alignment: .bottomTrailing) {
                    itemIconView

                    // Type badge
                    Image(systemName: itemIcon)
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                        .padding(4)
                        .background(itemColor)
                        .clipShape(Circle())
                }

                // Info
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    Text(item.name)
                        .font(DesignTokens.Typography.bodyMedium)
                        .fontWeight(.medium)
                        .foregroundColor(DesignTokens.Colors.text)
                        .lineLimit(1)

                    Text(item.bundleIdentifier)
                        .font(DesignTokens.Typography.captionMedium)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                        .lineLimit(1)

                    HStack(spacing: DesignTokens.Spacing.xs) {
                        Text(itemTypeDisplay)
                            .font(DesignTokens.Typography.captionSmall)
                            .foregroundColor(itemColor)

                        if item.itemType.contains("Launch") {
                            Text("•")
                                .foregroundColor(DesignTokens.Colors.textSecondary)

                            Text("System")
                                .font(DesignTokens.Typography.captionSmall)
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                        }
                    }
                }

                Spacer()

                // Status indicator
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            }
            .padding(DesignTokens.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.large)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.large)
                    .stroke(itemColor.opacity(0.3), lineWidth: 1)
            )
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovered = hovering
            }
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
    }

    private var itemIconView: some View {
        Group {
            if let icon = getAppIconSafely(for: item.path) {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "app")
                    .font(.title2)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
        }
        .frame(width: 44, height: 44)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(DesignTokens.Colors.backgroundSecondary)
        )
    }

    private func getAppIconSafely(for path: URL) -> NSImage? {
        let semaphore = DispatchSemaphore(value: 0)
        var result: NSImage?

        DispatchQueue.global(qos: .userInitiated).async {
            let icon = NSWorkspace.shared.icon(forFile: path.path)
            if icon.isValid && icon.representations.count > 0 {
                result = icon
            }
            semaphore.signal()
        }

        _ = semaphore.wait(timeout: .now() + 0.5)
        return result
    }
}

// MARK: - Category Sidebar Row

/// Row item for the category sidebar
struct CategorySidebarRow: View {
    let tab: ItemType
    let isSelected: Bool
    let itemCount: Int
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.xxs) {
                Image(systemName: tab.icon)
                    .font(.system(size: 13))
                    .foregroundColor(isSelected ? DesignTokens.Colors.accent : DesignTokens.Colors.textSecondary)
                    .frame(width: 20)

                Text(tab.rawValue)
                    .font(DesignTokens.Typography.subhead)
                    .foregroundColor(isSelected ? DesignTokens.Colors.textPrimary : DesignTokens.Colors.textSecondary)
                    .lineLimit(1)

                Spacer()

                Text("\(itemCount)")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                    .padding(.horizontal, DesignTokens.Spacing.xxs)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(DesignTokens.Colors.backgroundTertiary)
                    )
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xxs)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.small)
                    .fill(isSelected ? DesignTokens.Colors.selectedContentBackground : (isHovered ? DesignTokens.Colors.unemphasizedSelectedContentBackground.opacity(0.5) : Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(DesignTokens.Animation.fast) {
                isHovered = hovering
            }
        }
        .accessibilityLabel("\(tab.rawValue), \(itemCount) items")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Filter Pill

/// Pill-shaped filter button for quick filters
struct FilterPill: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.xxxs) {
                Image(systemName: icon)
                    .font(.system(size: 10))

                Text(title)
                    .font(DesignTokens.Typography.caption)
            }
            .padding(.horizontal, DesignTokens.Spacing.xs)
            .padding(.vertical, DesignTokens.Spacing.xxxs)
            .foregroundColor(isSelected ? .white : DesignTokens.Colors.textSecondary)
            .background(
                Capsule()
                    .fill(isSelected ? DesignTokens.Colors.accent : (isHovered ? DesignTokens.Colors.backgroundTertiary : DesignTokens.Colors.backgroundSecondary))
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : DesignTokens.Colors.separator.opacity(0.5), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(DesignTokens.Animation.fast) {
                isHovered = hovering
            }
        }
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Preview

#Preview {
    AppInventoryView()
        .frame(width: 900, height: 700)
}
