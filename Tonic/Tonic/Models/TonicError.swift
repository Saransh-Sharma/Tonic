//
//  TonicError.swift
//  Tonic
//
//  Comprehensive error enum for all application error scenarios
//  Implements LocalizedError for user-facing error messages
//

import Foundation

/// Comprehensive error enum for Tonic application
/// Provides localized error messages and recovery suggestions for all error scenarios
public enum TonicError: LocalizedError, Sendable {

    // MARK: - Permission Errors

    /// Full Disk Access permission not granted
    case permissionDenied(type: String)

    /// Accessibility permission not granted
    case accessibilityPermissionDenied

    /// Location permission not granted (weather service)
    case locationPermissionDenied

    /// Notification permission not granted
    case notificationPermissionDenied

    // MARK: - File System Errors

    /// File or directory not found
    case fileMissing(path: String)

    /// Cannot access file (access denied, protected)
    case fileAccessDenied(path: String)

    /// Cannot write to file system
    case fileWriteFailed(path: String)

    /// File system operation failed
    case fileOperationFailed(operation: String, reason: String)

    /// Insufficient disk space
    case insufficientDiskSpace(required: Int64, available: Int64)

    /// Cannot delete file (in use or protected)
    case cannotDelete(path: String, reason: String)

    /// Invalid file path
    case invalidFilePath(path: String)

    /// Cleaning operation failed
    case cleaningFailed(category: String, reason: String)

    /// Full Disk Access required
    case fullDiskAccessRequired(operation: String)

    // MARK: - Scan Errors

    /// Scan was interrupted by user
    case scanInterrupted

    /// Scan failed to start
    case scanFailedToStart(reason: String)

    /// Scan encountered an error
    case scanFailed(reason: String)

    /// No permission to scan directory
    case scanPermissionDenied(path: String)

    /// Timeout during scan
    case scanTimeout(operation: String)

    // MARK: - Network Errors

    /// Network request failed
    case networkError(underlyingError: Error)

    /// Network timeout
    case networkTimeout(service: String)

    /// Invalid network response
    case invalidNetworkResponse(service: String)

    /// No internet connection
    case noInternetConnection

    /// Server error (4xx or 5xx)
    case serverError(statusCode: Int, service: String)

    // MARK: - Data/Cache Errors

    /// Cache is corrupted
    case cacheCorrupted(reason: String)

    /// Cache read failed
    case cacheReadFailed

    /// Cache write failed
    case cacheWriteFailed

    /// Invalid data format
    case invalidDataFormat(dataType: String)

    /// Failed to decode data
    case decodingFailed(dataType: String, reason: String)

    /// Failed to encode data
    case encodingFailed(dataType: String)

    // MARK: - Validation Errors

    /// Invalid user input
    case invalidInput(message: String)

    /// Empty input where value required
    case emptyInput(field: String)

    /// Input exceeds maximum length
    case inputTooLong(field: String, max: Int)

    /// Value out of acceptable range
    case valueOutOfRange(field: String, min: String, max: String)

    /// Invalid email format
    case invalidEmail(email: String)

    /// Invalid URL format
    case invalidURL(url: String)

    /// Empty field (alias for emptyInput for compatibility)
    case emptyField(fieldName: String)

    /// Field too short
    case fieldTooShort(fieldName: String, minimum: Int)

    /// Field too long (alias for inputTooLong for compatibility)
    case fieldTooLong(fieldName: String, maximum: Int)

    /// Not numeric value
    case notNumeric(fieldName: String)

    /// Invalid format
    case invalidFormat(fieldName: String, expectedFormat: String)

    /// Validation failed
    case validationFailed(fieldName: String, reason: String)

    // MARK: - System Errors

    /// Out of memory
    case outOfMemory

    /// System call failed
    case systemCallFailed(call: String, errno: Int32)

    /// Operation not supported on this system
    case operationNotSupported(operation: String)

    /// System configuration missing
    case configurationMissing(key: String)

    /// Process failed
    case processFailedFailed(processName: String, exitCode: Int32)

    // MARK: - Helper Tool Errors

    /// Privileged helper tool not installed
    case helperToolNotInstalled

    /// Failed to communicate with helper tool
    case helperToolCommunicationFailed(reason: String)

    /// Helper tool returned an error
    case helperToolError(message: String)

    /// Failed to authorize privileged operation
    case authorizationFailed

    // MARK: - App State Errors

    /// Invalid app state for operation
    case invalidAppState(expectedState: String, currentState: String)

    /// Feature not available
    case featureNotAvailable(feature: String)

    /// Service not initialized
    case serviceNotInitialized(serviceName: String)

    // MARK: - Unknown/Generic Errors

    /// Unknown error with optional description
    case unknown(message: String?)

    /// Generic error from another framework
    case generic(Error)

