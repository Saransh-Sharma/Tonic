//
//  SparklineChart.swift
//  Tonic
//
//  Mini line chart component for network metrics
//  Task ID: fn-2.8.7
//

import SwiftUI
import Charts

// MARK: - Sparkline Chart

/// Mini line chart for displaying metric history
public struct SparklineChart: View {

    // MARK: - Properties

    let data: [Double]
    let color: Color
    let height: CGFloat
    let showArea: Bool
    let lineWidth: CGFloat

    // MARK: - Initialization

    public init(
        data: [Double],
        color: Color = .blue,
        height: CGFloat = 32,
        showArea: Bool = true,
        lineWidth: CGFloat = 1.5
    ) {
        self.data = data
        self.color = color
        self.height = height
        self.showArea = showArea
        self.lineWidth = lineWidth
    }

    // MARK: - Body

    public var body: some View {
        if data.isEmpty || data.allSatisfy({ $0 == 0 }) {
            // Empty state placeholder
            GeometryReader { geometry in
                Path { path in
                    path.move(to: CGPoint(x: 0, y: height / 2))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: height / 2))
                }
                .stroke(
                    color.opacity(0.2),
                    style: StrokeStyle(lineWidth: lineWidth, dash: [4, 4])
                )
            }
            .frame(height: height)
        } else {
            Chart {
                if showArea {
                    AreaMark(
                        x: .value("Index", 0),
                        yStart: .value("Min", normalizedMin),
                        yEnd: .value("Max", normalizedMax)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [color.opacity(0.15), color.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }

                LineMark(
                    x: .value("Index", 0),
                    y: .value("Value", 0)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [color, color.opacity(0.6)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .lineStyle(StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartPlotStyle { plotArea in
                plotArea
                    .background(Color.clear)
            }
            .frame(height: height)
            .chartYScale(domain: normalizedMin...normalizedMax)
            .chartBackground { _ in
                // Draw the actual data points as a path for better control
                sparklinePath
            }
            .overlay {
                sparklinePath
            }
        }
    }

    // MARK: - Computed Properties

    private var normalizedMin: Double {
        let validValues = data.filter { $0 != 0 }
        guard let min = validValues.min(), let max = validValues.max(), max != min else {
            return 0
        }
        return min - (max - min) * 0.1
    }

    private var normalizedMax: Double {
        let validValues = data.filter { $0 != 0 }
        guard let min = validValues.min(), let max = validValues.max(), max != min else {
            return 1
        }
        return max + (max - min) * 0.1
    }

    private var sparklinePath: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height

            let validValues = data.filter { $0 != 0 }
            guard !validValues.isEmpty,
                  let minVal = validValues.min(),
                  let maxVal = validValues.max(),
                  maxVal != minVal else {
                // Fallback to flat line
                return AnyView(
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: height / 2))
                        path.addLine(to: CGPoint(x: width, y: height / 2))
                    }
                    .stroke(color.opacity(0.3), style: StrokeStyle(lineWidth: lineWidth, dash: [4, 4]))
                )
            }

            let range = maxVal - minVal
            let padding = range * 0.1
            let effectiveMin = minVal - padding
            let effectiveMax = maxVal + padding
            let effectiveRange = effectiveMax - effectiveMin

            var points: [CGPoint] = []
            let stepX = width / max(1, Double(data.count - 1))

            for (index, value) in data.enumerated() {
                let x = Double(index) * stepX
                let normalizedY: Double
                if value == 0 {
                    // Use previous value or center
                    normalizedY = 0.5
                } else {
                    normalizedY = 1 - ((value - effectiveMin) / effectiveRange)
                }
                let y = normalizedY * height
                points.append(CGPoint(x: x, y: y))
            }

            return AnyView(
                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)

                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            )
        }
    }
}

// MARK: - Preview

#Preview("Sparkline Charts") {
    VStack(spacing: 20) {
        VStack(alignment: .leading, spacing: 4) {
            Text("Download Speed")
                .font(.caption)
                .foregroundColor(.secondary)
            SparklineChart(
                data: [0, 10, 25, 20, 35, 30, 45, 40, 50, 45, 60, 55],
                color: .green
            )
        }

        VStack(alignment: .leading, spacing: 4) {
            Text("Ping")
                .font(.caption)
                .foregroundColor(.secondary)
            SparklineChart(
                data: [20, 25, 18, 22, 30, 28, 35, 25, 20, 18, 22, 20],
                color: .yellow
            )
        }

        VStack(alignment: .leading, spacing: 4) {
            Text("Packet Loss")
                .font(.caption)
                .foregroundColor(.secondary)
            SparklineChart(
                data: [0, 0, 1, 0, 0, 2, 0, 0, 0, 1, 0, 0],
                color: .red
            )
        }

        VStack(alignment: .leading, spacing: 4) {
            Text("Signal Strength")
                .font(.caption)
                .foregroundColor(.secondary)
            SparklineChart(
                data: [-55, -54, -56, -53, -55, -57, -56, -55, -54, -55, -56, -55],
                color: .blue
            )
        }
    }
    .padding()
    .frame(width: 300)
}
