//
//  NotificationSettingsView.swift
//  Tonic
//
//  Notification settings UI with threshold configuration
//  Task ID: fn-6-i4g.10
//

import SwiftUI

// MARK: - Notification Settings View

/// Main view for configuring notification thresholds per widget type
struct NotificationSettingsView: View {
    @State private var notificationManager = NotificationManager.shared
    @State private var preferences = WidgetPreferences.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showingPermissionAlert = false
    @State private var showingTestAlert = false
    @State private var testAlertMessage = ""

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection

            Divider()

            // Content
            ScrollView {
                VStack(spacing: DesignTokens.Spacing.lg) {
                    // Global settings
                    globalNotificationSettings

                    // Per-widget notification thresholds
                    ForEach(notifiableWidgetTypes) { widgetType in
                        widgetNotificationSection(for: widgetType)
                    }
                }
                .padding(DesignTokens.Spacing.lg)
            }

            Divider()

            // Footer
            footerSection
        }
        .frame(width: 500, height: 650)
        .background(DesignTokens.Colors.background)
        .alert("Notification Permission", isPresented: $showingPermissionAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Open Settings") {
                notificationManager.openNotificationSettings()
            }
        } message: {
            Text("Notification permission is required. Please enable it in System Settings.")
        }
        .alert("Test Notification", isPresented: $showingTestAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(testAlertMessage)
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
                Text("Notification Settings")
                    .font(DesignTokens.Typography.h3)

                Text("Configure alerts for system resource thresholds")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }

            Spacer()

            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(DesignTokens.Spacing.md)
    }

    // MARK: - Global Notification Settings

    private var globalNotificationSettings: some View {
        PreferenceList {
            PreferenceSection(header: "Global Settings") {
                // Enable/Disable all notifications
                PreferenceToggleRow(
                    title: "Enable Notifications",
                    subtitle: notificationManager.hasPermission
                        ? "Allow Tonic to send notifications"
                        : "Permission required - tap to request",
                    icon: "bell",
                    iconColor: notificationManager.hasPermission
                        ? DesignTokens.Colors.success
                        : DesignTokens.Colors.warning,
                    isOn: Binding(
                        get: { notificationManager.config.notificationsEnabled },
                        set: { newValue in
                            if newValue && !notificationManager.hasPermission {
                                showingPermissionAlert = true
                            } else {
                                notificationManager.toggleNotifications()
                            }
                        }
                    )
                )

                // Respect Do Not Disturb
                PreferenceToggleRow(
                    title: "Respect Do Not Disturb",
                    subtitle: "Suppress notifications during Focus modes",
                    icon: "moon",
                    isOn: Binding(
                        get: { notificationManager.config.respectDoNotDisturb },
                        set: { _ in notificationManager.toggleRespectDoNotDisturb() }
                    )
                )

                // Minimum interval between notifications
                NotificationIntervalRow(
                    title: "Minimum Interval",
                    subtitle: "Prevent notification spam",
                    icon: "clock",
                    currentInterval: notificationManager.config.minimumInterval,
                    onIntervalChanged: { newInterval in
                        notificationManager.setMinimumInterval(newInterval)
                    }
                )
            }
        }
    }

    // MARK: - Widget Notification Section

    private func widgetNotificationSection(for widgetType: WidgetType) -> some View {
        let thresholds = notificationManager.config.thresholds(for: widgetType)
        let hasEnabledThresholds = notificationManager.config.hasThresholds(for: widgetType)

        return PreferenceList {
            PreferenceSection(header: widgetType.displayName) {
                // Widget info row
                PreferenceRow(
                    title: widgetType.displayName + " Notifications",
                    subtitle: hasEnabledThresholds
                        ? "\(thresholds.count) threshold(s) configured"
                        : "No thresholds configured",
                    icon: widgetType.icon,
                    iconColor: widgetAccentColor(for: widgetType),
                    showDivider: !thresholds.isEmpty
                ) {
                    // Add threshold button
                    Button {
                        addDefaultThreshold(for: widgetType)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(DesignTokens.Colors.accent)
                    }
                    .buttonStyle(.plain)
                    .help("Add threshold")
                }

                // Existing thresholds
                if !thresholds.isEmpty {
                    ForEach(Array(thresholds.enumerated()), id: \.element.id) { index, threshold in
                        NotificationThresholdRow(
                            threshold: threshold,
                            widgetType: widgetType,
                            onToggle: {
                                notificationManager.toggleThreshold(id: threshold.id)
                            },
                            onEdit: {
                                editThreshold(threshold)
                            },
                            onDelete: {
                                notificationManager.removeThreshold(id: threshold.id)
                            },
                            onTest: {
                                testThreshold(threshold)
                            }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Footer Section

    private var footerSection: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            // Reset button
            Button(role: .destructive) {
                notificationManager.resetToDefaults()
            } label: {
                Label("Reset All", systemImage: "arrow.counterclockwise")
                    .font(DesignTokens.Typography.body)
                    .foregroundColor(DesignTokens.Colors.destructive)
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .background(DesignTokens.Colors.destructive.opacity(0.1))
                    .cornerRadius(DesignTokens.CornerRadius.medium)
            }
            .buttonStyle(.plain)

            Spacer()

            // Send test notification
            Button {
                notificationManager.sendTestNotification()
                testAlertMessage = "Test notification sent. Check Notification Center."
                showingTestAlert = true
            } label: {
                Label("Test", systemImage: "bell.badge")
                    .font(DesignTokens.Typography.body)
                    .foregroundColor(.white)
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .background(DesignTokens.Colors.accent)
                    .cornerRadius(DesignTokens.CornerRadius.medium)
            }
            .buttonStyle(.plain)

            // Done button
            Button {
                dismiss()
            } label: {
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

    // MARK: - Helper Methods

    private var notifiableWidgetTypes: [WidgetType] {
        [.cpu, .memory, .disk, .gpu, .battery, .sensors]
    }

    private func widgetAccentColor(for type: WidgetType) -> Color {
        switch type {
        case .cpu: return Color(red: 0.37, green: 0.62, blue: 1.0)
        case .memory: return Color(red: 0.19, green: 0.82, blue: 0.35)
        case .disk: return Color(red: 1.0, green: 0.62, blue: 0.04)
        case .gpu: return Color(red: 0.75, green: 0.35, blue: 0.95)
        case .battery: return Color(red: 0.19, green: 0.82, blue: 0.35)
        case .sensors: return Color(red: 1.0, green: 0.45, blue: 0.0)
        default: return DesignTokens.Colors.accent
        }
    }

    private func addDefaultThreshold(for widgetType: WidgetType) {
        let defaults = NotificationThreshold.defaultThresholds(for: widgetType)
        if let defaultThreshold = defaults.first {
            var newThreshold = defaultThreshold
            newThreshold.isEnabled = true
            notificationManager.updateThreshold(newThreshold)
        }
    }

    private func editThreshold(_ threshold: NotificationThreshold) {
        // Present an edit sheet for the threshold
        // This would expand to show threshold editor
        // For now, we toggle through common values
        var updatedThreshold = threshold
        let stepValue = stepForWidgetType(threshold.widgetType)
        updatedThreshold.value = min(threshold.value + stepValue, maxValueForWidgetType(threshold.widgetType))
        notificationManager.updateThreshold(updatedThreshold)
    }

    private func testThreshold(_ threshold: NotificationThreshold) {
        let (title, body) = generateTestContent(for: threshold)
        notificationManager.sendNotification(title: title, body: body, thresholdId: "test_\(threshold.id.uuidString)")
        testAlertMessage = "Test notification sent for \(threshold.widgetType.displayName)."
        showingTestAlert = true
    }

    private func generateTestContent(for threshold: NotificationThreshold) -> (String, String) {
        let title = "\(threshold.widgetType.displayName) Alert (Test)"
        let body = "This is a test. Threshold: \(threshold.formattedValue)"
        return (title, body)
    }

    private func stepForWidgetType(_ type: WidgetType) -> Double {
        switch type {
        case .cpu, .memory, .gpu, .battery: return 5.0
        case .disk: return 5.0
        case .sensors: return 5.0
        default: return 1.0
        }
    }

    private func maxValueForWidgetType(_ type: WidgetType) -> Double {
        switch type {
        case .cpu, .memory, .gpu, .battery: return 100.0
        case .disk: return 100.0
        case .sensors: return 120.0
        default: return 100.0
        }
    }
}

// MARK: - Notification Threshold Row

/// A row displaying a single notification threshold with controls
struct NotificationThresholdRow: View {
    let threshold: NotificationThreshold
    let widgetType: WidgetType
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onTest: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                // Condition badge
                conditionBadge

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
                    Text(thresholdLabel)
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(threshold.isEnabled
                            ? DesignTokens.Colors.textPrimary
                            : DesignTokens.Colors.textSecondary)

                    Text(thresholdDescription)
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                }

                Spacer()

                // Action buttons (show on hover)
                if isHovered {
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        // Test button
                        Button(action: onTest) {
                            Image(systemName: "bell.badge")
                                .font(.system(size: 12))
                                .foregroundColor(DesignTokens.Colors.info)
                        }
                        .buttonStyle(.plain)
                        .help("Send test notification")

                        // Edit button
                        Button(action: onEdit) {
                            Image(systemName: "pencil")
                                .font(.system(size: 12))
                                .foregroundColor(DesignTokens.Colors.accent)
                        }
                        .buttonStyle(.plain)
                        .help("Edit threshold")

                        // Delete button
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: 12))
                                .foregroundColor(DesignTokens.Colors.destructive)
                        }
                        .buttonStyle(.plain)
                        .help("Remove threshold")
                    }
                    .transition(.opacity)
                }

                // Toggle
                Toggle("", isOn: .init(
                    get: { threshold.isEnabled },
                    set: { _ in onToggle() }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
            }
            .padding(.vertical, DesignTokens.Spacing.sm)
            .padding(.horizontal, DesignTokens.Spacing.md)
            .background(isHovered
                ? DesignTokens.Colors.unemphasizedSelectedContentBackground.opacity(0.3)
                : Color.clear)
            .contentShape(Rectangle())
            .onHover { hovering in
                withAnimation(DesignTokens.Animation.fast) {
                    isHovered = hovering
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(thresholdLabel)
    }

    private var conditionBadge: some View {
        Text(threshold.condition.symbol)
            .font(DesignTokens.Typography.captionEmphasized)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(conditionColor)
            .cornerRadius(4)
    }

    private var conditionColor: Color {
        switch threshold.condition {
        case .greaterThan, .greaterThanOrEqual:
            return DesignTokens.Colors.warning
        case .lessThan, .lessThanOrEqual:
            return DesignTokens.Colors.info
        default:
            return DesignTokens.Colors.textSecondary
        }
    }

    private var thresholdLabel: String {
        "\(threshold.widgetType.displayName) \(threshold.condition.symbol) \(threshold.formattedValue)"
    }

    private var thresholdDescription: String {
        switch threshold.widgetType {
        case .cpu:
            return "Alert when CPU usage \(threshold.condition.displayName.lowercased()) threshold"
        case .memory:
            return "Alert when memory usage \(threshold.condition.displayName.lowercased()) threshold"
        case .disk:
            return "Alert when disk usage \(threshold.condition.displayName.lowercased()) threshold"
        case .gpu:
            return "Alert when GPU usage \(threshold.condition.displayName.lowercased()) threshold"
        case .battery:
            return "Alert when battery level \(threshold.condition.displayName.lowercased()) threshold"
        case .sensors:
            return "Alert when temperature \(threshold.condition.displayName.lowercased()) threshold"
        default:
            return "Threshold alert"
        }
    }
}

// MARK: - Notification Interval Row

/// A row for selecting the minimum notification interval
struct NotificationIntervalRow: View {
    let title: String
    let subtitle: String?
    let icon: String?
    let currentInterval: TimeInterval
    let onIntervalChanged: (TimeInterval) -> Void

    var body: some View {
        PreferenceRow(
            title: title,
            subtitle: subtitle,
            icon: icon,
            showDivider: false
        ) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                ForEach(NotificationConfig.PresetInterval.allCases) { preset in
                    intervalButton(preset)
                }
            }
        }
    }

    private func intervalButton(_ preset: NotificationConfig.PresetInterval) -> some View {
        let isSelected = abs(currentInterval - preset.timeInterval) < 0.1

        return Button {
            onIntervalChanged(preset.timeInterval)
        } label: {
            Text(preset.displayName)
                .font(DesignTokens.Typography.caption)
                .foregroundColor(isSelected ? .white : DesignTokens.Colors.textSecondary)
                .padding(.horizontal, DesignTokens.Spacing.sm)
                .padding(.vertical, DesignTokens.Spacing.xs)
                .background(isSelected ? DesignTokens.Colors.accent : DesignTokens.Colors.backgroundSecondary)
                .cornerRadius(DesignTokens.CornerRadius.small)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Notification Settings") {
    NotificationSettingsView()
}
