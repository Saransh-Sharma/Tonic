//
//  ServiceErrorHandlingTests.swift
//  TonicTests
//
//  Validates ServiceErrorHandler default mappings to TonicError.
//

import Foundation
import XCTest
@testable import Tonic

final class ServiceErrorHandlingTests: XCTestCase {
    private let handler = TestServiceErrorHandler()

    // MARK: - File System Mappings

    func testPerformFileOperationMapsMissingFile() {
        XCTAssertThrowsError(
            try handler.performFileOperation(name: "read", path: "/missing/path") {
                throw CocoaError(.fileNoSuchFile)
            }
        ) { error in
            guard let tonicError = error as? TonicError else {
                XCTFail("Expected TonicError")
                return
            }
            guard case .fileMissing(let path) = tonicError else {
                XCTFail("Expected .fileMissing, got \(tonicError)")
                return
            }
            XCTAssertEqual(path, "/missing/path")
        }
    }

    func testPerformFileOperationMapsReadPermissionDenied() {
        XCTAssertThrowsError(
            try handler.performFileOperation(name: "read", path: "/protected/path") {
                throw CocoaError(.fileReadNoPermission)
            }
        ) { error in
            guard let tonicError = error as? TonicError else {
                XCTFail("Expected TonicError")
                return
            }
            guard case .fileAccessDenied(let path) = tonicError else {
                XCTFail("Expected .fileAccessDenied, got \(tonicError)")
                return
            }
            XCTAssertEqual(path, "/protected/path")
        }
    }

    func testPerformFileOperationMapsOutOfSpace() {
        XCTAssertThrowsError(
            try handler.performFileOperation(name: "write", path: "/disk/path") {
                throw CocoaError(.fileWriteOutOfSpace)
            }
        ) { error in
            guard let tonicError = error as? TonicError else {
                XCTFail("Expected TonicError")
                return
            }
            guard case .insufficientDiskSpace(let required, let available) = tonicError else {
                XCTFail("Expected .insufficientDiskSpace, got \(tonicError)")
                return
            }
            XCTAssertEqual(required, 0)
            XCTAssertEqual(available, 0)
        }
    }

    func testHandleFileSystemErrorFallsBackToFileOperationFailed() {
        struct SampleError: LocalizedError {
            var errorDescription: String? { "sample failure" }
        }

        let result = handler.handleFileSystemError(
            SampleError(),
            operation: "enumerate",
            path: "/tmp/test"
        )

        guard case .fileOperationFailed(let operation, let reason) = result else {
            XCTFail("Expected .fileOperationFailed, got \(result)")
            return
        }

        XCTAssertEqual(operation, "enumerate")
        XCTAssertEqual(reason, "sample failure")
    }

    // MARK: - Async Wrappers

    func testPerformFileOperationAsyncMapsCocoaErrors() async {
        await XCTAssertThrowsErrorAsync(
            try await handler.performFileOperationAsync(name: "read", path: "/async/missing") {
                throw CocoaError(.fileNoSuchFile)
            }
        ) { error in
            guard let tonicError = error as? TonicError else {
                XCTFail("Expected TonicError")
                return
            }
            guard case .fileMissing(let path) = tonicError else {
                XCTFail("Expected .fileMissing, got \(tonicError)")
                return
            }
            XCTAssertEqual(path, "/async/missing")
        }
    }

    // MARK: - Network Mappings

    func testHandleNetworkTimeout() {
        let result = handler.handleNetworkError(URLError(.timedOut), operation: "sync")

        guard case .networkTimeout(let service) = result else {
            XCTFail("Expected .networkTimeout, got \(result)")
            return
        }
        XCTAssertEqual(service, "sync")
    }

    func testHandleNoInternetConnection() {
        let result = handler.handleNetworkError(URLError(.notConnectedToInternet), operation: "sync")

        guard case .noInternetConnection = result else {
            XCTFail("Expected .noInternetConnection, got \(result)")
            return
        }
    }

    func testHandleInvalidNetworkResponse() {
        let result = handler.handleNetworkError(URLError(.serverCertificateUntrusted), operation: "api")

        guard case .invalidNetworkResponse(let service) = result else {
            XCTFail("Expected .invalidNetworkResponse, got \(result)")
            return
        }
        XCTAssertEqual(service, "api")
    }

    func testHandleNetworkErrorPassthroughForTonicError() {
        let tonicError = TonicError.noInternetConnection
        let result = handler.handleNetworkError(tonicError, operation: "api")

        guard case .noInternetConnection = result else {
            XCTFail("Expected passthrough TonicError, got \(result)")
            return
        }
    }

    // MARK: - Permission + Scan Mappings

    func testHandlePermissionErrorMapsType() {
        let result = handler.handlePermissionError("scan", requiredPermission: "Full Disk Access")

        guard case .permissionDenied(let type) = result else {
            XCTFail("Expected .permissionDenied, got \(result)")
            return
        }
        XCTAssertEqual(type, "Full Disk Access")
    }

    func testHandleScanErrorPermissionDenied() {
        let error = NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoPermissionError)
        let result = handler.handleScanError(error, operation: "/Users/test/Library")

