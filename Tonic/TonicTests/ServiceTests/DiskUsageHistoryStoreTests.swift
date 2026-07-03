import XCTest
@testable import Tonic

final class DiskUsageHistoryStoreTests: XCTestCase {

    private var storeURL: URL!

    override func setUpWithError() throws {
        storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("DiskUsageHistoryTests-\(UUID().uuidString).json")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: storeURL)
    }

    private func makeStore() -> DiskUsageHistoryStore {
        DiskUsageHistoryStore(storeURL: storeURL)
    }

    private func sample(daysAgo: Int, used: Int64, free: Int64, volume: String = "/") -> DiskUsageSample {
        DiskUsageSample(
            date: Date().addingTimeInterval(-Double(daysAgo) * 86_400),
            volumePath: volume,
            usedBytes: used,
            freeBytes: free
        )
    }

    func testRecordReplacesSameDaySample() {
        let store = makeStore()
        store.record(sample(daysAgo: 0, used: 100, free: 900))
        store.record(sample(daysAgo: 0, used: 120, free: 880))
        let samples = store.samples()
        XCTAssertEqual(samples.count, 1)
        XCTAssertEqual(samples[0].usedBytes, 120)
    }

    func testPersistsAcrossInstances() {
        let store = makeStore()
        store.record(sample(daysAgo: 1, used: 50, free: 950))
        let reloaded = DiskUsageHistoryStore(storeURL: storeURL)
        XCTAssertEqual(reloaded.samples().count, 1)
        XCTAssertEqual(reloaded.samples()[0].usedBytes, 50)
    }

    func testForecastRequiresSevenSamples() {
        let store = makeStore()
        for day in (0..<5).reversed() {
            store.record(sample(daysAgo: day, used: Int64(100 + (5 - day) * 10), free: 1000))
        }
        XCTAssertNil(store.forecast(), "fewer than 7 samples must not forecast")
    }

    func testForecastsSteadyGrowth() {
        let store = makeStore()
        // 10 GB used growing 1 GB/day with 20 GB free → full in ~20 days ≈ 3 weeks.
        let gb: Int64 = 1_000_000_000
        for day in (0..<10).reversed() {
            let used = 10 * gb + Int64(10 - day) * gb
            store.record(sample(daysAgo: day, used: used, free: 20 * gb))
        }
        let forecast = store.forecast()
        XCTAssertNotNil(forecast)
        XCTAssertEqual(forecast?.weeksUntilFull, 3)
        // Slope should be about a GB per day.
        if let perDay = forecast?.bytesPerDay {
            XCTAssertGreaterThan(perDay, gb / 2)
            XCTAssertLessThan(perDay, gb * 2)
        }
    }

    func testNoForecastWhenShrinkingOrFlat() {
        let store = makeStore()
        for day in (0..<10).reversed() {
            store.record(sample(daysAgo: day, used: 1000, free: 5000))
        }
        XCTAssertNil(store.forecast(), "flat usage must stay quiet")
    }

    func testNoForecastWhenFullIsFarAway() {
        let store = makeStore()
        let gb: Int64 = 1_000_000_000
        // Growing 1 MB/day with 1 TB free → decades out; suppress.
        for day in (0..<10).reversed() {
            store.record(sample(daysAgo: day, used: gb + Int64(10 - day) * 1_000_000, free: 1000 * gb))
        }
        XCTAssertNil(store.forecast())
    }

    func testVolumesAreIndependent() {
        let store = makeStore()
        store.record(sample(daysAgo: 0, used: 10, free: 90, volume: "/"))
        store.record(sample(daysAgo: 0, used: 20, free: 80, volume: "/Volumes/External"))
        XCTAssertEqual(store.samples(volumePath: "/").count, 1)
        XCTAssertEqual(store.samples(volumePath: "/Volumes/External").count, 1)
        XCTAssertEqual(store.samples(volumePath: "/Volumes/External")[0].usedBytes, 20)
    }
}
