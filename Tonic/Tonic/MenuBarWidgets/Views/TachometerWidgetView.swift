//
//  TachometerWidgetView.swift
//  Tonic
//
//  Tachometer widget view for circular gauge display
//  Matches Stats Master's Tachometer functionality
//  Task ID: fn-5-v8r.9
//

import SwiftUI

// MARK: - Tachometer Config

/// Configuration for tachometer display
public struct TachometerConfig: Sendable, Equatable {
    public let size: CGFloat
    public let minValue: Double
    public let maxValue: Double
    public let showNeedle: Bool
    public let showLabel: Bool
    public let colorMode: TachometerColorMode

    public init(
        size: CGFloat = 24,
        minValue: Double = 0,
        maxValue: Double = 100,
        showNeedle: Bool = true,
        showLabel: Bool = true,
        colorMode: TachometerColorMode = .dynamic
    ) {
        self.size = max(18, size)
        self.minValue = minValue
        self.maxValue = maxValue
        self.showNeedle = showNeedle
        self.showLabel = showLabel
        self.colorMode = colorMode
    }
}

/// Color mode for tachometer
public enum TachometerColorMode: String, Sendable, Equatable {
    case dynamic    // Color changes based on value position
    case fixed      // Single color
    case zones      // Color zones (green/yellow/red)
}

// MARK: - Tachometer Widget View

/// Tachometer widget for displaying circular gauge values
/// Ideal for: RPM, percentage with visual arc
public struct TachometerWidgetView: View {
    private let value: Double
    private let config: TachometerConfig
    private let fixedColor: Color

    public init(
        value: Double,
        config: TachometerConfig = TachometerConfig(),
        fixedColor: Color = .accentColor
    ) {
        self.value = value
        self.config = config
        self.fixedColor = fixedColor
    }

    public var body: some View {
        HStack(spacing: 6) {
            ZStack {
                // Background arc (270 degrees - leaving bottom open)
                backgroundArc

                // Value arc
                valueArc

                // Needle
                if config.showNeedle {
                    needle
                }

                // Center dot
                Circle()
                    .fill(.primary)
                    .frame(width: 2, height: 2)
            }
            .frame(width: config.size, height: config.size)

            // Optional label
            if config.showLabel {
                VStack(alignment: .leading, spacing: 0) {
                    Text(displayValue)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(effectiveColor)

                    Text(label)
                        .font(.system(size: 7))
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(height: 22)
        .padding(.horizontal, 4)
    }

    private var displayValue: String {
        let clamped = max(config.minValue, min(config.maxValue, value))
        if clamped >= 1000 {
            return String(format: "%.1fK", clamped / 1000)
        }
        return String(format: "%.0f", clamped)
    }

    private var label: String {
        if config.maxValue > 1000 {
            return "RPM"
        }
        return "%"
    }

    private var normalizedValue: Double {
        let range = config.maxValue - config.minValue
        guard range > 0 else { return 0 }
        return (value - config.minValue) / range
    }

    private var effectiveColor: Color {
        switch config.colorMode {
        case .fixed:
            return fixedColor
        case .dynamic:
            return colorForNormalizedValue(normalizedValue)
        case .zones:
            return colorForZones(normalizedValue)
        }
    }

    private var backgroundArc: some View {
        Path { path in
            let center = CGPoint(x: config.size / 2, y: config.size / 2)
            let radius = (config.size / 2) - 2

            var startAngle = Angle.degrees(135)
            let endAngle = Angle.degrees(405)

            path.addArc(
                center: center,
                radius: radius,
                startAngle: startAngle,
                endAngle: endAngle,
                clockwise: false
            )
        }
        .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 2)
    }

    private var valueArc: some View {
        Path { path in
            let center = CGPoint(x: config.size / 2, y: config.size / 2)
            let radius = (config.size / 2) - 2

            let startAngle = Angle.degrees(135)
            let endAngle = Angle.degrees(135 + (normalizedValue * 270))

            path.addArc(
                center: center,
                radius: radius,
                startAngle: startAngle,
                endAngle: endAngle,
                clockwise: false
            )
        }
        .stroke(
            effectiveColor,
            style: StrokeStyle(lineWidth: 2, lineCap: .round)
        )
        .animation(.easeInOut(duration: 0.2), value: normalizedValue)
    }

    private var needle: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = (geometry.size.width / 2) - 4
            let angle = Angle.degrees(135 + (normalizedValue * 270))

            let endX = center.x + radius * CGFloat(cos(angle.radians - .pi / 2))
            let endY = center.y + radius * CGFloat(sin(angle.radians - .pi / 2))

            Path { path in
                path.move(to: center)
                path.addLine(to: CGPoint(x: endX, y: endY))
            }
            .stroke(.primary, style: StrokeStyle(lineWidth: 1, lineCap: .round))
            .animation(.easeInOut(duration: 0.2), value: normalizedValue)
        }
        .frame(width: config.size, height: config.size)
    }

