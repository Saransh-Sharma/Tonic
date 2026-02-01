//
//  NotificationThreshold.swift
//  Tonic
//
//  Per-widget threshold configuration for notifications
//  Task ID: fn-6-i4g.3
//

import Foundation

// MARK: - Notification Condition

/// Comparison conditions for notification thresholds
public enum NotificationCondition: String, CaseIterable, Codable, Sendable {
    case equals = "equals"
    case notEquals = "notEquals"
    case greaterThan = "greaterThan"
    case lessThan = "lessThan"
    case greaterThanOrEqual = "greaterThanOrEqual"
    case lessThanOrEqual = "lessThanOrEqual"

    /// Display name for the condition
    public var displayName: String {
        switch self {
        case .equals: return "Equals"
        case .notEquals: return "Not Equals"
        case .greaterThan: return "Greater Than"
        case .lessThan: return "Less Than"
        case .greaterThanOrEqual: return "Greater Than or Equal"
        case .lessThanOrEqual: return "Less Than or Equal"
        }
    }

    /// Symbol for display in UI
    public var symbol: String {
        switch self {
        case .equals: return "="
        case .notEquals: return "≠"
        case .greaterThan: return ">"
        case .lessThan: return "<"
        case .greaterThanOrEqual: return "≥"
        case .lessThanOrEqual: return "≤"
        }
    }

    /// Evaluate whether this condition matches for given values
    /// - Parameters:
    ///   - currentValue: The current sensor value
    ///   - threshold: The threshold value to compare against
    /// - Returns: True if the condition is met
    public func matches(currentValue: Double, threshold: Double) -> Bool {
        switch self {
        case .equals:
            return currentValue == threshold
        case .notEquals:
            return currentValue != threshold
        case .greaterThan:
            return currentValue > threshold
        case .lessThan:
            return currentValue < threshold
        case .greaterThanOrEqual:
            return currentValue >= threshold
        case .lessThanOrEqual:
            return currentValue <= threshold
        }
    }
}

// MARK: - Notification Threshold

/// Configuration for a single notification threshold on a widget
public struct NotificationThreshold: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public var widgetType: WidgetType
    public var condition: NotificationCondition
    public var value: Double
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        widgetType: WidgetType,
        condition: NotificationCondition,
        value: Double,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.widgetType = widgetType
        self.condition = condition
        self.value = value
        self.isEnabled = isEnabled
    }

    /// Evaluate whether this threshold is triggered by the current value
    /// - Parameter currentValue: The current sensor value to check
    /// - Returns: True if the threshold is enabled and the condition matches
    public func matches(currentValue: Double) -> Bool {
        isEnabled && condition.matches(currentValue: currentValue, threshold: value)
    }

    /// Generate a descriptive label for this threshold
    public var label: String {
        "\(widgetType.displayName) \(condition.symbol) \(formattedValue)"
    }

    /// Format the threshold value based on widget type
    public var formattedValue: String {
        switch widgetType {
        case .cpu, .memory, .gpu, .battery:
            return String(format: "%.0f%%", value)
        case .disk:
            return String(format: "%.0f%%", value)
        case .network:
            return String(format: "%.1f MB/s", value)
        case .weather:
            return String(format: "%.1f°", value)
        case .sensors:
            return String(format: "%.1f°", value)
        case .bluetooth:
            return String(format: "%.0f%%", value)
        }
    }
}

// MARK: - Default Thresholds

extension NotificationThreshold {
    /// Default suggested thresholds for each widget type
    public static func defaultThresholds(for widgetType: WidgetType) -> [NotificationThreshold] {
        switch widgetType {
        case .cpu:
            return [
                NotificationThreshold(
                    widgetType: .cpu,
                    condition: .greaterThanOrEqual,
                    value: 90.0
                )
            ]
        case .memory:
            return [
                NotificationThreshold(
                    widgetType: .memory,
                    condition: .greaterThanOrEqual,
                    value: 90.0
                )
            ]
        case .disk:
            return [
                NotificationThreshold(
                    widgetType: .disk,
                    condition: .greaterThanOrEqual,
                    value: 90.0
                )
            ]
        case .battery:
            return [
                NotificationThreshold(
                    widgetType: .battery,
                    condition: .lessThanOrEqual,
                    value: 20.0
                ),
                NotificationThreshold(
                    widgetType: .battery,
                    condition: .lessThanOrEqual,
                    value: 10.0
                )
            ]
        case .gpu:
            return [
                NotificationThreshold(
                    widgetType: .gpu,
                    condition: .greaterThanOrEqual,
                    value: 90.0
                )
            ]
        case .network:
            return [] // Network thresholds are user-configured
        case .weather:
            return [] // Weather notifications not typically threshold-based
        case .sensors:
            return [
                NotificationThreshold(
                    widgetType: .sensors,
                    condition: .greaterThanOrEqual,
                    value: 90.0
                )
            ]
        case .bluetooth:
            return [] // Bluetooth thresholds not typically needed
        }
    }
}
