//
//  DirectorySnapshotStore.swift
//  Tonic
//
//  "What grew": snapshots the sizes of a fixed set of high-churn roots at
//  each Smart Scan, keeps the last ten snapshots, and diffs the latest two
//  so the Storage tab can say *where* new usage came from instead of just
//  that the disk filled up.
//

import Foundation

struct DirectorySnapshot: Codable, Sendable, Equatable {
    let date: Date
    /// Path → allocated bytes at snapshot time.
    let sizes: [String: Int64]
}

struct DirectoryGrowth: Sendable, Equatable {
    let path: String
    let delta: Int64
    let currentSize: Int64

    var displayName: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}

final class DirectorySnapshotStore: @unchecked Sendable {

    static let shared = DirectorySnapshotStore()

    /// High-churn roots worth tracking. Missing paths are skipped quietly.
    static let defaultRoots: [String] = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            home + "/Library/Caches",
            home + "/Downloads",
            home + "/Library/Developer",
            home + "/Movies",
            home + "/Pictures",
            home + "/Documents",
            home + "/Library/Application Support",
            "/Applications",
        ]
    }()

    private let lock = NSLock()
    private var snapshots: [DirectorySnapshot] = []
    private let storeURL: URL
    private let roots: [String]
    private let maxSnapshots = 10

    init(storeURL: URL? = nil, roots: [String] = DirectorySnapshotStore.defaultRoots) {
        self.roots = roots
        if let storeURL {
            self.storeURL = storeURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Tonic/DirectorySnapshots", isDirectory: true)
            try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
            self.storeURL = base.appendingPathComponent("snapshots.json")
        }
        load()
    }

    // MARK: - Capture

    /// Size the tracked roots and append a snapshot. Rate-limited to one per
    /// six hours so back-to-back scans don't produce useless zero-diffs.
    func captureIfDue(now: Date = Date()) {
        lock.lock()
        let last = snapshots.last?.date
        lock.unlock()
        if let last, now.timeIntervalSince(last) < 6 * 3600 { return }

        var sizes: [String: Int64] = [:]
        for root in roots where FileManager.default.fileExists(atPath: root) {
            if let size = DirectorySizeCache.shared.size(for: root, includeHidden: true) {
                sizes[root] = size
            }
        }
        guard !sizes.isEmpty else { return }
        append(DirectorySnapshot(date: now, sizes: sizes))
    }

    /// Direct insertion for tests.
    func append(_ snapshot: DirectorySnapshot) {
        lock.lock()
        defer { lock.unlock() }
        snapshots.append(snapshot)
        snapshots.sort { $0.date < $1.date }
        if snapshots.count > maxSnapshots {
            snapshots.removeFirst(snapshots.count - maxSnapshots)
        }
        save()
    }

    // MARK: - Diff

    /// Largest growers between the two most recent snapshots. Shrinking or
    /// flat roots are excluded — this list explains growth, nothing else.
    func topGrowth(limit: Int = 5, minimumDelta: Int64 = 50 * 1024 * 1024) -> [DirectoryGrowth] {
        lock.lock()
        defer { lock.unlock() }
        guard snapshots.count >= 2 else { return [] }
        let previous = snapshots[snapshots.count - 2]
        let latest = snapshots[snapshots.count - 1]

        return latest.sizes.compactMap { path, current -> DirectoryGrowth? in
            guard let before = previous.sizes[path] else { return nil }
            let delta = current - before
            guard delta >= minimumDelta else { return nil }
            return DirectoryGrowth(path: path, delta: delta, currentSize: current)
        }
        .sorted { $0.delta > $1.delta }
        .prefix(limit)
        .map { $0 }
    }

    var latestSnapshotDate: Date? {
        lock.lock()
        defer { lock.unlock() }
        return snapshots.last?.date
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: storeURL),
              let decoded = try? JSONDecoder().decode([DirectorySnapshot].self, from: data)
        else { return }
        snapshots = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(snapshots) else { return }
        try? data.write(to: storeURL, options: .atomic)
    }
}
