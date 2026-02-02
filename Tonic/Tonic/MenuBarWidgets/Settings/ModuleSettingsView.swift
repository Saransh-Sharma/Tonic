//
//  ModuleSettingsView.swift
//  Tonic
//
//  Per-module settings configuration UI
//  Task ID: fn-8-v3b.15
//

import SwiftUI

// MARK: - Module Settings View

/// Main module settings view that lists all available modules
/// Tapping a module expands its settings panel
public struct ModuleSettingsView: View {

    // MARK: - Properties

    @AppStorage("moduleSettings") private var moduleSettingsData: Data = {
        // Encode default settings
        let defaults = ModuleSettings.default
        return (try? JSONEncoder().encode(defaults)) ?? Data()
    }()

    @State private var selectedModule: (any ModuleSettingsConfig)?
    @State private var moduleSettings: ModuleSettings = .default

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            // Module list
            List {
                ForEach(Array(moduleSettings.allModules.enumerated()), id: \.offset) { _, module in
                    ModuleListItem(
                        module: module,
                        isSelected: selectedModule?.widgetType == module.widgetType
                    ) {
                        withAnimation(DesignTokens.Animation.fast) {
                            if selectedModule?.widgetType == module.widgetType {
                                selectedModule = nil
                            } else {
                                selectedModule = module
                            }
                        }
                    }
                }
            }
            .listStyle(.inset)

            // Selected module settings panel
            if let selectedModule = selectedModule {
                Divider()
                ModuleSettingsPanel(module: selectedModule, settings: $moduleSettings)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .onChange(of: moduleSettings) { _, newValue in
            saveSettings(newValue)
        }
    }

    // MARK: - Private Methods

    private func saveSettings(_ settings: ModuleSettings) {
        if let encoded = try? JSONEncoder().encode(settings) {
            moduleSettingsData = encoded
        }
    }

    private func loadSettings() -> ModuleSettings {
        guard let decoded = try? JSONDecoder().decode(ModuleSettings.self, from: moduleSettingsData) else {
            return .default
        }
        return decoded
    }
}

// MARK: - Module List Item

private struct ModuleListItem: View {
    let module: any ModuleSettingsConfig
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: module.icon)
                    .font(.system(size: 16))
                    .foregroundColor(DesignTokens.Colors.accent)
                    .frame(width: 28)

                Text(module.displayName)
                    .font(DesignTokens.Typography.body)
                    .foregroundColor(DesignTokens.Colors.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DesignTokens.Colors.textQuaternary)
            }
            .padding(.vertical, DesignTokens.Spacing.xxs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isSelected ? Color(nsColor: .selectedControlBackgroundColor) : Color.clear)
        .cornerRadius(DesignTokens.CornerRadius.medium)
    }
}

// MARK: - Module Settings Panel

private struct ModuleSettingsPanel: View {
    let module: any ModuleSettingsConfig
    @Binding var settings: ModuleSettings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                // Header
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: module.icon)
                        .font(.system(size: 20))
                        .foregroundColor(DesignTokens.Colors.accent)

                    Text("\(module.displayName) Settings")
                        .font(DesignTokens.Typography.h3)
                        .foregroundColor(DesignTokens.Colors.textPrimary)

                    Spacer()
                }
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.top, DesignTokens.Spacing.md)

                // Module-specific settings
                Group {
                    switch module.widgetType {
                    case .cpu:
                        CPUModuleSettingsView(settings: $settings.cpu)
                    case .disk:
                        DiskModuleSettingsView(settings: $settings.disk)
                    case .network:
                        NetworkModuleSettingsView(settings: $settings.network)
                    case .memory:
                        MemoryModuleSettingsView(settings: $settings.memory)
                    case .sensors:
                        SensorsModuleSettingsView(settings: $settings.sensors)
                    case .battery:
                        BatteryModuleSettingsView(settings: $settings.battery)
                    default:
                        EmptyView()
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.bottom, DesignTokens.Spacing.md)
            }
        }
    }
}

