//
//  SpeedWidgetView.swift
//  Tonic
//
//  Speed widget for network I/O display
//  Matches Stats Master's Speed widget functionality
//  Task ID: fn-5-v8r.11
//

import SwiftUI

// MARK: - Speed Widget Config

/// Configuration for speed widget display
public struct SpeedWidgetConfig: Sendable, Equatable {
    public let displayMode: DisplayMode
    public let iconMode: IconMode
    public let showUnits: Bool
    public let showIcon: Bool
    public let downloadColor: Color
    public let uploadColor: Color
    public let valueAlignment: HorizontalAlignment

    public init(
        displayMode: DisplayMode = .twoRows,
        iconMode: IconMode = .arrows,
        showUnits: Bool = true,
        showIcon: Bool = true,
        downloadColor: Color = .blue,
        uploadColor: Color = .red,
        valueAlignment: HorizontalAlignment = .leading
    ) {
        self.displayMode = displayMode
        self.iconMode = iconMode
        self.showUnits = showUnits
        self.showIcon = showIcon
        self.downloadColor = downloadColor
        self.uploadColor = uploadColor
        self.valueAlignment = valueAlignment
    }
}

/// Display mode for speed values
public enum DisplayMode: String, Sendable, Equatable {
    case oneRow      // Download | Upload
    case twoRows     // Download on top, Upload below
    case chart       // Mini sparkline charts
}

/// Icon mode for indicators
public enum IconMode: String, Sendable, Equatable {
    case arrows      // ↓ / ↑
    case dots        // • / •
    case io          // I / O
    case labels      // "DN" / "UP"
    case none
}

// MARK: - Speed Widget View

/// Speed widget for displaying network upload/download
/// Enhanced version of Network widget with Stats Master features
public struct SpeedWidgetView: View {
    private let downloadSpeed: Double  // bytes per second
    private let uploadSpeed: Double    // bytes per second
    private let config: SpeedWidgetConfig
    private let connectionType: ConnectionType?
    private let ssid: String?

    public init(
        downloadSpeed: Double,
        uploadSpeed: Double,
        config: SpeedWidgetConfig = SpeedWidgetConfig(),
        connectionType: ConnectionType? = nil,
        ssid: String? = nil
    ) {
        self.downloadSpeed = downloadSpeed
        self.uploadSpeed = uploadSpeed
        self.config = config
        self.connectionType = connectionType
        self.ssid = ssid
    }

    public init(networkData: NetworkData, config: SpeedWidgetConfig = SpeedWidgetConfig()) {
        self.downloadSpeed = networkData.downloadBytesPerSecond
        self.uploadSpeed = networkData.uploadBytesPerSecond
        self.config = config
        self.connectionType = networkData.isConnected ? networkData.connectionType : nil
        self.ssid = networkData.ssid
    }

    public var body: some View {
        Group {
            switch config.displayMode {
            case .oneRow:
                oneRowView
            case .twoRows:
                twoRowsView
            case .chart:
                chartView
            }
        }
        .frame(height: 22)
        .padding(.horizontal, 4)
    }

    // MARK: - Display Modes

