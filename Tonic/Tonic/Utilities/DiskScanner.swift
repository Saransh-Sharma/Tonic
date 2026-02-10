//
//  DiskScanner.swift
//  Tonic
//
//  Concurrent directory scanner for disk analysis
//

import Foundation

// MARK: - Scan Error

enum DiskScanError: Error, LocalizedError {
    case accessDenied(String)
    case notFound(String)
    case timeout(String)
    case cancelled
    case permissionRequired(String)

    var errorDescription: String? {
        switch self {
        case .accessDenied(let path):
            return "Access denied: \(path)"
        case .notFound(let path):
            return "Not found: \(path)"
        case .timeout(let path):
            return "Scan timeout: \(path)"
        case .cancelled:
            return "Scan cancelled"
        case .permissionRequired(let path):
            return "Full Disk Access required to scan \(path)"
        }
    }
}

// MARK: - Disk Scanner

/// Concurrent disk scanner using Swift Concurrency
@Observable
final class DiskScanner: @unchecked Sendable {

    // MARK: - Properties

    private let fileManager = FileManager.default
    private let lock = NSLock()
    private let skipDirectoryNames: Set<String> = [".git", ".hg", ".svn", "node_modules", ".npm", ".venv", "venv", "build", "dist", ".build", "target"]
    private var _isScanning = false
    private var _currentProgress: DiskScanProgress?
    private var scanTask: Task<DiskScanResult, Error>?

    var isScanning: Bool {
        get { lock.locked { _isScanning } }
        set { lock.locked { _isScanning = newValue } }
    }

    var currentProgress: DiskScanProgress? {
        get { lock.locked { _currentProgress } }
        set { lock.locked { _currentProgress = newValue } }
    }

    /// Cancel the current scan
    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
    }

    // MARK: - Public Scan Methods

    /// Scan a directory path concurrently with timeout
    func scanPath(
        _ path: String,
        mode: StorageScanMode = .quick,
        policy: ScanPerformancePolicy = .adaptiveDefault,
        progress: @escaping (DiskScanProgress) -> Void
    ) async throws -> DiskScanResult {
        guard !isScanning else {
            throw DiskScanError.cancelled
        }

        // Cancel any existing scan
        scanTask?.cancel()
        let task = Task<DiskScanResult, Error> {
            try await withTimeout(seconds: 60) { [self] in // 60 second timeout
                try await performScan(path: path, mode: mode, policy: policy, progress: progress)
            }
        }
        scanTask = task

        defer { scanTask = nil }

        // Create new scan task
        return try await withTaskCancellationHandler(
            operation: {
                try await task.value
            },
            onCancel: {
                task.cancel()
                isScanning = false
            }
        )
    }

    /// Perform the actual scan operation
    private func performScan(
        path: String,
        mode: StorageScanMode,
        policy: ScanPerformancePolicy,
        progress: @escaping (DiskScanProgress) -> Void
    ) async throws -> DiskScanResult {
        isScanning = true
        defer { isScanning = false }

        // Check if path exists and is accessible
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else {
            throw DiskScanError.notFound(path)
        }

        guard isDirectory.boolValue else {
            throw DiskScanError.accessDenied(path)
        }

        let startTime = Date()

        // Use TaskGroup for concurrent scanning, then aggregate deterministically in the parent task.
        let (entries, largeFiles, metrics) = try await withThrowingTaskGroup(of: ChunkResult.self) { group in
            // Get directory contents with error handling
            let children: [URL]
            do {
                children = try fileManager.contentsOfDirectory(at: URL(fileURLWithPath: path), includingPropertiesForKeys: nil)
            } catch {
                // If we can't access the directory, check if it's a permission issue
                if (error as NSError).code == NSFileReadNoPermissionError {
                    throw DiskScanError.permissionRequired(path)
                }
                throw DiskScanError.accessDenied(path)
            }

            // Worker pool tuned for sustained scan throughput with lower energy impact.
            let numWorkers = effectiveWorkerCount(policy: policy)
            let semaphore = AsyncSemaphore(value: numWorkers)

            for child in children {
                group.addTask {
                    await semaphore.acquire()
                    defer {
                        Task { await semaphore.release() }
                    }

                    return await self.scanChild(child: child, mode: mode)
                }
            }

            // Collect full coverage (no truncation), then sort once at the end.
            var entriesBuffer: [DirEntry] = []
            var largeFilesBuffer: [LargeFile] = []
            var aggregate = ChunkMetrics()
            var processedItems: Int64 = 0
            var lastEmittedItems: Int64 = 0
            var lastEmittedAt = Date.distantPast

            for try await result in group {
                entriesBuffer.append(contentsOf: result.entries)
                largeFilesBuffer.append(contentsOf: result.largeFiles)
                aggregate.files += result.metrics.files
                aggregate.directories += result.metrics.directories
                aggregate.bytes += result.metrics.bytes
                processedItems += result.metrics.files + result.metrics.directories

                // Emit progress by item and time cadence to avoid "stuck at zero" UX.
                let itemDelta = processedItems - lastEmittedItems
                let shouldEmit = itemDelta >= Int64(max(20, policy.eventBatchSize / 8))
                    || Date().timeIntervalSince(lastEmittedAt) >= policy.progressEmitInterval
                if processedItems > 0 && shouldEmit {
                    let snapshot = DiskScanProgress(
                        filesScanned: aggregate.files,
                        dirsScanned: aggregate.directories,
                        bytesScanned: aggregate.bytes,
                        currentPath: result.currentPath
                    )
                    progress(snapshot)
                    currentProgress = snapshot
                    lastEmittedItems = processedItems
                    lastEmittedAt = Date()
                }
            }

            // Always publish a final aggregate progress snapshot, even for tiny scans.
            let finalSnapshot = DiskScanProgress(
                filesScanned: aggregate.files,
                dirsScanned: aggregate.directories,
                bytesScanned: aggregate.bytes,
                currentPath: path
            )
            progress(finalSnapshot)
            currentProgress = finalSnapshot

            // Deduplicate by path while preserving largest encountered size for stable results.
            var entryByPath: [String: DirEntry] = [:]
            for entry in entriesBuffer {
                if let existing = entryByPath[entry.path], existing.size > entry.size {
                    continue
                }
                entryByPath[entry.path] = entry
            }

            var largeByPath: [String: LargeFile] = [:]
            for file in largeFilesBuffer {
                if let existing = largeByPath[file.path], existing.size > file.size {
                    continue
                }
                largeByPath[file.path] = file
            }

            let sortedEntries = Array(entryByPath.values).sorted { $0.size > $1.size }
            let sortedLarge = Array(largeByPath.values).sorted { $0.size > $1.size }
            return (sortedEntries, sortedLarge, aggregate)
        }

        // Try Spotlight for large files as fallback
        let finalLargeFiles = await findLargeFilesWithSpotlight(in: path, existing: largeFiles)

        // Calculate total size
        let totalSize = entries.reduce(0) { $0 + $1.size }

        let duration = Date().timeIntervalSince(startTime)

        return DiskScanResult(
            entries: entries,
            largeFiles: finalLargeFiles,
            totalSize: totalSize,
            totalFiles: metrics.files,
            scanDuration: duration
        )
    }

    /// Get overview sizes for system directories
    func getOverviewSizes(for paths: [String], progress: @escaping (String, Int64) -> Void) async throws -> [DirectoryOverviewEntry] {
        var entries: [DirectoryOverviewEntry] = []

        for path in paths {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                continue
            }

            let entry = DirectoryOverviewEntry(
                name: displayName(for: path),
                path: path,
                size: nil,  // Pending scan
                isDir: true
            )
            entries.append(entry)
        }

        // Scan all paths with bounded concurrency.
        try await withThrowingTaskGroup(of: (path: String, size: Int64).self) { group in
            let maxConcurrent = max(1, min(4, entries.count))
            let semaphore = AsyncSemaphore(value: maxConcurrent)

            for entry in entries {
                group.addTask {
                    await semaphore.acquire()
                    defer {
                        Task { await semaphore.release() }
                    }

                    let size = await self.calculateDirectorySize(entry.path)
                    progress(entry.path, size)
                    return (entry.path, size)
                }
            }

            for try await (path, size) in group {
                if let index = entries.firstIndex(where: { $0.path == path }) {
                    entries[index].size = size
                }
            }
        }

        return entries
    }

    // MARK: - Private Scan Methods

    private struct ChunkResult {
        let entries: [DirEntry]
        let largeFiles: [LargeFile]
        let metrics: ChunkMetrics
        let currentPath: String
    }

    private struct ChunkMetrics: Sendable {
        var files: Int64 = 0
        var directories: Int64 = 0
        var bytes: Int64 = 0
    }

    private func scanChild(
        child: URL,
        mode: StorageScanMode
    ) async -> ChunkResult {
        let path = child.path
        let name = (path as NSString).lastPathComponent

        // Skip symlinks
        if isSymlink(at: path) {
            return ChunkResult(entries: [], largeFiles: [], metrics: ChunkMetrics(), currentPath: path)
        }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else {
            return ChunkResult(entries: [], largeFiles: [], metrics: ChunkMetrics(), currentPath: path)
        }

        if isDirectory.boolValue {
            return await scanDirectory(
                path: path,
                name: name,
                mode: mode
            )
        } else {
            return scanFile(
                path: path,
                name: name
            )
        }
    }

    private func scanFile(
        path: String,
        name: String
    ) -> ChunkResult {
        guard let attributes = try? fileManager.attributesOfItem(atPath: path),
              (attributes[.size] as? Int64) != nil else {
            return ChunkResult(entries: [], largeFiles: [], metrics: ChunkMetrics(), currentPath: path)
        }

        let actualSize = getActualFileSize(from: attributes)

        let entry = DirEntry(
            name: name,
            path: path,
            size: actualSize,
            isDir: false,
            lastAccess: (attributes[.modificationDate] as? Date) ?? Date(),
            isEstimated: false
        )

        var largeFiles: [LargeFile] = []
        let minLargeFileSize: Int64 = 100 * 1024 * 1024  // 100 MB
        if actualSize >= minLargeFileSize,
           !shouldSkipFileForLargeTracking(path) {
            largeFiles.append(LargeFile(name: name, path: path, size: actualSize))
        }

        return ChunkResult(
            entries: [entry],
            largeFiles: largeFiles,
            metrics: ChunkMetrics(files: 1, directories: 0, bytes: actualSize),
            currentPath: path
        )
    }

    private func scanDirectory(
        path: String,
        name: String,
        mode: StorageScanMode
    ) async -> ChunkResult {
        // Skip certain directories
        if skipDirectoryNames.contains(name) {
            return ChunkResult(entries: [], largeFiles: [], metrics: ChunkMetrics(), currentPath: path)
        }

        // In quick mode we use recursive `du` for an immediate accurate top-level summary.
        // In full/targeted mode we avoid subtree recursion here to prevent double traversal.
        let size: Int64
        let isEstimated: Bool
        if mode == .quick {
            if let duSize = await getDirectorySizeFromDu(path) {
                size = duSize
            } else {
                size = await fastRecursiveScan(path: path)
            }
            isEstimated = false
        } else {
            size = 0
            isEstimated = true
        }

        let entry = DirEntry(
            name: name,
            path: path,
            size: size,
            isDir: true,
            lastAccess: getLastAccessTime(for: path) ?? Date(),
            isEstimated: isEstimated
        )

        return ChunkResult(
            entries: [entry],
            largeFiles: [],
            metrics: ChunkMetrics(files: 0, directories: 1, bytes: size),
            currentPath: path
        )
    }

    private func calculateDirectorySize(_ path: String) async -> Int64 {
        // Use du command for all directories (fast and reliable with Full Disk Access)
        return await getDirectorySizeFromDu(path) ?? 0
    }

    /// Lightweight child listing used by recursive indexing to avoid repeated deep subtree sizing.
    func listImmediateChildrenLightweight(at path: String) async -> [DirEntry] {
        let keys: [URLResourceKey] = [
            .isDirectoryKey,
            .isSymbolicLinkKey,
            .fileSizeKey,
            .contentAccessDateKey,
            .contentModificationDateKey,
            .volumeIdentifierKey,
            .volumeNameKey,
            .fileResourceIdentifierKey
        ]
        guard let urls = try? fileManager.contentsOfDirectory(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: keys,
            options: []
        ) else {
            return []
        }

        var entries: [DirEntry] = []
        entries.reserveCapacity(urls.count)

        for url in urls {
            let childPath = url.path
            let name = url.lastPathComponent
            if skipDirectoryNames.contains(name) {
                continue
            }

            guard let values = try? url.resourceValues(forKeys: Set(keys)) else {
                continue
            }

            let isSymbolicLink = values.isSymbolicLink ?? false
            if isSymbolicLink {
                continue
            }

            let isDirectory = values.isDirectory ?? false
            let fileSize = Int64(values.fileSize ?? 0)
            let lastOpened = values.contentAccessDate
            let lastAccess = lastOpened ?? values.contentModificationDate ?? Date()
            let volumeID = values.volumeIdentifier.map { String(describing: $0) }
            let volumeName = values.volumeName
            let fsID = values.fileResourceIdentifier.map { String(describing: $0) }

            entries.append(
                DirEntry(
                    name: name,
                    path: childPath,
                    size: isDirectory ? 0 : fileSize,
                    isDir: isDirectory,
                    lastAccess: lastAccess,
                    isEstimated: isDirectory,
                    volumeIDHint: volumeID,
                    volumeNameHint: volumeName,
                    filesystemIDHint: fsID,
                    lastOpenedHint: lastOpened,
                    lastOpenedEstimated: lastOpened == nil
                )
            )
        }

        return entries
    }

    private func fastRecursiveScan(path: String) async -> Int64 {
        // Fallback to recursive scan only if du fails
        guard let contents = try? fileManager.contentsOfDirectory(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        let skipDirs: Set<String> = [".git", ".hg", ".svn", "node_modules", ".npm", ".venv", "venv", "build", "dist"]

        return await withTaskGroup(of: Int64.self) { group in
            for item in contents {
                let itemPath = item.path
                let name = (itemPath as NSString).lastPathComponent

                if skipDirs.contains(name) {
                    continue
                }

                guard let resourceValues = try? item.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]),
                      let isDirectory = resourceValues.isDirectory else {
                    continue
                }

                if isDirectory {
                    // Limit recursion depth for performance
                    let depth = (itemPath as NSString).pathComponents.count
                    if depth < 5 {  // Only scan 5 levels deep
                        group.addTask {
                            return await self.fastRecursiveScan(path: itemPath)
                        }
                    }
                } else {
                    let size = Int64(resourceValues.fileSize ?? 0)
                    group.addTask { return size }
                }
            }

            var total: Int64 = 0
            for await size in group {
                total += size
            }
            return total
        }
    }

    // MARK: - Spotlight Integration

    private func findLargeFilesWithSpotlight(in path: String, existing: [LargeFile]) async -> [LargeFile] {
        if !existing.isEmpty {
            return existing
        }

        let minLargeFileSize: Int64 = 100 * 1024 * 1024  // 100 MB
        let query = "kMDItemFSSize >= \(minLargeFileSize)"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        process.arguments = ["-onlyin", path, query]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()

            let timeoutTask = Task {
                try? await Task.sleep(nanoseconds: 30_000_000_000)  // 30 seconds
                process.terminate()
            }

            let data = try? pipe.fileHandleForReading.readToEnd()
            timeoutTask.cancel()

            guard let output = String(data: data ?? Data(), encoding: .utf8) else {
                return existing
            }

            var files: [LargeFile] = []
            for line in output.components(separatedBy: .newlines) {
                let filePath = line.trimmingCharacters(in: .whitespaces)
                guard !filePath.isEmpty,
                      !shouldSkipFileForLargeTracking(filePath),
                      let attributes = try? fileManager.attributesOfItem(atPath: filePath),
                      let fileSize = attributes[.size] as? Int64 else {
                    continue
                }

                if fileSize >= minLargeFileSize {
                    let name = (filePath as NSString).lastPathComponent
                    files.append(LargeFile(name: name, path: filePath, size: fileSize))
                }
            }

            files.sort { $0.size > $1.size }
            return files

        } catch {
            return existing
        }
    }

    // MARK: - Helper Methods

    private func getDirectorySizeFromDu(_ path: String) async -> Int64? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/du")
        process.arguments = ["-sk", path]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()

            let timeoutTask = Task {
                try? await Task.sleep(nanoseconds: 60_000_000_000)  // 60 seconds
                process.terminate()
            }

            guard let data = try? pipe.fileHandleForReading.readToEnd(),
                  let output = String(data: data, encoding: .utf8) else {
                timeoutTask.cancel()
                return nil
            }

            timeoutTask.cancel()

            let fields = output.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard let kbString = fields.first,
                  let kb = Int64(kbString) else {
                return nil
            }

            return kb * 1024
        } catch {
            return nil
        }
    }

    private func getActualFileSize(from attributes: [FileAttributeKey: Any]) -> Int64 {
        guard let fileSize = attributes[.size] as? Int64 else {
            return 0
        }

        // Use file size directly for simplicity
        return fileSize
    }

    private func getLastAccessTime(for path: String) -> Date? {
        let url = URL(fileURLWithPath: path)
        if let values = try? url.resourceValues(forKeys: [.contentAccessDateKey, .contentModificationDateKey]) {
            if let access = values.contentAccessDate {
                return access
            }
            if let modification = values.contentModificationDate {
                return modification
            }
        }
        return try? fileManager.attributesOfItem(atPath: path)[.modificationDate] as? Date
    }

    private func isSymlink(at path: String) -> Bool {
        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: path)
            return attrs[.type] as? FileAttributeType == .typeSymbolicLink
        } catch {
            return false
        }
    }

    private func shouldSkipFileForLargeTracking(_ path: String) -> Bool {
        let skipExtensions: Set<String> = [
            ".swift", ".m", ".h", ".mm", ".cpp", ".c", ".cc", ".hpp", ".hxx",
            ".js", ".jsx", ".ts", ".tsx", ".py", ".go", ".rs", ".java", ".kt",
            ".json", ".xml", ".yaml", ".yml", ".txt", ".md", ".lock"
        ]

        let ext = ((path as NSString).pathExtension as String).lowercased()
        return skipExtensions.contains(".\(ext)")
    }

    private func displayName(for path: String) -> String {
        switch path {
        case FileManager.default.homeDirectoryForCurrentUser.path:
            return "Home"
        case "/Applications":
            return "Applications"
        case "/Library":
            return "System Library"
        case "/Volumes":
            return "Volumes"
        default:
            return (path as NSString).lastPathComponent
        }
    }

    private func effectiveWorkerCount(policy: ScanPerformancePolicy) -> Int {
        let thermal = ProcessInfo.processInfo.thermalState
        let upper = max(policy.minWorkers, policy.maxWorkers)
        switch thermal {
        case .nominal:
            return upper
        case .fair:
            return max(policy.minWorkers, upper - 2)
        case .serious:
            return max(policy.minWorkers, upper / 2)
        case .critical:
            return policy.minWorkers
        @unknown default:
            return max(policy.minWorkers, upper / 2)
        }
    }

    // MARK: - Timeout Helper

    /// Execute an async operation with a timeout
    private func withTimeout<T>(
        seconds: TimeInterval,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw DiskScanError.timeout("Operation exceeded \(seconds) seconds")
            }

            guard let result = try await group.next() else {
                throw DiskScanError.timeout("Operation timed out")
            }

            group.cancelAll()
            return result
        }
    }
}

