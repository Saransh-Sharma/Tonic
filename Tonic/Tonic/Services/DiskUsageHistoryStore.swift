//
//  DiskUsageHistoryStore.swift
//  Tonic
//
//  One disk-usage sample per day, kept for a year, persisted as JSON in
//  Application Support (same pattern as CleanupHistoryStore). Powers the
//  storage timeline chart and the "full in ~N weeks" forecast.
//
//  The forecast is deliberately conservative: it needs at least a week of
//  samples, and it stays quiet when the trend is flat, shrinking, or points
//  more than six months out — a scary number nobody can act on is noise.
//

import Foundation

struct DiskUsageSample: Codable, Sendable, Equatable {
    let date: Date
    let volumePath: String
    let usedBytes: Int64
    let freeBytes: Int64
}

struct DiskUsageForecast: Sendable, Equatable {
    /// Average growth per day over the analysis window, in bytes.
    let bytesPerDay: Int64
    /// Whole weeks until the volume runs out at the current rate.
    let weeksUntilFull: Int
}

final class DiskUsageHistoryStore: @unchecked Sendable {

    static let shared = DiskUsageHistoryStore()

    private let lock = NSLock()
    private var samples: [DiskUsageSample] = []
    private let storeURL: URL
    private let maxSamples = 365

    /// Testable clock.
    var now: () -> Date = { Date() }

    init(storeURL: URL? = nil) {
        if let storeURL {
            self.storeURL = storeURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Tonic/DiskUsageHistory", isDirectory: true)
            try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
            self.storeURL = base.appendingPathComponent("history.json")
        }
        load()
    }

    // MARK: - Sampling

    /// Record today's sample for the boot volume unless one already exists.
    /// Cheap to call from every launch/foreground.
    func recordSampleIfNeeded(volumePath: String = "/") {
        lock.lock()
        let alreadySampledToday = samples.contains {
            $0.volumePath == volumePath && Calendar.current.isDate($0.date, inSameDayAs: now())
        }
        lock.unlock()
        guard !alreadySampledToday else { return }

        guard let values = try? URL(fileURLWithPath: volumePath).resourceValues(forKeys: [
            .volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey,
        ]),
            let total = values.volumeTotalCapacity,
            let available = values.volumeAvailableCapacityForImportantUsage
        else { return }

        record(DiskUsageSample(
            date: now(),
            volumePath: volumePath,
            usedBytes: Int64(total) - available,
            freeBytes: available
        ))
    }

    /// Direct insertion for tests and alternate volumes.
    func record(_ sample: DiskUsageSample) {
        lock.lock()
        defer { lock.unlock() }
        // Replace any same-day sample for the volume, keep the rest.
        samples.removeAll {
            $0.volumePath == sample.volumePath && Calendar.current.isDate($0.date, inSameDayAs: sample.date)
        }
        samples.append(sample)
        samples.sort { $0.date < $1.date }
        if samples.count > maxSamples {
            samples.removeFirst(samples.count - maxSamples)
        }
        save()
    }

    func samples(volumePath: String = "/", days: Int? = nil) -> [DiskUsageSample] {
        lock.lock()
        defer { lock.unlock() }
        var result = samples.filter { $0.volumePath == volumePath }
        if let days {
            let cutoff = now().addingTimeInterval(-Double(days) * 24 * 3600)
            result = result.filter { $0.date >= cutoff }
        }
        return result
    }

    // MARK: - Forecast

    /// Least-squares fit over the trailing window. Returns nil (stays quiet)
    /// when history is short, the disk isn't growing, or full is >26 weeks out.
    func forecast(volumePath: String = "/", windowDays: Int = 30) -> DiskUsageForecast? {
        let window = samples(volumePath: volumePath, days: windowDays)
        guard window.count >= 7, let latest = window.last else { return nil }

        let t0 = window[0].date.timeIntervalSinceReferenceDate
        let points = window.map { sample in
            (x: (sample.date.timeIntervalSinceReferenceDate - t0) / 86_400.0,
             y: Double(sample.usedBytes))
        }

        let n = Double(points.count)
        let sumX = points.reduce(0) { $0 + $1.x }
        let sumY = points.reduce(0) { $0 + $1.y }
        let sumXY = points.reduce(0) { $0 + $1.x * $1.y }
        let sumXX = points.reduce(0) { $0 + $1.x * $1.x }
        let denominator = n * sumXX - sumX * sumX
        guard denominator != 0 else { return nil }

        let slope = (n * sumXY - sumX * sumY) / denominator // bytes per day
        guard slope > 0 else { return nil }

        let daysUntilFull = Double(latest.freeBytes) / slope
        let weeks = Int((daysUntilFull / 7).rounded())
        guard weeks >= 1, weeks <= 26 else { return nil }

        return DiskUsageForecast(bytesPerDay: Int64(slope), weeksUntilFull: weeks)
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: storeURL),
              let decoded = try? JSONDecoder().decode([DiskUsageSample].self, from: data)
        else { return }
        samples = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(samples) else { return }
        try? data.write(to: storeURL, options: .atomic)
    }
}
