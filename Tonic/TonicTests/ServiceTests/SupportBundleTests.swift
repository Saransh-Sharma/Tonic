import XCTest
@testable import Tonic

final class SupportBundleTests: XCTestCase {
    func testRedactionRemovesSensitiveValues() {
        let home = NSHomeDirectory()
        let input = "token=abc123 mail me@example.com file \(home)/Private.txt https://user:pass@example.com/private?q=1"
        let value = SupportBundleRedactor.redact(input)
        XCTAssertFalse(value.contains("abc123"))
        XCTAssertFalse(value.contains("me@example.com"))
        XCTAssertFalse(value.contains(home))
        XCTAssertFalse(value.contains("user:pass"))
        XCTAssertFalse(value.contains("private?q=1"))
    }

    func testBuilderExcludesSensitiveDictionaryCategories() async {
        let builder = SupportBundleBuilder(receipts: { [["clipboard": "secret", "detail": "/Users/alice/item"]] })
        let payload = await builder.build(categories: [.receipts])
        XCTAssertEqual(payload.receipts?.first?["clipboard"], "[EXCLUDED]")
        XCTAssertFalse(payload.receipts?.first?["detail"]?.contains("alice") == true)
    }

    func testRedactionRemovesJWTsAndCommandArgumentsFromLogs() {
        let value = SupportBundleRedactor.redact(
            "command: /bin/tool --token value\njwt eyJhbGciOiJIUzI1NiJ9.cGF5bG9hZA.c2lnbmF0dXJl"
        )
        XCTAssertFalse(value.contains("/bin/tool"))
        XCTAssertFalse(value.contains("eyJhbGci"))
        XCTAssertTrue(value.contains("[EXCLUDED]"))
        XCTAssertTrue(value.contains("[TOKEN]"))
    }

    func testArchiveContainsOnlySelectedReviewableCategories() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SupportBundleTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let archive = root.appendingPathComponent("support.zip")
        let builder = SupportBundleBuilder(receipts: { [["detail": "safe"]] }, logs: { ["safe log"] })
        let payload = await builder.build(categories: [.receipts])

        try await builder.writeArchive(payload, to: archive)

        let listing = try String(contentsOf: archiveListing(archive), encoding: .utf8)
        XCTAssertTrue(listing.contains("manifest.json"))
        XCTAssertTrue(listing.contains("receipts.json"))
        XCTAssertTrue(listing.contains("README.txt"))
        XCTAssertFalse(listing.contains("logs.txt"))
        XCTAssertFalse(listing.contains("application.json"))
    }

    private func archiveListing(_ archive: URL) throws -> URL {
        let output = archive.deletingLastPathComponent().appendingPathComponent("listing.txt")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-Z1", archive.path]
        let handle = try FileHandle(forWritingTo: output, createIfNeeded: true)
        defer { try? handle.close() }
        process.standardOutput = handle
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)
        return output
    }
}

private extension FileHandle {
    convenience init(forWritingTo url: URL, createIfNeeded: Bool) throws {
        if createIfNeeded { FileManager.default.createFile(atPath: url.path, contents: nil) }
        try self.init(forWritingTo: url)
    }
}
