//
//  DirectorySizeCache.swift
//  Tonic
//
//  Lightweight cache + fast size estimation for large directory scans
//

import Foundation

final class DirectorySizeCache: @unchecked Sendable {
    static let shared = DirectorySizeCache()

    private struct CacheEntry {
        let size: Int64
        let modDate: Date?
        let timestamp: Date
    }

    private let fileManager = FileManager.default
    private let lock = NSLock()
    private var cache: [String: CacheEntry] = [:]
    private let maxAge: TimeInterval = 60 * 10 // 10 minutes

    private init() {}

    func size(for path: String, includeHidden: Bool = true) -> Int64? {
        guard fileManager.fileExists(atPath: path) else { return nil }

        let modDate = (try? fileManager.attributesOfItem(atPath: path)[.modificationDate] as? Date) ?? nil
        let now = Date()

        if let entry = cachedEntry(for: path), entry.modDate == modDate, now.timeIntervalSince(entry.timestamp) < maxAge {
            return entry.size
        }

        let size = computeSize(path: path, includeHidden: includeHidden)
        if let size {
            setEntry(CacheEntry(size: size, modDate: modDate, timestamp: now), for: path)
        }
        return size
    }

    private func cachedEntry(for path: String) -> CacheEntry? {
        lock.lock()
        defer { lock.unlock() }
        return cache[path]
    }

    private func setEntry(_ entry: CacheEntry, for path: String) {
        lock.lock()
        cache[path] = entry
        lock.unlock()
    }

    private func computeSize(path: String, includeHidden: Bool) -> Int64? {
        let url = URL(fileURLWithPath: path)
        if let values = try? url.resourceValues(forKeys: [.totalFileSizeKey, .totalFileAllocatedSizeKey]) {
            if let size = values.totalFileSize ?? values.totalFileAllocatedSize {
                return Int64(size)
            }
        }

        var totalSize: Int64 = 0
        var options: FileManager.DirectoryEnumerationOptions = [.skipsPackageDescendants]
        if !includeHidden {
            options.insert(.skipsHiddenFiles)
        }

        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey], options: options) else {
            return nil
        }

        while let itemURL = enumerator.nextObject() as? URL {
            if let values = try? itemURL.resourceValues(forKeys: [.fileSizeKey]) {
                totalSize += Int64(values.fileSize ?? 0)
            }
        }

        return totalSize
    }
}
