//
//  ModulesSettingsContent.swift
//  Tonic
//
//  Editorial per-module widget settings.
//

import SwiftUI

struct ModulesSettingsContent: View {
    @State private var selectedModule: WidgetType = .cpu
    @State private var preferences = WidgetPreferences.shared

    var body: some View {
        HStack(spacing: 0) {
            moduleList
                .frame(width: 196)
            TonicHairline()
                .frame(width: 1)
            detail
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TonicDS.Colors.canvas)
        .onReceive(NotificationCenter.default.publisher(for: .openModuleSettings)) { notification in
            guard let rawModule = notification.userInfo?[SettingsDeepLinkUserInfoKey.module] as? String,
                  let module = WidgetType(rawValue: rawModule),
                  WidgetType.parityCases.contains(module) else {
                return
            }
            selectedModule = module
        }
    }

    private var moduleList: some View {
        VStack(alignment: .leading, spacing: 0) {
            MonoLabel("MODULES")
                .padding(.horizontal, TonicDS.Space.md)
                .frame(height: 44, alignment: .leading)
            TonicHairline()
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(WidgetType.parityCases) { module in
                        SystemListRow {
                            Image(systemName: module.icon)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(module == selectedModule ? TonicDS.Colors.textPrimary : TonicDS.Colors.textMuted)
                                .frame(width: 22)
                        } center: {
                            Text(module.displayName)
                                .tonicType(.body)
                                .foregroundStyle(TonicDS.Colors.textPrimary)
                        } trailing: {
                            Circle()
                                .fill((preferences.config(for: module)?.isEnabled ?? false) ? TonicDS.Colors.statusSuccess : TonicDS.Colors.hairline)
                                .frame(width: 6, height: 6)
                        } onTap: {
                            selectedModule = module
                        }
                        TonicHairline().padding(.leading, TonicDS.Space.md)
                    }
                }
            }
        }
        .background(TonicDS.Colors.canvasSoft)
    }

    @ViewBuilder
    private var detail: some View {
        if let config = preferences.config(for: selectedModule) {
            ScrollView {
                ModuleSettingsDetail(module: selectedModule, config: config, preferences: preferences)
                    .padding(TonicDS.Space.xl)
            }
        } else {
            TonicEmptyState(systemImage: "slider.horizontal.3", title: "Select a Module")
        }
    }
}

