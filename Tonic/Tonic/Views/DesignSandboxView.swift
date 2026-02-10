//
//  DesignSandboxView.swift
//  Tonic
//
//  A comprehensive showcase of all design components and their variants
//  Used for design validation, component testing, and developer reference
//

import SwiftUI

struct DesignSandboxView: View {
    @State private var selectedTab: SandboxTab = .theme

    enum SandboxTab {
        case theme
        case smartScan
        case menuWidgets
        case appManager
        case cards
        case metrics
        case preferences
        case buttons
        case status
        case misc

        var icon: String {
            switch self {
            case .theme: return "paintpalette"
            case .smartScan: return "sparkles"
            case .menuWidgets: return "menubar.rectangle"
            case .appManager: return "app.badge.fill"
            case .cards: return "square.grid.2x2"
            case .metrics: return "chart.line.uptrend.xyaxis"
            case .preferences: return "list.bullet"
            case .buttons: return "hand.tap"
            case .status: return "checkmark.circle"
            case .misc: return "sparkles"
            }
        }

        var label: String {
            switch self {
            case .theme: return "Theme"
            case .smartScan: return "Smart Scan"
            case .menuWidgets: return "Menu Widgets"
            case .appManager: return "App Manager"
            case .cards: return "Cards"
            case .metrics: return "Metrics"
            case .preferences: return "Preferences"
            case .buttons: return "Buttons"
            case .status: return "Status"
            case .misc: return "Misc"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: DesignTokens.Spacing.sm) {
                ForEach([SandboxTab.theme, .smartScan, .menuWidgets, .appManager, .cards, .metrics, .preferences, .buttons, .status, .misc], id: \.label) { tab in
                    VStack(spacing: DesignTokens.Spacing.xxxs) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 14, weight: .semibold))
                        Text(tab.label)
                            .font(DesignTokens.Typography.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .background(selectedTab == tab ? DesignTokens.Colors.accent.opacity(0.1) : Color.clear)
                    .foregroundColor(selectedTab == tab ? DesignTokens.Colors.accent : DesignTokens.Colors.textSecondary)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedTab = tab
                        }
                    }
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(DesignTokens.Colors.backgroundSecondary)

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    switch selectedTab {
                    case .theme:
                        ThemeSandboxShowcase()
                    case .smartScan:
                        SmartScanSandboxShowcase()
                    case .menuWidgets:
                        MenuWidgetsShowcase()
                    case .appManager:
                        AppManagerShowcase()
                    case .cards:
                        CardsShowcase()
                    case .metrics:
                        MetricsShowcase()
                    case .preferences:
                        PreferencesShowcase()
                    case .buttons:
                        ButtonsShowcase()
                    case .status:
                        StatusShowcase()
                    case .misc:
                        MiscShowcase()
                    }
                }
                .padding(DesignTokens.Spacing.lg)
            }
        }
        .background(DesignTokens.Colors.background)
    }
}

// MARK: - Card Variants Showcase

struct CardsShowcase: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            Text("Card Component")
                .font(DesignTokens.Typography.h2)

            Text("Interactive cards with semantic variants: elevated (shadow), flat (border), and inset (nested)")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            // Elevated variant
            SectionShowcase(title: "Elevated") {
                Card(variant: .elevated) {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            Image(systemName: "sparkles")
                                .font(.title2)
                                .foregroundColor(DesignTokens.Colors.accent)
                            Text("Elevated Card")
                                .font(DesignTokens.Typography.bodyEmphasized)
                        }
                        Text("Uses shadow for depth - perfect for primary content containers")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    }
                }
            }

            // Flat variant
            SectionShowcase(title: "Flat") {
                Card(variant: .flat) {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            Image(systemName: "rectangle.on.rectangle")
                                .font(.title2)
                                .foregroundColor(DesignTokens.Colors.info)
                            Text("Flat Card")
                                .font(DesignTokens.Typography.bodyEmphasized)
                        }
                        Text("Uses border only - for secondary content without shadow emphasis")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    }
                }
            }

            // Inset variant
            SectionShowcase(title: "Inset") {
                Card(variant: .inset) {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            Image(systemName: "rectangle.inset.filled")
                                .font(.title2)
                                .foregroundColor(DesignTokens.Colors.warning)
                            Text("Inset Card")
                                .font(DesignTokens.Typography.bodyEmphasized)
                        }
                        Text("Uses inset border - ideal for grouped or nested content")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    }
                }
            }
        }
    }
}

// MARK: - Metric Row Showcase

struct MetricsShowcase: View {
    @State private var updateFrequency = "5min"
    @State private var metric1Data = [0.3, 0.4, 0.35, 0.5, 0.45, 0.52, 0.51]
    @State private var metric2Data = [0.6, 0.62, 0.65, 0.7, 0.72, 0.75, 0.78]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            Text("MetricRow Component")
                .font(DesignTokens.Typography.h2)

            Text("Reusable rows for displaying system metrics with optional sparkline history")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            // Basic metric without sparkline
            SectionShowcase(title: "Basic Metric") {
                VStack(spacing: 0) {
                    MetricRow(
                        icon: "cpu",
                        title: "CPU Usage",
                        value: "45%",
                        iconColor: DesignTokens.Colors.accent
                    )
                    Divider()
                    MetricRow(
                        icon: "memorychip",
                        title: "Memory",
                        value: "8.2 GB / 16 GB",
                        iconColor: DesignTokens.Colors.info
                    )
                }
                .background(DesignTokens.Colors.backgroundSecondary)
                .cornerRadius(DesignTokens.CornerRadius.medium)
            }

            // Metrics with sparkline
            SectionShowcase(title: "With Sparkline") {
                VStack(spacing: 0) {
                    MetricRow(
                        icon: "memorychip",
                        title: "Memory Usage",
                        value: "8.2 GB",
                        iconColor: DesignTokens.Colors.info,
                        sparklineData: metric1Data,
                        sparklineColor: DesignTokens.Colors.info
                    )
                    Divider()
                    MetricRow(
                        icon: "internaldrive",
                        title: "Disk Usage",
                        value: "234 GB free",
                        iconColor: DesignTokens.Colors.warning,
                        sparklineData: metric2Data,
                        sparklineColor: DesignTokens.Colors.warning
                    )
                    Divider()
                    MetricRow(
                        icon: "network",
                        title: "Network Speed",
                        value: "12.5 MB/s",
                        iconColor: DesignTokens.Colors.success
                    )
                }
                .background(DesignTokens.Colors.backgroundSecondary)
                .cornerRadius(DesignTokens.CornerRadius.medium)
            }
        }
    }
}