// MARK: - Async Semaphore

/// Async semaphore for concurrent task limiting
actor AsyncSemaphore {
    private var value: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(value: Int) {
        self.value = value
    }

    func acquire() async {
        if value > 0 {
            value -= 1
            return
        }

        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func release() {
        if let waiter = waiters.first {
            waiters.removeFirst()
            waiter.resume()
        } else {
            value += 1
        }
    }
}

private actor ScanWorkerActor {
    private let scanner: DiskScanner

    init(scanner: DiskScanner) {
        self.scanner = scanner
    }

    func listImmediateChildren(at path: String) async -> [DirEntry] {
        await scanner.listImmediateChildrenLightweight(at: path)
    }
}

private actor ScanIndexCoordinatorActor {
    private let scanWorker: ScanWorkerActor
    private var queue: [StorageNode]
    private var cursor = 0
    private var visited: Set<String> = []

    init(initialDirectories: [StorageNode], scanWorker: ScanWorkerActor) {
        self.scanWorker = scanWorker
        queue = initialDirectories
            .filter(\.isDirectory)
            .sorted { $0.logicalBytes > $1.logicalBytes }
    }

    func hasRemaining() -> Bool {
        cursor < queue.count
    }

    func enqueue(_ directories: [StorageNode]) {
        queue.append(contentsOf: directories.filter(\.isDirectory))
    }

    func nextBatch(workerCount: Int) async -> [(StorageNode, [DirEntry])] {
        var batch: [StorageNode] = []
        while cursor < queue.count, batch.count < workerCount {
            let directory = queue[cursor]
            cursor += 1
            guard directory.isDirectory else { continue }
            if visited.insert(directory.path).inserted {
                batch.append(directory)
            }
        }

        guard !batch.isEmpty else {
            return []
        }

        let worker = scanWorker
        return await withTaskGroup(of: (StorageNode, [DirEntry]).self, returning: [(StorageNode, [DirEntry])].self) { group in
            for directory in batch {
                group.addTask {
                    if Task.isCancelled {
                        return (directory, [])
                    }
                    let entries = await worker.listImmediateChildren(at: directory.path)
                    return (directory, entries)
                }
            }

            var results: [(StorageNode, [DirEntry])] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
    }
}

// MARK: - NSLock Extension

extension NSLock {
    func locked<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}

// MARK: - Data Types

/// Represents a single entry in a directory scan
struct DirEntry: Identifiable, Codable, Hashable, Sendable {
    let id = UUID()
    let name: String
    let path: String
    var size: Int64
    let isDir: Bool
    let lastAccess: Date
    let isEstimated: Bool
    let volumeIDHint: String?
    let volumeNameHint: String?
    let filesystemIDHint: String?
    let lastOpenedHint: Date?
    let lastOpenedEstimated: Bool

    enum CodingKeys: String, CodingKey {
        case name, path, size, isDir, lastAccess, isEstimated
        case volumeIDHint, volumeNameHint, filesystemIDHint, lastOpenedHint, lastOpenedEstimated
    }

    init(
        name: String,
        path: String,
        size: Int64,
        isDir: Bool,
        lastAccess: Date,
        isEstimated: Bool = false,
        volumeIDHint: String? = nil,
        volumeNameHint: String? = nil,
        filesystemIDHint: String? = nil,
        lastOpenedHint: Date? = nil,
        lastOpenedEstimated: Bool = true
    ) {
        self.name = name
        self.path = path
        self.size = size
        self.isDir = isDir
        self.lastAccess = lastAccess
        self.isEstimated = isEstimated
        self.volumeIDHint = volumeIDHint
        self.volumeNameHint = volumeNameHint
        self.filesystemIDHint = filesystemIDHint
        self.lastOpenedHint = lastOpenedHint
        self.lastOpenedEstimated = lastOpenedEstimated
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        path = try container.decode(String.self, forKey: .path)
        size = try container.decode(Int64.self, forKey: .size)
        isDir = try container.decode(Bool.self, forKey: .isDir)
        lastAccess = try container.decode(Date.self, forKey: .lastAccess)
        isEstimated = try container.decodeIfPresent(Bool.self, forKey: .isEstimated) ?? false
        volumeIDHint = try container.decodeIfPresent(String.self, forKey: .volumeIDHint)
        volumeNameHint = try container.decodeIfPresent(String.self, forKey: .volumeNameHint)
        filesystemIDHint = try container.decodeIfPresent(String.self, forKey: .filesystemIDHint)
        lastOpenedHint = try container.decodeIfPresent(Date.self, forKey: .lastOpenedHint)
        lastOpenedEstimated = try container.decodeIfPresent(Bool.self, forKey: .lastOpenedEstimated) ?? true
    }
}

/// Represents a large file entry
struct LargeFile: Identifiable, Codable, Hashable, Sendable {
    let id = UUID()
    let name: String
    let path: String
    let size: Int64

    enum CodingKeys: String, CodingKey {
        case name, path, size
    }
}

/// Result of a directory scan operation
struct DiskScanResult: Codable, Sendable {
    let entries: [DirEntry]
    let largeFiles: [LargeFile]
    let totalSize: Int64
    let totalFiles: Int64
    let scanDuration: TimeInterval

    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }

    var formattedFileCount: String {
        NumberFormatter.localizedString(from: NSNumber(value: totalFiles), number: .decimal)
    }
}

/// Progress updates during scanning
struct DiskScanProgress: Sendable {
    let filesScanned: Int64
    let dirsScanned: Int64
    let bytesScanned: Int64
    let currentPath: String

    var formattedFilesScanned: String {
        NumberFormatter.localizedString(from: NSNumber(value: filesScanned), number: .decimal)
    }

    var formattedBytesScanned: String {
        ByteCountFormatter.string(fromByteCount: bytesScanned, countStyle: .file)
    }
}

/// Entry for system overview (top-level directories)
struct DirectoryOverviewEntry: Identifiable, Hashable, Sendable {
    let id = UUID()
    let name: String
    let path: String
    var size: Int64?
    let isDir: Bool

    /// Returns display size, or "Scanning..." for pending entries
    var displaySize: String {
        guard let size = size else {
            return "Scanning..."
        }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    /// Whether this entry has a valid size
    var isScanned: Bool {
        return size != nil
    }
}

// MARK: - Storage Intelligence Hub Engine

@MainActor
@Observable
final class StorageIntelligenceEngine {
    private let fileManager = FileManager.default
    private let scanner = DiskScanner()
    private let categoryScanner = ScanCategoryScanner()
    private let fileOperations = FileOperations.shared

    private let historyDefaultsKey = "storageHub.scanHistory.v1"
    private let excludedDefaultsKey = "storageHub.excludedPaths.v1"

    private(set) var session: StorageScanSession?
    private(set) var currentPath: String = FileManager.default.homeDirectoryForCurrentUser.path
    private(set) var nodesByPath: [String: [StorageNode]] = [:]
    private(set) var insights: [StorageInsight] = []
    private(set) var reclaimPacks: [StorageReclaimPack] = []
    private(set) var history: [StorageScanHistoryEntry] = []
    private(set) var filters: StorageFilterState = StorageFilterState()
    private(set) var cartNodeIDs: Set<String> = []
    private(set) var selectedNodeID: String?
    private(set) var excludedPaths: Set<String> = []
    private(set) var lastWarning: String?
    private(set) var activeGuidedStep: Int = 0
    private(set) var timeShiftSummary: StorageTimeShiftSummary?
    private(set) var forecast: StorageForecast?
    private(set) var anomalies: [StorageAnomaly] = []
    private(set) var personaBundles: [StoragePersonaBundle] = []
    private(set) var hygieneRoutines: [StorageHygieneRoutine] = []
    private(set) var liveHotspots: [StorageLiveHotspot] = []
    private(set) var ioVolumeHistory: [StorageVolumeIOHistoryPoint] = []
    private(set) var processDeltas: [StorageProcessDelta] = []
    private(set) var liveMonitoringEnabled: Bool = false
    private(set) var lastCleanupPlan: CleanupPlan?

    private var scanTask: Task<Void, Never>?
    private var liveMonitorTask: Task<Void, Never>?
    private var streamContinuation: AsyncStream<ScanEvent>.Continuation?
    private var lastPathSample: [String: (bytes: Int64, date: Date)] = [:]
    private var appOwnershipIndex: [String: String] = [:]
    private var appOwnershipBundleIndex: [String: String] = [:]
    private var parentGroupIndex: [String: String] = [:]
    private var measuredProcessProvider = MeasuredProcessIOMonitorProvider()
    private var fallbackProcessProvider = PathDeltaFallbackProvider()
    private var scanPolicy: ScanPerformancePolicy = .adaptiveDefault
    @ObservationIgnored
    private let scanWorker: ScanWorkerActor

    init() {
        scanWorker = ScanWorkerActor(scanner: scanner)
        history = loadHistory()
        excludedPaths = loadExcludedPaths()
        hygieneRoutines = defaultHygieneRoutines()
    }

    var visibleNodes: [StorageNode] {
        let nodes = nodesByPath[currentPath] ?? []
        return applyFilters(to: nodes).sorted { $0.logicalBytes > $1.logicalBytes }
    }

    var selectedNode: StorageNode? {
        guard let selectedNodeID else { return nil }
        return findNode(by: selectedNodeID)
    }

    var cartCandidates: [CleanupCandidate] {
        var seenIdentityKeys: Set<String> = []
        return cartNodeIDs.compactMap { nodeID in
            guard let node = findNode(by: nodeID) else { return nil }
            let identity = node.filesystemID ?? canonicalIdentityPath(node.path)
            let isDuplicate = seenIdentityKeys.contains(identity)
            seenIdentityKeys.insert(identity)
            return cleanupCandidate(for: node, duplicateConflict: isDuplicate)
        }
    }

    var groupedCartCandidates: [CleanupCandidateGroup] {
        struct CartGroupKey: Hashable {
            let domain: StorageDomain
            let actionType: CleanupActionType
        }

        let grouped = Dictionary(grouping: cartCandidates) { candidate in
            let node = findNode(by: candidate.nodeId)
            return CartGroupKey(domain: node?.domain ?? .other, actionType: candidate.actionType)
        }

        return grouped
            .map { key, value in
                let sortedItems = value.sorted { $0.estimatedReclaimBytes > $1.estimatedReclaimBytes }
                return CleanupCandidateGroup(
                    id: "\(key.domain.rawValue)-\(key.actionType.rawValue)",
                    domain: key.domain,
                    actionType: key.actionType,
                    items: sortedItems,
                    reclaimableBytes: sortedItems.reduce(0) { $0 + $1.estimatedReclaimBytes }
                )
            }
            .sorted { $0.reclaimableBytes > $1.reclaimableBytes }
    }

    var guidedSteps: [GuidedCleanupStep] {
        let sorted = reclaimPacks.sorted { $0.reclaimableBytes > $1.reclaimableBytes }
        var assigned = Set<UUID>()

        let biggestWins = sorted.filter {
            guard !assigned.contains($0.id) else { return false }
            let match = $0.reclaimableBytes >= 300 * 1024 * 1024 && $0.riskLevel != .high && $0.riskLevel != .protected
            if match { assigned.insert($0.id) }
            return match
        }
        let lowRisk = sorted.filter {
            guard !assigned.contains($0.id) else { return false }
            let match = $0.riskLevel == .low
            if match { assigned.insert($0.id) }
            return match
        }
        let advanced = sorted.filter {
            guard !assigned.contains($0.id) else { return false }
            let match = $0.riskLevel == .medium || $0.riskLevel == .high
            if match { assigned.insert($0.id) }
            return match
        }
        let finalReviewBytes = cartCandidates.reduce(0) { $0 + $1.estimatedReclaimBytes }

        return [
            GuidedCleanupStep(
                id: UUID(),
                title: "Biggest Wins First",
                subtitle: "Largest safe opportunities with fast impact.",
                packs: Array(biggestWins.prefix(4)),
                totalBytes: biggestWins.reduce(0) { $0 + $1.reclaimableBytes }
            ),
            GuidedCleanupStep(
                id: UUID(),
                title: "Low-Risk Hygiene",
                subtitle: "Routine cleanup with minimal side effects.",
                packs: Array(lowRisk.prefix(4)),
                totalBytes: lowRisk.reduce(0) { $0 + $1.reclaimableBytes }
            ),
            GuidedCleanupStep(
                id: UUID(),
                title: "Advanced Cleanup",
                subtitle: "Higher-impact actions that deserve review.",
                packs: Array(advanced.prefix(4)),
                totalBytes: advanced.reduce(0) { $0 + $1.reclaimableBytes }
            ),
            GuidedCleanupStep(
                id: UUID(),
                title: "Final Review",
                subtitle: "Dry-run summary, safety checks, and undo expectations before execution.",
                packs: [],
                totalBytes: finalReviewBytes
            )
        ]
    }

    var totalReclaimableBytes: Int64 {
        reclaimPacks.reduce(0) { $0 + $1.reclaimableBytes }
    }

    var storyboardHeadline: String {
        guard totalReclaimableBytes > 0 else {
            return "Run a scan to reveal reclaimable storage opportunities."
        }
        let bytes = ByteCountFormatter.string(fromByteCount: totalReclaimableBytes, countStyle: .file)
        let steps = max(guidedSteps.count, 1)
        return "You can safely reclaim \(bytes) in \(steps) steps."
    }

    var rootDomainBreakdown: [StorageDomain: Int64] {
        let rootNodes = nodesByPath[session?.scope.rootPath ?? currentPath] ?? []
        return domainBreakdown(for: rootNodes)
    }

    var trendHistory: [StorageScanHistoryEntry] {
        guard let root = session?.scope.rootPath else {
            return history
        }
        return history.filter { $0.rootPath == root }.sorted { $0.finishedAt < $1.finishedAt }
    }

    var ownerApps: [String] {
        let apps = nodesByPath.values
            .flatMap { $0 }
            .compactMap(\.ownerApp)
        return Array(Set(apps)).sorted()
    }

    private var shouldResolveStrictMetadata: Bool {
        filters.lastOpenedIsStrict || !filters.volumes.isEmpty
    }

    var availableVolumes: [String] {
        let names = nodesByPath.values
            .flatMap { $0 }
            .compactMap(\.volumeName)
            .filter { !$0.isEmpty }
        return Array(Set(names)).sorted()
    }

    func startScan(
        mode: StorageScanMode = .quick,
        rootPath: String = FileManager.default.homeDirectoryForCurrentUser.path,
        targetedPaths: [String] = []
    ) -> AsyncStream<ScanEvent> {
        cancelActiveScan()

        let resolvedTargets: [String]
        if mode == .targeted {
            let filtered = targetedPaths.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            resolvedTargets = filtered.isEmpty ? [rootPath] : filtered
        } else {
            resolvedTargets = targetedPaths
        }

        let scope = StorageScanScope(rootPath: rootPath, targetedPaths: resolvedTargets)
        let session = StorageScanSession(
            id: UUID(),
            mode: mode,
            scope: scope,
            startAt: Date(),
            endAt: nil,
            status: .preparing,
            confidence: 0,
            scannedBytes: 0,
            scannedItems: 0,
            indexedDirectories: 0,
            indexedNodes: 0,
            stageDurations: [:],
            filesPerSecond: 0,
            directoriesPerSecond: 0,
            eventBatchesPerSecond: 0,
            avgBatchLatency: 0,
            energyMode: scanPolicy.energyMode,
            warnings: []
        )

        self.session = session
        currentPath = rootPath
        cartNodeIDs.removeAll()
        selectedNodeID = nil
        insights = []
        reclaimPacks = []
        nodesByPath = [:]
        parentGroupIndex = [:]
        activeGuidedStep = 0
        lastWarning = nil
        timeShiftSummary = nil
        forecast = nil
        anomalies = []
        personaBundles = []
        liveHotspots = []
        ioVolumeHistory = []
        processDeltas = []
        lastPathSample = [:]
        lastCleanupPlan = nil

        return AsyncStream { continuation in
            streamContinuation = continuation
            scanTask = Task { [weak self] in
                guard let self else { return }
                await self.refreshAppOwnershipIndex()
                await self.runScan(mode: mode, scope: scope, continuation: continuation)
            }
        }
    }

    func cancelActiveScan() {
        scanTask?.cancel()
        scanTask = nil
        scanner.cancelScan()

        guard var session else { return }
        session.status = .cancelled
        session.endAt = Date()
        self.session = session
        streamContinuation?.yield(.cancelled)
        streamContinuation?.finish()
        streamContinuation = nil
    }

    func setLiveMonitoring(enabled: Bool) {
        liveMonitoringEnabled = enabled
        if enabled {
            startLiveMonitoring()
        } else {
            stopLiveMonitoring()
        }
    }

    func toggleHygieneRoutine(_ routineID: UUID) {
        guard let index = hygieneRoutines.firstIndex(where: { $0.id == routineID }) else { return }
        hygieneRoutines[index].isEnabled.toggle()
        hygieneRoutines[index].nextRunAt = hygieneRoutines[index].isEnabled
            ? computeNextRunDate(for: hygieneRoutines[index].frequency, from: Date())
            : nil
    }

    @discardableResult
    func runHygieneRoutineNow(_ routineID: UUID) async -> CleanupExecutionResult? {
        guard let index = hygieneRoutines.firstIndex(where: { $0.id == routineID }) else { return nil }
        let routine = hygieneRoutines[index]
        for pack in reclaimPacks where packMatchesRoutine(pack: pack, routine: routine) {
            addPackToCart(pack)
        }
        let result = await executeCleanup(mode: routine.templateAction)
        hygieneRoutines[index].lastRunAt = Date()
        hygieneRoutines[index].nextRunAt = hygieneRoutines[index].isEnabled
            ? computeNextRunDate(for: hygieneRoutines[index].frequency, from: Date())
            : nil
        return result
    }

    func setFilter(_ update: (inout StorageFilterState) -> Void) {
        var copy = filters
        update(&copy)
        filters = copy
    }

    func setCurrentPath(_ path: String) {
        currentPath = path
    }

    func selectNode(_ node: StorageNode?) {
        selectedNodeID = node?.id
    }

    func addToCart(_ node: StorageNode) {
        let candidate = cleanupCandidate(for: node)
        guard candidate.blockedReason == nil else {
            lastWarning = candidate.blockedReason
            return
        }
        cartNodeIDs.insert(node.id)
    }

    func removeFromCart(_ node: StorageNode) {
        cartNodeIDs.remove(node.id)
    }

    func toggleCart(_ node: StorageNode) {
        if cartNodeIDs.contains(node.id) {
            removeFromCart(node)
        } else {
            addToCart(node)
        }
    }

    func addPackToCart(_ pack: StorageReclaimPack) {
        for path in pack.paths {
            guard let node = findNode(by: path) else { continue }
            addToCart(node)
        }
    }

    func addPersonaBundleToCart(_ bundle: StoragePersonaBundle) {
        for path in bundle.candidatePaths {
            guard let node = findNode(by: path) else { continue }
            addToCart(node)
        }
    }

    func openInAppManager(for node: StorageNode) {
        let query = node.ownerApp ?? node.name
        Task { @MainActor in
            let inventory = AppInventoryService.shared
            inventory.selectedTab = .apps
            inventory.searchText = query
            NotificationCenter.default.post(
                name: .openAppManagerFromStorageHub,
                object: nil,
                userInfo: ["query": query, "path": node.path]
            )
        }
    }

    func nextGuidedStep() {
        activeGuidedStep = min(activeGuidedStep + 1, max(guidedSteps.count - 1, 0))
    }

    func previousGuidedStep() {
        activeGuidedStep = max(activeGuidedStep - 1, 0)
    }

    @discardableResult
    func loadChildrenIfNeeded(for node: StorageNode, forceRefresh: Bool = false) async -> [StorageNode] {
        if !forceRefresh, let cached = nodesByPath[node.path], !cached.isEmpty {
            let needsHydration = cached.contains(where: \.sizeIsEstimated)
            if !needsHydration {
                return cached
            }
        }

        do {
            let result = try await scanner.scanPath(node.path, mode: .quick, policy: scanPolicy) { _ in }
            let mapped = mapEntries(
                result.entries,
                parentPath: node.path,
                depth: node.depth + 1,
                calculateChildCounts: true,
                resolveResourceMetadata: shouldResolveStrictMetadata
            )
            let sorted = mapped.sorted { $0.logicalBytes > $1.logicalBytes }
            setChildren(sorted, for: node.path)
            refreshChildrenSummary(forParentPath: node.path, loadedChildren: sorted.count, totalChildrenHint: sorted.count)
            return nodesByPath[node.path] ?? []
        } catch {
            lastWarning = error.localizedDescription
            return []
        }
    }

    @discardableResult
    func loadPathIfNeeded(_ path: String, forceRefresh: Bool = false) async -> [StorageNode] {
        if !forceRefresh, let cached = nodesByPath[path], !cached.isEmpty {
            let needsHydration = cached.contains(where: \.sizeIsEstimated)
            if !needsHydration {
                return cached
            }
        }

        do {
            let result = try await scanner.scanPath(path, mode: .quick, policy: scanPolicy) { _ in }
            let mapped = mapEntries(
                result.entries,
                parentPath: path,
                depth: (path as NSString).pathComponents.count,
                calculateChildCounts: true,
                resolveResourceMetadata: shouldResolveStrictMetadata
            )
            let sorted = mapped.sorted { $0.logicalBytes > $1.logicalBytes }
            setChildren(sorted, for: path)
            refreshChildrenSummary(forParentPath: path, loadedChildren: sorted.count, totalChildrenHint: sorted.count)
            return nodesByPath[path] ?? []
        } catch {
            lastWarning = error.localizedDescription
            return []
        }
    }

    func prepareCleanupPlan(mode: CleanupActionType = .moveToTrash) -> CleanupPlan {
        let candidates = cartCandidates.map { candidate in
            CleanupCandidate(
                id: candidate.id,
                nodeId: candidate.nodeId,
                path: candidate.path,
                actionType: mode,
                estimatedReclaimBytes: candidate.estimatedReclaimBytes,
                riskLevel: candidate.riskLevel,
                safeReason: candidate.safeReason,
                blockedReason: candidate.blockedReason,
                selected: candidate.selected
            )
        }

        let dryRun = dryRunCleanupResult(for: candidates, mode: mode)
        return CleanupPlan(
            id: UUID(),
            items: candidates,
            mode: mode,
            dryRunResult: dryRun,
            executionResult: nil,
            undoToken: nil
        )
    }

    @discardableResult
    func undoLastCleanupPlan() async -> Bool {
        let undone = await fileOperations.undoLastOperation()
        if undone {
            let detail = "Storage cleanup undo completed"
            ActivityLogStore.shared.record(ActivityEvent(category: .clean, title: "Storage cleanup undone", detail: detail, impact: .low))
        }
        return undone
    }

    @discardableResult
    func executeCleanup(mode: CleanupActionType = .moveToTrash) async -> CleanupExecutionResult {
        let plan = prepareCleanupPlan(mode: mode)
        return await executeCleanup(plan: plan)
    }

    @discardableResult
    func executeCleanup(plan: CleanupPlan) async -> CleanupExecutionResult {
        let beforeUsed = usedBytesForVolume(path: session?.scope.rootPath ?? currentPath)
        let blockedCandidates = plan.items.filter { $0.blockedReason != nil }
        var failedItems = blockedCandidates.count
        var failures = blockedCandidates.compactMap { candidate in
            candidate.blockedReason.map { "\(candidate.path): \($0)" }
        }

        let executable = plan.items.filter { $0.blockedReason == nil }
        var cleanedBytes: Int64 = 0
        var cleanedItems = 0
        var excludedItems = 0
        var excludedBytes: Int64 = 0
        var undoToken: String?

        switch plan.mode {
        case .excludeForever:
            for candidate in executable {
                excludedPaths.insert(candidate.path)
                excludedItems += 1
                excludedBytes += candidate.estimatedReclaimBytes
                cartNodeIDs.remove(candidate.nodeId)
            }
            persistExcludedPaths()

        case .moveToTrash:
            let paths = executable.map(\.path)
            let operation = await fileOperations.moveFilesToTrash(atPaths: paths)
            let failedPathSet = Set(operation.errors.map(\.path))
            cleanedBytes = operation.bytesFreed
            cleanedItems = operation.filesProcessed
            failedItems += operation.errors.count
            failures.append(contentsOf: operation.errors.compactMap(\.errorDescription))
            undoToken = fileOperations.latestOperationRecordID?.uuidString

            for candidate in executable where !failedPathSet.contains(candidate.path) {
                cartNodeIDs.remove(candidate.nodeId)
            }

        case .secureDelete:
            let paths = executable.map(\.path)
            let operation = await fileOperations.deleteFiles(atPaths: paths)
            let failedPathSet = Set(operation.errors.map(\.path))
            cleanedBytes = operation.bytesFreed
            cleanedItems = operation.filesProcessed
            failedItems += operation.errors.count
            failures.append(contentsOf: operation.errors.compactMap(\.errorDescription))

            for candidate in executable where !failedPathSet.contains(candidate.path) {
                cartNodeIDs.remove(candidate.nodeId)
            }
        }

        let afterUsed = usedBytesForVolume(path: session?.scope.rootPath ?? currentPath)
        let result = CleanupExecutionResult(
            cleanedBytes: cleanedBytes,
            cleanedItems: cleanedItems,
            excludedItems: excludedItems,
            excludedBytes: excludedBytes,
            failedItems: failedItems,
            failures: failures,
            beforeUsedBytes: beforeUsed > 0 ? beforeUsed : nil,
            afterUsedBytes: afterUsed > 0 ? afterUsed : nil,
            completedAt: Date()
        )

        lastCleanupPlan = CleanupPlan(
            id: plan.id,
            items: plan.items,
            mode: plan.mode,
            dryRunResult: plan.dryRunResult,
            executionResult: result,
            undoToken: undoToken
        )

        let reclaimedText = ByteCountFormatter.string(fromByteCount: cleanedBytes, countStyle: .file)
        let detail = "Storage Intelligence cleanup • reclaimed \(reclaimedText) • \(cleanedItems) cleaned • \(excludedItems) excluded"
        ActivityLogStore.shared.record(
            ActivityEvent(
                category: .clean,
                title: "Storage cleanup executed",
                detail: detail,
                impact: cleanedBytes > 1_000_000_000 ? .high : .medium,
                metadata: undoToken == nil ? nil : ["undoToken": undoToken ?? ""]
            )
        )

        return result
    }

    // MARK: - Scan Pipeline

    private func runScan(
        mode: StorageScanMode,
        scope: StorageScanScope,
        continuation: AsyncStream<ScanEvent>.Continuation
    ) async {
        let policy = scanPolicy
        let resolveStrictMetadata = shouldResolveStrictMetadata
        let startedAt = Date()
        var stageDurations: [String: TimeInterval] = [:]
        var activePhase = "Preparing"
        var phaseStartedAt = Date()
        var lastProgressEmission = Date.distantPast

        var cumulativeFiles: Int64 = 0
        var cumulativeItems: Int64 = 0
        var cumulativeBytes: Int64 = 0
        var cumulativeIndexedDirectories: Int64 = 0
        var cumulativeIndexedNodes: Int64 = 0
        var eventBatchCount: Int64 = 0
        var totalBatchLatency: TimeInterval = 0
        var compatibilityNodeEventSent = false
        var largeFileMap: [String: LargeFile] = [:]

        func beginPhase(_ phase: String, status: StorageScanStatus) {
            let now = Date()
            stageDurations[activePhase, default: 0] += now.timeIntervalSince(phaseStartedAt)
            activePhase = phase
            phaseStartedAt = now
            continuation.yield(.phaseStarted(phase))
            updateSession(status: status)
            updateSessionStageDurations(stageDurations)
        }

        func emitProgress(_ snapshot: ScanProgressSnapshot, force: Bool = false) {
            let now = Date()
            guard force || now.timeIntervalSince(lastProgressEmission) >= policy.progressEmitInterval else { return }
            updateSessionProgress(files: snapshot.scannedItems, bytes: snapshot.scannedBytes)
            updateSessionIndexing(
                indexedDirectories: snapshot.indexedDirectories,
                indexedNodes: snapshot.indexedNodes
            )
            continuation.yield(.progress(
                filesScanned: snapshot.scannedItems,
                bytesScanned: snapshot.scannedBytes,
                currentPath: snapshot.currentPath
            ))
            lastProgressEmission = now
        }

        continuation.yield(.phaseStarted(activePhase))
        updateSession(status: .preparing)
        updateSessionStageDurations(stageDurations)

        do {
            beginPhase("Scanning", status: .scanning)

            let scanRoots = resolvedScanRoots(mode: mode, scope: scope)
            for scanRoot in scanRoots {
                if Task.isCancelled {
                    continuation.yield(.cancelled)
                    continuation.finish()
                    return
                }

                if mode == .quick {
                    let rootScanResult = try await scanner.scanPath(scanRoot, mode: .quick, policy: policy) { progress in
                        let mergedItems = cumulativeItems + progress.filesScanned + progress.dirsScanned
                        let mergedBytes = cumulativeBytes + progress.bytesScanned
                        emitProgress(
                            ScanProgressSnapshot(
                                scannedItems: mergedItems,
                                scannedBytes: mergedBytes,
                                indexedDirectories: cumulativeIndexedDirectories,
                                indexedNodes: cumulativeIndexedNodes,
                                currentPath: progress.currentPath
                            )
                        )
                    }

                    beginPhase("Indexing", status: .indexing)

                    let rootNodes = mapEntries(
                        rootScanResult.entries,
                        parentPath: scanRoot,
                        depth: 1,
                        calculateChildCounts: true,
                        resolveResourceMetadata: resolveStrictMetadata
                    ).sorted { $0.logicalBytes > $1.logicalBytes }
                    setChildren(rootNodes, for: scanRoot)
                    refreshChildrenSummary(
                        forParentPath: scanRoot,
                        loadedChildren: rootNodes.count,
                        totalChildrenHint: rootNodes.count
                    )
                    currentPath = scanRoots.first ?? scope.rootPath

                    if !rootNodes.isEmpty {
                        continuation.yield(.nodeIndexedBatch(rootNodes))
                        eventBatchCount += 1
                        totalBatchLatency += policy.eventEmitInterval
                        if !compatibilityNodeEventSent, let firstNode = rootNodes.first {
                            continuation.yield(.nodeIndexed(firstNode))
                            compatibilityNodeEventSent = true
                        }
                    }

                    let rootDirectoryCount = Int64(rootScanResult.entries.filter(\.isDir).count)
                    cumulativeFiles += rootScanResult.totalFiles
                    cumulativeItems += rootScanResult.totalFiles + rootDirectoryCount
                    cumulativeBytes += rootScanResult.totalSize
                    for large in rootScanResult.largeFiles {
                        largeFileMap[large.path] = large
                    }

                    emitProgress(
                        ScanProgressSnapshot(
                            scannedItems: cumulativeItems,
                            scannedBytes: cumulativeBytes,
                            indexedDirectories: cumulativeIndexedDirectories,
                            indexedNodes: cumulativeIndexedNodes,
                            currentPath: scanRoot
                        ),
                        force: true
                    )
                } else {
                    let rootEntries = await scanWorker.listImmediateChildren(at: scanRoot)
                    beginPhase("Indexing", status: .indexing)

                    let rootNodes = mapEntries(
                        rootEntries,
                        parentPath: scanRoot,
                        depth: 1,
                        calculateChildCounts: false,
                        resolveResourceMetadata: resolveStrictMetadata
                    ).sorted { $0.logicalBytes > $1.logicalBytes }
                    setChildren(rootNodes, for: scanRoot)
                    refreshChildrenSummary(
                        forParentPath: scanRoot,
                        loadedChildren: rootNodes.count,
                        totalChildrenHint: rootNodes.count
                    )
                    currentPath = scanRoots.first ?? scope.rootPath

                    if !rootNodes.isEmpty {
                        continuation.yield(.nodeIndexedBatch(rootNodes))
                        eventBatchCount += 1
                        totalBatchLatency += policy.eventEmitInterval
                        if !compatibilityNodeEventSent, let firstNode = rootNodes.first {
                            continuation.yield(.nodeIndexed(firstNode))
                            compatibilityNodeEventSent = true
                        }
                    }

                    let rootFileCount = Int64(rootNodes.filter { !$0.isDirectory }.count)
                    let rootFileBytes = rootNodes.reduce(into: Int64(0)) { partialResult, node in
                        if !node.isDirectory {
                            partialResult += node.logicalBytes
                        }
                    }
                    cumulativeFiles += rootFileCount
                    cumulativeItems += Int64(rootNodes.count)
                    cumulativeBytes += rootFileBytes
                    for node in rootNodes where !node.isDirectory && node.logicalBytes >= 100 * 1024 * 1024 {
                        largeFileMap[node.path] = LargeFile(name: node.name, path: node.path, size: node.logicalBytes)
                    }

                    emitProgress(
                        ScanProgressSnapshot(
                            scannedItems: cumulativeItems,
                            scannedBytes: cumulativeBytes,
                            indexedDirectories: cumulativeIndexedDirectories,
                            indexedNodes: cumulativeIndexedNodes,
                            currentPath: scanRoot
                        ),
                        force: true
                    )

                    let indexingSnapshot = await recursivelyIndexDirectories(
                        from: rootNodes.filter(\.isDirectory),
                        continuation: continuation,
                        policy: policy,
                        resolveResourceMetadata: resolveStrictMetadata
                    ) { snapshot in
                        let mergedSnapshot = ScanProgressSnapshot(
                            scannedItems: cumulativeItems + snapshot.indexedNodes,
                            scannedBytes: cumulativeBytes + snapshot.indexedBytesEstimate,
                            indexedDirectories: cumulativeIndexedDirectories + snapshot.indexedDirectories,
                            indexedNodes: cumulativeIndexedNodes + snapshot.indexedNodes,
                            currentPath: snapshot.currentPath
                        )
                        for large in snapshot.newLargeFiles {
                            largeFileMap[large.path] = large
                        }
                        emitProgress(mergedSnapshot)
                    }

                    cumulativeFiles += indexingSnapshot.indexedFiles
                    cumulativeItems += indexingSnapshot.indexedNodes
                    cumulativeBytes += indexingSnapshot.indexedBytesEstimate
                    cumulativeIndexedDirectories += indexingSnapshot.indexedDirectories
                    cumulativeIndexedNodes += indexingSnapshot.indexedNodes
                    eventBatchCount += indexingSnapshot.eventBatchCount
                    totalBatchLatency += indexingSnapshot.totalBatchLatency

                    _ = materializeDirectoryRollups(from: scanRoot)

                    emitProgress(
                        ScanProgressSnapshot(
                            scannedItems: cumulativeItems,
                            scannedBytes: cumulativeBytes,
                            indexedDirectories: cumulativeIndexedDirectories,
                            indexedNodes: cumulativeIndexedNodes,
                            currentPath: scanRoot
                        ),
                        force: true
                    )
                }
            }

            stageDurations[activePhase, default: 0] += Date().timeIntervalSince(phaseStartedAt)
            updateSessionStageDurations(stageDurations)

            let aggregateEntries = scanRoots.flatMap { rootPath in
                (nodesByPath[rootPath] ?? []).map {
                    DirEntry(
                        name: $0.name,
                        path: $0.path,
                        size: $0.logicalBytes,
                        isDir: $0.isDirectory,
                        lastAccess: $0.lastAccess ?? Date(),
                        isEstimated: $0.sizeIsEstimated
                    )
                }
            }
            let rootTotalSize = scanRoots.reduce(into: Int64(0)) { partialResult, rootPath in
                partialResult += (nodesByPath[rootPath] ?? []).reduce(0) { $0 + $1.logicalBytes }
            }

            let aggregateScanResult = DiskScanResult(
                entries: aggregateEntries,
                largeFiles: Array(largeFileMap.values).sorted { $0.size > $1.size },
                totalSize: max(rootTotalSize, cumulativeBytes),
                totalFiles: cumulativeFiles,
                scanDuration: Date().timeIntervalSince(startedAt)
            )

            let primaryRoot = scanRoots.first ?? scope.rootPath
            insights = await buildInsights(rootPath: primaryRoot, scanResult: aggregateScanResult)
            reclaimPacks = await buildReclaimPacks(rootPath: primaryRoot, scanResult: aggregateScanResult)
            personaBundles = buildPersonaBundles(rootPath: primaryRoot)

            for insight in insights {
                continuation.yield(.insightReady(insight))
            }

            let elapsed = max(Date().timeIntervalSince(startedAt), 0.001)
            updateSessionPerformance(
                filesPerSecond: Double(cumulativeFiles) / elapsed,
                directoriesPerSecond: Double(cumulativeIndexedDirectories) / elapsed,
                eventBatchesPerSecond: Double(eventBatchCount) / elapsed,
                avgBatchLatency: eventBatchCount > 0 ? totalBatchLatency / Double(eventBatchCount) : 0,
                energyMode: policy.energyMode
            )

            let confidence = computeConfidence(rootPath: primaryRoot, scanResult: aggregateScanResult)
            updateSessionCompletion(confidence: confidence)

            let domainMap = domainBreakdown(for: nodesByPath[primaryRoot] ?? [])
            let volumeUsed = usedBytesForVolume(path: primaryRoot)
            let volumeTotal = totalCapacityForVolume(path: primaryRoot)
            let previousScan = history.first(where: { $0.rootPath == primaryRoot })
            timeShiftSummary = computeTimeShiftSummary(
                previousScan: previousScan,
                currentDomainBreakdown: domainMap,
                currentTotalScanned: aggregateScanResult.totalSize,
                currentReclaimable: totalReclaimableBytes
            )
            forecast = buildForecast(
                rootPath: primaryRoot,
                currentUsedBytes: volumeUsed,
                currentTotalBytes: volumeTotal
            )
            anomalies = buildAnomalies(
                rootPath: primaryRoot,
                domainBreakdown: domainMap,
                totalDelta: timeShiftSummary?.totalBytesDelta ?? 0
            )

            if let session {
                continuation.yield(.completed(session))
                persistHistory(
                    StorageScanHistoryEntry(
                        id: UUID(),
                        finishedAt: session.endAt ?? Date(),
                        rootPath: primaryRoot,
                        mode: session.mode,
                        reclaimedBytes: totalReclaimableBytes,
                        scannedBytes: session.scannedBytes,
                        confidence: session.confidence,
                        volumeUsedBytes: volumeUsed,
                        volumeTotalBytes: volumeTotal,
                        domainBreakdown: encodeDomainBreakdown(domainMap),
                        scanDuration: session.endAt?.timeIntervalSince(session.startAt)
                    )
                )
            }

            if liveMonitoringEnabled {
                startLiveMonitoring()
            }
        } catch is CancellationError {
            updateSession(status: .cancelled)
            continuation.yield(.cancelled)
        } catch {
            lastWarning = error.localizedDescription
            updateSessionFailure(error.localizedDescription)
            continuation.yield(.warning(error.localizedDescription))
        }

        continuation.finish()
        streamContinuation = nil
        scanTask = nil
    }

    private func mapEntries(
        _ entries: [DirEntry],
        parentPath _: String,
        depth: Int,
        calculateChildCounts: Bool,
        resolveResourceMetadata: Bool = false
    ) -> [StorageNode] {
        entries.map { entry in
            let domain = classifyDomain(for: entry.path)
            let risk = classifyRisk(for: entry.path, domain: domain)
            let reclaimable: Int64 = risk == .protected ? 0 : entry.size
            let ownerApp = detectOwnerApp(path: entry.path)
            let fileType = classifyFileType(path: entry.path, isDirectory: entry.isDir)
            let resource: NodeResourceMetadata
            if resolveResourceMetadata {
                resource = resourceMetadata(for: entry.path)
            } else {
                resource = NodeResourceMetadata(
                    volumeID: entry.volumeIDHint,
                    volumeName: entry.volumeNameHint,
                    fileSystemID: entry.filesystemIDHint,
                    lastOpenedAt: entry.lastOpenedHint,
                    lastOpenedEstimated: entry.lastOpenedEstimated
                )
            }
            let loadedChildren = nodesByPath[entry.path]?.count ?? 0
            let totalChildren = entry.isDir
                ? (calculateChildCounts ? countImmediateChildren(at: entry.path) : loadedChildren)
                : 0
            let hasMore = entry.isDir
                ? (calculateChildCounts ? loadedChildren < totalChildren : true)
                : false

            return StorageNode(
                id: entry.path,
                path: entry.path,
                name: entry.name,
                kind: classifyKind(entry: entry),
                logicalBytes: entry.size,
                physicalBytes: entry.size,
                childrenSummary: StorageNodeChildrenSummary(
                    totalChildren: totalChildren,
                    loadedChildren: loadedChildren,
                    hasMore: hasMore
                ),
                riskLevel: risk,
                ownerApp: ownerApp,
                domain: domain,
                fileType: fileType,
                volumeID: resource.volumeID,
                volumeName: resource.volumeName,
                filesystemID: resource.fileSystemID,
                depth: depth,
                isHidden: entry.name.hasPrefix("."),
                isDirectory: entry.isDir,
                lastAccess: entry.lastAccess,
                lastOpenedAt: resource.lastOpenedAt ?? entry.lastAccess,
                lastOpenedEstimated: resource.lastOpenedEstimated,
                lastSizeRefreshAt: entry.isEstimated ? nil : Date(),
                reclaimableBytes: reclaimable,
                sizeIsEstimated: entry.isEstimated
            )
        }
    }

    private func classifyDomain(for path: String) -> StorageDomain {
        let homePath = fileManager.homeDirectoryForCurrentUser.path
        if path.hasPrefix("/System") || path.hasPrefix("/Library") {
            return .system
        }
        if path.contains("/Applications") {
            return .applications
        }
        if path.contains("/Developer") || path.contains("Xcode") || path.contains("/.build") || path.contains("/DerivedData") {
            return .developer
        }
        if path.contains("/Library/CloudStorage") || path.contains("Dropbox") || path.contains("Google Drive") || path.contains("OneDrive") {
            return .cloud
        }
        if path.hasPrefix(homePath) {
            return .userFiles
        }
        return .other
    }

    private func classifyRisk(for path: String, domain: StorageDomain) -> StorageRiskLevel {
        if isProtectedPath(path) {
            return .protected
        }

        if domain == .system {
            return .high
        }

        if path.contains("/Library/Application Support") || path.contains("/Library/Preferences") {
            return .medium
        }

        return .low
    }

    private func classifyKind(entry: DirEntry) -> StorageNodeKind {
        if entry.isDir {
            if entry.name.hasSuffix(".app") || entry.name.hasSuffix(".bundle") || entry.name.hasSuffix(".framework") {
                return .package
            }
            return .directory
        }
        return .file
    }

    private func detectOwnerApp(path: String) -> String? {
        if let exact = appOwnershipIndex[path] {
            return exact
        }

        if let bundleRoot = appBundleRoot(in: path),
           let owner = appOwnershipBundleIndex[bundleRoot] {
            return owner
        }

        guard let appRange = path.range(of: ".app/") else { return nil }
        let appPathPrefix = path[..<appRange.lowerBound]
        return (String(appPathPrefix) as NSString).lastPathComponent
    }

    private func classifyFileType(path: String, isDirectory: Bool) -> StorageFileType {
        if isDirectory, path.hasSuffix(".app") {
            return .application
        }

        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg", "png", "gif", "bmp", "tiff", "webp", "heic":
            return .image
        case "mp4", "mov", "avi", "mkv", "flv", "wmv", "webm":
            return .video
        case "mp3", "m4a", "wav", "flac", "aac", "ogg":
            return .audio
        case "pdf", "doc", "docx", "txt", "rtf", "pages", "numbers", "key":
            return .document
        case "zip", "rar", "7z", "tar", "gz", "bz2", "dmg", "iso", "pkg":
            return .archive
        case "swift", "m", "h", "mm", "c", "cc", "cpp", "hpp", "js", "ts", "tsx", "py", "go", "rs", "java", "kt":
            return .developer
        case "app":
            return .application
        default:
            return .other
        }
    }

    private struct NodeResourceMetadata {
        let volumeID: String?
        let volumeName: String?
        let fileSystemID: String?
        let lastOpenedAt: Date?
        let lastOpenedEstimated: Bool
    }

    private func resourceMetadata(for path: String) -> NodeResourceMetadata {
        let url = URL(fileURLWithPath: path)
        let keys: Set<URLResourceKey> = [
            .volumeIdentifierKey,
            .volumeNameKey,
            .fileResourceIdentifierKey,
            .contentAccessDateKey
        ]

        guard let values = try? url.resourceValues(forKeys: keys) else {
            return NodeResourceMetadata(
                volumeID: nil,
                volumeName: nil,
                fileSystemID: nil,
                lastOpenedAt: nil,
                lastOpenedEstimated: true
            )
        }

        let volumeID = values.volumeIdentifier.map { String(describing: $0) }
        let volumeName = values.volumeName
        let fsID = values.fileResourceIdentifier.map { String(describing: $0) }
        let opened = values.contentAccessDate
        return NodeResourceMetadata(
            volumeID: volumeID,
            volumeName: volumeName,
            fileSystemID: fsID,
            lastOpenedAt: opened,
            lastOpenedEstimated: opened == nil
        )
    }

    private func countImmediateChildren(at path: String) -> Int {
        guard let children = try? fileManager.contentsOfDirectory(
            atPath: path
        ) else {
            return 0
        }
        return children.count
    }

    private func cleanupCandidate(for node: StorageNode, duplicateConflict: Bool = false) -> CleanupCandidate {
        let blockedReason: String?
        if duplicateConflict {
            blockedReason = "Duplicate filesystem item already in cart"
        } else if excludedPaths.contains(node.path) {
            blockedReason = "Path is excluded"
        } else if node.riskLevel == .protected {
            blockedReason = "Protected system location"
        } else if node.reclaimableBytes <= 0 {
            blockedReason = "No reclaimable size"
        } else {
            blockedReason = nil
        }

        let safeReason: String
        switch node.riskLevel {
        case .low: safeReason = "Safe cleanup candidate"
        case .medium: safeReason = "Review recommended before cleanup"
        case .high: safeReason = "Potential side effects, review carefully"
        case .protected: safeReason = "Protected by Safety Center policy"
        }

        return CleanupCandidate(
            id: UUID(),
            nodeId: node.id,
            path: node.path,
            actionType: .moveToTrash,
            estimatedReclaimBytes: node.reclaimableBytes,
            riskLevel: node.riskLevel,
            safeReason: safeReason,
            blockedReason: blockedReason,
            selected: cartNodeIDs.contains(node.id)
        )
    }

    private func buildInsights(rootPath: String, scanResult: DiskScanResult) async -> [StorageInsight] {
        var result: [StorageInsight] = []

        let usedBytes = usedBytesForVolume(path: rootPath)
        let unknownBytes = max(usedBytes - scanResult.totalSize, 0)
        let hiddenEstimate = Int64(Double(unknownBytes) * 0.45)
        let purgeableEstimate = Int64(Double(unknownBytes) * 0.25)

        result.append(StorageInsight(
            id: UUID(),
            category: .hidden,
            bytes: hiddenEstimate,
            confidence: 0.58,
            explanation: "Estimated hidden and restricted content not fully visible from standard scan paths.",
            recommendedActions: ["Grant Full Disk Access", "Run Full mode"]
        ))

        result.append(StorageInsight(
            id: UUID(),
            category: .purgeable,
            bytes: purgeableEstimate,
            confidence: 0.45,
            explanation: "Estimated purgeable and cache-managed space that macOS may reclaim automatically.",
            recommendedActions: ["Restart after cleanup", "Review large temporary files"]
        ))

        result.append(StorageInsight(
            id: UUID(),
            category: .unknown,
            bytes: unknownBytes,
            confidence: 0.40,
            explanation: "Difference between total used storage and indexed scan content.",
            recommendedActions: ["Re-run with Full mode", "Inspect System and hidden categories"]
        ))

        let topDomain = (nodesByPath[rootPath] ?? []).reduce(into: [StorageDomain: Int64]()) { partialResult, node in
            partialResult[node.domain, default: 0] += node.logicalBytes
        }
        if let dominant = topDomain.max(by: { $0.value < $1.value }) {
            var actions = ["Review top \(dominant.key.rawValue.lowercased())", "Add large items to cart"]
            if dominant.key == .applications {
                actions.append("Open in App Manager")
            }
            result.append(StorageInsight(
                id: UUID(),
                category: dominant.key == .applications ? .applications : .user,
                bytes: dominant.value,
                confidence: 0.92,
                explanation: "\(dominant.key.rawValue) currently dominate storage usage.",
                recommendedActions: actions
            ))
        }

        return result
    }

    private func buildReclaimPacks(rootPath: String, scanResult: DiskScanResult) async -> [StorageReclaimPack] {
        var packs: [StorageReclaimPack] = []
        let junk = await categoryScanner.scanJunkFiles()

        let junkCandidates: [(String, String, Int64, [String], StorageRiskLevel)] = [
            ("Downloads old files", "Older files in Downloads likely safe to archive or delete.", junk.oldFiles.size, junk.oldFiles.paths, .low),
            ("Browser caches", "Cache files can be regenerated by browsers.", junk.cacheFiles.size, junk.cacheFiles.paths, .low),
            ("Log files", "Old logs are usually safe to remove.", junk.logFiles.size, junk.logFiles.paths, .medium),
            ("Trash bins", "Items in Trash are reclaimable now.", junk.trashItems.size, junk.trashItems.paths, .low),
            ("Temp files", "Temporary artifacts from apps and build tools.", junk.tempFiles.size, junk.tempFiles.paths, .low)
        ]

        for candidate in junkCandidates where candidate.2 > 0 {
            packs.append(StorageReclaimPack(
                id: UUID(),
                title: candidate.0,
                rationale: candidate.1,
                reclaimableBytes: candidate.2,
                paths: candidate.3,
                riskLevel: candidate.4
            ))
        }

        let archives = scanResult.largeFiles.filter {
            let ext = ($0.name as NSString).pathExtension.lowercased()
            return ["zip", "tar", "gz", "7z", "rar", "dmg", "iso", "pkg"].contains(ext)
        }
        let archiveBytes = archives.reduce(0) { $0 + $1.size }
        if archiveBytes > 0 {
            packs.append(StorageReclaimPack(
                id: UUID(),
                title: "Large archives and disk images",
                rationale: "Large compressed files and images are often stale and high-impact.",
                reclaimableBytes: archiveBytes,
                paths: archives.map(\.path),
                riskLevel: .medium
            ))
        }

        let xcodePaths = (nodesByPath[rootPath] ?? []).filter {
            $0.path.contains("Xcode") || $0.path.contains("/Developer")
        }
        let xcodeBytes = xcodePaths.reduce(0) { $0 + $1.reclaimableBytes }
        if xcodeBytes > 0 {
            packs.append(StorageReclaimPack(
                id: UUID(),
                title: "Xcode derived data and simulators",
                rationale: "Developer artifacts can grow rapidly and are usually reproducible.",
                reclaimableBytes: xcodeBytes,
                paths: xcodePaths.map(\.path),
                riskLevel: .medium
            ))
        }

        return packs.sorted { $0.reclaimableBytes > $1.reclaimableBytes }
    }

    private func buildPersonaBundles(rootPath: String) -> [StoragePersonaBundle] {
        let nodes = nodesByPath[rootPath] ?? []
        var bundles: [StoragePersonaBundle] = []

        let developerCandidates = nodes.filter {
            let path = $0.path.lowercased()
            return path.contains("xcode") || path.contains("deriveddata") || path.contains("simulator") || path.contains("node_modules") || path.contains("/.build")
        }
        if !developerCandidates.isEmpty {
            bundles.append(StoragePersonaBundle(
                id: UUID(),
                persona: .developer,
                title: "Developer Workspace Cleanup",
                rationale: "Derived data, simulators, and build artifacts tend to regrow and are often safe to regenerate.",
                reclaimableBytes: developerCandidates.reduce(0) { $0 + $1.reclaimableBytes },
                candidatePaths: Array(developerCandidates.prefix(10).map(\.path)),
                riskLevel: .medium
            ))
        }

        let creatorCandidates = nodes.filter {
            let path = $0.path.lowercased()
            return path.contains("/movies") || path.contains("/pictures") || path.contains("adobe") || path.contains("premiere") || path.contains("final cut")
        }
        if !creatorCandidates.isEmpty {
            bundles.append(StoragePersonaBundle(
                id: UUID(),
                persona: .creator,
                title: "Creator Media Archives",
                rationale: "Media exports and render caches are usually high-impact opportunities.",
                reclaimableBytes: creatorCandidates.reduce(0) { $0 + $1.reclaimableBytes },
                candidatePaths: Array(creatorCandidates.prefix(10).map(\.path)),
                riskLevel: .medium
            ))
        }

        let gamerCandidates = nodes.filter {
            let path = $0.path.lowercased()
            return path.contains("steam") || path.contains("epic") || path.contains("battle.net") || path.contains("/games")
        }
        if !gamerCandidates.isEmpty {
            bundles.append(StoragePersonaBundle(
                id: UUID(),
                persona: .gamer,
                title: "Game Content Footprint",
                rationale: "Cached game assets and inactive game libraries usually consume significant space.",
                reclaimableBytes: gamerCandidates.reduce(0) { $0 + $1.reclaimableBytes },
                candidatePaths: Array(gamerCandidates.prefix(10).map(\.path)),
                riskLevel: .medium
            ))
        }

        let officeCandidates = nodes.filter {
            let path = $0.path.lowercased()
            return path.contains("/downloads") || path.contains("/documents") || path.contains("/desktop")
        }
        if !officeCandidates.isEmpty {
            bundles.append(StoragePersonaBundle(
                id: UUID(),
                persona: .office,
                title: "Office Clutter Sweep",
                rationale: "Stale installers, duplicate exports, and old downloads are generally low-risk wins.",
                reclaimableBytes: officeCandidates.reduce(0) { $0 + $1.reclaimableBytes },
                candidatePaths: Array(officeCandidates.prefix(10).map(\.path)),
                riskLevel: .low
            ))
        }

        return bundles.sorted { $0.reclaimableBytes > $1.reclaimableBytes }
    }

    private func buildAnomalies(
        rootPath: String,
        domainBreakdown: [StorageDomain: Int64],
        totalDelta: Int64
    ) -> [StorageAnomaly] {
        var result: [StorageAnomaly] = []

        if totalDelta > 8 * 1024 * 1024 * 1024 {
            result.append(StorageAnomaly(
                id: UUID(),
                detectedAt: Date(),
                path: rootPath,
                bytesDelta: totalDelta,
                severity: .warning,
                likelyCause: "Rapid storage growth since last scan",
                recommendation: "Review top growth domains and add the largest folders to cart."
            ))
        }

        for pack in reclaimPacks.prefix(3) where pack.reclaimableBytes > 4 * 1024 * 1024 * 1024 {
            result.append(StorageAnomaly(
                id: UUID(),
                detectedAt: Date(),
                path: pack.paths.first ?? rootPath,
                bytesDelta: pack.reclaimableBytes,
                severity: pack.riskLevel == .high ? .critical : .info,
                likelyCause: "\(pack.title) accumulated unusually high reclaimable data",
                recommendation: "Open bundle details and validate before cleanup."
            ))
        }

        if let systemBytes = domainBreakdown[.system], systemBytes > 80 * 1024 * 1024 * 1024 {
            result.append(StorageAnomaly(
                id: UUID(),
                detectedAt: Date(),
                path: "/System",
                bytesDelta: systemBytes,
                severity: .warning,
                likelyCause: "System domain is dominating storage consumption",
                recommendation: "Use Insights to separate purgeable and unknown system allocations."
            ))
        }

        return result.sorted { abs($0.bytesDelta) > abs($1.bytesDelta) }
    }

    private func computeTimeShiftSummary(
        previousScan: StorageScanHistoryEntry?,
        currentDomainBreakdown: [StorageDomain: Int64],
        currentTotalScanned: Int64,
        currentReclaimable: Int64
    ) -> StorageTimeShiftSummary? {
        guard let previousScan else { return nil }
        let previousDomains = decodeDomainBreakdown(previousScan.domainBreakdown)

        let deltas = StorageDomain.allCases.map { domain in
            StorageDomainDelta(
                id: domain.rawValue,
                domain: domain,
                bytesDelta: currentDomainBreakdown[domain, default: 0] - previousDomains[domain, default: 0]
            )
        }
        .sorted { abs($0.bytesDelta) > abs($1.bytesDelta) }

        let totalDelta = currentTotalScanned - previousScan.scannedBytes
        let reclaimDelta = currentReclaimable - previousScan.reclaimedBytes
        let dominantDelta = deltas.first(where: { $0.bytesDelta != 0 })
        let narrative: String
        if let dominantDelta {
            let deltaValue = ByteCountFormatter.string(fromByteCount: abs(dominantDelta.bytesDelta), countStyle: .file)
            let direction = dominantDelta.bytesDelta >= 0 ? "grew" : "shrunk"
            narrative = "\(dominantDelta.domain.rawValue) \(direction) by \(deltaValue) since last scan."
        } else {
            narrative = "Storage footprint is stable since the previous scan."
        }

        return StorageTimeShiftSummary(
            baselineDate: previousScan.finishedAt,
            totalBytesDelta: totalDelta,
            reclaimableBytesDelta: reclaimDelta,
            domainDeltas: deltas,
            narrative: narrative
        )
    }

    private func buildForecast(
        rootPath: String,
        currentUsedBytes: Int64,
        currentTotalBytes: Int64
    ) -> StorageForecast {
        var points = history
            .filter { $0.rootPath == rootPath }
            .compactMap { entry -> (date: Date, used: Int64)? in
                guard let used = entry.volumeUsedBytes, used > 0 else { return nil }
                return (entry.finishedAt, used)
            }
            .sorted { $0.date < $1.date }

        if currentUsedBytes > 0 {
            points.append((Date(), currentUsedBytes))
        }

        guard let first = points.first, let last = points.last, points.count >= 2 else {
            return StorageForecast(
                estimatedDaysToFull: nil,
                projectedFullDate: nil,
                avgDailyGrowthBytes: 0,
                confidence: 0.30,
                narrative: "Need at least two completed scans on this scope for forecasting."
            )
        }

        let duration = max(last.date.timeIntervalSince(first.date), 1)
        let dailyGrowth = Int64(Double(last.used - first.used) / (duration / 86_400))
        let growthPositive = max(dailyGrowth, 0)
        let remaining = max(currentTotalBytes - currentUsedBytes, 0)
        let daysToFull: Int? = growthPositive > 0 ? Int(remaining / growthPositive) : nil
        let projectedDate = daysToFull.map { Calendar.current.date(byAdding: .day, value: $0, to: Date()) ?? Date() }
        let confidence = min(0.9, 0.35 + Double(points.count) * 0.08)

        let narrative: String
        if let daysToFull {
            narrative = "At current growth pace, this volume may fill in about \(daysToFull) days."
        } else {
            narrative = "Storage growth is flat or decreasing; no saturation date projected."
        }

        return StorageForecast(
            estimatedDaysToFull: daysToFull,
            projectedFullDate: projectedDate,
            avgDailyGrowthBytes: dailyGrowth,
            confidence: confidence,
            narrative: narrative
        )
    }

    private func defaultHygieneRoutines() -> [StorageHygieneRoutine] {
        [
            StorageHygieneRoutine(
                id: UUID(),
                title: "Weekly Low-Risk Hygiene",
                description: "Clean browser caches, temp files, and trash with strict safety constraints.",
                frequency: .weekly,
                isEnabled: false,
                nextRunAt: nil,
                lastRunAt: nil,
                guardrails: ["Move to Trash only", "Never touch protected paths", "Review blocked items"],
                templateAction: .moveToTrash
            ),
            StorageHygieneRoutine(
                id: UUID(),
                title: "Biweekly Download Audit",
                description: "Review and clean stale installer archives and old downloads.",
                frequency: .biweekly,
                isEnabled: false,
                nextRunAt: nil,
                lastRunAt: nil,
                guardrails: ["Exclude app bundles", "Require user review in cart before execution"],
                templateAction: .moveToTrash
            ),
            StorageHygieneRoutine(
                id: UUID(),
                title: "Monthly Deep Reclaim",
                description: "Focus on heavy reclaim packs with medium risk and explicit confirmations.",
                frequency: .monthly,
                isEnabled: false,
                nextRunAt: nil,
                lastRunAt: nil,
                guardrails: ["No secure delete for high-risk candidates", "Log all execution outcomes"],
                templateAction: .moveToTrash
            )
        ]
    }

    private func computeNextRunDate(for frequency: HygieneFrequency, from date: Date) -> Date {
        let days: Int
        switch frequency {
        case .weekly: days = 7
        case .biweekly: days = 14
        case .monthly: days = 30
        }
        return Calendar.current.date(byAdding: .day, value: days, to: date) ?? date
    }

    private func packMatchesRoutine(pack: StorageReclaimPack, routine: StorageHygieneRoutine) -> Bool {
        let title = pack.title.lowercased()
        let routineTitle = routine.title.lowercased()
        if routineTitle.contains("download") {
            return title.contains("download") || title.contains("archive")
        }
        if routineTitle.contains("deep") {
            return pack.riskLevel == .medium || pack.reclaimableBytes > 500 * 1024 * 1024
        }
        return pack.riskLevel == .low || title.contains("cache") || title.contains("temp") || title.contains("trash")
    }

    private func resolvedScanRoots(mode: StorageScanMode, scope: StorageScanScope) -> [String] {
        if mode == .targeted {
            let targeted = scope.targetedPaths.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            return targeted.isEmpty ? [scope.rootPath] : targeted
        }
        return [scope.rootPath]
    }

    private func effectiveWorkerCount(policy: ScanPerformancePolicy) -> Int {
        let thermal = ProcessInfo.processInfo.thermalState
        let upper = max(policy.minWorkers, policy.maxWorkers)
        switch thermal {
        case .nominal:
            return upper
        case .fair:
            return max(policy.minWorkers, upper - 2)
        case .serious:
            return max(policy.minWorkers, upper / 2)
        case .critical:
            return policy.minWorkers
        @unknown default:
            return max(policy.minWorkers, upper / 2)
        }
    }

    private struct IndexingProgressSnapshot: Sendable {
        var indexedDirectories: Int64
        var indexedFiles: Int64
        var indexedNodes: Int64
        var indexedBytesEstimate: Int64
        var newLargeFiles: [LargeFile]
        var eventBatchCount: Int64
        var totalBatchLatency: TimeInterval
        var currentPath: String
    }

    private func recursivelyIndexDirectories(
        from directories: [StorageNode],
        continuation: AsyncStream<ScanEvent>.Continuation,
        policy: ScanPerformancePolicy,
        resolveResourceMetadata: Bool,
        onProgress: @escaping (IndexingProgressSnapshot) -> Void
    ) async -> IndexingProgressSnapshot {
        let coordinator = ScanIndexCoordinatorActor(initialDirectories: directories, scanWorker: scanWorker)
        var indexedDirectories: Int64 = 0
        var indexedFiles: Int64 = 0
        var indexedNodes: Int64 = 0
        var indexedBytesEstimate: Int64 = 0
        var newLargeFilesSinceProgress: [LargeFile] = []
        var eventBatchCount: Int64 = 0
        var totalBatchLatency: TimeInterval = 0
        var currentProgressPath = currentPath
        var pendingNodes: [StorageNode] = []
        var lastEventEmitAt = Date()
        var lastProgressEmitAt = Date.distantPast

        func flushPendingNodes(force: Bool = false) {
            guard !pendingNodes.isEmpty else { return }
            let elapsed = Date().timeIntervalSince(lastEventEmitAt)
            let shouldEmit = force || pendingNodes.count >= policy.eventBatchSize || elapsed >= policy.eventEmitInterval
            guard shouldEmit else { return }
            continuation.yield(.nodeIndexedBatch(pendingNodes))
            eventBatchCount += 1
            totalBatchLatency += elapsed
            pendingNodes.removeAll(keepingCapacity: true)
            lastEventEmitAt = Date()
        }

        func emitProgress(force: Bool = false) {
            let now = Date()
            guard force || now.timeIntervalSince(lastProgressEmitAt) >= policy.progressEmitInterval else { return }
            onProgress(
                IndexingProgressSnapshot(
                    indexedDirectories: indexedDirectories,
                    indexedFiles: indexedFiles,
                    indexedNodes: indexedNodes,
                    indexedBytesEstimate: indexedBytesEstimate,
                    newLargeFiles: newLargeFilesSinceProgress,
                    eventBatchCount: eventBatchCount,
                    totalBatchLatency: totalBatchLatency,
                    currentPath: currentProgressPath
                )
            )
            newLargeFilesSinceProgress.removeAll(keepingCapacity: true)
            lastProgressEmitAt = now
        }

        while await coordinator.hasRemaining(), !Task.isCancelled {
            let workerCount = effectiveWorkerCount(policy: policy)
            let batchResults = await coordinator.nextBatch(workerCount: workerCount)
            if batchResults.isEmpty {
                continue
            }

            if ProcessInfo.processInfo.thermalState == .serious || ProcessInfo.processInfo.thermalState == .critical {
                try? await Task.sleep(nanoseconds: 40_000_000)
            }

            var discoveredDirectories: [StorageNode] = []
            var updates: [(parentPath: String, children: [StorageNode])] = []

            for (directory, entries) in batchResults {
                if Task.isCancelled {
                    break
                }

                let mapped = mapEntries(
                    entries,
                    parentPath: directory.path,
                    depth: directory.depth + 1,
                    calculateChildCounts: false,
                    resolveResourceMetadata: resolveResourceMetadata
                )
                updates.append((parentPath: directory.path, children: mapped))
                discoveredDirectories.append(contentsOf: mapped.filter(\.isDirectory))
                indexedDirectories += 1
                indexedFiles += Int64(mapped.filter { !$0.isDirectory }.count)
                indexedNodes += Int64(mapped.count)
                indexedBytesEstimate += mapped.reduce(0) { partialResult, node in
                    partialResult + (node.isDirectory ? 0 : node.logicalBytes)
                }
                for fileNode in mapped where !fileNode.isDirectory && fileNode.logicalBytes >= 100 * 1024 * 1024 {
                    let largeFile = LargeFile(
                        name: fileNode.name,
                        path: fileNode.path,
                        size: fileNode.logicalBytes
                    )
                    newLargeFilesSinceProgress.append(largeFile)
                }
                currentProgressPath = directory.path
            }

            for update in updates {
                setChildren(update.children, for: update.parentPath)
                refreshChildrenSummary(
                    forParentPath: update.parentPath,
                    loadedChildren: update.children.count,
                    totalChildrenHint: update.children.count
                )
                pendingNodes.append(contentsOf: update.children)
            }
            flushPendingNodes()
            emitProgress()

            if !discoveredDirectories.isEmpty {
                await coordinator.enqueue(discoveredDirectories)
            }
        }

        flushPendingNodes(force: true)
        emitProgress(force: true)

        return IndexingProgressSnapshot(
            indexedDirectories: indexedDirectories,
            indexedFiles: indexedFiles,
            indexedNodes: indexedNodes,
            indexedBytesEstimate: indexedBytesEstimate,
            newLargeFiles: [],
            eventBatchCount: eventBatchCount,
            totalBatchLatency: totalBatchLatency,
            currentPath: currentProgressPath
        )
    }

    private func dryRunCleanupResult(for candidates: [CleanupCandidate], mode: CleanupActionType) -> CleanupExecutionResult {
        let blockedCount = candidates.filter { $0.blockedReason != nil }.count
        let executable = candidates.filter { $0.blockedReason == nil }

        let cleanedBytes: Int64
        let cleanedItems: Int
        let excludedItems: Int
        let excludedBytes: Int64

        if mode == .excludeForever {
            cleanedBytes = 0
            cleanedItems = 0
            excludedItems = executable.count
            excludedBytes = executable.reduce(0) { $0 + $1.estimatedReclaimBytes }
        } else {
            cleanedBytes = executable.reduce(0) { $0 + $1.estimatedReclaimBytes }
            cleanedItems = executable.count
            excludedItems = 0
            excludedBytes = 0
        }

        return CleanupExecutionResult(
            cleanedBytes: cleanedBytes,
            cleanedItems: cleanedItems,
            excludedItems: excludedItems,
            excludedBytes: excludedBytes,
            failedItems: blockedCount,
            failures: candidates.compactMap { candidate in
                candidate.blockedReason.map { "\(candidate.path): \($0)" }
            },
            beforeUsedBytes: nil,
            afterUsedBytes: nil,
            completedAt: Date()
        )
    }

    private func canonicalIdentityPath(_ path: String) -> String {
        URL(fileURLWithPath: path)
            .resolvingSymlinksInPath()
            .standardizedFileURL
            .path
    }

    private func setChildren(_ children: [StorageNode], for parentPath: String) {
        nodesByPath[parentPath] = children
        for child in children {
            parentGroupIndex[child.path] = parentPath
        }
    }

    private func refreshChildrenSummary(
        forParentPath parentPath: String,
        loadedChildren: Int,
        totalChildrenHint: Int? = nil
    ) {
        guard let groupPath = parentGroupIndex[parentPath],
              var groupNodes = nodesByPath[groupPath],
              let index = groupNodes.firstIndex(where: { $0.path == parentPath }) else {
            return
        }

        let existing = groupNodes[index]
        let total = max(
            existing.childrenSummary.totalChildren,
            totalChildrenHint ?? countImmediateChildren(at: parentPath)
        )
        let summary = StorageNodeChildrenSummary(
            totalChildren: total,
            loadedChildren: loadedChildren,
            hasMore: loadedChildren < total
        )
        groupNodes[index] = node(existing, with: summary)
        nodesByPath[groupPath] = groupNodes
    }

    private func materializeDirectoryRollups(from rootPath: String) -> Int64 {
        var memo: [String: Int64] = [:]

        func sizeForDirectory(_ path: String) -> Int64 {
            if let cached = memo[path] {
                return cached
            }

            guard let children = nodesByPath[path] else {
                memo[path] = 0
                return 0
            }

            var total: Int64 = 0
            for child in children {
                if child.isDirectory {
                    total += sizeForDirectory(child.path)
                } else {
                    total += child.logicalBytes
                }
            }
            memo[path] = total
            return total
        }

        _ = sizeForDirectory(rootPath)

        for (path, total) in memo {
            guard let groupPath = parentGroupIndex[path],
                  var siblings = nodesByPath[groupPath],
                  let index = siblings.firstIndex(where: { $0.path == path }) else {
                continue
            }

            let existing = siblings[index]
            let rolled = StorageNode(
                id: existing.id,
                path: existing.path,
                name: existing.name,
                kind: existing.kind,
                logicalBytes: total,
                physicalBytes: total,
                childrenSummary: existing.childrenSummary,
                riskLevel: existing.riskLevel,
                ownerApp: existing.ownerApp,
                domain: existing.domain,
                fileType: existing.fileType,
                volumeID: existing.volumeID,
                volumeName: existing.volumeName,
                filesystemID: existing.filesystemID,
                depth: existing.depth,
                isHidden: existing.isHidden,
                isDirectory: existing.isDirectory,
                lastAccess: existing.lastAccess,
                lastOpenedAt: existing.lastOpenedAt,
                lastOpenedEstimated: existing.lastOpenedEstimated,
                lastSizeRefreshAt: Date(),
                reclaimableBytes: existing.riskLevel == .protected ? 0 : total,
                sizeIsEstimated: false
            )
            siblings[index] = rolled
            nodesByPath[groupPath] = siblings
        }

        return memo[rootPath] ?? 0
    }

    private func node(_ node: StorageNode, with summary: StorageNodeChildrenSummary) -> StorageNode {
        StorageNode(
            id: node.id,
            path: node.path,
            name: node.name,
            kind: node.kind,
            logicalBytes: node.logicalBytes,
            physicalBytes: node.physicalBytes,
            childrenSummary: summary,
            riskLevel: node.riskLevel,
            ownerApp: node.ownerApp,
            domain: node.domain,
            fileType: node.fileType,
            volumeID: node.volumeID,
            volumeName: node.volumeName,
            filesystemID: node.filesystemID,
            depth: node.depth,
            isHidden: node.isHidden,
            isDirectory: node.isDirectory,
            lastAccess: node.lastAccess,
            lastOpenedAt: node.lastOpenedAt,
            lastOpenedEstimated: node.lastOpenedEstimated,
            lastSizeRefreshAt: node.lastSizeRefreshAt,
            reclaimableBytes: node.reclaimableBytes,
            sizeIsEstimated: node.sizeIsEstimated
        )
    }

    private func refreshAppOwnershipIndex() async {
        let apps = await MainActor.run {
            AppInventoryService.shared.apps
        }
        var exactIndex: [String: String] = [:]
        var bundleIndex: [String: String] = [:]
        for app in apps {
            let appPath = app.path.path
            exactIndex[appPath] = app.appName
            if let bundleRoot = appBundleRoot(in: appPath) {
                bundleIndex[bundleRoot] = app.appName
            } else if appPath.hasSuffix(".app") {
                bundleIndex[appPath] = app.appName
            }
        }
        appOwnershipIndex = exactIndex
        appOwnershipBundleIndex = bundleIndex
    }

    private func appBundleRoot(in path: String) -> String? {
        if path.hasSuffix(".app") {
            return path
        }
        guard let appRange = path.range(of: ".app/") else {
            return nil
        }
        return String(path[..<appRange.upperBound].dropLast())
    }

    private func domainBreakdown(for nodes: [StorageNode]) -> [StorageDomain: Int64] {
        nodes.reduce(into: [StorageDomain: Int64]()) { partialResult, node in
            partialResult[node.domain, default: 0] += node.logicalBytes
        }
    }

    private func encodeDomainBreakdown(_ breakdown: [StorageDomain: Int64]) -> [String: Int64] {
        breakdown.reduce(into: [String: Int64]()) { partialResult, pair in
            partialResult[pair.key.rawValue] = pair.value
        }
    }

    private func decodeDomainBreakdown(_ breakdown: [String: Int64]?) -> [StorageDomain: Int64] {
        guard let breakdown else { return [:] }
        var parsed: [StorageDomain: Int64] = [:]
        for (key, value) in breakdown {
            guard let domain = StorageDomain(rawValue: key) else { continue }
            parsed[domain] = value
        }
        return parsed
    }

    private func computeConfidence(rootPath: String, scanResult: DiskScanResult) -> Double {
        let usedBytes = usedBytesForVolume(path: rootPath)
        guard usedBytes > 0 else { return 0.6 }

        let coverage = min(max(Double(scanResult.totalSize) / Double(usedBytes), 0), 1)
        let permissionBonus = scanResult.totalSize > 0 ? 0.05 : -0.1
        let warningPenalty = Double(session?.warnings.count ?? 0) * 0.04
        return min(max(coverage + permissionBonus - warningPenalty, 0.3), 0.98)
    }

    private func applyFilters(to nodes: [StorageNode]) -> [StorageNode] {
        nodes.filter { node in
            if node.logicalBytes < filters.minBytes { return false }
            if !filters.domains.contains(node.domain) { return false }
            if !filters.riskLevels.contains(node.riskLevel) { return false }
            if !filters.fileTypes.contains(node.fileType) { return false }
            if !filters.volumes.isEmpty {
                guard let volumeName = node.volumeName, filters.volumes.contains(volumeName) else {
                    return false
                }
            }
            if !filters.includeHidden && node.isHidden { return false }
            if !filters.includeSystem && node.domain == .system { return false }
            if filters.onlyReclaimable && node.reclaimableBytes <= 0 { return false }
            if excludedPaths.contains(node.path) { return false }
            if let minAgeDays = filters.minAgeDays {
                guard let lastAccess = node.lastAccess else { return false }
                let ageSeconds = Date().timeIntervalSince(lastAccess)
                if ageSeconds < Double(minAgeDays) * 86_400 {
                    return false
                }
            }
            if filters.lastOpenedWindow != .any {
                let referenceDate = node.lastOpenedAt
                if referenceDate == nil && filters.lastOpenedIsStrict {
                    return false
                }
                let lastOpened = referenceDate ?? node.lastAccess
                guard let lastOpened else { return false }
                let ageDays = Date().timeIntervalSince(lastOpened) / 86_400
                switch filters.lastOpenedWindow {
                case .any:
                    break
                case .last7Days:
                    if ageDays > 7 { return false }
                case .last30Days:
                    if ageDays > 30 { return false }
                case .last90Days:
                    if ageDays > 90 { return false }
                case .olderThan90Days:
                    if ageDays <= 90 { return false }
                }
            }
            if !filters.ownerApps.isEmpty {
                guard let owner = node.ownerApp, filters.ownerApps.contains(owner) else {
                    return false
                }
            }
            if !filters.searchText.isEmpty {
                let needle = filters.searchText.lowercased()
                if !node.name.lowercased().contains(needle) && !node.path.lowercased().contains(needle) {
                    return false
                }
            }
            return true
        }
    }

    private func findNode(by nodeID: String) -> StorageNode? {
        for (_, nodes) in nodesByPath {
            if let node = nodes.first(where: { $0.id == nodeID }) {
                return node
            }
        }
        return nil
    }

    private func isProtectedPath(_ path: String) -> Bool {
        let protectedPrefixes = ["/System", "/usr", "/bin", "/sbin", "/private", "/Library"]
        if protectedPrefixes.contains(where: { path.hasPrefix($0) }) {
            return true
        }
        if path.hasSuffix(".app") && path.hasPrefix("/Applications") {
            return true
        }
        return false
    }

    private func usedBytesForVolume(path: String) -> Int64 {
        let url = URL(fileURLWithPath: path)
        guard let values = try? url.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey]),
              let total = values.volumeTotalCapacity,
              let free = values.volumeAvailableCapacity else {
            return 0
        }
        return Int64(max(total - free, 0))
    }

    private func totalCapacityForVolume(path: String) -> Int64 {
        let url = URL(fileURLWithPath: path)
        guard let values = try? url.resourceValues(forKeys: [.volumeTotalCapacityKey]),
              let total = values.volumeTotalCapacity else {
            return 0
        }
        return Int64(total)
    }

    private func startLiveMonitoring() {
        stopLiveMonitoring()
        liveMonitorTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await sampleLiveSignals()
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
    }

    private func stopLiveMonitoring() {
        liveMonitorTask?.cancel()
        liveMonitorTask = nil
        lastPathSample = [:]
    }

    private func sampleLiveSignals() async {
        let candidateNodes = Array(visibleNodes.filter(\.isDirectory).prefix(8))
        var samplePaths = candidateNodes.map(\.path)
        if samplePaths.isEmpty {
            samplePaths = [currentPath]
        }

        do {
            let entries = try await scanner.getOverviewSizes(for: samplePaths, progress: { _, _ in })
            let now = Date()
            var hotspots: [StorageLiveHotspot] = []
            var readMBps: Double = 0
            var writeMBps: Double = 0

            for entry in entries {
                guard let currentSize = entry.size else { continue }
                if let previous = lastPathSample[entry.path] {
                    let elapsed = max(now.timeIntervalSince(previous.date), 1)
                    let deltaBytes = currentSize - previous.bytes
                    let bytesPerSecond = Int64(Double(deltaBytes) / elapsed)

                    if abs(bytesPerSecond) >= 1_000_000 {
                        let node = findNode(by: entry.path)
                        let read = bytesPerSecond < 0 ? Double(abs(bytesPerSecond)) / 1_048_576 : 0
                        let write = bytesPerSecond > 0 ? Double(bytesPerSecond) / 1_048_576 : 0
                        readMBps += read
                        writeMBps += write

                        hotspots.append(StorageLiveHotspot(
                            id: UUID(),
                            path: entry.path,
                            bytesPerSecond: bytesPerSecond,
                            estimatedReadMBps: read,
                            estimatedWriteMBps: write,
                            sourceLabel: node?.ownerApp ?? node?.domain.rawValue ?? "Filesystem",
                            riskLevel: node?.riskLevel ?? .low,
                            sourceConfidence: .estimated
                        ))
                    }
                }
                lastPathSample[entry.path] = (bytes: currentSize, date: now)
            }

            liveHotspots = hotspots.sorted { abs($0.bytesPerSecond) > abs($1.bytesPerSecond) }
            let utilization = min((readMBps + writeMBps) / 400, 1)
            let point = StorageVolumeIOHistoryPoint(
                id: UUID(),
                date: now,
                readMBps: readMBps,
                writeMBps: writeMBps,
                utilization: utilization
            )
            ioVolumeHistory.append(point)
            if ioVolumeHistory.count > 120 {
                ioVolumeHistory.removeFirst(ioVolumeHistory.count - 120)
            }

            if let measured = measuredProcessProvider.sample(at: now) {
                processDeltas = measured
            } else {
                processDeltas = fallbackProcessProvider.sample(at: now, hotspots: liveHotspots)
            }
        } catch {
            lastWarning = "Live monitoring sample failed: \(error.localizedDescription)"
        }
    }

    private func updateSession(status: StorageScanStatus) {
        guard var session else { return }
        session.status = status
        self.session = session
    }

    private func updateSessionProgress(files: Int64, bytes: Int64) {
        guard var session else { return }
        session.scannedItems = files
        session.scannedBytes = bytes
        self.session = session
    }

    private func updateSessionIndexing(indexedDirectories: Int64, indexedNodes: Int64) {
        guard var session else { return }
        session.indexedDirectories = indexedDirectories
        session.indexedNodes = indexedNodes
        self.session = session
    }

    private func updateSessionStageDurations(_ stageDurations: [String: TimeInterval]) {
        guard var session else { return }
        session.stageDurations = stageDurations
        self.session = session
    }

    private func updateSessionPerformance(
        filesPerSecond: Double,
        directoriesPerSecond: Double,
        eventBatchesPerSecond: Double,
        avgBatchLatency: Double,
        energyMode: String
    ) {
        guard var session else { return }
        session.filesPerSecond = filesPerSecond
        session.directoriesPerSecond = directoriesPerSecond
        session.eventBatchesPerSecond = eventBatchesPerSecond
        session.avgBatchLatency = avgBatchLatency
        session.energyMode = energyMode
        self.session = session
    }

    private func updateSessionCompletion(confidence: Double) {
        guard var session else { return }
        session.status = .completed
        session.endAt = Date()
        session.confidence = confidence
        self.session = session
    }

    private func updateSessionFailure(_ message: String) {
        guard var session else { return }
        session.status = .failed
        session.endAt = Date()
        session.warnings.append(message)
        self.session = session
    }

    private func loadHistory() -> [StorageScanHistoryEntry] {
        guard let data = UserDefaults.standard.data(forKey: historyDefaultsKey),
              let decoded = try? JSONDecoder().decode([StorageScanHistoryEntry].self, from: data) else {
            return []
        }
        return decoded.sorted { $0.finishedAt > $1.finishedAt }
    }

    private func persistHistory(_ entry: StorageScanHistoryEntry) {
        var updated = history
        updated.insert(entry, at: 0)
        history = Array(updated.prefix(20))
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: historyDefaultsKey)
        }
    }

    private func loadExcludedPaths() -> Set<String> {
        guard let stored = UserDefaults.standard.array(forKey: excludedDefaultsKey) as? [String] else {
            return []
        }
        return Set(stored)
    }

    private func persistExcludedPaths() {
        UserDefaults.standard.set(Array(excludedPaths), forKey: excludedDefaultsKey)
    }
}

