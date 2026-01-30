//
//  BarChartWidgetView.swift
//  Tonic
//
//  Bar Chart widget view for multi-value data visualization
//  Matches Stats Master's Bar Chart functionality
//  Task ID: fn-5-v8r.8
//

import SwiftUI

// MARK: - Bar Chart Config

/// Configuration for bar chart display
public struct BarChartConfig: Sendable, Equatable {
    public let barWidth: CGFloat
    public let barSpacing: CGFloat
    public let showLabels: Bool
    public let colorMode: BarColorMode

    public init(
        barWidth: CGFloat = 4,
        barSpacing: CGFloat = 2,
        showLabels: Bool = false,
        colorMode: BarColorMode = .uniform
    ) {
        self.barWidth = max(1, barWidth)
        self.barSpacing = barSpacing
        self.showLabels = showLabels
        self.colorMode = colorMode
    }
}

/// Color mode for bars
public enum BarColorMode: String, Sendable, Equatable {
    case uniform
    case gradient
    case byValue
    case byCategory
}

// MARK: - Bar Chart Widget View

/// Bar chart widget for displaying multi-value data
/// Ideal for: CPU cores, memory zones
public struct BarChartWidgetView: View {
    private let data: [Double]
    private let config: BarChartConfig
    private let baseColor: Color

    public init(
        data: [Double],
        config: BarChartConfig = BarChartConfig(),
        baseColor: Color = .accentColor
    ) {
        self.data = data
        self.config = config
        self.baseColor = baseColor
    }

    public var body: some View {
        HStack(spacing: config.barSpacing) {
            ForEach(Array(data.enumerated()), id: \.offset) { index, value in
                barView(for: value, at: index)
            }
        }
        .frame(height: 22)
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private func barView(for value: Double, at index: Int) -> some View {
        VStack(spacing: 2) {
            if config.showLabels {
                Text("\(Int(value * 100))")
                    .font(.system(size: 6, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(height: 8)
            }

            GeometryReader { geometry in
                let barHeight = max(2, geometry.size.height * CGFloat(value))
                let yPosition = geometry.size.height - barHeight

                RoundedRectangle(cornerRadius: 1)
                    .fill(barColor(for: value, at: index))
                    .frame(width: config.barWidth, height: barHeight)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        .frame(width: config.barWidth, height: 22)
    }

    private func barColor(for value: Double, at index: Int) -> Color {
        switch config.colorMode {
        case .uniform:
            return baseColor
        case .gradient:
            // Gradient from first to last bar
            let ratio = data.count > 1 ? Double(index) / Double(data.count - 1) : 0
            return baseColor.opacity(0.4 + (0.6 * ratio))
        case .byValue:
            return colorForValue(value)
        case .byCategory:
            // Different color per category (index-based)
            let colors: [Color] = [.blue, .green, .orange, .purple, .red, .yellow, .pink, .cyan]
            return colors[index % colors.count]
        }
    }

    private func colorForValue(_ value: Double) -> Color {
        switch value {
        case 0..<0.5: return .green
        case 0.5..<0.8: return .orange
        default: return .red
        }
    }
}

// MARK: - Mini Bar Chart (Compact)

/// Compact horizontal bar chart for single value display
public struct MiniBarChartView: View {
    let value: Double
    let color: Color
    let height: CGFloat

    public init(value: Double, color: Color = .accentColor, height: CGFloat = 4) {
        self.value = value
        self.color = color
        self.height = max(2, height)
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .frame(height: height)

                RoundedRectangle(cornerRadius: height / 2)
                    .fill(color)
                    .frame(width: geometry.size.width * CGFloat(value), height: height)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Preview

#Preview("Bar Chart Widget") {
    VStack(spacing: 16) {
        // CPU cores
        VStack(alignment: .leading, spacing: 4) {
            Text("CPU Cores")
                .font(.caption)
                .foregroundColor(.secondary)
            BarChartWidgetView(
                data: [0.45, 0.72, 0.38, 0.56, 0.29, 0.81, 0.44, 0.67],
                config: BarChartConfig(barWidth: 4, barSpacing: 2),
                baseColor: .blue
            )
        }

        // Memory zones
        VStack(alignment: .leading, spacing: 4) {
            Text("Memory Zones")
                .font(.caption)
                .foregroundColor(.secondary)
            BarChartWidgetView(
                data: [0.82, 0.45, 0.67, 0.23],
                config: BarChartConfig(barWidth: 6, barSpacing: 3, colorMode: .gradient),
                baseColor: .purple
            )
        }

        // With labels
        VStack(alignment: .leading, spacing: 4) {
            Text("With Labels")
                .font(.caption)
                .foregroundColor(.secondary)
            BarChartWidgetView(
                data: [0.35, 0.58, 0.72],
                config: BarChartConfig(barWidth: 8, barSpacing: 4, showLabels: true, colorMode: .byValue)
            )
        }

        // Mini bars
        VStack(alignment: .leading, spacing: 8) {
            MiniBarChartView(value: 0.45, color: .green)
            MiniBarChartView(value: 0.72, color: .orange)
            MiniBarChartView(value: 0.28, color: .blue)
        }
        .padding()
    }
    .padding()
}
