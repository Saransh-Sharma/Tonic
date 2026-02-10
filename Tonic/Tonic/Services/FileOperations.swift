//
//  FileOperations.swift
//  Tonic
//
//  Service for trash and file management operations
//

import Foundation
import UniformTypeIdentifiers

// MARK: - File Operation Types

/// Types of file operations supported by FileOperations service
public enum FileOperationType: String, Sendable, CaseIterable, Codable {
    case delete = "Delete"
    case trash = "Move to Trash"
    case secureDelete = "Secure Delete"
    case copy = "Copy"
    case move = "Move"

    var icon: String {
        switch self {
        case .delete: return "trash"
        case .trash: return "arrow.down.doc"
        case .secureDelete: return "shredder"
        case .copy: return "doc.on.doc"
        case .move: return "arrow.right.doc.on.arrow.left"
        }
    }
}

/// Progress information for file operations
public struct FileOperationProgress: Sendable, Identifiable {
    public let id = UUID()
    public let operationType: FileOperationType
    public let currentFile: String
    public let processedFiles: Int
    public let totalFiles: Int
    public let bytesProcessed: Int64
    public let totalBytes: Int64

    public var progress: Double {
        guard totalFiles > 0 else { return 0 }
        return Double(processedFiles) / Double(totalFiles)
    }

    public var progressString: String {
        let progressPercent = Int(progress * 100)
        return "\(progressPercent)% (\(processedFiles)/\(totalFiles))"
    }
}

/// Result of a file operation
public struct FileOperationResult: Sendable {
    public let success: Bool
    public let operationType: FileOperationType
    public let filesProcessed: Int
    public let bytesFreed: Int64
    public let errors: [FileOperationError]
    public let duration: TimeInterval

    public var formattedBytesFreed: String {
        ByteCountFormatter.string(fromByteCount: bytesFreed, countStyle: .file)
    }

    public var formattedDuration: String {
        NumberFormatter.localizedString(from: NSNumber(value: duration), number: .decimal)
    }
}

/// Error information for file operations
public struct FileOperationError: Sendable, Error, LocalizedError {
    public let path: String
    public let errorType: ErrorType
    public let underlyingError: String?
    public let blockedReason: ScopeBlockedReason?

    public enum ErrorType: String, Sendable {
        case accessDenied = "Access Denied"
        case notFound = "Not Found"
        case protected = "Protected File"
        case insufficientSpace = "Insufficient Space"
        case unknown = "Unknown Error"
    }

    public init(
        path: String,
        errorType: ErrorType,
        underlyingError: String?,
        blockedReason: ScopeBlockedReason? = nil
    ) {
        self.path = path
        self.errorType = errorType
        self.underlyingError = underlyingError
        self.blockedReason = blockedReason
    }

    public var errorDescription: String? {
        var description = "\(errorType.rawValue): \(path)"
        if let blockedReason {
            description += " - \(blockedReason.userMessage)"
        }
        if let underlying = underlyingError {
            description += " - \(underlying)"
        }
        return description
    }
}

/// Record for undo/redo functionality
public struct FileOperationRecord: Sendable, Identifiable, Codable {
    public let id: UUID
    public let operationType: FileOperationType
    public let originalPaths: [String]
    public let destinationPaths: [String]?
    public let timestamp: Date

    public init(operationType: FileOperationType, originalPaths: [String], destinationPaths: [String]?) {
        self.id = UUID()
        self.operationType = operationType
        self.originalPaths = originalPaths
        self.destinationPaths = destinationPaths
        self.timestamp = Date()
    }

    /// Whether this operation can be undone
    public var canUndo: Bool {
        switch operationType {
        case .delete, .secureDelete:
            return false  // Cannot undo permanent deletion
        case .trash:
            return true   // Can restore from trash
        case .copy, .move:
            return destinationPaths != nil
        }
    }
}

// MARK: - File Operations Service

/// Service for managing file operations including trash, deletion, and secure deletion
@Observable
public final class FileOperations: @unchecked Sendable {

    // MARK: - Properties

    private let fileManager = FileManager.default
    private let scopedFS = ScopedFileSystem.shared

