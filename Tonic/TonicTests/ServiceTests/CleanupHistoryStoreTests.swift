import Foundation
import XCTest
@testable import Tonic

/// Tests the recovery ledger that backs Undo and the Recently Cleaned screen.
final class CleanupHistoryStoreTests: XCTestCase {

    private var tempRoot: URL!
    private var store: CleanupHistoryStore!

    override func setUpWithError() throws {
        tempRoot = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("CleanupHistoryTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        store = CleanupHistoryStore(storageDirectory: tempRoot.appendingPathComponent("store"))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    /// Simulates a file that has been moved to the Trash: returns (originalPath, trashPath)
    /// where a real file exists at trashPath and nothing exists at originalPath.
    private func makeTrashedFile(name: String, contents: String = "data") throws -> (original: String, trash: String) {
        let original = tempRoot.appendingPathComponent("home/\(name)")
        let trash = tempRoot.appendingPathComponent("trash/\(name)")
        try FileManager.default.createDirectory(at: trash.deletingLastPathComponent(), withIntermediateDirectories: true)
        try contents.data(using: .utf8)!.write(to: trash)
        return (original.path, trash.path)
    }

    func testRecordIgnoresEmptyEntries() {
        XCTAssertNil(store.record(title: "Smart Clean", entries: []))
        XCTAssertTrue(store.batches.isEmpty)
    }

    func testRecordAndRestoreTrashedItemRoundTrip() async throws {
        let file = try makeTrashedFile(name: "movie.mov", contents: "movie-bytes")
        let entry = CleanupHistoryEntry(
            originalPath: file.original,
            size: 11,
            category: "Large & Old Files",
            recovery: .trashed(trashPath: file.trash)
        )
        let batch = try XCTUnwrap(store.record(title: "Smart Clean", entries: [entry]))

        // Precondition: trashed file present, original absent.
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.trash))
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.original))

        let result = await store.restoreBatch(batch.id)

        XCTAssertEqual(result.restored, 1)
        XCTAssertEqual(result.failed, 0)
        XCTAssertEqual(result.restoredBytes, 11)
        // File moved back to its original location, removed from Trash.
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.original))
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.trash))
        // Entry is marked restored and no longer restorable.
        let stored = try XCTUnwrap(store.batches.first?.entries.first)
        XCTAssertNotNil(stored.restoredDate)
        XCTAssertFalse(stored.isRestorable)
    }

    func testPermanentEntriesAreNotRestorable() async throws {
        let entry = CleanupHistoryEntry(
            originalPath: "/private/var/folders/cache.bin",
            size: 1024,
            category: "System Junk",
            recovery: .permanent
        )
        let batch = try XCTUnwrap(store.record(title: "Smart Clean", entries: [entry]))

        XCTAssertFalse(batch.hasRecoverable)
        let result = await store.restoreBatch(batch.id)
        XCTAssertEqual(result.restored, 0)
    }

    func testRestoreDoesNotClobberRecreatedOriginal() async throws {
        let file = try makeTrashedFile(name: "report.pdf")
        // User has recreated a file at the original path since the cleanup.
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: file.original).deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try "new".data(using: .utf8)!.write(to: URL(fileURLWithPath: file.original))

        let entry = CleanupHistoryEntry(
            originalPath: file.original,
            size: 4,
            category: "Downloads",
            recovery: .trashed(trashPath: file.trash)
        )
        let batch = try XCTUnwrap(store.record(title: "Smart Clean", entries: [entry]))

        let result = await store.restoreBatch(batch.id)
        XCTAssertEqual(result.restored, 0)
        XCTAssertEqual(result.failed, 1)
        // The recreated original is left untouched.
        XCTAssertEqual(try String(contentsOfFile: file.original, encoding: .utf8), "new")
    }

    func testPruneDemotesEntriesWhoseTrashItemIsGone() async throws {
        let file = try makeTrashedFile(name: "clip.mp4")
        let entry = CleanupHistoryEntry(
            originalPath: file.original,
            size: 4,
            category: "Large & Old Files",
            recovery: .trashed(trashPath: file.trash)
        )
        _ = store.record(title: "Smart Clean", entries: [entry])

        // Simulate the user emptying the Trash.
        try FileManager.default.removeItem(atPath: file.trash)
        store.prune()

        let stored = try XCTUnwrap(store.batches.first?.entries.first)
        XCTAssertFalse(stored.isRestorable, "Entry should be demoted to non-restorable once its Trash item is gone")
        XCTAssertEqual(stored.recovery, .permanent)
    }

    func testPersistenceReloadsAcrossInstances() throws {
        let entry = CleanupHistoryEntry(
            originalPath: "/private/tmp/x",
            size: 5,
            category: "System Junk",
            recovery: .permanent
        )
        let dir = tempRoot.appendingPathComponent("persist")
        let first = CleanupHistoryStore(storageDirectory: dir)
        _ = first.record(title: "Smart Clean", entries: [entry])

        let second = CleanupHistoryStore(storageDirectory: dir)
        XCTAssertEqual(second.batches.count, 1)
        XCTAssertEqual(second.batches.first?.entries.first?.size, 5)
    }
}
