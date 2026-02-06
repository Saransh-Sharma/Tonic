//
//  DeepCleanEngine.swift
//  Tonic
//
//  Deep clean module for comprehensive system cleanup
//  Task ID: fn-1.7
//

import Foundation
import Darwin
import OSLog

/// Categories of cleanable items
public enum DeepCleanCategory: String, Sendable, CaseIterable, Identifiable {
    case systemCache = "System Cache"
    case userCache = "User Cache"
    case logFiles = "Log Files"
    case tempFiles = "Temporary Files"
    case browserCache = "Browser Cache"
    case downloads = "Downloads"
    case trash = "Trash"
    case development = "Development Artifacts"
    case docker = "Docker"
    case xcode = "Xcode Derived Data"

    public var id: String { rawValue }

    var icon: String {
        switch self {
        case .systemCache: return "archivebox.fill"
        case .userCache: return "folder.fill"
        case .logFiles: return "doc.text.fill"
        case .tempFiles: return "clock"
        case .browserCache: return "safari"
        case .downloads: return "arrow.down.circle"
        case .trash: return "trash"
        case .development: return "hammer"
        case .docker: return "shippingbox"
        case .xcode: return "xcodes"
        }
    }

    var description: String {
        switch self {
        case .systemCache: return "System-level cache files"
        case .userCache: return "Application cache files"
        case .logFiles: return "System and application logs"
        case .tempFiles: return "Temporary files"
        case .browserCache: return "Browser cache and history"
        case .downloads: return "Old downloads"
        case .trash: return "Empty trash"
        case .development: return "Build artifacts and dependencies"
        case .docker: return "Docker images and containers"
        case .xcode: return "Xcode derived data and archives"
        }
    }
}

/// Result of a deep clean scan
public struct DeepCleanResult: Sendable, Identifiable {
    public let id = UUID()
    let category: DeepCleanCategory
    let itemCount: Int
    let totalSize: Int64
    let paths: [String]
    let safeToDelete: Bool

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
}

/// Deep clean engine for comprehensive scanning and cleaning
@Observable
public final class DeepCleanEngine: @unchecked Sendable {

    private let fileManager = FileManager.default
    private let sizeCache = DirectorySizeCache.shared

    public static let shared = DeepCleanEngine()

    private var isScanning = false
    private var scanProgress: Double = 0

    public var currentScanningCategory: String?

    private init() {}

    /// Scan for cleanable items in all categories
    public func scanAllCategories() async -> [DeepCleanResult] {
        isScanning = true
        defer { isScanning = false }

        var results: [DeepCleanResult] = []

        for (index, category) in DeepCleanCategory.allCases.enumerated() {
            currentScanningCategory = category.rawValue
            scanProgress = Double(index) / Double(DeepCleanCategory.allCases.count)

            let result = await scanCategory(category)
            results.append(result)
        }

        currentScanningCategory = nil
        scanProgress = 1.0

        return results
    }

    /// Scan a specific category
    public func scanCategory(_ category: DeepCleanCategory) async -> DeepCleanResult {
        var paths: [String] = []
        var totalSize: Int64 = 0

        switch category {
        case .systemCache:
            let cachePaths = await scanSystemCaches()
            paths = cachePaths.map { $0.path }
            totalSize = cachePaths.reduce(0) { $0 + $1.size }

        case .userCache:
            let cachePaths = await scanUserCaches()
            paths = cachePaths.map { $0.path }
            totalSize = cachePaths.reduce(0) { $0 + $1.size }

        case .logFiles:
            let logPaths = await scanLogFiles()
            paths = logPaths.map { $0.path }
            totalSize = logPaths.reduce(0) { $0 + $1.size }

        case .tempFiles:
            let tempPaths = await scanTempFiles()
            paths = tempPaths.map { $0.path }
            totalSize = tempPaths.reduce(0) { $0 + $1.size }

        case .browserCache:
            let browserPaths = await scanBrowserCaches()
            paths = browserPaths.map { $0.path }
            totalSize = browserPaths.reduce(0) { $0 + $1.size }

        case .downloads:
            let downloadPaths = await scanOldDownloads()
            paths = downloadPaths.map { $0.path }
            totalSize = downloadPaths.reduce(0) { $0 + $1.size }

        case .trash:
            let trashPaths = trashContents()
            paths = trashPaths
            totalSize = measureTrashSize(trashPaths)

        case .development:
            let devPaths = await scanDevelopmentArtifacts()
            paths = devPaths.map { $0.path }
            totalSize = devPaths.reduce(0) { $0 + $1.size }

        case .docker:
            let dockerPaths = await scanDockerArtifacts()
            paths = dockerPaths.map { $0.path }
            totalSize = dockerPaths.reduce(0) { $0 + $1.size }

        case .xcode:
            let xcodePaths = await scanXcodeArtifacts()
            paths = xcodePaths.map { $0.path }
            totalSize = xcodePaths.reduce(0) { $0 + $1.size }
        }

        return DeepCleanResult(
            category: category,
            itemCount: paths.count,
            totalSize: totalSize,
            paths: paths,
            safeToDelete: true
        )
    }

