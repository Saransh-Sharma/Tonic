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
