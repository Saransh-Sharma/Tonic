//
//  HealthScoreHistoryStore.swift
//  Tonic
//
//  One health-score sample per completed Smart Scan (capped per day) so Home
//  can show the score's trend instead of a single number without context.
//

import Foundation

struct HealthScoreSample: Codable, Sendable, Equatable {
    let date: Date
    let score: Int
}

final class HealthScoreHistoryStore: @unchecked Sendable {

    static let shared = HealthScoreHistoryStore()

    private let lock = NSLock()
    private var samples: [HealthScoreSample] = []
    private let storeURL: URL
    private let maxSamples = 90

    init(storeURL: URL? = nil) {
        if let storeURL {
            self.storeURL = storeURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Tonic/HealthScoreHistory", isDirectory: true)
            try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
            self.storeURL = base.appendingPathComponent("scores.json")
        }
        load()
    }

    /// Record a score; same-day scans replace the day's sample.
    func record(score: Int, date: Date = Date()) {
        lock.lock()
        defer { lock.unlock() }
        samples.removeAll { Calendar.current.isDate($0.date, inSameDayAs: date) }
        samples.append(HealthScoreSample(date: date, score: score))
        samples.sort { $0.date < $1.date }
        if samples.count > maxSamples {
            samples.removeFirst(samples.count - maxSamples)
        }
        save()
    }

    func recentScores(days: Int = 30) -> [HealthScoreSample] {
        lock.lock()
        defer { lock.unlock() }
        let cutoff = Date().addingTimeInterval(-Double(days) * 24 * 3600)
        return samples.filter { $0.date >= cutoff }
    }

    private func load() {
        guard let data = try? Data(contentsOf: storeURL),
              let decoded = try? JSONDecoder().decode([HealthScoreSample].self, from: data)
        else { return }
        samples = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(samples) else { return }
        try? data.write(to: storeURL, options: .atomic)
    }
}
