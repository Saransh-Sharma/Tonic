//
//  WidgetHistoryStore.swift
//  Tonic
//
//  Timestamped resource graph history for the monitoring dashboard.
//

import AppKit
import Foundation
import Synchronization

/// Stores live session samples and the existing 24-hour minute history used by
/// dashboard compatibility APIs. Longer retention lives in
/// `LongTermMetricsStore`, which is thread-safe and independent of SwiftUI.
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
        case .sevenDays, .thirtyDays:
            return LongTermMetricsStore.shared.resourceSamples(for: range)
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
        guard let data = try? Data(contentsOf: storageURL) else { return }

        if let payload = try? JSONDecoder.resourceHistory.decode(PersistedResourceHistory.self, from: data) {
            historicalSamples = payload.minute.sorted { $0.timestamp < $1.timestamp }
            return
        }

        // Pre-tier format: a bare minute-sample array. Seed the coarse tiers
        // from it so the first 7d/30d chart isn't empty after upgrade.
        if let legacy = try? JSONDecoder.resourceHistory.decode([ResourceMetricSample].self, from: data) {
            historicalSamples = legacy.sorted { $0.timestamp < $1.timestamp }
        }
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

// MARK: - Dedicated long-term history

public enum LongTermMetricsTier: String, Codable, Sendable, CaseIterable {
    case minute
    case hour
    case day
}

public struct LongTermMetricSample: Codable, Sendable, Equatable, Identifiable {
    public var id: Date { timestamp }
    public let timestamp: Date
    public let cpuPercent: Double
    public let memoryPercent: Double
    public let memoryUsedBytes: UInt64
    public let memoryTotalBytes: UInt64
    public let networkUploadBytesPerSecond: Double
    public let networkDownloadBytesPerSecond: Double
    public let diskUsedPercent: Double
    public let diskReadBytesPerSecond: Double
    public let diskWriteBytesPerSecond: Double
    public let gpuPercent: Double?
    public let temperatureC: Double?
    public let sampleCount: Int

    public init(
        timestamp: Date = Date(),
        cpuPercent: Double,
        memoryPercent: Double,
        memoryUsedBytes: UInt64,
        memoryTotalBytes: UInt64,
        networkUploadBytesPerSecond: Double,
        networkDownloadBytesPerSecond: Double,
        diskUsedPercent: Double,
        diskReadBytesPerSecond: Double,
        diskWriteBytesPerSecond: Double,
        gpuPercent: Double? = nil,
        temperatureC: Double? = nil,
        sampleCount: Int = 1
    ) {
        self.timestamp = timestamp
        self.cpuPercent = ResourceMetricCalculators.clampedPercent(cpuPercent)
        self.memoryPercent = ResourceMetricCalculators.clampedPercent(memoryPercent)
        self.memoryUsedBytes = memoryUsedBytes
        self.memoryTotalBytes = memoryTotalBytes
        self.networkUploadBytesPerSecond = max(0, networkUploadBytesPerSecond)
        self.networkDownloadBytesPerSecond = max(0, networkDownloadBytesPerSecond)
        self.diskUsedPercent = ResourceMetricCalculators.clampedPercent(diskUsedPercent)
        self.diskReadBytesPerSecond = max(0, diskReadBytesPerSecond)
        self.diskWriteBytesPerSecond = max(0, diskWriteBytesPerSecond)
        self.gpuPercent = gpuPercent.map(ResourceMetricCalculators.clampedPercent)
        self.temperatureC = temperatureC?.isFinite == true ? temperatureC : nil
        self.sampleCount = max(1, sampleCount)
    }

