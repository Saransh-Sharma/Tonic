//
//  PopupSettingsView.swift
//  Tonic
//
//  Global popover settings configuration UI
//  Task ID: fn-8-v3b.16
//

import SwiftUI

// MARK: - Popup Settings View

/// Global popover settings view for all widgets
/// Includes keyboard shortcut, chart history, scaling, and color options
public struct PopupSettingsView: View {

    // MARK: - Properties

    @AppStorage("popupSettings") private var popupSettingsData: Data = {
        let defaults = PopupSettings()
        return (try? JSONEncoder().encode(defaults)) ?? Data()
    }()

    @State private var settings: PopupSettings = PopupSettings()
    @State private var showingColorPicker = false
    @State private var selectedColorIndex: Int = 0

    // Metrics that can have custom colors
    private let availableMetrics: [(name: String, key: String, icon: String)] = [
        ("CPU", "cpu", "cpu"),
        ("GPU", "gpu", "tv"),
        ("Memory", "memory", "memorychip"),
        ("Disk", "disk", "internaldrive"),
        ("Network", "network", "wifi"),
        ("Battery", "battery", "battery.100"),
        ("Sensors", "sensors", "thermometer"),
        ("Bluetooth", "bluetooth", "bluetooth"),
    ]

    // Predefined colors for easy selection
    private let colorOptions: [(name: String, hex: String)] = [
        ("Blue", "#007AFF"),
        ("Purple", "#5856D6"),
        ("Pink", "#FF2D55"),
        ("Red", "#FF3B30"),
        ("Orange", "#FF9500"),
        ("Yellow", "#FFCC00"),
        ("Green", "#34C759"),
        ("Teal", "#5AC8FA"),
        ("Cyan", "#32ADE6"),
        ("Indigo", "#5856D6"),
        ("Gray", "#8E8E93"),
    ]

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                // Keyboard Shortcut Section
                keyboardShortcutSection

                Divider()

                // Chart History Section
                chartHistorySection

                Divider()

                // Scaling Mode Section
                scalingModeSection

                Divider()

                // Color Options Section
                colorOptionsSection

                Divider()

