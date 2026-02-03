//
//  MemoryPopoverView.swift
//  Tonic
//
//  Stats Master-style Memory popover with pressure gauge dashboard
//  Task ID: fn-8-v3b.4
//

import SwiftUI

// MARK: - Memory Popover View

/// Complete Stats Master-style Memory popover with:
/// - Dashboard section (pressure gauge with 3-color arc)
/// - Usage history line chart
/// - Details section (Used, Wired, Active, Compressed, Free, Total)
/// - Swap section (hidden if not configured)
/// - Top processes list
public struct MemoryPopoverView: View {

    // MARK: - Properties

    @State private var dataManager = WidgetDataManager.shared

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            ScrollView {
                VStack(spacing: PopoverConstants.sectionSpacing) {
                    // Dashboard Section
                    dashboardSection

                    Divider()

                    // History Chart
                    historyChartSection

                    Divider()

                    // Details Section
                    detailsSection

                    // Swap Section (only show if swap is configured)
                    if hasSwapData {
                        Divider()
                        swapSection
                    }

                    Divider()

                    // Top Processes
                    topProcessesSection
                }
                .padding(PopoverConstants.horizontalPadding)
                .padding(.vertical, PopoverConstants.verticalPadding)
            }
        }
        .frame(width: PopoverConstants.width, height: PopoverConstants.maxHeight)
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(PopoverConstants.cornerRadius)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: PopoverConstants.iconTextGap) {
            // Icon
            Image(systemName: PopoverConstants.Icons.memory)
                .font(.title2)
                .foregroundColor(DesignTokens.Colors.accent)

            // Title
            Text("Memory")
                .font(PopoverConstants.headerTitleFont)
                .foregroundColor(DesignTokens.Colors.textPrimary)

            Spacer()

            // Activity Monitor button
            Button {
                NSWorkspace.shared.launchApplication("Activity Monitor")
            } label: {
                HStack(spacing: PopoverConstants.compactSpacing) {
                    Image(systemName: PopoverConstants.Icons.activityMonitor)
                        .font(.system(size: PopoverConstants.mediumIconSize))
                    Text("Activity Monitor")
                        .font(PopoverConstants.smallLabelFont)
                }
                .foregroundColor(DesignTokens.Colors.textSecondary)
            }
            .buttonStyle(.plain)

            // Settings button
            Button {
                // TODO: Open settings to Memory widget configuration
            } label: {
                Image(systemName: PopoverConstants.Icons.settings)
                    .font(.body)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Dashboard Section

    private var dashboardSection: some View {
        VStack(alignment: .leading, spacing: PopoverConstants.itemSpacing) {
            PopoverSectionHeader(title: "Dashboard")

            HStack(spacing: DesignTokens.Spacing.sm) {
                // Memory pressure gauge (primary visual)
                MemoryPressureGaugeView(
                    pressurePercentage: pressurePercentage,
                    pressureLevel: dataManager.memoryData.pressure,
                    size: 80
                )

                VStack(spacing: PopoverConstants.compactSpacing) {
                    // Used memory metric
                    MetricCard(
                        value: formatBytes(dataManager.memoryData.usedBytes),
                        label: "Used",
                        color: .blue
                    )

                    // Free memory metric
                    if let freeBytes = dataManager.memoryData.freeBytes {
                        MetricCard(
                            value: formatBytes(freeBytes),
                            label: "Free",
                            color: .green
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: 90) // Stats Master parity: 90px dashboard height
    }

    // MARK: - History Chart Section

    private var historyChartSection: some View {
        VStack(alignment: .leading, spacing: PopoverConstants.itemSpacing) {
            PopoverSectionHeader(title: "Usage History")

            NetworkSparklineChart(
                data: dataManager.memoryHistory,
                color: DesignTokens.Colors.accent,
                height: 70,
                showArea: true,
                lineWidth: 1.5
            )
            .frame(height: 70)
        }
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: PopoverConstants.itemSpacing) {
            PopoverSectionHeader(title: "Details")

            // Two-column grid for memory details
            let detailItems = memoryDetailItems
            let halfCount = (detailItems.count + 1) / 2

            ForEach(0..<halfCount, id: \.self) { index in
                HStack(spacing: DesignTokens.Spacing.md) {
                    // Left column item
                    if index < detailItems.count {
                        detailRow(for: detailItems[index])
                    }

                    Spacer()

                    // Right column item
                    if index + halfCount < detailItems.count {
                        detailRow(for: detailItems[index + halfCount])
                    }
                }
            }
        }
    }

    private func detailRow(for item: MemoryDetailItem) -> some View {
        HStack(spacing: 4) {
            if let icon = item.icon {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Text(item.label)
                .font(PopoverConstants.detailLabelFont)
                .foregroundColor(.secondary)

            Text(item.value)
                .font(PopoverConstants.detailValueFont)
                .fontWeight(.medium)
                .foregroundColor(item.valueColor)
        }
    }

    // MARK: - Swap Section

    private var swapSection: some View {
        VStack(alignment: .leading, spacing: PopoverConstants.itemSpacing) {
            PopoverSectionHeader(title: "Swap")

            HStack(spacing: PopoverConstants.itemSpacing) {
                // Swap used
                swapMetricItem(
                    "Used",
                    value: dataManager.memoryData.swapUsedBytes ?? dataManager.memoryData.swapBytes,
                    color: .orange
                )

                // Swap total
                if let swapTotal = dataManager.memoryData.swapTotalBytes {
                    swapMetricItem(
                        "Total",
                        value: swapTotal,
                        color: .gray
                    )
                }
            }
        }
    }

    private func swapMetricItem(_ label: String, value: UInt64, color: Color) -> some View {
        VStack(spacing: PopoverConstants.compactSpacing) {
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(color)

            Text(formatBytes(value))
                .font(PopoverConstants.smallValueFont)
                .foregroundColor(DesignTokens.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Top Processes Section

    private var topProcessesSection: some View {
        VStack(alignment: .leading, spacing: PopoverConstants.itemSpacing) {
            PopoverSectionHeader(title: "Top Processes")

            if let topProcesses = dataManager.memoryData.topProcesses, !topProcesses.isEmpty {
                VStack(spacing: PopoverConstants.compactSpacing) {
                    ForEach(topProcesses.prefix(5)) { process in
                        ProcessRow(
                            name: process.name,
                            icon: process.icon,
                            value: memoryPercentage(for: process),
                            color: DesignTokens.Colors.accent
                        )
                    }
                }
            } else if dataManager.topMemoryApps.isEmpty {
                EmptyStateView(
                    icon: "app.dashed",
                    title: "No process data available"
                )
            } else {
                VStack(spacing: PopoverConstants.compactSpacing) {
                    ForEach(dataManager.topMemoryApps.prefix(5)) { process in
                        ProcessRow(
                            name: process.name,
                            icon: process.icon,
                            value: memoryPercentage(for: process),
                            color: DesignTokens.Colors.accent
                        )
                    }
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var pressurePercentage: Double {
        if let pressureValue = dataManager.memoryData.pressureValue {
            return pressureValue
        }
        // Fallback to calculated percentage based on usage
        let usagePercentage = dataManager.memoryData.usagePercentage
        // Map 0-100 usage to approximate pressure
        switch usagePercentage {
        case 0..<50: return 25
        case 50..<75: return 50
        case 75..<90: return 75
        default: return 95
        }
    }

    private var hasSwapData: Bool {
        return (dataManager.memoryData.swapTotalBytes ?? 0) > 0 ||
               (dataManager.memoryData.swapBytes ?? 0) > 0
    }

    private var memoryDetailItems: [MemoryDetailItem] {
        var items: [MemoryDetailItem] = []

        // Used
        items.append(MemoryDetailItem(
            label: "Used",
            value: formatBytes(dataManager.memoryData.usedBytes),
            icon: "memorychip.fill",
            valueColor: .blue
        ))

        // Wired
        items.append(MemoryDetailItem(
            label: "Wired",
            value: formatBytes(dataManager.memoryData.usedBytes * 15 / 100), // Approximate
            icon: "link",
            valueColor: .green
        ))

        // Active
        if let activeBytes = dataManager.memoryData.activeBytes {
            items.append(MemoryDetailItem(
                label: "Active",
                value: formatBytes(activeBytes),
                icon: "bolt.fill",
                valueColor: .purple
            ))
        } else {
            // Fallback calculation
            items.append(MemoryDetailItem(
                label: "Active",
                value: formatBytes(dataManager.memoryData.usedBytes * 60 / 100),
                icon: "bolt.fill",
                valueColor: .purple
            ))
        }

        // Compressed
        items.append(MemoryDetailItem(
            label: "Compressed",
            value: formatBytes(dataManager.memoryData.compressedBytes),
            icon: "archivebox",
            valueColor: .orange
        ))

        // Free
        if let freeBytes = dataManager.memoryData.freeBytes {
            items.append(MemoryDetailItem(
                label: "Free",
                value: formatBytes(freeBytes),
                icon: "minus.circle.fill",
                valueColor: .green
            ))
        }

        // Total
        items.append(MemoryDetailItem(
            label: "Total",
            value: formatBytes(dataManager.memoryData.totalBytes),
            icon: "square.stack.3d.up.fill",
            valueColor: .gray
        ))

        return items
    }

    // MARK: - Formatting Helpers

    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }

    private func memoryPercentage(for process: AppResourceUsage) -> Double {
        guard dataManager.memoryData.totalBytes > 0 else {
            return 0
        }
        return (Double(process.memoryBytes) / Double(dataManager.memoryData.totalBytes)) * 100
    }
}

// MARK: - Memory Detail Item

struct MemoryDetailItem {
    let label: String
    let value: String
    let icon: String?
    let valueColor: Color
}

// MARK: - Preview

#Preview("Memory Popover") {
    MemoryPopoverView()
}
