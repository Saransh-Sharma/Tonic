//
//  AppInventoryService.swift
//  Tonic
//
//  Central service for app inventory management, scanning, filtering, and uninstallation.
//

import Foundation
import SwiftUI

// MARK: - ActionTableItem Conformance

extension AppMetadata: ActionTableItem {}

// MARK: - App Inventory Service

@MainActor
class AppInventoryService: ObservableObject {
    @Published var apps: [AppMetadata] = []
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var progress: Double = 0
    @Published var searchText = "" {
        didSet { recomputeFilteredApps() }
    }
    @Published var sortOption: SortOption = .sizeDescending {
        didSet { recomputeFilteredApps() }
    }
    @Published var selectedTab: ItemType = .apps {
        didSet { recomputeFilteredApps() }
    }
    @Published var quickFilterCategory: QuickFilterCategory = .all {
        didSet { recomputeFilteredApps() }
    }
    @Published var loginItemFilter: LoginItemFilter = .all {
        didSet { recomputeFilteredApps() }
    }
    @Published var selectedAppIDs: Set<UUID> = []
    @Published var isSelecting = false
    @Published var isUninstalling = false
    @Published var uninstallProgress: Double = 0
    @Published var isCheckingUpdates = false
    @Published var availableUpdates: Int = 0
    @Published var appsWithUpdates: Set<String> = []
    @Published var errorMessage: String?
    @Published var lastScanDate: Date?

    // Cached filter results (updated via recomputeFilteredApps)
    @Published private(set) var filteredApps: [AppMetadata] = []
    @Published private(set) var appsInCurrentTab: [AppMetadata] = []
    @Published private(set) var totalAppsSize: Int64 = 0

    // View mode (list vs grid) with persistence
    @Published var viewMode: AppViewMode = AppViewMode(rawValue: UserDefaults.standard.string(forKey: "appManagerViewMode") ?? "") ?? .list

    // Login items and background activities
    @Published var loginItems: [LoginItem] = []
    @Published var launchServices: [LaunchService] = []
    @Published var backgroundActivities: [BackgroundActivityItem] = []

    private let updater = AppUpdater.shared
    let cache = AppCache.shared
    private let scanner = BackgroundAppScanner()
    private let scopedFS = ScopedFileSystem.shared
    let fileOps = FileOperations.shared
    private let activityLog = ActivityLogStore.shared
    private let loginItemsManager = LoginItemsManager.shared
    private let backgroundActivityManager = BackgroundActivityManager.shared

    private var scanTask: Task<Void, Never>?
    private(set) var hasScannedThisSession = false

    // MARK: - Singleton

    public static let shared = AppInventoryService()

    private init() {
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
            hasScannedThisSession = true
            recomputeFilteredApps()
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
        scanTask?.cancel()

        if apps.isEmpty {
            loadCachedApps()
        }

        scanTask = Task {
            await performFastScan()
        }

        await scanTask?.value
    }

    func refreshSizes() async {
        guard !apps.isEmpty else { return }

        isRefreshing = true
        defer { isRefreshing = false }

        let paths = apps.map { $0.path.path }
        let sizes = await scanner.calculateSizes(for: paths)

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

        recomputeFilteredApps()
        cache.saveApps(apps)
    }

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
        let scanStart = Date()
        isLoading = true
        errorMessage = nil
        progress = 0

        let fastApps = await scanner.scanAppsFast()

        guard !Task.isCancelled else {
            isLoading = false
            return
        }

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
        apps = tempApps
        isLoading = false
        isRefreshing = true
        recomputeFilteredApps()

        let paths = tempApps.map { $0.path.path }
        let sizes = await scanner.calculateSizes(for: paths)

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
        hasScannedThisSession = true
        recomputeFilteredApps()

        cache.saveApps(apps)
        await fetchLoginItemsAndBackgroundActivities()
        await checkForUpdates()

