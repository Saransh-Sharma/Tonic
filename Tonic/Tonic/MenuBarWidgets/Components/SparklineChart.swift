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
public struct NetworkSparklineChart: View {

    // MARK: - Properties

    let data: [Double]
    let color: Color
    let height: CGFloat
    let showArea: Bool
    let lineWidth: CGFloat
    /// When set, values normalize against this ceiling (0 at the baseline)
    /// instead of the data's own min/max range.
    let fixedMax: Double?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// One-shot path draw-in on first appear; live data updates after stay instant.
    @State private var drawProgress: CGFloat = 0

    // MARK: - Initialization

    public init(
        data: [Double],
        color: Color? = nil,
        height: CGFloat = 32,
        showArea: Bool = true,
        lineWidth: CGFloat = 1.5,
        fixedMax: Double? = nil
    ) {
        self.data = data
        self.color = color ?? TonicDS.Colors.statusInfo
        self.height = height
        self.showArea = showArea
        self.lineWidth = lineWidth
        self.fixedMax = fixedMax
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

            // Line path — trims in on first appear ("the data draws itself")
            linePath(from: pathPoints)
                .trim(from: 0, to: drawProgress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))

            // Optional area fill (fades in with the draw)
            if showArea {
                areaPath(from: pathPoints, height: effectiveHeight)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(TonicDS.Chart.areaOpacity),
                                     color.opacity(TonicDS.Chart.areaSoftOpacity)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .opacity(Double(drawProgress))
            }
        }
        .onAppear {
            guard drawProgress == 0 else { return }
            // Popovers live outside the main window tree, so also honor the app toggle.
            if reduceMotion || AppearancePreferences.shared.reduceMotion {
                drawProgress = 1
            } else {
                withAnimation(TonicDS.Motion.appear) { drawProgress = 1 }
            }
        }
    }

    // MARK: - Path Generation

    private func generatePoints(for width: CGFloat, height: CGFloat) -> [CGPoint] {
        // Pinned scale: normalize against the fixed ceiling with the baseline at 0.
        if let fixedMax, fixedMax > 0 {
            let stepX = width / max(1, CGFloat(data.count - 1))
            let inset: CGFloat = 2
            return data.enumerated().map { index, value in
                let fraction = min(1, max(0, value / fixedMax))
                let y = inset + (1 - fraction) * (height - inset * 2)
                return CGPoint(x: CGFloat(index) * stepX, y: y)
            }
        }

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
            let inset: CGFloat = 2
            let y = inset + normalizedY * (height - inset * 2)
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

// MARK: - Bidirectional Network Traffic Chart

public enum NetworkTrafficChartMode: Sendable, Equatable {
    case compactMenuBar
    case popover
    case monitorCard

    var minimumVisibleFraction: Double {
        switch self {
        case .compactMenuBar: return 0.16
        case .popover: return 0.06
        case .monitorCard: return 0
        }
    }

    var centerlineColor: Color {
        switch self {
        case .compactMenuBar:
            return TonicDS.Colors.textMuted.opacity(0.35)
        case .popover:
            return TonicDS.Colors.hairlineOnDark
        case .monitorCard:
            return TonicDS.Colors.hairline
        }
    }
}

public enum NetworkTrafficChartScale {
    public static func maxMagnitude(downloadData: [Double], uploadData: [Double]) -> Double {
        max((downloadData + uploadData).compactMap(sanitizedPositiveValue).max() ?? 0, 1)
    }

    public static func normalizedMagnitude(
        _ value: Double,
        maxMagnitude: Double,
        minimumVisibleFraction: Double
    ) -> Double {
        guard let sanitized = sanitizedPositiveValue(value), maxMagnitude > 0 else { return 0 }
        let normalized = min(1, sanitized / maxMagnitude)
        return max(minimumVisibleFraction, normalized)
    }

    public static func sanitizedPositiveValue(_ value: Double) -> Double? {
        guard value.isFinite, value > 0 else { return nil }
        return value
    }
}

/// Directional traffic chart: download rises above the centerline, upload falls below it.
public struct NetworkTrafficChart: View {
    let downloadData: [Double]
    let uploadData: [Double]
    let height: CGFloat
    let mode: NetworkTrafficChartMode
    let lineWidth: CGFloat
    /// Series colors — defaults are network download/upload; disk consoles
    /// pass read/write instead.
    let downloadColor: Color
    let uploadColor: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drawProgress: CGFloat = 0

    public init(
        downloadData: [Double],
        uploadData: [Double],
        height: CGFloat = 32,
        mode: NetworkTrafficChartMode = .popover,
        lineWidth: CGFloat = 1.5,
        downloadColor: Color? = nil,
        uploadColor: Color? = nil
    ) {
        self.downloadData = downloadData
        self.uploadData = uploadData
        self.height = height
        self.mode = mode
        self.lineWidth = lineWidth
        self.downloadColor = downloadColor ?? TonicDS.Chart.download
        self.uploadColor = uploadColor ?? TonicDS.Chart.upload
    }

    public var body: some View {
        Group {
            if isEmpty {
                emptyPlaceholder
            } else {
                trafficChart
            }
        }
        .frame(height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var isEmpty: Bool {
        let combined = downloadData + uploadData
        return combined.isEmpty || combined.allSatisfy { !$0.isFinite || $0 <= 0 }
    }

    private var accessibilityLabel: String {
        let latestDownload = downloadData.last ?? 0
        let latestUpload = uploadData.last ?? 0
        return "Network traffic chart, down \(Self.rate(latestDownload)), up \(Self.rate(latestUpload))"
    }

    private var emptyPlaceholder: some View {
        GeometryReader { geometry in
            let centerY = geometry.size.height / 2
            Path { path in
                path.move(to: CGPoint(x: 0, y: centerY))
                path.addLine(to: CGPoint(x: geometry.size.width, y: centerY))
            }
            .stroke(
                mode.centerlineColor.opacity(0.5),
                style: StrokeStyle(lineWidth: lineWidth, dash: [4, 4])
            )
        }
    }

    private var trafficChart: some View {
        GeometryReader { geometry in
            let maxMagnitude = NetworkTrafficChartScale.maxMagnitude(
                downloadData: downloadData,
                uploadData: uploadData
            )
            let centerY = geometry.size.height / 2

            Path { path in
                path.move(to: CGPoint(x: 0, y: centerY))
                path.addLine(to: CGPoint(x: geometry.size.width, y: centerY))
            }
            .stroke(mode.centerlineColor.opacity(0.55), lineWidth: 1)

            linePath(
                data: downloadData,
                size: geometry.size,
                maxMagnitude: maxMagnitude,
                direction: .download
            )
            .trim(from: 0, to: drawProgress)
            .stroke(downloadColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))

            linePath(
                data: uploadData,
                size: geometry.size,
                maxMagnitude: maxMagnitude,
                direction: .upload
            )
            .trim(from: 0, to: drawProgress)
            .stroke(uploadColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }
        .onAppear {
            guard drawProgress == 0 else { return }
            if reduceMotion || AppearancePreferences.shared.reduceMotion {
                drawProgress = 1
            } else {
                withAnimation(TonicDS.Motion.appear) { drawProgress = 1 }
            }
        }
    }

    private enum Direction {
        case download
        case upload

        var sign: CGFloat {
            switch self {
            case .download: return -1
            case .upload: return 1
            }
        }
    }

    private func linePath(
        data: [Double],
        size: CGSize,
        maxMagnitude: Double,
        direction: Direction
    ) -> Path {
        var path = Path()
        guard !data.isEmpty else { return path }

        let points = points(
            data: data,
            size: size,
            maxMagnitude: maxMagnitude,
            direction: direction
        )
        guard let first = points.first else { return path }

        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }

    private func points(
        data: [Double],
        size: CGSize,
        maxMagnitude: Double,
        direction: Direction
    ) -> [CGPoint] {
        let width = max(0, size.width)
        let centerY = size.height / 2
        let verticalInset: CGFloat = 2
        let halfHeight = max(1, (size.height - verticalInset * 2) / 2)
        let stepX = width / max(1, CGFloat(data.count - 1))

        return data.enumerated().map { index, value in
            let fraction = NetworkTrafficChartScale.normalizedMagnitude(
                value,
                maxMagnitude: maxMagnitude,
                minimumVisibleFraction: mode.minimumVisibleFraction
            )
            let x = CGFloat(index) * stepX
            let y = centerY + direction.sign * CGFloat(fraction) * halfHeight
            return CGPoint(x: x, y: min(size.height - verticalInset, max(verticalInset, y)))
        }
    }

    private static func rate(_ bytesPerSecond: Double) -> String {
        rateByteFormatter.string(fromByteCount: Int64(max(0, bytesPerSecond))) + "/s"
    }

    private static let rateByteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB, .useBytes]
        formatter.countStyle = .memory
        return formatter
    }()
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
