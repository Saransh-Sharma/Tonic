//
//  PreferencesAbout.swift
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

struct SystemInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Text(label)
                .font(DesignTokens.Typography.caption)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            Spacer()

            Text(value)
                .font(DesignTokens.Typography.caption)
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Shortcut Row

struct ShortcutRow: View {
    let title: String
    let shortcut: String

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Text(title)
                .font(DesignTokens.Typography.caption)
                .foregroundColor(DesignTokens.Colors.textPrimary)

            Spacer()

            Text(shortcut)
                .font(DesignTokens.Typography.caption)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(DesignTokens.Colors.backgroundSecondary)
                .cornerRadius(4)
        }
    }
}

// MARK: - About Settings Content

struct AboutSettingsContent: View {
    var body: some View {
        PreferenceList {
            // App Info Section
            PreferenceSection(header: "About") {
                VStack(spacing: DesignTokens.Spacing.md) {
                    // App icon with gradient
                    ZStack {
                        TonicBrandAssets.appImage()
                            .resizable()
                            .scaledToFit()
                            .frame(width: 64, height: 64)
                    }

                    VStack(spacing: DesignTokens.Spacing.xxxs) {
                        Text("Tonic")
                            .font(DesignTokens.Typography.h1)
                            .foregroundColor(DesignTokens.Colors.textPrimary)

                        Text("A modern macOS system management utility")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    // Version info
                    HStack(spacing: DesignTokens.Spacing.md) {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
                            Text("Version")
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                            Text(Bundle.main.appVersion)
                                .font(DesignTokens.Typography.subhead)
                                .foregroundColor(DesignTokens.Colors.textPrimary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
                            Text("Build")
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                            Text(Bundle.main.buildNumber)
                                .font(DesignTokens.Typography.subhead)
                                .foregroundColor(DesignTokens.Colors.textPrimary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.top, DesignTokens.Spacing.sm)
                }
                .padding(.vertical, DesignTokens.Spacing.md)
                .padding(.horizontal, DesignTokens.Spacing.md)
                .frame(maxWidth: .infinity)
            }

            // Resources Section
            PreferenceSection(header: "Resources") {
                VStack(spacing: 0) {
                    AboutLinkRow(
                        title: "Website",
                        subtitle: "Visit the Tonic homepage",
                        icon: "globe",
                        url: "https://github.com/Saransh-Sharma/PreTonic"
                    )
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .padding(.horizontal, DesignTokens.Spacing.md)

                    Divider()
                        .padding(.leading, DesignTokens.Spacing.md + 16 + DesignTokens.Spacing.sm)

                    AboutLinkRow(
                        title: "Report an Issue",
                        subtitle: "Help us improve by reporting bugs",
                        icon: "exclamationmark.bubble.fill",
                        url: "https://github.com/Saransh-Sharma/PreTonic/issues"
                    )
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .padding(.horizontal, DesignTokens.Spacing.md)

                    Divider()
                        .padding(.leading, DesignTokens.Spacing.md + 16 + DesignTokens.Spacing.sm)

                    AboutLinkRow(
                        title: "License",
                        subtitle: "View the open source license",
                        icon: "doc.text.fill",
                        url: "https://github.com/Saransh-Sharma/PreTonic/blob/main/LICENSE"
                    )
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .padding(.horizontal, DesignTokens.Spacing.md)
                }
            }

            // Technologies Section
            PreferenceSection(header: "Built With") {
                HStack(spacing: DesignTokens.Spacing.lg) {
                    TechBadge(name: "Swift", icon: "swift", color: Color.orange)
                    TechBadge(name: "SwiftUI", icon: "rectangle.stack.fill", color: TonicColors.accent)
                    TechBadge(name: "macOS", icon: "apple.logo", color: DesignTokens.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.Spacing.md)
                .padding(.horizontal, DesignTokens.Spacing.md)
            }

            if BuildCapabilities.current.requiresScopeAccess {
                PreferenceSection(header: "Advanced Maintenance") {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        Image(systemName: "info.circle")
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Some low-level maintenance tasks are limited in the App Store edition.")
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(DesignTokens.Colors.textPrimary)
                            Link("Learn about direct edition capabilities", destination: URL(string: "https://github.com/Saransh-Sharma/PreTonic")!)
                                .font(DesignTokens.Typography.caption)
                        }
                        Spacer()
                    }
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .padding(.horizontal, DesignTokens.Spacing.md)
                }
            }

            // Copyright
            VStack {
                Text("© 2024 Tonic. All rights reserved.")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
        }
        .padding(DesignTokens.Spacing.lg)
    }
}

// MARK: - About Link Row

struct AboutLinkRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let url: String

    @State private var isHovered = false

    var body: some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(TonicColors.accent.opacity(0.15))
                        .frame(width: 32, height: 32)

                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(TonicColors.accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(DesignTokens.Typography.caption)
                        .fontWeight(.medium)
                        .foregroundColor(DesignTokens.Colors.textPrimary)

                    Text(subtitle)
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            .padding(DesignTokens.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium)
                    .fill(isHovered ? DesignTokens.Colors.unemphasizedSelectedContentBackground : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(DesignTokens.Animation.fast) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Tech Badge

struct TechBadge: View {
    let name: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(color)

            Text(name)
                .font(DesignTokens.Typography.caption)
                .foregroundColor(DesignTokens.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Luxury Theme System

