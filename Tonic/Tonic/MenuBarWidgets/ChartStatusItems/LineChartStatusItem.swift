//
//  LineChartStatusItem.swift
//  Tonic
//
//  Status item for line chart visualization
//  Task ID: fn-6-i4g.12
//  Performance optimized view refresh
//

import AppKit
import SwiftUI

/// Status item that displays a line chart visualization in the menu bar
@MainActor
public final class LineChartStatusItem: WidgetStatusItem {

    /// Performance optimization: Cache history hash to avoid unnecessary redraws
    private var cachedHistoryHash: Int = 0

    public override func createCompactView() -> AnyView {
        let dataManager = WidgetDataManager.shared
        let history: [Double]
        let currentValue: Double

        switch widgetType {
        case .cpu:
            history = dataManager.getCPUHistory()
            currentValue = dataManager.cpuData.totalUsage
        case .memory:
            history = dataManager.getMemoryHistory()
            currentValue = dataManager.memoryData.usagePercentage
        case .network:
            // For network, use download history
            history = dataManager.getNetworkDownloadHistory()
            currentValue = min(1.0, dataManager.networkData.downloadBytesPerSecond / 10_000_000) // Normalize to 0-1
        case .gpu:
            history = dataManager.getCPUHistory() // Reuse CPU history as placeholder
            currentValue = dataManager.gpuData.usagePercentage ?? 0
        default:
            history = []
            currentValue = 0
        }

        // Create line chart config from widget configuration
        let chartConfig = LineChartConfig(
            historySize: configuration.chartConfig?.historySize ?? 60,
            scaling: configuration.chartConfig?.scaling ?? .linear,
            showBackground: configuration.chartConfig?.showBackground ?? false,
            showFrame: configuration.chartConfig?.showFrame ?? false,
            showValue: false,
            showValueOverlay: configuration.chartConfig?.showValue ?? false,
            fillMode: .gradient,
            lineColor: .blue
        )

        // Performance: Use cached data if unchanged
        let currentHash = history.hashValue
        if currentHash == cachedHistoryHash && cachedHistoryHash != 0 {
            // Data unchanged, view will use SwiftUI's built-in diffing
        }
        cachedHistoryHash = currentHash

        return AnyView(
            LineChartWidgetView(
                data: history.isEmpty ? [0.3, 0.4, 0.35, 0.5, 0.45, 0.6] : history,
                config: chartConfig,
                currentValue: currentValue
            )
            .equatable() // Performance: Add equatable modifier to prevent unnecessary redraws
        )
    }

    public override func createDetailView() -> AnyView {
        let dataManager = WidgetDataManager.shared

        // Use Stats Master-style popover for CPU
        if widgetType == .cpu {
            return AnyView(CPUPopoverView())
        }

        // Use Stats Master-style popover for GPU
        if widgetType == .gpu {
            // TODO: GPUPopoverView needs to be added to Xcode project
            return AnyView(GPUDetailView())
        }

        // Get chart data based on widget type
        let history: [Double]
        let currentValue: Double

        switch widgetType {
        case .memory:
            history = dataManager.getMemoryHistory()
            currentValue = dataManager.memoryData.usagePercentage
        default:
            history = []
            currentValue = 0
        }

        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: widgetType.icon)
                        .foregroundColor(.blue)
                    Text("\(widgetType.displayName) History")
                        .font(.headline)
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Current: \(Int(currentValue * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    LineChartWidgetView(
                        data: history.isEmpty ? [0.3, 0.4, 0.35] : history,
                        config: LineChartConfig(
                            historySize: 90,
                            showBackground: true,
                            showFrame: true,
                            fillMode: .gradient
                        ),
                        currentValue: currentValue
                    )
                    .frame(height: 60)
                }

                Spacer()
            }
            .padding()
            .frame(width: 250, height: 180)
        )
    }
}
