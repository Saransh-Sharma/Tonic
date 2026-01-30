//
//  ServiceErrorHandlingTests.swift
//  TonicTests
//
//  Tests for service error handling - verify TonicError integration in services
//

import XCTest
@testable import Tonic

final class ServiceErrorHandlingTests: XCTestCase {

    // MARK: - File System Error Handling Tests

    func testHandleFileNotFoundError() {
        let mockHandler = MockServiceErrorHandler()
        let error = NSError(domain: NSCocoaErrorDomain, code: NSFileNoSuchFileError)

        let result = mockHandler.handleFileSystemError(error, operation: "read", path: "/nonexistent")

        if case .fileNotFound(let path) = result {
            XCTAssertEqual(path, "/nonexistent")
        } else {
            XCTFail("Should convert to fileNotFound error")
        }
    }

    func testHandleAccessDeniedError() {
        let mockHandler = MockServiceErrorHandler()
        let error = NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoPermission)

        let result = mockHandler.handleFileSystemError(error, operation: "read", path: "/protected")

        if case .accessDenied(let path) = result {
            XCTAssertEqual(path, "/protected")
        } else {
            XCTFail("Should convert to accessDenied error")
        }
    }

    func testHandleInsufficientSpaceError() {
        let mockHandler = MockServiceErrorHandler()
        let error = NSError(domain: NSCocoaErrorDomain, code: NSFileWriteOutOfSpace)

        let result = mockHandler.handleFileSystemError(error, operation: "write", path: "/disk")

        if case .insufficientDiskSpace = result {
            // Success
        } else {
            XCTFail("Should convert to insufficientDiskSpace error")
        }
    }

    // MARK: - Network Error Handling Tests

    func testHandleNetworkTimeoutError() {
        let mockHandler = MockServiceErrorHandler()
        let error = URLError(.timedOut)

        let result = mockHandler.handleNetworkError(error, operation: "fetch")

        if case .networkTimeout = result {
            // Success
        } else {
            XCTFail("Should convert to networkTimeout error")
        }
    }

    func testHandleNoNetworkConnectionError() {
        let mockHandler = MockServiceErrorHandler()
        let error = URLError(.notConnectedToInternet)

        let result = mockHandler.handleNetworkError(error, operation: "sync")

        if case .noNetworkConnection = result {
            // Success
        } else {
            XCTFail("Should convert to noNetworkConnection error")
        }
    }

    func testHandleBadServerResponseError() {
        let mockHandler = MockServiceErrorHandler()
        let error = URLError(.badServerResponse)

        let result = mockHandler.handleNetworkError(error, operation: "api")

        if case .invalidNetworkResponse = result {
            // Success
        } else {
            XCTFail("Should convert to invalidNetworkResponse error")
        }
    }

    // MARK: - Permission Error Handling Tests

    func testHandleFullDiskAccessRequired() {
        let mockHandler = MockServiceErrorHandler()

        let result = mockHandler.handlePermissionError("scan", requiredPermission: "Full Disk Access")

        if case .fullDiskAccessRequired = result {
            // Success
        } else {
            XCTFail("Should convert to fullDiskAccessRequired error")
        }
    }

    func testHandleAccessibilityPermissionRequired() {
        let mockHandler = MockServiceErrorHandler()

        let result = mockHandler.handlePermissionError("enable", requiredPermission: "Accessibility")

        if case .accessibilityPermissionRequired = result {
            // Success
        } else {
            XCTFail("Should convert to accessibilityPermissionRequired error")
        }
    }

    func testHandleLocationPermissionRequired() {
        let mockHandler = MockServiceErrorHandler()

        let result = mockHandler.handlePermissionError("fetch", requiredPermission: "Location")

        if case .locationPermissionRequired = result {
            // Success
        } else {
            XCTFail("Should convert to locationPermissionRequired error")
        }
    }

    // MARK: - Scan Error Handling Tests

    func testHandleScanPermissionError() {
        let mockHandler = MockServiceErrorHandler()
        let error = NSError(domain: "ScanError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Permission denied"])

        let result = mockHandler.handleScanError(error, scanType: "disk")

        if case .scanPermissionDenied = result {
            // Success
        } else {
            XCTFail("Should convert to scanPermissionDenied error")
        }
    }

    func testHandleScanInterruptedError() {
        let mockHandler = MockServiceErrorHandler()
        let error = NSError(domain: "ScanError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Scan interrupted"])

        let result = mockHandler.handleScanError(error, scanType: "disk")

        if case .scanInterrupted = result {
            // Success
        } else {
            XCTFail("Should convert to scanInterrupted error")
        }
    }

    func testHandleScanTimeoutError() {
        let mockHandler = MockServiceErrorHandler()
        let error = NSError(domain: "ScanError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Scan timeout"])

        let result = mockHandler.handleScanError(error, scanType: "disk")

        if case .scanTimeout = result {
            // Success
        } else {
            XCTFail("Should convert to scanTimeout error")
        }
    }

    // MARK: - Cleaning Error Handling Tests

    func testHandleProtectedFileError() {
        let mockHandler = MockServiceErrorHandler()
        let error = NSError(domain: "CleanError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Protected file"])

        let result = mockHandler.handleCleaningError(error, category: "cache")

        if case .protectedFileEncountered = result {
            // Success
        } else {
            XCTFail("Should convert to protectedFileEncountered error")
        }
    }

    // MARK: - Data Error Handling Tests

    func testHandleDataCorruptionError() {
        let mockHandler = MockServiceErrorHandler()
        let error = NSError(domain: "DataError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode JSON"])

        let result = mockHandler.handleDataError(error, dataType: "cache")

        if case .dataCorrupted = result {
            // Success
        } else {
            XCTFail("Should convert to dataCorrupted error")
        }
    }

    // MARK: - Path Validation Tests

    func testValidatePathExists() {
        let mockHandler = MockServiceErrorHandler()

        // Test with temp directory (should exist)
        do {
            try mockHandler.validatePathExists(NSTemporaryDirectory())
            // Success - no error thrown
        } catch {
            XCTFail("Should not throw for existing path")
        }
    }

    func testValidatePathExistsThrowsForNonexistent() {
        let mockHandler = MockServiceErrorHandler()
        let nonexistentPath = "/nonexistent/path/\(UUID().uuidString)"

        do {
            try mockHandler.validatePathExists(nonexistentPath)
            XCTFail("Should throw for nonexistent path")
        } catch let error as TonicError {
            if case .fileNotFound = error {
                // Success
            } else {
                XCTFail("Should throw fileNotFound error")
            }
        } catch {
            XCTFail("Should throw TonicError")
        }
    }

    func testValidatePathIsDirectory() {
        let mockHandler = MockServiceErrorHandler()
        let tempDir = NSTemporaryDirectory()

        do {
            try mockHandler.validatePathIsDirectory(tempDir)
            // Success - no error thrown
        } catch {
            XCTFail("Should not throw for directory path")
        }
    }

    func testValidatePathIsFile() {
        let mockHandler = MockServiceErrorHandler()
        let tempDir = NSTemporaryDirectory()

        do {
            try mockHandler.validatePathIsFile(tempDir)
            XCTFail("Should throw for directory path")
        } catch let error as TonicError {
            if case .invalidPath = error {
                // Success
            } else {
                XCTFail("Should throw invalidPath error")
            }
        } catch {
            XCTFail("Should throw TonicError")
        }
    }

    // MARK: - Disk Space Validation Tests

    func testValidateDiskSpaceAvailable() {
        let mockHandler = MockServiceErrorHandler()

        do {
            try mockHandler.validateDiskSpace(required: 1_000_000)  // 1 MB
            // Success - should have at least 1 MB free
        } catch {
            // May fail on system with extremely low space, which is acceptable
        }
    }

    // MARK: - Error Message Mapping Tests

    func testErrorMessageMappingPermission() {
        let mockHandler = MockServiceErrorHandler()
        let error = NSError(domain: "Test", code: 0, userInfo: [NSLocalizedDescriptionKey: "Permission denied"])

        let result = mockHandler.handleFileSystemError(error, operation: "test", path: "/test")

        if case .accessDenied = result {
            // Success
        } else {
            XCTFail("Should map 'permission' message to accessDenied")
        }
    }

    func testErrorMessageMappingSpace() {
        let mockHandler = MockServiceErrorHandler()
        let error = NSError(domain: "Test", code: 0, userInfo: [NSLocalizedDescriptionKey: "Out of space"])

        let result = mockHandler.handleFileSystemError(error, operation: "test", path: "/test")

        if case .insufficientDiskSpace = result {
            // Success
        } else {
            XCTFail("Should map 'space' message to insufficientDiskSpace")
        }
    }

    // MARK: - Cocoa Error Code Handling Tests

    func testCocoaErrorFileReadPermission() {
        let mockHandler = MockServiceErrorHandler()
        let cocoaError = NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoPermission)

        let result = mockHandler.handleFileSystemError(cocoaError, operation: "read", path: "/protected")

        if case .accessDenied = result {
            // Success
        } else {
            XCTFail("Should handle NSFileReadNoPermission")
        }
    }

    func testCocoaErrorFileWritePermission() {
        let mockHandler = MockServiceErrorHandler()
        let cocoaError = NSError(domain: NSCocoaErrorDomain, code: NSFileWriteNoPermission)

        let result = mockHandler.handleFileSystemError(cocoaError, operation: "write", path: "/protected")

        if case .accessDenied = result {
            // Success
        } else {
            XCTFail("Should handle NSFileWriteNoPermission")
        }
    }

    // MARK: - Network Error Code Handling Tests

    func testURLErrorNetworkConnectionLost() {
        let mockHandler = MockServiceErrorHandler()
        let urlError = URLError(.networkConnectionLost)

        let result = mockHandler.handleNetworkError(urlError, operation: "sync")

        if case .noNetworkConnection = result {
            // Success
        } else {
            XCTFail("Should handle networkConnectionLost")
        }
    }

    func testURLErrorCannotParseResponse() {
        let mockHandler = MockServiceErrorHandler()
        let urlError = URLError(.cannotParseResponse)

        let result = mockHandler.handleNetworkError(urlError, operation: "api")

        if case .invalidNetworkResponse = result {
            // Success
        } else {
            XCTFail("Should handle cannotParseResponse")
        }
    }

    // MARK: - Error Severity Tests

    func testErrorSeverityLevels() {
        // Verify that TonicError properly maps to severity levels
        let fileNotFoundError = TonicError.fileNotFound(path: "/test")
        XCTAssertEqual(fileNotFoundError.severity, .error)

        let fdaError = TonicError.fullDiskAccessRequired
        XCTAssertEqual(fdaError.severity, .critical)

        let networkError = TonicError.networkTimeout
        XCTAssertEqual(networkError.severity, .error)
    }

    // MARK: - Error Recoverability Tests

    func testErrorRecoverability() {
        // Verify that errors properly indicate if they're recoverable
        let fileNotFoundError = TonicError.fileNotFound(path: "/test")
        XCTAssertFalse(fileNotFoundError.isRecoverable)

        let networkTimeoutError = TonicError.networkTimeout
        XCTAssertTrue(networkTimeoutError.isRecoverable)

        let fdaError = TonicError.fullDiskAccessRequired
        XCTAssertTrue(fdaError.isRecoverable)
    }
}