    private let lock = NSLock()
    private var _currentProgress: FileOperationProgress?
    private var _operationHistory: [FileOperationRecord] = []
    private var _isProcessing = false

    public var currentProgress: FileOperationProgress? {
        get { lock.locked { _currentProgress } }
        set { lock.locked { _currentProgress = newValue } }
    }

    public var operationHistory: [FileOperationRecord] {
        get { lock.locked { _operationHistory } }
        set { lock.locked { _operationHistory = newValue } }
    }

    public var latestOperationRecordID: UUID? {
        lock.locked { _operationHistory.last?.id }
    }

    public var isProcessing: Bool {
        get { lock.locked { _isProcessing } }
        set { lock.locked { _isProcessing = newValue } }
    }

    // Maximum history size for undo operations
    private let maxHistorySize = 50

    // MARK: - Singleton

    public static let shared = FileOperations()

    private init() {}

    private func mapOperationError(path: String, error: Error, requiresWrite: Bool) -> FileOperationError {
        if let fileError = error as? FileOperationError {
            return fileError
        }

        let blockedReason = scopedFS.blockedReason(for: error, path: path, requiresWrite: requiresWrite)
        let errorType: FileOperationError.ErrorType

        if blockedReason != nil {
            errorType = .accessDenied
        } else if let nsError = error as NSError?, nsError.code == NSFileNoSuchFileError {
            errorType = .notFound
        } else if ProtectedApps.isPathProtected(path) {
            errorType = .protected
        } else {
            errorType = .unknown
        }

        return FileOperationError(
            path: path,
            errorType: errorType,
            underlyingError: error.localizedDescription,
            blockedReason: blockedReason
        )
    }

    // MARK: - Trash Operations

    /// Move files to trash using NSFileManager
    /// - Parameter paths: Array of file paths to move to trash
    /// - Parameter progressHandler: Optional closure for progress updates
    /// - Returns: Result of the operation
    @discardableResult
    public func moveFilesToTrash(
        atPaths paths: [String],
        progressHandler: ((FileOperationProgress) -> Void)? = nil
    ) async -> FileOperationResult {
        let startTime = Date()
        var errors: [FileOperationError] = []
        var processedCount = 0
        var bytesFreed: Int64 = 0
        isProcessing = true

        for (index, path) in paths.enumerated() {
            // Update progress
            let progress = FileOperationProgress(
                operationType: .trash,
                currentFile: path,
                processedFiles: index,
                totalFiles: paths.count,
                bytesProcessed: 0,
                totalBytes: 0
            )
            currentProgress = progress
            progressHandler?(progress)

            do {
                // Try to get file size before moving
                let attributes = try scopedFS.attributesOfItem(atPath: path)
                let fileSize = attributes[.size] as? Int64 ?? 0

                // Attempt regular trash operation
                var resultingURL: NSURL?
                try scopedFS.trashItem(at: path, resultingItemURL: &resultingURL)

                if resultingURL != nil {
                    processedCount += 1
                    bytesFreed += fileSize
                } else {
                    errors.append(FileOperationError(
                        path: path,
                        errorType: .accessDenied,
                        underlyingError: "Trash operation returned no result URL",
                        blockedReason: scopedFS.blockedReason(forPath: path, requiresWrite: true)
                    ))
                }

            } catch {
                errors.append(mapOperationError(path: path, error: error, requiresWrite: true))
            }
        }

        // Record operation for undo when at least one item moved to Trash.
        if processedCount > 0 {
            let record = FileOperationRecord(
                operationType: .trash,
                originalPaths: paths,
                destinationPaths: nil
            )
            addToHistory(record)
        }

        isProcessing = false
        currentProgress = nil

        return FileOperationResult(
            success: errors.isEmpty || processedCount > 0,
            operationType: .trash,
            filesProcessed: processedCount,
            bytesFreed: bytesFreed,
            errors: errors,
            duration: Date().timeIntervalSince(startTime)
        )
    }

