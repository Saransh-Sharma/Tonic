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

// MARK: - Settings Navigation

enum SettingsSection: String, CaseIterable, Identifiable {
    case general = "General"
    case permissions = "Permissions"
    case helper = "Helper"
    case updates = "Updates"
    case about = "About"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape.fill"
        case .permissions: return "hand.raised.fill"
        case .helper: return "wrench.and.screwdriver.fill"
        case .updates: return "arrow.down.circle.fill"
        case .about: return "info.circle.fill"
        }
    }

    var description: String {
        switch self {
        case .general: return "Appearance and startup"
        case .permissions: return "System access"
        case .helper: return "Advanced features"
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
        HStack(spacing: 0) {
            // Sidebar
            settingsSidebar

            // Divider
            Rectangle()
                .fill(DesignTokens.Colors.border)
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
                Image(systemName: "drop.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.linearGradient(
                        colors: [TonicColors.accent, TonicColors.accent.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))

                Text("Settings")
                    .font(DesignTokens.Typography.headlineMedium)
                    .foregroundColor(DesignTokens.Colors.text)
            }
            .padding(.vertical, DesignTokens.Spacing.lg)
            .frame(maxWidth: .infinity)
            .background(DesignTokens.Colors.surface.opacity(0.5))

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
                .font(DesignTokens.Typography.captionSmall)
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .padding(.bottom, DesignTokens.Spacing.md)
        }
        .frame(width: 200)
        .background(DesignTokens.Colors.surface.opacity(0.3))
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
                    case .permissions:
                        PermissionsSettingsContent()
                    case .helper:
                        HelperSettingsContent()
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
                        .font(DesignTokens.Typography.bodyMedium)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundColor(isSelected ? .white : DesignTokens.Colors.text)

                    Text(section.description)
                        .font(DesignTokens.Typography.captionSmall)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : DesignTokens.Colors.textTertiary)
                }

                Spacer()
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium)
                    .fill(isSelected ? TonicColors.accent : (isHovered ? DesignTokens.Colors.surfaceHovered : Color.clear))
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
                    .font(DesignTokens.Typography.headlineLarge)
                    .foregroundColor(DesignTokens.Colors.text)

                Text(sectionSubtitle)
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }

            Spacer()
        }
        .padding(.bottom, DesignTokens.Spacing.sm)
    }

    private var sectionSubtitle: String {
        switch section {
        case .general: return "Customize how Tonic looks and behaves"
        case .permissions: return "Manage system permissions for full functionality"
        case .helper: return "Enable advanced system operations"
        case .updates: return "Keep Tonic up to date"
        case .about: return "Learn more about Tonic"
        }
    }
}

// MARK: - Settings Card Component

struct SettingsCard<Content: View>: View {
    let title: String?
    let icon: String?
    let content: Content

    init(title: String? = nil, icon: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            if let title = title {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(TonicColors.accent)
                    }

                    Text(title)
                        .font(DesignTokens.Typography.headlineSmall)
                        .foregroundColor(DesignTokens.Colors.text)
                }
            }

            content
        }
        .padding(DesignTokens.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.Colors.surface)
        .cornerRadius(DesignTokens.CornerRadius.large)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Settings Row Component

struct SettingsRow<Accessory: View>: View {
    let title: String
    let subtitle: String?
    let icon: String?
    let iconColor: Color
    let accessory: Accessory

    @State private var isHovered = false