        guard case .scanPermissionDenied(let path) = result else {
            XCTFail("Expected .scanPermissionDenied, got \(result)")
            return
        }
        XCTAssertEqual(path, "/Users/test/Library")
    }

    func testHandleScanErrorDefaultsToScanFailed() {
        let error = NSError(domain: "ScanError", code: 1001, userInfo: [NSLocalizedDescriptionKey: "scan failed"])
        let result = handler.handleScanError(error, operation: "disk")

        guard case .scanFailed(let reason) = result else {
            XCTFail("Expected .scanFailed, got \(result)")
            return
        }
        XCTAssertTrue(reason.contains("scan failed"))
    }

    func testHandleScanTimeoutIncludesOperation() {
        let result = handler.handleScanTimeout("deep scan")
        guard case .scanTimeout(let operation) = result else {
            XCTFail("Expected .scanTimeout, got \(result)")
            return
        }
        XCTAssertEqual(operation, "deep scan")
    }

    // MARK: - Clean + Data Mappings

    func testHandleCleanErrorMapsFileAccessDenied() {
        let error = NSError(domain: NSCocoaErrorDomain, code: NSFileWriteNoPermissionError)
        let result = handler.handleCleanError(error, path: "/protected/file")

        guard case .fileAccessDenied(let path) = result else {
            XCTFail("Expected .fileAccessDenied, got \(result)")
            return
        }
        XCTAssertEqual(path, "/protected/file")
    }

    func testHandleCleanErrorMapsFileMissing() {
        let error = NSError(domain: NSCocoaErrorDomain, code: NSFileNoSuchFileError)
        let result = handler.handleCleanError(error, path: "/missing/file")

        guard case .fileMissing(let path) = result else {
            XCTFail("Expected .fileMissing, got \(result)")
            return
        }
        XCTAssertEqual(path, "/missing/file")
    }

    func testHandleCleanErrorMapsOutOfSpace() {
        let error = NSError(domain: NSCocoaErrorDomain, code: NSFileWriteOutOfSpaceError)
        let result = handler.handleCleanError(error, path: "/tmp/file")

        guard case .insufficientDiskSpace(let required, let available) = result else {
            XCTFail("Expected .insufficientDiskSpace, got \(result)")
            return
        }
        XCTAssertEqual(required, 0)
        XCTAssertEqual(available, 0)
    }

    func testHandleCleanErrorDefaultsToFileWriteFailed() {
        let error = NSError(domain: "CleanError", code: 999, userInfo: nil)
        let result = handler.handleCleanError(error, path: "/tmp/file")

        guard case .fileWriteFailed(let path) = result else {
            XCTFail("Expected .fileWriteFailed, got \(result)")
            return
        }
        XCTAssertEqual(path, "/tmp/file")
    }

    func testHandleDecodingErrorIncludesTypeAndReason() {
        struct SampleDecodeError: LocalizedError {
            var errorDescription: String? { "bad json" }
        }

        let result = handler.handleDecodingError(SampleDecodeError(), dataType: "ScopeState")

        guard case .decodingFailed(let dataType, let reason) = result else {
            XCTFail("Expected .decodingFailed, got \(result)")
            return
        }
        XCTAssertEqual(dataType, "ScopeState")
        XCTAssertEqual(reason, "bad json")
    }

    func testHandleEncodingAndInvalidFormat() {
        let encoding = handler.handleEncodingError("ScopeState")
        guard case .encodingFailed(let dataType) = encoding else {
            XCTFail("Expected .encodingFailed, got \(encoding)")
            return
        }
        XCTAssertEqual(dataType, "ScopeState")

        let invalid = handler.handleInvalidDataFormat("ScopeState")
        guard case .invalidDataFormat(let dataType) = invalid else {
            XCTFail("Expected .invalidDataFormat, got \(invalid)")
            return
        }
        XCTAssertEqual(dataType, "ScopeState")
    }

    // MARK: - Generic + Error Traits

    func testHandleGenericErrorPassthroughAndWrap() {
        let tonic = TonicError.fileMissing(path: "/tmp/missing")
        let passthrough = handler.handleGenericError(tonic)
        guard case .fileMissing(let path) = passthrough else {
            XCTFail("Expected passthrough TonicError, got \(passthrough)")
            return
        }
        XCTAssertEqual(path, "/tmp/missing")

        struct OtherError: Error {}
        let wrapped = handler.handleGenericError(OtherError())
        guard case .generic = wrapped else {
            XCTFail("Expected .generic, got \(wrapped)")
            return
        }
    }

    func testSeverityAndRecoverability() {
        XCTAssertEqual(TonicError.permissionDenied(type: "Full Disk Access").severity, .warning)
        XCTAssertEqual(TonicError.fileAccessDenied(path: "/tmp/file").severity, .error)
        XCTAssertEqual(TonicError.networkTimeout(service: "sync").severity, .info)
        XCTAssertEqual(TonicError.outOfMemory.severity, .critical)

        XCTAssertTrue(TonicError.permissionDenied(type: "Full Disk Access").isRecoverable)
        XCTAssertTrue(TonicError.networkTimeout(service: "sync").isRecoverable)
        XCTAssertFalse(TonicError.outOfMemory.isRecoverable)
    }
}

private struct TestServiceErrorHandler: ServiceErrorHandler {}

private extension XCTestCase {
    func XCTAssertThrowsErrorAsync<T>(
        _ expression: @autoclosure () async throws -> T,
        _ errorHandler: (Error) -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await expression()
            XCTFail("Expected error to be thrown", file: file, line: line)
        } catch {
            errorHandler(error)
        }
    }
}