    /// Empty the Trash
    /// - Parameter secure: Whether to securely delete (overwrite before delete)
    /// - Returns: Result of the operation
    @discardableResult
    public func emptyTrash(secure: Bool = false) async -> FileOperationResult {
        let startTime = Date()
        var errors: [FileOperationError] = []
        var filesProcessed = 0
        var bytesFreed: Int64 = 0

        isProcessing = true

        // Get trash paths for all user volumes
        let trashPaths = getAllTrashPaths()

        for trashPath in trashPaths {
            var entries: [URL] = []
            do {
                try scopedFS.enumerateDirectory(
                    atPath: trashPath,
                    includingPropertiesForKeys: [.fileSizeKey],
                    options: []
                ) { url in
                    entries.append(url)
                }
            } catch {
                errors.append(mapOperationError(path: trashPath, error: error, requiresWrite: true))
                continue
            }

            for url in entries {
                do {
                    let fileSize: Int64 = (try? scopedFS.resourceValues(for: url, keys: [.fileSizeKey]))
                        .map { Int64($0.fileSize ?? 0) } ?? 0

                    if secure {
                        let _ = try await secureDeleteFile(atPath: url.path, passes: 3)
                    } else {
                        try scopedFS.removeItem(atPath: url.path)
                    }

                    filesProcessed += 1
                    bytesFreed += fileSize
                } catch {
                    errors.append(mapOperationError(path: url.path, error: error, requiresWrite: true))
                }
            }
        }

        isProcessing = false

        return FileOperationResult(
            success: errors.isEmpty || filesProcessed > 0,
            operationType: secure ? .secureDelete : .delete,
            filesProcessed: filesProcessed,
            bytesFreed: bytesFreed,
            errors: errors,
            duration: Date().timeIntervalSince(startTime)
        )
    }

    /// Get the total size of items in Trash
    public func getTrashSize() async -> Int64 {
        var totalSize: Int64 = 0
        let trashPaths = getAllTrashPaths()

        for trashPath in trashPaths {
            do {
                try scopedFS.enumerateDirectory(
                    atPath: trashPath,
                    includingPropertiesForKeys: [.fileSizeKey],
                    options: []
                ) { url in
                    let size: Int64 = (try? scopedFS.resourceValues(for: url, keys: [.fileSizeKey]))
                        .map { Int64($0.fileSize ?? 0) } ?? 0
                    totalSize += size
                }
            } catch {
                continue
            }
        }

        return totalSize
    }

    // MARK: - Delete Operations

    /// Delete files directly without moving to trash
    /// - Parameter paths: Array of file paths to delete
    /// - Returns: Result of the operation
    @discardableResult
    public func deleteFiles(
        atPaths paths: [String]
    ) async -> FileOperationResult {
        let startTime = Date()
        var errors: [FileOperationError] = []
        var processedCount = 0
        var bytesFreed: Int64 = 0

        isProcessing = true

        for (index, path) in paths.enumerated() {
            // Update progress
            currentProgress = FileOperationProgress(
                operationType: .delete,
                currentFile: path,
                processedFiles: index,
                totalFiles: paths.count,
                bytesProcessed: 0,
                totalBytes: 0
            )

            // Get file size before deletion
            let fileSize = (try? scopedFS.attributesOfItem(atPath: path)[.size] as? Int64) ?? 0

            do {
                try scopedFS.removeItem(atPath: path)
                processedCount += 1
                bytesFreed += fileSize
            } catch {
                errors.append(mapOperationError(path: path, error: error, requiresWrite: true))
            }
        }

        isProcessing = false
        currentProgress = nil

        return FileOperationResult(
            success: errors.isEmpty || processedCount > 0,
            operationType: .delete,
            filesProcessed: processedCount,
            bytesFreed: bytesFreed,
            errors: errors,
            duration: Date().timeIntervalSince(startTime)
        )
    }

    /// Securely delete a file by overwriting before deletion
    /// - Parameter path: Path to the file to securely delete
    /// - Parameter passes: Number of overwrite passes (default: 3)
    /// - Returns: True if successful
    public func secureDeleteFile(atPath path: String, passes: Int = 3) async throws -> Bool {
        // Check if file exists
        guard scopedFS.fileExists(atPath: path) else {
            throw FileOperationError(path: path, errorType: .notFound, underlyingError: nil)
        }

        try await manualSecureDelete(atPath: path, passes: passes)
        return true
    }

