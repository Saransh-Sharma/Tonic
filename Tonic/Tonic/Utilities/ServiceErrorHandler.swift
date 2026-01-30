//
//  ServiceErrorHandler.swift
//  Tonic
//
//  Service error handling utilities - wraps common operations with TonicError
//

import Foundation

// MARK: - Service Error Handler Protocol

/// Protocol for services that need comprehensive error handling
protocol ServiceErrorHandler {
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
            return .fileNotFound(path: path)

        case .fileWriteNoPermission, .fileReadNoPermission:
            return .accessDenied(path: path)

        case .fileWriteInvalidFileName:
            return .invalidPath(path: path)

        case .fileWriteOutOfSpace:
            return .insufficientDiskSpace(required: 0, available: 0)

        default:
            return .fileOperationFailed(operation: operation, path: path, reason: error.localizedDescription)
        }
    }

    // MARK: - Filesystem Error Handling

    func handleFileSystemError(_ error: Error, operation: String, path: String) -> TonicError {
        let errorMessage = error.localizedDescription

        if errorMessage.lowercased().contains("permission") {
            return .accessDenied(path: path)
        } else if errorMessage.lowercased().contains("no such file") {
            return .fileNotFound(path: path)
        } else if errorMessage.lowercased().contains("space") {
            return .insufficientDiskSpace(required: 0, available: 0)
        } else {
            return .fileOperationFailed(operation: operation, path: path, reason: errorMessage)
        }
    }

    // MARK: - Network Error Handling

    func handleNetworkError(_ error: Error, operation: String) -> TonicError {
        if let urlError = error as? URLError {
            return handleURLError(urlError, operation: operation)
        }

        let errorMessage = error.localizedDescription

        if errorMessage.lowercased().contains("timeout") {
            return .networkTimeout
        } else if errorMessage.lowercased().contains("no connection") {
            return .noNetworkConnection
        } else {
            return .networkError(operation: operation, reason: errorMessage)
        }
    }

    private func handleURLError(_ error: URLError, operation: String) -> TonicError {
        switch error.code {
        case .timedOut:
            return .networkTimeout

        case .notConnectedToInternet:
            return .noNetworkConnection

        case .networkConnectionLost:
            return .noNetworkConnection

        case .cannotParseResponse:
            return .invalidNetworkResponse(operation: operation)

        case .badServerResponse:
            return .serverError(statusCode: 500, operation: operation)

        default:
            return .networkError(operation: operation, reason: error.localizedDescription)
        }
    }

    // MARK: - Permission Error Handling

    func handlePermissionError(_ operation: String, requiredPermission: String) -> TonicError {
        switch requiredPermission.lowercased() {
        case "fda", "full disk access":
            return .fullDiskAccessRequired

        case "accessibility":
            return .accessibilityPermissionRequired

        case "location":
            return .locationPermissionRequired

        case "notifications":
            return .notificationPermissionRequired

        default:
            return .permissionDenied(permission: requiredPermission)
        }
    }

    // MARK: - Validation Error Handling

    func validatePathExists(_ path: String) throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: path) else {
            throw TonicError.fileNotFound(path: path)
        }
    }

    func validatePathIsDirectory(_ path: String) throws {
        let fileManager = FileManager.default
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else {
            throw TonicError.invalidPath(path: path)
        }
    }

    func validatePathIsFile(_ path: String) throws {
        let fileManager = FileManager.default
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDir), !isDir.boolValue else {
            throw TonicError.invalidPath(path: path)
        }
    }

    func validateDiskSpace(required: Int64) throws {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser

        if let availableSpace = try? fileManager.attributesOfFileSystem(forPath: home.path)[.systemFreeSize] as? Int64 {
            guard availableSpace >= required else {
                throw TonicError.insufficientDiskSpace(required: required, available: availableSpace)
            }
        }
    }
}

// MARK: - Scan Error Handler

extension ServiceErrorHandler {

    /// Handles scan-specific errors
    func handleScanError(_ error: Error, scanType: String) -> TonicError {
        let errorMessage = error.localizedDescription

        if errorMessage.lowercased().contains("permission") {
            return .scanPermissionDenied
        } else if errorMessage.lowercased().contains("interrupted") {
            return .scanInterrupted
        } else if errorMessage.lowercased().contains("timeout") {
            return .scanTimeout
        } else {
            return .scanFailed(reason: errorMessage)
        }
    }

    /// Validates scan can start
    func validateScanStarting() throws {
        // Check for required permissions
        let permissionManager = PermissionManager.shared

        guard permissionManager.hasFullDiskAccess() else {
            throw TonicError.fullDiskAccessRequired
        }
    }
}

// MARK: - Cleaning Error Handler

extension ServiceErrorHandler {

    /// Handles cleaning operation errors
    func handleCleaningError(_ error: Error, category: String) -> TonicError {
        let errorMessage = error.localizedDescription

        if errorMessage.lowercased().contains("protected") {
            return .protectedFileEncountered(path: category)
        } else if errorMessage.lowercased().contains("permission") {
            return .accessDenied(path: category)
        } else {
            return .cleaningFailed(category: category, reason: errorMessage)
        }
    }
}

// MARK: - Data Cache Error Handler

extension ServiceErrorHandler {

    /// Handles data loading/caching errors
    func handleDataError(_ error: Error, dataType: String) -> TonicError {
        let errorMessage = error.localizedDescription

        if errorMessage.lowercased().contains("decode") {
            return .dataCorrupted(type: dataType, reason: errorMessage)
        } else if errorMessage.lowercased().contains("encode") {
            return .cachingFailed(reason: errorMessage)
        } else if errorMessage.lowercased().contains("not found") {
            return .dataNotFound(type: dataType)
        } else {
            return .dataProcessingFailed(type: dataType, reason: errorMessage)
        }
    }
}

// MARK: - Async Operation Error Handler

/// Helper for wrapping async operations with error handling
struct AsyncOperationWithErrorHandling<T> {
    let operation: () async throws -> T
    let errorHandler: (Error) -> TonicError

    func execute() async throws -> T {
        do {
            return try await operation()
        } catch let error as TonicError {
            throw error
        } catch {
            throw errorHandler(error)
        }
    }
}

// MARK: - Result Wrapping

/// Helper for operations that should return Result<T, TonicError>
func withErrorHandling<T>(
    operation: @escaping () throws -> T,
    errorHandler: @escaping (Error) -> TonicError
) -> Result<T, TonicError> {
    do {
        return .success(try operation())
    } catch let error as TonicError {
        return .failure(error)
    } catch {
        return .failure(errorHandler(error))
    }
}

/// Helper for async operations that should return Result<T, TonicError>
func withAsyncErrorHandling<T>(
    operation: @escaping () async throws -> T,
    errorHandler: @escaping (Error) -> TonicError
) async -> Result<T, TonicError> {
    do {
        return .success(try await operation())
    } catch let error as TonicError {
        return .failure(error)
    } catch {
        return .failure(errorHandler(error))
    }
}
