//
//  SpeedStatusItem.swift
//  Tonic
//
//  Status item for network speed visualization
//

import AppKit
import SwiftUI

/// Status item that displays network up/down speeds in the menu bar
@MainActor
public final class SpeedStatusItem: WidgetStatusItem {

    public override func createCompactView() -> AnyView {
        let dataManager = WidgetDataManager.shared
        let upload = dataManager.networkData.uploadBytesPerSecond
        let download = dataManager.networkData.downloadBytesPerSecond

        // TODO: Implement SpeedWidgetView
        return AnyView(
            Text("↑\(formatSpeed(upload)) ↓\(formatSpeed(download))")
                .font(.system(size: 10))
                .foregroundColor(configuration.accentColor.colorValue(for: widgetType))
        )
    }

    public override func createDetailView() -> AnyView {
        let dataManager = WidgetDataManager.shared
        let networkData = dataManager.networkData

        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: widgetType.icon)
                        .foregroundColor(.blue)
                    Text("Network Speed")
                        .font(.headline)
                    Spacer()
                }

                HStack(spacing: 20) {
                    VStack(alignment: .leading) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down")
                                .foregroundColor(.cyan)
                            Text("Download")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Text(formatSpeed(networkData.downloadBytesPerSecond))
                            .font(.system(.body, design: .monospaced))
                    }

                    VStack(alignment: .leading) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up")
                                .foregroundColor(.green)
                            Text("Upload")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Text(formatSpeed(networkData.uploadBytesPerSecond))
                            .font(.system(.body, design: .monospaced))
                    }
                }

                Divider()

                // Show connection info if available
                if let ssid = networkData.ssid {
                    HStack {
                        Text("Network:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(ssid)
                            .font(.caption)
                        Spacer()
                    }
                }

                if let ip = networkData.ipAddress {
                    HStack {
                        Text("IP Address:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(ip)
                            .font(.system(.caption, design: .monospaced))
                        Spacer()
                    }
                }

                Spacer()
            }
            .padding()
            .frame(width: 220, height: 160)
        )
    }

    private func formatSpeed(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond < 1024 {
            return "\(Int(bytesPerSecond)) B/s"
        } else if bytesPerSecond < 1024 * 1024 {
            return String(format: "%.1f KB/s", bytesPerSecond / 1024)
        } else {
            return String(format: "%.2f MB/s", bytesPerSecond / (1024 * 1024))
        }
    }
}
