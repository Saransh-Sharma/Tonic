//
//  VisualizationType.swift
//  Tonic
//
//  Visualization types for menu bar widgets
//  Matches Stats Master's widget visualization system
//

import SwiftUI

// MARK: - Visualization Type

/// Visualization types available for menu bar widgets
/// Each data source (WidgetType) can use compatible visualizations
public enum VisualizationType: String, CaseIterable, Identifiable, Codable, Sendable {
    case mini = "mini"                      // Icon + value (default)
    case lineChart = "line_chart"           // Real-time line graph
    case barChart = "bar_chart"             // Per-core/per-zone bars
    case pieChart = "pie_chart"             // Circular progress
    case tachometer = "tachometer"          // Gauge with needle
    case stack = "sensors"                  // Multiple sensor readings
    case speed = "speed"                    // Network up/down display
    case networkChart = "network_chart"     // Dual-line network chart (upload/download)
    case batteryDetails = "battery_details" // Extended battery info
    case label = "label"                    // Static text label
    case state = "state"                    // On/off indicator
    case text = "text"                      // Dynamic formatted text
    case memory = "memory"                  // Two-row used/total memory display
    case battery = "battery"                // Battery icon with fill level

    public var id: String { rawValue }

    /// Display name for the visualization
    public var displayName: String {
        switch self {
        case .mini: return "Mini"
        case .lineChart: return "Line Chart"
        case .barChart: return "Bar Chart"
        case .pieChart: return "Pie Chart"
        case .tachometer: return "Tachometer"
        case .stack: return "Stack"
        case .speed: return "Speed"
        case .networkChart: return "Network Chart"
        case .batteryDetails: return "Battery Details"
        case .label: return "Label"
        case .state: return "State"
        case .text: return "Text"
        case .memory: return "Memory"
        case .battery: return "Battery"
        }
    }

    /// Short name for UI buttons
    public var shortName: String {
        switch self {
        case .mini: return "Mini"
        case .lineChart: return "Line"
        case .barChart: return "Bar"
        case .pieChart: return "Pie"
        case .tachometer: return "Gauge"
        case .stack: return "Stack"
        case .speed: return "Speed"
        case .networkChart: return "Dual"
        case .batteryDetails: return "Details"
        case .label: return "Label"
        case .state: return "State"
        case .text: return "Text"
        case .memory: return "Memory"
        case .battery: return "Battery"
        }
    }

    /// SF Symbol icon for the visualization
    public var icon: String {
        switch self {
        case .mini: return "square.fill"
        case .lineChart: return "chart.line.uptrend.xyaxis"
        case .barChart: return "chart.bar.fill"
        case .pieChart: return "chart.pie.fill"
        case .tachometer: return "gauge"
        case .stack: return "square.stack.fill"
        case .speed: return "speedometer"
        case .networkChart: return "chart.xyaxis.line"
        case .batteryDetails: return "bolt.fill.batteryblock"
        case .label: return "textformat"
        case .state: return "circlebadge.fill"
        case .text: return "text.alignleft"
        case .memory: return "memorychip"
        case .battery: return "battery.100"
        }
    }

    /// Approximate width in points for this visualization in menu bar
    public var estimatedWidth: CGFloat {
        switch self {
        case .mini: return 50
        case .lineChart: return 60
        case .barChart: return 50
        case .pieChart: return 24
        case .tachometer: return 24
        case .stack: return 80
        case .speed: return 90
        case .networkChart: return 60
        case .batteryDetails: return 80
        case .label: return 60
        case .state: return 20
        case .text: return 70
        case .memory: return 50
        case .battery: return 40
        }
    }