    init(
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        iconColor: Color = TonicColors.accent,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.iconColor = iconColor
        self.accessory = accessory()
    }

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            if let icon = icon {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 32, height: 32)

                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(iconColor)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DesignTokens.Typography.bodyMedium)
                    .foregroundColor(DesignTokens.Colors.text)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(DesignTokens.Typography.captionMedium)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
            }

            Spacer()

            accessory
        }
        .padding(DesignTokens.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium)
                .fill(isHovered ? DesignTokens.Colors.surfaceHovered : Color.clear)
        )
        .onHover { hovering in
            withAnimation(DesignTokens.Animation.fast) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - General Settings Content

struct GeneralSettingsContent: View {
    @State private var preferences = AppearancePreferences.shared
    @AppStorage("launchAtLogin") private var launchAtLogin = false

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            // Appearance Card
            SettingsCard(title: "Appearance", icon: "paintbrush.fill") {
                VStack(spacing: DesignTokens.Spacing.md) {
                    // Theme selector
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        Text("Theme")
                            .font(DesignTokens.Typography.captionLarge)
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

                    Divider()
                        .padding(.vertical, DesignTokens.Spacing.xxs)

                    // Accent color
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        Text("Accent Color")
                            .font(DesignTokens.Typography.captionLarge)
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
                }
            }
            .fadeInSlideUp(delay: 0.05)

            // Startup Card
            SettingsCard(title: "Startup", icon: "power") {
                SettingsRow(
                    title: "Launch at Login",
                    subtitle: "Automatically start Tonic when you log in",
                    icon: "arrow.right.circle.fill",
                    iconColor: TonicColors.success
                ) {
                    Toggle("", isOn: $launchAtLogin)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
            }
            .fadeInSlideUp(delay: 0.1)

            // Data Management Card
            SettingsCard(title: "Data", icon: "internaldrive.fill") {
                VStack(spacing: DesignTokens.Spacing.xs) {
                    SettingsRow(
                        title: "Clear Cache",
                        subtitle: "Remove temporary files created by Tonic",
                        icon: "trash.fill",
                        iconColor: TonicColors.warning
                    ) {
                        Button("Clear") {
                            // Clear cache action
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    SettingsRow(
                        title: "Reset Settings",
                        subtitle: "Restore all settings to their defaults",
                        icon: "arrow.counterclockwise",
                        iconColor: TonicColors.error
                    ) {
                        Button("Reset") {
                            // Reset settings action
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
            .fadeInSlideUp(delay: 0.15)
        }
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
                                .stroke(isSelected ? TonicColors.accent : DesignTokens.Colors.border, lineWidth: isSelected ? 2 : 1)
                        )
                        .shadow(color: Color.black.opacity(isHovered ? 0.15 : 0.08), radius: isHovered ? 6 : 3, x: 0, y: 2)

                    // Icon
                    Image(systemName: mode.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(previewIconColor)
                }

                Text(mode.rawValue)
                    .font(DesignTokens.Typography.captionMedium)
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
        VStack(spacing: DesignTokens.Spacing.md) {
            // Status overview
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
                    .font(DesignTokens.Typography.bodySmall)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isRefreshing)
            }
            .padding(DesignTokens.Spacing.md)
            .background(DesignTokens.Colors.surface)
            .cornerRadius(DesignTokens.CornerRadius.large)
            .fadeInSlideUp(delay: 0.05)

            // Permission cards
            PermissionCard(
                permission: .fullDiskAccess,
                title: "Full Disk Access",
                description: "Required to scan all files and folders on your Mac for complete system analysis.",
                icon: "externaldrive.fill",
                isCritical: true,
                status: permissionManager.permissionStatuses[.fullDiskAccess] ?? .notDetermined
            ) {
                _ = permissionManager.requestFullDiskAccess()
            }
            .fadeInSlideUp(delay: 0.1)

            PermissionCard(
                permission: .accessibility,
                title: "Accessibility",
                description: "Enables enhanced system monitoring and optimization features.",
                icon: "hand.raised.fill",
                isCritical: false,
                status: permissionManager.permissionStatuses[.accessibility] ?? .notDetermined
            ) {
                _ = permissionManager.requestAccessibility()
            }
            .fadeInSlideUp(delay: 0.15)

            PermissionCard(
                permission: .notifications,
                title: "Notifications",
                description: "Receive alerts about scan results, system warnings, and updates.",
                icon: "bell.fill",
                isCritical: false,
                status: permissionManager.permissionStatuses[.notifications] ?? .notDetermined
            ) {
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
            }
            .fadeInSlideUp(delay: 0.2)
        }
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
                    .stroke(DesignTokens.Colors.border, lineWidth: 3)
                    .frame(width: 36, height: 36)

                Circle()
                    .trim(from: 0, to: CGFloat(count) / CGFloat(total))
                    .stroke(statusColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 36, height: 36)
                    .rotationEffect(.degrees(-90))

                Text("\(count)")
                    .font(DesignTokens.Typography.bodySmall)
                    .fontWeight(.semibold)
                    .foregroundColor(statusColor)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text("\(count) of \(total)")
                    .font(DesignTokens.Typography.bodyMedium)
                    .fontWeight(.medium)
                    .foregroundColor(DesignTokens.Colors.text)

                Text(label)
                    .font(DesignTokens.Typography.captionSmall)
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
                        .font(DesignTokens.Typography.bodyMedium)
                        .fontWeight(.medium)
                        .foregroundColor(DesignTokens.Colors.text)

                    if isCritical {
                        Text("Required")
                            .font(DesignTokens.Typography.captionSmall)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(TonicColors.accent.opacity(0.8))
                            .cornerRadius(4)
                    }
                }

                Text(description)
                    .font(DesignTokens.Typography.captionMedium)
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
                        .font(DesignTokens.Typography.captionMedium)
                        .foregroundColor(statusColor)
                }

                if status != .authorized {
                    Button("Grant") {
                        action()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }
        .padding(DesignTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.large)
                .fill(isHovered ? DesignTokens.Colors.surfaceHovered : DesignTokens.Colors.surface)
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
        VStack(spacing: DesignTokens.Spacing.md) {
            // Status card
            HelperStatusCard(
                isInstalled: helperManager.isHelperInstalled,
                isLoading: isInstalling || isUninstalling
            )
            .fadeInSlideUp(delay: 0.05)

            // Features card
            SettingsCard(title: "What You Can Do", icon: "sparkles") {
                VStack(spacing: DesignTokens.Spacing.sm) {
                    SettingsHelperFeatureRow(
                        icon: "bolt.fill",
                        title: "System Optimization",
                        description: "Flush DNS cache, clear RAM, and rebuild system services",
                        color: TonicColors.warning
                    )

                    SettingsHelperFeatureRow(
                        icon: "trash.fill",
                        title: "Deep Clean",
                        description: "Remove system-level cache and temporary files",
                        color: TonicColors.error
                    )

                    SettingsHelperFeatureRow(
                        icon: "eye.fill",
                        title: "Hidden Space Analysis",
                        description: "Access and analyze hidden system directories",
                        color: TonicColors.accent
                    )

                    SettingsHelperFeatureRow(
                        icon: "shield.fill",
                        title: "Secure Operations",
                        description: "All operations run with minimal required privileges",
                        color: TonicColors.success
                    )
                }
            }
            .fadeInSlideUp(delay: 0.1)

            // Action buttons
            HelperActionButtons(
                isInstalled: helperManager.isHelperInstalled,
                isInstalling: isInstalling,
                isUninstalling: isUninstalling,
                onInstall: { Task { await installHelper() } },
                onReinstall: { Task { await reinstallHelper() } },
                onUninstall: { Task { await uninstallHelper() } }
            )
            .fadeInSlideUp(delay: 0.15)
        }
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

// MARK: - Helper Status Card

struct HelperStatusCard: View {
    let isInstalled: Bool
    let isLoading: Bool

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            // Animated status icon
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 56, height: 56)

                if isLoading {
                    ProgressView()
                        .scaleEffect(1.2)
                } else {
                    Image(systemName: isInstalled ? "checkmark.shield.fill" : "xmark.shield.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(statusColor)
                }
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Text("Helper Tool Status")
                    .font(DesignTokens.Typography.captionLarge)
                    .foregroundColor(DesignTokens.Colors.textSecondary)

                Text(isLoading ? "Processing..." : (isInstalled ? "Installed & Ready" : "Not Installed"))
                    .font(DesignTokens.Typography.headlineSmall)
                    .foregroundColor(DesignTokens.Colors.text)

                Text(isInstalled ? "All advanced features are available" : "Install to unlock advanced system features")
                    .font(DesignTokens.Typography.captionMedium)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }

            Spacer()

            // Status badge
            if !isLoading {
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 10, height: 10)

                    Text(isInstalled ? "Active" : "Inactive")
                        .font(DesignTokens.Typography.captionMedium)
                        .fontWeight(.medium)
                        .foregroundColor(statusColor)
                }
                .padding(.horizontal, DesignTokens.Spacing.sm)
                .padding(.vertical, DesignTokens.Spacing.xs)
                .background(statusColor.opacity(0.15))
                .cornerRadius(DesignTokens.CornerRadius.round)
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.large)
                .fill(DesignTokens.Colors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.large)
                .stroke(statusColor.opacity(0.3), lineWidth: 1)
        )
    }

    private var statusColor: Color {
        if isLoading { return DesignTokens.Colors.textTertiary }
        return isInstalled ? TonicColors.success : TonicColors.error
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
                    .font(DesignTokens.Typography.bodySmall)
                    .fontWeight(.medium)
                    .foregroundColor(DesignTokens.Colors.text)

                Text(description)
                    .font(DesignTokens.Typography.captionSmall)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }

            Spacer()
        }
    }
}

