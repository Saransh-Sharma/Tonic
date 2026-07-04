//
//  WidgetHistoryStore.swift
//  Tonic
//
//  Timestamped resource graph history for the monitoring dashboard.
//

import AppKit
import Foundation

/// Stores live session samples and 24-hour downsampled resource history.
@MainActor
@Observable
public final class WidgetHistoryStore {

    public static let shared = WidgetHistoryStore()

    // MARK: - Constants

    private let liveCapacity: Int
    private let historicalCapacity: Int
    private let persistenceDuration: TimeInterval
    private let minimumSaveInterval: TimeInterval
    private let storageURL: URL
    private let fileManager: FileManager
    private let logger = Logger(subsystem: "com.tonic.app", category: "WidgetHistoryStore")

    // MARK: - Storage

    public private(set) var liveSamples: [ResourceMetricSample] = []
    public private(set) var historicalSamples: [ResourceMetricSample] = []

    private var lastSaveDate: Date?

    // MARK: - Compatibility History Accessors

    public var cpuHistory: [Double] {
        chartSeries(for: .cpuPercent, range: .live)
    }

    public var memoryHistory: [Double] {
        chartSeries(for: .memoryPercent, range: .live)
    }

    public var networkUploadHistory: [Double] {
        chartSeries(for: .networkUploadBytesPerSecond, range: .live)
    }

    public var networkDownloadHistory: [Double] {
        chartSeries(for: .networkDownloadBytesPerSecond, range: .live)
    }

    // MARK: - Initialization

    init(
        storageURL: URL? = nil,
        fileManager: FileManager = .default,
        liveCapacity: Int = 180,
        historicalCapacity: Int = 1_440,
        persistenceDuration: TimeInterval = 24 * 60 * 60,
        minimumSaveInterval: TimeInterval = 60
    ) {
        self.fileManager = fileManager
        self.storageURL = storageURL ?? Self.defaultStorageURL(fileManager: fileManager)
        self.liveCapacity = liveCapacity
        self.historicalCapacity = historicalCapacity
        self.persistenceDuration = persistenceDuration
        self.minimumSaveInterval = minimumSaveInterval

        loadHistory()
        pruneOldHistory()
        setupAppLifecycleObservers()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public API

    public func record(_ sample: ResourceMetricSample) {
        liveSamples.append(sample)
        if liveSamples.count > liveCapacity {
            liveSamples.removeFirst(liveSamples.count - liveCapacity)
        }

        upsertHistoricalSample(sample)
        pruneOldHistory()
        saveHistoryIfNeeded()
    }

    public func samples(for range: ResourceHistoryRange) -> [ResourceMetricSample] {
        switch range {
        case .live:
            return liveSamples
        case .oneHour, .twentyFourHours:
            guard let duration = range.duration else { return historicalSamples }
            let cutoff = Date().addingTimeInterval(-duration)
            return historicalSamples.filter { $0.timestamp >= cutoff }
        }
    }

    public func chartSeries(for metric: ResourceMetricKind, range: ResourceHistoryRange) -> [Double] {
        samples(for: range).map { $0.value(for: metric) }
    }

    public func summary(for metric: ResourceMetricKind, range: ResourceHistoryRange) -> ResourceMetricSummary {
        let values = chartSeries(for: metric, range: range)
        guard let latest = values.last else {
            return .empty
        }

        let total = values.reduce(0, +)
        return ResourceMetricSummary(
            latest: latest,
            average: total / Double(values.count),
            peak: values.max() ?? latest
        )
    }

    public func saveHistory() {
        pruneOldHistory()
        do {
            try fileManager.createDirectory(
                at: storageURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder.resourceHistory.encode(historicalSamples)
            try data.write(to: storageURL, options: .atomic)
            lastSaveDate = Date()
        } catch {
            logger.error("Failed to save widget history: \(error.localizedDescription)")
        }
    }

    public func clearHistory() {
        liveSamples = []
        historicalSamples = []
        lastSaveDate = nil
        try? fileManager.removeItem(at: storageURL)
    }

    // MARK: - Legacy Add API

    public func addCPUValue(_ value: Double) {
        record(legacySample(cpuPercent: value))
    }

    public func addMemoryValue(_ value: Double) {
        record(legacySample(memoryPercent: value))
    }

    public func addNetworkUploadValue(_ bytesPerSecond: Double) {
        record(legacySample(networkUploadBytesPerSecond: bytesPerSecond))
    }

    public func addNetworkDownloadValue(_ bytesPerSecond: Double) {
        record(legacySample(networkDownloadBytesPerSecond: bytesPerSecond))
    }

    // MARK: - Private Methods

    /// Historical samples are always appended/updated in non-decreasing timestamp order (they
    /// come from a serially-dispatched live monitoring tick), so a fresh append is already in the
    /// right place and an in-place update to the last bucket never changes ordering — no sort
    /// needed on this hot path.
    private func upsertHistoricalSample(_ sample: ResourceMetricSample) {
        let bucketTimestamp = ResourceMetricCalculators.minuteBucketTimestamp(for: sample.timestamp)
        let bucketed = sample.withTimestamp(bucketTimestamp)

        if let index = historicalSamples.firstIndex(where: { $0.timestamp == bucketTimestamp }) {
            historicalSamples[index] = historicalSamples[index].averaged(with: bucketed)
        } else {
            historicalSamples.append(bucketed)
        }

        if historicalSamples.count > historicalCapacity {
            historicalSamples.removeFirst(historicalSamples.count - historicalCapacity)
        }
    }

    private func pruneOldHistory() {
        let cutoff = Date().addingTimeInterval(-persistenceDuration)
        historicalSamples.removeAll { $0.timestamp < cutoff }
    }

    private func saveHistoryIfNeeded() {
        guard lastSaveDate.map({ Date().timeIntervalSince($0) >= minimumSaveInterval }) ?? true else {
            return
        }
        saveHistory()
    }

    private func loadHistory() {
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder.resourceHistory.decode([ResourceMetricSample].self, from: data) else {
            return
        }

        historicalSamples = decoded.sorted { $0.timestamp < $1.timestamp }
    }

    private func setupAppLifecycleObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillResignActive),
            name: NSApplication.willResignActiveNotification,
            object: nil
        )
    }

    @objc private func applicationWillTerminate() {
        saveHistory()
    }

    @objc private func applicationWillResignActive() {
        saveHistory()
    }

    private func legacySample(
        cpuPercent: Double = 0,
        memoryPercent: Double = 0,
        networkUploadBytesPerSecond: Double = 0,
        networkDownloadBytesPerSecond: Double = 0
    ) -> ResourceMetricSample {
        ResourceMetricSample(
            cpuPercent: cpuPercent,
            memoryPercent: memoryPercent,
            memoryUsedBytes: 0,
            memoryTotalBytes: 0,
            networkUploadBytesPerSecond: networkUploadBytesPerSecond,
            networkDownloadBytesPerSecond: networkDownloadBytesPerSecond,
            diskUsedPercent: 0,
            diskReadBytesPerSecond: 0,
            diskWriteBytesPerSecond: 0
        )
    }

    private static func defaultStorageURL(fileManager: FileManager) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return base
            .appendingPathComponent("Tonic", isDirectory: true)
            .appendingPathComponent("ResourceMetricHistory.json")
    }
}