                // Popover Dimensions Section
                popoverDimensionsSection
            }
            .padding(DesignTokens.Spacing.md)

            Spacer()
        }
        .onChange(of: settings) { _, newValue in
            saveSettings(newValue)
        }
        .onAppear {
            loadSettings()
        }
    }

    // MARK: - Sections

    private var keyboardShortcutSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Keyboard Shortcut")
                .font(DesignTokens.Typography.subheadEmphasized)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "command")
                    .font(.system(size: 14))
                    .foregroundColor(DesignTokens.Colors.textSecondary)

                if let shortcut = settings.keyboardShortcut {
                    Text(shortcut.uppercased())
                        .font(DesignTokens.Typography.monoBody)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                        .padding(.horizontal, DesignTokens.Spacing.xxs)
                        .padding(.vertical, 4)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(DesignTokens.CornerRadius.small)

                    Button("Clear") {
                        settings.keyboardShortcut = nil
                    }
                    .buttonStyle(.plain)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.accent)
                } else {
                    Text("Not Set")
                        .font(DesignTokens.Typography.subhead)
                        .foregroundColor(DesignTokens.Colors.textTertiary)

                    Button("Set Shortcut...") {
                        // Placeholder - full implementation requires global hotkey registration
                        settings.keyboardShortcut = "Cmd+Shift+T"
                    }
                    .buttonStyle(.plain)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.accent)
                }

                Spacer()
            }
            .padding(.horizontal, DesignTokens.Spacing.xxs)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(DesignTokens.CornerRadius.medium)

            Text("Global shortcut to open widget popovers from anywhere")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(DesignTokens.Colors.textTertiary)
        }
    }

    private var chartHistorySection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Chart History Duration")
                .font(DesignTokens.Typography.subheadEmphasized)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            HStack(spacing: DesignTokens.Spacing.md) {
                Text("\(settings.chartHistoryDuration)s")
                    .font(DesignTokens.Typography.monoBody)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                    .frame(width: 50)

                Slider(
                    value: Binding(
                        get: { Double(settings.chartHistoryDuration) },
                        set: { settings.chartHistoryDuration = Int($0) }
                    ),
                    in: 60...300,
                    step: 30
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text("60s")
                        .font(DesignTokens.Typography.caption2)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                    Text("300s")
                        .font(DesignTokens.Typography.caption2)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                }
            }

            Text("Number of seconds of data to display in charts (180s = 180 samples at 1Hz)")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(DesignTokens.Colors.textTertiary)
        }
    }

    private var scalingModeSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Chart Scaling Mode")
                .font(DesignTokens.Typography.subheadEmphasized)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            Picker("", selection: $settings.scalingMode) {
                ForEach(PopupSettings.ScalingMode.allCases, id: \.self) { mode in
                    Label(mode.displayName, systemImage: mode.icon)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if settings.scalingMode == .fixed {
                HStack(spacing: DesignTokens.Spacing.md) {
                    Text("Fixed Scale:")
                        .font(DesignTokens.Typography.subhead)
                        .foregroundColor(DesignTokens.Colors.textSecondary)

                    Slider(
                        value: $settings.fixedScaleValue,
                        in: 10...200,
                        step: 10
                    )

                    Text("\(Int(settings.fixedScaleValue))%")
                        .font(DesignTokens.Typography.monoSubhead)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                        .frame(width: 45)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Text("Controls how Y-axis scales on charts")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(DesignTokens.Colors.textTertiary)
        }
    }

    private var colorOptionsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Color Options")
                .font(DesignTokens.Typography.subheadEmphasized)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            Toggle("Auto-color based on utilization", isOn: $settings.useAutoColors)

            if !settings.useAutoColors {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("Primary Color")
                        .font(DesignTokens.Typography.subhead)
                        .foregroundColor(DesignTokens.Colors.textSecondary)

                    // Color picker with predefined options
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: DesignTokens.Spacing.xs) {
                        ForEach(Array(colorOptions.enumerated()), id: \.offset) { index, color in
                            colorButton(name: color.name, hex: color.hex, index: index)
                        }
                    }

                    // Custom color picker
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        Text("Custom:")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(DesignTokens.Colors.textSecondary)

                        ColorPicker("", selection: Binding(
                            get: { Color(hex: settings.primaryColor) ?? .blue },
                            set: { settings.primaryColor = $0.toHex() }
                        ))
                        .labelsHidden()
                        .supportsOpacity(false)

                        Text(settings.primaryColor)
                            .font(DesignTokens.Typography.monoCaption)
                            .foregroundColor(DesignTokens.Colors.textTertiary)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))

                Divider()

                // Per-metric color picker
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("Per-Metric Colors")
                        .font(DesignTokens.Typography.subhead)
                        .foregroundColor(DesignTokens.Colors.textSecondary)

                    ForEach(availableMetrics, id: \.key) { metric in
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            Image(systemName: metric.icon)
                                .font(.system(size: 14))
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                                .frame(width: 24)

                            Text(metric.name)
                                .font(DesignTokens.Typography.subhead)
                                .foregroundColor(DesignTokens.Colors.textPrimary)

                            Spacer()

                            ColorPicker("", selection: Binding(
                                get: {
                                    if let hex = settings.metricColors[metric.key] {
                                        return Color(hex: hex) ?? DesignTokens.Colors.accent
                                    }
                                    return DesignTokens.Colors.accent
                                },
                                set: { newColor in
                                    settings.metricColors[metric.key] = newColor.toHex()
                                }
                            ))
                            .labelsHidden()
                            .supportsOpacity(false)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Text("Auto-color changes from green→yellow→orange→red based on value")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(DesignTokens.Colors.textTertiary)
        }
    }

    private var popoverDimensionsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Popover Dimensions")
                .font(DesignTokens.Typography.subheadEmphasized)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            HStack(spacing: DesignTokens.Spacing.md) {
                Text("Width:")
                    .font(DesignTokens.Typography.subhead)
                    .foregroundColor(DesignTokens.Colors.textSecondary)

                Slider(
                    value: $settings.popoverWidth,
                    in: 240...400,
                    step: 20
                )

                Text("\(Int(settings.popoverWidth))px")
                    .font(DesignTokens.Typography.monoSubhead)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                    .frame(width: 50)
            }

            Text("Stats Master standard: 280px")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(DesignTokens.Colors.textTertiary)
        }
    }

    // MARK: - Private Methods

    private func colorButton(name: String, hex: String, index: Int) -> some View {
        Button {
            settings.primaryColor = hex
        } label: {
            VStack(spacing: 4) {
                Circle()
                    .fill(Color(hex: hex) ?? .blue)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Circle()
                            .stroke(settings.primaryColor == hex ? Color.primary : Color.clear, lineWidth: 2)
                    )

                Text(name)
                    .font(DesignTokens.Typography.caption2)
                    .foregroundColor(settings.primaryColor == hex ? DesignTokens.Colors.accent : DesignTokens.Colors.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }

    private func saveSettings(_ settings: PopupSettings) {
        if let encoded = try? JSONEncoder().encode(settings) {
            popupSettingsData = encoded
        }
    }

    private func loadSettings() {
        guard let decoded = try? JSONDecoder().decode(PopupSettings.self, from: popupSettingsData) else {
            return
        }
        settings = decoded
    }
}

// MARK: - Color Extension

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = Double((rgb & 0xFF0000) >> 16) / 255
        let g = Double((rgb & 0x00FF00) >> 8) / 255
        let b = Double(rgb & 0x0000FF) / 255

        self.init(red: r, green: g, blue: b)
    }

    func toHex() -> String {
        #if os(macOS)
        guard let components = NSColor(self).usingColorSpace(.deviceRGB) else {
            return "#000000"
        }
        let r = Int(components.redComponent * 255)
        let g = Int(components.greenComponent * 255)
        let b = Int(components.blueComponent * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
        #else
        return "#000000"
        #endif
    }
}

// MARK: - Preview

#Preview("Popup Settings") {
    PopupSettingsView()
        .frame(width: 540, height: 480)
}