// MARK: - Helper Action Buttons

struct HelperActionButtons: View {
    let isInstalled: Bool
    let isInstalling: Bool
    let isUninstalling: Bool
    let onInstall: () -> Void
    let onReinstall: () -> Void
    let onUninstall: () -> Void

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            if !isInstalled {
                Button(action: onInstall) {
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
                .controlSize(.large)
                .disabled(isInstalling)
            } else {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Button(action: onReinstall) {
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

                    Button(action: onUninstall) {
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
                    .tint(TonicColors.error)
                    .disabled(isInstalling || isUninstalling)
                }
            }
        }
        .padding(DesignTokens.Spacing.md)
        .background(DesignTokens.Colors.surface)
        .cornerRadius(DesignTokens.CornerRadius.large)
    }
}

// MARK: - Updates Settings Content

struct UpdatesSettingsContent: View {
    @AppStorage("automaticallyChecksForUpdates") private var automaticallyChecksForUpdates = true
    @AppStorage("allowBetaUpdates") private var allowBetaUpdates = false
    @State private var isCheckingForUpdates = false
    @State private var lastChecked: Date? = nil

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            // Current version card
            HStack(spacing: DesignTokens.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(.linearGradient(
                            colors: [TonicColors.accent, TonicColors.accent.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 56, height: 56)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    Text("Tonic is Up to Date")
                        .font(DesignTokens.Typography.headlineSmall)
                        .foregroundColor(DesignTokens.Colors.text)

                    Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0") (Build \(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"))")
                        .font(DesignTokens.Typography.bodySmall)
                        .foregroundColor(DesignTokens.Colors.textSecondary)

                    if let lastChecked = lastChecked {
                        Text("Last checked: \(lastChecked, style: .relative) ago")
                            .font(DesignTokens.Typography.captionSmall)
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
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text(isCheckingForUpdates ? "Checking..." : "Check Now")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isCheckingForUpdates)
            }
            .padding(DesignTokens.Spacing.lg)
            .background(DesignTokens.Colors.surface)
            .cornerRadius(DesignTokens.CornerRadius.large)
            .fadeInSlideUp(delay: 0.05)

