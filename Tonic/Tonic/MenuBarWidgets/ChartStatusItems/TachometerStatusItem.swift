//
//  TachometerStatusItem.swift
//  Tonic
//
//  Status item for tachometer/gauge visualization
//

import AppKit
import SwiftUI

/// Status item that displays a tachometer gauge visualization in the menu bar
@MainActor
public final class TachometerStatusItem: WidgetStatusItem {

    public override func createCompactView() -> AnyView {
        let dataManager = WidgetDataManager.shared
        let value: Double

        switch widgetType {
        case .cpu:
            value = dataManager.cpuData.totalUsage
        case .memory:
            value = dataManager.memoryData.usagePercentage
        case .gpu:
            value = dataManager.gpuData.usagePercentage ?? 0
        default:
            value = 0
        }

        // TODO: Implement TachometerWidgetView
        return AnyView(
            Text("\(Int(value))%")
                .font(.system(size: 11))
                .foregroundColor(configuration.accentColor.colorValue(for: widgetType))
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
