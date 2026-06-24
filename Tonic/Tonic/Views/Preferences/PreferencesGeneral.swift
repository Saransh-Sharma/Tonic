//
//  PreferencesGeneral.swift
//  Tonic
//
//  Extracted from PreferencesView.swift to keep settings sections modular.
//

import SwiftUI
import AppKit
import UserNotifications

#if canImport(Sparkle)
import Sparkle
#endif

struct GeneralSettingsContent: View {
    @State private var preferences = AppearancePreferences.shared
    @State private var showResetSheet = false
    @State private var showFeedbackSheet = false
    @AppStorage(TonicUserDefaultsKey.powerUserModeEnabled) private var powerUserModeEnabled = false

    var body: some View {
        PreferenceList {
            // Appearance Section
            PreferenceSection(header: "Appearance") {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                        Text("Theme")
                            .font(DesignTokens.Typography.captionEmphasized)
                            .foregroundColor(DesignTokens.Colors.textSecondary)

                        HStack(spacing: DesignTokens.Spacing.sm) {
                            ForEach(ThemeMode.allCases) { mode in
                                ThemeSelectorButton(
                                    mode: mode,
                                    isSelected: preferences.themeMode == mode
                                ) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        preferences.setThemeMode(mode)
                                        NotificationCenter.default.post(name: NSNotification.Name("TonicThemeDidChange"), object: nil)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .padding(.horizontal, DesignTokens.Spacing.md)

                    Divider()
                        .padding(.leading, DesignTokens.Spacing.md)

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                        Text("Luxury Theme System")
                            .font(DesignTokens.Typography.captionEmphasized)
                            .foregroundColor(DesignTokens.Colors.textSecondary)

                        LuxuryThemeSystemRow()
                    }
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .padding(.horizontal, DesignTokens.Spacing.md)
                }
            }

            PreferenceSection(header: "General") {
                VStack(spacing: 0) {
                    PreferenceToggleRow(
                        title: "Power User Mode",
                        subtitle: "Reveals developer caches, path-level scan detail, and advanced cleanup context.",
                        icon: TonicUserMode.powerUser.icon,
                        iconColor: TonicColors.accent,
                        showDivider: true,
                        isOn: $powerUserModeEnabled
                    )

                    ShortcutRow(title: "Open Command Palette", shortcut: "⌘K")
                        .padding(.vertical, DesignTokens.Spacing.sm)
                        .padding(.horizontal, DesignTokens.Spacing.md)

                    Divider()
                        .padding(.leading, DesignTokens.Spacing.md)

                    Button {
                        showFeedbackSheet = true
                    } label: {
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            Image(systemName: "bubble.right.fill")
                                .foregroundColor(TonicColors.accent)

                            Text("Open Feedback Form")
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(DesignTokens.Colors.textPrimary)

                            Spacer()
                        }
                        .padding(.vertical, DesignTokens.Spacing.sm)
                        .padding(.horizontal, DesignTokens.Spacing.md)
                    }
                    .buttonStyle(.plain)
                }
            }

            #if DEBUG
            PreferenceSection(header: "Developer Debug") {
                let features = WIPFeature.allCases
                VStack(spacing: 0) {
                    ForEach(Array(features.enumerated()), id: \.element) { index, feature in
                        PreferenceToggleRow(
                            title: feature.displayName,
                            subtitle: "Show this WIP route in app navigation",
                            icon: feature.icon,
                            iconColor: DesignTokens.Colors.warning,
                            showDivider: index < features.count - 1,
                            isOn: debugFeatureBinding(for: feature)
                        )
                    }

                    PreferenceButtonRow(
                        title: "Reset Feature Overrides",
                        subtitle: "Restore Debug defaults for all WIP routes",
                        icon: "arrow.counterclockwise",
                        iconColor: DesignTokens.Colors.warning,
                        showDivider: false,
                        buttonTitle: "Reset",
                        buttonStyle: .secondary
                    ) {
                        FeatureFlags.clearAllOverrides()
                        NotificationCenter.default.post(name: .featureFlagsDidChange, object: nil)
                    }
                }
            }
            #endif

            // Danger Zone Section
            PreferenceSection(header: "Danger Zone") {
                PreferenceButtonRow(
                    title: "Reset App & Start Fresh",
                    subtitle: "Clear all data, remove helper, and restart setup",
                    icon: "arrow.counterclockwise.circle.fill",
                    iconColor: DesignTokens.Colors.destructive,
                    showDivider: false,
                    buttonTitle: "Reset App...",
                    buttonStyle: .destructive,
                    action: { showResetSheet = true }
                )
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .sheet(isPresented: $showResetSheet) {
            ResetConfirmationSheet(isPresented: $showResetSheet)
        }
        .sheet(isPresented: $showFeedbackSheet) {
            FeedbackSheetView()
        }
    }

    #if DEBUG
    private func debugFeatureBinding(for feature: WIPFeature) -> Binding<Bool> {
        Binding(
            get: { FeatureFlags.isEnabled(feature) },
            set: { enabled in
                FeatureFlags.set(feature, enabled: enabled)
                NotificationCenter.default.post(name: .featureFlagsDidChange, object: nil)
            }
        )
    }
    #endif
}


// MARK: - Theme Selector Button

struct ThemeSelectorButton: View {
    let mode: ThemeMode
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignTokens.Spacing.xs) {
                ZStack {
                    // Preview window
                    RoundedRectangle(cornerRadius: 8)
                        .fill(previewBackground)
                        .frame(width: 64, height: 44)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isSelected ? TonicColors.accent : DesignTokens.Colors.separator, lineWidth: isSelected ? 2 : 1)
                        )
                        .shadow(color: Color.black.opacity(isHovered ? 0.15 : 0.08), radius: isHovered ? 6 : 3, x: 0, y: 2)

                    // Icon
                    Image(systemName: mode.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(previewIconColor)
                }

                Text(mode.rawValue)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(isSelected ? TonicColors.accent : DesignTokens.Colors.textSecondary)
            }
            .scaleEffect(isHovered ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovered = hovering
            }
        }
    }

    private var previewBackground: Color {
        switch mode {
        case .system: return Color(nsColor: .windowBackgroundColor)
        case .light: return Color.white
        case .dark: return Color(red: 0.12, green: 0.12, blue: 0.14)
        }
    }

    private var previewIconColor: Color {
        switch mode {
        case .system: return DesignTokens.Colors.textSecondary
        case .light: return Color.gray
        case .dark: return Color.white.opacity(0.8)
        }
    }
}

// MARK: - Permissions Settings Content


struct LuxuryThemeSystemRow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "09090C"), Color(hex: "443566"), Color(hex: "DAB783")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 86, height: 32)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.25), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Atelier Luxury Palette")
                        .font(DesignTokens.Typography.captionEmphasized)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                    Text("Single premium palette with world-specific accents.")
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }

                Spacer()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Atelier luxury palette is active")
        .accessibilityHint("Color palette switching has been removed.")
    }
}

// MARK: - Window Manager for Preferences