            // Update preferences card
            SettingsCard(title: "Update Preferences", icon: "gearshape.fill") {
                VStack(spacing: DesignTokens.Spacing.xs) {
                    SettingsRow(
                        title: "Automatic Updates",
                        subtitle: "Check for updates automatically in the background",
                        icon: "arrow.triangle.2.circlepath",
                        iconColor: TonicColors.accent
                    ) {
                        Toggle("", isOn: $automaticallyChecksForUpdates)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .onChange(of: automaticallyChecksForUpdates) { _, newValue in
                                #if canImport(Sparkle)
                                SparkleUpdater.shared.automaticallyChecksForUpdates = newValue
                                #endif
                            }
                    }

                    Divider()
                        .padding(.vertical, DesignTokens.Spacing.xxs)

                    SettingsRow(
                        title: "Beta Updates",
                        subtitle: "Include pre-release versions (may be unstable)",
                        icon: "flask.fill",
                        iconColor: TonicColors.warning
                    ) {
                        Toggle("", isOn: $allowBetaUpdates)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                }
            }
            .fadeInSlideUp(delay: 0.1)

            // Release notes card
            SettingsCard(title: "What's New", icon: "doc.text.fill") {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    ReleaseNoteItem(
                        version: "0.1.0",
                        title: "Initial Release",
                        description: "Smart scan, deep clean, system monitoring, and menu bar widgets."
                    )
                }
            }
            .fadeInSlideUp(delay: 0.15)
        }
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
                .font(DesignTokens.Typography.captionMedium)
                .foregroundColor(TonicColors.accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(TonicColors.accent.opacity(0.15))
                .cornerRadius(4)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DesignTokens.Typography.bodySmall)
                    .fontWeight(.medium)
                    .foregroundColor(DesignTokens.Colors.text)

                Text(description)
                    .font(DesignTokens.Typography.captionMedium)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
        }
    }
}

