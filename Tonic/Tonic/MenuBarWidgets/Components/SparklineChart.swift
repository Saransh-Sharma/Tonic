//
//  SparklineChart.swift
//  Tonic
//
//  Mini line chart component for network metrics
//  Task ID: fn-2.8.7
//  Performance optimized: Simplified rendering, removed heavy Charts dependency
//

import SwiftUI

// MARK: - Sparkline Chart

/// Mini line chart for displaying metric history
/// Optimized to avoid recalculating paths on every render
public struct NetworkSparklineChart: View, Equatable {

    // MARK: - Properties

    let data: [Double]
    let color: Color
    let height: CGFloat
    let showArea: Bool
    let lineWidth: CGFloat

    // Performance: Equatable conformance for SwiftUI optimization
    public static func == (lhs: NetworkSparklineChart, rhs: NetworkSparklineChart) -> Bool {
        return lhs.data == rhs.data &&
               lhs.color == rhs.color &&
               lhs.height == rhs.height &&
               lhs.showArea == rhs.showArea &&
               lhs.lineWidth == rhs.lineWidth
    }

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
        Group {
            if data.isEmpty || data.allSatisfy({ $0 == 0 }) {
                emptyPlaceholder
            } else {
                optimizedSparkline
            }
        }
        .frame(height: height)
    }

    // MARK: - Views

    private var emptyPlaceholder: some View {
        GeometryReader { geometry in
            Path { path in
                let y = height / 2
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: geometry.size.width, y: y))
            }
            .stroke(
                color.opacity(0.2),
                style: StrokeStyle(lineWidth: lineWidth, dash: [4, 4])
            )
        }
    }

    private var optimizedSparkline: some View {
        GeometryReader { geometry in
            let effectiveWidth = geometry.size.width
            let effectiveHeight = geometry.size.height

            // Generate or retrieve cached path
            let pathPoints = generatePoints(for: effectiveWidth, height: effectiveHeight)

            // Line path
            linePath(from: pathPoints)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))

            // Optional area fill
            if showArea {
                areaPath(from: pathPoints, height: effectiveHeight)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.15), color.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        }
    }

    // MARK: - Path Generation

    private func generatePoints(for width: CGFloat, height: CGFloat) -> [CGPoint] {
        // Calculate fresh points
        let validValues = data.filter { $0 != 0 }
        guard !validValues.isEmpty,
              let minVal = validValues.min(),
              let maxVal = validValues.max(),
              maxVal != minVal else {
            // Flat line
            return [CGPoint(x: 0, y: height / 2), CGPoint(x: width, y: height / 2)]
        }

        let range = maxVal - minVal
        let padding = range * 0.1
        let effectiveMin = minVal - padding
        let effectiveRange = (maxVal + padding) - effectiveMin

        let stepX = width / max(1, CGFloat(data.count - 1))

        var points: [CGPoint] = []
        for (index, value) in data.enumerated() {
            let x = CGFloat(index) * stepX
            let normalizedY: Double
            if value == 0 {
                normalizedY = 0.5
            } else {
                normalizedY = 1 - ((value - effectiveMin) / effectiveRange)
            }
            let y = normalizedY * height
            points.append(CGPoint(x: x, y: y))
        }
        return points
    }

    private func linePath(from points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }

        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }

    private func areaPath(from points: [CGPoint], height: CGFloat) -> Path {
        var path = Path()
        guard let first = points.first,
              let last = points.last else { return path }

        path.move(to: CGPoint(x: first.x, y: height))
        path.addLine(to: first)

        for point in points {
            path.addLine(to: point)
        }

        path.addLine(to: CGPoint(x: last.x, y: height))
        path.closeSubpath()

        return path
    }

}

// MARK: - Preview

#Preview("Sparkline Charts") {
    VStack(spacing: 20) {
        VStack(alignment: .leading, spacing: 4) {
            Text("Download Speed")
                .font(.caption)
                .foregroundColor(.secondary)
            NetworkSparklineChart(
                data: [0, 10, 25, 20, 35, 30, 45, 40, 50, 45, 60, 55],
                color: .green
            )
        }

        VStack(alignment: .leading, spacing: 4) {
            Text("Ping")
                .font(.caption)
                .foregroundColor(.secondary)
            NetworkSparklineChart(
                data: [20, 25, 18, 22, 30, 28, 35, 25, 20, 18, 22, 20],
                color: .yellow
            )
        }

        VStack(alignment: .leading, spacing: 4) {
            Text("Packet Loss")
                .font(.caption)
                .foregroundColor(.secondary)
            NetworkSparklineChart(
                data: [0, 0, 1, 0, 0, 2, 0, 0, 0, 1, 0, 0],
                color: .red
            )
        }

        VStack(alignment: .leading, spacing: 4) {
            Text("Signal Strength")
                .font(.caption)
                .foregroundColor(.secondary)
            NetworkSparklineChart(
                data: [-55, -54, -56, -53, -55, -57, -56, -55, -54, -55, -56, -55],
                color: .blue
            )
        }
    }
    .padding()
    .frame(width: 300)
}
