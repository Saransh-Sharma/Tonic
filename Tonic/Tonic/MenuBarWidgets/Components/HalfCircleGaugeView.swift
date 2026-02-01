//
//  HalfCircleGaugeView.swift
//  Tonic
//
//  Semi-circle gauge for single-value data visualization
//  Displays temperature, frequency, and other single metrics
//  Task ID: fn-6-i4g.30
//

import SwiftUI

// MARK: - Half Circle Gauge View

/// Semi-circle gauge for displaying single value with progress fill
/// Ideal for: Temperature, frequency, pressure, and other single metrics
///
/// Example:
/// ```swift
/// HalfCircleGaugeView(
///     value: 45,
///     maxValue: 100,
///     label: "Temperature",
///     unit: "°C",
///     color: .orange
/// )
/// ```
public struct HalfCircleGaugeView: View {
    // MARK: - Properties

    private let value: Double
    private let maxValue: Double
    private let minValue: Double
    private let label: String?
    private let unit: String?
    private let color: Color
    private let size: CGSize
    private let lineWidth: CGFloat

    // MARK: - Computed Properties

    private var fillFraction: Double {
        let range = maxValue - minValue
        guard range > 0 else { return 0 }
        let clamped = max(minValue, min(maxValue, value))
        return (clamped - minValue) / range
    }

    private var displayValue: String {
        let clamped = max(minValue, min(maxValue, value))

        // Format based on value magnitude
        if clamped >= 1000000 {
            return String(format: "%.1fM", clamped / 1000000)
        } else if clamped >= 1000 {
            return String(format: "%.1fK", clamped / 1000)
        } else if clamped >= 100 {
            return String(format: "%.0f", clamped)
        } else if clamped >= 10 {
            return String(format: "%.1f", clamped)
        } else {
            return String(format: "%.2f", clamped)
        }
    }

    // MARK: - Initializer

    /// Initialize a half-circle gauge
    /// - Parameters:
    ///   - value: Current value to display
    ///   - maxValue: Maximum value for the gauge
    ///   - minValue: Minimum value for the gauge (default: 0)
    ///   - label: Optional label text below the gauge
    ///   - unit: Optional unit symbol to append to value
    ///   - color: Progress fill color (default: accent)
    ///   - size: Width x height of the gauge (default: 80x50)
    ///   - lineWidth: Stroke width of the gauge arc (default: 10)
    public init(
        value: Double,
        maxValue: Double,
        minValue: Double = 0,
        label: String? = nil,
        unit: String? = nil,
        color: Color = Color.accentColor,
        size: CGSize = CGSize(width: 80, height: 50),
        lineWidth: CGFloat = 10
    ) {
        self.value = value
        self.maxValue = maxValue
        self.minValue = minValue
        self.label = label
        self.unit = unit
        self.color = color
        self.size = size
        self.lineWidth = lineWidth
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 4) {
            // Gauge arc and value
            gaugeContent

            // Optional label
            if let label = label {
                Text(label)
                    .font(.system(size: max(8, size.height * 0.16)))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
        }
        .frame(width: size.width, height: size.height + (label != nil ? 16 : 0))
    }

    // MARK: - View Components

    private var gaugeContent: some View {
        ZStack {
            // Background semi-circle
            backgroundArc

            // Fill semi-circle
            fillArc

            // Value text
            valueText
        }
        .frame(width: size.width, height: size.height)
    }

    private var backgroundArc: some View {
        Path { path in
            let center = CGPoint(x: size.width / 2, y: size.height - lineWidth / 2)
            let radius = (size.width - lineWidth) / 2

            path.addArc(
                center: center,
                radius: radius,
                startAngle: .degrees(180),
                endAngle: .degrees(0),
                clockwise: false
            )
        }
        .stroke(
            color.opacity(0.2),
            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
        )
    }

