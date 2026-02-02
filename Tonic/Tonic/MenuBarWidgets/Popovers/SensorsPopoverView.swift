//
//  SensorsPopoverView.swift
//  Tonic
//
//  Stats Master-style Sensors popover with dashboard, history, and details
//  Task ID: fn-6-i4g.39
//

import SwiftUI

// MARK: - Sensors Popover View

/// Complete Stats Master-style Sensors popover with:
/// - Dashboard section (temperature gauge, fan RPM gauge)
/// - Temperature history line chart
/// - All temperature readings with color-coded values
/// - Fan speeds with visual RPM indicators
/// - Optional voltage and power readings
public struct SensorsPopoverView: View {

    // MARK: - Properties

    @State private var dataManager = WidgetDataManager.shared
    @State private var temperatureUnit: TemperatureUnit = .celsius

    /// Whether to show fan control section based on settings
    private var shouldShowFanControl: Bool {
        WidgetPreferences.shared.widgetConfigs
            .first(where: { $0.type == .sensors })?.moduleSettings.sensors.showFanSpeeds ?? true
    }

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
                    if !dataManager.sensorsHistory.isEmpty {
                        historyChartSection

                        Divider()
                    }

                    // Temperature Section
                    if !dataManager.sensorsData.temperatures.isEmpty {
                        temperaturesSection

                        Divider()
                    }

                    // Fan Control Section (integrated from FanControlView)
                    // Only show when SMC is available, fans are present, and showFanSpeeds is enabled
                    if !dataManager.sensorsData.fans.isEmpty && SMCReader.shared.isAvailable && shouldShowFanControl {
                        fanControlSection

                        Divider()
                    }

                    // Fan Section
                    if !dataManager.sensorsData.fans.isEmpty {
                        fansSection

                        Divider()
                    }

                    // Voltage Section (if available)
                    if !dataManager.sensorsData.voltages.isEmpty {
                        voltagesSection

                        Divider()
                    }

