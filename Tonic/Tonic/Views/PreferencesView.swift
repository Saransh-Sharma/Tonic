//
//  PreferencesView.swift
//  Tonic
//
//  Beautiful settings experience with sidebar navigation
//

import SwiftUI
import UserNotifications

#if canImport(Sparkle)
import Sparkle
#endif

enum SettingsSection: String, CaseIterable, Identifiable {
    case general = "General"
    case modules = "Modules"
    case permissions = "Permissions"
    case updates = "Updates"
    case about = "About"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape.fill"
        case .modules: return "square.grid.2x2.fill"
        case .permissions: return "hand.raised.fill"
        case .updates: return "arrow.down.circle.fill"
        case .about: return "info.circle.fill"
        }
    }

    var description: String {
        switch self {
        case .general: return "Appearance"
        case .modules: return "Widget configuration"
        case .permissions: return BuildCapabilities.current.requiresScopeAccess ? "Access & permissions" : "System access"
        case .updates: return "Software updates"
        case .about: return "App information"
        }
    }
}

// MARK: - Main Preferences View

struct PreferencesView: View {
    @State private var selectedSection: SettingsSection = .general
    @State private var animateContent = false

    var body: some View {
        TonicThemeProvider(world: .protectionMagenta) {
            ZStack {
                WorldCanvasBackground()

                HStack(spacing: 0) {
                    // Sidebar
                    settingsSidebar

                    // Divider
                    Rectangle()
                        .fill(DesignTokens.Colors.separator)
                        .frame(width: 1)

                    // Content
                    settingsContent
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .atelierSurface(radius: AtelierLayout.radiusLg)
                .padding(12)
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.3)) {
                    animateContent = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .openSettingsSection)) { notification in
                guard let rawSection = notification.userInfo?[SettingsDeepLinkUserInfoKey.section] as? String,
                      let section = SettingsSection(rawValue: rawSection) else {
                    return
                }

                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    selectedSection = section
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .openModuleSettings)) { _ in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    selectedSection = .modules
                }
            }
        }
    }

    private var settingsSidebar: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: DesignTokens.Spacing.xs) {
                TonicBrandAssets.appImage()
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)

                Text("Settings")
                    .font(DesignTokens.Typography.h3)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
            }
            .padding(.vertical, DesignTokens.Spacing.lg)
            .frame(maxWidth: .infinity)
            .background(DesignTokens.Colors.backgroundSecondary.opacity(0.5))

            Divider()
                .padding(.horizontal, DesignTokens.Spacing.md)

            // Navigation items
            ScrollView {
                VStack(spacing: DesignTokens.Spacing.xs) {
                    ForEach(SettingsSection.allCases) { section in
                        SettingsSidebarItem(
                            section: section,
                            isSelected: selectedSection == section
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedSection = section
                            }
                        }
                    }
                }
                .padding(DesignTokens.Spacing.sm)
            }

            Spacer()

            // Version footer
            Text("Version \(Bundle.main.appVersion)")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .padding(.bottom, DesignTokens.Spacing.md)
        }
        .frame(width: 200)
        .background(DesignTokens.Colors.backgroundSecondary.opacity(0.3))
    }

    @ViewBuilder
    private var settingsContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Section header
                SettingsSectionHeader(section: selectedSection)
                    .padding(DesignTokens.Spacing.lg)

                // Section content
                Group {
                    switch selectedSection {
                    case .general:
                        GeneralSettingsContent()
                    case .modules:
                        ModulesSettingsContent()
                    case .permissions:
                        PermissionsSettingsContent()
                    case .updates:
                        UpdatesSettingsContent()
                    case .about:
                        AboutSettingsContent()
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .padding(.bottom, DesignTokens.Spacing.lg)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .id(selectedSection) // Force view refresh on section change
        .transition(.opacity.combined(with: .move(edge: .trailing)))
    }
}

// MARK: - Sidebar Item

struct SettingsSidebarItem: View {
    let section: SettingsSection
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                // Icon
                Image(systemName: section.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelected ? .white : DesignTokens.Colors.textSecondary)
                    .frame(width: 24, height: 24)

                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(section.rawValue)
                        .font(DesignTokens.Typography.subhead)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundColor(isSelected ? .white : DesignTokens.Colors.textPrimary)

                    Text(section.description)
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : DesignTokens.Colors.textTertiary)
                }

                Spacer()
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium)
                    .fill(isSelected ? TonicColors.accent : (isHovered ? DesignTokens.Colors.unemphasizedSelectedContentBackground : Color.clear))
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

// MARK: - Section Header

struct SettingsSectionHeader: View {
    let section: SettingsSection

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            // Icon with gradient background
            ZStack {
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium)
                    .fill(.linearGradient(
                        colors: [TonicColors.accent, TonicColors.accent.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 44, height: 44)

                Image(systemName: section.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Text(section.rawValue)
                    .font(DesignTokens.Typography.h1)
                    .foregroundColor(DesignTokens.Colors.textPrimary)

                Text(sectionSubtitle)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }

            Spacer()
        }
        .padding(.bottom, DesignTokens.Spacing.sm)
    }

    private var sectionSubtitle: String {
        switch section {
        case .general: return "Customize how Tonic looks and behaves"
        case .modules: return "Configure menu bar widgets"
        case .permissions: return "Manage system permissions for full functionality"
        case .updates: return "Keep Tonic up to date"
        case .about: return "Learn more about Tonic"
        }
    }
}


// MARK: - General Settings Content


class PreferencesWindowController: NSObject, NSWindowDelegate {
    static let shared = PreferencesWindowController()

    private var window: NSWindow?

    private override init() {
        super.init()
    }

    func showWindow() {
        if let window = window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            let contentView = PreferencesView()
            window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            window?.title = "Settings"
            window?.minSize = NSSize(width: 700, height: 500)
            window?.contentView = NSHostingView(rootView: contentView)
            window?.center()
            window?.makeKeyAndOrderFront(nil)
            window?.delegate = self
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}

// MARK: - Preview

#Preview {
    PreferencesView()
}
