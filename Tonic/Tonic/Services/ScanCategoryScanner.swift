//
//  ScanCategoryScanner.swift
//  Tonic
//
//  Dedicated service for category-specific scanning
//  Discovers detailed file categories for comprehensive scan results
//

import Foundation
import CryptoKit
import OSLog

// Note: Assumes ScanResult.swift models are imported via module
// Imports: JunkCategory, PerformanceCategory, AppIssueCategory, FileGroup, AppMetadata, DuplicateAppGroup, OrphanedFile, ScanConfiguration

// MARK: - Scan Category Scanner

struct LargeOldFileEntry: Hashable, Sendable {
    let path: String
    let size: Int64
    let modificationDate: Date?
}

struct DuplicateFileGroup: Hashable, Sendable {
    let fingerprint: String
    let paths: [String]
    let sizePerFile: Int64

    var totalSize: Int64 {
        Int64(paths.count) * sizePerFile
    }

    var reclaimableEstimate: Int64 {
        Int64(max(0, paths.count - 1)) * sizePerFile
    }
}

struct ClutterScanResult: Sendable {
    let largeOldFiles: [LargeOldFileEntry]
    let duplicateFiles: [DuplicateFileGroup]
    let scannedRoots: [String]
    let inaccessibleRoots: [String]
    let duplicateCandidateCapReached: Bool
    let largeOldCandidateCapReached: Bool
    let wasCancelled: Bool

    var totalLargeOldSize: Int64 {
        largeOldFiles.reduce(0) { $0 + $1.size }
    }

    var duplicateReclaimableSize: Int64 {
        duplicateFiles.reduce(0) { $0 + $1.reclaimableEstimate }
    }

    var needsAdditionalAccess: Bool {
        scannedRoots.isEmpty && !inaccessibleRoots.isEmpty
    }

    var hasPartialResults: Bool {
        duplicateCandidateCapReached || largeOldCandidateCapReached || wasCancelled
    }
}

@Observable
final class ScanCategoryScanner: @unchecked Sendable {
    private let logger = Logger(subsystem: "com.tonic.app", category: "ScanCategoryScanner")
    private let fileManager = FileManager.default
    private let sizeCache = DirectorySizeCache.shared
    private let lock = NSLock()
    private let scopedFS = ScopedFileSystem.shared

    // MARK: - Junk Files Scanning

    func scanJunkFiles(configuration: ScanConfiguration = .default) async -> JunkCategory {
        let tempFiles = await scanTempFiles()
        let cacheFiles = await scanCacheFiles()
        let logFiles = await scanLogFiles()
        let trashItems = await scanTrashItems()
        let languageFiles = await scanLanguageFiles()
        let oldFiles = await scanOldFiles(thresholdDays: configuration.oldFileThresholdDays)

        return JunkCategory(
            tempFiles: tempFiles,
            cacheFiles: cacheFiles,
            logFiles: logFiles,
            trashItems: trashItems,
            languageFiles: languageFiles,
            oldFiles: oldFiles
        )
    }

    private func scanTempFiles() async -> FileGroup {
        var paths: [String] = []
        var totalSize: Int64 = 0
        var fileCount = 0

        let tempPaths = getTempDirectories()

        for path in tempPaths {
            if Task.isCancelled { break }
            let (size, count) = await measureFilesInPath(path)
            if size > 0 {
                paths.append(path)
                totalSize += size
                fileCount += count
            }
        }

        return FileGroup(
            name: "Temporary Files",
            description: "Temporary files created during application usage",
            paths: paths,
            size: totalSize,
            count: fileCount
        )
    }

    private func scanCacheFiles() async -> FileGroup {
        var paths: [String] = []
        var totalSize: Int64 = 0
        var fileCount = 0

        let cachePaths = getCacheDirectories()

        for path in cachePaths {
            if Task.isCancelled { break }
            let (size, count) = await measureFilesInPath(path)
            if size > 0 {
                paths.append(path)
                totalSize += size
                fileCount += count
            }
        }

        return FileGroup(
            name: "Cache Files",
            description: "Cached data from applications and system services",
            paths: paths,
            size: totalSize,
            count: fileCount
        )
    }