// MARK: - CPU Module Settings View

private struct CPUModuleSettingsView: View {
    @Binding var settings: CPUModuleSettings

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            // Update Interval
            SettingsRow(label: "Update Interval", icon: "clock") {
                Picker("", selection: $settings.updateInterval) {
                    Text("0.5s").tag(0.5 as TimeInterval)
                    Text("1s").tag(1.0 as TimeInterval)
                    Text("2s").tag(2.0 as TimeInterval)
                    Text("5s").tag(5.0 as TimeInterval)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }

            Divider()

            // Top Process Count
            SettingsRow(label: "Top Processes", icon: "list.bullet") {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Stepper("\(settings.topProcessCount)", value: $settings.topProcessCount, in: 3...20)
                        .frame(width: 100)
                    Text("processes")
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
            }

            Divider()

            // Display Options
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text("Display Options")
                    .font(DesignTokens.Typography.subheadEmphasized)
                    .foregroundColor(DesignTokens.Colors.textSecondary)

                Toggle("Show E/P Cores", isOn: $settings.showEPCores)
                Toggle("Show Frequency", isOn: $settings.showFrequency)
                Toggle("Show Temperature", isOn: $settings.showTemperature)
                Toggle("Show Load Average", isOn: $settings.showLoadAverage)
            }
        }
    }
}

// MARK: - Disk Module Settings View

private struct DiskModuleSettingsView: View {
    @Binding var settings: DiskModuleSettings

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            // Update Interval
            SettingsRow(label: "Update Interval", icon: "clock") {
                Picker("", selection: $settings.updateInterval) {
                    Text("1s").tag(1.0 as TimeInterval)
                    Text("2s").tag(2.0 as TimeInterval)
                    Text("5s").tag(5.0 as TimeInterval)
                    Text("10s").tag(10.0 as TimeInterval)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }

            Divider()

            // Top Process Count
            SettingsRow(label: "Top Processes", icon: "list.bullet") {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Stepper("\(settings.topProcessCount)", value: $settings.topProcessCount, in: 3...20)
                        .frame(width: 100)
                    Text("processes")
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
            }

            Divider()

            // Display Options
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text("Display Options")
                    .font(DesignTokens.Typography.subheadEmphasized)
                    .foregroundColor(DesignTokens.Colors.textSecondary)

                Toggle("Show SMART Data", isOn: $settings.showSMART)
            }
        }
    }
}

// MARK: - Network Module Settings View

private struct NetworkModuleSettingsView: View {
    @Binding var settings: NetworkModuleSettings

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            // Update Interval
            SettingsRow(label: "Update Interval", icon: "clock") {
                Picker("", selection: $settings.updateInterval) {
                    Text("0.5s").tag(0.5 as TimeInterval)
                    Text("1s").tag(1.0 as TimeInterval)
                    Text("2s").tag(2.0 as TimeInterval)
                    Text("5s").tag(5.0 as TimeInterval)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }

            Divider()

            // Top Process Count
            SettingsRow(label: "Top Processes", icon: "list.bullet") {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Stepper("\(settings.topProcessCount)", value: $settings.topProcessCount, in: 3...20)
                        .frame(width: 100)
                    Text("processes")
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
            }

            Divider()

            // Display Options
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text("Display Options")
                    .font(DesignTokens.Typography.subheadEmphasized)
                    .foregroundColor(DesignTokens.Colors.textSecondary)

                Toggle("Show Public IP", isOn: $settings.showPublicIP)
                Toggle("Show WiFi Details", isOn: $settings.showWiFiDetails)
            }
        }
    }
}

// MARK: - Memory Module Settings View

