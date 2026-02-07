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

// MARK: - Feedback Types

enum FeedbackReportType: String {
    case bug
    case featureRequest = "feature_request"
    case performance
    case crash
    case general
}

// MARK: - Minimal Feedback Manager for PreferencesView

class SimpleFeedbackManager {
    static let shared = SimpleFeedbackManager()

    func getApplicationLogs() -> String? {
        guard let logsURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first else { return nil }
        let logFile = logsURL.appendingPathComponent("Logs/com.tonic.Tonic/system.log")

        guard FileManager.default.fileExists(atPath: logFile.path) else { return nil }

        do {
            let logContent = try String(contentsOf: logFile, encoding: .utf8)
            let logLines = logContent.split(separator: "\n").suffix(100).joined(separator: "\n")
            return logLines.isEmpty ? nil : logLines
        } catch {
            return nil
        }
    }

    func submitFeedback(
        type: FeedbackReportType,
        title: String,
        description: String,
        logs: String? = nil
    ) throws {
        let label = type == .bug ? "bug" : (type == .featureRequest ? "enhancement" : "feedback")
        let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Issue"
        let fullDescription = logs.map { "\(description)\n\nLogs:\n\($0)" } ?? description
        let encodedDescription = fullDescription.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        let gitHubURL = URL(string: "https://github.com/Saransh-Sharma/PreTonic/issues/new?title=\(encodedTitle)&labels=\(label)&body=\(encodedDescription)")!

        DispatchQueue.main.async {
            NSWorkspace.shared.open(gitHubURL)
        }
    }
}

// MARK: - Settings Navigation

enum SettingsSection: String, CaseIterable, Identifiable {
    case general = "General"
    case modules = "Modules"
    case permissions = "Permissions"
    case helper = "Helper"
    case updates = "Updates"
    case help = "Help"
    case about = "About"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape.fill"
        case .modules: return "square.grid.2x2.fill"
        case .permissions: return "hand.raised.fill"
        case .helper: return "wrench.and.screwdriver.fill"
        case .updates: return "arrow.down.circle.fill"
        case .help: return "bubble.right.fill"
        case .about: return "info.circle.fill"
        }
    }

    var description: String {
        switch self {
        case .general: return "Appearance and startup"
        case .modules: return "Widget configuration"
        case .permissions: return "System access"
        case .helper: return "Advanced features"
        case .updates: return "Software updates"
        case .help: return "Feedback and support"
        case .about: return "App information"
        }
    }
}

// MARK: - Main Preferences View

struct PreferencesView: View {
    @State private var selectedSection: SettingsSection = .general
    @State private var animateContent = false

    var body: some View {
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
        .background(DesignTokens.Colors.background)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                animateContent = true
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
            Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")")
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
                    case .helper:
                        HelperSettingsContent()
                    case .updates:
                        UpdatesSettingsContent()
                    case .help:
                        HelpSettingsContent()
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
        case .helper: return "Enable advanced system operations"
        case .updates: return "Keep Tonic up to date"
        case .help: return "Get help and send us feedback"
        case .about: return "Learn more about Tonic"
        }
    }
}


// MARK: - General Settings Content