    private func scanLogFiles() async -> FileGroup {
        var paths: [String] = []
        var totalSize: Int64 = 0
        var fileCount = 0

        let logPaths = getLogDirectories()

        for path in logPaths {
            if Task.isCancelled { break }
            let (size, count) = await measureFilesInPath(path, minAgeHours: 24)
            if size > 0 {
                paths.append(path)
                totalSize += size
                fileCount += count
            }
        }

        return FileGroup(
            name: "Log Files",
            description: "Application and system log files",
            paths: paths,
            size: totalSize,
            count: fileCount
        )
    }

    private func scanTrashItems() async -> FileGroup {
        var paths: [String] = []
        var totalSize: Int64 = 0
        var fileCount = 0

        let home = fileManager.homeDirectoryForCurrentUser.path
        let trashPath = home + "/.Trash"

        if scopedFS.fileExists(atPath: trashPath) {
            let (size, count) = await measureFilesInPath(trashPath)
            if size > 0 {
                paths.append(trashPath)
                totalSize = size
                fileCount = count
            }
        }

        return FileGroup(
            name: "Trash Items",
            description: "Files in the Trash that can be permanently deleted",
            paths: paths,
            size: totalSize,
            count: fileCount
        )
    }

    private func scanLanguageFiles() async -> FileGroup {
        var paths: [String] = []
        var totalSize: Int64 = 0
        var fileCount = 0

        let home = fileManager.homeDirectoryForCurrentUser.path
        let libraryPath = home + "/Library"

        guard scopedFS.canRead(path: libraryPath),
              let contents = try? scopedFS.contentsOfDirectory(
            atPath: libraryPath,
            includingPropertiesForKeys: [.isDirectoryKey]
        ) else {
            return FileGroup(name: "Language Files", description: "Unused language files", paths: [], size: 0, count: 0)
        }

        for item in contents {
            if Task.isCancelled { break }
            let path = item.path
            let name = (path as NSString).lastPathComponent

            // Look for language packs in app support
            if name.contains("Languages") || name.contains("language") {
                let (size, count) = await measureFilesInPath(path)
                if size > 0 {
                    paths.append(path)
                    totalSize += size
                    fileCount += count
                }
            }
        }

        return FileGroup(
            name: "Language Files",
            description: "Unused language packs and localization files",
            paths: paths,
            size: totalSize,
            count: fileCount
        )
    }

    private func scanOldFiles(thresholdDays: Int) async -> FileGroup {
        var paths: [String] = []
        var totalSize: Int64 = 0
        var fileCount = 0

        let home = fileManager.homeDirectoryForCurrentUser.path
        let downloadsPath = home + "/Downloads"

        let thresholdDate = Date().addingTimeInterval(-TimeInterval(thresholdDays * 24 * 3600))

        guard scopedFS.canRead(path: downloadsPath),
              let contents = try? scopedFS.contentsOfDirectory(
            atPath: downloadsPath,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return FileGroup(name: "Old Files", description: "Old files in Downloads", paths: [], size: 0, count: 0)
        }

        for url in contents {
            if Task.isCancelled { break }
            guard let resourceValues = try? scopedFS.resourceValues(
                for: url,
                keys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]
            ) else {
                continue
            }
            guard let modDate = resourceValues.contentModificationDate, modDate < thresholdDate else { continue }
            if resourceValues.isDirectory == true {
                if let size = sizeCache.size(for: url.path, includeHidden: false) {
                    paths.append(url.path)
                    totalSize += size
                    fileCount += 1
                }
            } else {
                let size = Int64(resourceValues.fileSize ?? 0)
                if size > 0 {
                    paths.append(url.path)
                    totalSize += size
                    fileCount += 1
                }
            }
        }

