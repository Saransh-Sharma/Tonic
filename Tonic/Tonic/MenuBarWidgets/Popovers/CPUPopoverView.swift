//
//  CPUPopoverView.swift
//  Tonic
//
//  Stats Master-style CPU popover with dashboard, charts, and details
//  Task ID: fn-6-i4g.32
//

import SwiftUI

// MARK: - CPU Popover View

/// Complete Stats Master-style CPU popover with:
/// - Dashboard section (pie chart, temperature, frequency gauges)
/// - Usage history line chart
/// - Per-core usage grouped by E/P
/// - System/User/Idle details
/// - Load average (1/5/15 min)
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
        HStack(spacing: DesignTokens.Spacing.sm) {
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
                HStack(spacing: 4) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 12))
                    Text("Activity Monitor")
                        .font(.system(size: 11))
                }
                .foregroundColor(DesignTokens.Colors.textSecondary)
            }
            .buttonStyle(.plain)

            // Settings button
            Button {
                // TODO: Open settings to CPU widget configuration
            } label: {
                Image(systemName: "gearshape")
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Dashboard")
                .font(PopoverConstants.sectionTitleFont)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            HStack(spacing: 20) {
                // System/User/Idle pie chart
                CPUCircularGaugeView(
                    systemUsage: dataManager.cpuData.systemUsage,
                    userUsage: dataManager.cpuData.userUsage,
                    idleUsage: dataManager.cpuData.idleUsage,
                    size: 70
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Usage History")
                .font(PopoverConstants.sectionTitleFont)
                .foregroundColor(DesignTokens.Colors.textSecondary)

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
        VStack(alignment: .leading, spacing: 8) {
            Text("Per-Core Usage")
                .font(PopoverConstants.sectionTitleFont)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            CoreClusterBarView.fromCPUData(
                eCoreUsage: dataManager.cpuData.eCoreUsage,
                pCoreUsage: dataManager.cpuData.pCoreUsage,
                barHeight: 8,
                barSpacing: 4,
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
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text("\(label): \(Int(value))%")
                .font(.system(size: 10))
                .foregroundColor(DesignTokens.Colors.textPrimary)
        }
    }

    // MARK: - Load Average Section

    private var loadAverageSection: some View {
        HStack(spacing: 12) {
            loadItem("1 min", value: dataManager.cpuData.averageLoad?[safe: 0])
            loadItem("5 min", value: dataManager.cpuData.averageLoad?[safe: 1])
            loadItem("15 min", value: dataManager.cpuData.averageLoad?[safe: 2])
        }
    }

    private func loadItem(_ label: String, value: Double?) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(DesignTokens.Colors.textSecondary)

            Text(String(format: "%.2f", value ?? 0))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(DesignTokens.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Top Processes Section

    private var topProcessesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Top Processes")
                .font(PopoverConstants.sectionTitleFont)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            if dataManager.topCPUApps.isEmpty {
                Text("No process data available")
                    .font(.system(size: 10))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 6) {
                    ForEach(dataManager.topCPUApps.prefix(5)) { process in
                        processBar(process)
                    }
                }
            }
        }
    }

    private func processBar(_ process: AppResourceUsage) -> some View {
        HStack(spacing: 8) {
            // App icon if available
            if let icon = process.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 14, height: 14)
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: 10))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .frame(width: 14, height: 14)
            }

            // Process name
            Text(process.name)
                .font(.system(size: 10))
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .frame(width: 70, alignment: .leading)
                .lineLimit(1)
                .truncationMode(.tail)

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.15))

                    RoundedRectangle(cornerRadius: 2)
                        .fill(DesignTokens.Colors.accent)
                        .frame(width: geometry.size.width * min(process.cpuUsage / 100, 1.0))
                        .animation(.easeInOut(duration: 0.2), value: process.cpuUsage)
                }
            }
            .frame(height: 6)

            // Percentage
            Text("\(Int(process.cpuUsage))%")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .frame(width: 30, alignment: .trailing)
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