    private var fillArc: some View {
        Path { path in
            let center = CGPoint(x: size.width / 2, y: size.height - lineWidth / 2)
            let radius = (size.width - lineWidth) / 2

            // Calculate end angle based on fill fraction
            let endAngle = Angle.degrees(180 + (fillFraction * 180))

            path.addArc(
                center: center,
                radius: radius,
                startAngle: .degrees(180),
                endAngle: endAngle,
                clockwise: false
            )
        }
        .stroke(
            color,
            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
        )
        .animation(.easeInOut(duration: 0.3), value: fillFraction)
    }

    private var valueText: some View {
        Text("\(displayValue)\(unit ?? "")")
            .font(.system(size: size.width * 0.15, weight: .medium))
            .foregroundColor(DesignTokens.Colors.textPrimary)
            .offset(y: size.height * 0.15)
    }
}

// MARK: - Temperature Gauge (Convenience)

/// Pre-configured half-circle gauge for temperature display
public struct TemperatureGaugeView: View {
    private let temperature: Double
    private let maxTemperature: Double
    private let size: CGSize
    private let showLabel: Bool

    public init(
        temperature: Double,
        maxTemperature: Double = 100,
        size: CGSize = CGSize(width: 80, height: 50),
        showLabel: Bool = true
    ) {
        self.temperature = temperature
        self.maxTemperature = maxTemperature
        self.size = size
        self.showLabel = showLabel
    }

    public var body: some View {
        let tempColor = colorForTemperature(temperature)

        HalfCircleGaugeView(
            value: temperature,
            maxValue: maxTemperature,
            label: showLabel ? "Temp" : nil,
            unit: "°C",
            color: tempColor,
            size: size
        )
    }

    private func colorForTemperature(_ temp: Double) -> Color {
        switch temp {
        case 0..<50: return TonicColors.success
        case 50..<75: return TonicColors.warning
        default: return TonicColors.error
        }
    }
}

// MARK: - Frequency Gauge (Convenience)

/// Pre-configured half-circle gauge for CPU frequency display
public struct FrequencyGaugeView: View {
    private let frequency: Double  // in GHz
    private let maxFrequency: Double  // in GHz
    private let size: CGSize
    private let showLabel: Bool

    public init(
        frequency: Double,
        maxFrequency: Double = 5.0,
        size: CGSize = CGSize(width: 80, height: 50),
        showLabel: Bool = true
    ) {
        self.frequency = frequency
        self.maxFrequency = maxFrequency
        self.size = size
        self.showLabel = showLabel
    }

    public var body: some View {
        HalfCircleGaugeView(
            value: frequency,
            maxValue: maxFrequency,
            label: showLabel ? "Freq" : nil,
            unit: "GHz",
            color: .purple,
            size: size
        )
    }
}

// MARK: - RPM Gauge (Convenience)

/// Pre-configured half-circle gauge for fan RPM display
public struct RPMGaugeView: View {
    private let rpm: Double
    private let maxRPM: Double
    private let size: CGSize
    private let showLabel: Bool

    public init(
        rpm: Double,
        maxRPM: Double = 3000,
        size: CGSize = CGSize(width: 80, height: 50),
        showLabel: Bool = true
    ) {
        self.rpm = rpm
        self.maxRPM = maxRPM
        self.size = size
        self.showLabel = showLabel
    }

    public var body: some View {
        let rpmColor = colorForRPM(rpm)

        HalfCircleGaugeView(
            value: rpm,
            maxValue: maxRPM,
            label: showLabel ? "RPM" : nil,
            unit: "",
            color: rpmColor,
            size: size
        )
    }

    private func colorForRPM(_ rpm: Double) -> Color {
        let ratio = rpm / maxRPM
        switch ratio {
        case 0..<0.6: return TonicColors.success
        case 0.6..<0.85: return TonicColors.warning
        default: return TonicColors.error
        }
    }
}

// MARK: - Pressure Gauge (Convenience)