        return FileGroup(
            name: "Old Files",
            description: "Older files in Downloads folder",
            paths: paths,
            size: totalSize,
            count: fileCount
        )
    }

    // MARK: - Clutter Scanning

    /// Depth preset for clutter scanning. Quick keeps the scan within the Smart
    /// Scan time budget; Deep raises the caps for more complete results.
    enum ClutterScanDepth: String, Sendable, CaseIterable {
        case quick
        case deep
    }

    /// Convenience entry point selecting caps and scan breadth from a depth preset.
    /// Quick scans the current user's personal folders within the time budget; Deep
    /// scans the whole startup disk across all users with larger caps.
    func scanClutterFiles(roots: [String]? = nil, depth: ClutterScanDepth) async -> ClutterScanResult {
        switch depth {
        case .quick:
            return await scanClutterFiles(
                roots: roots,
                maxLargeOldCandidates: 1_000,
                maxDuplicateHashCandidates: 600,
                maxDuplicateGroups: 100
            )
        case .deep:
            return await scanClutterFiles(
                roots: roots ?? wholeDiskClutterRoots(),
                maxLargeOldCandidates: 5_000,
                maxDuplicateHashCandidates: 4_000,
                maxDuplicateGroups: 250
            )
        }
    }

    /// Whole-disk roots for a Deep scan: the startup volume root (covering all
    /// users) when accessible, otherwise the broadest authorized scopes.
    private func wholeDiskClutterRoots() -> [String] {
        if BuildCapabilities.current.requiresScopeAccess {
            let activeScopes = AccessBroker.shared.activeScopes.filter { $0.kind != .applications }
            // Prefer a full-disk / startup-disk scope if the user has granted one.
            if let broad = activeScopes.first(where: { $0.kind == .startupDisk }) {
                return [broad.rootPath]
            }
            if !activeScopes.isEmpty {
                return activeScopes.map(\.rootPath)
            }
            // No broad scope granted — fall back to the personal folders we can read.
            return defaultClutterRoots()
        }
        // Non-sandboxed (Full Disk Access) build: scan the whole startup disk
        // (covers all users). System-owned files surface but are gated as
        // non-runnable by write-access checks, so they can't be deleted.
        return ["/"]
    }

    func scanClutterFiles(
        roots: [String]? = nil,
        largeFileThresholdBytes: Int64 = 100 * 1024 * 1024,
        oldFileThresholdDays: Int = ScanConfiguration.default.oldFileThresholdDays,
        duplicateMinFileSizeBytes: Int64 = 1 * 1024 * 1024,
        maxLargeOldCandidates: Int = 1_000,
        maxDuplicateHashCandidates: Int = 600,
        maxDuplicateGroups: Int = 100
    ) async -> ClutterScanResult {
        let scanRoots = roots ?? defaultClutterRoots()
        let oldThresholdDate = Date().addingTimeInterval(-TimeInterval(oldFileThresholdDays * 24 * 60 * 60))
        // Collect generously, then apply the meaningful (value-prioritized) caps by
        // sorting on size. Hard ceilings guard memory against pathological trees.
        let largeOldCollectionCeiling = max(maxLargeOldCandidates * 8, 8_000)
        let duplicateCollectionCeiling = max(maxDuplicateHashCandidates * 40, 40_000)

        var largeOldFiles: [LargeOldFileEntry] = []
        var candidatesBySize: [Int64: [String]] = [:]
        var scannedRoots: [String] = []
        var inaccessibleRoots: [String] = []
        var duplicateCandidateCount = 0
        var duplicateCandidateCapReached = false
        var largeOldCandidateCapReached = false
        var wasCancelled = false

        for root in scanRoots {
            if Task.isCancelled {
                wasCancelled = true
                break
            }
            guard fileManager.fileExists(atPath: root) else {
                inaccessibleRoots.append(root)
                continue
            }
            guard scopedFS.canRead(path: root) else {
                inaccessibleRoots.append(root)
                continue
            }
            scannedRoots.append(root)
            do {
                try scopedFS.enumerateDirectory(
                    atPath: root,
                    includingPropertiesForKeys: [
                        .isRegularFileKey,
                        .isDirectoryKey,
                        .fileSizeKey,
                        .totalFileAllocatedSizeKey,
                        .contentModificationDateKey
                    ],
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                ) { url in
                    if Task.isCancelled { throw CancellationError() }
                    guard let values = try? scopedFS.resourceValues(
                        for: url,
                        keys: [.isRegularFileKey, .fileSizeKey, .totalFileAllocatedSizeKey, .contentModificationDateKey]
                    ) else {
                        return
                    }
                    guard values.isRegularFile == true else { return }

                    let size = Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
                    guard size > 0 else { return }

                    if size >= largeFileThresholdBytes,
                       let modified = values.contentModificationDate,
                       modified < oldThresholdDate {
                        if largeOldFiles.count < largeOldCollectionCeiling {
                            largeOldFiles.append(LargeOldFileEntry(path: url.path, size: size, modificationDate: modified))
                        } else {
                            largeOldCandidateCapReached = true
                        }
                    }

                    if size >= duplicateMinFileSizeBytes {
                        if duplicateCandidateCount < duplicateCollectionCeiling {
                            candidatesBySize[size, default: []].append(url.path)
                            duplicateCandidateCount += 1
                        } else {
                            duplicateCandidateCapReached = true
                        }
                    }
                }
            } catch is CancellationError {
                wasCancelled = true
                break
            } catch {
                logger.debug("Skipping clutter root: \(root) - \(error.localizedDescription)")
            }
        }

        // Value-prioritized cap for large/old files: keep the biggest.
        if largeOldFiles.count > maxLargeOldCandidates {
            largeOldCandidateCapReached = true
        }
        let cappedLargeOld = Array(largeOldFiles.sorted { $0.size > $1.size }.prefix(maxLargeOldCandidates))

        let duplicateScan = await findDuplicateFiles(
            in: candidatesBySize,
            maxHashCandidates: maxDuplicateHashCandidates,
            maxGroups: maxDuplicateGroups
        )
        duplicateCandidateCapReached = duplicateCandidateCapReached || duplicateScan.capReached
        wasCancelled = wasCancelled || duplicateScan.wasCancelled

        return ClutterScanResult(
            largeOldFiles: Array(cappedLargeOld.prefix(250)),
            duplicateFiles: Array(duplicateScan.groups.sorted { $0.reclaimableEstimate > $1.reclaimableEstimate }.prefix(maxDuplicateGroups)),
            scannedRoots: scannedRoots,
            inaccessibleRoots: inaccessibleRoots,
            duplicateCandidateCapReached: duplicateCandidateCapReached,
            largeOldCandidateCapReached: largeOldCandidateCapReached,
            wasCancelled: wasCancelled
        )
    }

    private func defaultClutterRoots() -> [String] {
        let home = fileManager.homeDirectoryForCurrentUser.path
        let defaultRoots = [
            home + "/Downloads",
            home + "/Desktop",
            home + "/Documents",
            home + "/Movies",
            home + "/Music",
            home + "/Pictures"
        ]

        if BuildCapabilities.current.requiresScopeAccess {
            let activeScopes = AccessBroker.shared.activeScopes.filter { $0.kind != .applications }
            if activeScopes.contains(where: { $0.kind == .startupDisk || $0.kind == .home }) {
                return defaultRoots.filter { fileManager.fileExists(atPath: $0) && scopedFS.canRead(path: $0) }
            }
            if !activeScopes.isEmpty {
                return activeScopes.map(\.rootPath)
            }
            return defaultRoots
        }

        return defaultRoots.filter { fileManager.fileExists(atPath: $0) }
    }

    private func findDuplicateFiles(
        in candidatesBySize: [Int64: [String]],
        maxHashCandidates: Int,
        maxGroups: Int
    ) async -> (groups: [DuplicateFileGroup], capReached: Bool, wasCancelled: Bool) {
        var groups: [DuplicateFileGroup] = []
        var hashedCount = 0
        var capReached = false

        // Only sizes with collisions can hold duplicates; process the largest files
        // first so the most impactful duplicates survive the hash-candidate cap.
        let sizeGroups = candidatesBySize
            .filter { $0.value.count > 1 }
            .sorted { $0.key > $1.key }

        outer: for (size, paths) in sizeGroups {
            if Task.isCancelled { return (groups, capReached, true) }

            // Cheap 4 KB head-hash first to avoid full reads of same-size non-duplicates.
            var byHead: [String: [String]] = [:]
            for path in paths {
                if Task.isCancelled { return (groups, capReached, true) }
                if hashedCount >= maxHashCandidates {
                    capReached = true
                    break outer
                }
                guard let head = contentHash(forPath: path, prefixBytes: 4096) else { continue }
                byHead[head, default: []].append(path)
                hashedCount += 1
                if hashedCount.isMultiple(of: 50) {
                    await Task.yield()
                }
            }

            // Confirm head-hash collisions with a full content hash.
            for (_, headPaths) in byHead where headPaths.count > 1 {
                var byFull: [String: [String]] = [:]
                for path in headPaths {
                    if Task.isCancelled { return (groups, capReached, true) }
                    guard let full = contentHash(forPath: path) else { continue }
                    byFull[full, default: []].append(path)
                }
                for (hash, duplicatePaths) in byFull where duplicatePaths.count > 1 {
                    groups.append(DuplicateFileGroup(
                        fingerprint: hash,
                        paths: duplicatePaths.sorted(),
                        sizePerFile: size
                    ))
                    if groups.count >= maxGroups {
                        return (groups, capReached, false)
                    }
                }
            }
        }

        return (groups, capReached, false)
    }

    /// Content hash of a file. Pass `prefixBytes` to hash only the first N bytes
    /// (a cheap pre-filter); omit it to hash the entire file.
    private func contentHash(forPath path: String, prefixBytes: Int? = nil) -> String? {
        do {
            return try scopedFS.withReadAccess(path: path) {
                guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
                defer { try? handle.close() }

                var hasher = SHA256()
                if let prefixBytes {
                    let data = handle.readData(ofLength: prefixBytes)
                    hasher.update(data: data)
                } else {
                    while autoreleasepool(invoking: {
                        let data = handle.readData(ofLength: 1024 * 1024)
                        guard !data.isEmpty else { return false }
                        hasher.update(data: data)
                        return true
                    }) {}
                }

                return hasher.finalize().map { String(format: "%02x", $0) }.joined()
            }
        } catch {
            return nil
        }
    }

    // MARK: - Performance Issues Scanning

    func scanPerformanceIssues() async -> PerformanceCategory {
        let launchAgents = await scanLaunchAgents()
        let loginItems = await scanLoginItems()
        let browserCaches = await scanBrowserCaches()

        return PerformanceCategory(
            launchAgents: launchAgents,
            loginItems: loginItems,
            browserCaches: browserCaches,
            memoryIssues: [],
            diskFragmentation: nil
        )
    }

    private func scanLaunchAgents() async -> FileGroup {
        var paths: [String] = []
        var totalSize: Int64 = 0
        var fileCount = 0

        let home = fileManager.homeDirectoryForCurrentUser.path
        let launchAgentPaths = [
            home + "/Library/LaunchAgents",
            "/Library/LaunchAgents",
            "/Library/LaunchDaemons"
        ]

        for path in launchAgentPaths where scopedFS.fileExists(atPath: path) {
            if Task.isCancelled { break }
            guard let contents = try? scopedFS.contentsOfDirectory(
                atPath: path,
                includingPropertiesForKeys: [.fileSizeKey]
            ) else { continue }

            for item in contents {
                if Task.isCancelled { break }
                let (size, _) = await measureFilesInPath(item.path)
                if size > 0 {
                    paths.append(item.path)
                    totalSize += size
                    fileCount += 1
                }
            }
        }

        return FileGroup(
            name: "Launch Agents",
            description: "Background launch agents that may impact performance",
            paths: paths,
            size: totalSize,
            count: fileCount
        )
    }

    private func scanLoginItems() async -> FileGroup {
        var paths: [String] = []
        var totalSize: Int64 = 0
        var fileCount = 0

        let home = fileManager.homeDirectoryForCurrentUser.path
        let loginItemsPath = home + "/Library/Preferences/loginwindow.plist"

        if scopedFS.fileExists(atPath: loginItemsPath) {
            let (size, _) = await measureFilesInPath(loginItemsPath)
            if size > 0 {
                paths.append(loginItemsPath)
                totalSize = size
                fileCount = 1
            }
        }

        return FileGroup(
            name: "Login Items",
            description: "Applications that launch at startup",
            paths: paths,
            size: totalSize,
            count: fileCount
        )
    }

    private func scanBrowserCaches() async -> FileGroup {
        var paths: [String] = []
        var totalSize: Int64 = 0
        var fileCount = 0

        let home = fileManager.homeDirectoryForCurrentUser.path
        let browserCachePaths = [
            home + "/Library/Caches/Google/Chrome",
            home + "/Library/Caches/com.apple.Safari",
            home + "/Library/Caches/Firefox",
            home + "/Library/Caches/Mozilla/Firefox"
        ]

        for path in browserCachePaths where scopedFS.fileExists(atPath: path) {
            if Task.isCancelled { break }
            let (size, count) = await measureFilesInPath(path)
            if size > 0 {
                paths.append(path)
                totalSize += size
                fileCount += count
            }
        }

        return FileGroup(
            name: "Browser Caches",
            description: "Cached data from web browsers",
            paths: paths,
            size: totalSize,
            count: fileCount
        )
    }

    // MARK: - App Issues Scanning

    func scanAppIssues() async -> AppIssueCategory {
        let unusedApps = await findUnusedApps()
        let largeApps = await findLargeApps()
        let duplicateApps = await findDuplicateApps()
        let orphanedFiles = await findOrphanedFiles()

        return AppIssueCategory(
            unusedApps: unusedApps,
            largeApps: largeApps,
            duplicateApps: duplicateApps,
            orphanedFiles: orphanedFiles
        )
    }

    private func findUnusedApps() async -> [AppMetadata] {
        // This would integrate with the app inventory system
        // For now, return empty array as this requires tracking app usage
        return []
    }

    private func findLargeApps() async -> [AppMetadata] {
        var largeApps: [AppMetadata] = []
        let appPaths = ["/Applications", fileManager.homeDirectoryForCurrentUser.path + "/Applications"]

        for appPath in appPaths where scopedFS.fileExists(atPath: appPath) {
            if Task.isCancelled { break }
            guard let apps = try? scopedFS.contentsOfDirectory(
                atPath: appPath,
                includingPropertiesForKeys: [.isApplicationKey]
            ) else { continue }

            for app in apps where app.pathExtension == "app" {
                if Task.isCancelled { break }
                let appName = app.deletingPathExtension().lastPathComponent
                let (size, _) = await measureFilesInPath(app.path)

                // Only include apps larger than 500MB
                if size > 500 * 1024 * 1024 {
                    let metadata = AppMetadata(
                        bundleIdentifier: extractBundleID(from: app.path) ?? "",
                        appName: appName,
                        path: app,
                        version: extractVersion(from: app.path),
                        totalSize: size,
                        lastUsed: nil
                    )
                    largeApps.append(metadata)
                }
            }
        }

        return largeApps.sorted { $0.totalSize > $1.totalSize }
    }

    private func findDuplicateApps() async -> [DuplicateAppGroup] {
        var duplicates: [DuplicateAppGroup] = []
        var appsByName: [String: [URL]] = [:]

        let appPaths = ["/Applications", fileManager.homeDirectoryForCurrentUser.path + "/Applications"]

        for appPath in appPaths where scopedFS.fileExists(atPath: appPath) {
            if Task.isCancelled { break }
            guard let apps = try? scopedFS.contentsOfDirectory(
                atPath: appPath,
                includingPropertiesForKeys: nil
            ) else { continue }

            for app in apps where app.pathExtension == "app" {
                if Task.isCancelled { break }
                let appName = app.deletingPathExtension().lastPathComponent
                appsByName[appName, default: []].append(app)
            }
        }

        for (appName, paths) in appsByName where paths.count > 1 {
            if Task.isCancelled { break }
            var metadatas: [AppMetadata] = []
            var totalSize: Int64 = 0

            for path in paths {
                if Task.isCancelled { break }
                let (size, _) = await measureFilesInPath(path.path)
                totalSize += size

                let metadata = AppMetadata(
                    bundleIdentifier: extractBundleID(from: path.path) ?? "",
                    appName: appName,
                    path: path,
                    version: extractVersion(from: path.path),
                    totalSize: size,
                    lastUsed: nil
                )
                metadatas.append(metadata)
            }

            duplicates.append(DuplicateAppGroup(
                appName: appName,
                versions: metadatas,
                totalSize: totalSize
            ))
        }

        return duplicates
    }

    private func findOrphanedFiles() async -> [OrphanedFile] {
        var orphanedFiles: [OrphanedFile] = []
        let home = fileManager.homeDirectoryForCurrentUser.path
        let appSupportPath = home + "/Library/Application Support"

        guard scopedFS.canRead(path: appSupportPath),
              let contents = try? scopedFS.contentsOfDirectory(
            atPath: appSupportPath,
            includingPropertiesForKeys: [.isDirectoryKey]
        ) else {
            return []
        }

        for item in contents {
            if Task.isCancelled { break }
            let appName = item.lastPathComponent
            let appExists = isAppInstalled(appName)

            if !appExists {
                let (size, _) = await measureFilesInPath(item.path)
                if size > 5 * 1024 * 1024 {
                    let orphanedFile = OrphanedFile(
                        id: UUID(),
                        path: item.path,
                        size: size,
                        type: .appSupport,
                        possibleSourceApp: appName
                    )
                    orphanedFiles.append(orphanedFile)
                }
            }
        }

        return orphanedFiles.sorted { $0.size > $1.size }
    }

    // MARK: - Helper Methods

    private func measureFilesInPath(_ path: String, minAgeHours: Int = 0) async -> (size: Int64, count: Int) {
        let minAgeDate = minAgeHours > 0 ? Date().addingTimeInterval(-TimeInterval(minAgeHours * 3600)) : nil
        guard scopedFS.canRead(path: path),
              let contents = try? scopedFS.contentsOfDirectory(
            atPath: path,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return (0, 0)
        }

        var totalSize: Int64 = 0
        var fileCount = 0

        for url in contents {
            if Task.isCancelled { return (totalSize, fileCount) }
            guard let values = try? scopedFS.resourceValues(
                for: url,
                keys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]
            ) else {
                continue
            }

            if let minAge = minAgeDate, let modDate = values.contentModificationDate, modDate >= minAge {
                continue
            }

            if values.isDirectory == true {
                if let size = sizeCache.size(for: url.path, includeHidden: false) {
                    totalSize += size
                    fileCount += 1
                }
            } else {
                let size = Int64(values.fileSize ?? 0)
                totalSize += size
                fileCount += 1
            }
        }

        return (totalSize, fileCount)
    }

    private func getTempDirectories() -> [String] {
        var paths: [String] = []

        let home = fileManager.homeDirectoryForCurrentUser.path

        paths.append(NSTemporaryDirectory())
        paths.append(home + "/Library/Caches/temp")
        paths.append("/var/tmp")
        paths.append("/tmp")

        return paths.filter { scopedFS.fileExists(atPath: $0) }
    }

    private func getCacheDirectories() -> [String] {
        var paths: [String] = []

        let home = fileManager.homeDirectoryForCurrentUser.path

        paths.append(home + "/Library/Caches")
        paths.append(home + "/Library/Caches/com.apple.Safari")
        paths.append(home + "/Library/Caches/Google/Chrome")
        paths.append(home + "/Library/Caches/Mozilla/Firefox")
        paths.append(home + "/Library/Developer/Xcode/DerivedData")
        paths.append(home + "/Library/Caches/CocoaPods")

        return paths.filter { scopedFS.fileExists(atPath: $0) }
    }

    private func getLogDirectories() -> [String] {
        var paths: [String] = []

        let home = fileManager.homeDirectoryForCurrentUser.path

        paths.append(home + "/Library/Logs")
        paths.append(home + "/Library/Logs/DiagnosticReports")
        paths.append("/Library/Logs")

        return paths.filter { scopedFS.fileExists(atPath: $0) }
    }

    private func isAppInstalled(_ appName: String) -> Bool {
        let appPaths = [
            "/Applications/\(appName).app",
            fileManager.homeDirectoryForCurrentUser.path + "/Applications/\(appName).app"
        ]
        return appPaths.contains { scopedFS.fileExists(atPath: $0) }
    }

    private func extractBundleID(from appPath: String) -> String? {
        let infoPlistPath = appPath + "/Contents/Info.plist"
        guard scopedFS.canRead(path: infoPlistPath),
              let plist = try? scopedFS.withReadAccess(path: infoPlistPath, operation: {
            NSDictionary(contentsOfFile: infoPlistPath)
        }) else {
            return nil
        }
        return plist["CFBundleIdentifier"] as? String
    }

    private func extractVersion(from appPath: String) -> String? {
        let infoPlistPath = appPath + "/Contents/Info.plist"
        guard scopedFS.canRead(path: infoPlistPath),
              let plist = try? scopedFS.withReadAccess(path: infoPlistPath, operation: {
            NSDictionary(contentsOfFile: infoPlistPath)
        }) else {
            return nil
        }
        return plist["CFBundleShortVersionString"] as? String ?? plist["CFBundleVersion"] as? String
    }
}