private protocol ProcessIOMonitorProvider {
    mutating func sample(at date: Date) -> [StorageProcessDelta]?
}

private struct MeasuredProcessIOMonitorProvider: ProcessIOMonitorProvider {
    private var previousTotalsByPID: [Int32: (bytes: Int64, date: Date)] = [:]
    private let minimumRateThreshold: Int64 = 512_000

    mutating func sample(at date: Date) -> [StorageProcessDelta]? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid=,comm=,rbytes=,wbytes="]

        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else { return nil }
        guard let data = try? output.fileHandleForReading.readToEnd(),
              let text = String(data: data, encoding: .utf8) else {
            return nil
        }

        var parsed: [(pid: Int32, name: String, totalBytes: Int64)] = []
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard parts.count >= 4,
                  let pid = Int32(parts[0]),
                  let readBytes = Int64(parts[parts.count - 2]),
                  let writeBytes = Int64(parts[parts.count - 1]) else {
                continue
            }
            let name = parts[1]
            parsed.append((pid: pid, name: name, totalBytes: readBytes + writeBytes))
        }

        guard !parsed.isEmpty else { return nil }
        let activePIDs = Set(parsed.map(\.pid))
        previousTotalsByPID = previousTotalsByPID.filter { activePIDs.contains($0.key) }

        var deltas: [StorageProcessDelta] = []
        for processInfo in parsed {
            guard let previous = previousTotalsByPID[processInfo.pid] else {
                previousTotalsByPID[processInfo.pid] = (processInfo.totalBytes, date)
                continue
            }

            let elapsed = max(date.timeIntervalSince(previous.date), 0.25)
            let deltaBytes = processInfo.totalBytes - previous.bytes
            previousTotalsByPID[processInfo.pid] = (processInfo.totalBytes, date)

            let bytesPerSecond = Int64(Double(deltaBytes) / elapsed)
            if abs(bytesPerSecond) < minimumRateThreshold {
                continue
            }

            deltas.append(
                StorageProcessDelta(
                    id: UUID(),
                    processName: processInfo.name,
                    bytesPerSecond: bytesPerSecond,
                    paths: [],
                    observedAt: date,
                    sourceConfidence: .measured
                )
            )
        }

        return deltas.sorted { abs($0.bytesPerSecond) > abs($1.bytesPerSecond) }
    }
}

private struct PathDeltaFallbackProvider: ProcessIOMonitorProvider {
    mutating func sample(at date: Date) -> [StorageProcessDelta]? {
        return []
    }

    func sample(at date: Date, hotspots: [StorageLiveHotspot]) -> [StorageProcessDelta] {
        let grouped = Dictionary(grouping: hotspots, by: \.sourceLabel)
        return grouped.map { (key, spots) in
            StorageProcessDelta(
                id: UUID(),
                processName: key,
                bytesPerSecond: spots.reduce(0) { $0 + $1.bytesPerSecond },
                paths: spots.map(\.path),
                observedAt: date,
                sourceConfidence: .estimated
            )
        }
        .sorted { abs($0.bytesPerSecond) > abs($1.bytesPerSecond) }
    }
}

extension Notification.Name {
    static let openAppManagerFromStorageHub = Notification.Name("openAppManagerFromStorageHub")
}