        let duration = Date().timeIntervalSince(scanStart)
        let detail = "Found \(apps.count) apps · Updates \(availableUpdates) · Duration \(formatDuration(duration))"
        let event = ActivityEvent(
            category: .app,
            title: "App scan completed",
            detail: detail,
            impact: .low
        )
        activityLog.record(event)
    }

    private func fetchLoginItemsAndBackgroundActivities() async {
        await loginItemsManager.fetchLoginItems()
        await loginItemsManager.fetchLaunchServices()
        await backgroundActivityManager.fetchBackgroundActivities()

        loginItems = loginItemsManager.loginItems
        launchServices = loginItemsManager.launchServices
        backgroundActivities = backgroundActivityManager.backgroundActivities
    }

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

        apps = apps.map { app in
            var updatedApp = app
            updatedApp.hasUpdate = appsWithUpdates.contains(app.bundleIdentifier)
            return updatedApp
        }
        recomputeFilteredApps()
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

    /// Recomputes cached filteredApps, appsInCurrentTab, and totalAppsSize.
    /// Call whenever apps, selectedTab, quickFilterCategory, searchText, sortOption, or loginItemFilter change.
    func recomputeFilteredApps() {
        appsInCurrentTab = computeAppsInCurrentTab()
        filteredApps = computeFilteredApps()
        totalAppsSize = apps.reduce(0) { $0 + $1.totalSize }
    }

    private func matches(selectedTab: ItemType, for app: AppMetadata) -> Bool {
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

    private func matches(quickFilter: QuickFilterCategory, for app: AppMetadata) -> Bool {
        switch quickFilter {
        case .all:
            return true
        case .leastUsed:
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
            return ![.development, .games, .productivity, .utilities, .social, .creativity].contains(app.category)
        }
    }

    private func sortApps(_ apps: inout [AppMetadata], by option: SortOption, quickFilter: QuickFilterCategory) {
        if quickFilter == .leastUsed {
            apps.sort { ($0.lastUsed ?? .distantPast) < ($1.lastUsed ?? .distantPast) }
            return
        }

        switch option {
        case .nameAscending:
            apps.sort { $0.name.localizedCompare($1.name) == .orderedAscending }
        case .nameDescending:
            apps.sort { $0.name.localizedCompare($1.name) == .orderedDescending }
        case .sizeDescending:
            apps.sort { $0.totalSize > $1.totalSize }
        case .sizeAscending:
            apps.sort { $0.totalSize < $1.totalSize }
        case .category:
            apps.sort { $0.category.rawValue < $1.category.rawValue }
        case .dateInstalled:
            apps.sort { ($0.installDate ?? .distantPast) > ($1.installDate ?? .distantPast) }
        case .lastUsed:
            apps.sort { ($0.lastUsed ?? .distantPast) > ($1.lastUsed ?? .distantPast) }
        case .updateStatus:
            apps.sort { $0.hasUpdate && !$1.hasUpdate }
        }
    }

    private func computeFilteredApps() -> [AppMetadata] {
        var result = apps.filter { matches(selectedTab: selectedTab, for: $0) }

        // Quick filter category
        if quickFilterCategory != .all {
            result = result.filter { matches(quickFilter: quickFilterCategory, for: $0) }
        }

        // Search filter
        if !searchText.isEmpty {
            result = result.filter { app in
                app.name.localizedCaseInsensitiveContains(searchText) ||
                app.bundleIdentifier.localizedCaseInsensitiveContains(searchText)
            }
        }

        sortApps(&result, by: sortOption, quickFilter: quickFilterCategory)

        return result
    }

    private func computeAppsInCurrentTab() -> [AppMetadata] {
        apps.filter { matches(selectedTab: selectedTab, for: $0) }
    }

    var availableQuickFilters: [QuickFilterCategory] {
        let categoriesInTab = Set(appsInCurrentTab.map { $0.category })

        var filters: [QuickFilterCategory] = [.all, .leastUsed]

        if categoriesInTab.contains(.development) { filters.append(.development) }
        if categoriesInTab.contains(.games) { filters.append(.games) }
        if categoriesInTab.contains(.productivity) { filters.append(.productivity) }
        if categoriesInTab.contains(.utilities) { filters.append(.utilities) }
        if categoriesInTab.contains(.social) { filters.append(.social) }
        if categoriesInTab.contains(.creativity) { filters.append(.creative) }
        if !categoriesInTab.isSubset(of: [.development, .games, .productivity, .utilities, .social, .creativity]) {
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
        await uninstallApps(selectedApps)
    }

    func uninstallApps(
        _ appsToDelete: [AppMetadata],
        progressHandler: ((Int, Int, AppMetadata, Int64) -> Void)? = nil
    ) async -> UninstallResult {
        isUninstalling = true
        uninstallProgress = 0
        defer { isUninstalling = false }

        if appsToDelete.isEmpty {
            return UninstallResult(success: false, appsUninstalled: 0, bytesFreed: 0, errors: [])
        }
        var successCount = 0
        var bytesFreed: Int64 = 0
        var errors: [UninstallError] = []

        for (index, app) in appsToDelete.enumerated() {
            progressHandler?(index, appsToDelete.count, app, bytesFreed)

            if Task.isCancelled {
                errors.append(UninstallError(path: app.path.path, message: "Cancelled"))
                break
            }

            let access = scopedFS.accessState(forPath: app.path.path, requiresWrite: true)
            if access.state != .ready {
                errors.append(
                    UninstallError(
                        path: app.path.path,
                        message: access.reason?.userMessage ?? "Missing access scope"
                    )
                )
                uninstallProgress = Double(index + 1) / Double(appsToDelete.count)
                continue
            }

            if ProtectedApps.isProtectedFromUninstall(app.bundleIdentifier) {
                errors.append(UninstallError(path: app.path.path, message: "Protected app"))
                uninstallProgress = Double(index + 1) / Double(appsToDelete.count)
                continue
            }

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

        progressHandler?(appsToDelete.count, appsToDelete.count, appsToDelete.last ?? appsToDelete[0], bytesFreed)

        recomputeFilteredApps()
        cache.saveApps(apps)

        let detail = "Removed \(successCount) apps · Freed \(ByteCountFormatter.string(fromByteCount: bytesFreed, countStyle: .file)) · Errors \(errors.count)"
        let event = ActivityEvent(
            category: .app,
            title: "Apps uninstalled",
            detail: detail,
            impact: errors.isEmpty ? .low : .medium
        )
        activityLog.record(event)

        return UninstallResult(
            success: successCount > 0,
            appsUninstalled: successCount,
            bytesFreed: bytesFreed,
            errors: errors
        )
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        String(format: "%.1fs", seconds)
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