// MARK: - About Settings Content

struct AboutSettingsContent: View {
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            // App hero card
            VStack(spacing: DesignTokens.Spacing.md) {
                // App icon with gradient
                ZStack {
                    Circle()
                        .fill(.linearGradient(
                            colors: [TonicColors.accent, TonicColors.pro],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 80, height: 80)
                        .shadow(color: TonicColors.accent.opacity(0.4), radius: 12, x: 0, y: 4)

                    Image(systemName: "drop.fill")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundColor(.white)
                }
                .scaleIn()

                VStack(spacing: DesignTokens.Spacing.xs) {
                    Text("Tonic")
                        .font(DesignTokens.Typography.displaySmall)
                        .foregroundColor(DesignTokens.Colors.text)

                    Text("A modern macOS system management utility")
                        .font(DesignTokens.Typography.bodyMedium)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                // Version badge
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")")
                        .font(DesignTokens.Typography.captionMedium)
                        .foregroundColor(DesignTokens.Colors.textSecondary)

                    Text("•")
                        .foregroundColor(DesignTokens.Colors.textTertiary)

                    Text("Build \(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1")")
                        .font(DesignTokens.Typography.captionMedium)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
            }
            .padding(DesignTokens.Spacing.xl)
            .frame(maxWidth: .infinity)
            .background(DesignTokens.Colors.surface)
            .cornerRadius(DesignTokens.CornerRadius.large)
            .fadeInSlideUp(delay: 0.05)

            // Links card
            SettingsCard(title: "Resources", icon: "link") {
                VStack(spacing: DesignTokens.Spacing.xs) {
                    AboutLinkRow(
                        title: "Website",
                        subtitle: "Visit the Tonic homepage",
                        icon: "globe",
                        url: "https://github.com/Saransh-Sharma/PreTonic"
                    )

                    AboutLinkRow(
                        title: "Report an Issue",
                        subtitle: "Help us improve by reporting bugs",
                        icon: "exclamationmark.bubble.fill",
                        url: "https://github.com/Saransh-Sharma/PreTonic/issues"
                    )

                    AboutLinkRow(
                        title: "License",
                        subtitle: "View the open source license",
                        icon: "doc.text.fill",
                        url: "https://github.com/Saransh-Sharma/PreTonic/blob/main/LICENSE"
                    )
                }
            }
            .fadeInSlideUp(delay: 0.1)

            // Credits card
            SettingsCard(title: "Made With", icon: "heart.fill") {
                HStack(spacing: DesignTokens.Spacing.lg) {
                    TechBadge(name: "Swift", icon: "swift", color: Color.orange)
                    TechBadge(name: "SwiftUI", icon: "rectangle.stack.fill", color: TonicColors.accent)
                    TechBadge(name: "macOS", icon: "apple.logo", color: DesignTokens.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }
            .fadeInSlideUp(delay: 0.15)

            // Copyright
            Text("© 2024 Tonic. All rights reserved.")
                .font(DesignTokens.Typography.captionSmall)
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .padding(.top, DesignTokens.Spacing.sm)
                .fadeIn(delay: 0.2)
        }
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
                        .font(DesignTokens.Typography.bodySmall)
                        .fontWeight(.medium)
                        .foregroundColor(DesignTokens.Colors.text)

                    Text(subtitle)
                        .font(DesignTokens.Typography.captionSmall)
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
                    .fill(isHovered ? DesignTokens.Colors.surfaceHovered : Color.clear)
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
                .font(DesignTokens.Typography.captionMedium)
                .foregroundColor(DesignTokens.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
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
