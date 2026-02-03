//
//  TemperatureConverter.swift
//  Tonic
//
//  Temperature conversion utility for widget displays
//  Task ID: fn-6-i4g.50
//

import Foundation
import SwiftUI

// MARK: - Temperature Unit

/// Temperature unit for widget displays (CPU, GPU, Sensors, Battery)
public enum TemperatureUnit: String, Sendable, CaseIterable, Identifiable, Codable {
    case celsius = "C"
    case fahrenheit = "F"

    public var id: String { rawValue }

    /// Symbol for display (°C or °F)
    public var symbol: String {
        switch self {
        case .celsius: return "°C"
        case .fahrenheit: return "°F"
        }
    }

    /// Display name for UI
    public var displayName: String {
        switch self {
        case .celsius: return "Celsius (°C)"
        case .fahrenheit: return "Fahrenheit (°F)"
        }
    }

    /// Max temperature value for gauges (100°C = 212°F)
    public var maxTemperature: Double {
        switch self {
        case .celsius: return 100
        case .fahrenheit: return 212
        }
    }

    /// Warning threshold for color coding (50°C = 122°F)
    public var warningThreshold: Double {
        switch self {
        case .celsius: return 50
        case .fahrenheit: return 122
        }
    }

    /// Critical threshold for color coding (75°C = 167°F)
    public var criticalThreshold: Double {
        switch self {
        case .celsius: return 75
        case .fahrenheit: return 167
        }
    }
}

// MARK: - Temperature Converter

/// Temperature conversion and display helper
public struct TemperatureConverter {

    /// Convert Celsius to Fahrenheit
    public static func celsiusToFahrenheit(_ celsius: Double) -> Double {
        return (celsius * 9/5) + 32
    }

    /// Convert Fahrenheit to Celsius
    public static func fahrenheitToCelsius(_ fahrenheit: Double) -> Double {
        return (fahrenheit - 32) * 5/9
    }

    /// Convert temperature value to the desired unit
    /// - Parameters:
    ///   - celsius: Temperature value in Celsius (sensor data is always in Celsius)
    ///   - unit: Target unit for display
    /// - Returns: Temperature value in the target unit
    public static func display(_ celsius: Double, unit: TemperatureUnit) -> Double {
        switch unit {
        case .celsius:
            return celsius
        case .fahrenheit:
            return celsiusToFahrenheit(celsius)
        }
    }

    /// Format temperature as a string with unit symbol
    /// - Parameters:
    ///   - celsius: Temperature value in Celsius
    ///   - unit: Target unit for display
    /// - Returns: Formatted string like "45°C" or "113°F"
    public static func displayString(_ celsius: Double, unit: TemperatureUnit) -> String {
        let value = display(celsius, unit: unit)
        return "\(Int(value))\(unit.symbol)"
    }

    /// Format temperature as a string with decimal precision
    /// - Parameters:
    ///   - celsius: Temperature value in Celsius
    ///   - unit: Target unit for display
    ///   - precision: Number of decimal places (default: 1)
    /// - Returns: Formatted string like "45.5°C" or "113.9°F"
    public static func displayString(_ celsius: Double, unit: TemperatureUnit, precision: Int = 1) -> String {
        let value = display(celsius, unit: unit)
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = precision
        formatter.maximumFractionDigits = precision
        let formattedValue = formatter.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
        return "\(formattedValue)\(unit.symbol)"
    }

    /// Get color for temperature based on value and unit
    /// - Parameters:
    ///   - celsius: Temperature value in Celsius
    ///   - unit: Target unit (affects thresholds)
    /// - Returns: Color based on temperature zone
    public static func colorForTemperature(_ celsius: Double, unit: TemperatureUnit) -> Color {
        let value = display(celsius, unit: unit)
        switch value {
        case 0..<unit.warningThreshold:
            return TonicColors.success
        case unit.warningThreshold..<unit.criticalThreshold:
            return TonicColors.warning
        default:
            return TonicColors.error
        }
    }
}
