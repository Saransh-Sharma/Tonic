//
//  BatteryPopoverView.swift
//  Tonic
//
//  Stats Master-style Battery popover with dashboard, details, and battery info
//  Task ID: fn-6-i4g.38
//

import SwiftUI

// MARK: - Battery Popover View

/// Complete Stats Master-style Battery popover with:
/// - Dashboard section (battery visual)
/// - Details section (Level, Source, Time, Last charge)
/// - Battery section (Health, Capacity, Cycles, Temperature, Power)
/// - Power adapter section (when charging)
/// - Top processes list
public struct BatteryPopoverView: View {

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

                    Divider()

                    // Battery Info Section
                    batteryInfoSection

                    // Power Adapter Section (only when charging)
                    if dataManager.batteryData.isCharging {
                        Divider()
                        powerAdapterSection
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
        HStack(spacing: DesignTokens.Spacing.sm) {
            // Icon
            Image(systemName: PopoverConstants.Icons.battery)
                .font(.title2)
                .foregroundColor(batteryColor)

            // Title
            Text("Battery")
                .font(PopoverConstants.headerTitleFont)
                .foregroundColor(DesignTokens.Colors.textPrimary)

            Spacer()

            // Current percentage
            if dataManager.batteryData.isPresent {
                Text("\(Int(dataManager.batteryData.chargePercentage))%")
                    .font(PopoverConstants.headerValueFont)
                    .foregroundColor(batteryColor)
            }

            // Settings button
            Button {
                // TODO: Open settings to Battery widget configuration
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

    // MARK: - History Chart Section

    private var historyChartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Charge History")
                .font(PopoverConstants.sectionTitleFont)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            NetworkSparklineChart(
                data: dataManager.batteryHistory,
                color: batteryColor,
                height: 70,
                showArea: true,
                lineWidth: 1.5
            )
            .frame(height: 70)
        }
    }

    // MARK: - Dashboard Section

    private var dashboardSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dashboard")
                .font(PopoverConstants.sectionTitleFont)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            HStack(spacing: 20) {
                // Battery visual
                batteryVisualView
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var batteryVisualView: some View {
        let battery = dataManager.batteryData

        return ZStack {
            // Battery outline
            RoundedRectangle(cornerRadius: 6)
                .stroke(DesignTokens.Colors.textSecondary.opacity(0.3), lineWidth: 2)
                .frame(width: 80, height: 36)

            // Battery tip
            RoundedRectangle(cornerRadius: 2)
                .fill(DesignTokens.Colors.textSecondary.opacity(0.3))
                .frame(width: 4, height: 14)
                .offset(x: 44, y: 0)

            // Fill
            GeometryReader { geometry in
                RoundedRectangle(cornerRadius: 4)
                    .fill(batteryColor)
                    .frame(width: max(0, geometry.size.width * CGFloat(battery.chargePercentage / 100)), height: 28)
                    .animation(.easeInOut(duration: 0.3), value: battery.chargePercentage)
            }
            .frame(width: 76, height: 32)
            .offset(x: -40)

            // Charging indicator
            if battery.isCharging && !battery.isCharged {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
            }
        }
        .frame(width: 130, height: 40)
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Details")
                .font(PopoverConstants.sectionTitleFont)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            VStack(spacing: 6) {
                detailRow(label: "Level", value: "\(Int(dataManager.batteryData.chargePercentage))%")

                detailRow(label: "Source", value: sourceText)

                // Time to charge/discharge
                if let minutes = dataManager.batteryData.estimatedMinutesRemaining {
                    HStack {
                        Text(dataManager.batteryData.isCharging ? "Time to charge" : "Time to discharge")
                            .font(PopoverConstants.detailLabelFont)
                            .foregroundColor(DesignTokens.Colors.textSecondary)

                        Spacer()

                        Text(timeString(from: minutes))
                            .font(PopoverConstants.detailValueFont)
                            .fontWeight(.medium)
                            .foregroundColor(DesignTokens.Colors.textPrimary)
                    }
                } else if !dataManager.batteryData.isCharged {
                    detailRow(label: dataManager.batteryData.isCharging ? "Time to charge" : "Time to discharge", value: "Calculating...")
                }

                // Last charge info (placeholder - would need additional tracking)
                detailRow(label: "Last charge", value: "Unknown")
            }
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(PopoverConstants.detailLabelFont)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            Spacer()

            Text(value)
                .font(PopoverConstants.detailValueFont)
                .fontWeight(.medium)
                .foregroundColor(DesignTokens.Colors.textPrimary)
        }
    }

    // MARK: - Battery Info Section

    private var batteryInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Battery")
                .font(PopoverConstants.sectionTitleFont)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            VStack(spacing: 6) {
                // Health
                detailRow(label: "Health", value: healthText)
                    .overlay(
                        healthBadge
                            .offset(x: -50)
                    )

                // Capacity (would need max/design capacity from IOKit)
                detailRow(label: "Capacity", value: capacityText)

                // Cycles
                if let cycles = dataManager.batteryData.cycleCount {
                    detailRow(label: "Cycles", value: "\(cycles)")
                } else {
                    detailRow(label: "Cycles", value: "Unknown")
                }

                // Temperature
                if let temp = dataManager.batteryData.temperature {
                    detailRow(label: "Temperature", value: String(format: "%.1f°C", temp))
                } else {
                    detailRow(label: "Temperature", value: "Unknown")
                }

                // Optimized Charging
                if let optimized = dataManager.batteryData.optimizedCharging {
                    detailRow(label: "Optimized Charging", value: optimized ? "Enabled" : "Disabled")
                }
            }
        }
    }

    // MARK: - Power Adapter Section

    private var powerAdapterSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Power Adapter")
                .font(PopoverConstants.sectionTitleFont)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            VStack(spacing: 6) {
                // Is charging
                detailRow(label: "Is charging", value: dataManager.batteryData.isCharging ? "Yes" : "No")

                // Charger wattage
                if let wattage = dataManager.batteryData.chargerWattage {
                    detailRow(label: "Power", value: "\(wattage)W")
                } else {
                    detailRow(label: "Power", value: "Unknown")
                }
            }
        }
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
                        .fill(batteryColor)
                        .frame(width: geometry.size.width * min(process.cpuUsage / 100, 1.0))
                        .animation(.easeInOut(duration: 0.2), value: process.cpuUsage)
                }
            }
            .frame(height: 6)

            // CPU usage as proxy for energy impact
            Text("\(Int(process.cpuUsage))%")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .frame(width: 30, alignment: .trailing)
        }
    }

    // MARK: - Helper Views

    private var healthBadge: some View {
        Text(healthText)
            .font(.system(size: 8, weight: .medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(healthColor.opacity(0.2))
            .foregroundColor(healthColor)
            .cornerRadius(4)
    }

    // MARK: - Computed Properties

    private var batteryColor: Color {
        guard dataManager.batteryData.isPresent else { return .gray }
        if dataManager.batteryData.isCharging { return .blue }
        switch dataManager.batteryData.chargePercentage {
        case 0..<20: return .red
        case 20..<50: return .orange
        default: return .green
        }
    }

    private var healthColor: Color {
        switch dataManager.batteryData.health {
        case .good: return .green
        case .fair: return .orange
        case .poor: return .red
        case .unknown: return .gray
        }
    }

    private var healthText: String {
        dataManager.batteryData.health.description
    }

    private var capacityText: String {
        // Placeholder - would need current/max/design capacity from IOKit
        // For now, showing just the percentage
        return "\(Int(dataManager.batteryData.chargePercentage))%"
    }

    private var sourceText: String {
        if dataManager.batteryData.isCharging {
            return "Power Adapter"
        } else if dataManager.batteryData.isCharged {
            return "Fully Charged"
        } else {
            return "Battery"
        }
    }

    private func timeString(from minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)min"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
    }
}

// MARK: - Battery History Chart

/// Line chart showing battery charge percentage over time
public struct BatteryHistoryChart: View {
    let history: [Double]
    let height: CGFloat

    public init(history: [Double], height: CGFloat = 60) {
        self.history = history
        self.height = height
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Charge History")
                .font(PopoverConstants.sectionTitleFont)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            NetworkSparklineChart(
                data: history,
                color: batteryColorForHistory,
                height: height,
                showArea: true,
                lineWidth: 1.5
            )
        }
    }

    private var batteryColorForHistory: Color {
        if let last = history.last {
            switch last {
            case 0..<20: return .red
            case 20..<50: return .orange
            default: return .green
            }
        }
        return .green
    }
}

// MARK: - Preview

#Preview("Battery Popover") {
    BatteryPopoverView()
}
