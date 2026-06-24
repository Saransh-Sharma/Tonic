import Foundation
import XCTest
@testable import Tonic

/// Tests the destructive primitives used by Smart Care cleanup: permanent
/// deletion (system junk) and Trash routing (personal files).
final class FileOperationsTests: XCTestCase {

    private var tempRoot: URL!

    override func setUpWithError() throws {
        tempRoot = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("FileOpsTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    @discardableResult
    private func makeFile(_ name: String, bytes: Int) throws -> String {
        let url = tempRoot.appendingPathComponent(name)
        try Data(repeating: 0x41, count: bytes).write(to: url)
        return url.path
    }

    func testDeleteFilesPermanentlyRemovesAndAccountsBytes() async throws {
        let a = try makeFile("a.bin", bytes: 100)
        let b = try makeFile("b.bin", bytes: 250)

        let result = await FileOperations.shared.deleteFiles(atPaths: [a, b])

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.filesProcessed, 2)
        XCTAssertEqual(result.bytesFreed, 350)
        XCTAssertTrue(result.errors.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: a))
        XCTAssertFalse(FileManager.default.fileExists(atPath: b))
        // Permanent deletion does not populate the Trash map.
        XCTAssertTrue(result.trashMap.isEmpty)
    }

    func testDeleteFilesReportsErrorForMissingPath() async throws {
        let missing = tempRoot.appendingPathComponent("ghost.bin").path

        let result = await FileOperations.shared.deleteFiles(atPaths: [missing])

        XCTAssertEqual(result.filesProcessed, 0)
        XCTAssertEqual(result.bytesFreed, 0)
        XCTAssertEqual(result.errors.count, 1)
        XCTAssertEqual(result.errors.first?.path, missing)
    }

    func testMoveFilesToTrashReturnsTrashMapAndRemovesOriginal() async throws {
        let path = try makeFile("personal.txt", bytes: 42)

        let result = await FileOperations.shared.moveFilesToTrash(atPaths: [path])

        XCTAssertEqual(result.filesProcessed, 1)
        XCTAssertEqual(result.bytesFreed, 42)
        // Original is gone; a recoverable Trash URL is reported for restore.
        XCTAssertFalse(FileManager.default.fileExists(atPath: path))
        let trashPath = try XCTUnwrap(result.trashMap[path], "Expected a Trash URL for the moved file")
        XCTAssertTrue(FileManager.default.fileExists(atPath: trashPath))

        // Clean up the item we placed in the user's Trash.
        try? FileManager.default.removeItem(atPath: trashPath)
    }
}
