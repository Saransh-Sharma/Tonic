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
    @State private var temperatureUnit: TemperatureUnit = .celsius
    @State private var timeFormat: BatteryModuleSettings.TimeFormat = .short

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            // Empty state for desktop Macs without battery
            if !dataManager.batteryData.isPresent {
                emptyStateView
                    .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: PopoverConstants.sectionSpacing) {
                        // Dashboard Section
                        dashboardSection

                        SoftDivider()

                        // History Chart
                        historyChartSection

                        SoftDivider()

                        // Details Section
                        detailsSection

                        SoftDivider()

                        // Battery Info Section
                    batteryInfoSection

                    SoftDivider()

                    // Electrical Metrics Section
                    electricalMetricsSection

                    // Power Adapter Section (only when charging)
                    if dataManager.batteryData.isCharging {
                        SoftDivider()
                        powerAdapterSection
                    }

                    SoftDivider()

                    // Top Processes
                    topProcessesSection
                }
                .padding(PopoverConstants.horizontalPadding)
                .padding(.vertical, PopoverConstants.verticalPadding)
            }
            }  // End else block
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

    private func loadTemperatureUnit() {
        temperatureUnit = WidgetPreferences.shared.temperatureUnit

        // Find a battery widget config to read time format preference
        if let batteryWidget = WidgetPreferences.shared.widgetConfigs.first(where: { $0.type == .battery }) {
            timeFormat = batteryWidget.moduleSettings.battery.timeFormat
        } else {
            // Default if no battery widget configured
            timeFormat = .short
        }
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: PopoverConstants.sectionSpacing) {
            Image(systemName: "desktopcomputer")
                .font(.system(size: 48))
                .foregroundColor(DesignTokens.Colors.textSecondary)

            Text("No Battery")
                .font(PopoverConstants.sectionTitleFont)
                .foregroundColor(DesignTokens.Colors.textPrimary)

            Text("This Mac does not have a battery.")
                .font(PopoverConstants.detailLabelFont)
                .foregroundColor(DesignTokens.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(PopoverConstants.horizontalPadding)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: PopoverConstants.iconTextGap) {
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
            HoverableButton(systemImage: PopoverConstants.Icons.settings) {
                SettingsDeepLinkNavigator.openModuleSettings(.battery)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - History Chart Section

    private var historyChartSection: some View {
        VStack(alignment: .leading, spacing: PopoverConstants.itemSpacing) {
            PopoverSectionHeader(title: "Charge History")

            NetworkSparklineChart(
                data: dataManager.batteryHistory,
                color: batteryColor,
                height: PopoverConstants.SectionHeights.historyChart,
                showArea: true,
                lineWidth: 1.5
            )
            .frame(height: PopoverConstants.SectionHeights.historyChart)
        }
    }

    // MARK: - Dashboard Section

    private var dashboardSection: some View {
        VStack(alignment: .leading, spacing: PopoverConstants.itemSpacing) {
            PopoverSectionHeader(title: "Dashboard")

            HStack(spacing: DesignTokens.Spacing.sm) {
                // Battery visual
                batteryVisualView
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: PopoverConstants.SectionHeights.dashboard)
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
                    .foregroundColor(Color(nsColor: .windowBackgroundColor))
            }
        }
        .frame(width: 130, height: 40)
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: PopoverConstants.itemSpacing) {
            PopoverSectionHeader(title: "Details")

            VStack(spacing: PopoverConstants.compactSpacing) {
                PopoverDetailRow(label: "Level", value: "\(Int(dataManager.batteryData.chargePercentage))%")

                PopoverDetailRow(label: "Source", value: sourceText)

                // Time to charge/discharge
                if let minutes = dataManager.batteryData.estimatedMinutesRemaining {
                    PopoverDetailRow(label: dataManager.batteryData.isCharging ? "Time to charge" : "Time to discharge", value: timeString(from: minutes))
                } else if !dataManager.batteryData.isCharged {
                    PopoverDetailRow(label: dataManager.batteryData.isCharging ? "Time to charge" : "Time to discharge", value: "Calculating...")
                }

                PopoverDetailRow(label: "Last charge", value: lastChargeText)
            }
        }
    }

    private var lastChargeText: String {
        guard let timestamp = dataManager.batteryData.lastChargeTimestamp else {
            return "Unknown"
        }

        let formatter = DateComponentsFormatter()
        formatter.maximumUnitCount = 2
        formatter.unitsStyle = .full
        formatter.allowedUnits = [.day, .hour, .minute]
        return formatter.string(from: timestamp, to: Date()) ?? "Unknown"
    }

    // MARK: - Battery Info Section

    private var batteryInfoSection: some View {
        VStack(alignment: .leading, spacing: PopoverConstants.itemSpacing) {
            PopoverSectionHeader(title: "Battery")

            VStack(spacing: PopoverConstants.compactSpacing) {
                // Health
                PopoverDetailRow(label: "Health", value: healthText)
                    .overlay(
                        healthBadge
                            .offset(x: -50)
                    )

                // Capacity (would need max/design capacity from IOKit)
                PopoverDetailRow(label: "Capacity", value: capacityText)

                // Cycles
                if let cycles = dataManager.batteryData.cycleCount {
                    PopoverDetailRow(label: "Cycles", value: "\(cycles)")
                } else {
                    PopoverDetailRow(label: "Cycles", value: "Unknown")
                }

                // Temperature
                if let temp = dataManager.batteryData.temperature {
                    PopoverDetailRow(label: "Temperature", value: TemperatureConverter.displayString(temp, unit: temperatureUnit, precision: 1))
                } else {
                    PopoverDetailRow(label: "Temperature", value: "Unknown")
                }

                // Optimized Charging
                if let optimized = dataManager.batteryData.optimizedCharging {
                    PopoverDetailRow(label: "Optimized Charging", value: optimized ? "Enabled" : "Disabled")
                }
            }
        }
    }

    // MARK: - Power Adapter Section

    private var powerAdapterSection: some View {
        VStack(alignment: .leading, spacing: PopoverConstants.itemSpacing) {
            PopoverSectionHeader(title: "Power Adapter")

            VStack(spacing: PopoverConstants.compactSpacing) {
                // Is charging
                PopoverDetailRow(label: "Is charging", value: dataManager.batteryData.isCharging ? "Yes" : "No")

                // Charger wattage
                if let wattage = dataManager.batteryData.chargerWattage {
                    PopoverDetailRow(label: "Power", value: "\(wattage)W")
                } else {
                    PopoverDetailRow(label: "Power", value: "Unknown")
                }

                // Adapter current (mA)
                if let current = dataManager.batteryData.chargingCurrent {
                    PopoverDetailRow(label: "Current", value: "\(Int(current)) mA")
                }

                // Adapter voltage (V)
                if let voltage = dataManager.batteryData.chargingVoltage {
                    PopoverDetailRow(label: "Voltage", value: String(format: "%.2f V", voltage))
                }
            }
        }
    }

    // MARK: - Electrical Metrics Section

    private var electricalMetricsSection: some View {
        VStack(alignment: .leading, spacing: PopoverConstants.itemSpacing) {
            PopoverSectionHeader(title: "Electrical")

            VStack(spacing: PopoverConstants.compactSpacing) {
                // Amperage (mA) - negative when charging, positive when discharging
                if let amperage = dataManager.batteryData.amperage {
                    let amperageText = amperage < 0
                        ? "\(Int(abs(amperage))) mA (charging)"
                        : "\(Int(amperage)) mA (discharging)"
                    PopoverDetailRow(label: "Amperage", value: amperageText)
                } else {
                    PopoverDetailRow(label: "Amperage", value: "Unknown")
                }

                // Voltage (V)
                if let voltage = dataManager.batteryData.voltage {
                    PopoverDetailRow(label: "Voltage", value: String(format: "%.2f V", voltage))
                } else {
                    PopoverDetailRow(label: "Voltage", value: "Unknown")
                }

                // Power (W)
                if let power = dataManager.batteryData.batteryPower {
                    PopoverDetailRow(label: "Power", value: String(format: "%.2f W", power))
                } else {
                    PopoverDetailRow(label: "Power", value: "Unknown")
                }
            }
        }
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
                            color: batteryColor
                        )
                    }
                }
            }
        }
    }

    // MARK: - Helper Views

    private var healthBadge: some View {
        Text(healthText)
            .font(PopoverConstants.tinyValueFont)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(healthColor.opacity(0.2))
            .foregroundColor(healthColor)
            .cornerRadius(PopoverConstants.smallCornerRadius)
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
        // Show capacity breakdown: current / max / designed (mAh)
        if let current = dataManager.batteryData.currentCapacity,
           let maxCap = dataManager.batteryData.maxCapacity {
            if let designed = dataManager.batteryData.designedCapacity {
                return "\(current) / \(maxCap) / \(designed) mAh"
            } else {
                return "\(current) / \(maxCap) mAh"
            }
        }
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
        switch timeFormat {
        case .short:
            // Short format: "2h 30m" or "45min"
            if minutes < 60 {
                return "\(minutes)min"
            } else {
                let hours = minutes / 60
                let mins = minutes % 60
                return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
            }
        case .long:
            // Long format: "2 hours 30 minutes" or "45 minutes"
            if minutes < 60 {
                return minutes == 1 ? "1 minute" : "\(minutes) minutes"
            } else {
                let hours = minutes / 60
                let mins = minutes % 60
                if mins > 0 {
                    let hourStr = hours == 1 ? "1 hour" : "\(hours) hours"
                    let minStr = mins == 1 ? "1 minute" : "\(mins) minutes"
                    return "\(hourStr) \(minStr)"
                } else {
                    return hours == 1 ? "1 hour" : "\(hours) hours"
                }
            }
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