// MARK: - Preference List Showcase

struct PreferencesShowcase: View {
    @State private var automaticUpdates = false
    @State private var selectedTheme = "System"

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            Text("PreferenceList Component")
                .font(DesignTokens.Typography.h2)

            Text("Grouped settings sections with various control types: toggles, pickers, buttons, status")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            PreferenceList {
                PreferenceSection(header: "General", footer: "These settings control app behavior.") {
                    PreferenceToggleRow(
                        title: "Automatic Updates",
                        subtitle: "Check for updates automatically",
                        icon: "arrow.triangle.2.circlepath",
                        showDivider: false,
                        isOn: $automaticUpdates
                    )
                }

                PreferenceSection(header: "Appearance") {
                    PreferencePickerRow(
                        title: "Theme",
                        subtitle: "Choose your preferred appearance",
                        icon: "paintbrush",
                        selection: $selectedTheme
                    ) {
                        Text("System").tag("System")
                        Text("Light").tag("Light")
                        Text("Dark").tag("Dark")
                    }
                    PreferenceStatusRow(
                        title: "Full Disk Access",
                        subtitle: "Required for complete scanning",
                        icon: "externaldrive",
                        iconColor: DesignTokens.Colors.success,
                        showDivider: false,
                        status: .healthy,
                        statusText: "Granted"
                    )
                }

                PreferenceSection(header: "Data", footer: "Use the danger zone in Settings for destructive actions.") {
                    PreferenceStatusRow(
                        title: "App Data",
                        subtitle: "Managed by Tonic automatically",
                        icon: "internaldrive",
                        iconColor: DesignTokens.Colors.info,
                        showDivider: false,
                        status: .healthy,
                        statusText: "Healthy"
                    )
                }
            }
        }
    }
}

// MARK: - Buttons Showcase

struct ButtonsShowcase: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            Text("Button Styles")
                .font(DesignTokens.Typography.h2)

            Text("Primary, secondary, and destructive button variants")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            SectionShowcase(title: "Primary Button") {
                PrimaryButton("Start Scan", icon: "play.fill") {
                    // Action
                }
            }

            SectionShowcase(title: "Secondary Button") {
                SecondaryButton("Cancel", icon: "xmark") {
                    // Action
                }
            }

            SectionShowcase(title: "Destructive Button") {
                Button("Delete", action: {})
                    .buttonStyle(.bordered)
                    .tint(DesignTokens.Colors.destructive)
            }

            SectionShowcase(title: "Progress Bar") {
                ProgressBar(value: 45, total: 100, color: DesignTokens.Colors.accent)
                    .padding(DesignTokens.Spacing.sm)
                    .background(DesignTokens.Colors.backgroundSecondary)
                    .cornerRadius(DesignTokens.CornerRadius.medium)
            }
        }
    }
}

// MARK: - Status Indicators Showcase

struct StatusShowcase: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            Text("Status Indicators")
                .font(DesignTokens.Typography.h2)

            Text("RAG status colors and indicators for permission states")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            SectionShowcase(title: "Status Indicators") {
                HStack(spacing: DesignTokens.Spacing.lg) {
                    StatusIndicator(level: .healthy)
                    StatusIndicator(level: .warning)
                    StatusIndicator(level: .critical)
                    StatusIndicator(level: .unknown)
                }
            }

            SectionShowcase(title: "Status Cards") {
                VStack(spacing: DesignTokens.Spacing.md) {
                    StatusCard(
                        icon: "checkmark.circle",
                        title: "Full Disk Access",
                        description: "Permission granted for system scanning",
                        status: .healthy
                    )
                    StatusCard(
                        icon: "exclamationmark.triangle",
                        title: "Helper Tool",
                        description: "Needs installation for optimization",
                        status: .warning,
                        action: { }
                    )
                    StatusCard(
                        icon: "xmark.circle",
                        title: "Accessibility",
                        description: "Required for system optimization",
                        status: .critical
                    )
                }
            }

            SectionShowcase(title: "Permission Status Row") {
                PermissionStatusRow(
                    title: "Full Disk Access",
                    subtitle: "Required for complete system scan",
                    icon: "externaldrive",
                    status: .authorized,
                    showDivider: false
                )
            }
        }
    }
}

// MARK: - Miscellaneous Components

struct MiscShowcase: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            Text("Other Components")
                .font(DesignTokens.Typography.h2)

            Text("Additional UI elements for various use cases")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            SectionShowcase(title: "Badges") {
                HStack(spacing: DesignTokens.Spacing.md) {
                    Badge(text: "New", size: .small)
                    Badge(text: "Badge", color: DesignTokens.Colors.info, size: .medium)
                    Badge(text: "Large Badge", color: DesignTokens.Colors.warning, size: .large)
                }
            }

            SectionShowcase(title: "Stat Card") {
                StatCard(
                    title: "Disk Usage",
                    value: "234 GB",
                    icon: "internaldrive.fill",
                    color: DesignTokens.Colors.warning
                )
            }

            SectionShowcase(title: "Empty State") {
                EmptyState(
                    icon: "tray.fill",
                    title: "No Items",
                    message: "There are no items to display"
                )
            }

            SectionShowcase(title: "Search Bar") {
                let searchText = ""
                SearchBar(text: .constant(searchText), placeholder: "Search...")
            }

            SectionShowcase(title: "Section Header") {
                SectionHeader(
                    title: "Recent Activity",
                    subtitle: "Your recent system activities",
                    action: { },
                    actionTitle: "View All"
                )
            }

            SectionShowcase(title: "Info Row") {
                VStack(spacing: 0) {
                    InfoRow(label: "Model", value: "MacBook Pro M1", icon: "macbook")
                    Divider()
                    InfoRow(label: "Memory", value: "16 GB", icon: "memorychip")
                    Divider()
                    InfoRow(label: "Storage", value: "500 GB SSD", icon: "internaldrive")
                }
                .background(DesignTokens.Colors.backgroundSecondary)
                .cornerRadius(DesignTokens.CornerRadius.medium)
            }
        }
    }
}

// MARK: - Theme Sandbox

