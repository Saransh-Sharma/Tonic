//
//  PieChartStatusItem.swift
//  Tonic
//
//  Status item for pie chart visualization
//  Performance optimized view refresh
//

import AppKit
import SwiftUI

/// Status item that displays a pie chart visualization in the menu bar
@MainActor
public final class PieChartStatusItem: WidgetStatusItem {

    /// Performance optimization: Cache value to avoid unnecessary redraws
    private var cachedValue: Double = -1

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
        case .battery:
            value = dataManager.batteryData.chargePercentage
        default:
            value = 0
        }

        // Use PieChartWidgetView for actual pie chart visualization
        let normalizedValue = value / 100.0
        let color = configuration.accentColor.colorValue(for: widgetType)

        return AnyView(
            PieChartWidgetView(
                value: normalizedValue,
                config: PieChartConfig(
                    size: 18,
                    strokeWidth: 3,
                    showBackgroundCircle: true,
                    showLabel: false,
                    colorMode: configuration.accentColor == .utilization ? .dynamic : .fixed
                ),
                fixedColor: color
            )
            .equatable() // Performance: Add equatable modifier to prevent unnecessary redraws
        )
    }

    public override func createDetailView() -> AnyView {
        // Use Stats Master-style popover for all supported widget types
        switch widgetType {
        case .cpu:
            return AnyView(CPUPopoverView())
        case .gpu:
            return AnyView(GPUPopoverView())
        case .memory:
            return AnyView(MemoryPopoverView())
        case .disk:
            return AnyView(DiskPopoverView())
        case .network:
            return AnyView(NetworkPopoverView())
        case .battery:
            return AnyView(BatteryPopoverView())
        case .sensors:
            return AnyView(SensorsPopoverView())
        case .bluetooth:
            return AnyView(BluetoothPopoverView())
        default:
            // Fallback for weather, clock, or other types
            return super.createDetailView()
        }
    }
}
