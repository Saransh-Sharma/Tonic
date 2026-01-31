//
//  LineChartWidgetView.swift
//  Tonic
//
//  Line Chart widget view for real-time data visualization
//  Matches Stats Master's Line Chart functionality
//  Task ID: fn-5-v8r.7
//  Enhanced for Stats Master parity: fn-6-i4g.12
//

import SwiftUI

// MARK: - Line Chart Config

/// Configuration for line chart display
public struct LineChartConfig: Sendable, Equatable {
    public let historySize: Int  // 30-120
    public let scaling: ScalingMode
    public let showBackground: Bool
    public let showFrame: Bool
    public let showValue: Bool
    public let showValueOverlay: Bool  // Show current value as overlay on chart
    public let fillMode: FillMode  // Fill vs line only
    public let lineColor: ChartColor

    public init(
        historySize: Int = 60,
        scaling: ScalingMode = .linear,
        showBackground: Bool = false,
        showFrame: Bool = false,
        showValue: Bool = false,
        showValueOverlay: Bool = false,
        fillMode: FillMode = .gradient,
        lineColor: ChartColor = .accent
    ) {
        self.historySize = min(120, max(30, historySize))
        self.scaling = scaling
        self.showBackground = showBackground
        self.showFrame = showFrame
        self.showValue = showValue
        self.showValueOverlay = showValueOverlay
        self.fillMode = fillMode
        self.lineColor = lineColor
    }

    public var chartWidth: CGFloat {
        switch historySize {
        case 30: return 24
        case 60: return 32
        case 90: return 42
        case 120: return 52
        default: return 32
        }
    }
}

/// Fill mode for line chart
public enum FillMode: String, Sendable, Equatable {
    case gradient  // Gradient fill below line
    case solid     // Solid fill below line
    case lineOnly  // Line only, no fill
}

/// Color mode for chart line and fill
public enum ChartColor: String, Sendable, Equatable {
    case accent
    case utilization
    case pressure
    case monochrome
    case green
    case blue
    case purple
    case orange

    public var color: Color {
        switch self {
        case .accent: return .accentColor
        case .utilization: return .blue  // Will be dynamic based on value
        case .pressure: return .orange  // Will be dynamic based on pressure
        case .monochrome: return .primary
        case .green: return .green
        case .blue: return .blue
        case .purple: return .purple
        case .orange: return .orange
        }
    }
}

// MARK: - Circular Buffer

/// Circular buffer for efficient history storage
@Observable
@MainActor
public final class ChartDataBuffer: Sendable {
    private var buffer: [Double]
    private var capacity: Int
    private var head: Int = 0
    private var count: Int = 0

    public var values: [Double] {
        if count < capacity {
            return Array(buffer.prefix(count))
        }
        return Array(buffer.suffix(from: head)) + Array(buffer.prefix(head))
    }

    public init(capacity: Int) {
        self.capacity = capacity
        self.buffer = Array(repeating: 0.0, count: capacity)
    }

    public func add(_ value: Double) {
        buffer[head] = value
        head = (head + 1) % capacity
        count = min(count + 1, capacity)
    }

    public func reset() {
        buffer = Array(repeating: 0.0, count: capacity)
        head = 0
        count = 0
    }

    public func resize(to newCapacity: Int) {
        let currentValues = values
        capacity = newCapacity
        buffer = Array(repeating: 0.0, count: capacity)

        for (index, value) in currentValues.suffix(newCapacity).enumerated() {
            buffer[index] = value
        }

        head = min(currentValues.count, newCapacity) % newCapacity
        count = min(currentValues.count, newCapacity)
    }
}

// MARK: - Line Chart Widget View

/// Line chart widget for displaying real-time data
/// Matches Stats Master's Line Chart functionality
public struct LineChartWidgetView: View {
    private let data: [Double]
    private let config: LineChartConfig
    private let currentValue: Double?

    public init(
        data: [Double],
        config: LineChartConfig = LineChartConfig(),
        currentValue: Double? = nil
    ) {
        self.data = data
        self.config = config
        self.currentValue = currentValue ?? data.last
    }

    public var body: some View {
        HStack(spacing: 0) {
            chartContent
        }
        .frame(height: 22)
    }