    // MARK: - LocalizedError Protocol

    public var errorDescription: String? {
        switch self {
        // Permission Errors
        case .permissionDenied(let type):
            return "Permission Denied: \(type)"
        case .accessibilityPermissionDenied:
            return "Accessibility permission is required to complete this action"
        case .locationPermissionDenied:
            return "Location permission is required for weather information"
        case .notificationPermissionDenied:
            return "Notification permission is required for alerts"

        // File System Errors
        case .fileMissing(let path):
            return "File not found: \(path)"
        case .fileAccessDenied(let path):
            return "Access denied: \(path)"
        case .fileWriteFailed(let path):
            return "Cannot write to: \(path)"
        case .fileOperationFailed(let operation, let reason):
            return "\(operation) failed: \(reason)"
        case .insufficientDiskSpace(let required, let available):
            return "Insufficient disk space. Required: \(ByteCountFormatter.string(fromByteCount: required, countStyle: .file)), Available: \(ByteCountFormatter.string(fromByteCount: available, countStyle: .file))"
        case .cannotDelete(let path, let reason):
            return "Cannot delete \(path): \(reason)"
        case .invalidFilePath(let path):
            return "Invalid file path: \(path)"
        case .cleaningFailed(let category, let reason):
            return "Failed to clean \(category): \(reason)"
        case .fullDiskAccessRequired(let operation):
            return "Full Disk Access required for \(operation)"

        // Scan Errors
        case .scanInterrupted:
            return "Scan was interrupted"
        case .scanFailedToStart(let reason):
            return "Failed to start scan: \(reason)"
        case .scanFailed(let reason):
            return "Scan failed: \(reason)"
        case .scanPermissionDenied(let path):
            return "Permission denied to scan: \(path)"
        case .scanTimeout(let operation):
            return "Scan timeout during: \(operation)"

        // Network Errors
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .networkTimeout(let service):
            return "\(service) request timed out"
        case .invalidNetworkResponse(let service):
            return "Invalid response from \(service)"
        case .noInternetConnection:
            return "No internet connection"
        case .serverError(let statusCode, let service):
            return "\(service) server error (\(statusCode))"

        // Data/Cache Errors
        case .cacheCorrupted(let reason):
            return "Cache is corrupted: \(reason)"
        case .cacheReadFailed:
            return "Failed to read cache"
        case .cacheWriteFailed:
            return "Failed to write cache"
        case .invalidDataFormat(let dataType):
            return "Invalid \(dataType) format"
        case .decodingFailed(let dataType, let reason):
            return "Failed to decode \(dataType): \(reason)"
        case .encodingFailed(let dataType):
            return "Failed to encode \(dataType)"

        // Validation Errors
        case .invalidInput(let message):
            return "Invalid input: \(message)"
        case .emptyInput(let field):
            return "\(field) cannot be empty"
        case .inputTooLong(let field, let max):
            return "\(field) exceeds maximum length of \(max) characters"
        case .valueOutOfRange(let field, let min, let max):
            return "\(field) must be between \(min) and \(max)"
        case .invalidEmail(let email):
            return "Invalid email address: \(email)"
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .emptyField(let fieldName):
            return "\(fieldName) cannot be empty"
        case .fieldTooShort(let fieldName, let minimum):
            return "\(fieldName) must be at least \(minimum) characters"
        case .fieldTooLong(let fieldName, let maximum):
            return "\(fieldName) cannot exceed \(maximum) characters"
        case .notNumeric(let fieldName):
            return "\(fieldName) must be a numeric value"
        case .invalidFormat(let fieldName, let expectedFormat):
            return "\(fieldName) format is invalid. Expected: \(expectedFormat)"
        case .validationFailed(let fieldName, let reason):
            return "\(fieldName) validation failed: \(reason)"
        case .invalidURL(let url):
            return "Invalid URL: \(url)"

        // System Errors
        case .outOfMemory:
            return "Out of memory"
        case .systemCallFailed(let call, let errno):
            return "System call failed: \(call) (errno: \(errno))"
        case .operationNotSupported(let operation):
            return "Operation not supported: \(operation)"
        case .configurationMissing(let key):
            return "Configuration missing: \(key)"
        case .processFailedFailed(let processName, let exitCode):
            return "\(processName) failed with exit code \(exitCode)"

        // Helper Tool Errors
        case .helperToolNotInstalled:
            return "Privileged helper tool is not installed"
        case .helperToolCommunicationFailed(let reason):
            return "Failed to communicate with helper tool: \(reason)"
        case .helperToolError(let message):
            return "Helper tool error: \(message)"
        case .authorizationFailed:
            return "Authorization failed"

        // App State Errors
        case .invalidAppState(let expectedState, let currentState):
            return "Invalid app state. Expected: \(expectedState), Current: \(currentState)"
        case .featureNotAvailable(let feature):
            return "\(feature) is not available"
        case .serviceNotInitialized(let serviceName):
            return "\(serviceName) is not initialized"

        // Unknown/Generic Errors
        case .unknown(let message):
            if let message = message {
                return "An error occurred: \(message)"
            }
            return "An unknown error occurred"
        case .generic(let error):
            return "Error: \(error.localizedDescription)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        // Permission Errors
        case .permissionDenied(let type):
            return "Grant \(type) permission in System Settings > Security & Privacy"
        case .accessibilityPermissionDenied:
            return "Enable Accessibility permission in System Settings > Security & Privacy > Accessibility"
        case .locationPermissionDenied:
            return "Enable Location permission in System Settings > Security & Privacy > Location Services"
        case .notificationPermissionDenied:
            return "Enable Notification permission in System Settings > Notifications"

        // File System Errors
        case .fileAccessDenied:
            return "Check file permissions or try running with elevated privileges"
        case .fileWriteFailed:
            return "Check disk space and file permissions"
        case .fileOperationFailed:
            return "Try the operation again or check system permissions"
        case .insufficientDiskSpace:
            return "Free up disk space and try again"
        case .cannotDelete:
            return "Close any applications using this file and try again"
        case .invalidFilePath:
            return "Enter a valid file path"
        case .cleaningFailed:
            return "Try the cleaning operation again or check permissions"
        case .fullDiskAccessRequired:
            return "Grant Full Disk Access permission in System Settings > Security & Privacy > Privacy"

        // Scan Errors
        case .scanInterrupted:
            return "Restart the scan to continue"
        case .scanFailedToStart:
            return "Check your internet connection and try again"
        case .scanFailed:
            return "Try running the scan again"
        case .scanPermissionDenied:
            return "Grant Full Disk Access permission in System Settings"
        case .scanTimeout:
            return "Try the scan again or check your system resources"

        // Network Errors
        case .networkError:
            return "Check your internet connection and try again"
        case .networkTimeout:
            return "Check your internet connection or try again later"
        case .invalidNetworkResponse:
            return "The server response was invalid. Try again later"
        case .noInternetConnection:
            return "Connect to the internet and try again"
        case .serverError:
            return "The service is temporarily unavailable. Try again later"

        // Data/Cache Errors
        case .cacheCorrupted:
            return "The cache will be cleared on next launch"
        case .cacheReadFailed:
            return "Try restarting the application"
        case .cacheWriteFailed:
            return "Check disk space and permissions"
        case .invalidDataFormat:
            return "The data format is invalid. Try restarting the application"
        case .decodingFailed:
            return "The data could not be decoded. Try restarting the application"
        case .encodingFailed:
            return "Failed to save data. Try again"

        // Validation Errors
        case .emptyInput, .emptyField:
            return "This field is required"
        case .inputTooLong, .fieldTooLong:
            return "Reduce the length of your input"
        case .valueOutOfRange:
            return "Enter a value within the specified range"
        case .invalidEmail:
            return "Please enter a valid email address"
        case .invalidURL:
            return "Please enter a valid URL"
        case .fieldTooShort:
            return "Increase the length of your input"
        case .notNumeric:
            return "Enter a numeric value"
        case .invalidFormat:
            return "Enter a value in the correct format"
        case .validationFailed:
            return "Check your input and try again"

        // System Errors
        case .outOfMemory:
            return "Close some applications and try again"
        case .systemCallFailed:
            return "A system error occurred. Try again"
        case .operationNotSupported:
            return "This operation is not supported on your system"
        case .configurationMissing:
            return "Application configuration is missing. Reinstall the application"
        case .processFailedFailed:
            return "Try the operation again"

        // Helper Tool Errors
        case .helperToolNotInstalled:
            return "Reinstall the application with admin privileges"
        case .helperToolCommunicationFailed:
            return "Restart the application and try again"
        case .authorizationFailed:
            return "Authorization was denied. Try again with admin privileges"

        // App State Errors
        case .serviceNotInitialized:
            return "Try restarting the application"

        default:
            return nil
        }
    }