    private var oneRowView: some View {
        HStack(spacing: 6) {
            // Connection indicator
            if config.showIcon {
                connectionIndicator
            }

            // Download
            HStack(spacing: 2) {
                if config.showIcon {
                    iconFor(.download)
                }
                Text(formatSpeed(downloadSpeed))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(config.downloadColor)
                if config.showUnits {
                    Text("/s")
                        .font(.system(size: 7))
                        .foregroundColor(.secondary)
                }
            }

            // Divider
            Text("|")
                .font(.system(size: 8))
                .foregroundColor(.secondary.opacity(0.5))

            // Upload
            HStack(spacing: 2) {
                if config.showIcon {
                    iconFor(.upload)
                }
                Text(formatSpeed(uploadSpeed))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(config.uploadColor)
                if config.showUnits {
                    Text("/s")
                        .font(.system(size: 7))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var twoRowsView: some View {
        VStack(spacing: 0) {
            // Download row
            HStack(spacing: 4) {
                if config.showIcon {
                    iconFor(.download)
                        .font(.system(size: 8))
                }
                Text(formatSpeed(downloadSpeed))
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundColor(config.downloadColor)
                if config.showUnits {
                    Text("/s")
                        .font(.system(size: 6))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            // Upload row
            HStack(spacing: 4) {
                if config.showIcon {
                    iconFor(.upload)
                        .font(.system(size: 8))
                }
                Text(formatSpeed(uploadSpeed))
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundColor(config.uploadColor)
                if config.showUnits {
                    Text("/s")
                        .font(.system(size: 6))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
        .frame(width: 50)
    }

    private var chartView: some View {
        HStack(spacing: 6) {
            // Mini chart placeholder - would need history data
            VStack(spacing: 2) {
                MiniBarChartView(value: min(1, downloadSpeed / 10_000_000), color: config.downloadColor, height: 3)
                MiniBarChartView(value: min(1, uploadSpeed / 1_000_000), color: config.uploadColor, height: 3)
            }

            if config.showIcon {
                connectionIndicator
            }
        }
    }

    // MARK: - Components

    private var connectionIndicator: some View {
        Group {
            switch connectionType {
            case .wifi:
                if let ssid = ssid, !ssid.isEmpty {
                    Image(systemName: "wifi.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "wifi")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            case .ethernet:
                Image(systemName: "cable.connector")
                    .font(.system(size: 10))
                    .foregroundColor(.green)
            case .cellular:
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 10))
                    .foregroundColor(.green)
            case .unknown, .none:
                Image(systemName: "network.slash")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private func iconFor(_ direction: Direction) -> some View {
        switch config.iconMode {
        case .arrows:
            Image(systemName: direction == .download ? "arrow.down" : "arrow.up")
                .font(.system(size: 7))
                .foregroundColor(direction == .download ? config.downloadColor : config.uploadColor)
        case .dots:
            Circle()
                .fill(direction == .download ? config.downloadColor : config.uploadColor)
                .frame(width: 4, height: 4)
        case .io:
            Text(direction == .download ? "I" : "O")
                .font(.system(size: 7, weight: .bold))
                .foregroundColor(direction == .download ? config.downloadColor : config.uploadColor)
        case .labels:
            Text(direction == .download ? "DN" : "UP")
                .font(.system(size: 6, weight: .bold))
                .foregroundColor(direction == .download ? config.downloadColor : config.uploadColor)
        case .none:
            EmptyView()
        }
    }

    // MARK: - Formatting

    private func formatSpeed(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond >= 1_000_000 {
            return String(format: "%.1fM", bytesPerSecond / 1_000_000)
        } else if bytesPerSecond >= 1_000 {
            return String(format: "%.0fK", bytesPerSecond / 1_000)
        } else {
            return "\(Int(bytesPerSecond))"
        }
    }

    private enum Direction {
        case download, upload
    }
}

// MARK: - Network Data Extension

public extension NetworkData {
    var connectionType: ConnectionType {
        ConnectionType(rawValue: connectionTypeRaw) ?? .unknown
    }

    var connectionTypeRaw: String {
        // Store raw connection type
        switch self.connectionType {
        case .wifi: return "wifi"
        case .ethernet: return "ethernet"
        case .cellular: return "cellular"
        case .unknown: return "unknown"
        }
    }
}

// MARK: - Connection Type

public enum ConnectionType: String, Sendable {
    case wifi
    case ethernet
    case cellular
    case unknown
}

// MARK: - Mini Bar Chart (reused from BarChartWidgetView)

struct MiniBarChartView: View {
    let value: Double
    let color: Color
    let height: CGFloat

    var body: some View {
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

#Preview("Speed Widget") {
    VStack(spacing: 20) {
        // Two rows mode
        VStack(alignment: .leading, spacing: 4) {
            Text("Two Rows Mode")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                SpeedWidgetView(
                    downloadSpeed: 5_240_000,
                    uploadSpeed: 450_000,
                    config: SpeedWidgetConfig(displayMode: .twoRows),
                    connectionType: .wifi,
                    ssid: "HomeNetwork"
                )

                SpeedWidgetView(
                    downloadSpeed: 124_000,
                    uploadSpeed: 12_000,
                    config: SpeedWidgetConfig(displayMode: .twoRows),
                    connectionType: .ethernet
                )
            }
        }

        // One row mode
        VStack(alignment: .leading, spacing: 4) {
            Text("One Row Mode")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                SpeedWidgetView(
                    downloadSpeed: 5_240_000,
                    uploadSpeed: 450_000,
                    config: SpeedWidgetConfig(displayMode: .oneRow),
                    connectionType: .wifi,
                    ssid: "HomeNetwork"
                )

                SpeedWidgetView(
                    downloadSpeed: 124_000,
                    uploadSpeed: 12_000,
                    config: SpeedWidgetConfig(displayMode: .oneRow, iconMode: .io),
                    connectionType: .ethernet
                )
            }
        }

        // Chart mode
        VStack(alignment: .leading, spacing: 4) {
            Text("Chart Mode")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                SpeedWidgetView(
                    downloadSpeed: 8_500_000,
                    uploadSpeed: 1_200_000,
                    config: SpeedWidgetConfig(displayMode: .chart),
                    connectionType: .wifi
                )

                SpeedWidgetView(
                    downloadSpeed: 2_100_000,
                    uploadSpeed: 350_000,
                    config: SpeedWidgetConfig(displayMode: .chart, iconMode: .dots),
                    connectionType: .ethernet
                )
            }
        }

        // Different icon modes
        VStack(alignment: .leading, spacing: 4) {
            Text("Icon Modes")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                SpeedWidgetView(
                    downloadSpeed: 3_500_000,
                    uploadSpeed: 500_000,
                    config: SpeedWidgetConfig(displayMode: .oneRow, iconMode: .arrows)
                )
                SpeedWidgetView(
                    downloadSpeed: 3_500_000,
                    uploadSpeed: 500_000,
                    config: SpeedWidgetConfig(displayMode: .oneRow, iconMode: .dots)
                )
                SpeedWidgetView(
                    downloadSpeed: 3_500_000,
                    uploadSpeed: 500_000,
                    config: SpeedWidgetConfig(displayMode: .oneRow, iconMode: .io)
                )
                SpeedWidgetView(
                    downloadSpeed: 3_500_000,
                    uploadSpeed: 500_000,
                    config: SpeedWidgetConfig(displayMode: .oneRow, iconMode: .labels)
                )
            }
        }

        // Disconnected state
        VStack(alignment: .leading, spacing: 4) {
            Text("Disconnected")
                .font(.caption)
                .foregroundColor(.secondary)

            SpeedWidgetView(
                downloadSpeed: 0,
                uploadSpeed: 0,
                config: SpeedWidgetConfig(displayMode: .oneRow),
                connectionType: nil
            )
        }
    }
    .padding()
}
