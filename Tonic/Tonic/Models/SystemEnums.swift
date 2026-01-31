//
//  SystemEnums.swift
//  Tonic
//
//  Shared system enumeration types
//  Task ID: fn-3.7
//

import Foundation
import SwiftUI
import AppKit

// MARK: - Included Types

// These types are included here for compilation compatibility.
// Full implementations are in their respective files (DiskSMARTData.swift, ProcessUsage.swift)

/// NVMe drive SMART data placeholder
/// Full implementation in DiskSMARTData.swift
public struct NVMeSMARTData: Sendable, Codable, Equatable {
    public let temperature: Double?
    public let percentageUsed: Double?
    public let criticalWarning: Bool
    public let powerCycles: UInt64
    public let powerOnHours: UInt64
    public let dataReadBytes: UInt64?
    public let dataWrittenBytes: UInt64?

    public init(
        temperature: Double?,
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

/// Per-process resource usage information placeholder
/// Full implementation in ProcessUsage.swift
public struct ProcessUsage: Identifiable, Sendable {
    public let id: Int32  // PID
    public let name: String
    public let iconData: Data?  // Raw icon data
    public let cpuUsage: Double?
    public let memoryUsage: UInt64?
    public let diskReadBytes: UInt64?
    public let diskWriteBytes: UInt64?
    public let networkBytes: UInt64?

    public init(
        id: Int32,
        name: String,
        iconData: Data? = nil,
        cpuUsage: Double? = nil,
        memoryUsage: UInt64? = nil,
        diskReadBytes: UInt64? = nil,
        diskWriteBytes: UInt64? = nil,
        networkBytes: UInt64? = nil
    ) {
        self.id = id
        self.name = name
        self.iconData = iconData
        self.cpuUsage = cpuUsage
        self.memoryUsage = memoryUsage
        self.diskReadBytes = diskReadBytes
        self.diskWriteBytes = diskWriteBytes
        self.networkBytes = networkBytes
    }

    /// Recover NSImage from stored data (convenience for UI)
    public func icon() -> NSImage? {
        guard let iconData = iconData else { return nil }
        return NSImage(data: iconData)
    }

    /// Create ProcessUsage with NSImage (stores it as Data)
    public func withIcon(_ image: NSImage?) -> ProcessUsage {
        var data: Data?
        if let image = image, let tiffData = image.tiffRepresentation {
            data = tiffData
        }
        return ProcessUsage(
            id: self.id,
            name: self.name,
            iconData: data,
            cpuUsage: self.cpuUsage,
            memoryUsage: self.memoryUsage,
            diskReadBytes: self.diskReadBytes,
            diskWriteBytes: self.diskWriteBytes,
            networkBytes: self.networkBytes
        )
    }
}

// MARK: - Memory Pressure

/// System memory pressure state
public enum MemoryPressure: String, CaseIterable, Sendable {
    case normal = "Normal"
    case warning = "Warning"
    case critical = "Critical"

    /// Color representation for UI
    public var color: Color {
        switch self {
        case .normal: return DesignTokens.Colors.progressLow
        case .warning: return DesignTokens.Colors.progressMedium
        case .critical: return DesignTokens.Colors.progressHigh
        }
    }
}

// MARK: - Battery Health

/// Battery health state
public enum BatteryHealth: String, CaseIterable, Sendable {
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
    case unknown = "Unknown"
}

// MARK: - Power Source

/// Power source type for battery tracking
public enum PowerSource: String, Sendable, Codable {
    case battery = "battery"
    case acAdapter = "acAdapter"
    case ups = "ups"
    case unknown = "unknown"

    public var displayName: String {
        switch self {
        case .battery: return "Battery"
        case .acAdapter: return "Power Adapter"
        case .ups: return "UPS"
        case .unknown: return "Unknown"
        }
    }

    public var iconName: String {
        switch self {
        case .battery: return "battery.100"
        case .acAdapter: return "bolt.fill"
        case .ups: return "cable.connector"
        case .unknown: return "questionmark.circle"
        }
    }
}

// MARK: - Thermal State

/// System thermal state for performance monitoring
public enum ThermalState: String, Sendable, Codable {
    case nominal = "nominal"
    case fair = "fair"
    case serious = "serious"
    case critical = "critical"

    public var displayName: String {
        switch self {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        }
    }

    public var colorHex: String {
        switch self {
        case .nominal: return "#34C759"      // Green
        case .fair: return "#FF9F0A"         // Orange
        case .serious: return "#FF9500"      // Darker Orange
        case .critical: return "#FF3B30"     // Red
        }
    }
}

// MARK: - Process Sort Option

/// Sorting options for process lists
public enum ProcessSortOption: String, Sendable, Codable {
    case cpu = "cpu"
    case memory = "memory"
    case pid = "pid"
    case name = "name"

    public var displayName: String {
        switch self {
        case .cpu: return "CPU Usage"
        case .memory: return "Memory Usage"
        case .pid: return "Process ID"
        case .name: return "Name"
        }
    }
}
