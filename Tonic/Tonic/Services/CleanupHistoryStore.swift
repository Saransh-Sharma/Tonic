//
//  CleanupHistoryStore.swift
//  Tonic
//
//  Records what each Smart Care cleanup removed and how it can be recovered.
//  Personal files are moved to the macOS Trash (recoverable via Restore / Put Back);
//  system junk is removed permanently and kept here as history only.
//

import Foundation
import OSLog

// MARK: - Recovery Descriptor

/// How a cleaned item can be recovered.
enum CleanupRecovery: Codable, Hashable, Sendable {
    /// Moved to the macOS Trash at `trashPath`; can be restored to `originalPath`.
    case trashed(trashPath: String)
    /// Permanently removed (regenerable system junk); not restorable.
    case permanent

    var isRestorable: Bool {
        if case .trashed = self { return true }
        return false
    }
}

// MARK: - Cleanup History Entry

struct CleanupHistoryEntry: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let originalPath: String
    let fileName: String
    let size: Int64
    /// Display grouping label (e.g. the Smart Care item title this path belonged to).
    let category: String
    var recovery: CleanupRecovery
    /// Set once the item has been restored to its original location.
    var restoredDate: Date?

    init(
        id: UUID = UUID(),
        originalPath: String,
        size: Int64,
        category: String,
        recovery: CleanupRecovery,
        restoredDate: Date? = nil
    ) {
        self.id = id
        self.originalPath = originalPath
        self.fileName = (originalPath as NSString).lastPathComponent
        self.size = size
        self.category = category
        self.recovery = recovery
        self.restoredDate = restoredDate
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var isRestorable: Bool {
        restoredDate == nil && recovery.isRestorable
    }
}

// MARK: - Cleanup History Batch

/// One cleanup run, grouping every item removed together.
struct CleanupHistoryBatch: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let date: Date
    /// Human label for the run, e.g. "Smart Clean" or "Space cleanup".
    let title: String
    var entries: [CleanupHistoryEntry]

    init(id: UUID = UUID(), date: Date = Date(), title: String, entries: [CleanupHistoryEntry]) {
        self.id = id
        self.date = date
        self.title = title
        self.entries = entries
    }

    var totalSize: Int64 { entries.reduce(0) { $0 + $1.size } }
    var recoverableEntries: [CleanupHistoryEntry] { entries.filter { $0.isRestorable } }
    var hasRecoverable: Bool { entries.contains { $0.isRestorable } }

    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
}

// MARK: - Restore Result

struct CleanupRestoreResult: Sendable {
    let restored: Int
    let failed: Int
    let restoredBytes: Int64

    static let empty = CleanupRestoreResult(restored: 0, failed: 0, restoredBytes: 0)
}

// MARK: - Cleanup History Store

@Observable
final class CleanupHistoryStore: @unchecked Sendable {

    static let shared = CleanupHistoryStore()

    private let logger = Logger(subsystem: "com.tonic.app", category: "CleanupHistory")
    private let fileManager = FileManager.default
    private let lock = NSLock()
    private let storageURL: URL

    /// Retention window after which permanent (history-only) batches are pruned.
    private let retentionInterval: TimeInterval = 30 * 24 * 60 * 60

    private var _batches: [CleanupHistoryBatch] = []

    /// Most-recent-first list of cleanup batches.
    private(set) var batches: [CleanupHistoryBatch] {
        get { lock.locked { _batches } }
        set { lock.locked { _batches = newValue } }
    }

