//
//  CPUPopoverView.swift
//  Tonic
//
//  Stats Master-style CPU popover with dashboard, charts, and details
//  Task ID: fn-6-i4g.32, fn-6-i4g.49
//

import SwiftUI

// MARK: - CPU Popover View

/// Complete Stats Master-style CPU popover with:
/// - Dashboard section (pie chart, temperature, frequency gauges)
/// - Usage history line chart
/// - Per-core usage grouped by E/P
/// - System/User/Idle details
/// - Load average (1/5/15 min)
/// - Frequency section (all/E/P cores in GHz)
/// - Top processes list
public struct CPUPopoverView: View {

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

                    // Per-Core Section
                    coreUsageSection

                    Divider()

                    // Details Section
                    detailsSection

                    Divider()

                    // Load Average
                    loadAverageSection

                    Divider()

                    // Frequency Section (Task 48)
                    if dataManager.cpuData.frequency != nil ||
                       dataManager.cpuData.eCoreFrequency != nil ||
                       dataManager.cpuData.pCoreFrequency != nil {
                        frequencySection

                        Divider()
                    }

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
            Image(systemName: PopoverConstants.Icons.cpu)
                .font(.title2)
                .foregroundColor(DesignTokens.Colors.accent)

            // Title
            Text("CPU")
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
                // TODO: Open settings to CPU widget configuration
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
                // System/User/Idle pie chart
                CPUCircularGaugeView(
                    systemUsage: dataManager.cpuData.systemUsage,
                    userUsage: dataManager.cpuData.userUsage,
                    idleUsage: dataManager.cpuData.idleUsage,
                    size: PopoverConstants.circularGaugeSize
                )

                // Temperature gauge
                TemperatureGaugeView(
                    temperature: dataManager.cpuData.temperature ?? 0,
                    maxTemperature: 100,
                    size: CGSize(width: 80, height: 50),
                    showLabel: true
                )

                // Frequency gauge
                FrequencyGaugeView(
                    frequency: dataManager.cpuData.frequency ?? 0,
                    maxFrequency: 5.0,
                    size: CGSize(width: 80, height: 50),
                    showLabel: true
                )
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - History Chart Section

    private var historyChartSection: some View {
        VStack(alignment: .leading, spacing: PopoverConstants.itemSpacing) {
            PopoverSectionHeader(title: "Usage History")

            NetworkSparklineChart(
                data: dataManager.cpuHistory,
                color: DesignTokens.Colors.accent,
                height: 70,
                showArea: true,
                lineWidth: 1.5
            )
            .frame(height: 70)
        }
    }

    // MARK: - Core Usage Section

    private var coreUsageSection: some View {
        VStack(alignment: .leading, spacing: PopoverConstants.itemSpacing) {
            PopoverSectionHeader(title: "Per-Core Usage")

            CoreClusterBarView.fromCPUData(
                eCoreUsage: dataManager.cpuData.eCoreUsage,
                pCoreUsage: dataManager.cpuData.pCoreUsage,
                barHeight: PopoverConstants.progressBarHeight + 2,
                barSpacing: PopoverConstants.compactSpacing,
                showLabels: true
            )
        }
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        HStack(spacing: 16) {
            detailDot("System", value: dataManager.cpuData.systemUsage, color: Color(red: 1.0, green: 0.3, blue: 0.2))
            detailDot("User", value: dataManager.cpuData.userUsage, color: Color(red: 0.2, green: 0.5, blue: 1.0))
            detailDot("Idle", value: dataManager.cpuData.idleUsage, color: Color.gray.opacity(0.3))
        }
    }

    private func detailDot(_ label: String, value: Double, color: Color) -> some View {
        HStack(spacing: PopoverConstants.iconTextGap) {
            IndicatorDot(color: color)
            Text("\(label): \(Int(value))%")
                .font(PopoverConstants.smallLabelFont)
                .foregroundColor(DesignTokens.Colors.textPrimary)
        }
    }

    // MARK: - Load Average Section

    private var loadAverageSection: some View {
        HStack(spacing: PopoverConstants.itemSpacing) {
            loadItem("1 min", value: dataManager.cpuData.averageLoad?[safe: 0])
            loadItem("5 min", value: dataManager.cpuData.averageLoad?[safe: 1])
            loadItem("15 min", value: dataManager.cpuData.averageLoad?[safe: 2])
        }
    }

    private func loadItem(_ label: String, value: Double?) -> some View {
        VStack(spacing: PopoverConstants.compactSpacing) {
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(DesignTokens.Colors.textSecondary)

            Text(String(format: "%.2f", value ?? 0))
                .font(PopoverConstants.smallValueFont)
                .foregroundColor(DesignTokens.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Frequency Section

    /// Detailed frequency section showing all cores, E-cores, and P-cores in GHz
    private var frequencySection: some View {
        VStack(alignment: .leading, spacing: PopoverConstants.itemSpacing) {
            PopoverSectionHeader(title: "Frequency")

            HStack(spacing: PopoverConstants.itemSpacing) {
                // All cores frequency
                if let allFreq = dataManager.cpuData.frequency {
                    frequencyItem("All", value: allFreq, color: .purple)
                }

                // E-cores frequency
                if let eFreq = dataManager.cpuData.eCoreFrequency {
                    frequencyItem("E-Cores", value: eFreq, color: CoreClusterBarView(eCores: [], pCores: []).eCoreColor)
                }

                // P-cores frequency
                if let pFreq = dataManager.cpuData.pCoreFrequency {
                    frequencyItem("P-Cores", value: pFreq, color: CoreClusterBarView(eCores: [], pCores: []).pCoreColor)
                }
            }
        }
    }

    private func frequencyItem(_ label: String, value: Double, color: Color) -> some View {
        VStack(spacing: PopoverConstants.compactSpacing) {
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(color)

            Text(String(format: "%.2f", value))
                .font(PopoverConstants.smallValueFont)
                .foregroundColor(DesignTokens.Colors.textPrimary)

            Text("GHz")
                .font(.system(size: 8))
                .foregroundColor(DesignTokens.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Top Processes Section

    private var topProcessesSection: some View {
        VStack(alignment: .leading, spacing: PopoverConstants.itemSpacing) {
            PopoverSectionHeader(title: "Top Processes")

            if dataManager.topCPUApps.isEmpty {
                EmptyStateView(
                    icon: "app.dashed",
                    title: "No process data available"
                )
            } else {
                VStack(spacing: PopoverConstants.compactSpacing) {
                    ForEach(dataManager.topCPUApps.prefix(5)) { process in
                        ProcessRow(
                            name: process.name,
                            icon: process.icon,
                            value: process.cpuUsage,
                            color: DesignTokens.Colors.accent
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Safe Array Access

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Preview

#Preview("CPU Popover") {
    CPUPopoverView()
}
