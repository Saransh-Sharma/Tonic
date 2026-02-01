//
//  GPUPopoverView.swift
//  Tonic
//
//  Stats Master-style GPU popover with dashboard, history, and details
//  Task ID: fn-6-i4g.36
//

import SwiftUI

// MARK: - GPU Popover View

/// Complete Stats Master-style GPU popover with:
/// - Dashboard section (usage gauge, temperature, memory)
/// - Usage history line chart
/// - GPU details (utilization, memory breakdown)
/// - Activity Monitor integration
public struct GPUPopoverView: View {

    // MARK: - Properties

    @State private var dataManager = WidgetDataManager.shared
    @State private var temperatureUnit: TemperatureUnit = .celsius

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            ScrollView {
                VStack(spacing: PopoverConstants.sectionSpacing) {
                    if isGPUSupported {
                        // Dashboard Section
                        dashboardSection

                        Divider()

                        // History Chart
                        historyChartSection

                        Divider()

                        // Details Section
                        detailsSection
                    } else {
                        // Unsupported message
                        unsupportedSection
                    }
                }
                .padding(PopoverConstants.horizontalPadding)
                .padding(.vertical, PopoverConstants.verticalPadding)
            }
        }
        .frame(width: PopoverConstants.width, height: PopoverConstants.maxHeight)
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(PopoverConstants.cornerRadius)
        .onAppear {
            loadTemperatureUnit()
        }
        .onReceive(NotificationCenter.default.publisher(for: .widgetConfigurationDidUpdate)) { _ in
            loadTemperatureUnit()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: PopoverConstants.iconTextGap) {
            // Icon
            Image(systemName: PopoverConstants.Icons.gpu)
                .font(.title2)
                .foregroundColor(DesignTokens.Colors.accent)

            // Title
            Text("GPU")
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
                // TODO: Open settings to GPU widget configuration
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

    // MARK: - GPU Support Check

    private var isGPUSupported: Bool {
        #if arch(arm64)
        return true
        #else
        return dataManager.gpuData.usagePercentage != nil
        #endif
    }

    // MARK: - Dashboard Section

    private var dashboardSection: some View {
        VStack(alignment: .leading, spacing: PopoverConstants.itemSpacing) {
            PopoverSectionHeader(title: "Dashboard")

            HStack(spacing: DesignTokens.Spacing.sm) {
                // GPU usage gauge
                gpuUsageGauge

                // Temperature gauge
                if let temperature = dataManager.gpuData.temperature {
                    TemperatureGaugeView(
                        temperature: temperature,
                        size: CGSize(width: 80, height: 50),
                        showLabel: true
                    )
                }

                // Memory gauge
                if let memoryPercentage = dataManager.gpuData.memoryUsagePercentage {
                    memoryGauge(memoryPercentage)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var gpuUsageGauge: some View {
        VStack(spacing: PopoverConstants.compactSpacing) {
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color(nsColor: .separatorColor).opacity(0.2), lineWidth: PopoverConstants.circularGaugeLineWidth)
                    .frame(width: PopoverConstants.circularGaugeSize, height: PopoverConstants.circularGaugeSize)

                // Fill circle
                if let usage = dataManager.gpuData.usagePercentage {
                    Circle()
                        .trim(from: 0, to: usage / 100)
                        .stroke(
                            gpuUsageColor(usage).gradient,
                            style: StrokeStyle(lineWidth: PopoverConstants.circularGaugeLineWidth, lineCap: .round)
                        )
                        .frame(width: PopoverConstants.circularGaugeSize, height: PopoverConstants.circularGaugeSize)
                        .rotationEffect(.degrees(-90))
                        .animation(PopoverConstants.fastAnimation, value: usage)

                    // Center text
                    VStack(spacing: 0) {
                        Text("\(Int(usage))%")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(DesignTokens.Colors.textPrimary)

                        Text("Usage")
                            .font(.system(size: 9))
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    }
                } else {
                    VStack(spacing: 0) {
                        Text("--")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(DesignTokens.Colors.textSecondary)

                        Text("Usage")
                            .font(.system(size: 9))
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    }
                }
            }
            .frame(width: PopoverConstants.circularGaugeSize, height: PopoverConstants.circularGaugeSize)

            Text("GPU Utilization")
                .font(.system(size: 9))
                .foregroundColor(DesignTokens.Colors.textSecondary)
        }
    }

    private func memoryGauge(_ percentage: Double) -> some View {
        VStack(spacing: PopoverConstants.compactSpacing) {
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color(nsColor: .separatorColor).opacity(0.2), lineWidth: PopoverConstants.circularGaugeLineWidth)
                    .frame(width: PopoverConstants.circularGaugeSize, height: PopoverConstants.circularGaugeSize)

                // Fill circle
                Circle()
                    .trim(from: 0, to: percentage / 100)
                    .stroke(
                        Color.purple.gradient,
                        style: StrokeStyle(lineWidth: PopoverConstants.circularGaugeLineWidth, lineCap: .round)
                    )
                    .frame(width: PopoverConstants.circularGaugeSize, height: PopoverConstants.circularGaugeSize)
                    .rotationEffect(.degrees(-90))
                    .animation(PopoverConstants.fastAnimation, value: percentage)

                // Center text
                VStack(spacing: 0) {
                    Text("\(Int(percentage))%")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(DesignTokens.Colors.textPrimary)

                    Text("VRAM")
                        .font(.system(size: 9))
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
            }
            .frame(width: PopoverConstants.circularGaugeSize, height: PopoverConstants.circularGaugeSize)

            Text("GPU Memory")
                .font(.system(size: 9))
                .foregroundColor(DesignTokens.Colors.textSecondary)
        }
    }

    // MARK: - History Chart Section

    private var historyChartSection: some View {
        VStack(alignment: .leading, spacing: PopoverConstants.itemSpacing) {
            PopoverSectionHeader(title: "Usage History")

            NetworkSparklineChart(
                data: dataManager.gpuHistory,
                color: gpuUsageColor(dataManager.gpuData.usagePercentage ?? 0),
                height: 70,
                showArea: true,
                lineWidth: 1.5
            )
            .frame(height: 70)
        }
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: PopoverConstants.sectionSpacing) {
            PopoverSectionHeader(title: "Details")

            // GPU Info Grid
            VStack(spacing: PopoverConstants.itemSpacing) {
                // GPU Type
                #if arch(arm64)
                IconLabelRow(
                    icon: "video.bubble.left.fill",
                    label: "GPU Type",
                    value: "Apple Silicon"
                )

                IconLabelRow(
                    icon: "memorychip.fill",
                    label: "Memory Type",
                    value: "Unified Memory"
                )
                #else
                if let usage = dataManager.gpuData.usagePercentage {
                    IconLabelRow(
                        icon: "video.bubble.left.fill",
                        label: "GPU Usage",
                        value: "\(Int(usage))%"
                    )
                }
                #endif

                // Temperature
                if let temperature = dataManager.gpuData.temperature {
                    IconLabelRow(
                        icon: "thermometer",
                        label: "Temperature",
                        value: TemperatureConverter.displayString(temperature, unit: temperatureUnit),
                        valueColor: TemperatureConverter.colorForTemperature(temperature, unit: temperatureUnit)
                    )
                }

                // Memory Usage
                if let used = dataManager.gpuData.usedMemory,
                   let total = dataManager.gpuData.totalMemory {
                    IconLabelRow(
                        icon: "memorychip.fill",
                        label: "Memory Used",
                        value: formatBytes(used)
                    )

                    IconLabelRow(
                        icon: "externaldrive.fill",
                        label: "Memory Total",
                        value: formatBytes(total)
                    )
                }
            }

            // Platform note
            #if arch(arm64)
            VStack(alignment: .leading, spacing: PopoverConstants.compactSpacing) {
                HStack(spacing: 6) {
                    Image(systemName: PopoverConstants.Icons.info)
                        .font(.system(size: 10))
                        .foregroundColor(DesignTokens.Colors.textTertiary)

                    Text("Apple Silicon integrated GPU")
                        .font(.system(size: 10))
                        .foregroundColor(DesignTokens.Colors.textTertiary)

                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(PopoverConstants.smallCornerRadius)
            }
            #endif
        }
    }

    // MARK: - Unsupported Section

    private var unsupportedSection: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: "info.circle")
                .font(.system(size: 40))
                .foregroundColor(DesignTokens.Colors.textSecondary)

            Text("GPU Monitoring Not Available")
                .font(.subheadline)
                .fontWeight(.semibold)

            Text("GPU monitoring requires Apple Silicon Mac or supported discrete GPU.")
                .font(.caption)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Helper Methods

    private func gpuUsageColor(_ usage: Double) -> Color {
        switch usage {
        case 0..<50: return TonicColors.success
        case 50..<80: return TonicColors.warning
        default: return TonicColors.error
        }
    }

    private func loadTemperatureUnit() {
        temperatureUnit = WidgetPreferences.shared.temperatureUnit
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory)
    }
}

// MARK: - Preview

#Preview("GPU Popover") {
    GPUPopoverView()
}
