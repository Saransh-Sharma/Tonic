//
//  DiskReader.swift
//  Tonic
//
//  Disk data reader conforming to WidgetReader protocol
//  Follows Stats Master's Disk module reader pattern
//  Task ID: fn-6-i4g.7
//

import Foundation
import IOKit.storage
import IOKit
import DiskArbitration
import AppKit

// MARK: - NVMe SMART Interface Constants

/// NVMe SMART user client type ID for IOKit plugin interface
private let kIONVMeSMARTUserClientTypeID = CFUUIDGetConstantUUIDWithBytes(nil,
    0xAA, 0x0F, 0xA6, 0xF9,
    0xC2, 0xD6, 0x45, 0x7F,
    0xB1, 0x0B, 0x59, 0xA1,
    0x32, 0x53, 0x29, 0x2F
)

/// NVMe SMART interface ID for IOKit plugin interface
private let kIONVMeSMARTInterfaceID = CFUUIDGetConstantUUIDWithBytes(nil,
    0xCC, 0xD1, 0xDB, 0x19,
    0xFD, 0x9A, 0x4D, 0xAF,
    0xBF, 0x95, 0x12, 0x45,
    0x4B, 0x23, 0x0A, 0xB6
)

/// Core Foundation plugin interface ID
private let kIOCFPlugInInterfaceID = CFUUIDGetConstantUUIDWithBytes(nil,
    0xC2, 0x44, 0xE8, 0x58,
    0x10, 0x9C, 0x11, 0xD4,
    0x91, 0xD4, 0x00, 0x50,
    0xE4, 0xC6, 0x42, 0x6F
)

// MARK: - Disk Reader

/// Enhanced disk data reader conforming to WidgetReader protocol
/// Follows Stats Master's Disk module CapacityReader pattern with SMART, IOPS, and process tracking
@MainActor
final class DiskReader: WidgetReader {
    typealias Output = [DiskVolumeData]

    let preferredInterval: TimeInterval = 2.0

    // MARK: - State Tracking for Delta Calculations

    private var previousIOStats: DiskIOSnapshot?
    private var previousProcessStats: [Int32: ProcessIOSnapshot] = [:]
    private let statsLock = NSLock()

    init() {}

    func read() async throws -> [DiskVolumeData] {
        // Run on background thread for stats collection
        return await Task.detached { [self] in
            await self.getDiskData()
        }.value
    }

