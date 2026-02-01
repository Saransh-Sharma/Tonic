//
//  MemoryWidgetView.swift
//  Tonic
//
//  Memory monitoring widget views
//  Task ID: fn-2.6
//  Updated: fn-6-i4g.18 - Standardized popover layout
//

import SwiftUI
import Charts

// MARK: - Memory Compact View

/// Compact menu bar view for Memory widget
public struct MemoryCompactView: View {
    let usagePercentage: Double
    let pressure: MemoryPressure

    public init(usagePercentage: Double, pressure: MemoryPressure) {
        self.usagePercentage = usagePercentage
        self.pressure = pressure
    }

    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "memorychip")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(pressureColor)

            Text("\(Int(usagePercentage))%")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.primary)

            // Pressure indicator dot
            Circle()
                .fill(pressureColor)
                .frame(width: 6, height: 6)
        }
        .padding(.horizontal, 4)
        .frame(height: 22)
    }

    private var pressureColor: Color {
        switch pressure {
        case .normal: return TonicColors.success
        case .warning: return TonicColors.warning
        case .critical: return TonicColors.error
        }
    }
}

// MARK: - Memory Detail View

/// Detailed popover view for Memory widget
/// Uses standardized PopoverTemplate for consistent layout
public struct MemoryDetailView: View {

    @State private var dataManager = WidgetDataManager.shared

    public init() {}

    public var body: some View {
        PopoverTemplate(
            icon: PopoverConstants.Icons.memory,
            title: PopoverConstants.Names.memory,
            headerValue: "\(Int(dataManager.memoryData.usagePercentage))%",
            headerColor: pressureColor
        ) {
            // Usage gauge
            usageGaugeSection

            // Memory breakdown
            memoryBreakdownSection

            // Pressure level
            pressureSection

            // History graph
            historyGraphSection

            // Top apps
            topAppsSection

            // Activity Monitor link
            ActivityMonitorButton()
        }
    }

    private var usageGaugeSection: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            // Circular gauge with centered value
            ZStack {
                CircularProgress(
                    percentage: dataManager.memoryData.usagePercentage,
                    size: 120,
                    lineWidth: 12,
                    color: pressureColor
                )

                VStack(spacing: 4) {
                    Text("\(Int(dataManager.memoryData.usagePercentage))%")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(pressureColor)

                    Text("used")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Used/Total text
            HStack(spacing: 4) {
                Text(formatBytes(dataManager.memoryData.usedBytes))
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("of")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(formatBytes(dataManager.memoryData.totalBytes))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var memoryBreakdownSection: some View {
        TitledPopoverSection(title: "Memory Breakdown") {
            VStack(spacing: 10) {
                memoryRow(label: "Used", value: dataManager.memoryData.usedBytes, color: pressureColor)
                memoryRow(label: "Compressed", value: dataManager.memoryData.compressedBytes, color: .purple)
                memoryRow(label: "Swap", value: dataManager.memoryData.swapBytes, color: .orange)

                let freeBytes = dataManager.memoryData.totalBytes - dataManager.memoryData.usedBytes
                memoryRow(label: "Free", value: freeBytes, color: .gray)
            }
        }
    }

    private func memoryRow(label: String, value: UInt64, color: Color) -> some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .leading)

            UsageBar(
                percentage: (Double(value) / Double(dataManager.memoryData.totalBytes)) * 100,
                color: color,
                height: 6
            )

            Text(formatBytes(value))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .trailing)
        }
    }

    private var pressureSection: some View {
        PopoverSection {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: pressureIcon)
                    .font(.title2)
                    .foregroundColor(pressureColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text(pressureText)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(pressureDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
        }
    }

    private var historyGraphSection: some View {
        TitledPopoverSection(title: "Usage History") {
            Chart(dataManager.memoryHistory.enumerated().map { (index, value) in
                ChartDataPoint(index: index, value: value)
            }) { item in
                LineMark(
                    x: .value("Time", item.index),
                    y: .value("Usage", item.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(pressureColor.gradient)
                .lineStyle(StrokeStyle(lineWidth: 2))

                AreaMark(
                    x: .value("Time", item.index),
                    y: .value("Usage", item.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        colors: [pressureColor.opacity(0.3), pressureColor.opacity(0.05)],
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
        ProcessListWidgetView(widgetType: .memory, maxCount: 5)
    }

    private var pressureColor: Color {
        switch dataManager.memoryData.pressure {
        case .normal: return TonicColors.success
        case .warning: return TonicColors.warning
        case .critical: return TonicColors.error
        }
    }

    private var pressureIcon: String {
        switch dataManager.memoryData.pressure {
        case .normal: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .critical: return "xmark.circle.fill"
        }
    }

    private var pressureText: String {
        switch dataManager.memoryData.pressure {
        case .normal: return "Normal"
        case .warning: return "Warning"
        case .critical: return "Critical"
        }
    }

    private var pressureDescription: String {
        switch dataManager.memoryData.pressure {
        case .normal: return "Memory pressure is normal"
        case .warning: return "System is under memory pressure"
        case .critical: return "Critical memory pressure - close apps"
        }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory)
    }
}

// MARK: - Memory Status Item

/// Manages the Memory widget's NSStatusItem
@MainActor
public final class MemoryStatusItem: WidgetStatusItem {

    public override init(widgetType: WidgetType = .memory, configuration: WidgetConfiguration) {
        super.init(widgetType: widgetType, configuration: configuration)
    }

    // Uses base WidgetStatusItem.createCompactView() which respects configuration

    public override func createDetailView() -> AnyView {
        AnyView(MemoryDetailView())
    }
}

// MARK: - Preview

#Preview("Memory Detail") {
    MemoryDetailView()
}