struct GeneralSettingsContent: View {
    @State private var preferences = AppearancePreferences.shared
    @AppStorage("launchAtLogin") private var launchAtLogin = false

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
                        Text("Accent Color")
                            .font(DesignTokens.Typography.captionEmphasized)
                            .foregroundColor(DesignTokens.Colors.textSecondary)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DesignTokens.Spacing.sm), count: 5), spacing: DesignTokens.Spacing.sm) {
                            ForEach(AccentColor.allCases) { color in
                                AccentColorButton(color: color, isSelected: preferences.accentColor == color) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        preferences.setAccentColor(color)
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
                        Text("Color Palette")
                            .font(DesignTokens.Typography.captionEmphasized)
                            .foregroundColor(DesignTokens.Colors.textSecondary)

                        PalettePickerView(
                            selectedPalette: preferences.colorPalette,
                            onSelect: { palette in
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    preferences.setColorPalette(palette)
                                }
                            }
                        )
                    }
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .padding(.horizontal, DesignTokens.Spacing.md)
                }
            }

            // General Section
            PreferenceSection(header: "General") {
                PreferenceToggleRow(
                    title: "Launch at Login",
                    subtitle: "Automatically start Tonic when you log in",
                    icon: "power",
                    showDivider: true,
                    isOn: $launchAtLogin
                )

                PreferenceToggleRow(
                    title: "High Contrast Mode",
                    subtitle: "Use bold colors with maximum contrast (WCAG AAA)",
                    icon: "contrast",
                    showDivider: false,
                    isOn: Binding(
                        get: { preferences.useHighContrast },
                        set: { newValue in
                            preferences.setUseHighContrast(newValue)
                        }
                    )
                )
            }

            // Data Section
            PreferenceSection(header: "Data") {
                PreferenceButtonRow(
                    title: "Clear Cache",
                    subtitle: "Remove temporary files created by Tonic",
                    icon: "trash.fill",
                    showDivider: true,
                    buttonTitle: "Clear",
                    action: { /* Clear cache action */ }
                )

                PreferenceButtonRow(
                    title: "Reset Settings",
                    subtitle: "Restore all settings to their defaults",
                    icon: "arrow.counterclockwise",
                    showDivider: false,
                    buttonTitle: "Reset",
                    action: { /* Reset settings action */ }
                )
            }

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
                    action: { /* Reset app action */ }
                )
            }
        }
        .padding(DesignTokens.Spacing.lg)
    }
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

struct PermissionsSettingsContent: View {
    @State private var permissionManager = PermissionManager.shared
    @State private var isRefreshing = false

    var body: some View {
        PreferenceList {
            PreferenceSection(header: "Permissions Status") {
                HStack(spacing: DesignTokens.Spacing.md) {
                    PermissionStatusBadge(
                        count: grantedCount,
                        total: 3,
                        label: "Granted"
                    )

                    Spacer()

                    Button {
                        Task { await refreshPermissions() }
                    } label: {
                        HStack(spacing: DesignTokens.Spacing.xxs) {
                            if isRefreshing {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                            Text("Refresh")
                        }
                        .font(DesignTokens.Typography.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(isRefreshing)
                }
                .padding(.vertical, DesignTokens.Spacing.sm)
                .padding(.horizontal, DesignTokens.Spacing.md)
            }

            PreferenceSection(header: "System Access") {
                PermissionStatusRow(
                    title: "Full Disk Access",
                    subtitle: "Required to scan all files and folders on your Mac",
                    icon: "externaldrive.fill",
                    status: permissionManager.permissionStatuses[.fullDiskAccess] ?? .notDetermined
                )

                PermissionStatusRow(
                    title: "Accessibility",
                    subtitle: "Enables enhanced system monitoring and optimization",
                    icon: "hand.raised.fill",
                    status: permissionManager.permissionStatuses[.accessibility] ?? .notDetermined
                )

                PermissionStatusRow(
                    title: "Notifications",
                    subtitle: "Receive alerts about scan results and system warnings",
                    icon: "bell.fill",
                    status: permissionManager.permissionStatuses[.notifications] ?? .notDetermined,
                    showDivider: false
                )
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .task {
            await permissionManager.checkAllPermissions()
        }
    }

    private var grantedCount: Int {
        permissionManager.permissionStatuses.values.filter { $0 == .authorized }.count
    }

    private func refreshPermissions() async {
        isRefreshing = true
        await permissionManager.checkAllPermissions()
        try? await Task.sleep(nanoseconds: 300_000_000)
        isRefreshing = false
    }
}

// MARK: - Permission Status Badge

struct PermissionStatusBadge: View {
    let count: Int
    let total: Int
    let label: String

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            ZStack {
                Circle()
                    .stroke(DesignTokens.Colors.separator, lineWidth: 3)
                    .frame(width: 36, height: 36)

                Circle()
                    .trim(from: 0, to: CGFloat(count) / CGFloat(total))
                    .stroke(statusColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 36, height: 36)
                    .rotationEffect(.degrees(-90))

                Text("\(count)")
                    .font(DesignTokens.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(statusColor)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text("\(count) of \(total)")
                    .font(DesignTokens.Typography.subhead)
                    .fontWeight(.medium)
                    .foregroundColor(DesignTokens.Colors.textPrimary)

                Text(label)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
        }
    }

    private var statusColor: Color {
        switch count {
        case 0: return TonicColors.error
        case 1..<total: return TonicColors.warning
        default: return TonicColors.success
        }
    }
}

// MARK: - Permission Card

struct PermissionCard: View {
    let permission: TonicPermission
    let title: String
    let description: String
    let icon: String
    let isCritical: Bool
    let status: PermissionStatus
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium)
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(statusColor)
            }

            // Content
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Text(title)
                        .font(DesignTokens.Typography.subhead)
                        .fontWeight(.medium)
                        .foregroundColor(DesignTokens.Colors.textPrimary)

                    if isCritical {
                        Text("Required")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(TonicColors.accent.opacity(0.8))
                            .cornerRadius(4)
                    }
                }

                Text(description)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            // Status and action
            VStack(alignment: .trailing, spacing: DesignTokens.Spacing.xs) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)

                    Text(statusLabel)
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(statusColor)
                }

