//
//  WidgetConfigurationSheet.swift
//  Tonic
//
//  Per-widget configuration sheet with Stats Master feature parity
//  Task ID: fn-5-v8r.14
//

import SwiftUI

// MARK: - Widget Display Mode Option

/// UI-only display mode options for the configuration sheet
/// Note: This is separate from the data model's WidgetDisplayMode which is Codable
public enum WidgetDisplayModeOption: String, CaseIterable, Identifiable {
    case iconOnly = "Icon Only"
    case iconAndValue = "Icon + Value"
    case iconValueAndSparkline = "Icon + Value + Sparkline"
    case compact = "Compact"
    case detailed = "Detailed"

    public var id: String { rawValue }

    /// Convert to the data model's WidgetDisplayMode
    public func toDataModel() -> WidgetDisplayMode {
        switch self {
        case .compact: return .compact
        case .detailed: return .detailed
        case .iconOnly, .iconAndValue, .iconValueAndSparkline: return .compact
        }
    }
}

// MARK: - Widget Refresh Interval

public enum WidgetRefreshInterval: Double, CaseIterable, Identifiable {
    case oneSecond = 1.0
    case twoSeconds = 2.0
    case threeSeconds = 3.0
    case fiveSeconds = 5.0
    case tenSeconds = 10.0
    case fifteenSeconds = 15.0
    case thirtySeconds = 30.0
    case sixtySeconds = 60.0

    public var id: String { "\(rawValue)" }

    public var description: String {
        switch self {
        case .oneSecond: return "1 second"
        case .twoSeconds: return "2 seconds"
        case .threeSeconds: return "3 seconds"
        case .fiveSeconds: return "5 seconds"
        case .tenSeconds: return "10 seconds"
        case .fifteenSeconds: return "15 seconds"
        case .thirtySeconds: return "30 seconds"
        case .sixtySeconds: return "60 seconds"
        }
    }
}

// MARK: - Available Widget Type

/// Available widget types for the configuration sheet UI
/// This bridges the UI config model with the data model's WidgetType
public enum AvailableWidgetType: String, CaseIterable, Identifiable {
    case cpu = "CPU"
    case memory = "Memory"
    case disk = "Disk"
    case network = "Network"
    case gpu = "GPU"
    case battery = "Battery"
    case weather = "Weather"
    case sensors = "Sensors"
    case bluetooth = "Bluetooth"
    case mini = "Mini"
    case lineChart = "Line Chart"
    case barChart = "Bar Chart"
    case pieChart = "Pie Chart"
    case tachometer = "Tachometer"
    case stack = "Stack"
    case speed = "Speed"
    case networkChart = "Network Chart"
    case batteryDetails = "Battery Details"
    case label = "Label"
    case state = "State"
    case text = "Text"
    case memory = "Memory Display"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .cpu: return "cpu"
        case .memory: return "memorychip"
        case .disk: return "internaldrive"
        case .network: return "network"
        case .gpu: return "cpu"
        case .battery: return "battery.100"
        case .weather: return "cloud.sun"
        case .sensors: return "thermometer"
        case .bluetooth: return "bluetooth"
        case .mini: return "circle"
        case .lineChart: return "chart.xyaxis.line"
        case .barChart: return "chart.bar.fill"
        case .pieChart: return "chart.pie.fill"
        case .tachometer: return "gauge"
        case .stack: return "stack"
        case .speed: return "speedometer"
        case .networkChart: return "network"
        case .batteryDetails: return "battery.100.bolt"
        case .label: return "textformat"
        case .state: return "circlebadge"
        case .text: return "text.alignleft"
        case .memory: return "memorychip"
        }
    }

    /// Convert to data model's WidgetType
    public func toWidgetType() -> WidgetType {
        switch self {
        case .cpu: return .cpu
        case .memory: return .memory
        case .disk: return .disk
        case .network: return .network
        case .gpu: return .gpu
        case .battery: return .battery
        case .weather: return .weather
        case .sensors: return .sensors
        case .bluetooth: return .bluetooth
        default: return .cpu  // Fallback for visualization types
        }
    }
}

// MARK: - Widget Config Model

@Observable
@MainActor
public final class WidgetConfig: Sendable {
    public var id: UUID
    public var name: String
    public var type: AvailableWidgetType
    public var displayMode: WidgetDisplayModeOption
    public var showLabel: Bool
    public var showIcon: Bool
    public var color: WidgetConfigColor
    public var refreshInterval: WidgetRefreshInterval
    public var historySize: Int  // For charts
    public var scalingMode: ScalingMode

    public init(
        id: UUID = UUID(),
        name: String,
        type: AvailableWidgetType,
        displayMode: WidgetDisplayModeOption = .iconAndValue,
        showLabel: Bool = true,
        showIcon: Bool = true,
        color: WidgetConfigColor = .accent,
        refreshInterval: WidgetRefreshInterval = .twoSeconds,
        historySize: Int = 60,
        scalingMode: ScalingMode = .linear
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.displayMode = displayMode
        self.showLabel = showLabel
        self.showIcon = showIcon
        self.color = color
        self.refreshInterval = refreshInterval
        self.historySize = historySize
        self.scalingMode = scalingMode
    }

    public var supportsHistory: Bool {
        type == .lineChart || type == .barChart
    }

    public var supportsScaling: Bool {
        type == .lineChart
    }
}

