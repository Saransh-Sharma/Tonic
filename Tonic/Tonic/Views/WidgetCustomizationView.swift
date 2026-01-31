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

    init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header with title and action buttons
            headerSection

            ScrollView {
                VStack(spacing: DesignTokens.Spacing.lg) {
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
            .onDrag {
                draggedWidget = config.type
                return NSItemProvider(object: config.type.rawValue as NSString)
            }
            .onDrop(of: [.text], delegate: WidgetDropDelegate(
                currentType: config.type,
                widgets: preferences.enabledWidgets,
                onDrop: { _ in
                    guard let draggedType = draggedWidget else { return false }
                    preferences.reorderWidgets(move: draggedType, to: config.type)
                    draggedWidget = nil
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
        let availableTypes = WidgetType.allCases.filter { type in
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
                    }
                    .padding(.vertical, DesignTokens.Spacing.lg)
                    Spacer()
                }
                .background(DesignTokens.Colors.backgroundSecondary)
                .cornerRadius(DesignTokens.CornerRadius.medium)
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
            .onTapGesture {
                withAnimation(DesignTokens.Animation.fast) {
                    toggleWidget(type)
                }
            }
            .onDrag {
                draggedWidget = type
                return NSItemProvider(object: type.rawValue as NSString)
            }
            .onDrop(of: [.text], isTargeted: nil) { _ in
                guard let draggedType = draggedWidget else { return false }
                if preferences.config(for: draggedType)?.isEnabled == false {
                    withAnimation(DesignTokens.Animation.fast) {
                        preferences.setWidgetEnabled(type: draggedType, enabled: true)
                    }
                }
                draggedWidget = nil
                return true
            }

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
        }
    }
}

// MARK: - Widget Settings Sheet

struct WidgetSettingsSheet: View {
    let widgetType: WidgetType
    @Bindable var preferences: WidgetPreferences
    @Environment(\.dismiss) private var dismiss

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
                        PreferenceSection(header: "Display Mode") {
                            displayModeSelector
                        }

                        PreferenceSection(header: "Value Format") {
                            valueFormatSelector
                        }

                        PreferenceSection(header: "Update Frequency") {
                            updateFrequencySelector
                        }

                        PreferenceSection(header: "Widget Color") {
                            colorSelector
                        }

                        PreferenceSection(header: "Notifications") {
                            widgetNotificationSettings
                        }

                        PreferenceSection(header: "Preview") {
                            widgetPreview
                        }
                    }
                }
                .padding(DesignTokens.Spacing.lg)
            }

            Divider()

            // Footer
            HStack(spacing: DesignTokens.Spacing.md) {
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

                Spacer()

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
        .frame(width: 400, height: 600)
        .background(DesignTokens.Colors.background)
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
        HStack(spacing: DesignTokens.Spacing.xs) {
            ForEach(WidgetAccentColor.allCases) { color in
                colorButton(color)
            }
        }
    }

    private func colorButton(_ color: WidgetAccentColor) -> some View {
        let isSelected = config?.accentColor == color

        return Button {
            withAnimation(DesignTokens.Animation.fast) {
                preferences.setWidgetColor(type: widgetType, color: color)
            }
        } label: {
            VStack(spacing: DesignTokens.Spacing.xs) {
                Circle()
                    .fill(swatchColor(for: color))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Circle()
                            .stroke(isSelected ? DesignTokens.Colors.accent : Color.clear, lineWidth: 2)
                    )
                    .overlay(
                        Image(systemName: isSelected ? "checkmark" : "")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(isSelected ? DesignTokens.Colors.accent : .white)
                    )

                Text(color.displayName)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(isSelected ? DesignTokens.Colors.textPrimary : DesignTokens.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func swatchColor(for color: WidgetAccentColor) -> Color {
        switch color {
        case .system:
            return widgetAccentColor
        case .blue: return Color(red: 0.37, green: 0.62, blue: 1.0)
        case .green: return Color(red: 0.19, green: 0.82, blue: 0.35)
        case .orange: return Color(red: 1.0, green: 0.62, blue: 0.04)
        case .purple: return Color(red: 0.75, green: 0.35, blue: 0.95)
        case .yellow: return Color(red: 1.0, green: 0.84, blue: 0.04)
        }
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
        }
    }
}

// MARK: - Widget Drop Delegate

private struct WidgetDropDelegate: DropDelegate {
    let currentType: WidgetType
    let widgets: [WidgetConfiguration]
    let onDrop: (WidgetType) -> Bool

    func performDrop(info: DropInfo) -> Bool {
        return onDrop(currentType)
    }

    func dropEntered(info: DropInfo) {
        // Visual feedback handled by hover state
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

        // Insert at new position
        widgetConfigs.insert(movedConfig, at: toIndex)

        // Update all positions
        for (index, _) in widgetConfigs.enumerated() {
            widgetConfigs[index].position = index
        }

        saveConfigs()
    }
}

// MARK: - Preview

#Preview("Widget Customization") {
    WidgetCustomizationView()
        .frame(width: 960, height: 700)
}
