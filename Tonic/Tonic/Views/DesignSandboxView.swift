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
                ForEach([SandboxTab.theme, .smartScan, .cards, .metrics, .preferences, .buttons, .status, .misc], id: \.label) { tab in
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
    @State private var launchAtLogin = true
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
                        title: "Launch at Login",
                        subtitle: "Start Tonic when you log in",
                        icon: "power",
                        isOn: $launchAtLogin
                    )
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

                PreferenceSection(header: "Data") {
                    PreferenceButtonRow(
                        title: "Clear Cache",
                        subtitle: "Remove temporary files",
                        icon: "trash",
                        iconColor: DesignTokens.Colors.warning,
                        buttonTitle: "Clear",
                        buttonStyle: .secondary
                    ) {
                        // Action
                    }
                    PreferenceButtonRow(
                        title: "Reset All Settings",
                        subtitle: "Restore default configuration",
                        icon: "arrow.counterclockwise",
                        iconColor: DesignTokens.Colors.destructive,
                        showDivider: false,
                        buttonTitle: "Reset",
                        buttonStyle: .destructive
                    ) {
                        // Action
                    }
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
    @State private var query = ""
    @State private var includeInAction = true
    @State private var permanentDelete = false
    @State private var selectedAppFilter: AppFilter = .all
    @State private var selectedRowA = false
    @State private var selectedRowB = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            Text("Smart Scan Components")
                .font(DesignTokens.Typography.h2)

            Text("Hub, managers, shell layout, rows, actions, and safety patterns.")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            SectionShowcase(title: "Hub Hero States") {
                TonicThemeProvider(world: .smartScanPurple) {
                    VStack(spacing: TonicSpaceToken.two) {
                        ScanHeroModule(state: .ready)
                        ScanHeroModule(state: .scanning(progress: 0.44))
                        ScanHeroModule(state: .results(space: "80.55 GB", performance: "18 items", apps: "38 apps"))
                    }
                    .padding(TonicSpaceToken.two)
                    .background(WorldCanvasBackground())
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }

            SectionShowcase(title: "Timeline + Live Counters") {
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

            SectionShowcase(title: "Result Pillar Cards") {
                TonicThemeProvider(world: .smartScanPurple) {
                    ResultPillarCard(
                        title: "Space",
                        metric: "80.55 GB",
                        summary: "Cleanup + Clutter",
                        preview: [
                            ResultContributor(id: "xcodeJunk", title: "Xcode Junk", subtitle: "Developer artifacts", metric: "40.5 GB"),
                            ResultContributor(id: "downloads", title: "Downloads", subtitle: "Old downloads", metric: "18.2 GB"),
                            ResultContributor(id: "duplicates", title: "Duplicates", subtitle: "Duplicate file groups", metric: "448 MB")
                        ],
                        reviewTitle: "Review Space",
                        onReviewSection: {},
                        onReviewContributor: { _ in }
                    )
                    .padding(TonicSpaceToken.two)
                    .background(WorldCanvasBackground())
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }

            SectionShowcase(title: "ManagerShell States") {
                TonicThemeProvider(world: .cleanupGreen) {
                    ManagerShell(
                        header: AnyView(
                            PageHeader(
                                title: "Space Manager",
                                subtitle: "Three-pane shell",
                                showsBack: true,
                                searchText: $query,
                                onBack: {},
                                trailing: nil
                            )
                        ),
                        left: {
                            LeftNavPane {
                                LeftNavListItem(title: "System Junk", count: 4, isSelected: true, action: {})
                                LeftNavListItem(title: "Downloads", count: 2, isSelected: false, action: {})
                            }
                        },
                        middle: {
                            MiddleSummaryPane {
                                SectionSummaryCard(
                                    title: "System Junk",
                                    description: "Subcategory summary",
                                    metrics: ["All: 8", "Selected: 2", "Space: 12.3 GB"]
                                )
                            }
                        },
                        right: {
                            RightItemsPane {
                                ManagerSummaryStrip(text: "Xcode Junk · 11.2 GB · Safe: 2 · Needs review: 1")
                                SelectableRow(
                                    icon: "hammer",
                                    title: "Derived Data",
                                    subtitle: "Build artifacts",
                                    metric: "8.1 GB",
                                    isSelected: true,
                                    onSelect: {},
                                    onToggle: {}
                                )
                            }
                        },
                        footer: AnyView(
                            StickyActionBar(
                                summary: "Selected: 2 items · 8.1 GB",
                                variant: .cleanUp,
                                enabled: true,
                                action: {}
                            )
                        )
                    )
                    .padding(TonicSpaceToken.two)
                    .background(WorldCanvasBackground())
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }

            SectionShowcase(title: "Row Behavior Matrix") {
                TonicThemeProvider(world: .applicationsBlue) {
                    VStack(spacing: TonicSpaceToken.one) {
                        SelectableRow(
                            icon: "trash",
                            title: "Direct cleanable row",
                            subtitle: "Checkbox only",
                            metric: "2.4 GB",
                            isSelected: selectedRowA,
                            onSelect: {},
                            onToggle: { selectedRowA.toggle() }
                        )

                        DrilldownRow(
                            icon: "folder",
                            title: "Drilldown row",
                            subtitle: "Chevron only",
                            metric: "14 groups",
                            action: {}
                        )

                        HybridRow(
                            icon: "app.badge",
                            title: "Hybrid row",
                            subtitle: "Row opens details, checkbox selects",
                            metric: "4.8 GB",
                            isSelected: selectedRowB,
                            badges: [.unused, .large],
                            onSelect: {},
                            onToggle: { selectedRowB.toggle() }
                        )
                    }
                    .padding(TonicSpaceToken.two)
                    .background(WorldCanvasBackground())
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }

            SectionShowcase(title: "StickyActionBar Variants") {
                TonicThemeProvider(world: .performanceOrange) {
                    VStack(spacing: TonicSpaceToken.one) {
                        StickyActionBar(summary: "Cleanup selection", variant: .cleanUp, enabled: true, action: {})
                        StickyActionBar(summary: "Run tasks", variant: .run, enabled: true, action: {})
                        StickyActionBar(summary: "Disable startup items", variant: .disable, enabled: true, action: {})
                        StickyActionBar(summary: "Uninstall apps", variant: .uninstall, enabled: true, action: {})
                        StickyActionBar(summary: "Remove leftovers", variant: .remove, enabled: true, action: {})
                    }
                    .padding(TonicSpaceToken.two)
                    .background(WorldCanvasBackground())
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }

            SectionShowcase(title: "Detail + Confirmation + Risk") {
                TonicThemeProvider(world: .cleanupGreen) {
                    VStack(spacing: TonicSpaceToken.two) {
                        DetailPane(
                            title: "Xcode Junk",
                            subtitle: "Developer artifacts and simulators",
                            riskText: "Review shared simulator runtimes before removing.",
                            includeExcludeTitle: "Include in cleanup",
                            include: $includeInAction
                        )

                        DeleteModeToggle(permanent: $permanentDelete)

                        ActionConfirmationModal(
                            title: "Confirm Cleanup",
                            message: "You're about to remove 12 items (4.2 GB).",
                            confirmTitle: "Run",
                            onConfirm: {},
                            onCancel: {}
                        )

                        SegmentedFilter(
                            options: AppFilter.allCases,
                            selected: $selectedAppFilter,
                            title: { $0.title }
                        )
                    }
                    .padding(TonicSpaceToken.two)
                    .background(WorldCanvasBackground())
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
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

#Preview {
    DesignSandboxView()
        .background(DesignTokens.Colors.background)
}
