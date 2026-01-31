//
//  BarChartStatusItem.swift
//  Tonic
//
//  Status item for bar chart visualization
//

import AppKit
import SwiftUI

/// Status item that displays a bar chart visualization in the menu bar
@MainActor
public final class BarChartStatusItem: WidgetStatusItem {

    public override func createCompactView() -> AnyView {
        let dataManager = WidgetDataManager.shared
        let value: Double

        switch widgetType {
        case .cpu:
            value = dataManager.cpuData.totalUsage
        case .memory:
            value = dataManager.memoryData.usagePercentage
        case .disk:
            if let primary = dataManager.diskVolumes.first {
                value = primary.usagePercentage
            } else {
                value = 0
            }
        case .gpu:
            value = dataManager.gpuData.usagePercentage ?? 0
        default:
            value = 0
        }

        // TODO: Implement BarChartWidgetView
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