    // MARK: - Undo/Redo

    /// Undo the last file operation
    public func undoLastOperation() async -> Bool {
        guard let lastOperation = operationHistory.last, lastOperation.canUndo else {
            return false
        }

        switch lastOperation.operationType {
        case .trash:
            // Restore files from trash
            for originalPath in lastOperation.originalPaths {
                _ = await restoreFromTrash(originalPath: originalPath)
            }
            operationHistory.removeLast()
            return true

        case .move:
            // Move files back to original location
            if let destinations = lastOperation.destinationPaths {
                for (index, destPath) in destinations.enumerated() {
                    if index < lastOperation.originalPaths.count {
                        let originalPath = lastOperation.originalPaths[index]
                        try? scopedFS.withWriteAccess(path: destPath) {
                            try scopedFS.withWriteAccess(path: originalPath) {
                                try fileManager.moveItem(atPath: destPath, toPath: originalPath)
                            }
                        }
                    }
                }
                operationHistory.removeLast()
                return true
            }

        default:
            return false
        }

        return false
    }

    /// Clear operation history
    public func clearHistory() {
        operationHistory.removeAll()
    }

    // MARK: - Helper Methods

    /// Get all trash paths for user and mounted volumes
    private func getAllTrashPaths() -> [String] {
        var paths: [String] = []

        // User trash
        if let trashPath = fileManager.urls(for: .trashDirectory, in: .userDomainMask).first {
            paths.append(trashPath.path)
        }

        // Check for external volumes with .Trashes
        if let volumesRoot = try? fileManager.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: URL(fileURLWithPath: "/"), create: false) {
            let trashPath = volumesRoot.appendingPathComponent(".Trashes")
            if scopedFS.fileExists(atPath: trashPath.path) {
                paths.append(trashPath.path)
            }
        }

