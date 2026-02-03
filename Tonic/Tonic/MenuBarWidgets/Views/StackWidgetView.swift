//
//  StackWidgetView.swift
//  Tonic
//
//  Stack/Sensors widget view for multiple related values
//  Matches Stats Master's Stack widget functionality
//  Task ID: fn-5-v8r.9
//

import SwiftUI

// MARK: - Stack Widget Config

/// Configuration for stack widget display
public struct StackWidgetConfig: Sendable, Equatable {
    public let orientation: StackOrientation
    public let showLabels: Bool
    public let showValues: Bool
    public let labelWidth: CGFloat

    public init(
        orientation: StackOrientation = .vertical,
        showLabels: Bool = true,
        showValues: Bool = true,
        labelWidth: CGFloat = 40
    ) {
        self.orientation = orientation
        self.showLabels = showLabels
        self.showValues = showValues
        self.labelWidth = labelWidth
    }
}

/// Orientation of stack layout
public enum StackOrientation: String, Sendable, Equatable {
    case vertical
    case horizontal
}

// MARK: - Sensor Item

/// A single sensor reading in the stack
public struct SensorItem: Identifiable, Sendable {
    public let id = UUID()
    public let name: String
    public let value: Double
    public let unit: String
    public let color: Color?

    public init(name: String, value: Double, unit: String = "", color: Color? = nil) {
        self.name = name
        self.value = value
        self.unit = unit
        self.color = color
    }

    public var formattedValue: String {
        if unit.isEmpty {
            return String(format: "%.1f", value)
        } else {
            return "\(Int(value))\(unit)"
        }
    }
}

// MARK: - Stack Widget View

/// Stack widget for displaying multiple sensor values
/// Ideal for: Temperature, fan speeds in one widget
public struct StackWidgetView: View {
    private let items: [SensorItem]
    private let config: StackWidgetConfig

    public init(
        items: [SensorItem],
        config: StackWidgetConfig = StackWidgetConfig()
    ) {
        self.items = items
        self.config = config
    }

    public var body: some View {
        Group {
            if config.orientation == .vertical {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(items) { item in
                        sensorRow(for: item)
                    }
                }
            } else {
                HStack(spacing: 8) {
                    ForEach(items) { item in
                        sensorRow(for: item)
                    }
                }
            }
        }
        .frame(height: 22)
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private func sensorRow(for item: SensorItem) -> some View {
        let effectiveColor = item.color ?? colorForValue(item.value)

        switch config.orientation {
        case .vertical:
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    if config.showLabels {
                        Text(item.name)
                            .font(.system(size: 7))
                            .foregroundColor(.secondary)
                            .frame(width: config.labelWidth, alignment: .leading)
                    }

                    if config.showValues {
                        Text(item.formattedValue)
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundColor(effectiveColor)
                    }

                    Spacer()

                    // Mini bar indicator
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color(nsColor: .separatorColor).opacity(0.3))
                                .frame(height: 3)

                            RoundedRectangle(cornerRadius: 1)
                                .fill(effectiveColor)
                                .frame(width: geometry.size.width * CGFloat(min(1, item.value)), height: 3)
                        }
                    }
                    .frame(height: 3)
                }
            }

        case .horizontal:
            VStack(alignment: .leading, spacing: 0) {
                if config.showLabels {
                    Text(item.name)
                        .font(.system(size: 7))
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 4) {
                    if config.showValues {
                        Text(item.formattedValue)
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundColor(effectiveColor)
                    }

                    // Mini bar indicator
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color(nsColor: .separatorColor).opacity(0.3))
                                .frame(height: 3)

                            RoundedRectangle(cornerRadius: 1)
                                .fill(effectiveColor)
                                .frame(width: geo.size.width * CGFloat(min(1, item.value)), height: 3)
                        }
                    }
                    .frame(height: 3)
                }
            }
        }
    }

    private func colorForValue(_ value: Double) -> Color {
        // For temperatures/fans, assume higher = hotter/faster
        // Normalize typical range: 0-100 for fans, 0-100°C for temps
        let normalized = value / 100
        switch normalized {
        case 0..<0.5: return .green
        case 0.5..<0.8: return .orange
        default: return .red
        }
    }
}

// MARK: - Compact Stack View

/// Compact stack for tight menu bar display
public struct CompactStackView: View {
    let items: [SensorItem]
    let color: Color

    public init(items: [SensorItem], color: Color = .accentColor) {
        self.items = items
        self.color = color
    }

    public var body: some View {
        HStack(spacing: 4) {
            ForEach(items.prefix(3)) { item in
                VStack(spacing: 0) {
                    Text(item.name.prefix(1))
                        .font(.system(size: 6, weight: .bold))
                        .foregroundColor(.secondary)

                    Text(item.formattedValue)
                        .font(.system(size: 7, weight: .medium))
                        .foregroundColor(color)
                }
                .frame(width: 14)
            }
        }
        .frame(height: 22)
    }
}

// MARK: - Preview

#Preview("Stack Widget") {
    VStack(spacing: 20) {
        // Temperature sensors
        VStack(alignment: .leading, spacing: 4) {
            Text("Temperature Sensors")
                .font(.caption)
                .foregroundColor(.secondary)

            StackWidgetView(
                items: [
                    SensorItem(name: "CPU", value: 65, unit: "°C", color: .orange),
                    SensorItem(name: "GPU", value: 58, unit: "°C", color: .blue),
                    SensorItem(name: "SOC", value: 72, unit: "°C", color: .red)
                ],
                config: StackWidgetConfig(orientation: .vertical)
            )
        }

        // Fan speeds
        VStack(alignment: .leading, spacing: 4) {
            Text("Fan Speeds")
                .font(.caption)
                .foregroundColor(.secondary)

            StackWidgetView(
                items: [
                    SensorItem(name: "Fan 1", value: 1850, unit: " RPM"),
                    SensorItem(name: "Fan 2", value: 2100, unit: " RPM")
                ],
                config: StackWidgetConfig(orientation: .vertical, labelWidth: 35)
            )
        }

        // Horizontal orientation
        VStack(alignment: .leading, spacing: 4) {
            Text("Horizontal Stack")
                .font(.caption)
                .foregroundColor(.secondary)

            StackWidgetView(
                items: [
                    SensorItem(name: "CPU", value: 72, unit: "°C"),
                    SensorItem(name: "MEM", value: 45, unit: "°C"),
                    SensorItem(name: "BAT", value: 38, unit: "°C")
                ],
                config: StackWidgetConfig(orientation: .horizontal)
            )
        }

        // Compact view
        VStack(alignment: .leading, spacing: 4) {
            Text("Compact Stack")
                .font(.caption)
                .foregroundColor(.secondary)

            CompactStackView(
                items: [
                    SensorItem(name: "CPU", value: 65, unit: "°C"),
                    SensorItem(name: "MEM", value: 45, unit: "°C"),
                    SensorItem(name: "GPU", value: 58, unit: "°C")
                ],
                color: .orange
            )
        }
    }
    .padding()
}
