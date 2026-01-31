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
    
    public init(
        temperatures: [SensorReading] = [],
        fans: [FanReading] = [],
        voltages: [SensorReading] = []
    ) {
        self.temperatures = temperatures
        self.fans = fans
        self.voltages = voltages
    }
}

/// Individual sensor reading with name and value
public struct SensorReading: Sendable, Codable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let value: Double
    public let unit: String
    
    public init(id: String, name: String, value: Double, unit: String) {
        self.id = id
        self.name = name
        self.value = value
        self.unit = unit
    }
}

/// Fan sensor reading with RPM
public struct FanReading: Sendable, Codable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let rpm: Int
    public let maxRPM: Int?
    
    public init(id: String, name: String, rpm: Int, maxRPM: Int? = nil) {
        self.id = id
        self.name = name
        self.rpm = rpm
        self.maxRPM = maxRPM
    }
}