// MARK: - Widget Config Color Options

public enum WidgetConfigColor: String, CaseIterable, Identifiable {
    case accent = "Accent"
    case blue = "Blue"
    case green = "Green"
    case orange = "Orange"
    case red = "Red"
    case purple = "Purple"
    case pink = "Pink"
    case yellow = "Yellow"
    case monochrome = "Monochrome"
    case dynamic = "Dynamic (Value-based)"

    public var id: String { rawValue }

    public var color: Color {
        switch self {
        case .accent: return .accentColor
        case .blue: return .blue
        case .green: return .green
        case .orange: return .orange
        case .red: return .red
        case .purple: return .purple
        case .pink: return .pink
        case .yellow: return .yellow
        case .monochrome: return .primary
        case .dynamic: return .green  // Will change based on value
        }
    }
}

// MARK: - Widget Configuration Sheet

/// Per-widget configuration sheet with Stats Master feature parity
public struct WidgetConfigurationSheet: View {
    @Bindable var config: WidgetConfig
    @Environment(\.dismiss) private var dismiss

    public init(config: WidgetConfig) {
        self._config = State(initialValue: config)
    }

    public var body: some View {
        NavigationStack {
            Form {
                displayModeSection
                appearanceSection
                refreshSection

                if config.supportsHistory {
                    historySection
                }

                if config.supportsScaling {
                    scalingSection
                }
            }
            .formStyle(.grouped)
            .navigationTitle(config.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveConfig()
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 400, height: 500)
    }

    // MARK: - Sections

    private var displayModeSection: some View {
        Section("Display Mode") {
            Picker("Mode", selection: $config.displayMode) {
                ForEach(WidgetDisplayModeOption.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.menu)

            Toggle("Show Icon", isOn: $config.showIcon)
            Toggle("Show Label", isOn: $config.showLabel)
        }
    }

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Color", selection: $config.color) {
                ForEach(WidgetConfigColor.allCases) { color in
                    HStack {
                        Circle()
                            .fill(color.color)
                            .frame(width: 12, height: 12)
                        Text(color.rawValue)
                    }
                    .tag(color)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private var refreshSection: some View {
        Section("Refresh Interval") {
            Picker("Update Frequency", selection: $config.refreshInterval) {
                ForEach(WidgetRefreshInterval.allCases) { interval in
                    Text(interval.description).tag(interval)
                }
            }
            .pickerStyle(.menu)

            Text("More frequent updates use more CPU and battery")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var historySection: some View {
        Section("Chart History") {
            Picker("History Size", selection: Binding(
                get: { Int(config.historySize) },
                set: { config.historySize = $0 }
            )) {
                Text("30 points").tag(30)
                Text("60 points").tag(60)
                Text("90 points").tag(90)
                Text("120 points").tag(120)
            }
            .pickerStyle(.segmented)
        }
    }

    private var scalingSection: some View {
        Section("Scaling Mode") {
            Picker("Scaling", selection: $config.scalingMode) {
                Text("Linear").tag(ScalingMode.linear)
                Text("Square").tag(ScalingMode.square)
                Text("Cube").tag(ScalingMode.cube)
                Text("Logarithmic").tag(ScalingMode.logarithmic)
            }
            .pickerStyle(.menu)

            Text("Affects how values are displayed on the chart")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Actions

    private func saveConfig() {
        // Save to WidgetStore
        let store = WidgetStore.shared
        _ = store.saveConfig(WidgetConfiguration(
            id: config.id,
            name: config.name,
            type: .cpu,
            displayMode: .iconOnly,
            isEnabled: true,
            refreshInterval: config.refreshInterval.rawValue
        ))
    }
}

// MARK: - Compact Widget Config Row

/// Compact widget configuration row for inline editing
public struct WidgetConfigRow: View {
    @Bindable var config: WidgetConfig
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: config.type.icon)
                .foregroundColor(config.color.color)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(config.name)
                    .font(.subheadline)

                Text("\(config.refreshInterval.description) • \(config.displayMode.rawValue)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: onEdit) {
                Image(systemName: "gearshape")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(DesignTokens.Spacing.sm)
        .background(DesignTokens.Colors.backgroundSecondary)
        .cornerRadius(DesignTokens.CornerRadius.sm)
    }
}

// MARK: - Quick Config Toggle

/// Quick toggle for common widget settings
public struct WidgetQuickToggle: View {
    let title: String
    @Binding var isOn: Bool
    let icon: String
    let color: Color

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 16)

                Text(title)
                    .font(.subheadline)
            }
        }
        .toggleStyle(.switch)
    }
}

// MARK: - Preview

#Preview("Widget Configuration Sheet") {
    WidgetConfigurationSheet(
        config: WidgetConfig(
            name: "CPU Widget",
            type: .cpu,
            displayMode: .iconAndValue,
            showLabel: true,
            color: .blue
        )
    )
}

#Preview("Widget Config Row") {
    VStack(spacing: 8) {
        WidgetConfigRow(
            config: WidgetConfig(
                name: "CPU",
                type: .cpu,
                color: .blue
            ),
            onEdit: {}
        )

        WidgetConfigRow(
            config: WidgetConfig(
                name: "Memory",
                type: .memory,
                color: .purple
            ),
            onEdit: {}
        )
    }
    .padding()
}
