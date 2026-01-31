//
//  LineChartStatusItem.swift
//  Tonic
//
//  Status item for line chart visualization
//

import AppKit
import SwiftUI

/// Status item that displays a line chart visualization in the menu bar
@MainActor
public final class LineChartStatusItem: WidgetStatusItem {

    public override func createCompactView() -> AnyView {
        let dataManager = WidgetDataManager.shared
        let value: Double

        switch widgetType {
        case .cpu:
            value = dataManager.cpuData.totalUsage
        case .memory:
            value = dataManager.memoryData.usagePercentage
        case .network:
            value = dataManager.networkData.downloadBytesPerSecond / 1024 // KB/s
        case .gpu:
            value = dataManager.gpuData.usagePercentage ?? 0
        default:
            value = 0
        }

        // TODO: Implement LineChartWidgetView
        return AnyView(
            Text("\(Int(value))%")
                .font(.system(size: 11))
                .foregroundColor(configuration.accentColor.colorValue(for: widgetType))
        )
    }

    public override func createDetailView() -> AnyView {
        // TODO: Implement proper detail views
        return AnyView(EmptyView())
    }
}
