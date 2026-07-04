import Foundation
import XCTest
@testable import Tonic

/// Safety-slice regression tests: personal cleanup items must keep their
/// dataClass and selectionPolicy through the dedupe rebuild, and the run
/// path must route personal items to the Trash (recoverable history) while
/// junk deletes permanently.
final class CleanupSafetyRoutingTests: XCTestCase {

    private var fixtureRoot: URL!

    override func setUpWithError() throws {
        fixtureRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("CleanupSafetyTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: fixtureRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: fixtureRoot)
    }

    private func makeFile(_ name: String, bytes: Int = 64) throws -> String {
        let url = fixtureRoot.appendingPathComponent(name)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try Data(repeating: 0x41, count: bytes).write(to: url)
        return url.path
    }

    private func item(
        title: String,
        paths: [String],
        dataClass: SmartCareDataClass,
        selectionPolicy: SmartCareSelectionPolicy = .standard
    ) -> SmartCareItem {
        SmartCareItem(
            domain: .cleanup,
            groupId: UUID(),
            title: title,
            subtitle: "",
            size: 64,
            count: paths.count,
            safeToRun: true,
            isSmartSelected: false,
            action: .delete(paths: paths),
            paths: paths,
            scoreImpact: 1,
            selectionPolicy: selectionPolicy,
            dataClass: dataClass
        )
    }

    // MARK: - P0 regression: dedupe must not reclassify personal data

    /// Every personal scanner category survives dedupe with dataClass and
    /// selectionPolicy intact. Before the fix, dedupeItems rebuilt items with
    /// default arguments, silently turning personal data into system junk.
    func testDedupePreservesDataClassAndSelectionPolicy() throws {
        let engine = SmartCareEngine()

        let mailPath = try makeFile("Mail/Attachments/1/big.pdf")
        let backupPath = try makeFile("MobileSync/Backup/ABC/Manifest.db")
        let downloadPath = try makeFile("Downloads/installer.dmg")
        let largeOldPath = try makeFile("Movies/old-render.mov")
        let dupA = try makeFile("Docs/copy-a.txt")
        let dupB = try makeFile("Docs/copy-b.txt")
        let junkPath = try makeFile("Caches/blob.bin")

        let items = [
            item(title: "Large Mail Attachments", paths: [mailPath], dataClass: .personal),
            item(title: "Saransh's iPhone", paths: [backupPath], dataClass: .personal),
            item(title: "Old Downloads", paths: [downloadPath], dataClass: .personal),
            item(title: "Large & Old Files", paths: [largeOldPath], dataClass: .personal),
            item(title: "Duplicates", paths: [dupA, dupB], dataClass: .personal,
                 selectionPolicy: .keepOneCopy),
            item(title: "User Cache Files", paths: [junkPath], dataClass: .systemJunk),
        ]

        var ledger = SmartCareEngine.PathLedger()
        let deduped = engine.dedupeItems(items, ledger: &ledger)

        XCTAssertEqual(deduped.count, items.count, "no overlapping paths — nothing should drop")

        for original in items {
            let rebuilt = try XCTUnwrap(
                deduped.first { $0.id == original.id },
                "\(original.title) missing after dedupe"
            )
            XCTAssertEqual(rebuilt.dataClass, original.dataClass,
                           "\(original.title) changed dataClass in dedupe")
            XCTAssertEqual(rebuilt.selectionPolicy, original.selectionPolicy,
                           "\(original.title) changed selectionPolicy in dedupe")
        }

        // The one junk item is still junk — the fix must not over-correct.
        XCTAssertEqual(deduped.first { $0.title == "User Cache Files" }?.dataClass, .systemJunk)
    }

    /// Dedupe that actually removes overlapping paths still keeps the class.
    func testDedupeWithOverlapStillKeepsPersonalClass() throws {
        let engine = SmartCareEngine()
        let parent = try makeFile("Backups/Device/Manifest.db")
        let parentDir = (parent as NSString).deletingLastPathComponent

        let backupItem = item(title: "Device Backup", paths: [parentDir], dataClass: .personal)
        // Second item overlaps the first (child path) — its path gets deduped away.
        let overlapping = item(title: "Overlap", paths: [parent, try makeFile("Other/file.txt")],
                               dataClass: .personal)

        var ledger = SmartCareEngine.PathLedger()
        let deduped = engine.dedupeItems([backupItem, overlapping], ledger: &ledger)

        for rebuilt in deduped {
            XCTAssertEqual(rebuilt.dataClass, .personal, "\(rebuilt.title) lost personal class")
        }
    }

    // MARK: - Run path: personal → Trash + recoverable, junk → permanent

    @MainActor
    func testRunRoutesPersonalToTrashAndJunkToPermanentDeletion() async throws {
        let personalPath = try makeFile("RunPath/vacation.mov", bytes: 128)
        let junkPath = try makeFile("RunPath/stale-cache.bin", bytes: 128)

        let historyDir = fixtureRoot.appendingPathComponent("History", isDirectory: true)
        let historyStore = CleanupHistoryStore(storageDirectory: historyDir)

        let store = SmartCareSessionStore()
        let summary = await store.performRun(
            items: [
                item(title: "Old Downloads", paths: [personalPath], dataClass: .personal),
                item(title: "User Cache Files", paths: [junkPath], dataClass: .systemJunk),
            ],
            title: "Safety Test Run",
            historyStore: historyStore,
            progressUpdate: { _ in }
        )

        XCTAssertEqual(summary.errors, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: personalPath))
        XCTAssertFalse(FileManager.default.fileExists(atPath: junkPath))

        // The personal file must be recoverable from the Trash.
        XCTAssertEqual(summary.recoverableCount, 1,
                       "exactly the personal file should be recoverable")
        XCTAssertNotNil(summary.recoveryBatchID)

        let batch = try XCTUnwrap(historyStore.batches.first { $0.title == "Safety Test Run" })
        let personalEntry = try XCTUnwrap(batch.entries.first { $0.originalPath == personalPath })
        guard case .trashed(let trashPath) = personalEntry.recovery else {
            return XCTFail("personal file was not routed through the Trash")
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: trashPath),
                      "trashed copy should exist for recovery")
        // Clean up the trashed copy so test runs don't accumulate in Trash.
        try? FileManager.default.removeItem(atPath: trashPath)

        let junkEntry = try XCTUnwrap(batch.entries.first { $0.originalPath == junkPath })
        guard case .permanent = junkEntry.recovery else {
            return XCTFail("junk must be recorded as permanently removed")
        }
    }
}
