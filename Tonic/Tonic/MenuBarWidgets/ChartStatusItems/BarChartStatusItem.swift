//
//  BarChartStatusItem.swift
//  Tonic
//
//  Status item for bar chart visualization
//  Task ID: fn-6-i4g.12
//

import AppKit
import SwiftUI

/// Status item that displays a bar chart visualization in the menu bar
@MainActor
public final class BarChartStatusItem: WidgetStatusItem {

    public override func createCompactView() -> AnyView {
        let dataManager = WidgetDataManager.shared
        let data: [Double]
        let epData: EPCoreData?

        switch widgetType {
        case .cpu:
            data = dataManager.cpuData.perCoreUsage
            epData = EPCoreData(
                eCores: dataManager.cpuData.eCoreUsage ?? [],
                pCores: dataManager.cpuData.pCoreUsage ?? []
            )
        case .memory:
            // Memory zones (simulated)
            data = [
                dataManager.memoryData.usagePercentage,
                (dataManager.memoryData.pressureValue ?? 0) / 100,
                Double(dataManager.memoryData.compressedBytes) / Double(dataManager.memoryData.totalBytes),
                Double(dataManager.memoryData.swapBytes) / Double(dataManager.memoryData.totalBytes)
            ]
            epData = nil
        case .gpu:
            data = [dataManager.gpuData.usagePercentage ?? 0]
            epData = nil
        default:
            data = []
            epData = nil
        }

        let chartConfig = BarChartConfig(
            barWidth: 3,
            barSpacing: 1,
            showLabels: false,
            colorMode: .ePCores,
            stackedMode: false
        )

        return AnyView(
            BarChartWidgetView(
                data: data.isEmpty ? [0.3, 0.5, 0.4] : data,
                config: chartConfig,
                baseColor: configuration.accentColor.colorValue(for: widgetType),
                epCoreData: epData
            )
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

    @ViewBuilder
    private func memoryDetailView(_ dataManager: WidgetDataManager) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Used")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(dataManager.memoryData.usagePercentage))%")
                    .font(.system(.body, design: .monospaced))
            }

            HStack {
                Text("Pressure")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(dataManager.memoryData.pressureValue ?? 0))")
                    .font(.system(.body, design: .monospaced))
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Memory Zones")
                    .font(.caption)
                    .foregroundColor(.secondary)

                BarChartWidgetView(
                    data: [
                        dataManager.memoryData.usagePercentage / 100,
                        (dataManager.memoryData.pressureValue ?? 0) / 100,
                        Double(dataManager.memoryData.compressedBytes) / Double(max(1, dataManager.memoryData.totalBytes)),
                        Double(dataManager.memoryData.swapBytes) / Double(max(1, dataManager.memoryData.totalBytes))
                    ],
                    config: BarChartConfig(
                        barWidth: 8,
                        barSpacing: 4,
                        colorMode: .byValue
                    ),
                    baseColor: .green
                )
                .frame(height: 50)
            }

            Spacer()
        }
    }
}