private struct MemoryModuleSettingsView: View {
    @Binding var settings: MemoryModuleSettings

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            // Update Interval
            SettingsRow(label: "Update Interval", icon: "clock") {
                Picker("", selection: $settings.updateInterval) {
                    Text("0.5s").tag(0.5 as TimeInterval)
                    Text("1s").tag(1.0 as TimeInterval)
                    Text("2s").tag(2.0 as TimeInterval)
                    Text("5s").tag(5.0 as TimeInterval)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }

            Divider()

            // Top Process Count
            SettingsRow(label: "Top Processes", icon: "list.bullet") {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Stepper("\(settings.topProcessCount)", value: $settings.topProcessCount, in: 3...20)
                        .frame(width: 100)
                    Text("processes")
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
            }

            Divider()

            // Display Options
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text("Display Options")
                    .font(DesignTokens.Typography.subheadEmphasized)
                    .foregroundColor(DesignTokens.Colors.textSecondary)

                Toggle("Show Cache", isOn: $settings.showCache)
                Toggle("Show Wired", isOn: $settings.showWired)
            }
        }
    }
}

// MARK: - Sensors Module Settings View

private struct SensorsModuleSettingsView: View {
    @Binding var settings: SensorsModuleSettings

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            // Update Interval
            SettingsRow(label: "Update Interval", icon: "clock") {
                Picker("", selection: $settings.updateInterval) {
                    Text("0.5s").tag(0.5 as TimeInterval)
                    Text("1s").tag(1.0 as TimeInterval)
                    Text("2s").tag(2.0 as TimeInterval)
                    Text("5s").tag(5.0 as TimeInterval)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }

            Divider()

            // Fan Control Mode
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text("Fan Control Mode")
                    .font(DesignTokens.Typography.subheadEmphasized)
                    .foregroundColor(DesignTokens.Colors.textSecondary)

                Picker("", selection: $settings.fanControlMode) {
                    ForEach(SensorsModuleSettings.FanControlMode.allCases, id: \.self) { mode in
                        Label(mode.displayName, systemImage: mode.icon)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            Divider()

            // Display Options
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text("Display Options")
                    .font(DesignTokens.Typography.subheadEmphasized)
                    .foregroundColor(DesignTokens.Colors.textSecondary)

                Toggle("Show Fan Speeds", isOn: $settings.showFanSpeeds)
                Toggle("Save Fan Speeds", isOn: $settings.saveFanSpeed)
                Toggle("Sync Fan Control", isOn: $settings.syncFanControl)
            }
        }
    }
}

// MARK: - Battery Module Settings View

private struct BatteryModuleSettingsView: View {
    @Binding var settings: BatteryModuleSettings

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            // Update Interval
            SettingsRow(label: "Update Interval", icon: "clock") {
                Picker("", selection: $settings.updateInterval) {
                    Text("5s").tag(5.0 as TimeInterval)
                    Text("10s").tag(10.0 as TimeInterval)
                    Text("30s").tag(30.0 as TimeInterval)
                    Text("60s").tag(60.0 as TimeInterval)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }

            Divider()

            // Time Format
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text("Time Format")
                    .font(DesignTokens.Typography.subheadEmphasized)
                    .foregroundColor(DesignTokens.Colors.textSecondary)

                Picker("", selection: $settings.timeFormat) {
                    ForEach(BatteryModuleSettings.TimeFormat.allCases, id: \.self) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .pickerStyle(.segmented)
            }

            Divider()

            // Display Options
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text("Display Options")
                    .font(DesignTokens.Typography.subheadEmphasized)
                    .foregroundColor(DesignTokens.Colors.textSecondary)

                Toggle("Show Optimized Charging", isOn: $settings.showOptimizedCharging)
                Toggle("Show Cycle Count", isOn: $settings.showCycleCount)
            }
        }
    }
}

// MARK: - Settings Row Component

private struct SettingsRow<Content: View>: View {
    let label: String
    let icon: String
    let content: Content

    init(label: String, icon: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .frame(width: 24)

            Text(label)
                .font(DesignTokens.Typography.body)
                .foregroundColor(DesignTokens.Colors.textPrimary)

            Spacer()

            content
        }
    }
}

// MARK: - Preview

#Preview("Module Settings") {
    ModuleSettingsView()
        .frame(width: 540, height: 480)
}