                if status != .authorized {
                    Button("Grant") {
                        action()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .accessibilityLabel("Grant \(title.lowercased()) permission")
                    .accessibilityHint("Opens System Settings to grant permission")
                }
            }
        }
        .padding(DesignTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.large)
                .fill(isHovered ? DesignTokens.Colors.unemphasizedSelectedContentBackground : DesignTokens.Colors.backgroundSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.large)
                .stroke(statusColor.opacity(status == .authorized ? 0.3 : 0.15), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .onHover { hovering in
            withAnimation(DesignTokens.Animation.fast) {
                isHovered = hovering
            }
        }
    }

    private var statusColor: Color {
        switch status {
        case .authorized: return TonicColors.success
        case .denied: return isCritical ? TonicColors.error : TonicColors.warning
        case .notDetermined: return DesignTokens.Colors.textTertiary
        }
    }

    private var statusLabel: String {
        switch status {
        case .authorized: return "Granted"
        case .denied: return "Denied"
        case .notDetermined: return "Not Set"
        }
    }
}

// MARK: - Helper Settings Content

struct HelperSettingsContent: View {
    @State private var helperManager = PrivilegedHelperManager.shared
    @State private var isInstalling = false
    @State private var isUninstalling = false
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        PreferenceList {
            // Status Section
            PreferenceSection(header: "Helper Tool") {
                HStack(spacing: DesignTokens.Spacing.md) {
                    // Animated status icon
                    ZStack {
                        Circle()
                            .fill(statusColor.opacity(0.15))
                            .frame(width: 44, height: 44)

                        if isInstalling || isUninstalling {
                            ProgressView()
                                .scaleEffect(0.9)
                        } else {
                            Image(systemName: helperManager.isHelperInstalled ? "checkmark.shield.fill" : "xmark.shield.fill")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(statusColor)
                        }
                    }

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
                        Text(isInstalling || isUninstalling ? "Processing..." : (helperManager.isHelperInstalled ? "Installed & Ready" : "Not Installed"))
                            .font(DesignTokens.Typography.subhead)
                            .foregroundColor(DesignTokens.Colors.textPrimary)

                        Text(helperManager.isHelperInstalled ? "All advanced features are available" : "Install to unlock advanced system features")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    }

                    Spacer()

                    // Status badge
                    if !isInstalling && !isUninstalling {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(statusColor)
                                .frame(width: 8, height: 8)

                            Text(helperManager.isHelperInstalled ? "Active" : "Inactive")
                                .font(DesignTokens.Typography.caption)
                                .fontWeight(.medium)
                                .foregroundColor(statusColor)
                        }
                    }
                }
                .padding(.vertical, DesignTokens.Spacing.sm)
                .padding(.horizontal, DesignTokens.Spacing.md)
            }

            // Features Section
            PreferenceSection(header: "Capabilities") {
                VStack(spacing: 0) {
                    SettingsHelperFeatureRow(
                        icon: "bolt.fill",
                        title: "System Optimization",
                        description: "Flush DNS cache, clear RAM, and rebuild system services",
                        color: TonicColors.warning
                    )
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .padding(.horizontal, DesignTokens.Spacing.md)

                    Divider()
                        .padding(.leading, DesignTokens.Spacing.md + 16 + DesignTokens.Spacing.sm)

                    SettingsHelperFeatureRow(
                        icon: "sparkles",
                        title: "Smart Scan",
                        description: "Run intelligent system scans and cleanup recommendations",
                        color: TonicColors.accent
                    )
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .padding(.horizontal, DesignTokens.Spacing.md)

                    Divider()
                        .padding(.leading, DesignTokens.Spacing.md + 16 + DesignTokens.Spacing.sm)

                    SettingsHelperFeatureRow(
                        icon: "eye.fill",
                        title: "Hidden Space Analysis",
                        description: "Access and analyze hidden system directories",
                        color: TonicColors.accent
                    )
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .padding(.horizontal, DesignTokens.Spacing.md)

                    Divider()
                        .padding(.leading, DesignTokens.Spacing.md + 16 + DesignTokens.Spacing.sm)

                    SettingsHelperFeatureRow(
                        icon: "shield.fill",
                        title: "Secure Operations",
                        description: "All operations run with minimal required privileges",
                        color: TonicColors.success
                    )
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .padding(.horizontal, DesignTokens.Spacing.md)
                }
            }

            // Action Section
            PreferenceSection(header: "Actions") {
                VStack(spacing: DesignTokens.Spacing.xs) {
                    if !helperManager.isHelperInstalled {
                        Button {
                            Task { await installHelper() }
                        } label: {
                            HStack(spacing: DesignTokens.Spacing.xs) {
                                if isInstalling {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "plus.circle.fill")
                                }
                                Text(isInstalling ? "Installing..." : "Install Helper Tool")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignTokens.Spacing.sm)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isInstalling)
                    } else {
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            Button {
                                Task { await reinstallHelper() }
                            } label: {
                                HStack(spacing: DesignTokens.Spacing.xxs) {
                                    if isInstalling {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                    } else {
                                        Image(systemName: "arrow.clockwise")
                                    }
                                    Text(isInstalling ? "Reinstalling..." : "Reinstall")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .disabled(isInstalling || isUninstalling)

                            Button {
                                Task { await uninstallHelper() }
                            } label: {
                                HStack(spacing: DesignTokens.Spacing.xxs) {
                                    if isUninstalling {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                    } else {
                                        Image(systemName: "trash")
                                    }
                                    Text(isUninstalling ? "Removing..." : "Uninstall")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(DesignTokens.Colors.destructive)
                            .disabled(isInstalling || isUninstalling)
                        }
                    }
                }
                .padding(.vertical, DesignTokens.Spacing.sm)
                .padding(.horizontal, DesignTokens.Spacing.md)
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .task {
            _ = helperManager.checkInstallationStatus()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { showError = false }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
    }

    private var statusColor: Color {
        if isInstalling || isUninstalling { return DesignTokens.Colors.textTertiary }
        return helperManager.isHelperInstalled ? DesignTokens.Colors.success : DesignTokens.Colors.destructive
    }

    private func installHelper() async {
        isInstalling = true
        do {
            try await helperManager.installHelper()
        } catch {
            errorMessage = "Installation failed: \(error.localizedDescription)"
            showError = true
        }
        isInstalling = false
    }

    private func reinstallHelper() async {
        isInstalling = true
        do {
            try await helperManager.uninstallHelper()
            try await Task.sleep(nanoseconds: 500_000_000)
            try await helperManager.installHelper()
        } catch {
            errorMessage = "Reinstallation failed: \(error.localizedDescription)"
            showError = true
        }
        isInstalling = false
    }

    private func uninstallHelper() async {
        isUninstalling = true
        do {
            try await helperManager.uninstallHelper()
        } catch {
            errorMessage = "Uninstallation failed: \(error.localizedDescription)"
            showError = true
        }
        isUninstalling = false
    }
}

// MARK: - Settings Helper Feature Row

struct SettingsHelperFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    let color: Color

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(color.opacity(0.15))
                    .frame(width: 32, height: 32)

                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DesignTokens.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundColor(DesignTokens.Colors.textPrimary)

                Text(description)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }

            Spacer()
        }
    }
}