    public init(resource sample: ResourceMetricSample, gpuPercent: Double? = nil, temperatureC: Double? = nil) {
        self.init(
            timestamp: sample.timestamp,
            cpuPercent: sample.cpuPercent,
            memoryPercent: sample.memoryPercent,
            memoryUsedBytes: sample.memoryUsedBytes,
            memoryTotalBytes: sample.memoryTotalBytes,
            networkUploadBytesPerSecond: sample.networkUploadBytesPerSecond,
            networkDownloadBytesPerSecond: sample.networkDownloadBytesPerSecond,
            diskUsedPercent: sample.diskUsedPercent,
            diskReadBytesPerSecond: sample.diskReadBytesPerSecond,
            diskWriteBytesPerSecond: sample.diskWriteBytesPerSecond,
            gpuPercent: gpuPercent,
            temperatureC: temperatureC,
            sampleCount: sample.sampleCount
        )
    }

    public func value(for metric: ResourceMetricKind) -> Double {
        resourceSample.value(for: metric)
    }

    public var resourceSample: ResourceMetricSample {
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

    fileprivate func withTimestamp(_ timestamp: Date) -> Self {
        Self(
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
            gpuPercent: gpuPercent,
            temperatureC: temperatureC,
            sampleCount: sampleCount
        )
    }

    fileprivate func averaged(with next: Self) -> Self {
        let oldCount = Double(sampleCount)
        let newCount = Double(next.sampleCount)
        let totalCount = oldCount + newCount

        func average(_ old: Double, _ new: Double) -> Double {
            ((old * oldCount) + (new * newCount)) / totalCount
        }
        func averageBytes(_ old: UInt64, _ new: UInt64) -> UInt64 {
            UInt64(average(Double(old), Double(new)).rounded())
        }
        func averageOptional(_ old: Double?, _ new: Double?) -> Double? {
            switch (old, new) {
            case let (.some(lhs), .some(rhs)): return average(lhs, rhs)
            case let (.some(lhs), .none): return lhs
            case let (.none, .some(rhs)): return rhs
            case (.none, .none): return nil
            }
        }

        return Self(
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
            gpuPercent: averageOptional(gpuPercent, next.gpuPercent),
            temperatureC: averageOptional(temperatureC, next.temperatureC),
            sampleCount: sampleCount + next.sampleCount
        )
    }
}

/// Thread-safe, UI-independent tiered history. Synchronous access is deliberate:
/// each record mutates a few bounded arrays and writes at most once per minute.
public final class LongTermMetricsStore: @unchecked Sendable {
    public static let shared = LongTermMetricsStore()

    private enum DefaultsKey {
        static let enabled = "tonic.metrics.longTermEnabled"
        static let retentionDays = "tonic.metrics.retentionDays"
        static let legacyImportCompleted = "tonic.metrics.legacyImportCompleted"
    }

    private struct State: Sendable {
        var minute: [LongTermMetricSample] = []
        var hour: [LongTermMetricSample] = []
        var day: [LongTermMetricSample] = []
        var lastRecordedAt: Date?
        var lastSaveAt: Date?
    }

    private let state: Mutex<State>
    private let storageDirectory: URL
    private let legacyCombinedURL: URL
    private let fileManager: FileManager
    private let defaults: UserDefaults
    private let now: @Sendable () -> Date
    private let minimumSaveInterval: TimeInterval
    private let logger = Logger(subsystem: "com.tonic.app", category: "LongTermMetricsStore")