    private var chartContent: some View {
        ZStack(alignment: .leading) {
            // Background fill (if enabled)
            if config.showBackground {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(nsColor: .windowBackgroundColor))
            }

            // The chart
            GeometryReader { geometry in
                let size = geometry.size

                Group {
                    if data.isEmpty || data.allSatisfy({ $0 == 0 }) {
                        // Empty placeholder
                        Path { path in
                            let y = size.height / 2
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: size.width, y: y))
                        }
                        .stroke(
                            effectiveColor.opacity(0.2),
                            style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                        )
                    } else {
                        // Area fill (based on fillMode)
                        if config.fillMode != .lineOnly {
                            areaFill(size: size)
                        }

                        // Line path
                        linePath(size: size)
                            .stroke(
                                effectiveColor,
                                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                            )
                    }
                }
            }
            .frame(width: config.chartWidth)

            // Value overlay (if enabled)
            if config.showValueOverlay, let value = currentValue {
                valueOverlayView(value: value)
            }

            // Value text (legacy showValue - displays outside chart)
            if config.showValue, let value = currentValue {
                HStack {
                    Spacer()
                    Text("\(Int(value * 100))%")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundColor(effectiveColor)
                        .padding(.trailing, 4)
                }
            }
        }
        .overlay {
            // Frame overlay (if enabled)
            if config.showFrame {
                RoundedRectangle(cornerRadius: 2)
                    .stroke(effectiveColor.opacity(0.3), lineWidth: 1)
            }
        }
    }

    /// Value overlay displayed on the chart
    @ViewBuilder
    private func valueOverlayView(value: Double) -> some View {
        HStack {
            Spacer()
            VStack {
                Spacer()
                Text("\(Int(value * 100))")
                    .font(.system(size: 7, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(
                        Capsule()
                            .fill(effectiveColor)
                    )
                    .padding(.trailing, 2)
                    .padding(.bottom, 2)
            }
        }
    }

    /// Area fill based on fill mode
    @ViewBuilder
    private func areaFill(size: CGSize) -> some View {
        let areaPath = self.areaPath(size: size)

        switch config.fillMode {
        case .gradient:
            areaPath.fill(
                LinearGradient(
                    colors: [effectiveColor.opacity(0.3), effectiveColor.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        case .solid:
            areaPath.fill(effectiveColor.opacity(0.2))
        case .lineOnly:
            EmptyView()
        }
    }

    private func linePath(size: CGSize) -> Path {
        var path = Path()
        let points = generatePoints(size: size)

        guard let first = points.first else { return path }
        path.move(to: first)

        for point in points.dropFirst() {
            path.addLine(to: point)
        }

        return path
    }

    private func areaPath(size: CGSize) -> Path {
        var path = Path()
        let points = generatePoints(size: size)

        guard let first = points.first,
              let last = points.last else { return path }

        path.move(to: CGPoint(x: first.x, y: size.height))
        path.addLine(to: first)

        for point in points {
            path.addLine(to: point)
        }

        path.addLine(to: CGPoint(x: last.x, y: size.height))
        path.closeSubpath()

        return path
    }

    private func generatePoints(size: CGSize) -> [CGPoint] {
        let validValues = data.filter { $0 > 0 }
        guard !validValues.isEmpty,
              let maxVal = validValues.max() else {
            // Flat line
            return [
                CGPoint(x: 0, y: size.height / 2),
                CGPoint(x: size.width, y: size.height / 2)
            ]
        }

        let stepX = size.width / max(1, CGFloat(data.count - 1))

        var points: [CGPoint] = []
        for (index, value) in data.enumerated() {
            let x = CGFloat(index) * stepX
            let normalizedY: Double
            if value <= 0 {
                normalizedY = 0.5
            } else {
                normalizedY = 1 - config.scaling.normalize(value, maxValue: maxVal)
            }
            let y = max(0, min(size.height, normalizedY * size.height))
            points.append(CGPoint(x: x, y: y))
        }

        return points
    }

    private var effectiveColor: Color {
        switch config.lineColor {
        case .utilization:
            if let value = currentValue {
                return colorForValue(value)
            }
            return .blue
        case .pressure:
            // Would need pressure data - default to warning color
            return .orange
        default:
            return config.lineColor.color
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

// MARK: - Line Chart Widget State

@Observable
@MainActor
public final class LineChartWidgetState {
    public private(set) var config: LineChartConfig
    private let buffer: ChartDataBuffer

    public var data: [Double] {
        buffer.values
    }

    public var currentValue: Double? {
        buffer.values.last
    }

    public init(config: LineChartConfig = LineChartConfig()) {
        self.config = config
        self.buffer = ChartDataBuffer(capacity: config.historySize)
    }

    public func addValue(_ value: Double) {
        buffer.add(value)
    }

    public func updateConfig(_ newConfig: LineChartConfig) {
        guard newConfig.historySize != config.historySize else {
            config = newConfig
            return
        }
        config = newConfig
        buffer.resize(to: newConfig.historySize)
    }

    public func reset() {
        buffer.reset()
    }
}

// MARK: - Preview

#Preview("Line Chart Widget") {
    VStack(spacing: 16) {
        // Different configurations
        HStack(spacing: 12) {
            LineChartWidgetView(
                data: generateRandomData(count: 60),
                config: LineChartConfig(historySize: 60, lineColor: .accent),
                currentValue: 0.45
            )

            LineChartWidgetView(
                data: generateRandomData(count: 60),
                config: LineChartConfig(
                    historySize: 60,
                    showBackground: true,
                    showFrame: true,
                    lineColor: .utilization
                ),
                currentValue: 0.72
            )

            LineChartWidgetView(
                data: generateRandomData(count: 30),
                config: LineChartConfig(historySize: 30, showValue: true, lineColor: .green),
                currentValue: 0.28
            )
        }
        .padding()

        // Different scaling modes
        VStack(alignment: .leading, spacing: 4) {
            Text("Linear Scaling")
                .font(.caption)
            LineChartWidgetView(
                data: generateRandomData(count: 60),
                config: LineChartConfig(scaling: .linear, showFrame: true)
            )
        }
        .frame(width: 200)

        VStack(alignment: .leading, spacing: 4) {
            Text("Square Scaling")
                .font(.caption)
            LineChartWidgetView(
                data: generateRandomData(count: 60),
                config: LineChartConfig(scaling: .square, showFrame: true)
            )
        }
        .frame(width: 200)

        VStack(alignment: .leading, spacing: 4) {
            Text("Logarithmic Scaling")
                .font(.caption)
            LineChartWidgetView(
                data: generateRandomData(count: 60),
                config: LineChartConfig(scaling: .logarithmic, showFrame: true)
            )
        }
        .frame(width: 200)
    }
    .padding()
}

private func generateRandomData(count: Int) -> [Double] {
    var data: [Double] = []
    var value = Double.random(in: 0.2...0.5)
    for _ in 0..<count {
        value += Double.random(in: -0.1...0.1)
        value = max(0, min(1, value))
        data.append(value)
    }
    return data
}