    private func colorForNormalizedValue(_ value: Double) -> Color {
        // Gradient from green to red
        if value < 0.5 {
            return .green
        } else if value < 0.8 {
            return .orange
        } else {
            return .red
        }
    }

    private func colorForZones(_ value: Double) -> Color {
        // Distinct color zones
        if value < 0.33 {
            return .green
        } else if value < 0.66 {
            return .yellow
        } else {
            return .red
        }
    }
}

// MARK: - Gauge View (Simpler variant)

/// Simplified gauge without needle
public struct GaugeView: View {
    let value: Double
    let size: CGFloat
    let color: Color

    public init(value: Double, size: CGFloat = 20, color: Color = .accentColor) {
        self.value = max(0, min(1, value))
        self.size = size
        self.color = color
    }

    public var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 3)
                .frame(width: size, height: size)

            // Value arc (240 degrees - leaving bottom open)
            Circle()
                .trim(from: 0, to: value * 0.67)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(240 - 180))
                .frame(width: size, height: size)
                .animation(.easeOut(duration: 0.3), value: value)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Fan RPM Gauge (for fans)

/// RPM gauge specifically for fan speeds - compact circular gauge
public struct FanRPMGaugeView: View {
    let rpm: Double
    let maxRPM: Double
    let size: CGFloat

    public init(rpm: Double, maxRPM: Double = 3000, size: CGFloat = 28) {
        self.rpm = rpm
        self.maxRPM = maxRPM
        self.size = size
    }

    public var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 2)
                    .frame(width: size, height: size)

                Circle()
                    .trim(from: 0, to: (rpm / maxRPM) * 0.75)
                    .stroke(
                        rpmColor,
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                    .rotationEffect(.degrees(225))
                    .frame(width: size, height: size)

                // RPM label
                VStack(spacing: 0) {
                    if rpm >= 1000 {
                        Text("\(Int(rpm / 1000))K")
                            .font(.system(size: 8, weight: .bold))
                    } else {
                        Text("\(Int(rpm))")
                            .font(.system(size: 8, weight: .bold))
                    }
                    Text("RPM")
                        .font(.system(size: 5))
                        .foregroundColor(.secondary)
                }
                .offset(y: 2)
            }
            .frame(width: size, height: size)

            // Fan label
            Text("FAN")
                .font(.system(size: 6, weight: .medium))
                .foregroundColor(.secondary)
        }
    }

    private var rpmColor: Color {
        let ratio = rpm / maxRPM
        switch ratio {
        case 0..<0.6: return .green
        case 0.6..<0.85: return .orange
        default: return .red
        }
    }
}

// MARK: - Preview

#Preview("Tachometer Widget") {
    VStack(spacing: 24) {
        // Tachometer with different values
        HStack(spacing: 16) {
            TachometerWidgetView(value: 25)
            TachometerWidgetView(value: 50)
            TachometerWidgetView(value: 75)
            TachometerWidgetView(value: 95)
        }

        // RPM style
        HStack(spacing: 16) {
            TachometerWidgetView(
                value: 1850,
                config: TachometerConfig(
                    maxValue: 3000,
                    showLabel: true
                ),
                fixedColor: .green
            )
            TachometerWidgetView(
                value: 2400,
                config: TachometerConfig(
                    maxValue: 3000,
                    showLabel: true
                ),
                fixedColor: .orange
            )
            TachometerWidgetView(
                value: 2800,
                config: TachometerConfig(
                    maxValue: 3000,
                    showLabel: true
                ),
                fixedColor: .red
            )
        }

        // Different color modes
        HStack(spacing: 16) {
            TachometerWidgetView(
                value: 60,
                config: TachometerConfig(colorMode: .fixed),
                fixedColor: .blue
            )
            TachometerWidgetView(
                value: 60,
                config: TachometerConfig(colorMode: .dynamic)
            )
            TachometerWidgetView(
                value: 60,
                config: TachometerConfig(colorMode: .zones)
            )
        }

        // Simple gauges
        HStack(spacing: 12) {
            GaugeView(value: 0.3, size: 18, color: .green)
            GaugeView(value: 0.5, size: 18, color: .yellow)
            GaugeView(value: 0.8, size: 18, color: .orange)
            GaugeView(value: 0.95, size: 18, color: .red)
        }

        // RPM gauges
        HStack(spacing: 16) {
            FanRPMGaugeView(rpm: 1200, maxRPM: 3000, size: 32)
            FanRPMGaugeView(rpm: 1850, maxRPM: 3000, size: 32)
            FanRPMGaugeView(rpm: 2400, maxRPM: 3000, size: 32)
        }
    }
    .padding()
}