    public init(
        storageDirectory: URL? = nil,
        legacyCombinedURL: URL? = nil,
        fileManager: FileManager = .default,
        defaults: UserDefaults = .standard,
        minimumSaveInterval: TimeInterval = 60,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let tonicDirectory = appSupport.appendingPathComponent("Tonic", isDirectory: true)
        self.storageDirectory = storageDirectory
            ?? tonicDirectory.appendingPathComponent("MetricsHistory", isDirectory: true)
        self.legacyCombinedURL = legacyCombinedURL
            ?? tonicDirectory.appendingPathComponent("ResourceMetricHistory.json")
        self.fileManager = fileManager
        self.defaults = defaults
        self.minimumSaveInterval = minimumSaveInterval
        self.now = now

        var initial = State()
        initial.minute = Self.loadTier(.minute, directory: self.storageDirectory, fileManager: fileManager)
        initial.hour = Self.loadTier(.hour, directory: self.storageDirectory, fileManager: fileManager)
        initial.day = Self.loadTier(.day, directory: self.storageDirectory, fileManager: fileManager)

        var importedLegacy = false
        if initial.minute.isEmpty && initial.hour.isEmpty && initial.day.isEmpty,
           defaults.object(forKey: DefaultsKey.enabled) as? Bool ?? true,
           defaults.object(forKey: DefaultsKey.legacyImportCompleted) as? Bool != true,
           let data = try? Data(contentsOf: self.legacyCombinedURL) {
            if let payload = try? JSONDecoder.resourceHistory.decode(PersistedResourceHistory.self, from: data) {
                initial.minute = payload.minute.map { LongTermMetricSample(resource: $0) }
                initial.hour = payload.hourly.map { LongTermMetricSample(resource: $0) }
                initial.day = payload.daily.map { LongTermMetricSample(resource: $0) }
                importedLegacy = true
            } else if let legacy = try? JSONDecoder.resourceHistory.decode([ResourceMetricSample].self, from: data) {
                initial.minute = legacy.map { LongTermMetricSample(resource: $0) }
                for sample in initial.minute {
                    Self.upsert(sample, tier: .hour, samples: &initial.hour)
                    Self.upsert(sample, tier: .day, samples: &initial.day)
                }
                importedLegacy = true
            }
        }

        initial.minute.sort { $0.timestamp < $1.timestamp }
        initial.hour.sort { $0.timestamp < $1.timestamp }
        initial.day.sort { $0.timestamp < $1.timestamp }
        initial.lastRecordedAt = initial.minute.last?.timestamp
        self.state = Mutex(initial)
        prune()
        if importedLegacy {
            defaults.set(true, forKey: DefaultsKey.legacyImportCompleted)
            flush()
        }
    }

    public var isEnabled: Bool {
        get { defaults.object(forKey: DefaultsKey.enabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: DefaultsKey.enabled) }
    }

    public var retentionDays: Int {
        get { min(max(defaults.object(forKey: DefaultsKey.retentionDays) as? Int ?? 30, 7), 90) }
        set {
            defaults.set(min(max(newValue, 7), 90), forKey: DefaultsKey.retentionDays)
            prune()
            if isEnabled { flush() }
        }
    }

    @discardableResult
    public func record(_ sample: LongTermMetricSample) -> Bool {
        guard isEnabled else { return false }
        let result = state.withLock { state -> (accepted: Bool, shouldSave: Bool) in
            if let last = state.lastRecordedAt,
               sample.timestamp.timeIntervalSince(last) < 60 {
                return (false, false)
            }
            state.lastRecordedAt = sample.timestamp
            Self.upsert(sample, tier: .minute, samples: &state.minute)
            Self.upsert(sample, tier: .hour, samples: &state.hour)
            Self.upsert(sample, tier: .day, samples: &state.day)
            Self.prune(&state, now: now(), retentionDays: retentionDays)
            let shouldSave = state.lastSaveAt.map {
                sample.timestamp.timeIntervalSince($0) >= minimumSaveInterval
            } ?? true
            return (true, shouldSave)
        }
        if result.shouldSave { flush() }
        return result.accepted
    }

    public func samples(for range: ResourceHistoryRange) -> [LongTermMetricSample] {
        let cutoff = range.duration.map { now().addingTimeInterval(-$0) }
        return state.withLock { state in
            let source: [LongTermMetricSample]
            switch range {
            case .live: source = []
            case .oneHour, .twentyFourHours: source = state.minute
            case .sevenDays, .thirtyDays: source = state.hour
            }
            guard let cutoff else { return source }
            return source.filter { $0.timestamp >= cutoff }
        }
    }

    public func resourceSamples(for range: ResourceHistoryRange) -> [ResourceMetricSample] {
        samples(for: range).map(\.resourceSample)
    }

    public func chartSeries(for metric: ResourceMetricKind, range: ResourceHistoryRange) -> [Double] {
        samples(for: range).map { $0.value(for: metric) }
    }