    /// Clean items in specified categories
    public func cleanCategories(_ categories: [DeepCleanCategory]) async -> Int64 {
        var bytesFreed: Int64 = 0

        for category in categories {
            bytesFreed += await cleanCategory(category)
        }

        return bytesFreed
    }

    /// Clean a specific category
    public func cleanCategory(_ category: DeepCleanCategory) async -> Int64 {
        let result = await scanCategory(category)

        guard result.safeToDelete else { return 0 }

        var bytesFreed: Int64 = 0

        for path in result.paths {
            do {
                let attrs = try? fileManager.attributesOfItem(atPath: path)
                let size = attrs?[.size] as? Int64 ?? 0
                try fileManager.removeItem(atPath: path)
                bytesFreed += size
            } catch {
                // Skip items that can't be deleted
                continue
            }
        }

        return bytesFreed
    }

    // MARK: - Scan Methods

    private struct ItemPath {
        let path: String
        let size: Int64
    }

    private func scanSystemCaches() async -> [ItemPath] {
        var paths: [ItemPath] = []
        let cacheRoots = [
            "/Library/Caches",
            "/System/Library/Caches"
        ]

        for root in cacheRoots {
            let rootURL = URL(fileURLWithPath: root)
            guard let contents = try? fileManager.contentsOfDirectory(
                at: rootURL,
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            for url in contents {
                let nameLower = url.lastPathComponent.lowercased()
                if nameLower.contains("docker") {
                    continue
                }
                let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
                if values?.isDirectory == true {
                    if let size = await getDirectorySize(url.path) {
                        paths.append(ItemPath(path: url.path, size: size))
                    }
                } else if let fileSize = values?.fileSize {
                    paths.append(ItemPath(path: url.path, size: Int64(fileSize)))
                }
            }
        }

        return paths
    }

    private func scanUserCaches() async -> [ItemPath] {
        var paths: [ItemPath] = []
        let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first?.path ?? ""
        let cacheURL = URL(fileURLWithPath: cacheDir)
        let excludedTopLevel: Set<String> = [
            "com.apple.dt.xcode",
            "com.apple.dt.xcodepreviews",
            "com.apple.safari",
            "firefox",
            "com.docker.docker"
        ]
        if let contents = try? fileManager.contentsOfDirectory(
            at: cacheURL,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) {
            for url in contents {
                let nameLower = url.lastPathComponent.lowercased()
                if excludedTopLevel.contains(nameLower) || nameLower.contains("docker") {
                    continue
                }
                let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
                if values?.isDirectory == true {
                    if nameLower == "google" {
                        if let googleContents = try? fileManager.contentsOfDirectory(
                            at: url,
                            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
                            options: [.skipsHiddenFiles, .skipsPackageDescendants]
                        ) {
                            for child in googleContents {
                                let childName = child.lastPathComponent.lowercased()
                                if childName.contains("chrome") {
                                    continue
                                }
                                let childValues = try? child.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
                                if childValues?.isDirectory == true {
                                    if let size = sizeCache.size(for: child.path, includeHidden: true) {
                                        paths.append(ItemPath(path: child.path, size: size))
                                    }
                                } else if let fileSize = childValues?.fileSize {
                                    paths.append(ItemPath(path: child.path, size: Int64(fileSize)))
                                }
                            }
                        }
                        continue
                    }

                    if nameLower == "microsoft" {
                        if let microsoftContents = try? fileManager.contentsOfDirectory(
                            at: url,
                            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
                            options: [.skipsHiddenFiles, .skipsPackageDescendants]
                        ) {
                            for child in microsoftContents {
                                let childName = child.lastPathComponent.lowercased()
                                if childName.contains("edge") {
                                    continue
                                }
                                let childValues = try? child.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
                                if childValues?.isDirectory == true {
                                    if let size = sizeCache.size(for: child.path, includeHidden: true) {
                                        paths.append(ItemPath(path: child.path, size: size))
                                    }
                                } else if let fileSize = childValues?.fileSize {
                                    paths.append(ItemPath(path: child.path, size: Int64(fileSize)))
                                }
                            }
                        }
                        continue
                    }

                    if let size = sizeCache.size(for: url.path, includeHidden: true) {
                        paths.append(ItemPath(path: url.path, size: size))
                    }
                } else if let fileSize = values?.fileSize {
                    paths.append(ItemPath(path: url.path, size: Int64(fileSize)))
                }
            }
        }

        return paths
    }

    private func scanLogFiles() async -> [ItemPath] {
        var paths: [ItemPath] = []
        let logPaths = [
            fileManager.homeDirectoryForCurrentUser.path + "/Library/Logs",
            "/Library/Logs",
            "/var/log"
        ]

        for logPath in logPaths {
            if fileManager.fileExists(atPath: logPath) {
                if let size = await getDirectorySize(logPath) {
                    paths.append(ItemPath(path: logPath, size: size))
                }
            }
        }

        return paths
    }

    private func scanTempFiles() async -> [ItemPath] {
        var paths: [ItemPath] = []
        let tempPaths = [
            NSTemporaryDirectory(),
            "/tmp",
            fileManager.homeDirectoryForCurrentUser.path + "/.Trash"
        ]

        for tempPath in tempPaths {
            if fileManager.fileExists(atPath: tempPath) {
                if let size = await getDirectorySize(tempPath) {
                    paths.append(ItemPath(path: tempPath, size: size))
                }
            }
        }

        return paths
    }

    private func scanBrowserCaches() async -> [ItemPath] {
        var paths: [ItemPath] = []
        let home = fileManager.homeDirectoryForCurrentUser.path

        let browserCachePaths = [
            home + "/Library/Caches/com.apple.Safari",
            home + "/Library/Caches/Google/Chrome",
            home + "/Library/Caches/Microsoft/Edge",
            home + "/Library/Caches/Firefox"
        ]

        for cachePath in browserCachePaths {
            if fileManager.fileExists(atPath: cachePath) {
                if let size = await getDirectorySize(cachePath) {
                    paths.append(ItemPath(path: cachePath, size: size))
                }
            }
        }

        return paths
    }

    private func scanOldDownloads() async -> [ItemPath] {
        var paths: [ItemPath] = []
        let downloadsDir = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path ?? ""

        let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        let downloadsURL = URL(fileURLWithPath: downloadsDir)
        if let contents = try? fileManager.contentsOfDirectory(
            at: downloadsURL,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) {
            for url in contents {
                guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]) else {
                    continue
                }
                guard let modDate = values.contentModificationDate, modDate < thirtyDaysAgo else { continue }
                if values.isDirectory == true {
                    if let size = sizeCache.size(for: url.path, includeHidden: true) {
                        paths.append(ItemPath(path: url.path, size: size))
                    }
                } else {
                    let size = Int64(values.fileSize ?? 0)
                    paths.append(ItemPath(path: url.path, size: size))
                }
            }
        }

