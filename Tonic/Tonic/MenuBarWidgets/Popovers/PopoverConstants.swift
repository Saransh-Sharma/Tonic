//
//  PopoverConstants.swift
//  Tonic
//
//  Standardized layout constants for widget popover views
//  Task ID: fn-6-i4g.18
//

import SwiftUI

/// Standardized layout constants for all widget popovers
/// Based on Stats Master and PRD specifications
/// Task ID: fn-6-i4g.41 (Visual Polish and Spacing)
public struct PopoverConstants {

    // MARK: - Dimensions

    /// Standard popover width - consistent across all widgets
    static let width: CGFloat = 280

    /// Maximum popover height - content will scroll if needed
    static let maxHeight: CGFloat = 500

    /// Standard header height
    static let headerHeight: CGFloat = 44

    // MARK: - Spacing (using DesignTokens 8-point grid)

    /// Spacing between major sections
    static let sectionSpacing: CGFloat = DesignTokens.Spacing.xs  // 12pt

    /// Spacing between items within a section
    static let itemSpacing: CGFloat = DesignTokens.Spacing.xxs     // 8pt

    /// Compact spacing for tight rows
    static let compactSpacing: CGFloat = DesignTokens.Spacing.xxxs // 4pt

    /// Horizontal padding for content
    static let horizontalPadding: CGFloat = DesignTokens.Spacing.sm  // 16pt

    /// Vertical padding for content
    static let verticalPadding: CGFloat = DesignTokens.Spacing.sm    // 16pt

    /// Icon text gap in HStacks
    static let iconTextGap: CGFloat = DesignTokens.Spacing.xxxs    // 4pt

    // MARK: - Corner Radius

    /// Standard corner radius for popover
    static let cornerRadius: CGFloat = DesignTokens.CornerRadius.large  // 12pt

    /// Corner radius for inner cards/sections
    static let innerCornerRadius: CGFloat = DesignTokens.CornerRadius.medium  // 8pt

    /// Corner radius for small elements
    static let smallCornerRadius: CGFloat = DesignTokens.CornerRadius.small  // 4pt

    // MARK: - Typography

    /// Header title font
    static let headerTitleFont: Font = .headline

    /// Header value font
    static let headerValueFont: Font = .system(size: 20, weight: .bold, design: .monospaced)

    /// Section title font
    static let sectionTitleFont: Font = .subheadline

    /// Detail label font
    static let detailLabelFont: Font = DesignTokens.Typography.caption

    /// Detail value font
    static let detailValueFont: Font = DesignTokens.Typography.monoCaption

    /// Small label font (for tight spaces)
    static let smallLabelFont: Font = .system(size: 10)

    /// Small value font (monospace)
    static let smallValueFont: Font = .system(size: 10, weight: .medium, design: .monospaced)

    /// Medium value font (for emphasis)
    static let mediumValueFont: Font = .system(size: 11, weight: .medium)

    /// Large metric font (for dashboard numbers)
    static let largeMetricFont: Font = .system(size: 32, weight: .bold, design: .rounded)

    // MARK: - Component Sizes

    /// Circular gauge size
    static let circularGaugeSize: CGFloat = 70

    /// Circular gauge line width
    static let circularGaugeLineWidth: CGFloat = 10

    /// Progress bar height
    static let progressBarHeight: CGFloat = 6

    /// Icon size for small icons
    static let smallIconSize: CGFloat = 10

    /// Icon size for medium icons
    static let mediumIconSize: CGFloat = 12

    /// Icon size for app icons in lists
    static let appIconSize: CGFloat = 14

    /// Indicator dot size
    static let indicatorDotSize: CGFloat = 8

    // MARK: - Widget Icons

    /// SF Symbols for each widget type
    struct Icons {
        static let cpu = "cpu.fill"
        static let memory = "memorychip.fill"
        static let disk = "internaldrive.fill"
        static let network = "wifi.fill"
        static let gpu = "video.bubble.left.fill"
        static let battery = "battery.100"
        static let sensors = "thermometer"
        static let bluetooth = "antenna.radiowaves.left.and.right"
        static let weather = "cloud.sun.fill"
        static let clock = "clock.fill"
        static let activityMonitor = "chart.bar.xaxis"
        static let settings = "gearshape"
        static let checkmark = "checkmark.circle.fill"
        static let info = "info.circle"
        static let warning = "exclamationmark.triangle.fill"
    }

    // MARK: - Widget Names

    /// Display names for each widget type
    struct Names {
        static let cpu = "CPU Usage"
        static let memory = "Memory"
        static let disk = "Disk Usage"
        static let network = "Network"
        static let gpu = "GPU"
        static let battery = "Battery"
        static let sensors = "Sensors"
        static let bluetooth = "Bluetooth"
        static let weather = "Weather"
        static let clock = "Clock"
    }

    // MARK: - Process List Options

    /// Standard process list row counts
    enum ProcessCount: Int, CaseIterable {
        case none = 0
        case few = 3
        case medium = 5
        case many = 8
        case more = 10
        case maximum = 15
    }

    // MARK: - Animation Timings

    /// Fast animation for value changes
    static let fastAnimation: SwiftUI.Animation = .easeInOut(duration: DesignTokens.AnimationDuration.fast)

    /// Normal animation for layout changes
    static let normalAnimation: SwiftUI.Animation = .easeInOut(duration: DesignTokens.AnimationDuration.normal)

    /// Slow animation for major state changes
    static let slowAnimation: SwiftUI.Animation = .easeInOut(duration: DesignTokens.AnimationDuration.slow)

    // MARK: - Color Helpers

    /// Returns status color based on percentage (green -> yellow -> red)
    static func percentageColor(_ percentage: Double) -> Color {
        switch percentage {
        case 0..<50: return TonicColors.success
        case 50..<80: return TonicColors.warning
        default: return TonicColors.error
        }
    }

    /// Returns temperature color based on value
    static func temperatureColor(_ celsius: Double) -> Color {
        switch celsius {
        case 0..<60: return TonicColors.success
        case 60..<75: return TonicColors.warning
        default: return TonicColors.error
        }
    }

    /// Returns battery color based on percentage
    static func batteryColor(_ percentage: Int, isCharging: Bool = false) -> Color {
        if isCharging { return .blue }
        switch percentage {
        case 0..<20: return .red
        case 20..<50: return .orange
        default: return .green
        }
    }
}