private struct ModuleSettingsDetail: View {
    let module: WidgetType
    let config: WidgetConfiguration
    let preferences: WidgetPreferences
    @State private var dataManager = WidgetDataManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.xl) {
            TonicPageHeader(title: module.displayName, subtitle: "Menu-bar rendering, cadence, labels, chart history, and notification thresholds.") {
                StatusChip(config.isEnabled ? "Enabled" : "Off", color: config.isEnabled ? TonicDS.Colors.statusSuccess : TonicDS.Colors.textMuted)
            }

            SettingsPanel(title: "GENERAL") {
                TonicToggleRow(
                    title: "Show in Menu Bar",
                    description: "Enable or hide this module's compact readout.",
                    isOn: Binding(
                        get: { config.isEnabled },
                        set: { preferences.setWidgetEnabled(type: module, enabled: $0); WidgetCoordinator.shared.refreshWidgets() }
                    )
                )

                TonicPreferenceRow(title: "Visualization", description: "Stored format for the compact menu-bar item.") {
                    Picker("", selection: Binding(
                        get: { config.visualizationType },
                        set: { preferences.setWidgetVisualization(type: module, visualization: $0); WidgetCoordinator.shared.refreshWidgets() }
                    )) {
                        ForEach(module.compatibleVisualizations) { visualization in
                            Text(visualization.displayName).tag(visualization)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 180)
                }

                TonicPreferenceRow(title: "Display Mode", description: "Detailed mode adds a small data stroke when history exists.") {
                    Picker("", selection: Binding(
                        get: { config.displayMode },
                        set: { preferences.setWidgetDisplayMode(type: module, mode: $0); WidgetCoordinator.shared.refreshWidgets() }
                    )) {
                        ForEach(WidgetDisplayMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 150)
                }

                TonicToggleRow(
                    title: "Show Label",
                    description: "Adds the module name next to the mono value.",
                    isOn: Binding(
                        get: { config.showLabel },
                        set: { preferences.setWidgetShowLabel(type: module, show: $0); WidgetCoordinator.shared.refreshWidgets() }
                    )
                )

                TonicPreferenceRow(title: "Value Format", description: "Choose percent or native value where supported.") {
                    Picker("", selection: Binding(
                        get: { config.valueFormat },
                        set: { preferences.setWidgetValueFormat(type: module, format: $0); WidgetCoordinator.shared.refreshWidgets() }
                    )) {
                        ForEach(WidgetValueFormat.allCases) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 170)
                }

                TonicPreferenceRow(title: "Refresh Cadence", description: "Controls update interval for the compact readout.", showsDivider: false) {
                    Picker("", selection: Binding(
                        get: { config.refreshInterval },
                        set: { preferences.setWidgetRefreshInterval(type: module, interval: $0); WidgetCoordinator.shared.refreshWidgets() }
                    )) {
                        ForEach(WidgetUpdateInterval.allCases) { interval in
                            Text(interval.displayName).tag(interval)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 190)
                }
            }

            SettingsPanel(title: "CHART") {
                TonicPreferenceRow(title: "History Samples", description: "Retained samples for chart-capable visualizations.") {
                    let binding = Binding<Int>(
                        get: { config.chartConfig?.historySize ?? ChartConfiguration.default.historySize },
                        set: { value in
                            var chart = config.chartConfig ?? ChartConfiguration.default
                            chart.historySize = value
                            preferences.setWidgetChartConfig(type: module, chartConfig: chart)
                        }
                    )
                    Stepper(value: binding, in: 30...120, step: 10) {
                        Text("\(binding.wrappedValue)")
                            .tonicType(.monoLabel)
                            .monospacedDigit()
                            .foregroundStyle(TonicDS.Colors.textPrimary)
                            .frame(width: 42, alignment: .trailing)
                    }
                }

                TonicPreferenceRow(title: "Scaling", description: "Chart axis scaling mode.", showsDivider: false) {
                    Picker("", selection: Binding(
                        get: { config.chartConfig?.scaling ?? ChartConfiguration.default.scaling },
                        set: { value in
                            var chart = config.chartConfig ?? ChartConfiguration.default
                            chart.scaling = value
                            preferences.setWidgetChartConfig(type: module, chartConfig: chart)
                        }
                    )) {
                        ForEach(ScalingMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 150)
                }
            }

            SettingsPanel(title: "PREVIEW") {
                SystemListRow {
                    Image(systemName: module.icon)
                        .foregroundStyle(TonicDS.Colors.textMuted)
                        .frame(width: 24)
                } center: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(module.displayName)
                            .tonicType(.body)
                            .foregroundStyle(TonicDS.Colors.textPrimary)
                        Text(config.visualizationType.displayName)
                            .tonicType(.caption)
                            .foregroundStyle(TonicDS.Colors.textMuted)
                    }
                } trailing: {
                    Text(previewValue)
                        .tonicType(.monoLabel)
                        .monospacedDigit()
                        .foregroundStyle(previewColor)
                }
            }
        }
    }

    private var previewValue: String {
        switch module {
        case .cpu: return "\(Int(dataManager.cpuData.totalUsage))%"
        case .memory: return "\(Int(dataManager.memoryData.usagePercentage))%"
        case .disk: return dataManager.diskVolumes.first.map { "\(Int($0.usagePercentage))%" } ?? "--"
        case .network: return dataManager.networkData.downloadString
        case .gpu: return dataManager.gpuData.usagePercentage.map { "\(Int($0))%" } ?? "--"
        case .battery: return dataManager.batteryData.isPresent ? "\(Int(dataManager.batteryData.chargePercentage))%" : "--"
        case .sensors: return dataManager.sensorsData.temperatures.map(\.value).max().map { "\(Int($0))°" } ?? "--"
        case .bluetooth: return dataManager.bluetoothData.isBluetoothEnabled ? "\(dataManager.bluetoothData.connectedDevices.count)" : "Off"
        case .clock:
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: Date())
        case .weather: return "--"
        }
    }

    private var previewColor: Color {
        switch module {
        case .cpu: return TonicDS.Chart.utilization(dataManager.cpuData.totalUsage)
        case .memory: return TonicDS.Chart.utilization(dataManager.memoryData.usagePercentage)
        case .disk: return TonicDS.Chart.utilization(dataManager.diskVolumes.first?.usagePercentage ?? 0)
        case .gpu: return dataManager.gpuData.usagePercentage.map(TonicDS.Chart.utilization) ?? TonicDS.Colors.textMuted
        case .battery: return TonicDS.Chart.battery(level: dataManager.batteryData.chargePercentage, isCharging: dataManager.batteryData.isCharging)
        case .sensors: return dataManager.sensorsData.temperatures.map(\.value).max().map(TonicDS.Chart.temperature) ?? TonicDS.Colors.textMuted
        case .network: return TonicDS.Chart.download
        case .bluetooth: return dataManager.bluetoothData.isBluetoothEnabled ? TonicDS.Colors.statusInfo : TonicDS.Colors.statusWarning
        case .clock, .weather: return TonicDS.Colors.textMuted
        }
    }
}