                    // Power Section (if available)
                    if !dataManager.sensorsData.power.isEmpty {
                        powerSection
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
            Image(systemName: PopoverConstants.Icons.sensors)
                .font(.title2)
                .foregroundColor(DesignTokens.Colors.accent)

            // Title
            Text("Sensors")
                .font(PopoverConstants.headerTitleFont)
                .foregroundColor(DesignTokens.Colors.textPrimary)

            Spacer()

            // Max temperature display
            if let maxTemp = dataManager.sensorsData.temperatures.map({ $0.value }).max() {
                Text(TemperatureConverter.displayString(maxTemp, unit: temperatureUnit))
                    .font(PopoverConstants.headerValueFont)
                    .foregroundColor(TemperatureConverter.colorForTemperature(maxTemp, unit: temperatureUnit))
            }

            // Settings button
            Button {
                // TODO: Open settings to Sensors widget configuration
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
                // Max temperature gauge
                if let maxTemp = dataManager.sensorsData.temperatures.map({ $0.value }).max() {
                    TemperatureGaugeView(
                        temperature: maxTemp,
                        size: CGSize(width: 90, height: 55),
                        showLabel: true
                    )
                }

                // First fan RPM gauge (if fans available)
                if let firstFan = dataManager.sensorsData.fans.first {
                    RPMGaugeView(
                        rpm: Double(firstFan.rpm),
                        maxRPM: Double(firstFan.maxRPM ?? 3000),
                        size: CGSize(width: 90, height: 55),
                        showLabel: true
                    )
                }

                // Temperature count indicator
                VStack(spacing: PopoverConstants.compactSpacing) {
                    Text("\(dataManager.sensorsData.temperatures.count)")
                        .font(PopoverConstants.largeMetricFont)
                        .foregroundColor(DesignTokens.Colors.accent)

                    Text("Temp Sensors")
                        .font(.system(size: 9))
                        .foregroundColor(DesignTokens.Colors.textSecondary)

                    if !dataManager.sensorsData.fans.isEmpty {
                        Text("\(dataManager.sensorsData.fans.count) Fans")
                            .font(.system(size: 9))
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - History Chart Section

    private var historyChartSection: some View {
        VStack(alignment: .leading, spacing: PopoverConstants.itemSpacing) {
            PopoverSectionHeader(title: "Temperature History")

            NetworkSparklineChart(
                data: dataManager.sensorsHistory,
                color: TemperatureConverter.colorForTemperature(
                    dataManager.sensorsHistory.last ?? dataManager.sensorsData.temperatures.first?.value ?? 0,
                    unit: temperatureUnit
                ),
                height: 70,
                showArea: true,
                lineWidth: 1.5
            )
            .frame(height: 70)
        }
    }

    // MARK: - Temperatures Section

    private var temperaturesSection: some View {
        VStack(alignment: .leading, spacing: PopoverConstants.itemSpacing) {
            PopoverSectionHeader(title: "Temperatures")

            VStack(spacing: 6) {
                ForEach(dataManager.sensorsData.temperatures) { sensor in
                    sensorRow(sensor: sensor)
                }
            }
        }
    }

    private func sensorRow(sensor: SensorReading) -> some View {
        HStack(spacing: PopoverConstants.itemSpacing) {
            // Temperature indicator circle with color
            IndicatorDot(color: TemperatureConverter.colorForTemperature(sensor.value, unit: temperatureUnit))

            // Sensor name
            Text(sensor.name)
                .font(.system(size: 11))
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .frame(width: 80, alignment: .leading)
                .lineLimit(1)

            // Progress bar based on min/max
            if let sensorMin = sensor.min, let sensorMax = sensor.max, sensorMax > sensorMin {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: PopoverConstants.smallCornerRadius)
                            .fill(Color.gray.opacity(0.15))

                        RoundedRectangle(cornerRadius: PopoverConstants.smallCornerRadius)
                            .fill(TemperatureConverter.colorForTemperature(sensor.value, unit: temperatureUnit))
                            .frame(width: geometry.size.width * min(max(0, (sensor.value - sensorMin) / (sensorMax - sensorMin)), 1.0))
                            .animation(PopoverConstants.fastAnimation, value: sensor.value)
                    }
                }
                .frame(height: PopoverConstants.progressBarHeight)
            } else {
                // Default progress bar (0-100°C range or 0-212°F range)
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: PopoverConstants.smallCornerRadius)
                            .fill(Color.gray.opacity(0.15))

                        RoundedRectangle(cornerRadius: PopoverConstants.smallCornerRadius)
                            .fill(TemperatureConverter.colorForTemperature(sensor.value, unit: temperatureUnit))
                            .frame(width: geometry.size.width * Swift.min(max(0, sensor.value / temperatureUnit.maxTemperature), 1.0))
                            .animation(PopoverConstants.fastAnimation, value: sensor.value)
                    }
                }
                .frame(height: PopoverConstants.progressBarHeight)
            }

