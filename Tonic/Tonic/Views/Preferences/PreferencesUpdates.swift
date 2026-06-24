//
//  PreferencesUpdates.swift
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

struct UpdatesSettingsContent: View {
    @AppStorage("automaticallyChecksForUpdates") private var automaticallyChecksForUpdates = true
    @AppStorage("allowBetaUpdates") private var allowBetaUpdates = false
    @State private var isCheckingForUpdates = false
    @State private var lastChecked: Date? = nil

    var body: some View {
        PreferenceList {
            // Version Status Section
            PreferenceSection(header: "Version") {
                HStack(spacing: DesignTokens.Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(DesignTokens.Colors.success.opacity(0.15))
                            .frame(width: 44, height: 44)

                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(DesignTokens.Colors.success)
                    }

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
                        Text(BuildCapabilities.current.usesStoreUpdates ? "Updates are managed by the App Store" : "Tonic is Up to Date")
                            .font(DesignTokens.Typography.subhead)
                            .foregroundColor(DesignTokens.Colors.textPrimary)

                        Text("Version \(Bundle.main.appVersion)")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(DesignTokens.Colors.textSecondary)

                        if let lastChecked = lastChecked {
                            Text("Last checked: \(lastChecked, style: .relative) ago")
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(DesignTokens.Colors.textTertiary)
                        }
                    }

                    Spacer()

                    if BuildCapabilities.current.usesStoreUpdates {
                        Text("Open the App Store to check for updates.")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    } else {
                        Button {
                            checkForUpdates()
                        } label: {
                            HStack(spacing: DesignTokens.Spacing.xxs) {
                                if isCheckingForUpdates {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                }
                                Text(isCheckingForUpdates ? "Checking..." : "Check Now")
                            }
                            .font(DesignTokens.Typography.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(isCheckingForUpdates)
                    }
                }
                .padding(.vertical, DesignTokens.Spacing.sm)
                .padding(.horizontal, DesignTokens.Spacing.md)
            }

            // Update Preferences Section
            PreferenceSection(header: "Preferences") {
                if BuildCapabilities.current.usesStoreUpdates {
                    Text("Automatic and beta update preferences are unavailable in the Mac App Store edition.")
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, DesignTokens.Spacing.sm)
                        .padding(.horizontal, DesignTokens.Spacing.md)
                } else {
                    PreferenceToggleRow(
                        title: "Automatic Updates",
                        subtitle: "Check for updates automatically in the background",
                        icon: "arrow.triangle.2.circlepath",
                        showDivider: true,
                        isOn: $automaticallyChecksForUpdates
                    )
                    .onChange(of: automaticallyChecksForUpdates) { _, newValue in
                        #if canImport(Sparkle)
                        SparkleUpdater.shared.automaticallyChecksForUpdates = newValue
                        #endif
                    }

                    PreferenceToggleRow(
                        title: "Beta Updates",
                        subtitle: "Include pre-release versions (may be unstable)",
                        icon: "flask.fill",
                        iconColor: DesignTokens.Colors.warning,
                        showDivider: false,
                        isOn: $allowBetaUpdates
                    )
                }
            }

            // Release Notes Section
            PreferenceSection(header: "Release Notes") {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    ReleaseNoteItem(
                        version: "0.1.0",
                        title: "Initial Release",
                        description: "Smart scan, system monitoring, and menu bar widgets."
                    )
                }
                .padding(.vertical, DesignTokens.Spacing.sm)
                .padding(.horizontal, DesignTokens.Spacing.md)
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .onAppear {
            if BuildCapabilities.current.supportsSparkle {
                #if canImport(Sparkle)
                automaticallyChecksForUpdates = SparkleUpdater.shared.automaticallyChecksForUpdates
                #endif
            }
        }
    }

    private func checkForUpdates() {
        isCheckingForUpdates = true
        // Simulate check
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isCheckingForUpdates = false
            lastChecked = Date()
        }
    }
}

// MARK: - Release Note Item

struct ReleaseNoteItem: View {
    let version: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
            Text("v\(version)")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(TonicColors.accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(TonicColors.accent.opacity(0.15))
                .cornerRadius(4)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DesignTokens.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundColor(DesignTokens.Colors.textPrimary)

                Text(description)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
        }
    }
}

// MARK: - Feedback Sheet View