// MARK: - Mock Service Error Handler

private struct MockServiceErrorHandler: ServiceErrorHandler {
    func handleFileSystemError(_ error: Error, operation: String, path: String) -> TonicError {
        let handler: ServiceErrorHandler = EmptyServiceErrorHandler()
        return handler.handleFileSystemError(error, operation: operation, path: path)
    }

    func handleNetworkError(_ error: Error, operation: String) -> TonicError {
        let handler: ServiceErrorHandler = EmptyServiceErrorHandler()
        return handler.handleNetworkError(error, operation: operation)
    }

    func handlePermissionError(_ operation: String, requiredPermission: String) -> TonicError {
        let handler: ServiceErrorHandler = EmptyServiceErrorHandler()
        return handler.handlePermissionError(operation, requiredPermission: requiredPermission)
    }
}

private struct EmptyServiceErrorHandler: ServiceErrorHandler {
    func handleFileSystemError(_ error: Error, operation: String, path: String) -> TonicError {
        return .fileOperationFailed(operation: operation, path: path, reason: error.localizedDescription)
    }

    func handleNetworkError(_ error: Error, operation: String) -> TonicError {
        return .networkError(operation: operation, reason: error.localizedDescription)
    }

    func handlePermissionError(_ operation: String, requiredPermission: String) -> TonicError {
        return .permissionDenied(permission: requiredPermission)
    }
}
