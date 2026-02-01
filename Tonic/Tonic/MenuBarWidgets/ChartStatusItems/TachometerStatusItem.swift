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
        let dataManager = WidgetDataManager.shared
        let value: Double
        let label: String
        let details: String

        switch widgetType {
        case .cpu:
            value = dataManager.cpuData.totalUsage
            label = "CPU Usage"
            details = "Per-core: \(dataManager.cpuData.perCoreUsage.count) cores"
        case .memory:
            value = dataManager.memoryData.usagePercentage
            label = "Memory Usage"
            let usedGB = Double(dataManager.memoryData.usedBytes) / (1024 * 1024 * 1024)
            let totalGB = Double(dataManager.memoryData.totalBytes) / (1024 * 1024 * 1024)
            details = String(format: "%.1f / %.1f GB", usedGB, totalGB)
        case .gpu:
            value = dataManager.gpuData.usagePercentage ?? 0
            label = "GPU Usage"
            details = value > 0 ? "Active" : "Idle"
        default:
            value = 0
            label = "Usage"
            details = ""
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

                VStack(alignment: .center, spacing: 8) {
                    // Simple circular progress indicator
                    ZStack {
                        Circle()
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 8)
                            .frame(width: 70, height: 70)

                        Circle()
                            .trim(from: 0, to: value / 100)
                            .stroke(
                                LinearGradient(
                                    colors: [.green, .yellow, .orange, .red],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .frame(width: 70, height: 70)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.3), value: value)

                        Text("\(Int(value))%")
                            .font(.system(.title2, design: .rounded))
                            .fontWeight(.medium)
                    }
                    .frame(width: 80, height: 80)

                    if !details.isEmpty {
                        Text(details)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)

                Spacer()
            }
            .padding()
            .frame(width: 200, height: 180)
        )
    }
}
