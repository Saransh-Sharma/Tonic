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
        // Always use the full Stats Master-style popover for parity
        AnyView(NetworkPopoverView())
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
