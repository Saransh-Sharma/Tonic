//
//  ScanCategoryScanner.swift
//  Tonic
//
//  Dedicated service for category-specific scanning
//  Discovers detailed file categories for comprehensive scan results
//

import Foundation
import OSLog

// Note: Assumes ScanResult.swift models are imported via module
// Imports: JunkCategory, PerformanceCategory, AppIssueCategory, FileGroup, AppMetadata, DuplicateAppGroup, OrphanedFile, ScanConfiguration

// MARK: - Scan Category Scanner

@Observable
final class ScanCategoryScanner: @unchecked Sendable {
    private let logger = Logger(subsystem: "com.tonic.app", category: "ScanCategoryScanner")
    private let fileManager = FileManager.default
    private let sizeCache = DirectorySizeCache.shared
    private let lock = NSLock()

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

        if fileManager.fileExists(atPath: trashPath) {
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

        guard let contents = try? fileManager.contentsOfDirectory(
            at: URL(fileURLWithPath: libraryPath),
            includingPropertiesForKeys: [.isDirectoryKey]
        ) else {
            return FileGroup(name: "Language Files", description: "Unused language files", paths: [], size: 0, count: 0)
        }

        for item in contents {
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

        guard let contents = try? fileManager.contentsOfDirectory(
            at: URL(fileURLWithPath: downloadsPath),
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return FileGroup(name: "Old Files", description: "Old files in Downloads", paths: [], size: 0, count: 0)
        }

        for url in contents {
            guard let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]) else {
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

        for path in launchAgentPaths where fileManager.fileExists(atPath: path) {
            guard let contents = try? fileManager.contentsOfDirectory(
                at: URL(fileURLWithPath: path),
                includingPropertiesForKeys: [.fileSizeKey]
            ) else { continue }

            for item in contents {
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

        if fileManager.fileExists(atPath: loginItemsPath) {
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

        for path in browserCachePaths where fileManager.fileExists(atPath: path) {
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

        for appPath in appPaths where fileManager.fileExists(atPath: appPath) {
            guard let apps = try? fileManager.contentsOfDirectory(
                at: URL(fileURLWithPath: appPath),
                includingPropertiesForKeys: [.isApplicationKey]
            ) else { continue }

            for app in apps where app.pathExtension == "app" {
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

        for appPath in appPaths where fileManager.fileExists(atPath: appPath) {
            guard let apps = try? fileManager.contentsOfDirectory(
                at: URL(fileURLWithPath: appPath),
                includingPropertiesForKeys: nil
            ) else { continue }

            for app in apps where app.pathExtension == "app" {
                let appName = app.deletingPathExtension().lastPathComponent
                appsByName[appName, default: []].append(app)
            }
        }

        for (appName, paths) in appsByName where paths.count > 1 {
            var metadatas: [AppMetadata] = []
            var totalSize: Int64 = 0

            for path in paths {
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

        guard let contents = try? fileManager.contentsOfDirectory(
            at: URL(fileURLWithPath: appSupportPath),
            includingPropertiesForKeys: [.isDirectoryKey]
        ) else {
            return []
        }

        for item in contents {
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
        let baseURL = URL(fileURLWithPath: path)

        guard let contents = try? fileManager.contentsOfDirectory(
            at: baseURL,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return (0, 0)
        }

        var totalSize: Int64 = 0
        var fileCount = 0

        for url in contents {
            guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]) else {
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

        return paths.filter { fileManager.fileExists(atPath: $0) }
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

        return paths.filter { fileManager.fileExists(atPath: $0) }
    }

    private func getLogDirectories() -> [String] {
        var paths: [String] = []

        let home = fileManager.homeDirectoryForCurrentUser.path

        paths.append(home + "/Library/Logs")
        paths.append(home + "/Library/Logs/DiagnosticReports")
        paths.append("/Library/Logs")

        return paths.filter { fileManager.fileExists(atPath: $0) }
    }

    private func isAppInstalled(_ appName: String) -> Bool {
        let appPaths = [
            "/Applications/\(appName).app",
            fileManager.homeDirectoryForCurrentUser.path + "/Applications/\(appName).app"
        ]
        return appPaths.contains { fileManager.fileExists(atPath: $0) }
    }

    private func extractBundleID(from appPath: String) -> String? {
        let infoPlistPath = appPath + "/Contents/Info.plist"
        guard let plist = NSDictionary(contentsOfFile: infoPlistPath) else {
            return nil
        }
        return plist["CFBundleIdentifier"] as? String
    }

    private func extractVersion(from appPath: String) -> String? {
        let infoPlistPath = appPath + "/Contents/Info.plist"
        guard let plist = NSDictionary(contentsOfFile: infoPlistPath) else {
            return nil
        }
        return plist["CFBundleShortVersionString"] as? String ?? plist["CFBundleVersion"] as? String
    }
}