struct ThemeSandboxShowcase: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            Text("Tonic Theme")
                .font(DesignTokens.Typography.h2)

            Text("Immersive world canvases, glass surfaces, typography, depth, and calm motion tokens.")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            SectionShowcase(title: "World Canvases") {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DesignTokens.Spacing.md) {
                    ForEach(TonicWorld.allCases) { world in
                        TonicThemeProvider(world: world) {
                            ZStack {
                                WorldCanvasBackground()
                                Text(worldLabel(world))
                                    .font(TonicTypeToken.caption.weight(.semibold))
                                    .foregroundStyle(TonicTextToken.primary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(TonicNeutralToken.white.opacity(0.14))
                                    .clipShape(Capsule())
                            }
                            .frame(height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                        }
                    }
                }
            }

            SectionShowcase(title: "Glass Surfaces") {
                TonicThemeProvider(world: .smartScanPurple) {
                    VStack(spacing: TonicSpaceToken.two) {
                        GlassCard {
                            Text("Glass Card")
                                .font(TonicTypeToken.caption.weight(.semibold))
                                .foregroundStyle(TonicTextToken.primary)
                        }
                        GlassPanel {
                            Text("Glass Panel")
                                .font(TonicTypeToken.caption.weight(.semibold))
                                .foregroundStyle(TonicTextToken.primary)
                        }
                        PageHeader(
                            title: "Glass Header",
                            subtitle: "Header variant",
                            showsBack: true,
                            searchText: nil,
                            onBack: {},
                            trailing: nil
                        )
                    }
                    .padding(TonicSpaceToken.two)
                    .background(WorldCanvasBackground())
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }

            SectionShowcase(title: "Typography Scale") {
                TonicThemeProvider(world: .smartScanPurple) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: TonicSpaceToken.two) {
                            DisplayText("Display")
                            TitleText("Title")
                            BodyText("Body text for paragraph content.")
                            CaptionText("Caption text")
                            MicroText("Micro text")
                        }
                    }
                    .background(WorldCanvasBackground())
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }

            SectionShowcase(title: "Shadow / Radius / Spacing") {
                TonicThemeProvider(world: .smartScanPurple) {
                    VStack(alignment: .leading, spacing: TonicSpaceToken.three) {
                        HStack(spacing: TonicSpaceToken.two) {
                            RoundedRectangle(cornerRadius: TonicRadiusToken.s)
                                .fill(TonicGlassToken.fill)
                                .frame(width: 70, height: 44)
                            RoundedRectangle(cornerRadius: TonicRadiusToken.m)
                                .fill(TonicGlassToken.fill)
                                .frame(width: 70, height: 44)
                            RoundedRectangle(cornerRadius: TonicRadiusToken.l)
                                .fill(TonicGlassToken.fill)
                                .frame(width: 70, height: 44)
                            RoundedRectangle(cornerRadius: TonicRadiusToken.xl)
                                .fill(TonicGlassToken.fill)
                                .frame(width: 70, height: 44)
                        }

                        Text("Spacing scale: 8, 12, 16, 24, 32, 48, 64")
                            .font(TonicTypeToken.micro)
                            .foregroundStyle(TonicTextToken.secondary)
                    }
                    .padding(TonicSpaceToken.three)
                    .background(WorldCanvasBackground())
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }

            SectionShowcase(title: "Motion Preview") {
                TonicThemeProvider(world: .smartScanPurple) {
                    VStack(spacing: TonicSpaceToken.three) {
                        Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                            .font(.system(size: 40, weight: .semibold))
                            .foregroundStyle(TonicTextToken.primary)
                            .breathingHero()

                        PrimaryActionButton(title: "Hover + Press", icon: "hand.tap", action: {})
                            .calmHover()
                    }
                    .padding(TonicSpaceToken.three)
                    .background(WorldCanvasBackground())
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }

    private func worldLabel(_ world: TonicWorld) -> String {
        switch world {
        case .smartScanPurple: return "Smart Scan Purple"
        case .cleanupGreen: return "Cleanup Green"
        case .clutterTeal: return "Clutter Teal"
        case .applicationsBlue: return "Applications Blue"
        case .performanceOrange: return "Performance Orange"
        case .protectionMagenta: return "Protection Magenta"
        }
    }
}

// MARK: - Smart Scan Sandbox

struct SmartScanSandboxShowcase: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            Text("Smart Scan Components")
                .font(DesignTokens.Typography.h2)

            Text("Bento layouts, command dock states, quick action overlays, and badge mapping.")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            SectionShowcase(title: "Glass Rendering Modes") {
                TonicThemeProvider(world: .smartScanPurple) {
                    VStack(spacing: TonicSpaceToken.three) {
                        VStack(alignment: .leading, spacing: TonicSpaceToken.two) {
                            Text("Legacy")
                                .font(TonicTypeToken.caption.weight(.semibold))
                                .foregroundStyle(TonicTextToken.primary)

                            GlassPanel(radius: TonicRadiusToken.xl) {
                                VStack(alignment: .leading, spacing: TonicSpaceToken.two) {
                                    Text("Smart Scan Legacy Glass")
                                        .font(TonicTypeToken.body.weight(.semibold))
                                        .foregroundStyle(TonicTextToken.primary)
                                    Text("Custom fill + stroke + highlight surface.")
                                        .font(TonicTypeToken.caption)
                                        .foregroundStyle(TonicTextToken.secondary)
                                }
                            }

                            SmartScanCommandDock(
                                mode: .results,
                                summary: "Recommended: 18 tasks • Space: 80.55 GB • Apps: 38 apps",
                                primaryEnabled: true,
                                secondaryTitle: "Customize",
                                onSecondaryAction: {},
                                action: {}
                            )
                        }
                        .tonicGlassRenderingMode(.legacy)
                        .tonicForceLegacyGlass(true)

                        VStack(alignment: .leading, spacing: TonicSpaceToken.two) {
                            Text("Liquid")
                                .font(TonicTypeToken.caption.weight(.semibold))
                                .foregroundStyle(TonicTextToken.primary)

                            GlassPanel(radius: TonicRadiusToken.xl) {
                                VStack(alignment: .leading, spacing: TonicSpaceToken.two) {
                                    Text("Smart Scan Liquid Glass")
                                        .font(TonicTypeToken.body.weight(.semibold))
                                        .foregroundStyle(TonicTextToken.primary)
                                    Text("Apple liquid glass surface on macOS 26+.")
                                        .font(TonicTypeToken.caption)
                                        .foregroundStyle(TonicTextToken.secondary)
                                }
                            }

                            SmartScanQuickActionCard(
                                sheet: demoQuickSheet,
                                progress: 0.33,
                                summary: nil,
                                isRunning: true,
                                onStart: {},
                                onStop: {},
                                onDone: {}
                            )
                        }
                        .tonicGlassRenderingMode(.liquid)
                        .tonicForceLegacyGlass(false)
                    }
                    .padding(TonicSpaceToken.two)
                    .background(WorldCanvasBackground())
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }

            SectionShowcase(title: "Command Dock States") {
                TonicThemeProvider(world: .smartScanPurple) {
                    VStack(spacing: TonicSpaceToken.two) {
                        SmartScanCommandDock(
                            mode: .ready,
                            summary: "Run Smart Scan across Space, Performance, and Apps.",
                            primaryEnabled: true,
                            secondaryTitle: nil,
                            onSecondaryAction: nil,
                            action: {}
                        )
                        SmartScanCommandDock(
                            mode: .scanning,
                            summary: "Scanning: 44% • Space: 32.4 GB • Performance: 12 items • Apps: 38 apps",
                            primaryEnabled: true,
                            secondaryTitle: nil,
                            onSecondaryAction: nil,
                            action: {}
                        )
                        SmartScanCommandDock(
                            mode: .results,
                            summary: "Recommended: 18 tasks • Space: 80.55 GB • Apps: 38 apps",
                            primaryEnabled: true,
                            secondaryTitle: "Customize",
                            onSecondaryAction: {},
                            action: {}
                        )
                    }
                    .padding(TonicSpaceToken.two)
                    .background(WorldCanvasBackground())
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }

            SectionShowcase(title: "Pillar Header Variants") {
                TonicThemeProvider(world: .smartScanPurple) {
                    VStack(spacing: TonicSpaceToken.two) {
                        PillarSectionHeader(
                            title: "Space",
                            subtitle: "Cleanup + Clutter",
                            summary: "107.47 GB reclaimable",
                            sectionActionTitle: "Review All Junk",
                            world: .cleanupGreen,
                            onSectionAction: {}
                        )
                        PillarSectionHeader(
                            title: "Performance",
                            subtitle: "Optimize + Startup Control",
                            summary: "23 items affecting startup",
                            sectionActionTitle: "View All Tasks",
                            world: .performanceOrange,
                            onSectionAction: {}
                        )
                        PillarSectionHeader(
                            title: "Apps",
                            subtitle: "Uninstall + Updates + Leftovers",
                            summary: "88 apps found",
                            sectionActionTitle: "Manage My Applications",
                            world: .applicationsBlue,
                            onSectionAction: {}
                        )
                    }
                    .padding(TonicSpaceToken.two)
                    .background(WorldCanvasBackground())
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }

            SectionShowcase(title: "Bento Grid Layout Matrix") {
                TonicThemeProvider(world: .smartScanPurple) {
                    VStack(spacing: TonicSpaceToken.three) {
                        BentoGrid(
                            world: .cleanupGreen,
                            tiles: demoSpaceTiles,
                            onReview: { _ in },
                            onAction: { _, _ in }
                        )
                        BentoGrid(
                            world: .performanceOrange,
                            tiles: demoPerformanceTiles,
                            onReview: { _ in },
                            onAction: { _, _ in }
                        )
                    }
                    .padding(TonicSpaceToken.two)
                    .background(WorldCanvasBackground())
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }

            SectionShowcase(title: "Bento Tile Actions") {
                TonicThemeProvider(world: .applicationsBlue) {
                    VStack(spacing: TonicSpaceToken.two) {
                        BentoTile(
                            model: demoAppsTiles[0],
                            world: .applicationsBlue,
                            onReview: { _ in },
                            onAction: { _, _ in }
                        )
                        BentoTile(
                            model: demoAppsTiles[2],
                            world: .applicationsBlue,
                            onReview: { _ in },
                            onAction: { _, _ in }
                        )
                    }
                    .padding(TonicSpaceToken.two)
                    .background(WorldCanvasBackground())
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }

            SectionShowcase(title: "Quick Action Card States") {
                TonicThemeProvider(world: .smartScanPurple) {
                    VStack(spacing: TonicSpaceToken.two) {
                        SmartScanQuickActionCard(
                            sheet: demoQuickSheet,
                            progress: 0,
                            summary: nil,
                            isRunning: false,
                            onStart: {},
                            onStop: {},
                            onDone: {}
                        )
                        SmartScanQuickActionCard(
                            sheet: demoQuickSheet,
                            progress: 0.47,
                            summary: nil,
                            isRunning: true,
                            onStart: {},
                            onStop: {},
                            onDone: {}
                        )
                        SmartScanQuickActionCard(
                            sheet: demoQuickSheet,
                            progress: 1,
                            summary: SmartScanRunSummary(tasksRun: 4, spaceFreed: 2_484_000_000, errors: 1, scoreImprovement: 6),
                            isRunning: false,
                            onStart: {},
                            onStop: {},
                            onDone: {}
                        )
                    }
                    .padding(TonicSpaceToken.two)
                    .background(WorldCanvasBackground())
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }

            SectionShowcase(title: "Full Results Composition") {
                TonicThemeProvider(world: .smartScanPurple) {
                    VStack(spacing: TonicSpaceToken.three) {
                        PillarSectionHeader(
                            title: "Space",
                            subtitle: "Cleanup + Clutter",
                            summary: "144 GB reclaimable",
                            sectionActionTitle: "Review All Junk",
                            world: .cleanupGreen,
                            onSectionAction: {}
                        )
                        BentoGrid(world: .cleanupGreen, tiles: demoSpaceTiles, onReview: { _ in }, onAction: { _, _ in })
                        PillarSectionHeader(
                            title: "Performance",
                            subtitle: "Optimize + Startup Control",
                            summary: "23 items affecting startup",
                            sectionActionTitle: "View All Tasks",
                            world: .performanceOrange,
                            onSectionAction: {}
                        )
                        BentoGrid(world: .performanceOrange, tiles: demoPerformanceTiles, onReview: { _ in }, onAction: { _, _ in })
                        PillarSectionHeader(
                            title: "Apps",
                            subtitle: "Uninstall + Updates + Leftovers",
                            summary: "88 apps found",
                            sectionActionTitle: "Manage My Applications",
                            world: .applicationsBlue,
                            onSectionAction: {}
                        )
                        BentoGrid(world: .applicationsBlue, tiles: demoAppsTiles, onReview: { _ in }, onAction: { _, _ in })
                    }
                    .padding(TonicSpaceToken.two)
                    .background(WorldCanvasBackground())
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }

            SectionShowcase(title: "Badge World Mapping") {
                TonicThemeProvider(world: .smartScanPurple) {
                    VStack(spacing: TonicSpaceToken.two) {
                        ScanTimelineStepper(
                            stages: ["Space", "Performance", "Apps"],
                            activeIndex: 1,
                            completed: [0]
                        )
                        HStack(spacing: TonicSpaceToken.two) {
                            LiveCounterChip(label: "Space", value: "32.4 GB")
                            LiveCounterChip(label: "Performance", value: "12 items")
                            LiveCounterChip(label: "Apps", value: "38 apps")
                        }
                    }
                    .padding(TonicSpaceToken.two)
                    .background(WorldCanvasBackground())
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }

    private var demoSpaceTiles: [SmartScanBentoTileModel] {
        [
            SmartScanBentoTileModel(
                id: .spaceSystemJunk,
                size: .large,
                metricTitle: "22.5 GB",
                title: "System Junk Found",
                subtitle: "Clean up all unneeded files generated by your system.",
                iconSymbols: ["gearshape.2.fill", "clock.fill", "person.crop.circle"],
                reviewTarget: .tile(.spaceSystemJunk),
                actions: [.init(title: "Review", kind: .review), .init(title: "Clean", kind: .clean)]
            ),
            SmartScanBentoTileModel(
                id: .spaceTrashBins,
                size: .wide,
                metricTitle: "327 MB",
                title: "Trash Bins Found",
                subtitle: "Delete trash bin contents for good.",
                iconSymbols: ["trash.fill"],
                reviewTarget: .tile(.spaceTrashBins),
                actions: [.init(title: "Review", kind: .review), .init(title: "Clean", kind: .clean)]
            ),
            SmartScanBentoTileModel(
                id: .spaceExtraBinaries,
                size: .small,
                metricTitle: "3.2 GB",
                title: "Extra Binaries Found",
                subtitle: "Binary artifacts detected.",
                iconSymbols: ["terminal.fill"],
                reviewTarget: .tile(.spaceExtraBinaries),
                actions: [.init(title: "Review", kind: .review)]
            ),
            SmartScanBentoTileModel(
                id: .spaceXcodeJunk,
                size: .small,
                metricTitle: "118 GB",
                title: "Xcode Junk Found",
                subtitle: "Developer caches and runtimes.",
                iconSymbols: ["hammer.fill", "chevron.left.forwardslash.chevron.right"],
                reviewTarget: .tile(.spaceXcodeJunk),
                actions: [.init(title: "Review", kind: .review)]
            )
        ]
    }

    private var demoPerformanceTiles: [SmartScanBentoTileModel] {
        [
            SmartScanBentoTileModel(
                id: .performanceMaintenanceTasks,
                size: .large,
                metricTitle: "5 Tasks",
                title: "Maintenance Tasks Recommended",
                subtitle: "Run weekly maintenance tasks to keep your Mac in shape.",
                iconSymbols: ["wrench.and.screwdriver.fill", "magnifyingglass"],
                reviewTarget: .tile(.performanceMaintenanceTasks),
                actions: [.init(title: "Review", kind: .review), .init(title: "Run Tasks", kind: .run)]
            ),
            SmartScanBentoTileModel(
                id: .performanceLoginItems,
                size: .wide,
                metricTitle: "6 Items",
                title: "You Have 6 Login Items",
                subtitle: "Review applications that open automatically when your Mac starts.",
                iconSymbols: ["shippingbox.fill", "app.fill", "chevron.left.forwardslash.chevron.right"],
                reviewTarget: .tile(.performanceLoginItems),
                actions: [.init(title: "Review", kind: .review)]
            ),
            SmartScanBentoTileModel(
                id: .performanceBackgroundItems,
                size: .wide,
                metricTitle: "17 Items",
                title: "Background Items Found",
                subtitle: "Review background processes allowed to run on your Mac.",
                iconSymbols: ["bolt.horizontal.circle.fill"],
                reviewTarget: .tile(.performanceBackgroundItems),
                actions: [.init(title: "Review", kind: .review)]
            )
        ]
    }

    private var demoAppsTiles: [SmartScanBentoTileModel] {
        [
            SmartScanBentoTileModel(
                id: .appsUpdates,
                size: .large,
                metricTitle: "17 Updates",
                title: "Application Updates Available",
                subtitle: "Update software to keep up with latest features.",
                iconSymbols: ["square.and.arrow.down.fill", "arrow.triangle.2.circlepath", "app.badge.fill"],
                reviewTarget: .tile(.appsUpdates),
                actions: [.init(title: "Review", kind: .review), .init(title: "Update", kind: .update)]
            ),
            SmartScanBentoTileModel(
                id: .appsUnused,
                size: .wide,
                metricTitle: "2 Apps",
                title: "Unused Applications Found",
                subtitle: "Unused apps still consume space on your Mac.",
                iconSymbols: ["folder.fill"],
                reviewTarget: .tile(.appsUnused),
                actions: [.init(title: "Review", kind: .review)]
            ),
            SmartScanBentoTileModel(
                id: .appsLeftovers,
                size: .small,
                metricTitle: "715 MB",
                title: "App Leftovers Found",
                subtitle: "Remove orphaned files.",
                iconSymbols: ["trash.square.fill"],
                reviewTarget: .tile(.appsLeftovers),
                actions: [.init(title: "Review", kind: .review), .init(title: "Remove", kind: .remove)]
            ),
            SmartScanBentoTileModel(
                id: .appsInstallationFiles,
                size: .small,
                metricTitle: "10.4 GB",
                title: "Installation Files Found",
                subtitle: "Installer payloads and archives.",
                iconSymbols: ["shippingbox.fill"],
                reviewTarget: .tile(.appsInstallationFiles),
                actions: [.init(title: "Review", kind: .review), .init(title: "Remove", kind: .remove)]
            )
        ]
    }

    private var demoQuickSheet: SmartScanQuickActionSheetState {
        SmartScanQuickActionSheetState(
            tileID: .spaceSystemJunk,
            action: .clean,
            scope: .tile(.spaceSystemJunk),
            title: "Clean System Junk",
            subtitle: "About to clean selected system junk files.",
            items: [],
            estimatedSpace: 2_484_000_000
        )
    }
}

// MARK: - Helper Components

struct SectionShowcase<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text(title)
                .font(DesignTokens.Typography.subhead)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            content
        }
    }
}

// MARK: - Menu Widgets Showcase

struct MenuWidgetsShowcase: View {
    @State private var unifiedMode = false
    @State private var activeWidgets: [WidgetConfiguration] = []
    @State private var availableWidgets: Set<WidgetType> = []
    @State private var hoveredWidget: WidgetType?

    private var previewData: [(config: WidgetConfiguration, value: String, sparkline: [Double])] {
        [
            (demoCPUConfig, "45%", [0.3, 0.4, 0.35, 0.5, 0.45, 0.52]),
            (demoMemoryConfig, "8.2 GB", [0.6, 0.62, 0.65, 0.7, 0.72, 0.75])
        ]
    }

    var body: some View {
        TonicThemeProvider(world: .protectionMagenta) {
            VStack(alignment: .leading, spacing: TonicSpaceToken.four) {
                headerSection

                componentsSection
                animationsSection
            }
            .padding(TonicSpaceToken.three)
            .background(WorldCanvasBackground())
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: TonicSpaceToken.two) {
            Text("Menu Bar Widgets Components")
                .font(DesignTokens.Typography.h2)

            Text("Widget-specific UI components and animations for the Menu Bar Widgets screen. Includes hero module, active/available widget cards, command dock, and interaction effects.")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(DesignTokens.Colors.textSecondary)
        }
    }

    private var componentsSection: some View {
        VStack(alignment: .leading, spacing: TonicSpaceToken.four) {
            heroModuleSection
            widgetCardsSection
            sourceTilesSection
            oneViewModeSection
            miniPreviewsSection
            commandDockSection
        }
    }

    private var heroModuleSection: some View {
        VStack(alignment: .leading, spacing: TonicSpaceToken.two) {
            Text("Widget Hero Module")
                .font(DesignTokens.Typography.subhead)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            HStack(spacing: TonicSpaceToken.three) {
                // Idle state
                WidgetHeroModule(
                    state: .idle,
                    activeIcons: []
                )

                // Active state
                WidgetHeroModule(
                    state: .active(count: 3),
                    activeIcons: ["cpu", "memorychip", "internaldrive", "wifi", "battery.100", "thermometer"]
                )
            }
        }
    }

    private var widgetCardsSection: some View {
        VStack(alignment: .leading, spacing: TonicSpaceToken.two) {
            Text("Widget Card (Active Widget)")
                .font(DesignTokens.Typography.subhead)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            WidgetCard(
                config: demoCPUConfig,
                sparklineData: [0.3, 0.4, 0.35, 0.5, 0.45, 0.52],
                currentValue: "45%",
                isDragging: false,
                isDropTarget: false,
                onSettings: {},
                onRemove: {}
            )
        }
    }

    private var sourceTilesSection: some View {
        VStack(alignment: .leading, spacing: TonicSpaceToken.two) {
            Text("Widget Source Tiles (Available Widgets)")
                .font(DesignTokens.Typography.subhead)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: TonicSpaceToken.two) {
                WidgetSourceTile(
                    type: .cpu,
                    isEnabled: availableWidgets.contains(.cpu),
                    description: "Real-time CPU usage with per-core breakdown"
                ) {
                    toggleWidget(.cpu)
                }

                WidgetSourceTile(
                    type: .memory,
                    isEnabled: availableWidgets.contains(.memory),
                    description: "Memory usage with pressure gauge and swap info"
                ) {
                    toggleWidget(.memory)
                }

                WidgetSourceTile(
                    type: .disk,
                    isEnabled: availableWidgets.contains(.disk),
                    description: "Disk usage, I/O stats, and SMART health"
                ) {
                    toggleWidget(.disk)
                }

                WidgetSourceTile(
                    type: .network,
                    isEnabled: availableWidgets.contains(.network),
                    description: "Network bandwidth with WiFi details"
                ) {
                    toggleWidget(.network)
                }
            }
        }
    }

    private var oneViewModeSection: some View {
        VStack(alignment: .leading, spacing: TonicSpaceToken.two) {
            Text("OneView Mode Card")
                .font(DesignTokens.Typography.subhead)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            OneViewModeCard(
                enabled: $unifiedMode,
                onToggle: { _ in }
            )
        }
    }

    private var miniPreviewsSection: some View {
        VStack(alignment: .leading, spacing: TonicSpaceToken.two) {
            Text("Widget Mini Previews")
                .font(DesignTokens.Typography.subhead)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            HStack(spacing: TonicSpaceToken.two) {
                ForEach(previewData, id: \.config.id) { item in
                    WidgetMiniPreview(
                        config: item.config,
                        value: item.value,
                        sparklineData: item.sparkline
                    )
                }
            }
        }
    }

    private var commandDockSection: some View {
        VStack(alignment: .leading, spacing: TonicSpaceToken.two) {
            Text("Widget Command Dock")
                .font(DesignTokens.Typography.subhead)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            WidgetCommandDock(
                activeWidgets: [demoCPUConfig, demoMemoryConfig],
                previewValues: previewData,
                onApply: {},
                onNotifications: {}
            )
        }
    }

    private var animationsSection: some View {
        VStack(alignment: .leading, spacing: TonicSpaceToken.four) {
            Text("Animation Effects")
                .font(DesignTokens.Typography.h3)

            Text("All 12 animation effects used in the Menu Widgets screen")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            animationShowcaseGrid
        }
    }

    private var animationShowcaseGrid: some View {
        VStack(alignment: .leading, spacing: TonicSpaceToken.three) {
            // Breathing hero with bloom
            animationDemoRow(
                title: "Breathing Hero + Bloom",
                description: "Continuous idle animation on hero icon"
            ) {
                Image(systemName: "menubar.dock.rectangle.badge.record")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(TonicTextToken.primary)
                    .heroBloom()
                    .breathingHero()
            }

            // Depth lift on hover
            animationDemoRow(
                title: "Depth Lift on Hover",
                description: "Hover this card to see depth effect"
            ) {
                Text("Hover me")
                    .font(TonicTypeToken.caption)
                    .foregroundStyle(TonicTextToken.primary)
                    .padding(TonicSpaceToken.two)
                    .glassSurface(radius: TonicRadiusToken.l, variant: .base)
                    .depthLift()
            }

            // Gear icon rotation
            animationDemoRow(
                title: "Gear Icon Rotation",
                description: "15-degree rotation on hover"
            ) {
                Button(action: {}) {
                    Image(systemName: "gear")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(TonicTextToken.secondary)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    // Handled internally by WidgetCard component
                }
            }

            // Staggered reveal
            animationDemoRow(
                title: "Staggered Reveal Cascade",
                description: "Sections animate in with staggered delay"
            ) {
                HStack(spacing: TonicSpaceToken.two) {
                    ForEach(0..<3) { index in
                        RoundedRectangle(cornerRadius: TonicRadiusToken.s)
                            .fill(TonicGlassToken.fill)
                            .frame(width: 40, height: 40)
                            .staggeredReveal(index: index)
                    }
                }
            }

            // Toggle spring feedback
            animationDemoRow(
                title: "Toggle Spring Feedback",
                description: "Micro-animation on toggle change"
            ) {
                Toggle("", isOn: .constant(true))
                    .toggleStyle(.switch)
            }

            // Numeric text transition
            animationDemoRow(
                title: "Numeric Text Transition",
                description: "Smooth number value transitions"
            ) {
                Text("45%")
                    .font(TonicTypeToken.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(TonicTextToken.primary)
                    .contentTransition(.numericText())
            }

            // Scale/opacity transitions
            animationDemoRow(
                title: "Scale + Opacity Transition",
                description: "Combined scale and opacity animation"
            ) {
                RoundedRectangle(cornerRadius: TonicRadiusToken.s)
                    .fill(TonicGlassToken.fill)
                    .frame(width: 40, height: 40)
                    .scaleEffect(1.0)
                    .opacity(1.0)
            }

            // Spring tap response
            animationDemoRow(
                title: "Spring Tap Response",
                description: "Elastic spring animation on tap"
            ) {
                Button("Tap Me") {}
                    .buttonStyle(.bordered)
            }

            // Live data pulse
            animationDemoRow(
                title: "Live Data Pulse",
                description: "Smooth path animation for sparklines"
            ) {
                WidgetMiniPreview(
                    config: demoCPUConfig,
                    value: "45%",
                    sparklineData: [0.3, 0.4, 0.35, 0.5, 0.45, 0.52]
                )
            }

            // Widget enable pop-in
            animationDemoRow(
                title: "Widget Enable Pop-in",
                description: "Scale 0.95→1 with spring animation"
            ) {
                WidgetSourceTile(
                    type: .battery,
                    isEnabled: true,
                    description: "Battery level with health info"
                ) {}
            }

            // Drag reorder with lift
            animationDemoRow(
                title: "Drag Reorder Lift",
                description: "Lift effect during drag & drop"
            ) {
                HStack(spacing: TonicSpaceToken.two) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(TonicTextToken.tertiary)
                    Text("Drag me")
                        .font(TonicTypeToken.caption)
                        .foregroundStyle(TonicTextToken.primary)
                }
                .padding(TonicSpaceToken.two)
                .glassSurface(radius: TonicRadiusToken.l, variant: .base)
                .scaleEffect(0.97)
                .opacity(0.8)
            }

            // Hero count bump
            animationDemoRow(
                title: "Hero Count Bump",
                description: "Scale 1.05 on count change"
            ) {
                CounterChip(
                    title: "3 active",
                    value: nil,
                    world: .protectionMagenta,
                    isActive: true
                )
            }
        }
    }

    private func animationDemoRow<Content: View>(
        title: String,
        description: String,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: TonicSpaceToken.two) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(TonicTypeToken.caption.weight(.semibold))
                    .foregroundStyle(TonicTextToken.primary)

                Text(description)
                    .font(TonicTypeToken.micro)
                    .foregroundStyle(TonicTextToken.tertiary)
            }

            content()
        }
    }

    private func toggleWidget(_ type: WidgetType) {
        if availableWidgets.contains(type) {
            availableWidgets.remove(type)
        } else {
            availableWidgets.insert(type)
        }
    }

    // MARK: - Demo Data

    private var demoCPUConfig: WidgetConfiguration {
        WidgetConfiguration(
            type: .cpu,
            visualizationType: .mini,
            isEnabled: true,
            position: 0,
            displayMode: .detailed,
            showLabel: false,
            valueFormat: .percentage,
            refreshInterval: .balanced,
            accentColor: .system
        )
    }

    private var demoMemoryConfig: WidgetConfiguration {
        WidgetConfiguration(
            type: .memory,
            visualizationType: .mini,
            isEnabled: true,
            position: 1,
            displayMode: .detailed,
            showLabel: false,
            valueFormat: .valueWithUnit,
            refreshInterval: .balanced,
            accentColor: .system
        )
    }
}

// MARK: - App Manager Showcase

struct AppManagerShowcase: View {
    @State private var selectedDemo: UUID?
    @State private var showScanningHero = false
    @State private var shimmerTrigger = false
    @State private var counterValue = 0
    @State private var floatDemo = true

    private var demoApps: [AppMetadata] {
        [
            AppMetadata(
                bundleIdentifier: "com.apple.Safari",
                appName: "Safari",
                path: URL(fileURLWithPath: "/Applications/Safari.app"),
                version: "17.4",
                totalSize: 142_000_000,
                category: .productivity,
                itemType: "app"
            ),
            AppMetadata(
                bundleIdentifier: "com.apple.dt.Xcode",
                appName: "Xcode",
                path: URL(fileURLWithPath: "/Applications/Xcode.app"),
                version: "16.2",
                totalSize: 12_800_000_000,
                category: .development,
                itemType: "app"
            ),
            AppMetadata(
                bundleIdentifier: "com.spotify.client",
                appName: "Spotify",
                path: URL(fileURLWithPath: "/Applications/Spotify.app"),
                version: "1.2.31",
                totalSize: 450_000_000,
                category: .social,
                itemType: "app"
            ),
        ]
    }

    private var demoLoginItems: [AppMetadata] {
        [
            AppMetadata(
                bundleIdentifier: "com.example.agent",
                appName: "Background Updater",
                path: URL(fileURLWithPath: "/Library/LaunchAgents/com.example.agent.plist"),
                itemType: "LaunchAgent"
            ),
            AppMetadata(
                bundleIdentifier: "com.example.daemon",
                appName: "System Helper",
                path: URL(fileURLWithPath: "/Library/LaunchDaemons/com.example.daemon.plist"),
                itemType: "LaunchDaemon"
            ),
            AppMetadata(
                bundleIdentifier: "com.example.login",
                appName: "Startup Manager",
                path: URL(fileURLWithPath: "/Applications/StartupManager.app"),
                itemType: "loginItem"
            ),
        ]
    }

    var body: some View {
        TonicThemeProvider(world: .applicationsBlue) {
            VStack(alignment: .leading, spacing: TonicSpaceToken.four) {
                headerSection
                componentsSection
                animationsSection
            }
            .padding(TonicSpaceToken.three)
            .background(WorldCanvasBackground())
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: TonicSpaceToken.two) {
            Text("App Manager Components")
                .font(DesignTokens.Typography.h2)

            Text("App Manager-specific UI components and animations. Includes hero module, app item cards, command dock, login item rows, summary tiles, and interaction effects.")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(DesignTokens.Colors.textSecondary)
        }
    }

    // MARK: - Components

    private var componentsSection: some View {
        VStack(alignment: .leading, spacing: TonicSpaceToken.four) {
            heroModuleSection
            appItemCardsSection
            commandDockSection
            loginItemRowsSection
            summaryTilesSection
        }
    }

    private var heroModuleSection: some View {
        VStack(alignment: .leading, spacing: TonicSpaceToken.two) {
            Text("App Hero Module")
                .font(DesignTokens.Typography.subhead)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            HStack(spacing: TonicSpaceToken.three) {
                // Idle state
                AppHeroModule(
                    state: .idle(appCount: 142, totalSize: 48_500_000_000, updatesAvailable: 3),
                    topAppIcons: []
                )

                // Scanning state
                AppHeroModule(
                    state: .scanning(progress: showScanningHero ? 0.65 : 0.2),
                    topAppIcons: []
                )
            }

            Button("Toggle Scan Progress") {
                withAnimation(TonicMotionToken.springTap) {
                    showScanningHero.toggle()
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private var appItemCardsSection: some View {
        VStack(alignment: .leading, spacing: TonicSpaceToken.two) {
            Text("App Item Card")
                .font(DesignTokens.Typography.subhead)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            ForEach(Array(demoApps.enumerated()), id: \.element.id) { index, app in
                AppItemCard(
                    app: app,
                    isSelected: selectedDemo == app.id,
                    hasUpdate: index == 0,
                    isProtected: index == 0,
                    formattedSize: ByteCountFormatter.string(fromByteCount: app.totalSize, countStyle: .file),
                    onTap: {
                        withAnimation(TonicMotionToken.springTap) {
                            selectedDemo = selectedDemo == app.id ? nil : app.id
                        }
                    },
                    onDetail: {},
                    onReveal: {}
                )
            }
        }
    }

    private var commandDockSection: some View {
        VStack(alignment: .leading, spacing: TonicSpaceToken.two) {
            Text("App Command Dock")
                .font(DesignTokens.Typography.subhead)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            AppCommandDock(
                selectedCount: 3,
                selectedSize: "1.2 GB",
                onUninstall: {},
                onReveal: {}
            )
        }
    }

    private var loginItemRowsSection: some View {
        VStack(alignment: .leading, spacing: TonicSpaceToken.two) {
            Text("Login Item Rows")
                .font(DesignTokens.Typography.subhead)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            ForEach(demoLoginItems) { item in
                LoginItemRow(item: item, onTap: {})
            }
        }
    }

    private var summaryTilesSection: some View {
        VStack(alignment: .leading, spacing: TonicSpaceToken.two) {
            Text("Summary Tiles")
                .font(DesignTokens.Typography.subhead)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            HStack(spacing: TonicSpaceToken.two) {
                SummaryTile(
                    title: "In Current View",
                    value: "142",
                    icon: "square.grid.2x2",
                    world: .applicationsBlue
                )

                SummaryTile(
                    title: "Total Size",
                    value: "48.5 GB",
                    icon: "externaldrive",
                    world: .cleanupGreen
                )

                SummaryTile(
                    title: "Updates Available",
                    value: "3",
                    icon: "arrow.down.circle",
                    world: .performanceOrange
                )
            }
        }
    }

    // MARK: - Animations

    private var animationsSection: some View {
        VStack(alignment: .leading, spacing: TonicSpaceToken.four) {
            Text("Animation Effects")
                .font(DesignTokens.Typography.h3)

            Text("Animations used in the App Manager screen")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            // Breathing hero with bloom
            animationDemoRow(
                title: "Breathing Hero + Bloom",
                description: "Continuous idle animation on hero icon"
            ) {
                Image(systemName: "app.badge.checkmark")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(TonicTextToken.primary)
                    .heroBloom()
                    .breathingHero()
            }

            // Depth lift on hover
            animationDemoRow(
                title: "Depth Lift on Hover",
                description: "Hover this card to see depth effect"
            ) {
                Text("Hover me")
                    .font(TonicTypeToken.caption)
                    .foregroundStyle(TonicTextToken.primary)
                    .padding(TonicSpaceToken.two)
                    .glassSurface(radius: TonicRadiusToken.l, variant: .base)
                    .depthLift()
            }

            // Icon shimmer
            animationDemoRow(
                title: "Icon Shimmer",
                description: "Metallic shimmer sweep on app icons"
            ) {
                Image(systemName: "app.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(TonicTextToken.primary)
                    .iconShimmer()
            }

            // Update pulse badge
            animationDemoRow(
                title: "Update Pulse Badge",
                description: "Continuous gentle pulse on update badges"
            ) {
                MetaBadge(style: .needsReview)
                    .updatePulseBadge()
            }

            // Empty state float
            animationDemoRow(
                title: "Empty State Float",
                description: "Gentle bobbing on empty state icons"
            ) {
                Image(systemName: "app.dashed")
                    .font(.system(size: 28))
                    .foregroundStyle(TonicTextToken.tertiary)
                    .emptyStateFloat()
            }

            // Scanning dots
            animationDemoRow(
                title: "Scanning Dots",
                description: "Sequential dot animation during scan"
            ) {
                ScanningDotsView()
            }

            // Staggered reveal
            animationDemoRow(
                title: "Staggered Reveal Cascade",
                description: "Sections animate in with staggered delay"
            ) {
                HStack(spacing: TonicSpaceToken.two) {
                    ForEach(0..<4) { index in
                        RoundedRectangle(cornerRadius: TonicRadiusToken.s)
                            .fill(TonicGlassToken.fill)
                            .frame(width: 40, height: 40)
                            .staggeredReveal(index: index)
                    }
                }
            }

            // Numeric text transition
            animationDemoRow(
                title: "Numeric Counter Roll",
                description: "Tap to see numeric text transition"
            ) {
                HStack(spacing: TonicSpaceToken.two) {
                    Text("\(counterValue) apps")
                        .font(TonicTypeToken.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(TonicTextToken.primary)
                        .contentTransition(.numericText())

                    Button("Count") {
                        withAnimation(TonicMotionToken.springTap) {
                            counterValue += Int.random(in: 5...20)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            // Selection ripple + checkbox
            animationDemoRow(
                title: "Selection Checkbox Pop",
                description: "Tap an app card above to see checkbox animation"
            ) {
                HStack(spacing: TonicSpaceToken.two) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(TonicTextToken.primary)
                    Text("Demonstrated in App Item Cards above")
                        .font(TonicTypeToken.micro)
                        .foregroundStyle(TonicTextToken.tertiary)
                }
            }
        }
    }

    private func animationDemoRow<Content: View>(
        title: String,
        description: String,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: TonicSpaceToken.two) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(TonicTypeToken.caption.weight(.semibold))
                    .foregroundStyle(TonicTextToken.primary)

                Text(description)
                    .font(TonicTypeToken.micro)
                    .foregroundStyle(TonicTextToken.tertiary)
            }

            content()
        }
    }
}

#Preview {
    DesignSandboxView()
        .background(DesignTokens.Colors.background)
}
