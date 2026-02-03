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
    public static let width: CGFloat = 280

    /// Maximum popover height - content will scroll if needed
    public static let maxHeight: CGFloat = 500

    /// Standard header height
    public static let headerHeight: CGFloat = 44

    // MARK: - Stats Master Layout Constants

    /// Font sizes matching Stats Master (9pt small, 11pt medium, 13pt large)
    public struct FontSizes {
        public static let small: CGFloat = 9     // Stats Master: fontSmall
        public static let medium: CGFloat = 11    // Stats Master: fontMedium
        public static let large: CGFloat = 13     // Stats Master: fontLarge
    }

    /// Section heights matching Stats Master layout
    public struct SectionHeights {
        public static let dashboard: CGFloat = 90    // Dashboard section height
        public static let header: CGFloat = 22       // Section header row height
        public static let detail: CGFloat = 16        // Detail row height
        public static let process: CGFloat = 22       // Process row height
    }

    /// Spacing matching Stats Master layout
    public struct StatsMasterSpacing {
        public static let margins: CGFloat = 10           // Content margins
        public static let separatorHeight: CGFloat = 22   // Section separator height
    }

    // MARK: - Spacing (using DesignTokens 8-point grid)

    /// Spacing between major sections
    public static let sectionSpacing: CGFloat = DesignTokens.Spacing.xs  // 12pt

    /// Spacing between items within a section
    public static let itemSpacing: CGFloat = DesignTokens.Spacing.xxs     // 8pt

    /// Compact spacing for tight rows
    public static let compactSpacing: CGFloat = DesignTokens.Spacing.xxxs // 4pt

    /// Horizontal padding for content (Stats Master parity: 10px)
    public static let horizontalPadding: CGFloat = 10

    /// Vertical padding for content (Stats Master parity: 10px)
    public static let verticalPadding: CGFloat = 10

    /// Icon text gap in HStacks
    public static let iconTextGap: CGFloat = DesignTokens.Spacing.xxxs    // 4pt

    // MARK: - Corner Radius

    /// Standard corner radius for popover
    public static let cornerRadius: CGFloat = DesignTokens.CornerRadius.large  // 12pt

    /// Corner radius for inner cards/sections
    public static let innerCornerRadius: CGFloat = DesignTokens.CornerRadius.medium  // 8pt

    /// Corner radius for small elements
    public static let smallCornerRadius: CGFloat = DesignTokens.CornerRadius.small  // 4pt

    // MARK: - Typography

    /// Header title font
    public static let headerTitleFont: Font = .headline

    /// Header value font
    public static let headerValueFont: Font = .system(size: 20, weight: .bold, design: .monospaced)

    /// Section title font
    public static let sectionTitleFont: Font = .subheadline

    /// Detail label font
    public static let detailLabelFont: Font = DesignTokens.Typography.caption

    /// Detail value font
    public static let detailValueFont: Font = DesignTokens.Typography.monoCaption

    /// Small label font (for tight spaces)
    public static let smallLabelFont: Font = .system(size: 10)

    /// Small value font (monospace)
    public static let smallValueFont: Font = .system(size: 10, weight: .medium, design: .monospaced)

    /// Medium value font (for emphasis)
    public static let mediumValueFont: Font = .system(size: 11, weight: .medium)

    /// Large metric font (for dashboard numbers)
    public static let largeMetricFont: Font = .system(size: 32, weight: .bold, design: .rounded)

    // MARK: - Component Sizes

    /// Circular gauge size
    public static let circularGaugeSize: CGFloat = 70

    /// Circular gauge line width
    public static let circularGaugeLineWidth: CGFloat = 10

    /// Progress bar height
    public static let progressBarHeight: CGFloat = 6

    /// Icon size for small icons
    public static let smallIconSize: CGFloat = 10

    /// Icon size for medium icons
    public static let mediumIconSize: CGFloat = 12

    /// Icon size for app icons in lists
    public static let appIconSize: CGFloat = 14

    /// Indicator dot size
    public static let indicatorDotSize: CGFloat = 8

    // MARK: - Widget Icons

    /// SF Symbols for each widget type
    public struct Icons {
        public static let cpu = "cpu.fill"
        public static let memory = "memorychip.fill"
        public static let disk = "internaldrive.fill"
        public static let network = "wifi.fill"
        public static let gpu = "video.bubble.left.fill"
        public static let battery = "battery.100"
        public static let sensors = "thermometer"
        public static let bluetooth = "antenna.radiowaves.left.and.right"
        public static let weather = "cloud.sun.fill"
        public static let clock = "clock.fill"
        public static let activityMonitor = "chart.bar.xaxis"
        public static let settings = "gearshape"
        public static let checkmark = "checkmark.circle.fill"
        public static let info = "info.circle"
        public static let warning = "exclamationmark.triangle.fill"
    }

    // MARK: - Widget Names

    /// Display names for each widget type
    public struct Names {
        public static let cpu = "CPU Usage"
        public static let memory = "Memory"
        public static let disk = "Disk Usage"
        public static let network = "Network"
        public static let gpu = "GPU"
        public static let battery = "Battery"
        public static let sensors = "Sensors"
        public static let bluetooth = "Bluetooth"
        public static let weather = "Weather"
        public static let clock = "Clock"
    }

    // MARK: - Process List Options

    /// Standard process list row counts
    public enum ProcessCount: Int, CaseIterable {
        case none = 0
        case few = 3
        case medium = 5
        case many = 8
        case more = 10
        case maximum = 15
    }

    // MARK: - Animation Timings

    /// Fast animation for value changes
    public static let fastAnimation: SwiftUI.Animation = .easeInOut(duration: DesignTokens.AnimationDuration.fast)

    /// Normal animation for layout changes
    public static let normalAnimation: SwiftUI.Animation = .easeInOut(duration: DesignTokens.AnimationDuration.normal)

    /// Slow animation for major state changes
    public static let slowAnimation: SwiftUI.Animation = .easeInOut(duration: DesignTokens.AnimationDuration.slow)

    // MARK: - Color Helpers

    /// Returns status color based on percentage (green -> yellow -> red)
    public static func percentageColor(_ percentage: Double) -> Color {
        switch percentage {
        case 0..<50: return TonicColors.success
        case 50..<80: return TonicColors.warning
        default: return TonicColors.error
        }
    }

    /// Returns temperature color based on value
    public static func temperatureColor(_ celsius: Double) -> Color {
        switch celsius {
        case 0..<60: return TonicColors.success
        case 60..<75: return TonicColors.warning
        default: return TonicColors.error
        }
    }

    /// Returns battery color based on percentage
    public static func batteryColor(_ percentage: Int, isCharging: Bool = false) -> Color {
        if isCharging { return .blue }
        switch percentage {
        case 0..<20: return .red
        case 20..<50: return .orange
        default: return .green
        }
    }
}
