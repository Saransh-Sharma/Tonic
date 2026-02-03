//
//  NetworkChartWidgetView.swift
//  Tonic
//
//  Dual-line network chart widget for upload/download visualization
//  Matches Stats Master's Network Chart functionality
//  Task ID: fn-6-i4g.12
//

import SwiftUI

// MARK: - Network Chart Config

/// Configuration for network chart display
public struct NetworkChartConfig: Sendable, Equatable {
    public let historySize: Int
    public let scaling: ScalingMode
    public let showBackground: Bool
    public let showFrame: Bool
    public let showValues: Bool
    public let independentScaling: Bool  // Scale upload/download independently
    public let uploadColor: Color
    public let downloadColor: Color

    public init(
        historySize: Int = 60,
        scaling: ScalingMode = .linear,
        showBackground: Bool = false,
        showFrame: Bool = false,
        showValues: Bool = false,
        independentScaling: Bool = true,
        uploadColor: Color = .green,  // Green for upload
        downloadColor: Color = .blue   // Blue for download
    ) {
        self.historySize = min(120, max(30, historySize))
        self.scaling = scaling
        self.showBackground = showBackground
        self.showFrame = showFrame
        self.showValues = showValues
        self.independentScaling = independentScaling
        self.uploadColor = uploadColor
        self.downloadColor = downloadColor
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

// MARK: - Network Data

/// Network data for dual-line chart
public struct NetworkChartData: Sendable {
    public let upload: [Double]      // Upload history (bytes/s)
    public let download: [Double]    // Download history (bytes/s)
    public let currentUpload: Double // Current upload speed
    public let currentDownload: Double // Current download speed

    public init(
        upload: [Double] = [],
        download: [Double] = [],
        currentUpload: Double = 0,
        currentDownload: Double = 0
    ) {
        self.upload = upload
        self.download = download
        self.currentUpload = currentUpload
        self.currentDownload = currentDownload
    }

    public var isEmpty: Bool {
        upload.isEmpty && download.isEmpty
    }
}

// MARK: - Network Chart Widget View

/// Dual-line chart for network upload/download visualization
/// Matches Stats Master's network chart functionality
public struct NetworkChartWidgetView: View {
    private let data: NetworkChartData
    private let config: NetworkChartConfig

    public init(
        data: NetworkChartData,
        config: NetworkChartConfig = NetworkChartConfig()
    ) {
        self.data = data
        self.config = config
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
                    if data.isEmpty {
                        // Empty placeholder
                        Path { path in
                            let y = size.height / 2
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: size.width, y: y))
                        }
                        .stroke(
                            Color.secondary.opacity(0.2),
                            style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                        )
                    } else {
                        // Download line (drawn first, appears behind)
                        downloadLine(size: size)

                        // Upload line (drawn second, appears on top)
                        uploadLine(size: size)
                    }
                }
            }
            .frame(width: config.chartWidth)

            // Value overlay (if enabled)
            if config.showValues {
                valueOverlayView
            }

            // Frame overlay (if enabled)
            if config.showFrame {
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            }
        }
    }

    /// Download line path
    @ViewBuilder
    private func downloadLine(size: CGSize) -> some View {
        let points = generatePoints(
            from: data.download,
            maxValue: config.independentScaling ? (data.download.max() ?? 1) : max(data.download.max() ?? 1, data.upload.max() ?? 1),
            size: size
        )

        if !points.isEmpty {
            // Fill
            downloadAreaPath(points: points, size: size)
                .fill(
                    LinearGradient(
                        colors: [config.downloadColor.opacity(0.2), config.downloadColor.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Line
            linePath(from: points)
                .stroke(
                    config.downloadColor,
                    style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round)
                )
        }
    }

    /// Upload line path
    @ViewBuilder
    private func uploadLine(size: CGSize) -> some View {
        let points = generatePoints(
            from: data.upload,
            maxValue: config.independentScaling ? (data.upload.max() ?? 1) : max(data.download.max() ?? 1, data.upload.max() ?? 1),
            size: size
        )

        if !points.isEmpty {
            // Fill
            uploadAreaPath(points: points, size: size)
                .fill(
                    LinearGradient(
                        colors: [config.uploadColor.opacity(0.2), config.uploadColor.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Line
            linePath(from: points)
                .stroke(
                    config.uploadColor,
                    style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round)
                )
        }
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

    private func downloadAreaPath(points: [CGPoint], size: CGSize) -> Path {
        var path = Path()
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

    private func uploadAreaPath(points: [CGPoint], size: CGSize) -> Path {
        var path = Path()
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

    private func generatePoints(from values: [Double], maxValue: Double, size: CGSize) -> [CGPoint] {
        let validValues = values.filter { $0 > 0 }
        guard !validValues.isEmpty,
              maxValue > 0 else {
            return [
                CGPoint(x: 0, y: size.height / 2),
                CGPoint(x: size.width, y: size.height / 2)
            ]
        }

        let stepX = size.width / max(1, CGFloat(values.count - 1))

        var points: [CGPoint] = []
        for (index, value) in values.enumerated() {
            let x = CGFloat(index) * stepX
            let normalizedY: Double
            if value <= 0 {
                normalizedY = 0.5
            } else {
                normalizedY = 1 - config.scaling.normalize(value, maxValue: maxValue)
            }
            let y = max(0, min(size.height, normalizedY * size.height))
            points.append(CGPoint(x: x, y: y))
        }

        return points
    }

    @ViewBuilder
    private var valueOverlayView: some View {
        HStack(spacing: 4) {
            Spacer()

            // Download value
            VStack(alignment: .trailing, spacing: 0) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 5))
                    .foregroundColor(config.downloadColor)
                Text(formatSpeed(data.currentDownload))
                    .font(.system(size: 6, weight: .medium, design: .monospaced))
                    .foregroundColor(config.downloadColor)
            }
            .padding(.trailing, 2)

            // Upload value
            VStack(alignment: .trailing, spacing: 0) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 5))
                    .foregroundColor(config.uploadColor)
                Text(formatSpeed(data.currentUpload))
                    .font(.system(size: 6, weight: .medium, design: .monospaced))
                    .foregroundColor(config.uploadColor)
            }
            .padding(.trailing, 4)
        }
    }

    private func formatSpeed(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond < 1024 {
            return "\(Int(bytesPerSecond))B"
        } else if bytesPerSecond < 1024 * 1024 {
            return String(format: "%.1fK", bytesPerSecond / 1024)
        } else {
            return String(format: "%.1fM", bytesPerSecond / (1024 * 1024))
        }
    }
}

