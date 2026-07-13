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

final class LongTermMetricsStoreTests: XCTestCase {
    private var root: URL!
    private var defaults: UserDefaults!
    private var defaultsSuite: String!
    private let now = Date(timeIntervalSince1970: 2_000_000_000)

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("LongTermMetricsStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defaultsSuite = "LongTermMetricsStoreTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: defaultsSuite)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: defaultsSuite)
        try? FileManager.default.removeItem(at: root)
    }

    func testDeduplicatesReadingsInsideSixtySeconds() {
        let store = makeStore()
        XCTAssertTrue(store.record(sample(at: now.addingTimeInterval(-120), cpu: 20)))
        XCTAssertFalse(store.record(sample(at: now.addingTimeInterval(-90), cpu: 80)))
        XCTAssertTrue(store.record(sample(at: now.addingTimeInterval(-60), cpu: 60)))

        let samples = store.samples(for: .twentyFourHours)
        XCTAssertEqual(samples.count, 2)
        XCTAssertEqual(samples.map(\.cpuPercent), [20, 60])
    }

    func testCreatesWeightedHourAndDayRollups() {
        let store = makeStore()
        store.record(sample(at: now.addingTimeInterval(-3_600), cpu: 20, count: 2))
        store.record(sample(at: now, cpu: 80, count: 1))

        let hours = store.samples(for: .sevenDays)
        XCTAssertEqual(hours.count, 2)
        XCTAssertEqual(hours.last?.cpuPercent ?? 0, 80, accuracy: 0.001)
    }

    func testDisabledStoreWritesNothing() {
        let store = makeStore()
        store.isEnabled = false
        XCTAssertFalse(store.record(sample(at: now, cpu: 55)))
        XCTAssertEqual(store.storageSizeBytes, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("minute.json").path))
    }

    func testPersistenceRoundTripIncludesOptionalMetrics() {
        let first = makeStore()
        first.record(sample(at: now, cpu: 42, gpu: 73, temperature: 61))
        first.flush()

        let second = makeStore()
        let loaded = second.samples(for: .twentyFourHours)
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.gpuPercent, 73)
        XCTAssertEqual(loaded.first?.temperatureC, 61)
    }

    func testClearRemovesEveryTier() {
        let store = makeStore()
        store.record(sample(at: now, cpu: 42))
        XCTAssertGreaterThan(store.storageSizeBytes, 0)
        store.clearAll()
        XCTAssertEqual(store.storageSizeBytes, 0)
        XCTAssertTrue(store.samples(for: .thirtyDays).isEmpty)
    }

    func testLegacyCombinedHistoryImportsOnlyOnceEvenAfterClear() throws {
        let legacyURL = root.appendingPathComponent("legacy.json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode([sample(at: now, cpu: 37).resourceSample])
            .write(to: legacyURL, options: .atomic)

        let imported = makeStore()
        XCTAssertEqual(imported.samples(for: .twentyFourHours).map(\.cpuPercent), [37])
        imported.clearAll()

        let reopened = makeStore()
        XCTAssertTrue(reopened.samples(for: .twentyFourHours).isEmpty,
                      "clear must not resurrect the halfway implementation's legacy envelope")
    }

    func testCorruptTierIsIgnoredAndRecordingRecoversItAtomically() throws {
        try Data("not-json".utf8).write(to: root.appendingPathComponent("minute.json"), options: .atomic)
        let store = makeStore()
        XCTAssertTrue(store.samples(for: .twentyFourHours).isEmpty)

        XCTAssertTrue(store.record(sample(at: now, cpu: 64)))
        store.flush()
        let recovered = makeStore()
        XCTAssertEqual(recovered.samples(for: .twentyFourHours).map(\.cpuPercent), [64])
    }

    func testPrunesMinuteHourAndDayTiersAtTheirIndependentRetentionLimits() throws {
        let store = makeStore()
        store.retentionDays = 7
        XCTAssertTrue(store.record(sample(at: now.addingTimeInterval(-8 * 86_400), cpu: 10)))
        XCTAssertTrue(store.record(sample(at: now.addingTimeInterval(-2 * 86_400), cpu: 20)))
        XCTAssertTrue(store.record(sample(at: now, cpu: 30)))
        store.flush()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let minutes = try decoder.decode([LongTermMetricSample].self,
            from: Data(contentsOf: root.appendingPathComponent("minute.json")))
        let hours = try decoder.decode([LongTermMetricSample].self,
            from: Data(contentsOf: root.appendingPathComponent("hour.json")))
        let days = try decoder.decode([LongTermMetricSample].self,
            from: Data(contentsOf: root.appendingPathComponent("day.json")))

        XCTAssertEqual(minutes.map(\.cpuPercent), [30])
        XCTAssertEqual(hours.map(\.cpuPercent), [20, 30])
        XCTAssertEqual(days.map(\.cpuPercent), [10, 20, 30])
    }

    private func makeStore() -> LongTermMetricsStore {
        let fixedNow = now
        return LongTermMetricsStore(
            storageDirectory: root,
            legacyCombinedURL: root.appendingPathComponent("legacy.json"),
            defaults: defaults,
            minimumSaveInterval: 60,
            now: { fixedNow }
        )
    }

    private func sample(
        at date: Date,
        cpu: Double,
        gpu: Double? = nil,
        temperature: Double? = nil,
        count: Int = 1
    ) -> LongTermMetricSample {
        LongTermMetricSample(
            timestamp: date,
            cpuPercent: cpu,
            memoryPercent: 50,
            memoryUsedBytes: 8_000,
            memoryTotalBytes: 16_000,
            networkUploadBytesPerSecond: 100,
            networkDownloadBytesPerSecond: 200,
            diskUsedPercent: 40,
            diskReadBytesPerSecond: 300,
            diskWriteBytesPerSecond: 400,
            gpuPercent: gpu,
            temperatureC: temperature,
            sampleCount: count
        )
    }
}
