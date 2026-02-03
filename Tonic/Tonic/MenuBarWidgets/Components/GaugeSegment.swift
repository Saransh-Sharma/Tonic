//
//  GaugeSegment.swift
//  Tonic
//
//  Helper model for gauge visualization components
//  Task ID: fn-6-i4g.30
//

import SwiftUI

// MARK: - Gauge Segment

/// A single segment in a gauge visualization
/// Represents a value with its associated color
public struct GaugeSegment: Sendable, Identifiable, Equatable {
    public let id = UUID()
    public let value: Double
    public let color: Color

    public init(value: Double, color: Color) {
        self.value = value
        self.color = color
    }

    /// Convenience initializer with tuple
    public init(tuple: (value: Double, color: Color)) {
        self.value = tuple.value
        self.color = tuple.color
    }
}

// MARK: - Predefined Segment Sets

/// Common color combinations for gauge segments
public extension [GaugeSegment] {
    /// CPU usage segments (System, User, Idle)
    static var cpuUsage: [GaugeSegment] {
        [
            GaugeSegment(value: 0, color: Color(red: 1.0, green: 0.3, blue: 0.2)),  // System - red
            GaugeSegment(value: 0, color: Color(red: 0.2, green: 0.5, blue: 1.0)),  // User - blue
            GaugeSegment(value: 0, color: Color.gray.opacity(0.3))                   // Idle - gray
        ]
    }

    /// Memory usage segments (App, Wired, Compressed, Free)
    static var memoryUsage: [GaugeSegment] {
        [
            GaugeSegment(value: 0, color: Color(red: 0.2, green: 0.6, blue: 1.0)),  // App - blue
            GaugeSegment(value: 0, color: Color(red: 0.3, green: 0.7, blue: 0.4)),  // Wired - green
            GaugeSegment(value: 0, color: Color(red: 1.0, green: 0.6, blue: 0.0)),  // Compressed - orange
            GaugeSegment(value: 0, color: Color.gray.opacity(0.3))                   // Free - gray
        ]
    }

    /// Status gradient (green to red)
    static var statusGradient: [GaugeSegment] {
        [
            GaugeSegment(value: 1, color: TonicColors.success),
            GaugeSegment(value: 1, color: TonicColors.warning),
            GaugeSegment(value: 1, color: TonicColors.error)
        ]
    }
}
