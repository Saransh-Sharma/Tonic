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

// MARK: - Memory Pressure

/// System memory pressure state
public enum MemoryPressure: String, CaseIterable, Sendable {
    case normal = "Normal"
    case warning = "Warning"
    case critical = "Critical"

    /// Status color for UI — memory pressure is machine state, so it draws from the
    /// data-only status scale (never brand).
    public var color: Color {
        switch self {
        case .normal: return TonicDS.Colors.statusSuccess
        case .warning: return TonicDS.Colors.statusWarning
        case .critical: return TonicDS.Colors.statusCritical
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

    public var description: String {
        rawValue
    }
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
        case .nominal: return "#1f9d57"      // status-success
        case .fair: return "#e0a32c"         // status-warning
        case .serious: return "#e07b39"      // status-caution
        case .critical: return "#d14b4b"     // status-critical
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