    private convenience init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = appSupport
            .appendingPathComponent("Tonic", isDirectory: true)
            .appendingPathComponent("CleanupHistory", isDirectory: true)
        self.init(storageDirectory: folder)
    }

    /// Testable initializer that persists to a caller-provided directory.
    init(storageDirectory: URL) {
        try? fileManager.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        storageURL = storageDirectory.appendingPathComponent("history.json")
        load()
        prune()
    }

    // MARK: - Recording

    /// Record a completed cleanup run. No-op if there are no entries.
    @discardableResult
    func record(title: String, entries: [CleanupHistoryEntry]) -> CleanupHistoryBatch? {
        guard !entries.isEmpty else { return nil }
        let batch = CleanupHistoryBatch(title: title, entries: entries)
        var current = batches
        current.insert(batch, at: 0)
        batches = current
        save()
        return batch
    }

    // MARK: - Restore

    /// Restore a whole batch (recoverable entries only).
    @discardableResult
    func restoreBatch(_ batchID: UUID) async -> CleanupRestoreResult {
        guard let batch = batches.first(where: { $0.id == batchID }) else { return .empty }
        let ids = Set(batch.recoverableEntries.map { $0.id })
        return await restoreEntries(ids, in: batchID)
    }

    /// Restore specific entries within a batch by moving them out of the Trash.
    @discardableResult
    func restoreEntries(_ entryIDs: Set<UUID>, in batchID: UUID) async -> CleanupRestoreResult {
        var restored = 0
        var failed = 0
        var bytes: Int64 = 0

        var working = batches
        guard let batchIndex = working.firstIndex(where: { $0.id == batchID }) else { return .empty }

        for entryIndex in working[batchIndex].entries.indices {
            let entry = working[batchIndex].entries[entryIndex]
            guard entryIDs.contains(entry.id), entry.isRestorable,
                  case let .trashed(trashPath) = entry.recovery else { continue }

            if restoreFile(from: trashPath, to: entry.originalPath) {
                working[batchIndex].entries[entryIndex].restoredDate = Date()
                restored += 1
                bytes += entry.size
            } else {
                failed += 1
            }
        }

        batches = working
        save()
        return CleanupRestoreResult(restored: restored, failed: failed, restoredBytes: bytes)
    }

    private func restoreFile(from trashPath: String, to originalPath: String) -> Bool {
        guard fileManager.fileExists(atPath: trashPath) else {
            logger.debug("Trash item gone, cannot restore: \(trashPath)")
            return false
        }
        // Don't clobber a file the user has since recreated at the original path.
        guard !fileManager.fileExists(atPath: originalPath) else {
            logger.debug("Original path occupied, skipping restore: \(originalPath)")
            return false
        }
        do {
            let parent = (originalPath as NSString).deletingLastPathComponent
            try? fileManager.createDirectory(atPath: parent, withIntermediateDirectories: true)
            try fileManager.moveItem(atPath: trashPath, toPath: originalPath)
            return true
        } catch {
            logger.debug("Restore failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Purge (reclaim space)

    /// Permanently delete the tracked Trash items for a batch, reclaiming their
    /// space, and demote those entries to non-restorable history. Returns the
    /// number of bytes reclaimed.
    @discardableResult
    func purgeBatch(_ batchID: UUID) async -> Int64 {
        var working = batches
        guard let batchIndex = working.firstIndex(where: { $0.id == batchID }) else { return 0 }
        var reclaimed: Int64 = 0

        for entryIndex in working[batchIndex].entries.indices {
            let entry = working[batchIndex].entries[entryIndex]
            guard entry.isRestorable, case let .trashed(trashPath) = entry.recovery else { continue }
            if fileManager.fileExists(atPath: trashPath) {
                do {
                    try fileManager.removeItem(atPath: trashPath)
                    reclaimed += entry.size
                } catch {
                    logger.debug("Purge failed: \(error.localizedDescription)")
                    continue
                }
            }
            working[batchIndex].entries[entryIndex].recovery = .permanent
        }

        batches = working
        save()
        return reclaimed
    }

    /// Total bytes still recoverable from the Trash across all batches.
    var reclaimableBytes: Int64 {
        batches.reduce(0) { acc, batch in
            acc + batch.recoverableEntries.reduce(0) { $0 + $1.size }
        }
    }

    // MARK: - Maintenance

    /// Drop batches past the retention window, and demote trashed entries whose
    /// Trash item no longer exists (the user emptied the Trash) to non-restorable.
    func prune() {
        let cutoff = Date().addingTimeInterval(-retentionInterval)
        var working = batches.filter { $0.date >= cutoff }

        for batchIndex in working.indices {
            for entryIndex in working[batchIndex].entries.indices {
                let entry = working[batchIndex].entries[entryIndex]
                if case let .trashed(trashPath) = entry.recovery,
                   entry.restoredDate == nil,
                   !fileManager.fileExists(atPath: trashPath) {
                    working[batchIndex].entries[entryIndex].recovery = .permanent
                }
            }
        }

        batches = working
        save()
    }

    func clear() {
        batches = []
        save()
    }

    // MARK: - Persistence

    private func save() {
        do {
            let data = try JSONEncoder().encode(batches)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            logger.error("Failed to save cleanup history: \(error.localizedDescription)")
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL) else { return }
        do {
            _batches = try JSONDecoder().decode([CleanupHistoryBatch].self, from: data)
        } catch {
            logger.error("Failed to load cleanup history: \(error.localizedDescription)")
            _batches = []
        }
    }
}
