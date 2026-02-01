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
        let dataManager = WidgetDataManager.shared

        // Use Stats Master-style popover for CPU
        if widgetType == .cpu {
            return AnyView(CPUPopoverView())
        }

        // Use Stats Master-style popover for GPU
        if widgetType == .gpu {
            return AnyView(GPUPopoverView())
        }

        // Use Stats Master-style popover for Disk
        if widgetType == .disk {
            return AnyView(DiskPopoverView())
        }

        // Use generic popover for other widget types
        let value: Double
        let label: String
        let details: String
        let secondaryValue: String?

        switch widgetType {
        case .memory:
            value = dataManager.memoryData.usagePercentage
            label = "Memory Usage"
            let usedGB = Double(dataManager.memoryData.usedBytes) / (1024 * 1024 * 1024)
            let totalGB = Double(dataManager.memoryData.totalBytes) / (1024 * 1024 * 1024)
            details = String(format: "%.1f / %.1f GB", usedGB, totalGB)
            secondaryValue = "\(Int(dataManager.memoryData.usagePercentage))%"
        case .disk:
            if let primary = dataManager.diskVolumes.first {
                value = primary.usagePercentage
                label = primary.name
                let usedGB = Double(primary.usedBytes) / (1024 * 1024 * 1024)
                let totalGB = Double(primary.totalBytes) / (1024 * 1024 * 1024)
                details = String(format: "%.1f / %.1f GB", usedGB, totalGB)
                secondaryValue = "\(Int(primary.usagePercentage))%"
            } else {
                value = 0
                label = "Disk Usage"
                details = "No disks found"
                secondaryValue = nil
            }
        case .gpu:
            value = dataManager.gpuData.usagePercentage ?? 0
            label = "GPU Usage"
            details = value > 0 ? "Active" : "Idle"
            secondaryValue = "\(Int(value))%"
        case .battery:
            value = dataManager.batteryData.chargePercentage
            label = "Battery"
            if dataManager.batteryData.isCharging {
                details = "Charging"
            } else if dataManager.batteryData.isCharged {
                details = "Fully Charged"
            } else {
                let minutes = dataManager.batteryData.estimatedMinutesRemaining ?? 0
                details = minutes > 0 ? "\(minutes) min remaining" : "Calculating..."
            }
            secondaryValue = "\(Int(dataManager.batteryData.chargePercentage))%"
        default:
            value = 0
            label = "Usage"
            details = ""
            secondaryValue = nil
        }

        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: widgetType.icon)
                        .foregroundColor(.blue)
                    Text(label)
                        .font(.headline)
                    Spacer()
                }

                HStack(spacing: 16) {
                    // Simple circular progress for detail view
                    ZStack {
                        Circle()
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 6)
                            .frame(width: 60, height: 60)

                        Circle()
                            .trim(from: 0, to: value / 100)
                            .stroke(
                                configuration.accentColor.colorValue(for: widgetType),
                                style: StrokeStyle(lineWidth: 6, lineCap: .round)
                            )
                            .frame(width: 60, height: 60)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.3), value: value)
                    }
                    .frame(width: 70, height: 70)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(details)
                            .font(.system(.body, design: .monospaced))

                        if let secondary = secondaryValue {
                            Text(secondary)
                                .font(.system(.title2, design: .rounded))
                                .fontWeight(.medium)
                        } else {
                            Text("\(Int(value))%")
                                .font(.system(.title2, design: .rounded))
                                .fontWeight(.medium)
                        }
                    }

                    Spacer()
                }

                Spacer()
            }
            .padding()
            .frame(width: 200, height: 150)
        )
    }
}
