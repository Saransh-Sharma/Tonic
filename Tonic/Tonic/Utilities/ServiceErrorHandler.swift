//
//  ServiceErrorHandler.swift
//  Tonic
//
//  Service error handling utilities - wraps common operations with TonicError
//

import Foundation

// MARK: - Service Error Handler Protocol

/// Protocol for services that need comprehensive error handling
public protocol ServiceErrorHandler {
    /// Transform file system errors into TonicError
    func handleFileSystemError(_ error: Error, operation: String, path: String) -> TonicError

    /// Transform network errors into TonicError
    func handleNetworkError(_ error: Error, operation: String) -> TonicError

    /// Transform permission errors into TonicError
    func handlePermissionError(_ operation: String, requiredPermission: String) -> TonicError
}

// MARK: - Default Implementations

extension ServiceErrorHandler {

    /// Wraps file operations with error handling
    func performFileOperation<T>(
        name: String,
        path: String,
        operation: () throws -> T
    ) throws -> T {
        do {
            return try operation()
        } catch let error as CocoaError {
            throw handleCocoaError(error, operation: name, path: path)
        } catch {
            throw handleFileSystemError(error, operation: name, path: path)
        }
    }

    /// Wraps async file operations with error handling
    func performFileOperationAsync<T>(
        name: String,
        path: String,
        operation: () async throws -> T
    ) async throws -> T {
        do {
            return try await operation()
        } catch let error as CocoaError {
            throw handleCocoaError(error, operation: name, path: path)
        } catch {
            throw handleFileSystemError(error, operation: name, path: path)
        }
    }

    // MARK: - Cocoa Error Handling

    private func handleCocoaError(_ error: CocoaError, operation: String, path: String) -> TonicError {
        switch error.code {
        case .fileNoSuchFile:
            return .fileMissing(path: path)

        case .fileWriteNoPermission, .fileReadNoPermission:
            return .fileAccessDenied(path: path)

        case .fileWriteInvalidFileName:
            return .invalidFilePath(path: path)

        case .fileWriteOutOfSpace:
            return .insufficientDiskSpace(required: 0, available: 0)

        default:
            return .fileOperationFailed(operation: operation, reason: error.localizedDescription)
        }
    }

    // MARK: - Filesystem Error Handling

    func handleFileSystemError(_ error: Error, operation: String, path: String) -> TonicError {
        return .fileOperationFailed(operation: operation, reason: error.localizedDescription)
    }

    // MARK: - Network Error Handling

    func handleNetworkError(_ error: Error, operation: String) -> TonicError {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut:
                return .networkTimeout(service: operation)

            case .notConnectedToInternet, .networkConnectionLost:
                return .noInternetConnection

            case .serverCertificateUntrusted, .clientCertificateRejected:
                return .invalidNetworkResponse(service: operation)

            default:
                return .networkError(underlyingError: error)
            }
        } else if let error = error as? TonicError {
            return error
        } else {
            return .networkError(underlyingError: error)
        }
    }

    // MARK: - Permission Error Handling

    func handlePermissionError(_ operation: String, requiredPermission: String) -> TonicError {
        return .permissionDenied(type: requiredPermission)
    }

    // MARK: - Scan Error Handling

    func handleScanError(_ error: Error, operation: String) -> TonicError {
        if let error = error as? TonicError {
            return error
        }

        if (error as NSError).code == NSFileReadNoPermissionError {
            return .scanPermissionDenied(path: operation)
        }

        return .scanFailed(reason: error.localizedDescription)
    }

    func handleScanTimeout(_ operation: String) -> TonicError {
        return .scanTimeout(operation: operation)
    }

    // MARK: - Clean Error Handling

    func handleCleanError(_ error: Error, path: String) -> TonicError {
        if let error = error as? TonicError {
            return error
        }

        let nsError = error as NSError

        if nsError.code == NSFileWriteNoPermissionError {
            return .fileAccessDenied(path: path)
        }

        if nsError.code == NSFileNoSuchFileError {
            return .fileMissing(path: path)
        }

        if nsError.code == NSFileWriteOutOfSpaceError {
            return .insufficientDiskSpace(required: 0, available: 0)
        }

        return .fileWriteFailed(path: path)
    }

    // MARK: - Cache Error Handling

    func handleCacheError(_ error: Error) -> TonicError {
        if let error = error as? TonicError {
            return error
        }

        return .cacheReadFailed
    }

    func handleCacheCorrupted(_ reason: String) -> TonicError {
        return .cacheCorrupted(reason: reason)
    }

    // MARK: - Data Error Handling

    func handleDecodingError(_ error: Error, dataType: String) -> TonicError {
        return .decodingFailed(dataType: dataType, reason: error.localizedDescription)
    }

    func handleEncodingError(_ dataType: String) -> TonicError {
        return .encodingFailed(dataType: dataType)
    }

    func handleInvalidDataFormat(_ dataType: String) -> TonicError {
        return .invalidDataFormat(dataType: dataType)
    }

    // MARK: - Validation Error Handling

    func handleInvalidInput(_ message: String) -> TonicError {
        return .invalidInput(message: message)
    }

    func handleEmptyInput(_ field: String) -> TonicError {
        return .emptyInput(field: field)
    }

    func handleInputTooLong(_ field: String, max: Int) -> TonicError {
        return .inputTooLong(field: field, max: max)
    }

    func handleValueOutOfRange(_ field: String, min: String, max: String) -> TonicError {
        return .valueOutOfRange(field: field, min: min, max: max)
    }

    func handleInvalidEmail(_ email: String) -> TonicError {
        return .invalidEmail(email: email)
    }

    func handleInvalidURL(_ url: String) -> TonicError {
        return .invalidURL(url: url)
    }

    // MARK: - System Error Handling

    func handleSystemCallFailed(_ call: String, errno: Int32) -> TonicError {
        return .systemCallFailed(call: call, errno: errno)
    }

    func handleOperationNotSupported(_ operation: String) -> TonicError {
        return .operationNotSupported(operation: operation)
    }

    func handleOutOfMemory() -> TonicError {
        return .outOfMemory
    }

    // MARK: - Helper Tool Error Handling

    func handleHelperToolNotInstalled() -> TonicError {
        return .helperToolNotInstalled
    }

    func handleHelperToolCommunicationFailed(_ reason: String) -> TonicError {
        return .helperToolCommunicationFailed(reason: reason)
    }

    func handleHelperToolError(_ message: String) -> TonicError {
        return .helperToolError(message: message)
    }

    func handleAuthorizationFailed() -> TonicError {
        return .authorizationFailed
    }

    // MARK: - Generic Error Handling

    func handleUnknownError(_ message: String? = nil) -> TonicError {
        return .unknown(message: message)
    }

    func handleGenericError(_ error: Error) -> TonicError {
        if let tonicError = error as? TonicError {
            return tonicError
        }
        return .generic(error)
    }
}