/// Pre-configured half-circle gauge for pressure display
public struct PressureGaugeView: View {
    private let pressure: Double
    private let maxPressure: Double
    private let size: CGSize
    private let showLabel: Bool

    public init(
        pressure: Double,
        maxPressure: Double = 100,
        size: CGSize = CGSize(width: 80, height: 50),
        showLabel: Bool = true
    ) {
        self.pressure = pressure
        self.maxPressure = maxPressure
        self.size = size
        self.showLabel = showLabel
    }

    public var body: some View {
        HalfCircleGaugeView(
            value: pressure,
            maxValue: maxPressure,
            label: showLabel ? "Pressure" : nil,
            unit: "hPa",
            color: .blue,
            size: size
        )
    }
}

// MARK: - Preview

#Preview("Half Circle Gauge") {
    VStack(spacing: 32) {
        // Temperature gauges
        HStack(spacing: 24) {
            TemperatureGaugeView(temperature: 35)
            TemperatureGaugeView(temperature: 55)
            TemperatureGaugeView(temperature: 85)
        }

        // Frequency gauges
        HStack(spacing: 24) {
            FrequencyGaugeView(frequency: 0.8)
            FrequencyGaugeView(frequency: 2.4)
            FrequencyGaugeView(frequency: 4.2)
        }

        // RPM gauges
        HStack(spacing: 24) {
            RPMGaugeView(rpm: 800, maxRPM: 2000)
            RPMGaugeView(rpm: 1200, maxRPM: 2000)
            RPMGaugeView(rpm: 1800, maxRPM: 2000)
        }

        // Different sizes
        HStack(spacing: 24) {
            HalfCircleGaugeView(
                value: 60,
                maxValue: 100,
                label: "Load",
                unit: "%",
                color: .blue,
                size: CGSize(width: 60, height: 40)
            )

            HalfCircleGaugeView(
                value: 60,
                maxValue: 100,
                label: "Load",
                unit: "%",
                color: .blue,
                size: CGSize(width: 80, height: 50)
            )

            HalfCircleGaugeView(
                value: 60,
                maxValue: 100,
                label: "Load",
                unit: "%",
                color: .blue,
                size: CGSize(width: 100, height: 65)
            )
        }

        // Custom colors
        HStack(spacing: 24) {
            HalfCircleGaugeView(
                value: 75,
                maxValue: 100,
                label: "Speed",
                unit: "Mbps",
                color: .green
            )

            HalfCircleGaugeView(
                value: 50,
                maxValue: 100,
                label: "Quality",
                unit: "%",
                color: .orange
            )

            HalfCircleGaugeView(
                value: 90,
                maxValue: 100,
                label: "Level",
                unit: "%",
                color: .red
            )
        }

        // Dark mode preview
        HStack(spacing: 24) {
            TemperatureGaugeView(temperature: 65)
                .background(Color.black.opacity(0.8))
                .cornerRadius(8)

            FrequencyGaugeView(frequency: 3.2)
                .background(Color.black.opacity(0.8))
                .cornerRadius(8)
        }

        // Dashboard example (like CPU dashboard row)
        VStack(spacing: 12) {
            Text("Dashboard Example")
                .font(.headline)
                .foregroundColor(.secondary)

            HStack(spacing: 24) {
                // Temperature gauge
                TemperatureGaugeView(
                    temperature: 55,
                    size: CGSize(width: 80, height: 50)
                )

                // Frequency gauge
                FrequencyGaugeView(
                    frequency: 3.2,
                    maxFrequency: 5.0,
                    size: CGSize(width: 80, height: 50)
                )

                // Custom usage gauge
                HalfCircleGaugeView(
                    value: 68,
                    maxValue: 100,
                    label: "Usage",
                    unit: "%",
                    color: .blue,
                    size: CGSize(width: 80, height: 50)
                )
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
        }
    }
    .padding()
}
