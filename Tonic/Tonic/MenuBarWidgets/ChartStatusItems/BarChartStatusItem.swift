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
        let dataManager = WidgetDataManager.shared

        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: widgetType.icon)
                        .foregroundColor(.blue)
                    Text("\(widgetType.displayName) Details")
                        .font(.headline)
                    Spacer()
                }

                switch widgetType {
                case .cpu:
                    cpuDetailView(dataManager)
                case .memory:
                    memoryDetailView(dataManager)
                default:
                    Text("Detailed view coming soon")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            .padding()
            .frame(width: 250, height: 180)
        )
    }

    @ViewBuilder
    private func cpuDetailView(_ dataManager: WidgetDataManager) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Total CPU
            HStack {
                Text("Total CPU")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(dataManager.cpuData.totalUsage))%")
                    .font(.system(.body, design: .monospaced))
            }

            Divider()

            // Per-core with E/P coloring
            if !dataManager.cpuData.perCoreUsage.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Per-Core Usage")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    BarChartWidgetView(
                        data: dataManager.cpuData.perCoreUsage,
                        config: BarChartConfig(
                            barWidth: 6,
                            barSpacing: 2,
                            colorMode: .ePCores
                        ),
                        epCoreData: EPCoreData(
                            eCores: dataManager.cpuData.eCoreUsage ?? [],
                            pCores: dataManager.cpuData.pCoreUsage ?? []
                        )
                    )
                    .frame(height: 50)
                }
            }

            // E/P legend
            if dataManager.cpuData.eCoreUsage != nil || dataManager.cpuData.pCoreUsage != nil {
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(red: 0.37, green: 0.62, blue: 1.0))
                            .frame(width: 12, height: 12)
                        Text("E Cores")
                            .font(.caption2)
                    }
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(red: 1.0, green: 0.62, blue: 0.04))
                            .frame(width: 12, height: 12)
                        Text("P Cores")
                            .font(.caption2)
                    }
                }
            }

            Spacer()
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