// MARK: - Network Chart Widget State

@Observable
@MainActor
public final class NetworkChartWidgetState {
    public private(set) var config: NetworkChartConfig
    private var uploadBuffer: [Double]
    private var downloadBuffer: [Double]

    public init(config: NetworkChartConfig = NetworkChartConfig()) {
        self.config = config
        self.uploadBuffer = []
        self.downloadBuffer = []
    }

    public var data: NetworkChartData {
        NetworkChartData(
            upload: uploadBuffer,
            download: downloadBuffer,
            currentUpload: uploadBuffer.last ?? 0,
            currentDownload: downloadBuffer.last ?? 0
        )
    }

    public func addUpload(_ value: Double) {
        uploadBuffer.append(value)
        if uploadBuffer.count > config.historySize {
            uploadBuffer.removeFirst()
        }
    }

    public func addDownload(_ value: Double) {
        downloadBuffer.append(value)
        if downloadBuffer.count > config.historySize {
            downloadBuffer.removeFirst()
        }
    }

    public func addUpload(_ upload: Double, download: Double) {
        addUpload(upload)
        addDownload(download)
    }

    public func updateConfig(_ newConfig: NetworkChartConfig) {
        config = newConfig

        // Trim buffers if needed
        while uploadBuffer.count > config.historySize {
            uploadBuffer.removeFirst()
        }
        while downloadBuffer.count > config.historySize {
            downloadBuffer.removeFirst()
        }
    }

    public func reset() {
        uploadBuffer = []
        downloadBuffer = []
    }
}

// MARK: - Preview

#Preview("Network Chart Widget") {
    VStack(spacing: 16) {
        // Basic network chart
        VStack(alignment: .leading, spacing: 4) {
            Text("Network Activity")
                .font(.caption)
                .foregroundColor(.secondary)
            NetworkChartWidgetView(
                data: NetworkChartData(
                    upload: generateRandomData(count: 60, base: 100),
                    download: generateRandomData(count: 60, base: 500),
                    currentUpload: 150000,
                    currentDownload: 750000
                ),
                config: NetworkChartConfig(
                    historySize: 60,
                    independentScaling: true
                )
            )
        }

        // With values
        VStack(alignment: .leading, spacing: 4) {
            Text("With Speed Values")
                .font(.caption)
                .foregroundColor(.secondary)
            NetworkChartWidgetView(
                data: NetworkChartData(
                    upload: generateRandomData(count: 60, base: 100),
                    download: generateRandomData(count: 60, base: 500),
                    currentUpload: 250000,
                    currentDownload: 1200000
                ),
                config: NetworkChartConfig(
                    showValues: true,
                    independentScaling: true
                )
            )
        }

        // With frame
        VStack(alignment: .leading, spacing: 4) {
            Text("With Frame")
                .font(.caption)
                .foregroundColor(.secondary)
            NetworkChartWidgetView(
                data: NetworkChartData(
                    upload: generateRandomData(count: 60, base: 100),
                    download: generateRandomData(count: 60, base: 500),
                    currentUpload: 80000,
                    currentDownload: 450000
                ),
                config: NetworkChartConfig(
                    showBackground: true,
                    showFrame: true,
                    independentScaling: false
                )
            )
        }

        // Custom colors
        VStack(alignment: .leading, spacing: 4) {
            Text("Custom Colors (Orange/Red)")
                .font(.caption)
                .foregroundColor(.secondary)
            NetworkChartWidgetView(
                data: NetworkChartData(
                    upload: generateRandomData(count: 60, base: 100),
                    download: generateRandomData(count: 60, base: 500),
                    currentUpload: 500000,
                    currentDownload: 2000000
                ),
                config: NetworkChartConfig(
                    independentScaling: true,
                    uploadColor: .orange,
                    downloadColor: .red
                )
            )
        }
    }
    .padding()
}

private func generateRandomData(count: Int, base: Double) -> [Double] {
    var data: [Double] = []
    var value = base + Double.random(in: -base * 0.2...base * 0.2)
    for _ in 0..<count {
        value += Double.random(in: -base * 0.3...base * 0.3)
        value = max(base * 0.1, min(base * 3, value))
        data.append(value)
    }
    return data
}