    private func getDiskData() async -> [DiskVolumeData] {
        var volumes: [DiskVolumeData] = []
        let now = Date()

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

        // Get enhanced disk I/O rates (IOPS and bytes/sec)
        let (readIOPS, writeIOPS, readBps, writeBps) = getIOStatsWithRates()

        // Get NVMe SMART data for boot volume
        let smartData = getNVMeSMARTData()

        // Get top processes by disk I/O
        let topProcesses = getTopDiskProcesses(limit: 8)

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

            // Only attach enhanced data to boot/internal volumes
            let volumeSMART = isBootVolume ? smartData : nil
            let volumeReadIOPS = isBootVolume ? readIOPS : nil
            let volumeWriteIOPS = isBootVolume ? writeIOPS : nil
            let volumeReadBps = isBootVolume ? readBps : nil
            let volumeWriteBps = isBootVolume ? writeBps : nil
            let volumeTopProcesses = isBootVolume ? topProcesses : nil

            let volumeData = DiskVolumeData(
                name: name,
                path: url.path,
                usedBytes: UInt64(usedBytes),
                totalBytes: UInt64(totalBytes),
                isBootVolume: isBootVolume,
                isInternal: isInternal,
                isActive: isVolumeActive(BSDName: BSDName),
                smartData: volumeSMART,
                readIOPS: volumeReadIOPS,
                writeIOPS: volumeWriteIOPS,
                readBytesPerSecond: volumeReadBps,
                writeBytesPerSecond: volumeWriteBps,
                topProcesses: volumeTopProcesses,
                timestamp: now
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

    // MARK: - Volume Activity Check

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

    // MARK: - I/O Statistics with IOPS and Throughput

    private struct DiskIOSnapshot {
        let readBytes: UInt64
        let writeBytes: UInt64
        let readOperations: UInt64
        let writeOperations: UInt64
        let timestamp: Date
    }

    /// Get current I/O statistics and calculate rates (IOPS and bytes/sec)
    private func getIOStatsWithRates() -> (Double?, Double?, Double?, Double?) {
        let current = getRawIOStats()
        let now = Date()

        statsLock.lock()
        defer { statsLock.unlock() }

        guard let previous = previousIOStats else {
            // First call - store snapshot and return nil rates
            previousIOStats = DiskIOSnapshot(
                readBytes: current.readBytes,
                writeBytes: current.writeBytes,
                readOperations: current.readOps,
                writeOperations: current.writeOps,
                timestamp: now
            )
            return (nil, nil, nil, nil)
        }

        let timeDelta = now.timeIntervalSince(previous.timestamp)
        guard timeDelta > 0 else {
            return (nil, nil, nil, nil)
        }

        // Calculate deltas
        let readBytesDelta = current.readBytes > previous.readBytes ? current.readBytes - previous.readBytes : 0
        let writeBytesDelta = current.writeBytes > previous.writeBytes ? current.writeBytes - previous.writeBytes : 0
        let readOpsDelta = current.readOps > previous.readOperations ? current.readOps - previous.readOperations : 0
        let writeOpsDelta = current.writeOps > previous.writeOperations ? current.writeOps - previous.writeOperations : 0

        // Calculate rates
        let readIOPS = Double(readOpsDelta) / timeDelta
        let writeIOPS = Double(writeOpsDelta) / timeDelta
        let readBps = Double(readBytesDelta) / timeDelta
        let writeBps = Double(writeBytesDelta) / timeDelta

        // Update snapshot
        previousIOStats = DiskIOSnapshot(
            readBytes: current.readBytes,
            writeBytes: current.writeBytes,
            readOperations: current.readOps,
            writeOperations: current.writeOps,
            timestamp: now
        )

        return (readIOPS, writeIOPS, readBps, writeBps)
    }

    /// Get raw I/O statistics from IORegistry block storage drivers
    private func getRawIOStats() -> (readBytes: UInt64, writeBytes: UInt64, readOps: UInt64, writeOps: UInt64) {
        var totalReadBytes: UInt64 = 0
        var totalWriteBytes: UInt64 = 0
        var totalReadOps: UInt64 = 0
        var totalWriteOps: UInt64 = 0

        let matchingDict = IOServiceMatching(kIOBlockStorageDriverClass)
        var iterator: io_iterator_t = 0

        guard IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator) == KERN_SUCCESS else {
            return (0, 0, 0, 0)
        }

        defer { IOObjectRelease(iterator) }

        while true {
            let service = IOIteratorNext(iterator)
            guard service != 0 else { break }
            defer { IOObjectRelease(service) }

            // Get statistics from IORegistry
            guard let properties = IORegistryEntryCreateCFProperty(
                service,
                "Statistics" as CFString,
                kCFAllocatorDefault,
                0
            )?.takeRetainedValue() as? [String: Any] else {
                continue
            }

            // Extract byte counts
            if let readBytes = properties["Bytes (Read)"] as? UInt64 {
                totalReadBytes += readBytes
            }
            if let writeBytes = properties["Bytes (Write)"] as? UInt64 {
                totalWriteBytes += writeBytes
            }

            // Extract operation counts
            if let readOps = properties["Operations (Read)"] as? UInt64 {
                totalReadOps += readOps
            }
            if let writeOps = properties["Operations (Write)"] as? UInt64 {
                totalWriteOps += writeOps
            }
        }

        return (totalReadBytes, totalWriteBytes, totalReadOps, totalWriteOps)
    }

    // MARK: - NVMe SMART Data

    /// Get NVMe SMART data from the boot drive
    /// Falls back gracefully for non-NVMe drives
    private func getNVMeSMARTData() -> NVMeSMARTData? {
        // First try the simpler IORegistry property approach
        if let smartFromRegistry = getSMARTFromIORegistry() {
            return smartFromRegistry
        }

        // Try system_profiler fallback for basic disk info
        return getFallbackSMARTData()
    }

    /// Get SMART data from IORegistry properties (simpler approach)
    private func getSMARTFromIORegistry() -> NVMeSMARTData? {
        var iterator: io_iterator_t = 0

        // Match NVMe controller
        let matchingDict = IOServiceMatching("IONVMeController")
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator)

        guard result == KERN_SUCCESS else {
            return nil
        }

        defer { IOObjectRelease(iterator) }

        let nvmeService: io_service_t = IOIteratorNext(iterator)
        guard nvmeService != 0 else {
            return nil
        }

        defer { IOObjectRelease(nvmeService) }

        // Try to get SMART data from IORegistry properties
        // This works on some systems where SMART data is exposed as properties
        var temperature: Double? = nil
        var percentageUsed: Double? = nil
        var criticalWarning = false
        var powerCycles: UInt64 = 0
        var powerOnHours: UInt64 = 0
        var dataReadBytes: UInt64? = nil
        var dataWrittenBytes: UInt64? = nil

        // Check for "SMART" property dictionary
        if let properties = IORegistryEntryCreateCFProperty(nvmeService, "SMART" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? [String: Any] {
            temperature = properties["Composite Temperature"] as? Double ?? properties["Temperature"] as? Double
            percentageUsed = properties["Percentage Used"] as? Double
            if let warning = properties["Critical Warning"] as? UInt8 {
                criticalWarning = warning != 0
            }
            powerCycles = properties["Power Cycles"] as? UInt64 ?? 0
            powerOnHours = properties["Power On Hours"] as? UInt64 ?? 0
            if let dataUnitsRead = properties["Data Units Read"] as? UInt64 {
                dataReadBytes = dataUnitsRead * 512 * 1000 // Data units are in 512KB blocks
            }
            if let dataUnitsWritten = properties["Data Units Written"] as? UInt64 {
                dataWrittenBytes = dataUnitsWritten * 512 * 1000
            }

            return NVMeSMARTData(
                temperature: temperature,
                percentageUsed: percentageUsed,
                criticalWarning: criticalWarning,
                powerCycles: powerCycles,
                powerOnHours: powerOnHours,
                dataReadBytes: dataReadBytes,
                dataWrittenBytes: dataWrittenBytes
            )
        }

        // Check for NVMe SMART Capable property (indicates we can query SMART)
        if let smartCapable = IORegistryEntryCreateCFProperty(nvmeService, "NVMe SMART Capable" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Bool,
           smartCapable {
            // We could use IOKit plugin interface here, but it requires
            // special entitlements on modern macOS. Return basic info.
            return NVMeSMARTData(
                temperature: nil,
                percentageUsed: nil,
                criticalWarning: false,
                powerCycles: 0,
                powerOnHours: 0,
                dataReadBytes: nil,
                dataWrittenBytes: nil
            )
        }

        return nil
    }

    /// Fallback SMART data using system_profiler for non-NVMe drives
    private func getFallbackSMARTData() -> NVMeSMARTData? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        task.arguments = ["SPNVMeDataType", "-json"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard task.terminationStatus == 0 else {
                return nil
            }

            // Try to parse SMART status from JSON
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let nvmeInfo = json["SPNVMeDataType"] as? [[String: Any]],
               let firstDrive = nvmeInfo.first {

                // Extract available fields
                var percentageUsed: Double? = nil
                if let spareString = firstDrive["spares_percent"] as? String,
                   let spare = Double(spareString.replacingOccurrences(of: "%", with: "")) {
                    percentageUsed = 100.0 - spare // Convert available spare to percentage used
                }

                return NVMeSMARTData(
                    temperature: nil,
                    percentageUsed: percentageUsed,
                    criticalWarning: false,
                    powerCycles: 0,
                    powerOnHours: 0,
                    dataReadBytes: nil,
                    dataWrittenBytes: nil
                )
            }

            return nil
        } catch {
            return nil
        }
    }

    // MARK: - Process Disk I/O Tracking

    private struct ProcessIOSnapshot {
        let readBytes: UInt64
        let writeBytes: UInt64
        let timestamp: Date
    }

    /// Get top processes by disk I/O usage
    /// Uses proc_pid_rusage to get per-process disk statistics
    private func getTopDiskProcesses(limit: Int = 8) -> [ProcessUsage]? {
        var processes: [ProcessUsage] = []
        let now = Date()

        // Get list of all PIDs
        var pids: [Int32] = []
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-ax", "-o", "pid"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else {
                return nil
            }

            // Parse PIDs (skip header)
            for line in output.components(separatedBy: "\n").dropFirst() {
                guard let pid = Int32(line.trimmingCharacters(in: .whitespaces)), pid > 0 else {
                    continue
                }
                pids.append(pid)
            }
        } catch {
            return nil
        }