private extension ResourceMetricSample {
    func withTimestamp(_ timestamp: Date) -> ResourceMetricSample {
        ResourceMetricSample(
            timestamp: timestamp,
            cpuPercent: cpuPercent,
            memoryPercent: memoryPercent,
            memoryUsedBytes: memoryUsedBytes,
            memoryTotalBytes: memoryTotalBytes,
            networkUploadBytesPerSecond: networkUploadBytesPerSecond,
            networkDownloadBytesPerSecond: networkDownloadBytesPerSecond,
            diskUsedPercent: diskUsedPercent,
            diskReadBytesPerSecond: diskReadBytesPerSecond,
            diskWriteBytesPerSecond: diskWriteBytesPerSecond,
            sampleCount: sampleCount
        )
    }

    func averaged(with next: ResourceMetricSample) -> ResourceMetricSample {
        let count = Double(sampleCount)
        let divisor = count + 1

        func average(_ old: Double, _ new: Double) -> Double {
            ((old * count) + new) / divisor
        }

        func averageBytes(_ old: UInt64, _ new: UInt64) -> UInt64 {
            UInt64(average(Double(old), Double(new)).rounded())
        }

        return ResourceMetricSample(
            timestamp: timestamp,
            cpuPercent: average(cpuPercent, next.cpuPercent),
            memoryPercent: average(memoryPercent, next.memoryPercent),
            memoryUsedBytes: averageBytes(memoryUsedBytes, next.memoryUsedBytes),
            memoryTotalBytes: averageBytes(memoryTotalBytes, next.memoryTotalBytes),
            networkUploadBytesPerSecond: average(networkUploadBytesPerSecond, next.networkUploadBytesPerSecond),
            networkDownloadBytesPerSecond: average(networkDownloadBytesPerSecond, next.networkDownloadBytesPerSecond),
            diskUsedPercent: average(diskUsedPercent, next.diskUsedPercent),
            diskReadBytesPerSecond: average(diskReadBytesPerSecond, next.diskReadBytesPerSecond),
            diskWriteBytesPerSecond: average(diskWriteBytesPerSecond, next.diskWriteBytesPerSecond),
            sampleCount: sampleCount + next.sampleCount
        )
    }
}

private extension JSONEncoder {
    static var resourceHistory: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var resourceHistory: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
