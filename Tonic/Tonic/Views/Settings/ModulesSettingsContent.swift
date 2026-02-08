//
//  ModulesSettingsContent.swift
//  Tonic
//
//  Per-module settings for Stats Master-style configuration
//  Task ID: fn-6-i4g.33
//
//  Provides per-module settings similar to Stats Master's settings window
//  with split layout showing module list | module configuration
//

import SwiftUI

// MARK: - Modules Settings Content

/// Main container for module settings with split layout
struct ModulesSettingsContent: View {
    @State private var selectedModule: WidgetType = .cpu
    @State private var preferences = WidgetPreferences.shared

    var body: some View {
        HStack(spacing: 0) {
            // Module list sidebar
            moduleListSidebar
                .frame(width: 180)

            Divider()

            // Module-specific settings
            moduleSettingsDetail
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedModule)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.Colors.background)
        .onReceive(NotificationCenter.default.publisher(for: .openModuleSettings)) { notification in
            guard let rawModule = notification.userInfo?[SettingsDeepLinkUserInfoKey.module] as? String,
                  let module = WidgetType(rawValue: rawModule),
                  WidgetType.parityCases.contains(module) else {
                return
            }

            selectedModule = module
        }
    }

    // MARK: - Module List Sidebar

    private var moduleListSidebar: some View {
        VStack(spacing: 0) {
            // Sidebar header
            Text("Widgets")
                .font(DesignTokens.Typography.subheadEmphasized)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .padding(.horizontal, DesignTokens.Spacing.sm)
                .padding(.vertical, DesignTokens.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            // Module list
            ScrollView {
                VStack(spacing: DesignTokens.Spacing.xxxs) {
                    ForEach(WidgetType.parityCases) { module in
                        Button {
                            selectedModule = module
                        } label: {
                            ModuleListItem(
                                module: module,
                                isEnabled: preferences.config(for: module)?.isEnabled ?? false,
                                isSelected: selectedModule == module
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, DesignTokens.Spacing.xs)
            }
            .scrollContentBackground(.hidden)
            .background(DesignTokens.Colors.backgroundSecondary.opacity(0.5))
        }
    }

    // MARK: - Module Settings Detail

    @ViewBuilder
    private var moduleSettingsDetail: some View {
        if let config = preferences.config(for: selectedModule) {
            ScrollView {
                ModuleSettingsDetailView(
                    module: selectedModule,
                    config: config,
                    preferences: preferences
                )
                .id(selectedModule) // Force view refresh on module change
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        } else {
            Text("Select a module to configure")
                .foregroundColor(DesignTokens.Colors.textSecondary)
        }
    }
}

// MARK: - Module List Item

/// Single item in the module list with icon, name, and enabled indicator
struct ModuleListItem: View {
    let module: WidgetType
    let isEnabled: Bool
    let isSelected: Bool

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            // Module icon
            Image(systemName: module.icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isEnabled ? moduleAccentColor : DesignTokens.Colors.textTertiary)
                .frame(width: 24)

            // Module name
            Text(module.displayName)
                .font(DesignTokens.Typography.body)
                .foregroundColor(isEnabled ? DesignTokens.Colors.textPrimary : DesignTokens.Colors.textSecondary)

            Spacer()

            // Enabled indicator
            Circle()
                .fill(isEnabled ? DesignTokens.Colors.success : Color.clear)
                .frame(width: 6, height: 6)
        }
        .padding(.vertical, DesignTokens.Spacing.sm)
        .padding(.horizontal, DesignTokens.Spacing.md)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.small)
                .fill(isSelected ? DesignTokens.Colors.accent.opacity(0.15) : Color.clear)
        )
    }

    private var moduleAccentColor: Color {
        switch module {
        case .cpu: return Color(red: 0.37, green: 0.62, blue: 1.0)
        case .memory: return Color(red: 0.19, green: 0.82, blue: 0.35)
        case .disk: return Color(red: 1.0, green: 0.62, blue: 0.04)
        case .network: return Color(red: 0.39, green: 0.82, blue: 1.0)
        case .gpu: return Color(red: 0.75, green: 0.35, blue: 0.95)
        case .battery: return Color(red: 0.19, green: 0.82, blue: 0.35)
        case .weather: return Color(red: 1.0, green: 0.84, blue: 0.04)
        case .sensors: return Color(red: 1.0, green: 0.45, blue: 0.35)
        case .bluetooth: return Color(red: 0.0, green: 0.48, blue: 1.0)
        case .clock: return Color(red: 0.55, green: 0.35, blue: 0.95)
        }
    }
}