        statsLock.lock()
        defer { statsLock.unlock() }

        // Get disk I/O stats for each PID using proc_pid_rusage
        for pid in pids {
            var rusage = rusage_info_current()
            let result = withUnsafeMutablePointer(to: &rusage) {
                $0.withMemoryRebound(to: (rusage_info_t?.self), capacity: 1) {
                    proc_pid_rusage(pid, RUSAGE_INFO_CURRENT, $0)
                }
            }

            guard result == 0 else {
                continue
            }

            let currentReadBytes = rusage.ri_diskio_bytesread
            let currentWriteBytes = rusage.ri_diskio_byteswritten

            // Only include processes with actual disk I/O
            guard currentReadBytes > 0 || currentWriteBytes > 0 else {
                continue
            }

            // Calculate delta from previous snapshot
            var readDelta: UInt64 = 0
            var writeDelta: UInt64 = 0

            if let previous = previousProcessStats[pid] {
                if currentReadBytes > previous.readBytes {
                    readDelta = currentReadBytes - previous.readBytes
                }
                if currentWriteBytes > previous.writeBytes {
                    writeDelta = currentWriteBytes - previous.writeBytes
                }
            }

            // Update snapshot
            previousProcessStats[pid] = ProcessIOSnapshot(
                readBytes: currentReadBytes,
                writeBytes: currentWriteBytes,
                timestamp: now
            )

            // Only include if there's recent activity
            guard readDelta > 0 || writeDelta > 0 else {
                continue
            }

            // Get process name
            var pathBuffer = [Int8](repeating: 0, count: Int(MAXPATHLEN))
            let pathResult = proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count))

            guard pathResult > 0 else {
                continue
            }

            let path = String(cString: pathBuffer)
            let processName = (path as NSString).lastPathComponent

            processes.append(ProcessUsage(
                id: pid,
                name: processName,
                iconData: nil,
                cpuUsage: nil,
                memoryUsage: nil,
                diskReadBytes: readDelta,
                diskWriteBytes: writeDelta
            ))
        }

        // Clean up stale process entries (processes that no longer exist)
        let activePIDs = Set(pids)
        previousProcessStats = previousProcessStats.filter { activePIDs.contains($0.key) }

        // Sort by total disk I/O (read + write delta)
        processes.sort { (p1, p2) -> Bool in
            let p1Total = (p1.diskReadBytes ?? 0) + (p1.diskWriteBytes ?? 0)
            let p2Total = (p2.diskReadBytes ?? 0) + (p2.diskWriteBytes ?? 0)
            return p1Total > p2Total
        }

        // Take top N processes and add icons
        let topProcesses = Array(processes.prefix(limit))
        return topProcesses.map { process in
            let icon = getAppIconForProcess(pid: process.id, name: process.name)
            return process.withIcon(icon)
        }
    }

    /// Get app icon for a process
    private func getAppIconForProcess(pid: Int32, name: String) -> NSImage? {
        // Try to get icon from running application
        if let app = NSRunningApplication(processIdentifier: pid) {
            return app.icon
        }

        // Try to find the app bundle and get its icon
        var pathBuffer = [Int8](repeating: 0, count: Int(MAXPATHLEN))
        let pathResult = proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count))

        guard pathResult > 0 else {
            return nil
        }

        let path = String(cString: pathBuffer)

        // Walk up to find .app bundle
        var url = URL(fileURLWithPath: path)
        while !url.path.isEmpty && url.path != "/" {
            if url.pathExtension == "app" {
                return NSWorkspace.shared.icon(forFile: url.path)
            }
            url = url.deletingLastPathComponent()
        }

        return nil
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
        return await Task.detached { [self] in
            await self.getDiskActivity()
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

            guard let properties = IORegistryEntryCreateCFProperty(
                service,
                "Statistics" as CFString,
                kCFAllocatorDefault,
                0
            )?.takeRetainedValue() as? [String: Any] else {
                continue
            }

            if let readBytes = properties["Bytes (Read)"] as? UInt64 {
                totalRead += readBytes
            }
            if let writeBytes = properties["Bytes (Write)"] as? UInt64 {
                totalWrite += writeBytes
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
        if bytes >= 1_000_000_000 {
            return String(format: "%.1f GB/s", bytes / 1_000_000_000)
        } else if bytes >= 1_000_000 {
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
