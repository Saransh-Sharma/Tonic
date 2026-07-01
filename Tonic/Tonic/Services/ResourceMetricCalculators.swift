//
//  ResourceMetricCalculators.swift
//  Tonic
//
//  Pure monitoring math for live resource sampling and persisted dashboard history.
//

import Foundation

public struct CPUCounterSnapshot: Sendable, Equatable {
    public struct Core: Sendable, Equatable {
        public let user: UInt64
        public let system: UInt64
        public let idle: UInt64
        public let nice: UInt64

        public init(user: UInt64, system: UInt64, idle: UInt64, nice: UInt64) {
            self.user = user
            self.system = system
            self.idle = idle
            self.nice = nice
        }
    }

    public let cores: [Core]
    public let timestamp: Date

    public init(cores: [Core], timestamp: Date = Date()) {
        self.cores = cores
        self.timestamp = timestamp
    }
}

public struct CPUUsageSnapshot: Sendable, Equatable {
    public let totalUsage: Double
    public let userUsage: Double
    public let systemUsage: Double
    public let idleUsage: Double
    public let perCoreUsage: [Double]

    public init(
        totalUsage: Double,
        userUsage: Double,
        systemUsage: Double,
        idleUsage: Double,
        perCoreUsage: [Double]
    ) {
        self.totalUsage = totalUsage
        self.userUsage = userUsage
        self.systemUsage = systemUsage
        self.idleUsage = idleUsage
        self.perCoreUsage = perCoreUsage
    }

    public static func zero(coreCount: Int = 0) -> CPUUsageSnapshot {
        CPUUsageSnapshot(
            totalUsage: 0,
            userUsage: 0,
            systemUsage: 0,
            idleUsage: 100,
            perCoreUsage: Array(repeating: 0, count: max(0, coreCount))
        )
    }
}

public enum ResourceHistoryRange: String, CaseIterable, Codable, Sendable, Identifiable {
    case live
    case oneHour
    case twentyFourHours

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .live: return "Live"
        case .oneHour: return "1h"
        case .twentyFourHours: return "24h"
        }
    }

    public var duration: TimeInterval? {
        switch self {
        case .live: return nil
        case .oneHour: return 60 * 60
        case .twentyFourHours: return 24 * 60 * 60
        }
    }
}

public enum ResourceMetricKind: String, CaseIterable, Codable, Sendable {
    case cpuPercent
    case memoryPercent
    case memoryUsedBytes
    case networkUploadBytesPerSecond
    case networkDownloadBytesPerSecond
    case diskUsedPercent
    case diskReadBytesPerSecond
    case diskWriteBytesPerSecond
}

public struct ResourceMetricSample: Codable, Sendable, Equatable, Identifiable {
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
        diskWriteBytesPerSecond: Double
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
    }

    public func value(for metric: ResourceMetricKind) -> Double {
        switch metric {
        case .cpuPercent: return cpuPercent
        case .memoryPercent: return memoryPercent
        case .memoryUsedBytes: return Double(memoryUsedBytes)
        case .networkUploadBytesPerSecond: return networkUploadBytesPerSecond
        case .networkDownloadBytesPerSecond: return networkDownloadBytesPerSecond
        case .diskUsedPercent: return diskUsedPercent
        case .diskReadBytesPerSecond: return diskReadBytesPerSecond
        case .diskWriteBytesPerSecond: return diskWriteBytesPerSecond
        }
    }
}

public struct ResourceMetricSummary: Sendable, Equatable {
    public let latest: Double
    public let average: Double
    public let peak: Double

    public static let empty = ResourceMetricSummary(latest: 0, average: 0, peak: 0)

    public init(latest: Double, average: Double, peak: Double) {
        self.latest = latest
        self.average = average
        self.peak = peak
    }
}

public enum ResourceMetricCalculators {
    public static func cpuUsage(previous: CPUCounterSnapshot?, current: CPUCounterSnapshot) -> CPUUsageSnapshot {
        guard let previous, !current.cores.isEmpty else {
            return .zero(coreCount: current.cores.count)
        }

        let pairCount = min(previous.cores.count, current.cores.count)
        guard pairCount > 0 else {
            return .zero(coreCount: current.cores.count)
        }

        var userDelta: UInt64 = 0
        var systemDelta: UInt64 = 0
        var idleDelta: UInt64 = 0
        var niceDelta: UInt64 = 0
        var validCores = 0
        var perCoreUsage: [Double] = []
        perCoreUsage.reserveCapacity(current.cores.count)

        for index in 0..<pairCount {
            guard let delta = deltas(previous: previous.cores[index], current: current.cores[index]) else {
                perCoreUsage.append(0)
                continue
            }

            validCores += 1
            userDelta += delta.user
            systemDelta += delta.system
            idleDelta += delta.idle
            niceDelta += delta.nice

            let total = delta.user + delta.system + delta.idle + delta.nice
            let active = delta.user + delta.system + delta.nice
            perCoreUsage.append(percent(active, total: total))
        }

        if current.cores.count > pairCount {
            perCoreUsage.append(contentsOf: Array(repeating: 0, count: current.cores.count - pairCount))
        }

        guard validCores > 0 else {
            return .zero(coreCount: current.cores.count)
        }

        let totalDelta = userDelta + systemDelta + idleDelta + niceDelta
        guard totalDelta > 0 else {
            return .zero(coreCount: current.cores.count)
        }

        let activeDelta = userDelta + systemDelta + niceDelta
        return CPUUsageSnapshot(
            totalUsage: percent(activeDelta, total: totalDelta),
            userUsage: percent(userDelta + niceDelta, total: totalDelta),
            systemUsage: percent(systemDelta, total: totalDelta),
            idleUsage: percent(idleDelta, total: totalDelta),
            perCoreUsage: perCoreUsage
        )
    }

    public static func networkRate(previousBytes: UInt64, currentBytes: UInt64, elapsed: TimeInterval) -> Double {
        guard elapsed > 0, currentBytes >= previousBytes else {
            return 0
        }
        return Double(currentBytes - previousBytes) / elapsed
    }

    public static func minuteBucketTimestamp(for date: Date) -> Date {
        Date(timeIntervalSince1970: floor(date.timeIntervalSince1970 / 60) * 60)
    }

    public static func clampedPercent(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(100, max(0, value))
    }

    private static func deltas(previous: CPUCounterSnapshot.Core, current: CPUCounterSnapshot.Core) -> CPUCounterSnapshot.Core? {
        guard current.user >= previous.user,
              current.system >= previous.system,
              current.idle >= previous.idle,
              current.nice >= previous.nice else {
            return nil
        }

        return CPUCounterSnapshot.Core(
            user: current.user - previous.user,
            system: current.system - previous.system,
            idle: current.idle - previous.idle,
            nice: current.nice - previous.nice
        )
    }

    private static func percent(_ value: UInt64, total: UInt64) -> Double {
        guard total > 0 else { return 0 }
        return clampedPercent(Double(value) / Double(total) * 100)
    }
}