// MARK: - Module Settings Detail View

/// Detailed settings for a single module
struct ModuleSettingsDetailView: View {
    let module: WidgetType
    let config: WidgetConfiguration
    let preferences: WidgetPreferences
    @State var widgetDataManager = WidgetDataManager.shared
    @State var clockPreferences = ClockPreferences.shared

    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.lg) {
                // Module header
                moduleHeader

                PreferenceList {
                    // Enabled section
                    enabledSection

                    // Visualization section
                    if module.supportsCharts {
                        visualizationSection
                    }

                    // Display mode section
                    displayModeSection

                    // Value format section (if applicable)
                    if supportsValueFormat {
                        valueFormatSection
                    }

                    // Update interval section
                    updateIntervalSection

                    // Stats Master settings.swift parity controls
                    parityModuleSettingsSection

                    // Color section
                    colorSection

                    // Label section
                    labelSection

                    // Notifications section (if applicable)
                    if supportsNotifications {
                        notificationsSection
                    }

                    // Preview section
                    previewSection
                }
            }
            .padding(DesignTokens.Spacing.lg)
        }
    }

    // MARK: - Module Header

    private var moduleHeader: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            // Icon with gradient background
            ZStack {
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium)
                    .fill(.linearGradient(
                        colors: [moduleColor.opacity(0.8), moduleColor.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 48, height: 48)

                Image(systemName: module.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
                Text(module.displayName)
                    .font(DesignTokens.Typography.h3)
                    .foregroundColor(DesignTokens.Colors.textPrimary)

                Text(moduleDescription)
                    .font(DesignTokens.Typography.body)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }

            Spacer()
        }
        .padding(.bottom, DesignTokens.Spacing.xs)
    }

    private var moduleColor: Color {
        switch module {
        case .cpu: return Color(red: 0.37, green: 0.62, blue: 1.0)
        case .memory: return Color(red: 0.19, green: 0.82, blue: 0.35)
        case .disk: return Color(red: 1.0, green: 0.62, blue: 0.04)
        case .network: return Color(red: 0.39, green: 0.82, blue: 1.0)
        case .gpu: return Color(red: 0.75, green: 0.35, blue: 0.95)
        case .battery: return Color(red: 0.19, green: 0.82, blue: 0.35)
        case .weather: return Color(red: 1.0, green: 0.84, blue: 0.04)
        case .sensors: return Color(red: 1.0, green: 0.45, blue: 0.35)
        case .bluetooth: return Color(red: 0.0, green: 0.48, blue: 1.0)
        case .clock: return Color(red: 0.55, green: 0.35, blue: 0.95)
        }
    }

    private var moduleDescription: String {
        switch module {
        case .cpu: return "Processor usage and core activity"
        case .memory: return "RAM usage and memory pressure"
        case .disk: return "Storage space and disk activity"
        case .network: return "Network bandwidth and connectivity"
        case .gpu: return "Graphics processing utilization"
        case .battery: return "Battery status and power consumption"
        case .weather: return "Local weather conditions"
        case .sensors: return "Temperature and fan sensors"
        case .bluetooth: return "Bluetooth device battery levels"
        case .clock: return "Current time display"
        }
    }

    // MARK: - Enabled Section

    private var enabledSection: some View {
        PreferenceSection(header: "Status") {
            PreferenceToggleRow(
                title: "Show in menu bar",
                subtitle: "Display this widget in the menu bar",
                icon: module.icon,
                iconColor: moduleColor,
                showDivider: false,
                isOn: Binding(
                    get: { config.isEnabled },
                    set: { newValue in
                        withAnimation(DesignTokens.Animation.fast) {
                            preferences.setWidgetEnabled(type: module, enabled: newValue)
                        }
                    }
                )
            )
        }
    }

    // MARK: - Visualization Section

    private var visualizationSection: some View {
        PreferenceSection(header: "Visualization") {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text("Choose how this widget displays data")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textTertiary)

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: DesignTokens.Spacing.xs), count: 4),
                    spacing: DesignTokens.Spacing.xs
                ) {
                    ForEach(module.compatibleVisualizations) { visualization in
                        visualizationButton(visualization)
                    }
                }
            }
            .padding(.vertical, DesignTokens.Spacing.sm)
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .background(DesignTokens.Colors.backgroundTertiary)
            .cornerRadius(DesignTokens.CornerRadius.small)
        }
    }

    private func visualizationButton(_ visualization: VisualizationType) -> some View {
        let isSelected = config.visualizationType == visualization

        return Button {
            withAnimation(DesignTokens.Animation.fast) {
                preferences.setWidgetVisualization(type: module, visualization: visualization)
            }
        } label: {
            VStack(spacing: DesignTokens.Spacing.xxxs) {
                Image(systemName: visualization.icon)
                    .font(.system(size: 14, weight: .semibold))

                Text(visualization.shortName)
                    .font(DesignTokens.Typography.caption)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .foregroundColor(isSelected ? .white : DesignTokens.Colors.textSecondary)
            .background(isSelected ? moduleColor : DesignTokens.Colors.backgroundSecondary)
            .cornerRadius(DesignTokens.CornerRadius.small)
        }
        .buttonStyle(.plain)
        .help(visualization.description)
    }

    // MARK: - Display Mode Section

    private var displayModeSection: some View {
        PreferenceSection(header: "Display Mode") {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text("Choose how much detail to show")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textTertiary)

                HStack(spacing: DesignTokens.Spacing.xs) {
                    ForEach(WidgetDisplayMode.allCases) { mode in
                        displayModeButton(mode)
                    }
                }
            }
            .padding(.vertical, DesignTokens.Spacing.sm)
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .background(DesignTokens.Colors.backgroundTertiary)
            .cornerRadius(DesignTokens.CornerRadius.small)
        }
    }

    private func displayModeButton(_ mode: WidgetDisplayMode) -> some View {
        let isSelected = config.displayMode == mode

        return Button {
            withAnimation(DesignTokens.Animation.fast) {
                preferences.setWidgetDisplayMode(type: module, mode: mode)
            }
        } label: {
            VStack(spacing: DesignTokens.Spacing.xxxs) {
                Image(systemName: iconForDisplayMode(mode))
                    .font(.system(size: 14, weight: .semibold))

                Text(mode.shortLabel)
                    .font(DesignTokens.Typography.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .foregroundColor(isSelected ? .white : DesignTokens.Colors.textSecondary)
            .background(isSelected ? moduleColor : DesignTokens.Colors.backgroundSecondary)
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

    // MARK: - Value Format Section

    private var valueFormatSection: some View {
        PreferenceSection(header: "Value Format") {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text("Choose how values are displayed")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textTertiary)

                HStack(spacing: DesignTokens.Spacing.xs) {
                    ForEach(WidgetValueFormat.allCases) { format in
                        valueFormatButton(format)
                    }
                }
            }
            .padding(.vertical, DesignTokens.Spacing.sm)
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .background(DesignTokens.Colors.backgroundTertiary)
            .cornerRadius(DesignTokens.CornerRadius.small)
        }
    }

    private func valueFormatButton(_ format: WidgetValueFormat) -> some View {
        let isSelected = config.valueFormat == format

        return Button {
            withAnimation(DesignTokens.Animation.fast) {
                preferences.setWidgetValueFormat(type: module, format: format)
            }
        } label: {
            VStack(spacing: DesignTokens.Spacing.xxxs) {
                Text(exampleValueForFormat(format))
                    .font(DesignTokens.Typography.captionEmphasized)
                    .monospacedDigit()

                Text(format.shortLabel)
                    .font(DesignTokens.Typography.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .foregroundColor(isSelected ? .white : DesignTokens.Colors.textSecondary)
            .background(isSelected ? moduleColor : DesignTokens.Colors.backgroundSecondary)
            .cornerRadius(DesignTokens.CornerRadius.small)
        }
        .buttonStyle(.plain)
    }

    private func exampleValueForFormat(_ format: WidgetValueFormat) -> String {
        switch format {
        case .percentage:
            switch module {
            case .cpu: return "42%"
            case .memory: return "65%"
            case .disk: return "78%"
            case .gpu: return "45%"
            case .battery: return "85%"
            default: return "50%"
            }
        case .valueWithUnit:
            switch module {
            case .cpu: return "4.2 GHz"
            case .memory: return "13.0 GB"
            case .disk: return "41 GB"
            case .network: return "12 MB/s"
            case .gpu: return "1.2 GHz"
            case .battery: return "3h 20m"
            case .weather: return "21°C"
            case .sensors: return "45°C"
            case .bluetooth: return "2"
            case .clock: return "12:00"
            }
        }
    }

    // MARK: - Update Interval Section

    private var updateIntervalSection: some View {
        PreferenceSection(header: "Update Frequency") {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text("How often to refresh data")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textTertiary)

                HStack(spacing: DesignTokens.Spacing.xs) {
                    ForEach(WidgetUpdateInterval.allCases) { interval in
                        intervalButton(interval)
                    }
                }
            }
            .padding(.vertical, DesignTokens.Spacing.sm)
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .background(DesignTokens.Colors.backgroundTertiary)
            .cornerRadius(DesignTokens.CornerRadius.small)
        }
    }

    private func intervalButton(_ interval: WidgetUpdateInterval) -> some View {
        let isSelected = config.refreshInterval == interval

        return Button {
            withAnimation(DesignTokens.Animation.fast) {
                preferences.setWidgetRefreshInterval(type: module, interval: interval)
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
            .background(isSelected ? moduleColor : DesignTokens.Colors.backgroundSecondary)
            .cornerRadius(DesignTokens.CornerRadius.small)
        }
        .buttonStyle(.plain)
    }

    private func intervalLabel(_ interval: WidgetUpdateInterval) -> String {
        switch interval {
        case .power: return "Eco"
        case .balanced: return "Bal"
        case .performance: return "Fast"
        }
    }

    // MARK: - Color Section

    private var colorSection: some View {
        PreferenceSection(header: "Widget Color") {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                // Automatic colors
                colorCategoryRow(title: "Automatic", colors: WidgetAccentColor.automaticColors)

                // System colors
                colorCategoryRow(title: "System", colors: WidgetAccentColor.systemColors)

                // Primary colors (first row)
                colorCategoryRow(title: "Primary", colors: Array(WidgetAccentColor.primaryColors.prefix(8)))

                // Primary colors (second row)
                colorCategoryRow(title: "", colors: Array(WidgetAccentColor.primaryColors.dropFirst(8)))

                // Secondary colors
                colorCategoryRow(title: "Secondary", colors: WidgetAccentColor.secondaryColors)

                // Grays
                colorCategoryRow(title: "Grays", colors: WidgetAccentColor.grayColors)
            }
        }
    }

    private func colorCategoryRow(title: String, colors: [WidgetAccentColor]) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
            if !title.isEmpty {
                Text(title)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(26), spacing: DesignTokens.Spacing.xs), count: 10),
                spacing: DesignTokens.Spacing.xs
            ) {
                ForEach(colors) { color in
                    colorSwatchButton(color)
                }
            }
        }
    }

    private func colorSwatchButton(_ color: WidgetAccentColor) -> some View {
        let isSelected = config.accentColor == color

        return Button {
            withAnimation(DesignTokens.Animation.fast) {
                preferences.setWidgetColor(type: module, color: color)
            }
        } label: {
            ZStack {
                if color.isAutomatic {
                    Circle()
                        .fill(automaticColorGradient(for: color))
                        .frame(width: 22, height: 22)
                } else if color == .clear {
                    Circle()
                        .fill(
                            AngularGradient(
                                colors: [.white, .gray.opacity(0.3), .white],
                                center: .center
                            )
                        )
                        .frame(width: 22, height: 22)
                } else if let nsColor = color.nsColor {
                    Circle()
                        .fill(Color(nsColor: nsColor))
                        .frame(width: 22, height: 22)
                } else {
                    Circle()
                        .fill(moduleColor)
                        .frame(width: 22, height: 22)
                }

                if isSelected {
                    Circle()
                        .stroke(DesignTokens.Colors.accent, lineWidth: 2)
                        .frame(width: 26, height: 26)

                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(color == .white || color == .lightGray ? .black : .white)
                }
            }
            .frame(width: 26, height: 26)
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
                colors: [Color(red: 0.3, green: 0.8, blue: 1.0), Color(red: 1.0, green: 0.45, blue: 0.35)],
                startPoint: .leading,
                endPoint: .trailing
            )
        default:
            return LinearGradient(
                colors: [moduleColor],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    // MARK: - Label Section

    private var labelSection: some View {
        PreferenceSection(header: "Label") {
            PreferenceToggleRow(
                title: "Show widget label",
                subtitle: "Display widget name in menu bar",
                icon: "textformat",
                iconColor: DesignTokens.Colors.textSecondary,
                showDivider: false,
                isOn: Binding(
                    get: { config.showLabel },
                    set: { newValue in
                        withAnimation(DesignTokens.Animation.fast) {
                            preferences.setWidgetShowLabel(type: module, show: newValue)
                        }
                    }
                )
            )
        }
    }

    // MARK: - Notifications Section

    private var notificationsSection: some View {
        let notificationManager = NotificationManager.shared
        let thresholds = notificationManager.config.enabledThresholds(for: module)
        let hasThresholds = !thresholds.isEmpty

        return PreferenceSection(header: "Notifications") {
            VStack(spacing: DesignTokens.Spacing.sm) {
                // Status row
                HStack {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
                        Text(hasThresholds ? "Notifications enabled" : "Notifications disabled")
                            .font(DesignTokens.Typography.subhead)
                            .foregroundColor(hasThresholds
                                ? DesignTokens.Colors.success
                                : DesignTokens.Colors.textSecondary)

                        if hasThresholds {
                            Text("\(thresholds.count) threshold(s) configured")
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(DesignTokens.Colors.textTertiary)
                        }
                    }

                    Spacer()

                    // Quick enable/disable toggle
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
                }
                .padding(.vertical, DesignTokens.Spacing.xs)
                .padding(.horizontal, DesignTokens.Spacing.sm)
                .background(DesignTokens.Colors.backgroundTertiary)
                .cornerRadius(DesignTokens.CornerRadius.small)

                // Quick presets if no thresholds configured
                if !hasThresholds || thresholds.isEmpty {
                    quickThresholdPresets
                }
            }
        }
    }

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

    private func presetThresholds() -> [ThresholdPreset] {
        switch module {
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

    private func addPresetThreshold(_ preset: ThresholdPreset) {
        let threshold = NotificationThreshold(
            widgetType: module,
            condition: preset.condition,
            value: preset.value,
            isEnabled: true
        )
        NotificationManager.shared.updateThreshold(threshold)
    }

    private func toggleQuickNotification() {
        let notificationManager = NotificationManager.shared
        let hasThresholds = notificationManager.config.hasThresholds(for: module)

        if hasThresholds {
            // Remove all thresholds for this widget
            let thresholds = notificationManager.config.thresholds(for: module)
            for threshold in thresholds {
                notificationManager.removeThreshold(id: threshold.id)
            }
        } else {
            // Add default threshold
            let defaults = NotificationThreshold.defaultThresholds(for: module)
            if let defaultThreshold = defaults.first {
                var newThreshold = defaultThreshold
                newThreshold.isEnabled = true
                notificationManager.updateThreshold(newThreshold)
            }
        }
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        PreferenceSection(header: "Preview") {
            VStack(spacing: DesignTokens.Spacing.xs) {
                Text("Menu bar appearance")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack {
                    Spacer()

                    HStack(spacing: DesignTokens.Spacing.xs) {
                        Image(systemName: module.icon)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(config.accentColor.colorValue(for: module))

                        if config.showLabel {
                            Text(module.displayName)
                                .font(.system(size: 11, weight: .medium))
                        }

                        if config.displayMode == .compact || config.displayMode == .detailed {
                            Text(previewValue)
                                .font(.system(size: 11, weight: .medium).monospacedDigit())
                                .foregroundColor(DesignTokens.Colors.textPrimary)
                        }

                        if config.displayMode == .detailed {
                            miniSparkline
                                .frame(width: 32, height: 10)
                        }
                    }
                    .padding(.horizontal, DesignTokens.Spacing.sm)
                    .padding(.vertical, DesignTokens.Spacing.xs)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(DesignTokens.CornerRadius.small)

                    Spacer()
                }
            }
            .padding(.vertical, DesignTokens.Spacing.sm)
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .background(DesignTokens.Colors.backgroundTertiary)
            .cornerRadius(DesignTokens.CornerRadius.small)
        }
    }

    private var previewValue: String {
        let usePercent = config.valueFormat == .percentage
        let dataManager = WidgetDataManager.shared

        switch module {
        case .cpu:
            return "\(Int(dataManager.cpuData.totalUsage))%"
        case .memory:
            if usePercent {
                return "\(Int(dataManager.memoryData.usagePercentage))%"
            } else {
                let usedGB = Double(dataManager.memoryData.usedBytes) / (1024 * 1024 * 1024)
                return String(format: "%.1fGB", usedGB)
            }
        case .disk:
            if let primary = dataManager.diskVolumes.first {
                return usePercent ? "\(Int(primary.usagePercentage))%" : "\(primary.freeBytes / (1024*1024*1024))GB"
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
            return "21°"
        case .sensors:
            return "45°"
        case .bluetooth:
            return "2"
        case .clock:
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: Date())
        }
    }

    private var miniSparkline: some View {
        GeometryReader { geometry in
            Path { path in
                let data: [Double] = [30, 35, 32, 45, 42, 38, 44, 40]
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
                config.accentColor.colorValue(for: module),
                lineWidth: 1.2
            )
        }
    }

    // MARK: - Module Settings Section

    @ViewBuilder
    private var parityModuleSettingsSection: some View {
        PreferenceSection(header: "Module Settings") {
            VStack(spacing: 0) {
                switch module {
                case .cpu:
                    cpuSettingsRows
                case .memory:
                    memorySettingsRows
                case .disk:
                    diskSettingsRows
                case .network:
                    networkSettingsRows
                case .gpu:
                    gpuSettingsRows
                case .battery:
                    batterySettingsRows
                case .sensors:
                    sensorsSettingsRows
                case .bluetooth:
                    bluetoothSettingsRows
                case .clock:
                    clockSettingsRows
                case .weather:
                    EmptyView()
                }
            }
        }
    }

    // MARK: - CPU Settings

    @ViewBuilder
    private var cpuSettingsRows: some View {
        moduleToggleRow(
            title: "Show E/P Cores",
            subtitle: "Display efficiency and performance cores separately",
            icon: "cpu",
            isOn: moduleBinding(\.cpu.showEPCores, set: { $0.cpu.showEPCores = $1 })
        )

        moduleDivider

        moduleToggleRow(
            title: "Show Frequency",
            subtitle: "Display CPU frequency in MHz",
            icon: "gauge",
            isOn: moduleBinding(\.cpu.showFrequency, set: { $0.cpu.showFrequency = $1 })
        )

        moduleDivider

        moduleToggleRow(
            title: "Show Temperature",
            subtitle: "Display CPU temperature in popover",
            icon: "thermometer",
            iconColor: DesignTokens.Colors.warning,
            isOn: moduleBinding(\.cpu.showTemperature, set: { $0.cpu.showTemperature = $1 })
        )

        moduleDivider

        moduleToggleRow(
            title: "Show Load Average",
            subtitle: "Display 1/5/15 minute load averages",
            icon: "chart.line.uptrend.xyaxis",
            isOn: moduleBinding(\.cpu.showLoadAverage, set: { $0.cpu.showLoadAverage = $1 })
        )

        moduleDivider

        topProcessCountRow(
            current: config.moduleSettings.cpu.topProcessCount,
            set: { count in updateModuleSettings { $0.cpu.topProcessCount = count } }
        )
    }

    // MARK: - Memory Settings

    @ViewBuilder
    private var memorySettingsRows: some View {
        moduleToggleRow(
            title: "Show Swap",
            subtitle: "Display swap memory usage",
            icon: "arrow.triangle.swap",
            isOn: moduleBinding(\.memory.showSwap, set: { $0.memory.showSwap = $1 })
        )

        moduleDivider

        moduleToggleRow(
            title: "Show Compressed",
            subtitle: "Display compressed memory in breakdown",
            icon: "arrow.down.right.and.arrow.up.left",
            isOn: moduleBinding(\.memory.showCompressed, set: { $0.memory.showCompressed = $1 })
        )

        moduleDivider

        moduleToggleRow(
            title: "Pressure Gauge",
            subtitle: "Show memory pressure gauge in popover",
            icon: "gauge.with.needle",
            isOn: moduleBinding(\.memory.pressureGauge, set: { $0.memory.pressureGauge = $1 })
        )

        moduleDivider

        topProcessCountRow(
            current: config.moduleSettings.memory.topProcessCount,
            set: { count in updateModuleSettings { $0.memory.topProcessCount = count } }
        )
    }

    // MARK: - Disk Settings

    @ViewBuilder
    private var diskSettingsRows: some View {
        PreferenceRow(
            title: "Volume",
            subtitle: "Select which disk volume to monitor",
            icon: "internaldrive",
            iconColor: DesignTokens.Colors.accent,
            showDivider: false
        ) {
            Menu {
                Button("Auto") {
                    updateModuleSettings { $0.disk.selectedVolume = "Auto" }
                }
                Divider()
                ForEach(widgetDataManager.diskVolumes, id: \.name) { volume in
                    Button(action: {
                        updateModuleSettings { $0.disk.selectedVolume = volume.name }
                    }) {
                        HStack {
                            Text(volume.name)
                            if config.moduleSettings.disk.selectedVolume == volume.name {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Text(config.moduleSettings.disk.selectedVolume)
                        .font(DesignTokens.Typography.subhead)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                }
                .foregroundColor(DesignTokens.Colors.textPrimary)
            }
            .menuStyle(.borderlessButton)
        }

        moduleDivider

        moduleToggleRow(
            title: "Show SMART Status",
            subtitle: "Display SMART health information",
            icon: "checkmark.seal",
            iconColor: DesignTokens.Colors.success,
            isOn: moduleBinding(\.disk.showSMART, set: { $0.disk.showSMART = $1 })
        )
    }

    // MARK: - Network Settings

    @ViewBuilder
    private var networkSettingsRows: some View {
        moduleToggleRow(
            title: "Show Public IP",
            subtitle: "Display public IP address in popover",
            icon: "globe",
            isOn: moduleBinding(\.network.showPublicIP, set: { $0.network.showPublicIP = $1 })
        )

        moduleDivider

        moduleToggleRow(
            title: "Show WiFi Details",
            subtitle: "Display SSID, signal strength, and channel",
            icon: "wifi",
            isOn: moduleBinding(\.network.showWiFiDetails, set: { $0.network.showWiFiDetails = $1 })
        )

        moduleDivider

        moduleToggleRow(
            title: "Show DNS",
            subtitle: "Display DNS server information",
            icon: "server.rack",
            isOn: moduleBinding(\.network.showDNS, set: { $0.network.showDNS = $1 })
        )
    }

    // MARK: - GPU Settings

    @ViewBuilder
    private var gpuSettingsRows: some View {
        moduleToggleRow(
            title: "Show Render/Tiler",
            subtitle: "Display render and tiler utilization",
            icon: "square.stack.3d.up",
            isOn: moduleBinding(\.gpu.showRenderTiler, set: { $0.gpu.showRenderTiler = $1 })
        )

        moduleDivider

        moduleToggleRow(
            title: "Show Memory",
            subtitle: "Display GPU memory allocation",
            icon: "memorychip",
            isOn: moduleBinding(\.gpu.showMemory, set: { $0.gpu.showMemory = $1 })
        )
    }

    // MARK: - Battery Settings

    @ViewBuilder
    private var batterySettingsRows: some View {
        moduleToggleRow(
            title: "Show Adapter Details",
            subtitle: "Display power adapter information",
            icon: "powerplug",
            isOn: moduleBinding(\.battery.showAdapterDetails, set: { $0.battery.showAdapterDetails = $1 })
        )

        moduleDivider

        moduleToggleRow(
            title: "Show Electrical Metrics",
            subtitle: "Display amperage, voltage, and wattage",
            icon: "bolt",
            iconColor: DesignTokens.Colors.warning,
            isOn: moduleBinding(\.battery.showElectricalMetrics, set: { $0.battery.showElectricalMetrics = $1 })
        )
    }

    // MARK: - Sensors Settings

    @ViewBuilder
    private var sensorsSettingsRows: some View {
        moduleToggleRow(
            title: "Show Fan Control",
            subtitle: "Display fan speed controls in popover",
            icon: "fan",
            isOn: moduleBinding(\.sensors.showFanSpeeds, set: { $0.sensors.showFanSpeeds = $1 })
        )

        moduleDivider

        moduleToggleRow(
            title: "Show Voltages",
            subtitle: "Display voltage sensor readings",
            icon: "bolt.circle",
            isOn: moduleBinding(\.sensors.showVoltages, set: { $0.sensors.showVoltages = $1 })
        )

        moduleDivider

        moduleToggleRow(
            title: "Show Power",
            subtitle: "Display power consumption readings",
            icon: "bolt.fill",
            iconColor: DesignTokens.Colors.warning,
            isOn: moduleBinding(\.sensors.showPower, set: { $0.sensors.showPower = $1 })
        )
    }

    // MARK: - Bluetooth Settings

    @ViewBuilder
    private var bluetoothSettingsRows: some View {
        moduleToggleRow(
            title: "Show Signal Strength",
            subtitle: "Display Bluetooth signal strength for devices",
            icon: "antenna.radiowaves.left.and.right",
            isOn: moduleBinding(\.bluetooth.showSignalStrength, set: { $0.bluetooth.showSignalStrength = $1 })
        )
    }

    // MARK: - Clock Settings

    @ViewBuilder
    private var clockSettingsRows: some View {
        PreferenceToggleRow(
            title: "Show Seconds",
            subtitle: "Display seconds in time",
            icon: "clock.badge",
            iconColor: DesignTokens.Colors.accent,
            showDivider: false,
            isOn: Binding(
                get: { clockPreferences.showSeconds },
                set: { newValue in
                    clockPreferences.showSeconds = newValue
                    UserDefaults.standard.set(newValue, forKey: "tonic.clock.showSeconds")
                }
            )
        )

        moduleDivider

        PreferenceToggleRow(
            title: "Use 24-Hour Format",
            subtitle: "Display time in 24-hour format",
            icon: "clock",
            iconColor: DesignTokens.Colors.accent,
            showDivider: false,
            isOn: Binding(
                get: { clockPreferences.use24Hour },
                set: { newValue in
                    clockPreferences.use24Hour = newValue
                    UserDefaults.standard.set(newValue, forKey: "tonic.clock.use24Hour")
                }
            )
        )
    }

    // MARK: - Module Settings Helpers

    private var moduleDivider: some View {
        Divider()
            .padding(.leading, DesignTokens.Spacing.md)
    }

    private func moduleToggleRow(
        title: String,
        subtitle: String,
        icon: String,
        iconColor: Color = DesignTokens.Colors.accent,
        isOn: Binding<Bool>
    ) -> some View {
        PreferenceRow(
            title: title,
            subtitle: subtitle,
            icon: icon,
            iconColor: iconColor,
            showDivider: false
        ) {
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .labelsHidden()
        }
    }

    private func moduleBinding(
        _ keyPath: KeyPath<ModuleSettings, Bool>,
        set: @escaping (inout ModuleSettings, Bool) -> Void
    ) -> Binding<Bool> {
        Binding(
            get: { config.moduleSettings[keyPath: keyPath] },
            set: { newValue in
                updateModuleSettings { settings in
                    set(&settings, newValue)
                }
            }
        )
    }

    private func updateModuleSettings(_ update: (inout ModuleSettings) -> Void) {
        var currentSettings = config.moduleSettings
        update(&currentSettings)
        preferences.setWidgetModuleSettings(type: module, settings: currentSettings)
    }

    private func topProcessCountRow(current: Int, set: @escaping (Int) -> Void) -> some View {
        PreferenceRow(
            title: "Top Processes",
            subtitle: "Number of top processes to display",
            icon: "list.number",
            iconColor: DesignTokens.Colors.accent,
            showDivider: false
        ) {
            Menu {
                ForEach([5, 10, 15, 20], id: \.self) { count in
                    Button(action: { set(count) }) {
                        HStack {
                            Text("\(count)")
                            if current == count {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Text("\(current)")
                        .font(DesignTokens.Typography.subhead)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                }
                .foregroundColor(DesignTokens.Colors.textPrimary)
            }
            .menuStyle(.borderlessButton)
        }
    }

    // MARK: - Helper Properties

    private var supportsValueFormat: Bool {
        switch module {
        case .cpu, .memory, .gpu, .battery, .disk:
            return true
        case .network, .weather, .sensors, .bluetooth, .clock:
            return false
        }
    }

    private var supportsNotifications: Bool {
        switch module {
        case .cpu, .memory, .disk, .gpu, .battery, .sensors:
            return true
        case .network, .weather, .bluetooth, .clock:
            return false
        }
    }

    // MARK: - Helper Types

    private struct ThresholdPreset {
        let label: String
        let detail: String
        let value: Double
        let condition: NotificationCondition
    }
}

// MARK: - Preview

#Preview("Modules Settings") {
    ModulesSettingsContent()
        .frame(width: 700, height: 500)
}
