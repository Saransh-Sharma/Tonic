//
//  SettingsSectionComponents.swift
//  Tonic
//
//  Reusable settings components matching Stats Master's design
//  Sections with subtle backgrounds, rows with label+control pairs
//

import SwiftUI

// MARK: - Settings Section

/// Container for grouped settings with title and background
struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text(title)
                .font(DesignTokens.Typography.captionEmphasized)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .textCase(.uppercase)
                .padding(.horizontal, DesignTokens.Spacing.xs)

            VStack(spacing: 0) {
                content()
            }
            .background(DesignTokens.Colors.backgroundSecondary.opacity(0.5))
            .cornerRadius(DesignTokens.CornerRadius.medium)
        }
    }
}

// MARK: - Settings Row

/// Single row with label and control
struct SettingsRow<Control: View>: View {
    let label: String
    var description: String? = nil
    @ViewBuilder let control: () -> Control

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
                Text(label)
                    .font(DesignTokens.Typography.body)
                    .foregroundColor(DesignTokens.Colors.textPrimary)

                if let description = description {
                    Text(description)
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                }
            }

            Spacer()

            control()
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
    }
}

// MARK: - Toggle Row

/// Convenience wrapper for toggle settings
struct ToggleRow: View {
    let label: String
    var description: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        SettingsRow(label: label, description: description) {
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .controlSize(.small)
        }
    }
}

// MARK: - Interval Picker

/// Picker for update intervals
struct IntervalPicker: View {
    @Binding var selection: WidgetUpdateInterval

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            ForEach(WidgetUpdateInterval.allCases) { interval in
                IntervalButton(
                    interval: interval,
                    isSelected: selection == interval
                ) {
                    withAnimation(DesignTokens.Animation.fast) {
                        selection = interval
                    }
                }
            }
        }
    }
}

private struct IntervalButton: View {
    let interval: WidgetUpdateInterval
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignTokens.Spacing.xxxs) {
                Text("\(Int(interval.timeInterval))s")
                    .font(DesignTokens.Typography.captionEmphasized)
                    .monospacedDigit()

                Text(interval.shortLabel)
                    .font(.system(size: 8))
            }
            .frame(width: 52, height: 40)
            .foregroundColor(isSelected ? .white : DesignTokens.Colors.textSecondary)
            .background(isSelected ? DesignTokens.Colors.accent : DesignTokens.Colors.backgroundSecondary)
            .cornerRadius(DesignTokens.CornerRadius.small)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Color Picker Row

/// Horizontal color picker for widget accent colors
struct ColorPickerRow: View {
    let widgetType: WidgetType
    @Binding var selection: WidgetAccentColor

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            ForEach(WidgetAccentColor.allCases) { color in
                ColorSwatch(
                    color: color,
                    widgetType: widgetType,
                    isSelected: selection == color
                ) {
                    withAnimation(DesignTokens.Animation.fast) {
                        selection = color
                    }
                }
            }
        }
    }
}

private struct ColorSwatch: View {
    let color: WidgetAccentColor
    let widgetType: WidgetType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color.colorValue(for: widgetType))
                .frame(width: 24, height: 24)
                .overlay(
                    Circle()
                        .stroke(isSelected ? DesignTokens.Colors.accent : Color.clear, lineWidth: 2)
                        .padding(-2)
                )
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .opacity(isSelected ? 1 : 0)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Display Mode Picker

/// Segmented picker for display modes
struct DisplayModePicker: View {
    @Binding var selection: WidgetDisplayMode

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            ForEach(WidgetDisplayMode.allCases) { mode in
                DisplayModeButton(
                    mode: mode,
                    isSelected: selection == mode
                ) {
                    withAnimation(DesignTokens.Animation.fast) {
                        selection = mode
                    }
                }
            }
        }
    }
}

private struct DisplayModeButton: View {
    let mode: WidgetDisplayMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignTokens.Spacing.xxxs) {
                Image(systemName: iconFor(mode))
                    .font(.system(size: 14, weight: .semibold))

                Text(mode.shortLabel)
                    .font(.system(size: 9))
            }
            .frame(width: 64, height: 44)
            .foregroundColor(isSelected ? .white : DesignTokens.Colors.textSecondary)
            .background(isSelected ? DesignTokens.Colors.accent : DesignTokens.Colors.backgroundSecondary)
            .cornerRadius(DesignTokens.CornerRadius.small)
        }
        .buttonStyle(.plain)
    }

    private func iconFor(_ mode: WidgetDisplayMode) -> String {
        switch mode {
        case .compact: return "square.split.1x2"
        case .detailed: return "chart.line.uptrend.xyaxis"
        }
    }
}

// MARK: - Settings Divider

/// Subtle divider for use within settings sections
struct SettingsDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, DesignTokens.Spacing.md)
    }
}

// MARK: - Widget Preview Box

/// Shows a preview of how the widget will appear in menu bar
struct WidgetPreviewBox: View {
    let widgetType: WidgetType
    let displayMode: WidgetDisplayMode
    let accentColor: WidgetAccentColor
    let valueFormat: WidgetValueFormat

    @State private var dataManager = WidgetDataManager.shared

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xs) {
            Text("Preview")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(DesignTokens.Colors.textTertiary)

            // Menu bar simulation
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: widgetType.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(accentColor.colorValue(for: widgetType))

                if displayMode == .compact || displayMode == .detailed {
                    Text(previewValue)
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                }

                if displayMode == .detailed {
                    miniSparkline
                        .frame(width: 36, height: 10)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(Color.black.opacity(0.3))
            .cornerRadius(DesignTokens.CornerRadius.small)
        }
        .frame(maxWidth: .infinity)
        .padding(DesignTokens.Spacing.md)
        .background(DesignTokens.Colors.backgroundSecondary.opacity(0.5))
        .cornerRadius(DesignTokens.CornerRadius.medium)
    }

    private var previewValue: String {
        let usePercent = valueFormat == .percentage

        switch widgetType {
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
        }
    }

    private var miniSparkline: some View {
        GeometryReader { geometry in
            Path { path in
                let data: [Double] = sparklineData
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
                accentColor.colorValue(for: widgetType),
                lineWidth: 1.2
            )
        }
    }

    private var sparklineData: [Double] {
        switch widgetType {
        case .cpu:
            let history = dataManager.cpuHistory.suffix(8)
            return history.isEmpty ? [30, 35, 32, 38, 36, 34, 37, 35] : Array(history)
        case .memory:
            let history = dataManager.memoryHistory.suffix(8)
            return history.isEmpty ? [60, 62, 58, 65, 63, 67, 64, 68] : Array(history)
        default:
            return [30, 35, 32, 38, 36, 34, 37, 35]
        }
    }
}

// MARK: - Interval Extension

extension WidgetUpdateInterval {
    var shortLabel: String {
        switch self {
        case .power: return "Eco"
        case .balanced: return "Bal"
        case .performance: return "Fast"
        }
    }
}

// MARK: - Preview

#Preview("Settings Components") {
    VStack(spacing: 20) {
        SettingsSection(title: "Update Interval") {
            IntervalPicker(selection: .constant(.balanced))
                .padding()
        }

        SettingsSection(title: "Display") {
            ToggleRow(label: "Show percentage", isOn: .constant(true))
            SettingsDivider()
            ToggleRow(label: "Per-core usage", isOn: .constant(false))
        }

        WidgetPreviewBox(
            widgetType: .cpu,
            displayMode: .detailed,
            accentColor: .system,
            valueFormat: .percentage
        )
    }
    .padding()
    .frame(width: 400)
    .background(DesignTokens.Colors.background)
}