    var errorCode: String {
        switch self {
        // Permission Errors (PE)
        case .permissionDenied: return "PE001"
        case .accessibilityPermissionDenied: return "PE002"
        case .locationPermissionDenied: return "PE003"
        case .notificationPermissionDenied: return "PE004"

        // File System Errors (FE)
        case .fileMissing: return "FE001"
        case .fileAccessDenied: return "FE002"
        case .fileWriteFailed: return "FE003"
        case .fileOperationFailed: return "FE004"
        case .insufficientDiskSpace: return "FE005"
        case .cannotDelete: return "FE006"
        case .invalidFilePath: return "FE007"
        case .cleaningFailed: return "FE008"
        case .fullDiskAccessRequired: return "FE009"

        // Scan Errors (SE)
        case .scanInterrupted: return "SE001"
        case .scanFailedToStart: return "SE002"
        case .scanFailed: return "SE003"
        case .scanPermissionDenied: return "SE004"
        case .scanTimeout: return "SE005"

        // Network Errors (NE)
        case .networkError: return "NE001"
        case .networkTimeout: return "NE002"
        case .invalidNetworkResponse: return "NE003"
        case .noInternetConnection: return "NE004"
        case .serverError: return "NE005"

        // Data/Cache Errors (DE)
        case .cacheCorrupted: return "DE001"
        case .cacheReadFailed: return "DE002"
        case .cacheWriteFailed: return "DE003"
        case .invalidDataFormat: return "DE004"
        case .decodingFailed: return "DE005"
        case .encodingFailed: return "DE006"

        // Validation Errors (VE)
        case .invalidInput: return "VE001"
        case .emptyInput: return "VE002"
        case .inputTooLong: return "VE003"
        case .valueOutOfRange: return "VE004"
        case .invalidEmail: return "VE005"
        case .invalidURL: return "VE006"
        case .emptyField: return "VE007"
        case .fieldTooShort: return "VE008"
        case .fieldTooLong: return "VE009"
        case .notNumeric: return "VE010"
        case .invalidFormat: return "VE011"
        case .validationFailed: return "VE012"

        // System Errors (SYS)
        case .outOfMemory: return "SYS001"
        case .systemCallFailed: return "SYS002"
        case .operationNotSupported: return "SYS003"
        case .configurationMissing: return "SYS004"
        case .processFailedFailed: return "SYS005"

        // Helper Tool Errors (HT)
        case .helperToolNotInstalled: return "HT001"
        case .helperToolCommunicationFailed: return "HT002"
        case .helperToolError: return "HT003"
        case .authorizationFailed: return "HT004"

        // App State Errors (AS)
        case .invalidAppState: return "AS001"
        case .featureNotAvailable: return "AS002"
        case .serviceNotInitialized: return "AS003"

        // Unknown/Generic
        case .unknown: return "UNK001"
        case .generic: return "GEN001"
        }
    }