// MARK: - Updates Settings Content

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
                        Text("Tonic is Up to Date")
                            .font(DesignTokens.Typography.subhead)
                            .foregroundColor(DesignTokens.Colors.textPrimary)

                        Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(DesignTokens.Colors.textSecondary)

                        if let lastChecked = lastChecked {
                            Text("Last checked: \(lastChecked, style: .relative) ago")
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(DesignTokens.Colors.textTertiary)
                        }
                    }

                    Spacer()

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
                .padding(.vertical, DesignTokens.Spacing.sm)
                .padding(.horizontal, DesignTokens.Spacing.md)
            }

            // Update Preferences Section
            PreferenceSection(header: "Preferences") {
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
            #if canImport(Sparkle)
            automaticallyChecksForUpdates = SparkleUpdater.shared.automaticallyChecksForUpdates
            #endif
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

struct FeedbackSheetView: View {
    @Environment(\.dismiss) var dismiss
    @State private var feedbackType: FeedbackReportType = .general
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var includeLogs = false
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                HStack(spacing: DesignTokens.Spacing.md) {
                    Image(systemName: "bubble.right.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(TonicColors.accent)

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
                        Text("Send Feedback")
                            .font(DesignTokens.Typography.h3)
                            .foregroundColor(DesignTokens.Colors.textPrimary)

                        Text("Help us improve Tonic by sharing your feedback")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    }

                    Spacer()
                }
                .padding(DesignTokens.Spacing.lg)
            }
            .background(DesignTokens.Colors.backgroundSecondary.opacity(0.5))

            Divider()

            // Content
            ScrollView {
                VStack(spacing: DesignTokens.Spacing.lg) {
                    // Feedback Type
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        Text("Feedback Type")
                            .font(DesignTokens.Typography.captionEmphasized)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                            .fontWeight(.medium)

                        Picker("Type", selection: $feedbackType) {
                            Text("General Feedback").tag(FeedbackReportType.general)
                            Text("Bug Report").tag(FeedbackReportType.bug)
                            Text("Feature Request").tag(FeedbackReportType.featureRequest)
                            Text("Performance Issue").tag(FeedbackReportType.performance)
                        }
                        .pickerStyle(.segmented)
                    }

                    // Title
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text("Title")
                            .font(DesignTokens.Typography.captionEmphasized)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                            .fontWeight(.medium)

                        TextField("Brief summary of your feedback", text: $title)
                            .font(DesignTokens.Typography.body)
                            .padding(DesignTokens.Spacing.sm)
                            .background(DesignTokens.Colors.backgroundSecondary)
                            .cornerRadius(DesignTokens.CornerRadius.medium)
                    }

                    // Description
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            Text("Description")
                                .font(DesignTokens.Typography.captionEmphasized)
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                                .fontWeight(.medium)

                            Spacer()

                            Text("\(description.count)/500")
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(DesignTokens.Colors.textTertiary)
                        }

                        TextEditor(text: $description)
                            .font(DesignTokens.Typography.body)
                            .scrollContentBackground(.hidden)
                            .background(DesignTokens.Colors.backgroundSecondary)
                            .cornerRadius(DesignTokens.CornerRadius.medium)
                            .frame(height: 120)
                            .onChange(of: description) { _, newValue in
                                if newValue.count > 500 {
                                    description = String(newValue.prefix(500))
                                }
                            }
                    }

                    // Include Logs
                    Toggle(isOn: $includeLogs) {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
                            Text("Include Application Logs")
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(DesignTokens.Colors.textPrimary)

                            Text("Help us diagnose issues faster by including recent logs")
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                        }
                    }

                    // System Info
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text("System Information")
                            .font(DesignTokens.Typography.captionEmphasized)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                            .fontWeight(.medium)

                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                            SystemInfoRow(label: "macOS Version", value: systemMacOSVersion)
                            SystemInfoRow(label: "App Version", value: appVersion)
                            SystemInfoRow(label: "Architecture", value: systemArchitecture)
                        }
                        .padding(DesignTokens.Spacing.sm)
                        .background(DesignTokens.Colors.backgroundSecondary)
                        .cornerRadius(DesignTokens.CornerRadius.medium)
                    }

                    if let error = errorMessage {
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(DesignTokens.Colors.error)

                            Text(error)
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(DesignTokens.Colors.error)

                            Spacer()
                        }
                        .padding(DesignTokens.Spacing.sm)
                        .background(DesignTokens.Colors.error.opacity(0.1))
                        .cornerRadius(DesignTokens.CornerRadius.medium)
                    }
                }
                .padding(DesignTokens.Spacing.lg)
            }

            Divider()

            // Footer
            HStack(spacing: DesignTokens.Spacing.md) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button {
                    submitFeedback()
                } label: {
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        if isSubmitting {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "paperplane.fill")
                        }
                        Text(isSubmitting ? "Sending..." : "Send Feedback")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSubmitting || title.trimmingCharacters(in: .whitespaces).isEmpty || description.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .frame(width: 500, height: 700)
        .alert("Success", isPresented: $showSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Thank you for your feedback! We appreciate your input.")
        }
    }

    private func submitFeedback() {
        isSubmitting = true
        errorMessage = nil

        Task {
            do {
                let logs = includeLogs ? SimpleFeedbackManager.shared.getApplicationLogs() : nil
                try SimpleFeedbackManager.shared.submitFeedback(
                    type: feedbackType,
                    title: title,
                    description: description,
                    logs: logs
                )
                await MainActor.run {
                    isSubmitting = false
                    showSuccess = true
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private var systemMacOSVersion: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }

    private var systemArchitecture: String {
        var sysinfo = utsname()
        uname(&sysinfo)
        // Convert Int8 array to UInt8 array for String(decodingCString:as:)
        let machineData = withUnsafeBytes(of: &sysinfo.machine) { rawBuffer in
            Data(rawBuffer)
        }
        return String(data: machineData, encoding: .utf8)?.trimmingCharacters(in: .controlCharacters) ?? "unknown"
    }
}

// MARK: - System Info Row

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

// MARK: - Help Settings Content

struct HelpSettingsContent: View {
    @State private var showFeedbackSheet = false

    var body: some View {
        PreferenceList {
            // Feedback Section
            PreferenceSection(header: "Give Feedback") {
                VStack(spacing: DesignTokens.Spacing.md) {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        Text("We'd love to hear from you!")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(DesignTokens.Colors.textPrimary)

                        Text("Share bug reports, feature suggestions, or any feedback to help us improve Tonic.")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    }

                    Button {
                        showFeedbackSheet = true
                    } label: {
                        HStack(spacing: DesignTokens.Spacing.xs) {
                            Image(systemName: "bubble.right.fill")
                            Text("Open Feedback Form")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignTokens.Spacing.sm)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.vertical, DesignTokens.Spacing.sm)
                .padding(.horizontal, DesignTokens.Spacing.md)
            }

            // Support Section
            PreferenceSection(header: "Support") {
                VStack(spacing: 0) {
                    HelpLinkRow(
                        title: "GitHub Issues",
                        subtitle: "Report bugs or suggest features on GitHub",
                        icon: "exclamationmark.bubble.fill",
                        url: "https://github.com/Saransh-Sharma/PreTonic/issues"
                    )
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .padding(.horizontal, DesignTokens.Spacing.md)

                    Divider()
                        .padding(.leading, DesignTokens.Spacing.md + 16 + DesignTokens.Spacing.sm)

                    HelpLinkRow(
                        title: "Documentation",
                        subtitle: "Learn more about Tonic's features",
                        icon: "book.fill",
                        url: "https://github.com/Saransh-Sharma/PreTonic/wiki"
                    )
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .padding(.horizontal, DesignTokens.Spacing.md)

                    Divider()
                        .padding(.leading, DesignTokens.Spacing.md + 16 + DesignTokens.Spacing.sm)

                    HelpLinkRow(
                        title: "Project Website",
                        subtitle: "Visit the Tonic project on GitHub",
                        icon: "globe",
                        url: "https://github.com/Saransh-Sharma/PreTonic"
                    )
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .padding(.horizontal, DesignTokens.Spacing.md)
                }
            }

            // Keyboard Shortcuts Section
            PreferenceSection(header: "Keyboard Shortcuts") {
                VStack(spacing: 0) {
                    ShortcutRow(title: "Open Feedback", shortcut: "⌘?")
                        .padding(.vertical, DesignTokens.Spacing.sm)
                        .padding(.horizontal, DesignTokens.Spacing.md)

                    Divider()
                        .padding(.leading, DesignTokens.Spacing.md)

                    ShortcutRow(title: "Open Command Palette", shortcut: "⌘K")
                        .padding(.vertical, DesignTokens.Spacing.sm)
                        .padding(.horizontal, DesignTokens.Spacing.md)
                }
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .sheet(isPresented: $showFeedbackSheet) {
            FeedbackSheetView()
        }
    }
}

// MARK: - Help Link Row

struct HelpLinkRow: View {
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
                            Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
                                .font(DesignTokens.Typography.subhead)
                                .foregroundColor(DesignTokens.Colors.textPrimary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
                            Text("Build")
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                            Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1")
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

// MARK: - Palette Picker

struct PalettePickerView: View {
    let selectedPalette: TonicColorPalette
    let onSelect: (TonicColorPalette) -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: DesignTokens.Spacing.sm), count: 4),
            spacing: DesignTokens.Spacing.sm
        ) {
            ForEach(TonicColorPalette.allCases) { palette in
                PaletteSwatchView(
                    palette: palette,
                    isSelected: selectedPalette == palette,
                    colorScheme: colorScheme
                ) {
                    onSelect(palette)
                }
            }
        }
    }
}

struct PaletteSwatchView: View {
    let palette: TonicColorPalette
    let isSelected: Bool
    let colorScheme: ColorScheme
    let action: () -> Void

    @State private var isHovered = false

    private var accent: TonicWorldModeColorToken { palette.primaryAccent }

    private var darkColor: Color { Color(hex: accent.darkHex) }
    private var midColor: Color { Color(hex: accent.midHex) }
    private var lightColor: Color { Color(hex: accent.lightHex) }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [darkColor, midColor, lightColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 36)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(
                                    isSelected
                                        ? lightColor.opacity(0.9)
                                        : (isHovered ? lightColor.opacity(0.4) : Color.clear),
                                    lineWidth: isSelected ? 2.5 : 1.5
                                )
                        )
                        .shadow(
                            color: isSelected ? lightColor.opacity(0.3) : .clear,
                            radius: 6, x: 0, y: 2
                        )

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                    }
                }

                Text(palette.displayName)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(
                        isSelected
                            ? DesignTokens.Colors.textPrimary
                            : DesignTokens.Colors.textSecondary
                    )
                    .lineLimit(1)
            }
            .scaleEffect(isHovered ? 1.04 : 1.0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(palette.displayName) palette\(isSelected ? ", selected" : "")")
        .accessibilityHint(palette.mood)
        .onHover { hovering in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Window Manager for Preferences

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
