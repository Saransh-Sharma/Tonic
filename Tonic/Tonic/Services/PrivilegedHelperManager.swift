//
//  PrivilegedHelperManager.swift
//  Tonic
//
//  Manages privileged helper tool for root-required operations
//
//  Note: The privileged helper tool architecture is preserved for future implementation
//  of an XPC-based service. Currently, fan control uses direct SMC writes which work
//  on Apple Silicon without requiring a privileged helper.
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
    /// Note: Helper is not yet implemented, always returns false
    public func checkInstallationStatus() -> Bool {
        // The privileged helper tool is not yet implemented.
        // In the future, this will check for the XPC service status.
        // For now, always return false since there's no actual helper.
        isHelperInstalled = false
        installationStatus = "Not Implemented"
        return isHelperInstalled
    }

    /// Install the privileged helper tool
    /// Note: This will be implemented when the XPC service is ready
    public func installHelper() async throws {
        // The privileged helper installation is not yet implemented.
        // This will be replaced with SMAppService registration combined with
        // an XPC service in a future update.
        throw PrivilegedHelperError.operationFailed("Privileged helper is not yet implemented. Fan control uses direct SMC writes on Apple Silicon.")
    }

    /// Uninstall the privileged helper tool
    /// Note: This will be implemented when the XPC service is ready
    public func uninstallHelper() async throws {
        // The privileged helper uninstallation is not yet implemented.
        throw PrivilegedHelperError.operationFailed("Privileged helper is not yet implemented.")
    }

    // MARK: - Connection Management

    /// Establish connection to the helper
    public func establishConnection() async throws {
        // In production, this would create XPC connection
        // For now, no-op since helper is not implemented
        throw PrivilegedHelperError.notInstalled
    }

    /// Disconnect from the helper
    public func disconnect() {
        isHelperConnected = false
    }

    // MARK: - Privileged Operations

    /// Delete a file at the given path with root privileges
    public func deleteFile(atPath path: String) async throws -> Bool {
        throw PrivilegedHelperError.notInstalled
    }

    /// Delete multiple files at the given paths
    public func deleteFiles(atPaths paths: [String]) async throws -> (Int, String?) {
        throw PrivilegedHelperError.notInstalled
    }

    /// Move a file to trash (even if protected)
    public func moveFileToTrash(atPath path: String) async throws -> Bool {
        throw PrivilegedHelperError.notInstalled
    }

    /// Clear system cache directory
    public func clearCache(atPath cachePath: String) async throws -> Int64 {
        throw PrivilegedHelperError.notInstalled
    }

    /// Run a cleanup command with root privileges
    public func runCleanupCommand(_ command: String, arguments: [String]) async throws -> (String?, Int32, String?) {
        throw PrivilegedHelperError.notInstalled
    }

    /// Securely delete a file by overwriting before deletion
    public func secureDeleteFile(atPath path: String, passes: Int = 3) async throws -> Bool {
        throw PrivilegedHelperError.notInstalled
    }

    /// Perform the actual secure deletion
    private func performSecureDelete(atPath path: String, passes: Int) async throws {
        throw PrivilegedHelperError.notInstalled
    }

    /// Get helper version
    public func getVersion() async throws -> String {
        throw PrivilegedHelperError.notInstalled
    }

    // MARK: - Fan Control Methods

    /// Set fan operating mode (auto/manual) via privileged helper
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

    /// Set fan target speed in RPM via privileged helper
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
