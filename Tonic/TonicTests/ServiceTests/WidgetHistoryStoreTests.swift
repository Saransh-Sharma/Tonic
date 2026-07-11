import Foundation
import XCTest
@testable import Tonic

final class WidgetHistoryStoreTests: XCTestCase {
    private var tempRoot: URL!

    override func setUpWithError() throws {
        tempRoot = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("WidgetHistoryStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    @MainActor func testRecordingSamplesPopulatesLiveSessionHistory() {
        let store = makeStore()
        let sample = makeSample(cpu: 42, memory: 64, download: 2_048)

        store.record(sample)

        XCTAssertEqual(store.liveSamples, [sample])
        XCTAssertEqual(store.chartSeries(for: .cpuPercent, range: .live), [42])
        XCTAssertEqual(store.chartSeries(for: .networkDownloadBytesPerSecond, range: .live), [2_048])
    }

    @MainActor func testMinuteBucketsCoalesceSamplesInSameMinute() {
        let store = makeStore()
        let base = ResourceMetricCalculators.minuteBucketTimestamp(for: Date()).addingTimeInterval(10)

        store.record(makeSample(date: base, cpu: 20, memory: 40, download: 1_000))
        store.record(makeSample(date: base.addingTimeInterval(20), cpu: 60, memory: 80, download: 3_000))

        let historical = store.samples(for: .twentyFourHours)
        XCTAssertEqual(historical.count, 1)
        XCTAssertEqual(historical.first?.cpuPercent ?? 0, 40, accuracy: 0.001)
        XCTAssertEqual(historical.first?.memoryPercent ?? 0, 60, accuracy: 0.001)
        XCTAssertEqual(historical.first?.networkDownloadBytesPerSecond ?? 0, 2_000, accuracy: 0.001)
    }

    @MainActor func testSamplesOlderThanTwentyFourHoursArePruned() {
        let store = makeStore()

        store.record(makeSample(date: Date().addingTimeInterval(-25 * 60 * 60), cpu: 10, memory: 10))
        store.record(makeSample(date: Date(), cpu: 90, memory: 90))

        let historical = store.samples(for: .twentyFourHours)
        XCTAssertEqual(historical.count, 1)
        XCTAssertEqual(historical.first?.cpuPercent, 90)
    }

    @MainActor func testHistoryPersistsAndReloads() {
        let url = tempRoot.appendingPathComponent("history.json")
        let first = makeStore(storageURL: url)
        first.record(makeSample(cpu: 50, memory: 75, upload: 512, download: 4_096))
        first.saveHistory()

        let second = makeStore(storageURL: url)
        let historical = second.samples(for: .twentyFourHours)

        XCTAssertEqual(historical.count, 1)
        XCTAssertEqual(historical.first?.cpuPercent, 50)
        XCTAssertEqual(historical.first?.networkUploadBytesPerSecond, 512)
        XCTAssertEqual(historical.first?.networkDownloadBytesPerSecond, 4_096)
    }

    @MainActor func testRestartWeightsNewSampleBySavedBucketCountNotFiftyFifty() {
        let url = tempRoot.appendingPathComponent("history.json")
        let base = ResourceMetricCalculators.minuteBucketTimestamp(for: Date()).addingTimeInterval(5)

        let first = makeStore(storageURL: url)
        first.record(makeSample(date: base, cpu: 20, memory: 20))
        first.record(makeSample(date: base.addingTimeInterval(10), cpu: 40, memory: 40))
        first.saveHistory()
        // The bucket now holds an average of 30 backed by 2 samples.

        let second = makeStore(storageURL: url)
        second.record(makeSample(date: base.addingTimeInterval(20), cpu: 90, memory: 90))

        let historical = second.samples(for: .twentyFourHours)
        XCTAssertEqual(historical.count, 1)
        // Correct weighting: (30*2 + 90) / 3 = 50. A naive restart-resets-to-1 bug would give
        // (30*1 + 90) / 2 = 60 instead.
        XCTAssertEqual(historical.first?.cpuPercent ?? 0, 50, accuracy: 0.001)
        XCTAssertEqual(historical.first?.memoryPercent ?? 0, 50, accuracy: 0.001)
    }

    @MainActor func testSummaryReturnsLatestAverageAndPeak() {
        let store = makeStore()
        let now = Date()
        store.record(makeSample(date: now.addingTimeInterval(-120), cpu: 20, memory: 20))
        store.record(makeSample(date: now.addingTimeInterval(-60), cpu: 60, memory: 60))
        store.record(makeSample(date: now, cpu: 40, memory: 40))

        let summary = store.summary(for: .cpuPercent, range: .twentyFourHours)

        XCTAssertEqual(summary.latest, 40, accuracy: 0.001)
        XCTAssertEqual(summary.average, 40, accuracy: 0.001)
        XCTAssertEqual(summary.peak, 60, accuracy: 0.001)
    }

    @MainActor private func makeStore(storageURL: URL? = nil) -> WidgetHistoryStore {
        WidgetHistoryStore(
            storageURL: storageURL ?? tempRoot.appendingPathComponent("history.json"),
            liveCapacity: 180,
            historicalCapacity: 1_440,
            minimumSaveInterval: 60
        )
    }

    private func makeSample(
        date: Date = Date(),
        cpu: Double,
        memory: Double,
        upload: Double = 0,
        download: Double = 0
    ) -> ResourceMetricSample {
        ResourceMetricSample(
            timestamp: date,
            cpuPercent: cpu,
            memoryPercent: memory,
            memoryUsedBytes: 8_000,
            memoryTotalBytes: 16_000,
            networkUploadBytesPerSecond: upload,
            networkDownloadBytesPerSecond: download,
            diskUsedPercent: 50,
            diskReadBytesPerSecond: 100,
            diskWriteBytesPerSecond: 200
        )
    }
}