    // MARK: - Severity Levels

    /// Severity level for error handling and reporting
    var severity: ErrorSeverity {
        switch self {
        case .permissionDenied, .accessibilityPermissionDenied,
             .locationPermissionDenied, .notificationPermissionDenied:
            return .warning

        case .scanInterrupted, .networkTimeout:
            return .info

        case .fileMissing, .invalidInput, .emptyInput, .invalidEmail, .invalidURL:
            return .warning

        case .outOfMemory, .helperToolNotInstalled, .authorizationFailed:
            return .critical

        case .fileAccessDenied, .fileWriteFailed, .cannotDelete,
             .scanFailed, .networkError, .cacheCorrupted:
            return .error

        default:
            return .error
        }
    }

    /// Is this error recoverable?
    var isRecoverable: Bool {
        switch self {
        case .outOfMemory, .systemCallFailed, .operationNotSupported, .configurationMissing:
            return false
        default:
            return true
        }
    }
}

// MARK: - Error Severity

/// Severity level for errors
public enum ErrorSeverity: Int, Comparable {
    case info = 0
    case warning = 1
    case error = 2
    case critical = 3

    public static func < (lhs: ErrorSeverity, rhs: ErrorSeverity) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }

    var displayName: String {
        switch self {
        case .info: return "Info"
        case .warning: return "Warning"
        case .error: return "Error"
        case .critical: return "Critical"
        }
    }
}

// MARK: - Convenience Extensions

extension TonicError {
    /// Check if error is a network error
    var isNetworkError: Bool {
        switch self {
        case .networkError, .networkTimeout, .invalidNetworkResponse, .noInternetConnection, .serverError:
            return true
        default:
            return false
        }
    }

    /// Check if error is a permission error
    var isPermissionError: Bool {
        switch self {
        case .permissionDenied, .accessibilityPermissionDenied, .locationPermissionDenied,
             .notificationPermissionDenied, .fileAccessDenied, .scanPermissionDenied, .authorizationFailed:
            return true
        default:
            return false
        }
    }

    /// Check if error is a file system error
    var isFileSystemError: Bool {
        switch self {
        case .fileMissing, .fileAccessDenied, .fileWriteFailed, .fileOperationFailed,
             .insufficientDiskSpace, .cannotDelete, .invalidFilePath:
            return true
        default:
            return false
        }
    }

    /// Convert to user-facing message (combines error description and recovery suggestion)
    var userFacingMessage: String {
        var message = errorDescription ?? "An error occurred"
        if let suggestion = recoverySuggestion {
            message += "\n\n" + suggestion
        }
        return message
    }
}
