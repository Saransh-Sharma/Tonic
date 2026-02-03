//
//  DiskSMARTData.swift
//  Tonic
//
//  Disk health and S.M.A.R.T. data models
//  Task ID: fn-6-i4g.2
//

import Foundation

// MARK: - NVMe SMART Data

/// NVMe drive SMART (Self-Monitoring, Analysis and Reporting Technology) data
/// Provides health and usage information for NVMe SSDs
public struct NVMeSMARTData: Sendable, Codable, Equatable {
    /// Current drive temperature in Celsius (nil if not available)
    public let temperature: Double?

    /// Percentage of drive used (for endurance)
    /// Percentage Used = 100 - (Percentage Remaining)
    /// nil if not available or not an SSD
    public let percentageUsed: Double?

    /// Critical warning flags from SMART
    /// Bit 0: Available spare space is below threshold
    /// Bit 1: Temperature is below or above operating range
    /// Bit 2: Reliable write to media no longer guaranteed
    /// Bit 3: Volatile memory backup device failed
    /// Bit 4: Media has been placed in read-only mode
    public let criticalWarning: Bool

    /// Number of power cycles
    public let powerCycles: UInt64

    /// Power-on hours (lifetime)
    public let powerOnHours: UInt64

    /// Optional: Total data read in bytes
    public let dataReadBytes: UInt64?

    /// Optional: Total data written in bytes
    public let dataWrittenBytes: UInt64?

    public init(
        temperature: Double? = nil,
        percentageUsed: Double? = nil,
        criticalWarning: Bool = false,
        powerCycles: UInt64 = 0,
        powerOnHours: UInt64 = 0,
        dataReadBytes: UInt64? = nil,
        dataWrittenBytes: UInt64? = nil
    ) {
        self.temperature = temperature
        self.percentageUsed = percentageUsed
        self.criticalWarning = criticalWarning
        self.powerCycles = powerCycles
        self.powerOnHours = powerOnHours
        self.dataReadBytes = dataReadBytes
        self.dataWrittenBytes = dataWrittenBytes
    }

    /// Drive health status based on SMART data
    public var healthStatus: DiskHealthStatus {
        if criticalWarning {
            return .critical
        }
        if let percentageUsed = percentageUsed, percentageUsed > 90 {
            return .warning
        }
        if let temp = temperature, temp > 80 {
            return .warning
        }
        return .good
    }

    /// Formatted power-on time
    public var powerOnTimeString: String {
        let hours = Int(powerOnHours)
        if hours < 24 {
            return "\(hours)h"
        }
        let days = hours / 24
        if days < 365 {
            return "\(days)d"
        }
        let years = Double(days) / 365.0
        return String(format: "%.1fy", years)
    }

    /// Data read formatted as string
    public var dataReadString: String? {
        guard let dataReadBytes = dataReadBytes else { return nil }
        return ByteCountFormatter.string(fromByteCount: Int64(dataReadBytes), countStyle: .binary)
    }

    /// Data written formatted as string
    public var dataWrittenString: String? {
        guard let dataWrittenBytes = dataWrittenBytes else { return nil }
        return ByteCountFormatter.string(fromByteCount: Int64(dataWrittenBytes), countStyle: .binary)
    }
}

/// Disk health status classification
public enum DiskHealthStatus: String, Sendable, Codable {
    case good = "Good"
    case warning = "Warning"
    case critical = "Critical"
    case unknown = "Unknown"

    public var colorHex: String {
        switch self {
        case .good: return "#34C759"      // Green
        case .warning: return "#FF9F0A"   // Orange
        case .critical: return "#FF3B30"  // Red
        case .unknown: return "#8E8E93"   // Gray
        }
    }
}

// MARK: - Generic Disk SMART Data

/// Generic SMART data for any drive type
/// Falls back when NVMe-specific data is not available
public struct GenericSMARTData: Sendable, Codable, Equatable {
    /// Drive temperature in Celsius (nil if not available)
    public let temperature: Double?

    /// Overall health status from SMART
    public let healthStatus: DiskHealthStatus

    /// Number of bad sectors (if available)
    public let badSectors: UInt64?

    /// Number of reallocated sectors (if available)
    public let reallocatedSectors: UInt64?

    /// Power-on count
    public let powerCycleCount: UInt64?

    /// Power-on hours
    public let powerOnHours: UInt64?

    public init(
        temperature: Double? = nil,
        healthStatus: DiskHealthStatus = .unknown,
        badSectors: UInt64? = nil,
        reallocatedSectors: UInt64? = nil,
        powerCycleCount: UInt64? = nil,
        powerOnHours: UInt64? = nil
    ) {
        self.temperature = temperature
        self.healthStatus = healthStatus
        self.badSectors = badSectors
        self.reallocatedSectors = reallocatedSectors
        self.powerCycleCount = powerCycleCount
        self.powerOnHours = powerOnHours
    }

    /// Convert to NVMeSMARTData if possible
    public func asNVMe() -> NVMeSMARTData? {
        guard let temperature = temperature else { return nil }
        return NVMeSMARTData(
            temperature: temperature,
            percentageUsed: nil,
            criticalWarning: healthStatus == .critical,
            powerCycles: powerCycleCount ?? 0,
            powerOnHours: powerOnHours ?? 0
        )
    }
}