        return paths
    }

    private func trashRoots() -> [String] {
        var roots: [String] = []

        if let trashURL = fileManager.urls(for: .trashDirectory, in: .userDomainMask).first {
            roots.append(trashURL.path)
        }

        let homeTrash = fileManager.homeDirectoryForCurrentUser.path + "/.Trash"
        if fileManager.fileExists(atPath: homeTrash) {
            roots.append(homeTrash)
        }

        let uid = getuid()
        if let volumeURLs = try? fileManager.contentsOfDirectory(
            at: URL(fileURLWithPath: "/Volumes"),
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            for volume in volumeURLs {
                let values = try? volume.resourceValues(forKeys: [.isDirectoryKey])
                guard values?.isDirectory == true else { continue }
                let trashPath = volume.path + "/.Trashes/\(uid)"
                if fileManager.fileExists(atPath: trashPath) {
                    roots.append(trashPath)
                }
                let altTrash = volume.path + "/.Trash"
                if fileManager.fileExists(atPath: altTrash) {
                    roots.append(altTrash)
                }
            }
        }

        return Array(Set(roots))
    }

    private func trashContents() -> [String] {
        var items: [String] = []

        for root in trashRoots() {
            guard let contents = try? fileManager.contentsOfDirectory(
                at: URL(fileURLWithPath: root),
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
                options: [.skipsPackageDescendants]
            ) else { continue }

            for url in contents {
                items.append(url.path)
            }
        }

        return items
    }

    private func measureTrashSize(_ paths: [String]) -> Int64 {
        var total: Int64 = 0
        for path in paths {
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: path, isDirectory: &isDirectory) {
                if isDirectory.boolValue {
                    total += sizeCache.size(for: path, includeHidden: true) ?? 0
                } else if let values = try? URL(fileURLWithPath: path).resourceValues(forKeys: [.fileSizeKey]) {
                    total += Int64(values.fileSize ?? 0)
                }
            }
        }
        return total
    }

    private func scanDevelopmentArtifacts() async -> [ItemPath] {
        var paths: [ItemPath] = []
        let home = fileManager.homeDirectoryForCurrentUser.path

        let devPaths = [
            home + "/.npm",
            home + "/.yarn/cache",
            home + "/.cargo/registry",
            home + "/.gradle/caches",
            home + "/.m2/repository",
            home + "/.ivy2/cache",
            home + "/.sbt",
            home + "/.cabal"
        ]

        for devPath in devPaths {
            if fileManager.fileExists(atPath: devPath) {
                if let size = await getDirectorySize(devPath) {
                    paths.append(ItemPath(path: devPath, size: size))
                }
            }
        }

        return paths
    }

    private func scanDockerArtifacts() async -> [ItemPath] {
        var paths: [ItemPath] = []
        let home = fileManager.homeDirectoryForCurrentUser.path

        let dockerPaths = [
            home + "/Library/Containers/com.docker.docker",
            home + "/.docker"
        ]

        for dockerPath in dockerPaths {
            if fileManager.fileExists(atPath: dockerPath) {
                if let size = await getDirectorySize(dockerPath) {
                    paths.append(ItemPath(path: dockerPath, size: size))
                }
            }
        }

        return paths
    }

    private func scanXcodeArtifacts() async -> [ItemPath] {
        var paths: [ItemPath] = []
        let home = fileManager.homeDirectoryForCurrentUser.path

        let xcodePaths = [
            home + "/Library/Developer/Xcode/DerivedData",
            home + "/Library/Developer/Xcode/Archives",
            home + "/Library/Developer/Xcode/iOS DeviceSupport"
        ]

        for xcodePath in xcodePaths {
            if fileManager.fileExists(atPath: xcodePath) {
                if let size = await getDirectorySize(xcodePath) {
                    paths.append(ItemPath(path: xcodePath, size: size))
                }
            }
        }

        return paths
    }

    // MARK: - Helper Methods

    private func getDirectorySize(_ path: String) async -> Int64? {
        sizeCache.size(for: path, includeHidden: true)
    }

    private func getFileSize(_ path: String) async -> Int64? {
        guard fileManager.fileExists(atPath: path) else { return nil }
        let url = URL(fileURLWithPath: path)
        if let values = try? url.resourceValues(forKeys: [.fileSizeKey]) {
            return Int64(values.fileSize ?? 0)
        }
        return nil
    }
}
