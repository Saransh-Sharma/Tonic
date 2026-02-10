import Foundation
import XCTest
@testable import Tonic

final class AccessScopeModelsTests: XCTestCase {
    func testScopeBlockedReasonMessagesAreNonEmpty() {
        for reason in ScopeBlockedReason.allCases {
            XCTAssertFalse(reason.userMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    func testCoverageSummaryRoundTripState() {
        let summary = ScopeCoverageSummary(
            state: .limited,
            coveredPaths: ["/Users/test"],
            blockedPaths: ["/System": .macOSProtected]
        )

        XCTAssertEqual(summary.state, .limited)
        XCTAssertEqual(summary.coveredPaths.count, 1)
        XCTAssertEqual(summary.blockedPaths["/System"], .macOSProtected)
    }

    func testAccessScopeCodableRoundTrip() throws {
        let scope = AccessScope(
            displayName: "Home",
            rootPath: "/Users/test",
            kind: .home,
            bookmarkData: Data([0x00, 0x01])
        )

        let encoded = try JSONEncoder().encode(scope)
        let decoded = try JSONDecoder().decode(AccessScope.self, from: encoded)

        XCTAssertEqual(decoded.displayName, "Home")
        XCTAssertEqual(decoded.rootPath, "/Users/test")
        XCTAssertEqual(decoded.kind, .home)
        XCTAssertEqual(decoded.bookmarkData, Data([0x00, 0x01]))
    }

    func testAccessBrokerWithAccessScopeIDThrowsForUnknownScope() {
        XCTAssertThrowsError(try AccessBroker.shared.withAccess(scopeID: UUID()) { _ in () }) { error in
            guard case AccessBrokerError.scopeNotFound = error else {
                return XCTFail("Expected scopeNotFound, got \(error)")
            }
        }
    }

    func testAccessBrokerWithAccessForPathResolvesCanonicalPath() throws {
        let root = FileManager.default.temporaryDirectory.path
        let inputPath = root + "/../" + (root as NSString).lastPathComponent
        let resolved = try AccessBroker.shared.withAccess(forPath: inputPath) { url in
            url.path
        }
        XCTAssertEqual(resolved, ScopeResolver.shared.canonicalPath(inputPath))
    }

    func testScopedFileSystemResourceValuesAndRemoveItem() throws {
        let scopedFS = ScopedFileSystem.shared
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("tonic-scopedfs-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let fileURL = tempDirectory.appendingPathComponent("sample.txt")
        try Data("abc".utf8).write(to: fileURL)

        let values = try scopedFS.resourceValues(for: fileURL, keys: [.isDirectoryKey, .fileSizeKey])
        XCTAssertEqual(values.isDirectory, false)
        XCTAssertEqual(values.fileSize, 3)

        XCTAssertTrue(scopedFS.fileExists(atPath: fileURL.path))
        try scopedFS.removeItem(atPath: fileURL.path)
        XCTAssertFalse(scopedFS.fileExists(atPath: fileURL.path))
    }

    func testScopedFileSystemBlockedReasonMappingFromBrokerError() {
        let reason = ScopedFileSystem.shared.blockedReason(
            for: AccessBrokerError.blocked(.missingScope),
            path: "/tmp/example",
            requiresWrite: false
        )
        XCTAssertEqual(reason, .missingScope)
    }
}
