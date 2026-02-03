//
//  CPUWidgetView.swift
//  Tonic
//
//  CPU monitoring widget views
//  Task ID: fn-2.4
//  Updated: fn-6-i4g.18 - Standardized popover layout
//

import SwiftUI
import Charts
import os

// MARK: - CPU Compact View

/// Compact menu bar view for CPU widget
public struct CPUCompactView: View {
    let cpuUsage: Double

    public init(cpuUsage: Double) {
        self.cpuUsage = cpuUsage
    }

    public var body: some View {
        let cpuValue = Int(cpuUsage)

        HStack(spacing: 4) {
            Image(systemName: "cpu")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(usageColor)

            Text("\(cpuValue)%")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 4)
        .frame(height: 22)
    }

    private var usageColor: Color {
        switch cpuUsage {
        case 0..<50: return TonicColors.success
        case 50..<80: return TonicColors.warning
        default: return TonicColors.error
        }
    }
}

// MARK: - CPU Detail View

/// Detailed popover view for CPU widget
/// Uses standardized PopoverTemplate for consistent layout
public struct CPUDetailView: View {

    @State private var dataManager = WidgetDataManager.shared

    public init() {}

    public var body: some View {
        PopoverTemplate(
            icon: PopoverConstants.Icons.cpu,
            title: PopoverConstants.Names.cpu,
            headerValue: "\(Int(dataManager.cpuData.totalUsage))%",
            headerColor: usageColor
        ) {
            // Total usage display
            totalUsageSection

            // Per-core usage
            perCoreSection

            // History graph
            historyGraphSection

            // Top apps
            topAppsSection

            // Activity Monitor link
            ActivityMonitorButton()
        }
    }

    private var totalUsageSection: some View {
        VStack(alignment: .leading, spacing: PopoverConstants.itemSpacing) {
            Text("Total Usage")
                .font(PopoverConstants.sectionTitleFont)
                .foregroundColor(.secondary)

            HStack(alignment: .lastTextBaseline, spacing: DesignTokens.Spacing.sm) {
                Text("\(Int(dataManager.cpuData.totalUsage))%")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(usageColor)

                Text("of \(dataManager.cpuData.perCoreUsage.count) cores")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Usage bar
            UsageBar(percentage: dataManager.cpuData.totalUsage, color: usageColor)
        }
    }

    private var perCoreSection: some View {
        TitledPopoverSection(title: "Per-Core Usage") {
            VStack(spacing: PopoverConstants.itemSpacing) {
                ForEach(Array(dataManager.cpuData.perCoreUsage.enumerated()), id: \.offset) { index, usage in
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        Text("Core \(index + 1)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 50, alignment: .leading)

                        UsageBar(percentage: usage, color: colorForUsage(usage), height: 6)

                        Text("\(Int(usage))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 35, alignment: .trailing)
                    }
                }
            }
        }
    }

    private var historyGraphSection: some View {
        TitledPopoverSection(title: "Usage History") {
            Chart(dataManager.cpuHistory.enumerated().map { (index, value) in
                ChartDataPoint(index: index, value: value)
            }) { item in
                LineMark(
                    x: .value("Time", item.index),
                    y: .value("Usage", item.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(usageColor.gradient)
                .lineStyle(StrokeStyle(lineWidth: 2))

                AreaMark(
                    x: .value("Time", item.index),
                    y: .value("Usage", item.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        colors: [usageColor.opacity(0.3), usageColor.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .chartYScale(domain: 0...100)
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                    AxisValueLabel {
                        if let intValue = value.as(Int.self) {
                            Text("\(intValue)%")
                                .font(.caption2)
                        }
                    }
                    AxisGridLine()
                }
            }
            .chartXAxis(.hidden)
            .frame(height: 100)
        }
    }

    private var topAppsSection: some View {
        ProcessListWidgetView(widgetType: .cpu, maxCount: 5)
    }

    private var usageColor: Color {
        colorForUsage(dataManager.cpuData.totalUsage)
    }

    private func colorForUsage(_ usage: Double) -> Color {
        switch usage {
        case 0..<50: return TonicColors.success
        case 50..<80: return TonicColors.warning
        default: return TonicColors.error
        }
    }
}

// MARK: - Chart Data Point

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let index: Int
    let value: Double
}

// MARK: - CPU Status Item

/// Manages the CPU widget's NSStatusItem
@MainActor
public final class CPUStatusItem: WidgetStatusItem {

    public override init(widgetType: WidgetType = .cpu, configuration: WidgetConfiguration) {
        super.init(widgetType: widgetType, configuration: configuration)
    }

    // Uses base WidgetStatusItem.createCompactView() which respects configuration

    public override func createDetailView() -> AnyView {
        AnyView(CPUDetailView())
    }
}

// MARK: - Preview

#Preview("CPU Detail") {
    CPUDetailView()
}
