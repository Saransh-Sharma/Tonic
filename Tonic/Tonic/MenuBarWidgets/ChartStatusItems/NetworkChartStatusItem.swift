//
//  NetworkChartStatusItem.swift
//  Tonic
//
//  Status item for network chart visualization
//  Task ID: fn-6-i4g.12
//

import AppKit
import SwiftUI

/// Status item that displays a dual-line network chart in the menu bar
@MainActor
public final class NetworkChartStatusItem: WidgetStatusItem {

    private var chartState: NetworkChartWidgetState {
        NetworkChartWidgetState()
    }

    public override func createCompactView() -> AnyView {
        let dataManager = WidgetDataManager.shared
        let networkData = dataManager.networkData

        // Create network chart data
        let chartData = NetworkChartData(
            upload: dataManager.getNetworkUploadHistory(),
            download: dataManager.getNetworkDownloadHistory(),
            currentUpload: networkData.uploadBytesPerSecond,
            currentDownload: networkData.downloadBytesPerSecond
        )

        let config = NetworkChartConfig(
            historySize: configuration.chartConfig?.historySize ?? 60,
            scaling: configuration.chartConfig?.scaling ?? .linear,
            showBackground: configuration.chartConfig?.showBackground ?? false,
            showFrame: configuration.chartConfig?.showFrame ?? false,
            showValues: configuration.chartConfig?.showValue ?? false,
            independentScaling: true
        )

        return AnyView(
            NetworkChartWidgetView(data: chartData, config: config)
        )
    }

    public override func createDetailView() -> AnyView {
        // Detail view shows extended network info
        let dataManager = WidgetDataManager.shared
        let networkData = dataManager.networkData

        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                Text("Network Activity")
                    .font(.headline)

                HStack(spacing: 20) {
                    VStack(alignment: .leading) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down")
                                .foregroundColor(.blue)
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

                // Extended network chart for detail view
                NetworkChartWidgetView(
                    data: NetworkChartData(
                        upload: dataManager.getNetworkUploadHistory(),
                        download: dataManager.getNetworkDownloadHistory(),
                        currentUpload: networkData.uploadBytesPerSecond,
                        currentDownload: networkData.downloadBytesPerSecond
                    ),
                    config: NetworkChartConfig(
                        historySize: 90,
                        showBackground: true,
                        showFrame: true,
                        showValues: true
                    )
                )
                .frame(height: 60)
            }
            .padding()
            .frame(width: 220)
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
