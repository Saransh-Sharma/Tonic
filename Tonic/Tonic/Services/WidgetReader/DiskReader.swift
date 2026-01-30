//
//  DiskReader.swift
//  Tonic
//
//  Disk data reader conforming to WidgetReader protocol
//  Follows Stats Master's Disk module reader pattern
//  Task ID: fn-5-v8r.5
//

import Foundation
import IOKit.storage
import IOKit
import DiskArbitration

/// Disk data reader conforming to WidgetReader protocol
/// Follows Stats Master's Disk module CapacityReader pattern
@MainActor
final class DiskReader: WidgetReader {
    typealias Output = [DiskVolumeData]

    let preferredInterval: TimeInterval = 2.0

    private var previousActivity: [String: (read: UInt64, write: UInt64)] = [:]
    private let activityLock = NSLock()

    init() {}

    func read() async throws -> [DiskVolumeData] {
        // Run on background thread for stats collection
        return await Task.detached {
            self.getDiskData()
        }.value
    }

    private func getDiskData() async -> [DiskVolumeData] {
        var volumes: [DiskVolumeData] = []

        let keys: Set<URLResourceKey> = [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeIsBrowsableKey,
            .volumeIsInternalKey,
            .volumeIsRootFileSystemKey
        ]

        guard let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) else {
            return []
        }

        let session = DASessionCreate(kCFAllocatorDefault)
        guard let session else { return [] }

        for url in urls {
            // Skip non-volume paths
            guard url.pathComponents.count == 1 || (url.pathComponents.count > 1 && url.pathComponents[1] == "Volumes") else {
                continue
            }

            // Get disk properties
            guard let disk = DADiskCreateFromVolumePath(kCFAllocatorDefault, session, url as CFURL),
                  let diskName = DADiskGetBSDName(disk) else {
                continue
            }

            let BSDName = String(cString: diskName)

            // Get volume info
            let resourceValues: URLResourceValues
            do {
                resourceValues = try url.resourceValues(forKeys: keys)
            } catch {
                continue
            }

            guard let name = resourceValues.volumeName,
                  let totalBytes = resourceValues.volumeTotalCapacity,
                  let isInternal = resourceValues.volumeIsInternal else {
                continue
            }

            let availableBytes = resourceValues.volumeAvailableCapacity ?? 0
            let usedBytes = totalBytes - availableBytes
            let isBootVolume = resourceValues.volumeIsRootFileSystem ?? false

            // Skip recovery volumes
            if name == "Recovery" {
                continue
            }

            let volumeData = DiskVolumeData(
                name: name,
                path: url.path,
                usedBytes: UInt64(usedBytes),
                totalBytes: UInt64(totalBytes),
                isBootVolume: isBootVolume,
                isInternal: isInternal,
                isActive: isVolumeActive(BSDName: BSDName)
            )

            volumes.append(volumeData)
        }

        // Sort: boot volume first, then by name
        volumes.sort { a, b in
            if a.isBootVolume != b.isBootVolume {
                return a.isBootVolume
            }
            return a.name < b.name
        }

        return volumes
    }

    // MARK: - Private Methods

    private func isVolumeActive(BSDName: String) -> Bool {
        // Check if volume is currently mounted and active
        var stat = statfs()

        // Try direct BSD name path first
        let bsdPath = "/dev/\(BSDName)"
        if statfs(bsdPath, &stat) == 0 {
            return true
        }

        // Check by searching mount points
        let keys: Set<URLResourceKey> = [.volumeNameKey]
        guard let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) else {
            return false
        }

        let session = DASessionCreate(kCFAllocatorDefault)
        guard let session else { return false }

        for url in urls {
            if let disk = DADiskCreateFromVolumePath(kCFAllocatorDefault, session, url as CFURL),
               let diskName = DADiskGetBSDName(disk) {
                let currentBSDName = String(cString: diskName)
                if currentBSDName == BSDName {
                    return true
                }
            }
        }

        return false
    }
}

// MARK: - Disk Activity Reader

/// Reader for disk I/O activity (read/write rates)
@MainActor
final class DiskActivityReader: WidgetReader {
    typealias Output = DiskActivityData

    let preferredInterval: TimeInterval = 2.0

    private var previousStats: (readBytes: UInt64, writeBytes: UInt64, timestamp: Date)?

    init() {}

    func read() async throws -> DiskActivityData {
        // Run on background thread for stats collection
        return await Task.detached {
            self.getDiskActivity()
        }.value
    }

    private func getDiskActivity() async -> DiskActivityData {
        let (totalRead, totalWrite) = getDiskIOStats()

        let now = Date()
        var readRate: Double = 0
        var writeRate: Double = 0

        if let previous = previousStats {
            let timeDelta = now.timeIntervalSince(previous.timestamp)

            if timeDelta > 0 {
                readRate = Double(totalRead - previous.readBytes) / timeDelta
                writeRate = Double(totalWrite - previous.writeBytes) / timeDelta
            }
        }

        previousStats = (totalRead, totalWrite, now)

        return DiskActivityData(
            readBytesPerSecond: max(0, readRate),
            writeBytesPerSecond: max(0, writeRate),
            timestamp: now
        )
    }

    private func getDiskIOStats() -> (UInt64, UInt64) {
        var totalRead: UInt64 = 0
        var totalWrite: UInt64 = 0

        let matchingDict = IOServiceMatching(kIOBlockStorageDriverClass)
        var iterator: io_iterator_t = 0

        guard IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator) == KERN_SUCCESS else {
            return (0, 0)
        }

        defer { IOObjectRelease(iterator) }

        while true {
            let service = IOIteratorNext(iterator)
            guard service != 0 else { break }
            defer { IOObjectRelease(service) }

            guard let props = IORegistryEntryCreateCFProperty(
                service,
                kIOPropertyPlaneKey as CFString,
                kCFAllocatorDefault,
                0
            )?.takeRetainedValue() as? [String: Any] else {
                continue
            }

            // Try different key paths for statistics
            if let stats = props[kIOBlockStorageDriverStatisticsKey as String] as? [String: Any] {
                if let readBytes = stats[kIOBlockStorageDriverStatisticsBytesReadKey as String] as? UInt64 {
                    totalRead += readBytes
                }
                if let writeBytes = stats[kIOBlockStorageDriverStatisticsBytesWrittenKey as String] as? UInt64 {
                    totalWrite += writeBytes
                }
            }
        }

        return (totalRead, totalWrite)
    }
}

// MARK: - Data Models

/// Disk I/O activity data
public struct DiskActivityData: Sendable {
    public let readBytesPerSecond: Double
    public let writeBytesPerSecond: Double
    public let timestamp: Date

    public init(readBytesPerSecond: Double, writeBytesPerSecond: Double, timestamp: Date = Date()) {
        self.readBytesPerSecond = readBytesPerSecond
        self.writeBytesPerSecond = writeBytesPerSecond
        self.timestamp = timestamp
    }

    public var readString: String {
        formatBytes(readBytesPerSecond)
    }

    public var writeString: String {
        formatBytes(writeBytesPerSecond)
    }

    public var totalBytesPerSecond: Double {
        readBytesPerSecond + writeBytesPerSecond
    }

    private func formatBytes(_ bytes: Double) -> String {
        if bytes >= 1_000_000 {
            return String(format: "%.1f MB/s", bytes / 1_000_000)
        } else if bytes >= 1_000 {
            return String(format: "%.1f KB/s", bytes / 1_000)
        } else {
            return String(format: "%.0f B/s", bytes)
        }
    }
}

// MARK: - Constants

private let MNT_NOWAIT: Int32 = 2
