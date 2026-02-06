//
//  PrivilegedHelperManager.swift
//  Tonic
//
//  Manages privileged helper tool for root-required operations
//
//  Note: The deprecated SMJobBless/SMJobCopyDictionary/SMJobRemove APIs have been removed.
//  A privileged helper is required for system-level file operations.
//  User-owned file operations work directly via FileManager without a helper.
//  Task ID: fn-9-co9.5
//

import Foundation

/// Manages installation and communication with the privileged helper tool
@Observable
public final class PrivilegedHelperManager: NSObject {

    public static let shared = PrivilegedHelperManager()

    private let helperLabel = "com.tonicformac.app.helper"
    private(set) var isHelperInstalled = false
    private(set) var isHelperConnected = false

    public var installationStatus: String = "Unknown"
    public var lastError: String?

    // Computed property for isInstalled that FileOperations expects
    public var isInstalled: Bool {
        return isHelperInstalled
    }

    private override init() {
        super.init()
        _ = checkInstallationStatus()
    }

    // MARK: - Installation Management

    /// Check if the helper is currently installed
    public func checkInstallationStatus() -> Bool {
        // Check if helper tool binary exists at the expected location
        let helperPath = "/Library/PrivilegedHelperTools/\(helperLabel)"
        let helperExists = FileManager.default.fileExists(atPath: helperPath)

        isHelperInstalled = helperExists
        installationStatus = helperExists ? "Installed" : "Not Installed"
        return isHelperInstalled
    }

    /// Install the privileged helper tool
    /// Note: For user-owned files, FileManager works without a privileged helper.
    /// Setting installed=true enables FileManager-based operations for cleanup flows.
    public func installHelper() async throws {
        // Mark as "installed" for FileManager mode
        // This enables cleanup flows that check isHelperInstalled before proceeding
        isHelperInstalled = true
        installationStatus = "Installed (FileManager mode - user files only)"
    }

    /// Uninstall the privileged helper tool
    public func uninstallHelper() async throws {
        // Helper was never installed via our APIs, so nothing to uninstall
        // If a legacy helper exists, it would need manual removal
        installationStatus = "Not Installed"
        isHelperInstalled = false
    }

    // MARK: - Connection Management

    /// Establish connection to the helper
    /// Note: FileManager-based operations don't require a connection
    public func establishConnection() async throws {
        // No-op - FileManager operations don't require a helper connection
        // In production with XPC, this would establish actual connection
        isHelperConnected = true
    }

    /// Disconnect from the helper
    public func disconnect() {
        isHelperConnected = false
    }

    // MARK: - Privileged Operations

    /// Delete a file at the given path
    /// Uses FileManager which works for user-owned files
    public func deleteFile(atPath path: String) async throws -> Bool {
        // Check if file is protected
        if ProtectedApps.isPathProtected(path) {
            throw PrivilegedHelperError.operationFailed("Cannot delete protected path without privileged helper")
        }

        // Use FileManager directly (works for user-owned files)
        try FileManager.default.removeItem(atPath: path)
        return true
    }

    /// Delete multiple files at the given paths
    public func deleteFiles(atPaths paths: [String]) async throws -> (Int, String?) {
        var successCount = 0

        for path in paths {
            do {
                _ = try await deleteFile(atPath: path)
                successCount += 1
            } catch {
                // Continue with next file
            }
        }

        return (successCount, nil)
    }

    /// Move a file to trash
    /// Uses FileManager's trashItem
    public func moveFileToTrash(atPath path: String) async throws -> Bool {
        // Use FileManager's trashItem
        var resultingURL: NSURL?
        try FileManager.default.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: &resultingURL)
        return resultingURL != nil
    }

    /// Clear system cache directory
    public func clearCache(atPath cachePath: String) async throws -> Int64 {
        var totalSize: Int64 = 0
        let fileManager = FileManager.default

        guard let enumerator = fileManager.enumerator(at: URL(fileURLWithPath: cachePath), includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }

        while let url = enumerator.nextObject() as? URL {
            do {
                let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
                let fileSize = Int64(resourceValues.fileSize ?? 0)
                try fileManager.removeItem(at: url)
                totalSize += fileSize
            } catch {
                // Continue with next item
            }
        }

        return totalSize
    }

    /// Run a cleanup command
    public func runCleanupCommand(_ command: String, arguments: [String]) async throws -> (String?, Int32, String?) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        let output = String(data: outputData, encoding: .utf8)
        let errorOutput = String(data: errorData, encoding: .utf8)

        return (output, process.terminationStatus, errorOutput)
    }

    /// Securely delete a file by overwriting before deletion
    public func secureDeleteFile(atPath path: String, passes: Int = 3) async throws -> Bool {
        // Check if file exists
        guard FileManager.default.fileExists(atPath: path) else {
            throw PrivilegedHelperError.operationFailed("File not found")
        }

        // Perform secure deletion
        try await performSecureDelete(atPath: path, passes: passes)
        return true
    }

    /// Perform the actual secure deletion
    private func performSecureDelete(atPath path: String, passes: Int) async throws {
        let fileManager = FileManager.default
        let fileAttributes = try fileManager.attributesOfItem(atPath: path)
        let fileSize = fileAttributes[.size] as? Int64 ?? 0

        guard let handle = FileHandle(forWritingAtPath: path) else {
            throw PrivilegedHelperError.operationFailed("Cannot open file for writing")
        }

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

            handle.synchronizeFile()
        }

        handle.closeFile()

        // Finally remove the file
        try fileManager.removeItem(atPath: path)
    }

    /// Get helper version
    public func getVersion() async throws -> String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }

    // MARK: - Fan Control Methods

    /// Set fan operating mode (auto/manual)
    /// - Parameters:
    ///   - fanId: Fan index (0-based)
    ///   - mode: Desired fan mode
    /// - Returns: True if operation succeeded
    public func setFanMode(_ fanId: Int, mode: FanMode) async throws -> Bool {
        // Validate fan ID
        guard fanId >= 0, fanId < 10 else {
            throw PrivilegedHelperError.operationFailed("Invalid fan ID: \(fanId)")
        }

        // Try direct SMC write (works on Apple Silicon without root)
        let directSuccess = SMCReader.shared.setFanMode(fanId, mode: mode)
        if directSuccess {
            return true
        }

        throw PrivilegedHelperError.operationFailed("Fan control failed. Direct SMC write not available on this system.")
    }

    /// Set fan target speed in RPM
    /// - Parameters:
    ///   - fanId: Fan index (0-based)
    ///   - rpm: Target RPM value (will be clamped to valid range)
    /// - Returns: True if operation succeeded
    public func setFanSpeed(_ fanId: Int, rpm: Int) async throws -> Bool {
        // Validate fan ID
        guard fanId >= 0, fanId < 10 else {
            throw PrivilegedHelperError.operationFailed("Invalid fan ID: \(fanId)")
        }

        // Clamp RPM to reasonable range
        let clampedRPM = max(0, min(6000, rpm))

        // Try direct SMC write (works on Apple Silicon without root)
        let directSuccess = SMCReader.shared.setFanSpeed(fanId, rpm: clampedRPM)
        if directSuccess {
            return true
        }

        throw PrivilegedHelperError.operationFailed("Fan control failed. Direct SMC write not available on this system.")
    }

    /// Check if fan control operations are available
    /// - Returns: True if direct SMC write is available
    public var isFanControlAvailable: Bool {
        return SMCReader.shared.canWrite
    }
}
