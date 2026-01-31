//
//  SensorsData.swift
//  Tonic
//
//  Data model for system sensors
//

import Foundation

/// Data structure for system sensor readings (temperature, fan speeds, etc.)
public struct SensorsData: Sendable, Codable, Equatable {
    public var temperatures: [SensorReading]
    public var fans: [FanReading]
    public var voltages: [SensorReading]
    public var power: [SensorReading]

    public init(
        temperatures: [SensorReading] = [],
        fans: [FanReading] = [],
        voltages: [SensorReading] = [],
        power: [SensorReading] = []
    ) {
        self.temperatures = temperatures
        self.fans = fans
        self.voltages = voltages
        self.power = power
    }

    /// Empty sensor data
    public static let empty = SensorsData()
}

/// Individual sensor reading with name and value
public struct SensorReading: Sendable, Codable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let value: Double
    public let unit: String
    public let min: Double?
    public let max: Double?

    public init(
        id: String,
        name: String,
        value: Double,
        unit: String,
        min: Double? = nil,
        max: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.value = value
        self.unit = unit
        self.min = min
        self.max = max
    }

    /// Convenience initializer without min/max (backward compatible)
    public init(id: String, name: String, value: Double, unit: String) {
        self.id = id
        self.name = name
        self.value = value
        self.unit = unit
        self.min = nil
        self.max = nil
    }

    /// Normalized value (0-1) between min and max
    /// Returns nil if min/max are not available or equal
    public var normalizedValue: Double? {
        guard let min = min, let max = max, max > min else { return nil }
        return (value - min) / (max - min)
    }

    /// Formatted value string
    public var valueString: String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = unit == "°C" ? 1 : 2
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    /// Full formatted string with unit
    public var formattedString: String {
        "\(valueString)\(unit)"
    }
}

/// Fan sensor reading with RPM
public struct FanReading: Sendable, Codable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let rpm: Int
    public let minRPM: Int?
    public let maxRPM: Int?
    public let mode: FanMode?

    public init(id: String, name: String, rpm: Int, minRPM: Int? = nil, maxRPM: Int? = nil, mode: FanMode? = nil) {
        self.id = id
        self.name = name
        self.rpm = rpm
        self.minRPM = minRPM
        self.maxRPM = maxRPM
        self.mode = mode
    }

    /// Backward-compatible initializer without min/mode
    public init(id: String, name: String, rpm: Int, maxRPM: Int? = nil) {
        self.id = id
        self.name = name
        self.rpm = rpm
        self.minRPM = nil
        self.maxRPM = maxRPM
        self.mode = nil
    }

    /// Speed percentage (0-100) based on max RPM
    public var speedPercentage: Double? {
        guard let maxRPM = maxRPM, maxRPM > 0 else { return nil }
        return Double(rpm) / Double(maxRPM) * 100
    }

    /// Formatted mode string
    public var modeString: String? {
        mode?.displayName
    }
}

/// Fan operating mode
public enum FanMode: String, Sendable, Codable {
    case automatic = "auto"
    case forced = "forced"
    case manual = "manual"
    case unknown = "unknown"

    public var displayName: String {
        switch self {
        case .automatic: return "Auto"
        case .forced: return "Forced"
        case .manual: return "Manual"
        case .unknown: return "Unknown"
        }
    }
}
