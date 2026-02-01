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
struct PopoverConstants {

    // MARK: - Dimensions

    /// Standard popover width - consistent across all widgets
    static let width: CGFloat = 280

    /// Maximum popover height - content will scroll if needed
    static let maxHeight: CGFloat = 500

    /// Standard header height
    static let headerHeight: CGFloat = 44

    // MARK: - Spacing

    /// Spacing between major sections
    static let sectionSpacing: CGFloat = 12

    /// Spacing between items within a section
    static let itemSpacing: CGFloat = 8

    /// Horizontal padding for content
    static let horizontalPadding: CGFloat = 16

    /// Vertical padding for content
    static let verticalPadding: CGFloat = 16

    // MARK: - Corner Radius

    /// Standard corner radius for popover
    static let cornerRadius: CGFloat = 12

    /// Corner radius for inner cards/sections
    static let innerCornerRadius: CGFloat = 8

    // MARK: - Typography

    /// Header title font
    static let headerTitleFont: Font = .headline

    /// Header value font
    static let headerValueFont: Font = .system(size: 20, weight: .bold, design: .monospaced)

    /// Section title font
    static let sectionTitleFont: Font = .subheadline

    /// Detail label font
    static let detailLabelFont: Font = .caption

    /// Detail value font
    static let detailValueFont: Font = .caption

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
}
