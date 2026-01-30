//
//  PieChartWidgetView.swift
//  Tonic
//
//  Pie Chart widget view for percentage visualization
//  Matches Stats Master's Pie Chart functionality
//  Task ID: fn-5-v8r.8
//

import SwiftUI

// MARK: - Pie Chart Config

/// Configuration for pie chart display
public struct PieChartConfig: Sendable, Equatable {
    public let size: CGFloat
    public let strokeWidth: CGFloat
    public let showBackgroundCircle: Bool
    public let showLabel: Bool
    public let colorMode: PieColorMode

    public init(
        size: CGFloat = 18,
        strokeWidth: CGFloat = 3,
        showBackgroundCircle: Bool = true,
        showLabel: Bool = false,
        colorMode: PieColorMode = .dynamic
    ) {
        self.size = max(12, size)
        self.strokeWidth = max(1, strokeWidth)
        self.showBackgroundCircle = showBackgroundCircle
        self.showLabel = showLabel
        self.colorMode = colorMode
    }
}

/// Color mode for pie chart
public enum PieColorMode: String, Sendable, Equatable {
    case dynamic  // Color based on value
    case fixed    // Fixed color provided
    case gradient // Gradient around the circle
}

// MARK: - Pie Chart Widget View

/// Pie chart widget for displaying percentage values
/// Ideal for: Battery level, disk usage
public struct PieChartWidgetView: View {
    private let value: Double  // 0.0 to 1.0
    private let config: PieChartConfig
    private let fixedColor: Color

    public init(
        value: Double,
        config: PieChartConfig = PieChartConfig(),
        fixedColor: Color = .accentColor
    ) {
        self.value = max(0, min(1, value))
        self.config = config
        self.fixedColor = fixedColor
    }

    public var body: some View {
        HStack(spacing: 6) {
            // Pie chart circle
            ZStack {
                // Background circle
                if config.showBackgroundCircle {
                    Circle()
                        .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: config.strokeWidth)
                        .frame(width: config.size, height: config.size)
                }

                // Value arc
                Circle()
                    .trim(from: 0, to: value)
                    .stroke(
                        effectiveColor,
                        style: StrokeStyle(
                            lineWidth: config.strokeWidth,
                            lineCap: .round
                        )
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: config.size, height: config.size)
                    .animation(.easeInOut(duration: 0.3), value: value)
            }
            .frame(width: config.size, height: config.size)

            // Optional label
            if config.showLabel {
                Text("\(Int(value * 100))%")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(effectiveColor)
                    .frame(minWidth: 32, alignment: .leading)
            }
        }
        .frame(height: 22)
        .padding(.horizontal, 4)
    }

    private var effectiveColor: Color {
        switch config.colorMode {
        case .fixed:
            return fixedColor
        case .dynamic:
            return colorForValue(value)
        case .gradient:
            // Would require gradient stroke - not directly supported
            // Fall back to dynamic coloring
            return colorForValue(value)
        }
    }

    private func colorForValue(_ value: Double) -> Color {
        switch value {
        case 0..<0.2: return .red
        case 0.2..<0.5: return .orange
        case 0.5..<0.8: return .yellow
        default: return .green
        }
    }
}

// MARK: - Donut Chart Variant

/// Donut chart with label in center
public struct DonutChartView: View {
    let value: Double
    let size: CGFloat
    let strokeWidth: CGFloat
    let colors: (filled: Color, background: Color)

    public init(
        value: Double,
        size: CGFloat = 32,
        strokeWidth: CGFloat = 4,
        colors: (filled: Color, background: Color) = (.green, .gray)
    ) {
        self.value = max(0, min(1, value))
        self.size = size
        self.strokeWidth = strokeWidth
        self.colors = colors
    }

    public var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(colors.background.opacity(0.3), lineWidth: strokeWidth)

            // Value arc
            Circle()
                .trim(from: 0, to: value)
                .stroke(
                    colors.filled,
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Center label
            Text("\(Int(value * 100))")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(colors.filled)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Segmented Donut (Multi-value)

/// Donut chart showing multiple segments
public struct SegmentedDonutView: View {
    let segments: [(value: Double, color: Color)]
    let size: CGFloat
    let strokeWidth: CGFloat

    public init(
        segments: [(value: Double, color: Color)],
        size: CGFloat = 32,
        strokeWidth: CGFloat = 6
    ) {
        self.segments = segments
        self.size = size
        self.strokeWidth = strokeWidth
    }

    public var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: strokeWidth)

            // Value arcs
            let total = segments.reduce(0) { $0 + $1.value }
            var currentAngle = 0.0

            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                let segmentAngle = (segment.value / max(total, 0.001)) * 360

                Circle()
                    .trim(from: 0, to: segment.value / max(total, 0.001))
                    .stroke(
                        segment.color,
                        style: StrokeStyle(lineWidth: strokeWidth, lineCap: .butt)
                    )
                    .rotationEffect(.degrees(-90 + currentAngle))
                    .animation(.easeInOut(duration: 0.3), value: segment.value)

                currentAngle += segmentAngle
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Preview

#Preview("Pie Chart Widget") {
    VStack(spacing: 20) {
        HStack(spacing: 16) {
            // Different values
            PieChartWidgetView(value: 0.85, config: PieChartConfig(showLabel: true))
            PieChartWidgetView(value: 0.45, config: PieChartConfig(showLabel: true))
            PieChartWidgetView(value: 0.15, config: PieChartConfig(showLabel: true))
        }

        HStack(spacing: 16) {
            // Different sizes
            PieChartWidgetView(value: 0.72, config: PieChartConfig(size: 14, strokeWidth: 2))
            PieChartWidgetView(value: 0.72, config: PieChartConfig(size: 18, strokeWidth: 3))
            PieChartWidgetView(value: 0.72, config: PieChartConfig(size: 24, strokeWidth: 4))
        }

        // Battery style
        HStack(spacing: 16) {
            PieChartWidgetView(
                value: 0.92,
                config: PieChartConfig(colorMode: .dynamic, showLabel: true)
            )
            PieChartWidgetView(
                value: 0.35,
                config: PieChartConfig(colorMode: .dynamic, showLabel: true)
            )
            PieChartWidgetView(
                value: 0.12,
                config: PieChartConfig(colorMode: .dynamic, showLabel: true)
            )
        }

        // Donut charts
        HStack(spacing: 16) {
            DonutChartView(value: 0.75, colors: (.green, .gray))
            DonutChartView(value: 0.45, colors: (.blue, .gray))
            DonutChartView(value: 0.25, colors: (.orange, .gray))
        }

        // Segmented donut
        SegmentedDonutView(
            segments: [
                (0.5, .blue),
                (0.3, .green),
                (0.15, .orange),
                (0.05, .red)
            ],
            size: 48
        )

        // Disk usage style
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                PieChartWidgetView(value: 0.68, config: PieChartConfig(showLabel: false))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Macintosh HD")
                        .font(.caption)
                        .foregroundColor(.primary)
                    Text("68% used • 256 GB free")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
    .padding()
}
