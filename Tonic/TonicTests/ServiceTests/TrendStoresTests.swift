import XCTest
@testable import Tonic

/// Tests for the trend stores behind Home insights and "what grew":
/// DirectorySnapshotStore diffing and HealthScoreHistoryStore history.
final class TrendStoresTests: XCTestCase {

    private var storeURL: URL!

    override func setUpWithError() throws {
        storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("TrendStores-\(UUID().uuidString).json")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: storeURL)
    }

    // MARK: - DirectorySnapshotStore

    func testTopGrowthDiffsLatestTwoSnapshots() {
        let store = DirectorySnapshotStore(storeURL: storeURL, roots: [])
        let gb: Int64 = 1_000_000_000

        store.append(DirectorySnapshot(
            date: Date().addingTimeInterval(-86_400),
            sizes: ["/A": 10 * gb, "/B": 5 * gb, "/C": 2 * gb]
        ))
        store.append(DirectorySnapshot(
            date: Date(),
            sizes: ["/A": 13 * gb, "/B": 5 * gb, "/C": 1 * gb, "/D": 4 * gb]
        ))

        let growth = store.topGrowth(minimumDelta: 100)
        // Only /A grew; /B is flat, /C shrank, /D has no baseline.
        XCTAssertEqual(growth.map(\.path), ["/A"])
        XCTAssertEqual(growth[0].delta, 3 * gb)
        XCTAssertEqual(growth[0].currentSize, 13 * gb)
    }

    func testTopGrowthNeedsTwoSnapshots() {
        let store = DirectorySnapshotStore(storeURL: storeURL, roots: [])
        store.append(DirectorySnapshot(date: Date(), sizes: ["/A": 100]))
        XCTAssertTrue(store.topGrowth().isEmpty)
    }

    func testMinimumDeltaFiltersNoise() {
        let store = DirectorySnapshotStore(storeURL: storeURL, roots: [])
        store.append(DirectorySnapshot(date: Date().addingTimeInterval(-60), sizes: ["/A": 1000]))
        store.append(DirectorySnapshot(date: Date(), sizes: ["/A": 2000]))
        XCTAssertTrue(store.topGrowth(minimumDelta: 50 * 1024 * 1024).isEmpty,
                      "1 KB of growth must not surface as a grower")
    }

    func testSnapshotsPersistAcrossInstances() {
        let store = DirectorySnapshotStore(storeURL: storeURL, roots: [])
        store.append(DirectorySnapshot(date: Date(), sizes: ["/A": 42]))
        let reloaded = DirectorySnapshotStore(storeURL: storeURL, roots: [])
        XCTAssertNotNil(reloaded.latestSnapshotDate)
    }

    // MARK: - HealthScoreHistoryStore

    func testScoreHistoryReplacesSameDaySample() {
        let store = HealthScoreHistoryStore(storeURL: storeURL)
        store.record(score: 70)
        store.record(score: 85)
        let recent = store.recentScores()
        XCTAssertEqual(recent.count, 1, "same-day scans keep one sample")
        XCTAssertEqual(recent.last?.score, 85)
    }

    func testScoreHistoryKeepsChronologicalOrder() {
        let store = HealthScoreHistoryStore(storeURL: storeURL)
        store.record(score: 60, date: Date().addingTimeInterval(-2 * 86_400))
        store.record(score: 75, date: Date().addingTimeInterval(-86_400))
        store.record(score: 90)
        XCTAssertEqual(store.recentScores().map(\.score), [60, 75, 90])
    }

    // MARK: - MaintenanceScheduler rules (pure parts)

    func testQuietHourBoundaries() {
        func date(hour: Int) -> Date {
            Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date())!
        }
        XCTAssertTrue(MaintenanceScheduler.isQuietHour(now: date(hour: 23)))
        XCTAssertTrue(MaintenanceScheduler.isQuietHour(now: date(hour: 3)))
        XCTAssertFalse(MaintenanceScheduler.isQuietHour(now: date(hour: 12)))
        XCTAssertFalse(MaintenanceScheduler.isQuietHour(now: date(hour: 8)))
        XCTAssertTrue(MaintenanceScheduler.isQuietHour(now: date(hour: 22)))
    }

    func testCadenceIntervals() {
        XCTAssertNil(MaintenanceCadence.off.interval)
        XCTAssertEqual(MaintenanceCadence.daily.interval, 24 * 3600)
        XCTAssertEqual(MaintenanceCadence.weekly.interval, 7 * 24 * 3600)
    }
}
