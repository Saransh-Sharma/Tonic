//
//  WidgetCustomizationView.swift
//  Tonic
//
//  Redesigned Menu Bar Widgets with native list
//  Task ID: fn-4-as7.12
//

import SwiftUI

// MARK: - Widget Customization View

/// Main UI for customizing menu bar widgets using native List
struct WidgetCustomizationView: View {

    @State private var preferences = WidgetPreferences.shared
    @State private var draggedWidget: WidgetType?
    @State private var showingResetAlert = false
    @State private var dataManager = WidgetDataManager.shared
    @State private var selectedWidgetForSettings: WidgetType?
    @State private var showingNotificationSettings = false
    @State private var dropTargetType: WidgetType?

    init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header with title and action buttons
            headerSection

            ScrollView {
                VStack(spacing: DesignTokens.Spacing.lg) {
                    // OneView mode toggle
                    oneViewModeSection

                    // Active widgets as a native list
                    activeWidgetsListSection

                    // Available widgets section
                    availableWidgetsSection
                }
                .padding(DesignTokens.Spacing.lg)
            }
        }
        .background(DesignTokens.Colors.background)
        .alert("Reset to Defaults", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                preferences.resetToDefaults()
            }
        } message: {
            Text("This will reset all widget settings to their default values.")
        }
        .sheet(item: $selectedWidgetForSettings) { type in
            WidgetSettingsSheet(widgetType: type, preferences: preferences)
        }
        .sheet(isPresented: $showingNotificationSettings) {
            NotificationSettingsView()
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
            HStack {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    Text("Menu Bar Widgets")
                        .font(DesignTokens.Typography.h3)

                    Text("Drag to reorder, toggle to enable/disable widgets in your menu bar.")
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }

                Spacer()

                HStack(spacing: DesignTokens.Spacing.sm) {
                    Button(action: { showingResetAlert = true }) {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                            .font(DesignTokens.Typography.caption)
                            .padding(.horizontal, DesignTokens.Spacing.sm)
                            .padding(.vertical, DesignTokens.Spacing.xs)
                            .background(DesignTokens.Colors.backgroundSecondary)
                            .cornerRadius(DesignTokens.CornerRadius.small)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Reset widgets")
                    .accessibilityHint("Resets all widget settings to defaults")

                    Button(action: { showingNotificationSettings = true }) {
                        Label("Notifications", systemImage: "bell")
                            .font(DesignTokens.Typography.caption)
                            .padding(.horizontal, DesignTokens.Spacing.sm)
                            .padding(.vertical, DesignTokens.Spacing.xs)
                            .background(NotificationManager.shared.config.notificationsEnabled
                                ? DesignTokens.Colors.success.opacity(0.2)
                                : DesignTokens.Colors.backgroundSecondary)
                            .foregroundColor(NotificationManager.shared.config.notificationsEnabled
                                ? DesignTokens.Colors.success
                                : DesignTokens.Colors.textSecondary)
                            .cornerRadius(DesignTokens.CornerRadius.small)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Notification settings")
                    .accessibilityHint("Configure notification thresholds")

                    Button(action: {
                        withAnimation(DesignTokens.Animation.fast) {
                            WidgetCoordinator.shared.refreshWidgets()
                        }
                    }) {
                        Label("Apply", systemImage: "checkmark")
                            .font(DesignTokens.Typography.caption)
                            .padding(.horizontal, DesignTokens.Spacing.sm)
                            .padding(.vertical, DesignTokens.Spacing.xs)
                            .foregroundColor(.white)
                            .background(DesignTokens.Colors.accent)
                            .cornerRadius(DesignTokens.CornerRadius.small)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Apply widgets")
                    .accessibilityHint("Applies widget configuration to menu bar")
                }
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.md)
    }

    // MARK: - OneView Mode Section

    private var oneViewModeSection: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(DesignTokens.Colors.accent)

                    Text("Unified Menu Bar Mode")
                        .font(DesignTokens.Typography.subhead)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                }

                Text("Combine all widgets into a single menu bar item")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }

            Spacer()

            // Toggle switch
            Toggle("", isOn: Binding(
                get: { preferences.unifiedMenuBarMode },
                set: { newValue in
                    withAnimation(DesignTokens.Animation.fast) {
                        preferences.setUnifiedMenuBarMode(newValue)
                        // Refresh widgets to apply mode change
                        WidgetCoordinator.shared.refreshWidgets()
                    }
                }
            ))
            .toggleStyle(.switch)
        }
        .padding(DesignTokens.Spacing.md)
        .background(DesignTokens.Colors.backgroundSecondary)
        .cornerRadius(DesignTokens.CornerRadius.medium)
    }

    // MARK: - Active Widgets List Section

    private var activeWidgetsListSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Active Widgets")
                .font(DesignTokens.Typography.captionEmphasized)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .textCase(.uppercase)
                .padding(.horizontal, DesignTokens.Spacing.md)

            VStack(spacing: 0) {
                ForEach(Array(preferences.enabledWidgets.enumerated()), id: \.element.id) { index, config in
                    activeWidgetRow(config, index: index, isLast: index == preferences.enabledWidgets.count - 1)
                }

                if preferences.enabledWidgets.isEmpty {
                    emptyStateRow
                }
            }
            .background(DesignTokens.Colors.backgroundSecondary)
            .cornerRadius(DesignTokens.CornerRadius.medium)
        }
    }

    private func activeWidgetRow(_ config: WidgetConfiguration, index: Int, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                // Drag handle
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                    .frame(width: 16)

                // Widget icon and name
                Image(systemName: config.type.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(config.accentColor.colorValue(for: config.type))
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
                    Text(config.type.displayName)
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(DesignTokens.Colors.textPrimary)

                    HStack(spacing: DesignTokens.Spacing.xs) {
                        Text(config.displayMode.displayName)
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(DesignTokens.Colors.textSecondary)

                        // Mini sparkline inline
                        miniSparkline(for: config)
                            .frame(width: 32, height: 12)

                        // Current value
                        Text(widgetPreviewValue(config))
                            .font(DesignTokens.Typography.caption)
                            .monospacedDigit()
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    }
                }

                Spacer()

                // Settings button
                Button(action: { selectedWidgetForSettings = config.type }) {
                    Image(systemName: "gear")
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
                .buttonStyle(.plain)
                .frame(width: 24)
            }
            .padding(.vertical, DesignTokens.Spacing.sm)
            .padding(.horizontal, DesignTokens.Spacing.md)
            .contentShape(Rectangle())
            .background(
                dropTargetType == config.type ?
                    DesignTokens.Colors.accent.opacity(0.1) : Color.clear
            )
            .opacity(draggedWidget == config.type ? 0.5 : 1.0)
            .onDrag {
                draggedWidget = config.type
                return NSItemProvider(object: config.type.rawValue as NSString)
            }
            .onDrop(of: [.text], delegate: WidgetTypeDropDelegate(
                currentType: config.type,
                draggedType: $draggedWidget,
                dropTargetType: $dropTargetType,
                onDrop: { draggedType in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        preferences.reorderWidgets(move: draggedType, to: config.type)
                    }
                    return true
                }
            ))
            .contextMenu {
                Button(action: { selectedWidgetForSettings = config.type }) {
                    Label("Settings", systemImage: "gear")
                }

                Divider()

                Button(role: .destructive, action: {
                    withAnimation {
                        preferences.setWidgetEnabled(type: config.type, enabled: false)
                    }
                }) {
                    Label("Remove", systemImage: "minus.circle")
                }
            }

            // Divider
            if !isLast {
                Divider()
                    .padding(.leading, DesignTokens.Spacing.md + 24 + DesignTokens.Spacing.sm)
            }
        }
    }

    private var emptyStateRow: some View {
        HStack {
            Spacer()
            VStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(DesignTokens.Colors.textTertiary)

                Text("No active widgets")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
            .padding(.vertical, DesignTokens.Spacing.lg)
            Spacer()
        }
    }

    // MARK: - Available Widgets Section

    private var availableWidgetsSection: some View {
        let availableTypes = WidgetType.parityCases.filter { type in
            preferences.config(for: type)?.isEnabled != true
        }

        return VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Available Widgets")
                .font(DesignTokens.Typography.captionEmphasized)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .textCase(.uppercase)
                .padding(.horizontal, DesignTokens.Spacing.md)

            if availableTypes.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: DesignTokens.Spacing.xs) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(DesignTokens.Colors.success)

                        Text("All widgets active")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(DesignTokens.Colors.textSecondary)

                        Text("Drag widgets here to remove")
                            .font(.caption2)
                            .foregroundColor(DesignTokens.Colors.textTertiary)
                    }
                    .padding(.vertical, DesignTokens.Spacing.lg)
                    Spacer()
                }
                .background(draggedWidget != nil ? DesignTokens.Colors.accent.opacity(0.1) : DesignTokens.Colors.backgroundSecondary)
                .cornerRadius(DesignTokens.CornerRadius.medium)
                .animation(.easeInOut(duration: 0.2), value: draggedWidget != nil)
                .onDrop(of: [.text], isTargeted: nil) { _ in
                    // Allow dropping active widgets here to disable them
                    guard let draggedType = draggedWidget else { return false }
                    withAnimation(DesignTokens.Animation.fast) {
                        preferences.setWidgetEnabled(type: draggedType, enabled: false)
                    }
                    draggedWidget = nil
                    return true
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(availableTypes.enumerated()), id: \.element) { index, type in
                        availableWidgetRow(type, isLast: index == availableTypes.count - 1)
                    }
                }
                .background(DesignTokens.Colors.backgroundSecondary)
                .cornerRadius(DesignTokens.CornerRadius.medium)
            }
        }
    }

    private func availableWidgetRow(_ type: WidgetType, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                // Add icon
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DesignTokens.Colors.accent)
                    .frame(width: 24)

                // Widget icon and name
                Image(systemName: type.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignTokens.Colors.accent)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
                    Text(type.displayName)
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(DesignTokens.Colors.textPrimary)

                    Text(widgetDescription(for: type))
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.vertical, DesignTokens.Spacing.sm)
            .padding(.horizontal, DesignTokens.Spacing.md)
            .contentShape(Rectangle())
            .background(
                dropTargetType == type ?
                    DesignTokens.Colors.accent.opacity(0.1) : Color.clear
            )
            .onTapGesture {
                withAnimation(DesignTokens.Animation.fast) {
                    toggleWidget(type)
                }
            }
            .onDrag {
                draggedWidget = type
                return NSItemProvider(object: type.rawValue as NSString)
            }
            .onDrop(of: [.text], delegate: AvailableWidgetDropDelegate(
                currentType: type,
                draggedType: $draggedWidget,
                dropTargetType: $dropTargetType,
                onDrop: { draggedType in
                    withAnimation(DesignTokens.Animation.fast) {
                        // If dragging from active list, enable it and add at end
                        if preferences.config(for: draggedType)?.isEnabled == false {
                            preferences.setWidgetEnabled(type: draggedType, enabled: true)
                        }
                        // If dragging within available list, reorder (not implemented for available)
                    }
                    return true
                }
            ))

            // Divider
            if !isLast {
                Divider()
                    .padding(.leading, DesignTokens.Spacing.md + 24 + DesignTokens.Spacing.sm)
            }
        }
    }

    // MARK: - Helper Methods

    private func miniSparkline(for config: WidgetConfiguration) -> some View {
        let data = sparklineData(for: config.type)
        let sparklineColor = config.accentColor.colorValue(for: config.type)

        return GeometryReader { geometry in
            Path { path in
                guard data.count > 1 else { return }

                let stepX = geometry.size.width / CGFloat(data.count - 1)
                let maxY = data.max() ?? 1
                let minY = data.min() ?? 0
                let range = max(maxY - minY, 0.1)

                for (index, value) in data.enumerated() {
                    let x = CGFloat(index) * stepX
                    let normalizedY = (value - minY) / range
                    let y = geometry.size.height * (1 - normalizedY)

                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(
                LinearGradient(
                    colors: [sparklineColor, sparklineColor.opacity(0.4)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                lineWidth: 1.2
            )
        }
    }

    private func sparklineData(for type: WidgetType) -> [Double] {
        switch type {
        case .cpu:
            let history = dataManager.cpuHistory.suffix(10)
            return history.isEmpty ? [30, 35, 32, 38, 36, 34, 37, 35, 33, 36] : Array(history)
        case .memory:
            let history = dataManager.memoryHistory.suffix(10)
            return history.isEmpty ? [60, 62, 58, 65, 63, 67, 64, 68, 66, 65] : Array(history)
        default:
            return [30, 35, 32, 38, 36, 34, 37, 35, 33, 36]
        }
    }

    private func toggleWidget(_ type: WidgetType) {
        let currentConfig = preferences.config(for: type)
        let newState = !(currentConfig?.isEnabled ?? false)

        if newState {
            let maxPosition = preferences.widgetConfigs.map { $0.position }.max() ?? 0
            var newConfig = WidgetConfiguration.default(for: type, at: maxPosition + 1)
            newConfig.isEnabled = true
            preferences.updateConfig(for: type) { config in
                config = newConfig
            }
        } else {
            preferences.setWidgetEnabled(type: type, enabled: false)
        }
    }

    private func widgetPreviewValue(_ config: WidgetConfiguration) -> String {
        let usePercent = config.valueFormat == .percentage

        switch config.type {
        case .cpu:
            return "\(Int(dataManager.cpuData.totalUsage))%"
        case .memory:
            if usePercent {
                return "\(Int(dataManager.memoryData.usagePercentage))%"
            } else {
                let usedGB = Double(dataManager.memoryData.usedBytes) / (1024 * 1024 * 1024)
                return String(format: "%.1f GB", usedGB)
            }
        case .disk:
            if let primary = dataManager.diskVolumes.first {
                if usePercent {
                    return "\(Int(primary.usagePercentage))%"
                } else {
                    let freeGB = primary.freeBytes / (1024 * 1024 * 1024)
                    return "\(freeGB)GB"
                }
            }
            return "--"
        case .network:
            return dataManager.networkData.downloadString
        case .gpu:
            if let usage = dataManager.gpuData.usagePercentage {
                return "\(Int(usage))%"
            }
            return "--"
        case .battery:
            return "\(Int(dataManager.batteryData.chargePercentage))%"
        case .weather:
            return "21°C"
        case .sensors:
            return "--"
        case .bluetooth:
            if let device = dataManager.bluetoothData.devicesWithBattery.first,
               let battery = device.primaryBatteryLevel {
                return "\(battery)%"
            }
            return "\(dataManager.bluetoothData.connectedDevices.count)"
        case .clock:
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: Date())
        }
    }

    private func widgetDescription(for type: WidgetType) -> String {
        switch type {
        case .cpu: return "Monitor CPU usage and core activity."
        case .memory: return "Track RAM usage and available memory."
        case .disk: return "Monitor available space on drives."
        case .network: return "Real-time upload and download speeds."
        case .gpu: return "Monitor GPU utilization."
        case .battery: return "Displays charge and time remaining."
        case .weather: return "Current local temperature."
        case .sensors: return "System temperature and fan sensors."
        case .bluetooth: return "Connected Bluetooth device batteries."
        case .clock: return "Current local time."
        }
    }
}

// MARK: - Widget Settings Sheet

struct WidgetSettingsSheet: View {
    let widgetType: WidgetType
    @Bindable var preferences: WidgetPreferences
    @Environment(\.dismiss) private var dismiss

    @State private var showingResetAlert = false

    private var config: WidgetConfiguration? {
        preferences.config(for: widgetType)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                HStack {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        Image(systemName: widgetType.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(widgetAccentColor)

                        Text("\(widgetType.displayName) Settings")
                            .font(DesignTokens.Typography.bodyEmphasized)
                    }

                    Spacer()

                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(DesignTokens.Colors.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(DesignTokens.Spacing.md)

            Divider()

            // Settings content
            ScrollView {
                VStack(spacing: DesignTokens.Spacing.lg) {
                    PreferenceList {
                        // Visualization Type Section
                        PreferenceSection(header: "Visualization Type") {
                            visualizationTypeSelector
                        }

                        // Display Mode Section
                        PreferenceSection(header: "Display Mode") {
                            displayModeSelector
                        }

                        // Label Toggle Section
                        PreferenceSection(header: "Label") {
                            labelToggleRow
                        }

                        // Value Format Section (only show for relevant widget types)
                        if supportsValueFormat {
                            PreferenceSection(header: "Value Format") {
                                valueFormatSelector
                            }
                        }

                        // Update Frequency Section
                        PreferenceSection(header: "Update Frequency") {
                            updateFrequencySelector
                        }

                        // Per-Module Settings Section (Stats Master parity)
                        if hasModuleSpecificSettings {
                            PreferenceSection(header: "Module Settings") {
                                moduleSpecificSettings
                            }
                        }

                        // Widget Color Section
                        PreferenceSection(header: "Widget Color") {
                            colorSelector
                        }

                        // Chart Configuration Section (only show for chart-based visualizations)
                        if supportsChartConfiguration {
                            PreferenceSection(header: "Chart Configuration") {
                                chartConfigurationSection
                            }
                        }

                        // Notifications Section (only show for notifiable widget types)
                        if supportsNotifications {
                            PreferenceSection(header: "Notifications") {
                                widgetNotificationSettings
                            }
                        }

                        // Preview Section
                        PreferenceSection(header: "Preview") {
                            widgetPreview
                        }
                    }
                }
                .padding(DesignTokens.Spacing.lg)
            }

            Divider()

            // Footer with Reset, Remove, and Done buttons
            HStack(spacing: DesignTokens.Spacing.md) {
                // Reset to Defaults button
                Button {
                    showingResetAlert = true
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                        .padding(.horizontal, DesignTokens.Spacing.md)
                        .padding(.vertical, DesignTokens.Spacing.sm)
                        .background(DesignTokens.Colors.backgroundSecondary)
                        .cornerRadius(DesignTokens.CornerRadius.medium)
                }
                .buttonStyle(.plain)
                .help("Reset this widget to default settings")

                Spacer()

                // Remove button
                Button(role: .destructive, action: {
                    withAnimation {
                        preferences.setWidgetEnabled(type: widgetType, enabled: false)
                    }
                    dismiss()
                }) {
                    Label("Remove", systemImage: "trash")
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(DesignTokens.Colors.destructive)
                        .padding(.horizontal, DesignTokens.Spacing.md)
                        .padding(.vertical, DesignTokens.Spacing.sm)
                        .background(DesignTokens.Colors.destructive.opacity(0.1))
                        .cornerRadius(DesignTokens.CornerRadius.medium)
                }
                .buttonStyle(.plain)

                // Done button
                Button(action: {
                    WidgetCoordinator.shared.refreshWidgets()
                    dismiss()
                }) {
                    Text("Done")
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(.white)
                        .padding(.horizontal, DesignTokens.Spacing.md)
                        .padding(.vertical, DesignTokens.Spacing.sm)
                        .background(DesignTokens.Colors.accent)
                        .cornerRadius(DesignTokens.CornerRadius.medium)
                }
                .buttonStyle(.plain)
            }
            .padding(DesignTokens.Spacing.md)
        }
        .frame(width: 450, height: 650)
        .background(DesignTokens.Colors.background)
        .alert("Reset to Defaults", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                resetWidgetToDefaults()
            }
        } message: {
            Text("This will reset all settings for this widget to their default values.")
        }
    }

    // MARK: - Computed Properties

    private var supportsValueFormat: Bool {
        switch widgetType {
        case .cpu, .memory, .gpu, .battery, .disk:
            return true
        case .network, .weather, .sensors, .bluetooth, .clock:
            return false
        }
    }

    private var supportsChartConfiguration: Bool {
        guard let config = config else { return false }
        return config.visualizationType.supportsHistory
    }

    private var supportsNotifications: Bool {
        switch widgetType {
        case .cpu, .memory, .disk, .gpu, .battery, .sensors:
            return true
        case .network, .weather, .bluetooth, .clock:
            return false
        }
    }

    private var hasModuleSpecificSettings: Bool {
        switch widgetType {
        case .cpu, .disk, .network, .memory, .sensors, .battery:
            return true
        case .gpu, .weather, .bluetooth, .clock:
            return false
        }
    }

    // MARK: - Module-Specific Settings

    /// Per-module settings based on Stats Master's module settings
    /// Each module type has its own set of configurable options
    private var moduleSpecificSettings: some View {
        Group {
            switch widgetType {
            case .cpu:
                cpuModuleSettings
            case .disk:
                diskModuleSettings
            case .network:
                networkModuleSettings
            case .memory:
                memoryModuleSettings
            case .sensors:
                sensorsModuleSettings
            case .battery:
                batteryModuleSettings
            default:
                EmptyView()
            }
        }
    }

    // MARK: - CPU Module Settings

    private var cpuModuleSettings: some View {
        VStack(spacing: 0) {
            // Show E/P cores toggle
            cpuShowCoresRow

            Divider()
                .padding(.leading, DesignTokens.Spacing.md)

            // Show frequency toggle
            cpuShowFrequencyRow

            Divider()
                .padding(.leading, DesignTokens.Spacing.md)

            // Show temperature toggle
            cpuShowTemperatureRow

            Divider()
                .padding(.leading, DesignTokens.Spacing.md)

            // Show load average toggle
            cpuShowLoadAvgRow
        }
    }

    private var cpuShowCoresRow: some View {
        PreferenceRow(
            title: "Show E/P Cores",
            subtitle: "Display efficiency and performance cores separately",
            icon: "cpu",
            iconColor: DesignTokens.Colors.accent,
            showDivider: false
        ) {
            Toggle("", isOn: Binding(
                get: { config?.moduleSettings.cpu.showEPCores ?? false },
                set: { newValue in
                    updateModuleSettings { settings in
                        settings.cpu.showEPCores = newValue
                    }
                }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
        }
    }

    private var cpuShowFrequencyRow: some View {
        PreferenceRow(
            title: "Show Frequency",
            subtitle: "Display CPU frequency in MHz",
            icon: "gauge",
            iconColor: DesignTokens.Colors.accent,
            showDivider: false
        ) {
            Toggle("", isOn: Binding(
                get: { config?.moduleSettings.cpu.showFrequency ?? false },
                set: { newValue in
                    updateModuleSettings { settings in
                        settings.cpu.showFrequency = newValue
                    }
                }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
        }
    }

    private var cpuShowTemperatureRow: some View {
        PreferenceRow(
            title: "Show Temperature",
            subtitle: "Display CPU temperature in popover",
            icon: "thermometer",
            iconColor: DesignTokens.Colors.warning,
            showDivider: false
        ) {
            Toggle("", isOn: Binding(
                get: { config?.moduleSettings.cpu.showTemperature ?? true },
                set: { newValue in
                    updateModuleSettings { settings in
                        settings.cpu.showTemperature = newValue
                    }
                }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
        }
    }

    private var cpuShowLoadAvgRow: some View {
        PreferenceRow(
            title: "Show Load Average",
            subtitle: "Display 1/5/15 minute load averages",
            icon: "chart.line.uptrend.xyaxis",
            iconColor: DesignTokens.Colors.accent,
            showDivider: false
        ) {
            Toggle("", isOn: Binding(
                get: { config?.moduleSettings.cpu.showLoadAverage ?? true },
                set: { newValue in
                    updateModuleSettings { settings in
                        settings.cpu.showLoadAverage = newValue
                    }
                }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
        }
    }

    // MARK: - Disk Module Settings

    private var diskModuleSettings: some View {
        VStack(spacing: 0) {
            // Volume selector
            diskVolumeSelectorRow

            Divider()
                .padding(.leading, DesignTokens.Spacing.md)

            // Show SMART toggle
            diskShowSMARTRow
        }
    }

    private var diskVolumeSelectorRow: some View {
        let availableVolumes = WidgetDataManager.shared.diskVolumes
        let selectedVolume = config?.moduleSettings.disk.selectedVolume ?? "Auto"

        return PreferenceRow(
            title: "Volume",
            subtitle: "Select which disk volume to monitor",
            icon: "internaldrive",
            iconColor: DesignTokens.Colors.accent,
            showDivider: false
        ) {
            Menu {
                Text("Auto")
                    .tag("Auto")
                Divider()
                ForEach(availableVolumes, id: \.name) { volume in
                    Button(action: {
                        updateModuleSettings { settings in
                            settings.disk.selectedVolume = volume.name
                        }
                    }) {
                        HStack {
                            Text(volume.name)
                            if selectedVolume == volume.name {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Text(selectedVolume)
                        .font(DesignTokens.Typography.subhead)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                }
                .foregroundColor(DesignTokens.Colors.textPrimary)
            }
            .menuStyle(.borderlessButton)
        }
    }

    private var diskShowSMARTRow: some View {
        PreferenceRow(
            title: "Show SMART Status",
            subtitle: "Display SMART health information",
            icon: "checkmark.seal",
            iconColor: DesignTokens.Colors.success,
            showDivider: false
        ) {
            Toggle("", isOn: Binding(
                get: { config?.moduleSettings.disk.showSMART ?? true },
                set: { newValue in
                    updateModuleSettings { settings in
                        settings.disk.showSMART = newValue
                    }
                }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
        }
    }

    // MARK: - Network Module Settings

    private var networkModuleSettings: some View {
        VStack(spacing: 0) {
            // Interface selector
            networkInterfaceSelectorRow

            Divider()
                .padding(.leading, DesignTokens.Spacing.md)

            // Show public IP toggle
            networkShowPublicIPRow

            Divider()
                .padding(.leading, DesignTokens.Spacing.md)

            // Show WiFi details toggle
            networkShowWiFiDetailsRow
        }
    }

    private var networkInterfaceSelectorRow: some View {
        let selectedInterface = config?.moduleSettings.network.selectedInterface ?? "Auto"

        return PreferenceRow(
            title: "Network Interface",
            subtitle: "Select which network interface to monitor",
            icon: "network",
            iconColor: DesignTokens.Colors.accent,
            showDivider: false
        ) {
            Menu {
                Button("Auto") {
                    updateModuleSettings { settings in
                        settings.network.selectedInterface = "Auto"
                    }
                }
                Divider()
                Button("Wi-Fi") {
                    updateModuleSettings { settings in
                        settings.network.selectedInterface = "Wi-Fi"
                    }
                }
                Button("Ethernet") {
                    updateModuleSettings { settings in
                        settings.network.selectedInterface = "Ethernet"
                    }
                }
            } label: {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Text(selectedInterface)
                        .font(DesignTokens.Typography.subhead)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                }
                .foregroundColor(DesignTokens.Colors.textPrimary)
            }
            .menuStyle(.borderlessButton)
        }
    }

    private var networkShowPublicIPRow: some View {
        PreferenceRow(
            title: "Show Public IP",
            subtitle: "Display public IP address in popover",
            icon: "globe",
            iconColor: DesignTokens.Colors.accent,
            showDivider: false
        ) {
            Toggle("", isOn: Binding(
                get: { config?.moduleSettings.network.showPublicIP ?? false },
                set: { newValue in
                    updateModuleSettings { settings in
                        settings.network.showPublicIP = newValue
                    }
                }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
        }
    }

    private var networkShowWiFiDetailsRow: some View {
        PreferenceRow(
            title: "Show WiFi Details",
            subtitle: "Display SSID, signal strength, and channel",
            icon: "wifi",
            iconColor: DesignTokens.Colors.accent,
            showDivider: false
        ) {
            Toggle("", isOn: Binding(
                get: { config?.moduleSettings.network.showWiFiDetails ?? true },
                set: { newValue in
                    updateModuleSettings { settings in
                        settings.network.showWiFiDetails = newValue
                    }
                }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
        }
    }

    // MARK: - Memory Module Settings

    private var memoryModuleSettings: some View {
        VStack(spacing: 0) {
            // Show cache toggle
            memoryShowCacheRow

            Divider()
                .padding(.leading, DesignTokens.Spacing.md)

            // Show wired toggle
            memoryShowWiredRow
        }
    }

    private var memoryShowCacheRow: some View {
        PreferenceRow(
            title: "Show Cache",
            subtitle: "Display cached memory in breakdown",
            icon: "arrow.triangle.2.circlepath",
            iconColor: DesignTokens.Colors.accent,
            showDivider: false
        ) {
            Toggle("", isOn: Binding(
                get: { config?.moduleSettings.memory.showCache ?? true },
                set: { newValue in
                    updateModuleSettings { settings in
                        settings.memory.showCache = newValue
                    }
                }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
        }
    }

    private var memoryShowWiredRow: some View {
        PreferenceRow(
            title: "Show Wired",
            subtitle: "Display wired memory in breakdown",
            icon: "lock",
            iconColor: DesignTokens.Colors.accent,
            showDivider: false
        ) {
            Toggle("", isOn: Binding(
                get: { config?.moduleSettings.memory.showWired ?? true },
                set: { newValue in
                    updateModuleSettings { settings in
                        settings.memory.showWired = newValue
                    }
                }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
        }
    }

    // MARK: - Sensors Module Settings

    private var sensorsModuleSettings: some View {
        VStack(spacing: 0) {
            // Show fan speeds toggle
            sensorsShowFanSpeedsRow
        }
    }

    private var sensorsShowFanSpeedsRow: some View {
        PreferenceRow(
            title: "Show Fan Speeds",
            subtitle: "Display fan RPM readings",
            icon: "wind",
            iconColor: DesignTokens.Colors.accent,
            showDivider: false
        ) {
            Toggle("", isOn: Binding(
                get: { config?.moduleSettings.sensors.showFanSpeeds ?? true },
                set: { newValue in
                    updateModuleSettings { settings in
                        settings.sensors.showFanSpeeds = newValue
                    }
                }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
        }
    }

    // MARK: - Battery Module Settings

    private var batteryModuleSettings: some View {
        VStack(spacing: 0) {
            // Show optimized charging toggle
            batteryShowOptimizedChargingRow

            Divider()
                .padding(.leading, DesignTokens.Spacing.md)

            // Show cycle count toggle
            batteryShowCycleCountRow
        }
    }

    private var batteryShowOptimizedChargingRow: some View {
        PreferenceRow(
            title: "Show Optimized Charging",
            subtitle: "Display optimized charging status",
            icon: "leaf",
            iconColor: DesignTokens.Colors.success,
            showDivider: false
        ) {
            Toggle("", isOn: Binding(
                get: { config?.moduleSettings.battery.showOptimizedCharging ?? true },
                set: { newValue in
                    updateModuleSettings { settings in
                        settings.battery.showOptimizedCharging = newValue
                    }
                }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
        }
    }

    private var batteryShowCycleCountRow: some View {
        PreferenceRow(
            title: "Show Cycle Count",
            subtitle: "Display battery cycle count",
            icon: "arrow.clockwise",
            iconColor: DesignTokens.Colors.accent,
            showDivider: false
        ) {
            Toggle("", isOn: Binding(
                get: { config?.moduleSettings.battery.showCycleCount ?? true },
                set: { newValue in
                    updateModuleSettings { settings in
                        settings.battery.showCycleCount = newValue
                    }
                }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
        }
    }

    // MARK: - Module Settings Update Helper

    /// Helper to update module-specific settings
    private func updateModuleSettings(_ update: (inout ModuleSettings) -> Void) {
        var currentSettings = config?.moduleSettings ?? ModuleSettings.default
        update(&currentSettings)
        preferences.setWidgetModuleSettings(type: widgetType, settings: currentSettings)
    }

    // MARK: - Visualization Type Selector

    private var visualizationTypeSelector: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text("Choose how this widget displays data")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: DesignTokens.Spacing.xs), count: 3),
                spacing: DesignTokens.Spacing.xs
            ) {
                ForEach(compatibleVisualizations) { visualization in
                    visualizationTypeButton(visualization)
                }
            }
        }
    }

    private var compatibleVisualizations: [VisualizationType] {
        widgetType.compatibleVisualizations
    }

    private func visualizationTypeButton(_ visualization: VisualizationType) -> some View {
        let isSelected = config?.visualizationType == visualization

        return Button {
            withAnimation(DesignTokens.Animation.fast) {
                preferences.setWidgetVisualization(type: widgetType, visualization: visualization)
            }
        } label: {
            VStack(spacing: DesignTokens.Spacing.xxxs) {
                Image(systemName: visualization.icon)
                    .font(.system(size: 14, weight: .semibold))

                Text(visualization.displayName)
                    .font(DesignTokens.Typography.caption)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .foregroundColor(isSelected ? .white : DesignTokens.Colors.textSecondary)
            .background(isSelected ? DesignTokens.Colors.accent : DesignTokens.Colors.backgroundSecondary)
            .cornerRadius(DesignTokens.CornerRadius.small)
        }
        .buttonStyle(.plain)
        .help(visualization.description)
    }

    // MARK: - Label Toggle

    private var labelToggleRow: some View {
        PreferenceRow(
            title: "Show Label",
            subtitle: "Display widget name in menu bar",
            icon: "textformat",
            iconColor: DesignTokens.Colors.textSecondary,
            showDivider: false
        ) {
            Toggle("", isOn: Binding(
                get: { config?.showLabel ?? false },
                set: { newValue in
                    withAnimation(DesignTokens.Animation.fast) {
                        preferences.setWidgetShowLabel(type: widgetType, show: newValue)
                    }
                }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
        }
    }

    // MARK: - Chart Configuration Section

    private var chartConfigurationSection: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            // History Length Slider
            chartHistoryLengthRow

            // Scale Type Picker
            chartScaleTypeRow

            // Fill Mode (line charts only)
            if config?.visualizationType == .lineChart {
                chartFillModeRow
            }

            // Bar Color Mode (bar charts only)
            if config?.visualizationType == .barChart {
                chartBarColorModeRow
            }

            // Show Background Toggle
            chartShowBackgroundRow

            // Show Frame Toggle
            chartShowFrameRow
        }
    }

    private var chartHistoryLengthRow: some View {
        let currentHistorySize = config?.chartConfig?.historySize ?? ChartConfiguration.default.historySize

        return VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            HStack {
                Text("History Length")
                    .font(DesignTokens.Typography.subhead)
                    .foregroundColor(DesignTokens.Colors.textPrimary)

                Spacer()

                Text("\(currentHistorySize) points")
                    .font(DesignTokens.Typography.caption)
                    .monospacedDigit()
                    .foregroundColor(DesignTokens.Colors.accent)
            }

            Slider(
                value: Binding(
                    get: { Double(currentHistorySize) },
                    set: { newValue in
                        updateChartConfig { config in
                            config.historySize = Int(newValue)
                        }
                    }
                ),
                in: 30...120,
                step: 10
            )
            .accentColor(DesignTokens.Colors.accent)

            HStack {
                Text("30")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textTertiary)

                Spacer()

                Text("120")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .background(DesignTokens.Colors.backgroundTertiary)
        .cornerRadius(DesignTokens.CornerRadius.small)
    }

    private var chartScaleTypeRow: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
            Text("Scale Type")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: DesignTokens.Spacing.xxxs) {
                ForEach(ScalingMode.allCases) { mode in
                    scaleTypeButton(mode)
                }
            }
        }
    }

    private func scaleTypeButton(_ mode: ScalingMode) -> some View {
        let isSelected = config?.chartConfig?.scaling == mode

        return Button {
            updateChartConfig { config in
                config.scaling = mode
            }
        } label: {
            Text(mode.displayName)
                .font(DesignTokens.Typography.caption)
                .foregroundColor(isSelected ? .white : DesignTokens.Colors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.Spacing.xs)
                .background(isSelected ? DesignTokens.Colors.accent : DesignTokens.Colors.backgroundTertiary)
                .cornerRadius(DesignTokens.CornerRadius.small)
        }
        .buttonStyle(.plain)
    }

    private var chartFillModeRow: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
            Text("Fill Mode")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: DesignTokens.Spacing.xxxs) {
                ForEach(ChartFillMode.allCases) { mode in
                    fillModeButton(mode)
                }
            }
        }
    }

    private func fillModeButton(_ mode: ChartFillMode) -> some View {
        let isSelected = config?.chartConfig?.fillMode == mode

        return Button {
            updateChartConfig { config in
                config.fillMode = mode
            }
        } label: {
            Text(mode.displayName)
                .font(DesignTokens.Typography.caption)
                .foregroundColor(isSelected ? .white : DesignTokens.Colors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.Spacing.xs)
                .background(isSelected ? DesignTokens.Colors.accent : DesignTokens.Colors.backgroundTertiary)
                .cornerRadius(DesignTokens.CornerRadius.small)
        }
        .buttonStyle(.plain)
    }

    private var chartBarColorModeRow: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
            Text("Bar Color Mode")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: DesignTokens.Spacing.xxxs) {
                ForEach(ChartBarColorMode.allCases) { mode in
                    barColorModeButton(mode)
                }
            }
        }
    }

    private func barColorModeButton(_ mode: ChartBarColorMode) -> some View {
        let isSelected = config?.chartConfig?.barColorMode == mode

        return Button {
            updateChartConfig { config in
                config.barColorMode = mode
            }
        } label: {
            Text(mode.displayName)
                .font(DesignTokens.Typography.caption)
                .foregroundColor(isSelected ? .white : DesignTokens.Colors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.Spacing.xs)
                .background(isSelected ? DesignTokens.Colors.accent : DesignTokens.Colors.backgroundTertiary)
                .cornerRadius(DesignTokens.CornerRadius.small)
        }
        .buttonStyle(.plain)
    }

    private var chartShowBackgroundRow: some View {
        PreferenceRow(
            title: "Show Background",
            subtitle: "Display chart background fill",
            icon: "square.fill",
            iconColor: DesignTokens.Colors.textSecondary,
            showDivider: true
        ) {
            Toggle("", isOn: Binding(
                get: { config?.chartConfig?.showBackground ?? false },
                set: { newValue in
                    updateChartConfig { config in
                        config.showBackground = newValue
                    }
                }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
        }
    }

    private var chartShowFrameRow: some View {
        PreferenceRow(
            title: "Show Frame",
            subtitle: "Display border around chart",
            icon: "square",
            iconColor: DesignTokens.Colors.textSecondary,
            showDivider: false
        ) {
            Toggle("", isOn: Binding(
                get: { config?.chartConfig?.showFrame ?? false },
                set: { newValue in
                    updateChartConfig { config in
                        config.showFrame = newValue
                    }
                }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
        }
    }

    private func updateChartConfig(_ update: (inout ChartConfiguration) -> Void) {
        var currentConfig = config?.chartConfig ?? ChartConfiguration.default
        update(&currentConfig)
        preferences.setWidgetChartConfig(type: widgetType, chartConfig: currentConfig)
    }

    // MARK: - Reset to Defaults

    private func resetWidgetToDefaults() {
        let defaultConfig = WidgetConfiguration.default(for: widgetType, at: config?.position ?? 0)
        preferences.updateConfig(for: widgetType) { config in
            config.visualizationType = defaultConfig.visualizationType
            config.displayMode = defaultConfig.displayMode
            config.showLabel = defaultConfig.showLabel
            config.valueFormat = defaultConfig.valueFormat
            config.refreshInterval = defaultConfig.refreshInterval
            config.accentColor = defaultConfig.accentColor
            config.chartConfig = defaultConfig.chartConfig
        }

        // Also reset notification thresholds for this widget
        let notificationManager = NotificationManager.shared
        let thresholds = notificationManager.config.thresholds(for: widgetType)
        for threshold in thresholds {
            notificationManager.removeThreshold(id: threshold.id)
        }

        WidgetCoordinator.shared.refreshWidgets()
    }

    private var displayModeSelector: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            ForEach(WidgetDisplayMode.allCases) { mode in
                displayModeButton(mode)
            }
        }
    }

    private func displayModeButton(_ mode: WidgetDisplayMode) -> some View {
        let isSelected = config?.displayMode == mode

        return Button {
            withAnimation(DesignTokens.Animation.fast) {
                preferences.setWidgetDisplayMode(type: widgetType, mode: mode)
            }
        } label: {
            VStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: iconForDisplayMode(mode))
                    .font(.system(size: 16, weight: .semibold))

                Text(mode.shortLabel)
                    .font(DesignTokens.Typography.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .foregroundColor(isSelected ? .white : DesignTokens.Colors.textSecondary)
            .background(isSelected ? DesignTokens.Colors.accent : DesignTokens.Colors.backgroundSecondary)
            .cornerRadius(DesignTokens.CornerRadius.small)
        }
        .buttonStyle(.plain)
    }

    private func iconForDisplayMode(_ mode: WidgetDisplayMode) -> String {
        switch mode {
        case .compact: return "square.split.1x2"
        case .detailed: return "chart.line.uptrend.xyaxis"
        }
    }

    private var valueFormatSelector: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            ForEach(WidgetValueFormat.allCases) { format in
                valueFormatButton(format)
            }
        }
    }

    private func valueFormatButton(_ format: WidgetValueFormat) -> some View {
        let isSelected = config?.valueFormat == format

        return Button {
            withAnimation(DesignTokens.Animation.fast) {
                preferences.setWidgetValueFormat(type: widgetType, format: format)
            }
        } label: {
            VStack(spacing: DesignTokens.Spacing.xxxs) {
                Text(exampleValueForFormat(format))
                    .font(DesignTokens.Typography.captionEmphasized)
                    .monospacedDigit()

                Text(format.displayName)
                    .font(DesignTokens.Typography.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .foregroundColor(isSelected ? .white : DesignTokens.Colors.textSecondary)
            .background(isSelected ? DesignTokens.Colors.accent : DesignTokens.Colors.backgroundSecondary)
            .cornerRadius(DesignTokens.CornerRadius.small)
        }
        .buttonStyle(.plain)
    }

    private func exampleValueForFormat(_ format: WidgetValueFormat) -> String {
        switch format {
        case .percentage:
            switch widgetType {
            case .cpu: return "42%"
            case .memory: return "65%"
            case .disk: return "78%"
            case .gpu: return "45%"
            case .battery: return "85%"
            default: return "50%"
            }
        case .valueWithUnit:
            switch widgetType {
            case .cpu: return "4.2 GHz"
            case .memory: return "13.0 GB"
            case .disk: return "41 GB"
            case .network: return "12 MB/s"
            case .gpu: return "1.2 GHz"
            case .battery: return "3h 20m"
            case .weather: return "21°C"
            case .sensors: return "45°C"
            case .bluetooth: return "2 devices"
            case .clock: return "12:00"
            }
        }
    }

    private var updateFrequencySelector: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            ForEach(WidgetUpdateInterval.allCases) { interval in
                updateIntervalButton(interval)
            }
        }
    }

    private func updateIntervalButton(_ interval: WidgetUpdateInterval) -> some View {
        let isSelected = config?.refreshInterval == interval

        return Button {
            withAnimation(DesignTokens.Animation.fast) {
                preferences.setWidgetRefreshInterval(type: widgetType, interval: interval)
            }
        } label: {
            VStack(spacing: DesignTokens.Spacing.xxxs) {
                Text("\(Int(interval.timeInterval))s")
                    .font(DesignTokens.Typography.captionEmphasized)

                Text(intervalLabel(interval))
                    .font(DesignTokens.Typography.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .foregroundColor(isSelected ? .white : DesignTokens.Colors.textSecondary)
            .background(isSelected ? DesignTokens.Colors.accent : DesignTokens.Colors.backgroundSecondary)
            .cornerRadius(DesignTokens.CornerRadius.small)
        }
        .buttonStyle(.plain)
    }

    private func intervalLabel(_ interval: WidgetUpdateInterval) -> String {
        switch interval {
        case .power: return "Power Saver"
        case .balanced: return "Balanced"
        case .performance: return "Real-time"
        }
    }

    private var colorSelector: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            // Automatic color options
            colorCategorySection(
                title: "Automatic",
                colors: WidgetAccentColor.automaticColors
            )

            // System colors
            colorCategorySection(
                title: "System",
                colors: WidgetAccentColor.systemColors
            )

            // Primary colors
            colorCategorySection(
                title: "Primary",
                colors: WidgetAccentColor.primaryColors
            )

            // Secondary colors
            colorCategorySection(
                title: "Secondary",
                colors: WidgetAccentColor.secondaryColors
            )

            // Gray colors
            colorCategorySection(
                title: "Grays",
                colors: WidgetAccentColor.grayColors
            )

            // Special colors
            colorCategorySection(
                title: "Special",
                colors: WidgetAccentColor.specialColors
            )
        }
    }

    private func colorCategorySection(title: String, colors: [WidgetAccentColor]) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
            Text(title)
                .font(DesignTokens.Typography.caption)
                .foregroundColor(DesignTokens.Colors.textTertiary)

            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(32), spacing: DesignTokens.Spacing.xs), count: 8),
                spacing: DesignTokens.Spacing.xs
            ) {
                ForEach(colors) { color in
                    colorSwatchButton(color)
                }
            }
        }
    }

    private func colorSwatchButton(_ color: WidgetAccentColor) -> some View {
        let isSelected = config?.accentColor == color

        return Button {
            withAnimation(DesignTokens.Animation.fast) {
                preferences.setWidgetColor(type: widgetType, color: color)
            }
        } label: {
            ZStack {
                if color.isAutomatic {
                    Circle()
                        .fill(automaticColorGradient(for: color))
                        .frame(width: 24, height: 24)
                } else if color == .clear {
                    Circle()
                        .fill(
                            AngularGradient(
                                colors: [.white, .gray.opacity(0.3), .white],
                                center: .center
                            )
                        )
                        .frame(width: 24, height: 24)
                } else {
                    Circle()
                        .fill(swatchColor(for: color))
                        .frame(width: 24, height: 24)
                }

                if isSelected {
                    Circle()
                        .stroke(DesignTokens.Colors.accent, lineWidth: 2)
                        .frame(width: 28, height: 28)

                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(color == .white || color == .lightGray || color == .clear ? .black : .white)
                }
            }
            .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .help(color.displayName)
    }

    private func automaticColorGradient(for color: WidgetAccentColor) -> LinearGradient {
        switch color {
        case .utilization:
            return LinearGradient(
                colors: [.green, .yellow, .orange, .red],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .pressure:
            return LinearGradient(
                colors: [.green, .yellow, .red],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .cluster:
            return LinearGradient(
                colors: [WidgetColorPalette.ClusterColor.eCores, WidgetColorPalette.ClusterColor.pCores],
                startPoint: .leading,
                endPoint: .trailing
            )
        default:
            return LinearGradient(
                colors: [swatchColor(for: color)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    private func swatchColor(for color: WidgetAccentColor) -> Color {
        if let nsColor = color.nsColor {
            return Color(nsColor: nsColor)
        }
        // Fallback for automatic colors
        return widgetAccentColor
    }

    private var widgetPreview: some View {
        HStack {
            Spacer()

            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: widgetType.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(previewColor)

                if config?.displayMode == .compact || config?.displayMode == .detailed {
                    Text(previewValue)
                        .font(DesignTokens.Typography.caption)
                        .monospacedDigit()
                }

                if config?.displayMode == .detailed {
                    sparklinePreview
                        .frame(width: 40, height: 12)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(DesignTokens.Colors.backgroundSecondary)
            .cornerRadius(DesignTokens.CornerRadius.small)

            Spacer()
        }
    }

    private var previewColor: Color {
        guard let config = config else {
            return widgetAccentColor
        }
        return config.accentColor.colorValue(for: widgetType)
    }

    private var previewValue: String {
        let usePercent = config?.valueFormat == .percentage
        switch widgetType {
        case .cpu: return usePercent ? "42%" : "4.2 GHz"
        case .memory: return usePercent ? "65%" : "13.0 GB"
        case .disk: return usePercent ? "78%" : "41 GB"
        case .network: return "12 MB/s"
        case .gpu: return usePercent ? "45%" : "1.2 GHz"
        case .battery: return usePercent ? "85%" : "3h 20m"
        case .weather: return "21°C"
        case .sensors: return "45°C"
        case .bluetooth: return usePercent ? "75%" : "2 devices"
        case .clock: return "12:00"
        }
    }

    private var sparklinePreview: some View {
        GeometryReader { geometry in
            Path { path in
                let data: [Double] = [30, 35, 32, 45, 42, 38, 44, 40, 42]
                let stepX = geometry.size.width / CGFloat(data.count - 1)
                let maxY = data.max() ?? 1
                let minY = data.min() ?? 0
                let range = max(maxY - minY, 0.1)

                for (index, value) in data.enumerated() {
                    let x = CGFloat(index) * stepX
                    let normalizedY = (value - minY) / range
                    let y = geometry.size.height * (1 - normalizedY)

                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(
                LinearGradient(
                    colors: [previewColor, previewColor.opacity(0.4)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                lineWidth: 1.2
            )
        }
    }

    // MARK: - Notification Settings

    /// Notification threshold settings for this widget
    private var widgetNotificationSettings: some View {
        let notificationManager = NotificationManager.shared
        let thresholds = notificationManager.config.thresholds(for: widgetType)
        let hasThresholds = notificationManager.config.hasThresholds(for: widgetType)

        return VStack(spacing: DesignTokens.Spacing.sm) {
            // Status row
            HStack {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
                    Text(hasThresholds ? "Notifications configured" : "No notifications")
                        .font(DesignTokens.Typography.subhead)
                        .foregroundColor(hasThresholds
                            ? DesignTokens.Colors.success
                            : DesignTokens.Colors.textSecondary)

                    if hasThresholds {
                        Text("\(thresholds.count) threshold(s) active")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(DesignTokens.Colors.textTertiary)
                    }
                }

                Spacer()

                // Quick toggle
                Button {
                    toggleQuickNotification()
                } label: {
                    Image(systemName: hasThresholds ? "bell.fill" : "bell")
                        .font(.system(size: 14))
                        .foregroundColor(hasThresholds
                            ? DesignTokens.Colors.success
                            : DesignTokens.Colors.textSecondary)
                }
                .buttonStyle(.plain)
                .help(hasThresholds ? "Disable notifications" : "Enable default notifications")
            }
            .padding(.vertical, DesignTokens.Spacing.xs)
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .background(DesignTokens.Colors.backgroundTertiary)
            .cornerRadius(DesignTokens.CornerRadius.small)

            // Quick threshold presets
            if !hasThresholds || thresholds.isEmpty {
                quickThresholdPresets
            }
        }
    }

    /// Quick threshold presets for common scenarios
    private var quickThresholdPresets: some View {
        VStack(spacing: DesignTokens.Spacing.xxxs) {
            Text("Quick presets")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: DesignTokens.Spacing.xxxs) {
                ForEach(presetThresholds(), id: \.label) { preset in
                    Button {
                        addPresetThreshold(preset)
                    } label: {
                        VStack(spacing: DesignTokens.Spacing.xxxs) {
                            Text(preset.label)
                                .font(DesignTokens.Typography.captionEmphasized)
                            Text(preset.detail)
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(DesignTokens.Colors.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignTokens.Spacing.xs)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                        .background(DesignTokens.Colors.backgroundTertiary)
                        .cornerRadius(DesignTokens.CornerRadius.small)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// Threshold presets for this widget type
    private func presetThresholds() -> [ThresholdPreset] {
        switch widgetType {
        case .cpu:
            return [
                ThresholdPreset(label: "High", detail: "> 80%", value: 80, condition: .greaterThanOrEqual),
                ThresholdPreset(label: "Critical", detail: "> 90%", value: 90, condition: .greaterThanOrEqual)
            ]
        case .memory:
            return [
                ThresholdPreset(label: "High", detail: "> 85%", value: 85, condition: .greaterThanOrEqual),
                ThresholdPreset(label: "Critical", detail: "> 95%", value: 95, condition: .greaterThanOrEqual)
            ]
        case .disk:
            return [
                ThresholdPreset(label: "Full", detail: "> 90%", value: 90, condition: .greaterThanOrEqual),
                ThresholdPreset(label: "Warning", detail: "> 80%", value: 80, condition: .greaterThanOrEqual)
            ]
        case .gpu:
            return [
                ThresholdPreset(label: "High", detail: "> 85%", value: 85, condition: .greaterThanOrEqual),
                ThresholdPreset(label: "Critical", detail: "> 95%", value: 95, condition: .greaterThanOrEqual)
            ]
        case .battery:
            return [
                ThresholdPreset(label: "Low", detail: "< 20%", value: 20, condition: .lessThanOrEqual),
                ThresholdPreset(label: "Critical", detail: "< 10%", value: 10, condition: .lessThanOrEqual)
            ]
        case .sensors:
            return [
                ThresholdPreset(label: "Hot", detail: "> 85°", value: 85, condition: .greaterThanOrEqual),
                ThresholdPreset(label: "Very Hot", detail: "> 95°", value: 95, condition: .greaterThanOrEqual)
            ]
        default:
            return []
        }
    }

    /// Add a preset threshold
    private func addPresetThreshold(_ preset: ThresholdPreset) {
        let threshold = NotificationThreshold(
            widgetType: widgetType,
            condition: preset.condition,
            value: preset.value,
            isEnabled: true
        )
        NotificationManager.shared.updateThreshold(threshold)
    }

    /// Toggle quick notification (adds default threshold or removes all)
    private func toggleQuickNotification() {
        let notificationManager = NotificationManager.shared
        let hasThresholds = notificationManager.config.hasThresholds(for: widgetType)

        if hasThresholds {
            // Remove all thresholds for this widget
            let thresholds = notificationManager.config.thresholds(for: widgetType)
            for threshold in thresholds {
                notificationManager.removeThreshold(id: threshold.id)
            }
        } else {
            // Add default threshold
            let defaults = NotificationThreshold.defaultThresholds(for: widgetType)
            if let defaultThreshold = defaults.first {
                var newThreshold = defaultThreshold
                newThreshold.isEnabled = true
                notificationManager.updateThreshold(newThreshold)
            }
        }
    }

    /// Helper struct for threshold presets
    private struct ThresholdPreset {
        let label: String
        let detail: String
        let value: Double
        let condition: NotificationCondition
    }

    private var widgetAccentColor: Color {
        switch widgetType {
        case .cpu: return Color(red: 0.37, green: 0.62, blue: 1.0)
        case .memory: return Color(red: 0.19, green: 0.82, blue: 0.35)
        case .disk: return Color(red: 1.0, green: 0.62, blue: 0.04)
        case .network: return Color(red: 0.39, green: 0.82, blue: 1.0)
        case .gpu: return Color(red: 0.75, green: 0.35, blue: 0.95)
        case .battery: return Color(red: 0.19, green: 0.82, blue: 0.35)
        case .weather: return Color(red: 1.0, green: 0.84, blue: 0.04)
        case .sensors: return Color(red: 1.0, green: 0.45, blue: 0.35)
        case .bluetooth: return Color(red: 0.0, green: 0.48, blue: 1.0)  // Bluetooth blue
        case .clock: return Color(red: 0.55, green: 0.35, blue: 0.95)  // Clock purple
        }
    }
}

// MARK: - Widget Type Drop Delegate

private struct WidgetTypeDropDelegate: DropDelegate {
    let currentType: WidgetType
    let draggedType: Binding<WidgetType?>
    let dropTargetType: Binding<WidgetType?>
    let onDrop: (WidgetType) -> Bool

    func performDrop(info: DropInfo) -> Bool {
        dropTargetType.wrappedValue = nil
        return onDrop(currentType)
    }

    func dropEntered(info: DropInfo) {
        if draggedType.wrappedValue != currentType {
            dropTargetType.wrappedValue = currentType
            // Trigger drop when dragging over another item
            if let dragged = draggedType.wrappedValue {
                _ = onDrop(dragged)
                draggedType.wrappedValue = currentType // Update to prevent multiple drops
            }
        }
    }

    func dropExited(info: DropInfo) {
        if dropTargetType.wrappedValue == currentType {
            dropTargetType.wrappedValue = nil
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
}

// MARK: - Available Widget Drop Delegate

private struct AvailableWidgetDropDelegate: DropDelegate {
    let currentType: WidgetType
    let draggedType: Binding<WidgetType?>
    let dropTargetType: Binding<WidgetType?>
    let onDrop: (WidgetType) -> Bool

    func performDrop(info: DropInfo) -> Bool {
        dropTargetType.wrappedValue = nil
        return onDrop(currentType)
    }

    func dropEntered(info: DropInfo) {
        if draggedType.wrappedValue != currentType {
            dropTargetType.wrappedValue = currentType
        }
    }

    func dropExited(info: DropInfo) {
        if dropTargetType.wrappedValue == currentType {
            dropTargetType.wrappedValue = nil
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .copy)
    }
}

// MARK: - Widget Preferences Extension

extension WidgetPreferences {
    /// Reorder widgets by moving one type to another's position
    func reorderWidgets(move typeToMove: WidgetType, to targetType: WidgetType) {
        guard let fromIndex = widgetConfigs.firstIndex(where: { $0.type == typeToMove }),
              let toIndex = widgetConfigs.firstIndex(where: { $0.type == targetType }),
              typeToMove != targetType else {
            return
        }

        // Remove from current position
        let movedConfig = widgetConfigs[fromIndex]
        widgetConfigs.remove(at: fromIndex)

        // Calculate adjusted insertion index
        // When removing from an earlier index, the target index shifts by -1
        var adjustedToIndex = toIndex
        if fromIndex < toIndex {
            adjustedToIndex = toIndex - 1
        }

        // Insert at new position
        widgetConfigs.insert(movedConfig, at: adjustedToIndex)

        // Update all positions
        for (index, _) in widgetConfigs.enumerated() {
            widgetConfigs[index].position = index
        }

        saveConfigs()

        // Broadcast change for reactive updates
        Task { @MainActor in
            NotificationCenter.default.post(
                name: .widgetConfigurationDidUpdate,
                object: nil,
                userInfo: ["widgetType": "reorder"] // Special marker for reorder
            )
        }
    }
}

// MARK: - Preview

#Preview("Widget Customization") {
    WidgetCustomizationView()
        .frame(width: 960, height: 700)
}