            // Temperature value
            Text(TemperatureConverter.displayString(sensor.value, unit: temperatureUnit))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(TemperatureConverter.colorForTemperature(sensor.value, unit: temperatureUnit))
                .frame(width: 35, alignment: .trailing)
        }
    }

    // MARK: - Fans Section

    private var fansSection: some View {
        VStack(alignment: .leading, spacing: PopoverConstants.itemSpacing) {
            PopoverSectionHeader(title: "Fans")

            VStack(spacing: 6) {
                ForEach(dataManager.sensorsData.fans) { fan in
                    fanRow(fan: fan)
                }
            }
        }
    }

    private func fanRow(fan: FanReading) -> some View {
        HStack(spacing: PopoverConstants.itemSpacing) {
            // Fan icon
            Image(systemName: "fan.fill")
                .font(.system(size: 10))
                .foregroundColor(fanColor(fan.rpm, maxRPM: fan.maxRPM))
                .frame(width: 12)

            // Fan name
            Text(fan.name)
                .font(.system(size: 11))
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .frame(width: 80, alignment: .leading)
                .lineLimit(1)

            // Progress bar based on max RPM
            if let maxRPM = fan.maxRPM, maxRPM > 0 {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: PopoverConstants.smallCornerRadius)
                            .fill(Color.gray.opacity(0.15))

                        RoundedRectangle(cornerRadius: PopoverConstants.smallCornerRadius)
                            .fill(fanColor(fan.rpm, maxRPM: fan.maxRPM))
                            .frame(width: geometry.size.width * Swift.min(Double(fan.rpm) / Double(maxRPM), 1.0))
                            .animation(PopoverConstants.fastAnimation, value: fan.rpm)
                    }
                }
                .frame(height: PopoverConstants.progressBarHeight)
            } else {
                // Default progress bar (0-3000 RPM range)
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: PopoverConstants.smallCornerRadius)
                            .fill(Color.gray.opacity(0.15))

                        RoundedRectangle(cornerRadius: PopoverConstants.smallCornerRadius)
                            .fill(fanColor(fan.rpm, maxRPM: nil))
                            .frame(width: geometry.size.width * Swift.min(Double(fan.rpm) / 3000, 1.0))
                            .animation(PopoverConstants.fastAnimation, value: fan.rpm)
                    }
                }
                .frame(height: PopoverConstants.progressBarHeight)
            }

            // RPM value
            Text("\(fan.rpm)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(fanColor(fan.rpm, maxRPM: fan.maxRPM))
                .frame(width: 40, alignment: .trailing)

            // Mode indicator (if available)
            if let mode = fan.mode {
                Text(mode.displayName)
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Voltages Section

    private var voltagesSection: some View {
        VStack(alignment: .leading, spacing: PopoverConstants.itemSpacing) {
            PopoverSectionHeader(title: "Voltages")

            VStack(spacing: 6) {
                ForEach(dataManager.sensorsData.voltages) { voltage in
                    voltageRow(voltage: voltage)
                }
            }
        }
    }

    private func voltageRow(voltage: SensorReading) -> some View {
        HStack(spacing: PopoverConstants.itemSpacing) {
            // Voltage icon
            Image(systemName: "bolt.fill")
                .font(.system(size: 10))
                .foregroundColor(.yellow)
                .frame(width: 12)

            // Voltage name
            Text(voltage.name)
                .font(.system(size: 11))
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .frame(width: 80, alignment: .leading)
                .lineLimit(1)

            Spacer()

            // Voltage value
            Text("\(voltage.value, specifier: "%.2f")V")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(DesignTokens.Colors.textPrimary)
        }
    }

    // MARK: - Power Section

    private var powerSection: some View {
        VStack(alignment: .leading, spacing: PopoverConstants.itemSpacing) {
            PopoverSectionHeader(title: "Power")

            VStack(spacing: 6) {
                ForEach(dataManager.sensorsData.power) { power in
                    powerRow(power: power)
                }
            }
        }
    }

    private func powerRow(power: SensorReading) -> some View {
        HStack(spacing: 8) {
            // Power icon
            Image(systemName: "powerplug.fill")
                .font(.system(size: 10))
                .foregroundColor(.green)
                .frame(width: 12)

            // Power name
            Text(power.name)
                .font(.system(size: 11))
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .frame(width: 80, alignment: .leading)
                .lineLimit(1)

            Spacer()

            // Power value
            let unit = power.unit.isEmpty ? "W" : power.unit
            Text("\(power.value, specifier: "%.1f")\(unit)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(DesignTokens.Colors.textPrimary)
        }
    }

    // MARK: - Helper Methods

    private func loadTemperatureUnit() {
        temperatureUnit = WidgetPreferences.shared.temperatureUnit
    }

    // MARK: - Fan Control Section

    /// Fan control section with mode selector and per-fan sliders
    /// Gated by shouldShowFanControl, SMC availability, and fans presence at call site
    private var fanControlSection: some View {
        VStack(alignment: .leading, spacing: PopoverConstants.itemSpacing) {
            PopoverSectionHeader(title: "Fan Control", icon: "fan.badge.gearshape")

            FanControlView()
        }
    }

    private func fanColor(_ rpm: Int, maxRPM: Int?) -> Color {
        let ratio: Double
        if let max = maxRPM, max > 0 {
            ratio = Double(rpm) / Double(max)
        } else {
            ratio = Double(rpm) / 3000
        }

        switch ratio {
        case 0..<0.6:
            return TonicColors.success
        case 0.6..<0.85:
            return TonicColors.warning
        default:
            return TonicColors.error
        }
    }
}

// MARK: - Preview

#Preview("Sensors Popover") {
    SensorsPopoverView()
}
