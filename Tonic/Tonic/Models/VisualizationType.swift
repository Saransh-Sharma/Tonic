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
    case lineChart = "lineChart"            // Real-time line graph
    case barChart = "barChart"              // Per-core/per-zone bars
    case pieChart = "pieChart"              // Circular progress
    case tachometer = "tachometer"          // Gauge with needle
    case stack = "stack"                    // Multiple sensor readings
    case speed = "speed"                    // Network up/down display
    case batteryDetails = "batteryDetails"  // Extended battery info
    case label = "label"                    // Static text label
    case state = "state"                    // On/off indicator
    case text = "text"                      // Dynamic formatted text

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
        case .batteryDetails: return "Battery Details"
        case .label: return "Label"
        case .state: return "State"
        case .text: return "Text"
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
        case .batteryDetails: return "bolt.fill.batteryblock"
        case .label: return "textformat"
        case .state: return "circlebadge.fill"
        case .text: return "text.alignleft"
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
        case .batteryDetails: return 80
        case .label: return 60
        case .state: return 20
        case .text: return 70
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
        case .batteryDetails: return "Extended battery info"
        case .label: return "Custom text label"
        case .state: return "On/off indicator"
        case .text: return "Dynamic formatted text"
        }
    }

    /// Whether this visualization supports history data
    public var supportsHistory: Bool {
        switch self {
        case .lineChart, .barChart: return true
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
}

// MARK: - Chart Configuration

/// Configuration for chart-based visualizations
public struct ChartConfiguration: Codable, Sendable, Equatable {
    public var historySize: Int
    public var scaling: ScalingMode
    public var showBackground: Bool
    public var showFrame: Bool
    public var showValue: Bool

    public init(
        historySize: Int = 60,
        scaling: ScalingMode = .linear,
        showBackground: Bool = false,
        showFrame: Bool = false,
        showValue: Bool = false
    ) {
        self.historySize = min(120, max(30, historySize))
        self.scaling = scaling
        self.showBackground = showBackground
        self.showFrame = showFrame
        self.showValue = showValue
    }

    public static let `default` = ChartConfiguration()
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