    /// Description of what this visualization shows
    public var description: String {
        switch self {
        case .mini: return "Compact icon with value"
        case .lineChart: return "Real-time history graph"
        case .barChart: return "Multi-value bar display"
        case .pieChart: return "Circular progress indicator"
        case .tachometer: return "Gauge with needle"
        case .stack: return "Stacked sensor values"
        case .speed: return "Network speed display"
        case .networkChart: return "Dual-line upload/download chart"
        case .batteryDetails: return "Extended battery info"
        case .label: return "Custom text label"
        case .state: return "On/off indicator"
        case .text: return "Dynamic formatted text"
        case .memory: return "Two-row used/total display"
        case .battery: return "Battery icon with fill level"
        }
    }

    /// Whether this visualization supports history data
    public var supportsHistory: Bool {
        switch self {
        case .lineChart, .barChart, .networkChart: return true
        default: return false
        }
    }

    /// Whether this visualization supports sparkline in detailed mode
    public var supportsSparkline: Bool {
        switch self {
        case .mini: return true
        default: return false
        }
    }

    // Preserve compatibility with previously stored values.
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        switch rawValue {
        case "lineChart": self = .lineChart
        case "barChart": self = .barChart
        case "pieChart": self = .pieChart
        case "stack": self = .stack
        case "networkChart": self = .networkChart
        case "batteryDetails": self = .batteryDetails
        default:
            guard let value = VisualizationType(rawValue: rawValue) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unknown visualization type: \(rawValue)"
                )
            }
            self = value
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

// MARK: - Chart Configuration

/// Configuration for chart-based visualizations
public struct ChartConfiguration: Codable, Sendable, Equatable {
    public var historySize: Int
    public var scaling: ScalingMode
    public var showBackground: Bool
    public var showFrame: Bool
    public var showValue: Bool
    public var fillMode: ChartFillMode
    public var barColorMode: ChartBarColorMode

    public init(
        historySize: Int = 60,
        scaling: ScalingMode = .linear,
        showBackground: Bool = false,
        showFrame: Bool = false,
        showValue: Bool = false,
        fillMode: ChartFillMode = .gradient,
        barColorMode: ChartBarColorMode = .uniform
    ) {
        self.historySize = min(120, max(30, historySize))
        self.scaling = scaling
        self.showBackground = showBackground
        self.showFrame = showFrame
        self.showValue = showValue
        self.fillMode = fillMode
        self.barColorMode = barColorMode
    }

    public static let `default` = ChartConfiguration()
}

// MARK: - Chart Fill Mode

/// Fill mode for line chart area
public enum ChartFillMode: String, CaseIterable, Identifiable, Codable, Sendable, Equatable {
    case gradient
    case solid
    case lineOnly

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .gradient: return "Gradient"
        case .solid: return "Solid"
        case .lineOnly: return "Line Only"
        }
    }
}

// MARK: - Chart Bar Color Mode

/// Color mode for bar chart bars
public enum ChartBarColorMode: String, CaseIterable, Identifiable, Codable, Sendable, Equatable {
    case uniform
    case gradient
    case byValue
    case byCategory
    case ePCores

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .uniform: return "Uniform"
        case .gradient: return "Gradient"
        case .byValue: return "By Value"
        case .byCategory: return "By Category"
        case .ePCores: return "E/P Cores"
        }
    }
}

// MARK: - Scaling Mode

/// Scaling mode for chart values
public enum ScalingMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case linear = "linear"
    case square = "square"
    case cube = "cube"
    case logarithmic = "logarithmic"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .linear: return "Linear"
        case .square: return "Square"
        case .cube: return "Cube"
        case .logarithmic: return "Logarithmic"
        }
    }

    /// Scale a value (0-1) according to this mode
    public func scale(_ value: Double) -> Double {
        guard value > 0 else { return 0 }
        switch self {
        case .linear: return value
        case .square: return value * value
        case .cube: return value * value * value
        case .logarithmic: return log10(1 + value * 9) // Maps 0-1 to 0-1 logarithmically
        }
    }

    /// Normalize a value against a maximum using this scaling
    public func normalize(_ value: Double, maxValue: Double) -> Double {
        guard maxValue > 0 else { return 0 }
        let scaled = scale(value / maxValue)
        return min(1, max(0, scaled))
    }
}