        return paths
    }

    /// Restore a file from trash to its original location
    private func restoreFromTrash(originalPath: String) async -> Bool {
        let fileName = (originalPath as NSString).lastPathComponent

        // Find the file in trash
        guard let trashURL = fileManager.urls(for: .trashDirectory, in: .userDomainMask).first else {
            return false
        }

        var matchURL: URL?
        do {
            try scopedFS.enumerateDirectory(
                atPath: trashURL.path,
                includingPropertiesForKeys: [.nameKey]
            ) { url in
                if matchURL == nil && url.lastPathComponent == fileName {
                    matchURL = url
                }
            }
        } catch {
            return false
        }

        guard let sourceURL = matchURL else {
            return false
        }

        do {
            try scopedFS.withWriteAccess(path: sourceURL.path) {
                try scopedFS.withWriteAccess(path: originalPath) {
                    try fileManager.moveItem(at: sourceURL, to: URL(fileURLWithPath: originalPath))
                }
            }
            return true
        } catch {
            return false
        }
    }

    /// Manual secure deletion implementation
    private func manualSecureDelete(atPath path: String, passes: Int) async throws {
        do {
            try scopedFS.withWriteAccess(path: path) {
                guard let handle = FileHandle(forWritingAtPath: path) else {
                    throw FileOperationError(path: path, errorType: .accessDenied, underlyingError: "Cannot open file for writing")
                }

                let fileAttributes = try scopedFS.attributesOfItem(atPath: path)
                let fileSize = fileAttributes[.size] as? Int64 ?? 0

                // Overwrite patterns for secure deletion
                let patterns: [UInt8] = [0x00, 0xFF, 0x55, 0xAA, 0x00, 0xFF]

                for pass in 0..<passes {
                    handle.seek(toFileOffset: 0)
                    let pattern = patterns[pass % patterns.count]

                    // Create buffer of 64KB chunks
                    let chunkSize = 64 * 1024
                    var buffer = Data(repeating: pattern, count: chunkSize)

                    var remaining = fileSize
                    while remaining > 0 {
                        let writeSize = min(Int64(chunkSize), remaining)
                        if writeSize < chunkSize {
                            buffer = Data(repeating: pattern, count: Int(writeSize))
                        }
                        handle.write(buffer)
                        remaining -= writeSize
                    }

                    // synchronizeFile() is non-throwing on macOS 14+
                    // Ensures data is written to disk before proceeding
                    handle.synchronizeFile()
                }

                handle.closeFile()
                try fileManager.removeItem(atPath: path)
            }
        } catch {
            throw mapOperationError(path: path, error: error, requiresWrite: true)
        }
    }

    /// Add operation to history
    private func addToHistory(_ record: FileOperationRecord) {
        operationHistory.append(record)
        if operationHistory.count > maxHistorySize {
            operationHistory.removeFirst()
        }
    }

    // MARK: - Batch Operations

    /// Delete files in a directory matching a pattern
    public func deleteFilesInDirectory(
        atPath directoryPath: String,
        matchingPattern pattern: String? = nil,
        recursive: Bool = false
    ) async -> FileOperationResult {
        var filesToDelete: [String] = []

        guard scopedFS.fileExists(atPath: directoryPath) else {
            return FileOperationResult(
                success: false,
                operationType: .delete,
                filesProcessed: 0,
                bytesFreed: 0,
                errors: [FileOperationError(path: directoryPath, errorType: .notFound, underlyingError: nil)],
                duration: 0
            )
        }

        let options: FileManager.DirectoryEnumerationOptions = recursive ? [] : [.skipsSubdirectoryDescendants]

        do {
            try scopedFS.enumerateDirectory(
                atPath: directoryPath,
                includingPropertiesForKeys: nil,
                options: options
            ) { url in
                let filePath = url.path
                if let pattern {
                    let fileName = (filePath as NSString).lastPathComponent
                    if fileName.range(of: pattern, options: .regularExpression) != nil {
                        filesToDelete.append(filePath)
                    }
                } else {
                    filesToDelete.append(filePath)
                }
            }
        } catch {
            return FileOperationResult(
                success: false,
                operationType: .delete,
                filesProcessed: 0,
                bytesFreed: 0,
                errors: [mapOperationError(path: directoryPath, error: error, requiresWrite: true)],
                duration: 0
            )
        }

        return await deleteFiles(atPaths: filesToDelete)
    }

    /// Calculate size of files at given paths
    public func calculateSize(ofPaths paths: [String]) -> Int64 {
        var totalSize: Int64 = 0

        for path in paths {
            let attrs = try? scopedFS.attributesOfItem(atPath: path)
            let isDirectory = (attrs?[.type] as? FileAttributeType) == .typeDirectory

            if isDirectory {
                totalSize += directorySize(atPath: path)
            } else if let fileSize = attrs?[.size] as? Int64 {
                totalSize += fileSize
            }
        }

        return totalSize
    }

    /// Recursively calculate directory size
    private func directorySize(atPath path: String) -> Int64 {
        var totalSize: Int64 = 0

        do {
            try scopedFS.enumerateDirectory(atPath: path, includingPropertiesForKeys: [.fileSizeKey]) { url in
                let values = try? scopedFS.resourceValues(for: url, keys: [.fileSizeKey, .isDirectoryKey])
                if values?.isDirectory == false {
                    totalSize += Int64(values?.fileSize ?? 0)
                }
            }
        } catch {
            return totalSize
        }

        return totalSize
    }

    // MARK: - Validation

    /// Check if paths are safe to delete (not protected)
    public func validatePathsForDeletion(_ paths: [String]) -> (safe: [String], protected: [String]) {
        var safePaths: [String] = []
        var protectedPaths: [String] = []

        for path in paths {
            if ProtectedApps.isPathProtected(path) {
                protectedPaths.append(path)
            } else {
                safePaths.append(path)
            }
        }

        return (safePaths, protectedPaths)
    }

    /// Check if a path requires elevated permissions
    public func requiresElevatedPermissions(_ path: String) -> Bool {
        // Try to read file attributes
        if let attributes = try? scopedFS.attributesOfItem(atPath: path),
           let permissions = attributes[.posixPermissions] as? UInt16 {
            // Check if we have write permission
            let ownerOnly = (permissions & 0o200) != 0
            return !ownerOnly
        }
        return true
    }
}
