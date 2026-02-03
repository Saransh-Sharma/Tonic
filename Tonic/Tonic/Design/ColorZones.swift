//
//  ColorZones.swift
//  Tonic
//
//  Threshold-based coloring system for widgets
//  Enables custom color zones based on value thresholds
//
//  Task ID: fn-6-i4g.19
//

import SwiftUI
import AppKit

// MARK: - Color Zone

/// Defines a threshold-based color zone for automatic coloring
public struct ColorZone: Codable, Equatable, Sendable {
    /// The percentage threshold (0.0-1.0) at which this color applies
    public let threshold: Double
    /// The color key to apply when value exceeds this threshold
    public let colorKey: String

    public init(threshold: Double, colorKey: String) {
        self.threshold = threshold
        self.colorKey = colorKey
    }

    /// Get the Color for this zone
    public var color: Color {
        WidgetAccentColor(rawValue: colorKey)?.nsColor.map { Color(nsColor: $0) }
            ?? WidgetColorPalette.systemAccent
    }

    /// Get the NSColor for this zone
    public var nsColor: NSColor {
        WidgetAccentColor(rawValue: colorKey)?.nsColor ?? .controlAccentColor
    }
}

// MARK: - Color Zone Configuration

/// Configuration for threshold-based automatic coloring
public struct ColorZoneConfiguration: Codable, Equatable, Sendable {
    /// Ordered list of color zones (checked from highest threshold to lowest)
    public var zones: [ColorZone]

    /// Default base color when no threshold is exceeded
    public var baseColorKey: String

    public init(zones: [ColorZone] = [], baseColorKey: String = "secondGreen") {
        self.zones = zones.sorted { $0.threshold > $1.threshold }
        self.baseColorKey = baseColorKey
    }

    /// Returns the appropriate color for a given value (0.0-1.0)
    public func color(for value: Double) -> Color {
        for zone in zones where value >= zone.threshold {
            return zone.color
        }
        return WidgetAccentColor(rawValue: baseColorKey)?.nsColor.map { Color(nsColor: $0) }
            ?? WidgetColorPalette.systemAccent
    }

    /// Returns the appropriate NSColor for a given value (0.0-1.0)
    public func nsColor(for value: Double) -> NSColor {
        for zone in zones where value >= zone.threshold {
            return zone.nsColor
        }
        return WidgetAccentColor(rawValue: baseColorKey)?.nsColor ?? .controlAccentColor
    }

    // MARK: - Preset Configurations

    /// Standard utilization coloring: green -> yellow -> orange -> red
    public static let standardUtilization = ColorZoneConfiguration(
        zones: [
            ColorZone(threshold: 0.90, colorKey: "secondRed"),
            ColorZone(threshold: 0.75, colorKey: "secondOrange"),
            ColorZone(threshold: 0.50, colorKey: "secondYellow")
        ],
        baseColorKey: "secondGreen"
    )

    /// Memory pressure coloring: green -> yellow -> red
    public static let memoryPressure = ColorZoneConfiguration(
        zones: [
            ColorZone(threshold: 0.80, colorKey: "secondRed"),
            ColorZone(threshold: 0.50, colorKey: "secondYellow")
        ],
        baseColorKey: "secondGreen"
    )

    /// Battery level coloring: red (low) -> yellow -> green (full)
    /// Note: This is reversed - low values get warning colors
    public static let batteryLevel = ColorZoneConfiguration(
        zones: [
            ColorZone(threshold: 0.40, colorKey: "secondGreen"),
            ColorZone(threshold: 0.20, colorKey: "secondYellow")
        ],
        baseColorKey: "secondRed"
    )

    /// Temperature coloring: blue (cool) -> green -> yellow -> orange -> red (hot)
    public static let temperature = ColorZoneConfiguration(
        zones: [
            ColorZone(threshold: 0.90, colorKey: "secondRed"),
            ColorZone(threshold: 0.75, colorKey: "secondOrange"),
            ColorZone(threshold: 0.50, colorKey: "secondYellow"),
            ColorZone(threshold: 0.25, colorKey: "secondGreen")
        ],
        baseColorKey: "secondBlue"
    )
}

// MARK: - Utilization Color Helper

/// Helper to calculate utilization-based colors
public enum UtilizationColorHelper {
    /// Calculate color for a percentage value (0-100)
    public static func color(forPercentage percentage: Double) -> Color {
        let normalized = percentage / 100.0
        return color(forNormalized: normalized)
    }

    /// Calculate color for a normalized value (0.0-1.0)
    public static func color(forNormalized value: Double) -> Color {
        switch value {
        case 0..<0.50:
            return Color(nsColor: .systemGreen)
        case 0.50..<0.75:
            return Color(nsColor: .systemYellow)
        case 0.75..<0.90:
            return Color(nsColor: .systemOrange)
        default:
            return Color(nsColor: .systemRed)
        }
    }

    /// Calculate NSColor for a percentage value (0-100)
    public static func nsColor(forPercentage percentage: Double) -> NSColor {
        let normalized = percentage / 100.0
        return nsColor(forNormalized: normalized)
    }

    /// Calculate NSColor for a normalized value (0.0-1.0)
    public static func nsColor(forNormalized value: Double) -> NSColor {
        switch value {
        case 0..<0.50:
            return .systemGreen
        case 0.50..<0.75:
            return .systemYellow
        case 0.75..<0.90:
            return .systemOrange
        default:
            return .systemRed
        }
    }

    /// Calculate color with custom zones
    public static func color(forNormalized value: Double, zones: (orange: Double, red: Double)) -> Color {
        switch value {
        case 0..<zones.orange:
            return Color(nsColor: .systemGreen)
        case zones.orange..<zones.red:
            return Color(nsColor: .systemOrange)
        default:
            return Color(nsColor: .systemRed)
        }
    }
}