    public func summary(for metric: ResourceMetricKind, range: ResourceHistoryRange) -> ResourceMetricSummary {
        let values = chartSeries(for: metric, range: range)
        guard let latest = values.last else { return .empty }
        return ResourceMetricSummary(
            latest: latest,
            average: values.reduce(0, +) / Double(values.count),
            peak: values.max() ?? latest
        )
    }

    public func clearAll() {
        state.withLock { $0 = State() }
        for tier in LongTermMetricsTier.allCases {
            try? fileManager.removeItem(at: url(for: tier))
        }
    }

    public var storageSizeBytes: Int64 {
        LongTermMetricsTier.allCases.reduce(0) { total, tier in
            let values = try? url(for: tier).resourceValues(forKeys: [.fileSizeKey])
            return total + Int64(values?.fileSize ?? 0)
        }
    }

    public func flush() {
        guard isEnabled else { return }
        let snapshot = state.withLock { ($0.minute, $0.hour, $0.day) }
        do {
            try fileManager.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
            try JSONEncoder.resourceHistory.encode(snapshot.0).write(to: url(for: .minute), options: .atomic)
            try JSONEncoder.resourceHistory.encode(snapshot.1).write(to: url(for: .hour), options: .atomic)
            try JSONEncoder.resourceHistory.encode(snapshot.2).write(to: url(for: .day), options: .atomic)
            state.withLock { $0.lastSaveAt = now() }
        } catch {
            logger.error("Failed to persist metrics history: \(error.localizedDescription)")
        }
    }

    private func prune() {
        state.withLock { Self.prune(&$0, now: now(), retentionDays: retentionDays) }
    }

    private func url(for tier: LongTermMetricsTier) -> URL {
        storageDirectory.appendingPathComponent("\(tier.rawValue).json")
    }

    private static func loadTier(
        _ tier: LongTermMetricsTier,
        directory: URL,
        fileManager: FileManager
    ) -> [LongTermMetricSample] {
        let url = directory.appendingPathComponent("\(tier.rawValue).json")
        guard fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder.resourceHistory.decode([LongTermMetricSample].self, from: data)
        else { return [] }
        return decoded
    }

    private static func upsert(
        _ sample: LongTermMetricSample,
        tier: LongTermMetricsTier,
        samples: inout [LongTermMetricSample]
    ) {
        let timestamp: Date
        switch tier {
        case .minute: timestamp = ResourceMetricCalculators.minuteBucketTimestamp(for: sample.timestamp)
        case .hour: timestamp = ResourceMetricCalculators.hourBucketTimestamp(for: sample.timestamp)
        case .day: timestamp = ResourceMetricCalculators.dayBucketTimestamp(for: sample.timestamp)
        }
        let bucketed = sample.withTimestamp(timestamp)
        if let index = samples.lastIndex(where: { $0.timestamp == timestamp }) {
            samples[index] = samples[index].averaged(with: bucketed)
        } else {
            samples.append(bucketed)
        }
    }

    private static func prune(_ state: inout State, now: Date, retentionDays: Int) {
        state.minute.removeAll { $0.timestamp < now.addingTimeInterval(-24 * 60 * 60) }
        state.hour.removeAll { $0.timestamp < now.addingTimeInterval(-Double(retentionDays) * 24 * 60 * 60) }
        state.day.removeAll { $0.timestamp < now.addingTimeInterval(-365 * 24 * 60 * 60) }
    }
}

/// Versioned persistence envelope for the three downsampled tiers.
private struct PersistedResourceHistory: Codable {
    var schemaVersion: Int = 2
    let minute: [ResourceMetricSample]
    let hourly: [ResourceMetricSample]
    let daily: [ResourceMetricSample]
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
        let nextCount = Double(next.sampleCount)
        let divisor = count + nextCount

        func average(_ old: Double, _ new: Double) -> Double {
            ((old * count) + (new * nextCount)) / divisor
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
