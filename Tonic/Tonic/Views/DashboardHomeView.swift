//
//  DashboardHomeView.swift
//  Tonic
//
//  Modern dashboard (home) — mixed-world bento hub + system snapshot.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Dashboard Home

struct DashboardHomeView: View {
    @ObservedObject var scanManager: SmartScanManager
    @Binding var selectedDestination: NavigationDestination

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    @State private var widgetDataManager = WidgetDataManager.shared
    @State private var widgetPreferences = WidgetPreferences.shared
    @State private var activityStore = ActivityLogStore.shared
    @State private var permissionManager = PermissionManager.shared
    @State private var accessBroker = AccessBroker.shared

    @State private var systemSnapshot: SystemSnapshot?
    @State private var snapshotLoadError: String?
    @State private var snapshotIsLoading = false

    @State private var specsExpanded = false
    @State private var serialRevealed = false
    @State private var didCopySpecs = false
    @State private var showExportSheet = false
    @State private var showHealthExplanation = false

    var body: some View {
        TonicThemeProvider(world: .smartScanPurple) {
            ZStack {
                WorldCanvasBackground(recipe: .default)

                VStack(spacing: TonicSpaceToken.three) {
                    PageHeader(
                        title: "Dashboard",
                        subtitle: headerSubtitle,
                        trailing: AnyView(headerTrailingActions)
                    )
                    .staggeredReveal(index: 0)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: TonicSpaceToken.two) {
                            overviewSection
                                .staggeredReveal(index: 1)

                            cardsSection
                                .staggeredReveal(index: 2)

                            utilitiesSection
                                .staggeredReveal(index: 3)
                        }
                        .padding(.bottom, TonicSpaceToken.three)
                    }
                }
                .padding(.horizontal, TonicSpaceToken.three)
                .padding(.bottom, TonicSpaceToken.three)
                .padding(.top, 4)
            }
        }
        .sheet(isPresented: $showExportSheet) {
            DashboardExportSheet(
                title: "System Specs",
                bodyText: exportText
            )
        }
        .onAppear {
            if !widgetDataManager.isMonitoring {
                widgetDataManager.startMonitoring()
            }
            Task {
                await permissionManager.checkAllPermissions()
                accessBroker.refreshStatuses()
            }
            refreshSnapshot()
        }
    }

    // MARK: - Header

    private var headerSubtitle: String {
        if scanManager.isScanning {
            return "Scanning • \(Int(scanManager.scanProgress * 100))% • \(scanManager.currentPhase.rawValue)"
        }

        guard scanManager.hasScanResult else {
            return "Not scanned yet"
        }

        let recommendationCount = scanManager.recommendations.filter { !$0.isCompleted }.count
        let scanDate = scanManager.lastScanDate ?? Date()
        let relative = RelativeDateTimeFormatter().localizedString(for: scanDate, relativeTo: Date())
        return "Last scan: \(relative) • \(recommendationCount) recommendation\(recommendationCount == 1 ? "" : "s")"
    }

    private var headerTrailingActions: some View {
        HStack(spacing: TonicSpaceToken.one) {
            IconOnlyButton(systemName: "arrow.clockwise") {
                refreshSnapshot()
                if !widgetDataManager.isMonitoring {
                    widgetDataManager.startMonitoring()
                }
            }
            .accessibilityLabel("Refresh dashboard")

            IconOnlyButton(systemName: "questionmark.circle") {
                showHealthExplanation = true
            }
            .accessibilityLabel("Learn about health score")
            .accessibilityHint("Shows how the health score is calculated")
            .popover(isPresented: $showHealthExplanation, arrowEdge: .top) {
                DashboardHealthScoreExplanationPopover()
                    .frame(width: 320)
                    .padding(TonicSpaceToken.three)
            }

            IconOnlyButton(systemName: "square.and.arrow.up") {
                showExportSheet = true
            }
            .accessibilityLabel("Export system report")
        }
    }

    // MARK: - Sections

    private var overviewSection: some View {
        DashboardOverviewContainer {
            ViewThatFits(in: .horizontal) {
                overviewWide
                    .frame(minWidth: 980)
                overviewNarrow
            }
        }
    }

    private var overviewWide: some View {
        HStack(alignment: .top, spacing: TonicSpaceToken.two) {
            DashboardTileCard(world: .smartScanPurple, size: .large) {
                DashboardScanSummaryTile(
                    scanManager: scanManager,
                    cpuPercent: Int(widgetDataManager.cpuData.totalUsage),
                    cpuHistory: Array(widgetDataManager.cpuHistory.suffix(10)),
                    memoryHistory: Array(widgetDataManager.memoryHistory.suffix(10)),
                    memoryPressure: widgetDataManager.memoryData.pressure,
                    diskFreeText: diskFreeText,
                    isDiskLow: isDiskLow,
                    hasFullDiskAccess: hasFullDiskAccess,
                    coverageTier: BuildCapabilities.current.requiresScopeAccess ? accessBroker.coverageTier : nil,
                    onRequestFullDiskAccess: { _ = permissionManager.requestFullDiskAccess() },
                    onRunScan: { scanManager.startSmartScan() },
                    onStopScan: { scanManager.stopSmartScan() },
                    onRunSmartClean: { Task { await scanManager.quickClean() } },
                    onOpenSmartScan: { selectedDestination = .systemCleanup },
                    onExportReport: { showExportSheet = true }
                )
            }

            VStack(spacing: TonicSpaceToken.two) {
                DashboardTileCard(
                    world: .clutterTeal,
                    size: .wide,
                    forceHeight: specsExpanded ? 430 : 300
                ) {
                    SystemSnapshotTile(
                        snapshot: systemSnapshot,
                        isLoading: snapshotIsLoading,
                        errorText: snapshotLoadError,
                        isExpanded: $specsExpanded,
                        serialRevealed: $serialRevealed,
                        didCopy: $didCopySpecs,
                        onCopy: copySpecs,
                        onExport: { showExportSheet = true }
                    )
                }

                DashboardTileCard(world: .performanceOrange, size: .wide) {
                    LiveStatsTile(
                        cpuPercent: Int(widgetDataManager.cpuData.totalUsage),
                        memoryPressure: widgetDataManager.memoryData.pressure,
                        diskFreeText: diskFreeText,
                        cpuHistory: Array(widgetDataManager.cpuHistory.suffix(10)),
                        onOpen: isActivityNavigationEnabled ? { selectedDestination = .liveMonitoring } : nil
                    )
                }
            }
        }
    }

    private var overviewNarrow: some View {
        VStack(spacing: TonicSpaceToken.two) {
            DashboardTileCard(world: .smartScanPurple, size: .large) {
                DashboardScanSummaryTile(
                    scanManager: scanManager,
                    cpuPercent: Int(widgetDataManager.cpuData.totalUsage),
                    cpuHistory: Array(widgetDataManager.cpuHistory.suffix(10)),
                    memoryHistory: Array(widgetDataManager.memoryHistory.suffix(10)),
                    memoryPressure: widgetDataManager.memoryData.pressure,
                    diskFreeText: diskFreeText,
                    isDiskLow: isDiskLow,
                    hasFullDiskAccess: hasFullDiskAccess,
                    coverageTier: BuildCapabilities.current.requiresScopeAccess ? accessBroker.coverageTier : nil,
                    onRequestFullDiskAccess: { _ = permissionManager.requestFullDiskAccess() },
                    onRunScan: { scanManager.startSmartScan() },
                    onStopScan: { scanManager.stopSmartScan() },
                    onRunSmartClean: { Task { await scanManager.quickClean() } },
                    onOpenSmartScan: { selectedDestination = .systemCleanup },
                    onExportReport: { showExportSheet = true }
                )
            }

            DashboardTileCard(
                world: .clutterTeal,
                size: .wide,
                forceHeight: specsExpanded ? 430 : 300
            ) {
                SystemSnapshotTile(
                    snapshot: systemSnapshot,
                    isLoading: snapshotIsLoading,
                    errorText: snapshotLoadError,
                    isExpanded: $specsExpanded,
                    serialRevealed: $serialRevealed,
                    didCopy: $didCopySpecs,
                    onCopy: copySpecs,
                    onExport: { showExportSheet = true }
                )
            }

            DashboardTileCard(world: .performanceOrange, size: .wide) {
                LiveStatsTile(
                    cpuPercent: Int(widgetDataManager.cpuData.totalUsage),
                    memoryPressure: widgetDataManager.memoryData.pressure,
                    diskFreeText: diskFreeText,
                    cpuHistory: Array(widgetDataManager.cpuHistory.suffix(10)),
                    onOpen: isActivityNavigationEnabled ? { selectedDestination = .liveMonitoring } : nil
                )
            }
        }
    }

    private var widgetsPreviewCard: some View {
        DashboardTileCard(
            world: .protectionMagenta,
            size: .wide,
            forceHeight: 0
        ) {
            WidgetsTile(
                enabledConfigs: widgetPreferences.enabledWidgets,
                dataManager: widgetDataManager,
                onCustomize: { selectedDestination = .menuBarWidgets }
            )
        }
    }

    private var cardsSection: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: TonicSpaceToken.two) {
                VStack(spacing: TonicSpaceToken.two) {
                    widgetsPreviewCard
                    recommendationsCard
                }
                activityCard
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)

            VStack(spacing: TonicSpaceToken.two) {
                widgetsPreviewCard
                recommendationsCard
                activityCard
            }
        }
    }

    private var recommendationsCard: some View {
        GlassCard(radius: TonicRadiusToken.xl, variant: colorScheme == .dark ? .sunken : .raised) {
            VStack(alignment: .leading, spacing: TonicSpaceToken.two) {
                HStack {
                    Text("Recommendations")
                        .font(TonicTypeToken.body.weight(.semibold))
                        .foregroundStyle(TonicTextToken.primary)

                    Spacer()

                    if scanManager.hasScanResult {
                        TertiaryGhostButton(title: "View all") {
                            selectedDestination = .systemCleanup
                        }
                    }
                }

                let rows = Array(
                    scanManager.recommendations
                        .filter { !$0.isCompleted }
                        .sorted { lhs, rhs in
                            if lhs.priority.sortOrder != rhs.priority.sortOrder {
                                return lhs.priority.sortOrder < rhs.priority.sortOrder
                            }
                            return lhs.scoreImpact > rhs.scoreImpact
                        }
                        .prefix(5)
                )
                if rows.isEmpty {
                    EmptyStatePanel(
                        icon: "sparkles",
                        title: "All caught up",
                        message: scanManager.hasScanResult ? "No recommendations right now." : "Run a Smart Scan to see recommendations.",
                        compact: true
                    )
                } else {
                    VStack(spacing: 0) {
                        ForEach(rows) { rec in
                            DashboardRecommendationRowModern(
                                recommendation: rec,
                                onOpen: { selectedDestination = destination(for: rec) },
                                onPrimaryAction: { Task { await quickAction(for: rec) } }
                            )

                            if rec.id != rows.last?.id {
                                Divider().opacity(0.35)
                            }
                        }
                    }
                    .background(TonicGlassToken.fill)
                    .clipShape(RoundedRectangle(cornerRadius: TonicRadiusToken.l))
                }
            }
        }
    }

    private var activityCard: some View {
        GlassCard(radius: TonicRadiusToken.xl, variant: colorScheme == .dark ? .sunken : .raised) {
            VStack(alignment: .leading, spacing: TonicSpaceToken.two) {
                HStack {
                    Text("Recent Activity")
                        .font(TonicTypeToken.body.weight(.semibold))
                        .foregroundStyle(TonicTextToken.primary)

                    Spacer()

                    if !activityStore.entries.isEmpty && isActivityNavigationEnabled {
                        TertiaryGhostButton(title: "Show all") {
                            selectedDestination = .liveMonitoring
                        }
                    }
                }

                let rows = Array(activityStore.entries.prefix(5))
                if rows.isEmpty {
                    EmptyStatePanel(icon: "clock.arrow.circlepath", title: "No activity yet", message: "Run a Smart Scan to get started.", compact: true)
                } else {
                    VStack(spacing: 0) {
                        ForEach(rows) { event in
                            DashboardActivityRowModern(event: event)
                            if event.id != rows.last?.id {
                                Divider().opacity(0.35)
                            }
                        }
                    }
                    .background(TonicGlassToken.fill)
                    .clipShape(RoundedRectangle(cornerRadius: TonicRadiusToken.l))
                }
            }
        }
    }

    private var utilitiesSection: some View {
        HStack(spacing: TonicSpaceToken.two) {
            SecondaryPillButton(title: "Copy System Specs") {
                copySpecs()
            }

            SecondaryPillButton(title: "Export Support Report") {
                showExportSheet = true
            }

            Spacer()

            SecondaryPillButton(title: "Open Settings") {
                selectedDestination = .settings
            }
        }
        .padding(.horizontal, TonicSpaceToken.two)
    }

    // MARK: - Snapshot

    private func refreshSnapshot() {
        snapshotLoadError = nil
        snapshotIsLoading = true

        Task.detached(priority: .userInitiated) {
            do {
                let snapshot = try SystemSnapshotProvider.fetch()
                await MainActor.run {
                    self.systemSnapshot = snapshot
                    self.snapshotIsLoading = false
                }
            } catch {
                await MainActor.run {
                    self.snapshotLoadError = "Unable to load system specs"
                    self.snapshotIsLoading = false
                }
            }
        }
    }

    private var exportText: String {
        guard let systemSnapshot else {
            return "System specs are unavailable."
        }
        return systemSnapshot.exportText(serialRevealed: serialRevealed)
    }

    private func copySpecs() {
        let text = exportText
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        if reduceMotion {
            didCopySpecs = true
        } else {
            withAnimation(TonicMotionToken.springTap) {
                didCopySpecs = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if reduceMotion {
                didCopySpecs = false
            } else {
                withAnimation(.easeInOut(duration: TonicMotionToken.med)) {
                    didCopySpecs = false
                }
            }
        }
    }

    private var diskFreeText: String {
        guard let boot = widgetDataManager.diskVolumes.first(where: { $0.isBootVolume }) ?? widgetDataManager.diskVolumes.first else {
            return "—"
        }
        let freeGB = Double(boot.freeBytes) / (1024 * 1024 * 1024)
        return String(format: "%.0f GB free", freeGB)
    }

    private var isDiskLow: Bool {
        guard let boot = widgetDataManager.diskVolumes.first(where: { $0.isBootVolume }) ?? widgetDataManager.diskVolumes.first else {
            return false
        }
        let freeGB = Double(boot.freeBytes) / (1024 * 1024 * 1024)
        return freeGB < 20
    }

    private var hasFullDiskAccess: Bool {
        if BuildCapabilities.current.requiresScopeAccess {
            return accessBroker.hasUsableScope
        }
        return permissionManager.permissionStatuses[.fullDiskAccess] == .authorized
    }

    private var isActivityNavigationEnabled: Bool {
        FeatureFlags.isEnabled(.activity)
    }

    private func destination(for recommendation: Recommendation) -> NavigationDestination {
        switch recommendation.category {
        case .apps:
            return .appManager
        case .system:
            return .systemCleanup
        case .cache, .logs, .other:
            return .systemCleanup
        }
    }

    private func quickAction(for recommendation: Recommendation) async {
        switch destination(for: recommendation) {
        case .appManager:
            selectedDestination = .appManager
        default:
            await scanManager.quickClean()
        }
    }
}

// MARK: - Overview Container

private struct DashboardOverviewContainer<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
    }
}

private enum DashboardTileSize {
    case large
    case wide
    case small

    var height: CGFloat {
        switch self {
        case .large: return 400
        case .wide: return 178
        case .small: return 178
        }
    }
}

private struct DashboardTileCard<Content: View>: View {
    let world: TonicWorld
    let size: DashboardTileSize
    var forceHeight: CGFloat? = nil
    @ViewBuilder let content: () -> Content

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack {
            content()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minHeight: forceHeight ?? size.height)
        .padding(TonicSpaceToken.three)
        .glassSurface(radius: TonicRadiusToken.xl, variant: colorScheme == .dark ? .base : .raised)
        .tonicTheme(world)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Scan Summary Tile

private struct DashboardScanSummaryTile: View {
    @ObservedObject var scanManager: SmartScanManager
    let cpuPercent: Int
    let cpuHistory: [Double]
    let memoryHistory: [Double]
    let memoryPressure: MemoryPressure
    let diskFreeText: String
    let isDiskLow: Bool
    let hasFullDiskAccess: Bool
    let coverageTier: ScopeCoverageTier?
    let onRequestFullDiskAccess: () -> Void
    let onRunScan: () -> Void
    let onStopScan: () -> Void
    let onRunSmartClean: () -> Void
    let onOpenSmartScan: () -> Void
    let onExportReport: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.tonicTheme) private var theme
    @State private var showScopePopover = false
    @State private var accessBroker = AccessBroker.shared
    @State private var isScopeDropTargeted = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            if isReadyZeroState {
                RoundedRectangle(cornerRadius: TonicRadiusToken.xl)
                    .fill(theme.glowSoft.opacity(0.22))
                    .overlay(
                        RoundedRectangle(cornerRadius: TonicRadiusToken.xl)
                            .stroke(TonicStrokeToken.subtle, lineWidth: 1)
                    )
                    .allowsHitTesting(false)
                    .breathingHero()
            }

            VStack(alignment: .leading, spacing: TonicSpaceToken.two) {
                headerRow

                if scanManager.isScanning {
                    scanningBody
                } else if scanManager.hasScanResult {
                    resultBody
                } else {
                    zeroStateBody
                }

                actionsRow

                Spacer(minLength: 0)
            }
        }
        .heroSweep(active: scanManager.isScanning, radius: TonicRadiusToken.xl)
        .pulseGlow(active: scanManager.isScanning, progress: scanManager.scanProgress)
        .accessibilityLabel(scanAccessibilityLabel)
    }

    private var isReadyZeroState: Bool {
        !scanManager.isScanning && !scanManager.hasScanResult
    }

    private var scanAccessibilityLabel: String {
        if scanManager.isScanning {
            return "Smart Scan. Scanning \(Int(scanManager.scanProgress * 100)) percent. \(scanManager.currentPhase.rawValue)."
        }
        if scanManager.hasScanResult {
            return "Smart Scan. Last health score \(scanManager.healthScore) out of 100."
        }
        return "Smart Scan. Not scanned yet."
    }

    private var headerRow: some View {
        HStack(spacing: TonicSpaceToken.two) {
            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(theme.accent)

            Text("Smart Scan")
                .font(TonicTypeToken.caption.weight(.semibold))
                .foregroundStyle(TonicTextToken.primary)

            Spacer()

            if scanManager.isScanning {
                statusChip("Scanning", role: .world(.smartScanPurple))
                Text(elapsedText)
                    .font(TonicTypeToken.micro.monospacedDigit())
                    .foregroundStyle(TonicTextToken.tertiary)
            } else if scanManager.hasScanResult {
                statusChip("Scan complete", role: .semantic(.success))
                Text(lastScanRelativeText)
                    .font(TonicTypeToken.micro.monospacedDigit())
                    .foregroundStyle(TonicTextToken.tertiary)
            } else {
                statusChip("Not scanned yet", role: .semantic(.neutral))
            }
        }
    }

    private var scanningBody: some View {
        VStack(alignment: .leading, spacing: TonicSpaceToken.two) {
            HStack(alignment: .firstTextBaseline, spacing: TonicSpaceToken.two) {
                Text("\(Int(scanManager.scanProgress * 100))%")
                    .font(TonicTypeToken.tileMetric)
                    .foregroundStyle(TonicTextToken.primary)
                    .contentTransition(.numericText())

                Text(scanManager.currentPhase.rawValue)
                    .font(TonicTypeToken.body.weight(.medium))
                    .foregroundStyle(TonicTextToken.secondary)
            }

            ProgressView(value: scanManager.scanProgress)
                .progressViewStyle(.linear)
                .tint(theme.accent)
                .animation(reduceMotion ? .none : .easeInOut(duration: TonicMotionToken.med), value: scanManager.scanProgress)

            DashboardScanStageStepper(phase: scanManager.currentPhase)

            HStack(spacing: TonicSpaceToken.two) {
                DashboardScanLiveCounter(label: "Space found", value: spaceFoundText)
                DashboardScanLiveCounter(label: "Apps checked", value: appsCheckedText)
                DashboardScanLiveCounter(label: "Items flagged", value: flaggedText)
            }

            MicroText("You can keep using your Mac while we scan.")
        }
    }

    private var zeroStateBody: some View {
        VStack(alignment: .leading, spacing: TonicSpaceToken.two) {
            quickSnapshot

            BodyText(insightText)
                .foregroundStyle(TonicTextToken.secondary)

            whatItChecks

            if let coverageTier {
                HStack(spacing: TonicSpaceToken.one) {
                    GlassChip(
                        title: "Coverage: \(coverageTier.rawValue)",
                        icon: "scope",
                        role: .world(.smartScanPurple),
                        strength: .subtle
                    )

                    if !hasFullDiskAccess {
                        Text("Authorize Home, Applications, or your startup disk for deeper results.")
                            .font(TonicTypeToken.micro)
                            .foregroundStyle(TonicTextToken.tertiary)
                    }
                }
            }

            MicroText("Runs locally • No deletions without approval • ~45 seconds")
        }
    }

    private var quickSnapshot: some View {
        VStack(alignment: .leading, spacing: TonicSpaceToken.one) {
            Text("Quick Snapshot")
                .font(TonicTypeToken.caption.weight(.semibold))
                .foregroundStyle(TonicTextToken.primary)

            VStack(spacing: TonicSpaceToken.two) {
                DashboardQuickSnapshotRow(label: "CPU", value: "\(cpuPercent)%", sparkline: cpuHistory, sparklineColor: theme.worldToken.light)
                DashboardQuickSnapshotRow(label: "Memory", value: memoryPressure.rawValue, sparkline: memoryHistory, sparklineColor: theme.worldToken.light)
                DashboardQuickSnapshotRow(label: "Disk", value: diskFreeText, sparkline: nil, sparklineColor: nil, trailingTag: isDiskLow ? "Low" : nil)
            }
            .padding(.horizontal, TonicSpaceToken.two)
            .padding(.vertical, TonicSpaceToken.two)
            .background(TonicGlassToken.fill)
            .clipShape(RoundedRectangle(cornerRadius: TonicRadiusToken.l))
        }
    }

    private var whatItChecks: some View {
        VStack(alignment: .leading, spacing: TonicSpaceToken.two) {
            Text("What Smart Scan checks")
                .font(TonicTypeToken.micro.weight(.semibold))
                .foregroundStyle(TonicTextToken.primary)

            DashboardScopeRow(icon: "externaldrive.fill", title: "Space", detail: "Cache, logs, large files, hidden space")
            DashboardScopeRow(icon: "gauge", title: "Performance", detail: "Startup agents, background load")
            DashboardScopeRow(icon: "app.badge", title: "Apps", detail: "Large/old apps and leftovers")
        }
    }

    private var resultBody: some View {
        VStack(alignment: .leading, spacing: TonicSpaceToken.two) {
            HStack(alignment: .firstTextBaseline, spacing: TonicSpaceToken.one) {
                Text("\(scanManager.healthScore)")
                    .font(TonicTypeToken.hero)
                    .foregroundStyle(TonicTextToken.primary)
                    .contentTransition(.numericText())

                Text("/100")
                    .font(TonicTypeToken.caption)
                    .foregroundStyle(TonicTextToken.tertiary)

                Text(healthLabel)
                    .font(TonicTypeToken.micro.weight(.semibold))
                    .foregroundStyle(TonicTextToken.secondary)
            }

            HStack(spacing: TonicSpaceToken.one) {
                Button(action: onOpenSmartScan) {
                    CounterChip(title: "Space", value: spaceMetric, world: .cleanupGreen, isActive: false, isComplete: true)
                }
                .buttonStyle(.plain)

                Button(action: onOpenSmartScan) {
                    CounterChip(title: "Performance", value: performanceMetric, world: .performanceOrange, isActive: false, isComplete: true)
                }
                .buttonStyle(.plain)

                Button(action: onOpenSmartScan) {
                    CounterChip(title: "Apps", value: appsMetric, world: .applicationsBlue, isActive: false, isComplete: true)
                }
                .buttonStyle(.plain)
            }

            topWins
        }
    }

    private var topWins: some View {
        let rows = Array(
            scanManager.recommendations
                .filter { !$0.isCompleted }
                .sorted { lhs, rhs in
                    if lhs.priority.sortOrder != rhs.priority.sortOrder {
                        return lhs.priority.sortOrder < rhs.priority.sortOrder
                    }
                    if lhs.scoreImpact != rhs.scoreImpact {
                        return lhs.scoreImpact > rhs.scoreImpact
                    }
                    return lhs.scanRecommendation.spaceToReclaim > rhs.scanRecommendation.spaceToReclaim
                }
                .prefix(3)
        )

        return Group {
            if rows.isEmpty {
                EmptyView()
            } else {
                VStack(spacing: 0) {
                    ForEach(rows) { rec in
                        Button(action: onOpenSmartScan) {
                            DashboardTopWinRow(recommendation: rec)
                        }
                        .buttonStyle(.plain)
                        if rec.id != rows.last?.id {
                            Divider().opacity(0.35)
                        }
                    }
                }
                .background(TonicGlassToken.fill)
                .clipShape(RoundedRectangle(cornerRadius: TonicRadiusToken.l))
            }
        }
    }

    @ViewBuilder
    private var actionsRow: some View {
        if scanManager.isScanning {
            HStack(spacing: TonicSpaceToken.two) {
                PrimaryActionButton(
                    title: "Stop scan",
                    icon: "stop.fill",
                    action: onStopScan,
                    isEnabled: true
                )
            }
        } else if scanManager.hasScanResult {
            HStack(spacing: TonicSpaceToken.two) {
                PrimaryActionButton(
                    title: hasRunnableWork ? "Run Smart Clean" : "Run Again",
                    icon: hasRunnableWork ? "sparkles" : "play.fill",
                    action: hasRunnableWork ? onRunSmartClean : onRunScan,
                    isEnabled: true
                )

                SecondaryPillButton(title: "Review", action: onOpenSmartScan)
                TertiaryGhostButton(title: "Export report", action: onExportReport)
            }
        } else {
            VStack(alignment: .leading, spacing: TonicSpaceToken.one) {
                if !hasFullDiskAccess {
                    Button(action: onRequestFullDiskAccess) {
                        GlassChip(
                            title: BuildCapabilities.current.requiresScopeAccess
                                ? (isScopeDropTargeted ? "Drop location to authorize" : "Limited scan—Grant Access Scope")
                                : "Limited scan—Grant Full Disk Access",
                            icon: "lock.shield",
                            role: .semantic(.warning),
                            strength: .subtle
                        )
                    }
                    .buttonStyle(.plain)
                    .overlay(
                        RoundedRectangle(cornerRadius: TonicRadiusToken.chip)
                            .stroke(
                                BuildCapabilities.current.requiresScopeAccess && isScopeDropTargeted
                                    ? TonicStatusPalette.text(.warning).opacity(0.9)
                                    : Color.clear,
                                style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                            )
                    )
                    .onDrop(
                        of: [UTType.fileURL.identifier],
                        isTargeted: $isScopeDropTargeted
                    ) { providers in
                        handleDroppedScopeProviders(providers)
                    }
                }

                HStack(spacing: TonicSpaceToken.two) {
                    PrimaryActionButton(
                        title: "Run Smart Scan",
                        icon: "play.fill",
                        action: onRunScan,
                        isEnabled: true
                    )

                    Button {
                        showScopePopover.toggle()
                    } label: {
                        Text("What gets scanned?")
                            .font(TonicTypeToken.caption.weight(.semibold))
                            .foregroundStyle(TonicTextToken.secondary)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showScopePopover, arrowEdge: .bottom) {
                        DashboardWhatGetsScannedPopover()
                            .frame(width: 320)
                            .padding(TonicSpaceToken.three)
                    }

                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func statusChip(_ title: String, role: TonicChipRole) -> some View {
        GlassChip(title: title, role: role, strength: .subtle)
            .font(TonicTypeToken.micro.weight(.semibold))
    }

    private var insightText: String {
        if isDiskLow {
            return "Storage is running low—Smart Scan can reclaim space safely."
        }
        if memoryPressure != .normal {
            return "Memory pressure is elevated—Smart Scan can flag heavy startup agents."
        }
        return "Everything looks stable—Smart Scan finds optional optimizations."
    }

    private var elapsedText: String {
        guard let start = scanManager.scanStartDate else { return "—" }
        let seconds = Int(Date().timeIntervalSince(start))
        let minutes = seconds / 60
        let remaining = seconds % 60
        if minutes > 0 {
            return "\(minutes)m \(remaining)s"
        }
        return "\(remaining)s"
    }

    private var lastScanRelativeText: String {
        guard let date = scanManager.lastScanDate else { return "" }
        return RelativeDateTimeFormatter().localizedString(for: date, relativeTo: Date())
    }

    private var spaceFoundText: String {
        guard let bytes = scanManager.spaceFoundBytes else { return "—" }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private var appsCheckedText: String {
        guard let count = scanManager.appsScannedCount else { return "—" }
        return "\(count)"
    }

    private var flaggedText: String {
        guard let count = scanManager.flaggedCount else { return "—" }
        return "\(count)"
    }

    private var healthLabel: String {
        switch scanManager.healthScore {
        case 90...100: return "Excellent"
        case 75..<90: return "Good"
        case 50..<75: return "Fair"
        case 25..<50: return "Poor"
        default: return "Critical"
        }
    }

    private var hasRunnableWork: Bool {
        !scanManager.recommendations.filter {
            !$0.isCompleted && $0.scanRecommendation.actionable && $0.scanRecommendation.safeToFix
        }.isEmpty
    }

    private var spaceMetric: String {
        let bytes = scanManager.lastReclaimableBytes ?? Int64(scanManager.recommendations.reduce(0) { $0 + $1.scanRecommendation.spaceToReclaim })
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private var performanceMetric: String {
        let count = scanManager.recommendations.filter { $0.type == .optimize }.count
        return "\(count) item\(count == 1 ? "" : "s")"
    }

    private var appsMetric: String {
        let count = scanManager.recommendations.filter { $0.category == .apps }.count
        return "\(count) app\(count == 1 ? "" : "s")"
    }

    private func handleDroppedScopeProviders(_ providers: [NSItemProvider]) -> Bool {
        guard BuildCapabilities.current.requiresScopeAccess else { return false }
        let typeIdentifier = UTType.fileURL.identifier
        let matchingProviders = providers.filter { $0.hasItemConformingToTypeIdentifier(typeIdentifier) }
        guard !matchingProviders.isEmpty else { return false }

        for provider in matchingProviders {
            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, _ in
                let droppedURL: URL?
                if let data = item as? Data {
                    droppedURL = URL(dataRepresentation: data, relativeTo: nil)
                } else if let url = item as? URL {
                    droppedURL = url
                } else if let string = item as? String {
                    droppedURL = URL(string: string)
                } else {
                    droppedURL = nil
                }

                guard let droppedURL else { return }
                Task { @MainActor in
                    do {
                        _ = try accessBroker.addScope(from: droppedURL)
                        accessBroker.refreshStatuses()
                    } catch {
                        return
                    }
                }
            }
        }

        return true
    }
}

private struct DashboardQuickSnapshotRow: View {
    let label: String
    let value: String
    let sparkline: [Double]?
    let sparklineColor: Color?
    var trailingTag: String? = nil

    var body: some View {
        HStack(spacing: TonicSpaceToken.two) {
            Text(label)
                .font(TonicTypeToken.micro)
                .foregroundStyle(TonicTextToken.secondary)
                .frame(width: 54, alignment: .leading)

            Spacer()

            if let trailingTag {
                GlassChip(title: trailingTag, role: .semantic(.warning), strength: .subtle)
                    .font(TonicTypeToken.micro.weight(.semibold))
            }

            Text(value)
                .font(TonicTypeToken.micro.weight(.semibold))
                .foregroundStyle(TonicTextToken.primary)
                .contentTransition(.numericText())

            if let sparkline, let sparklineColor {
                MiniSparkline(data: sparkline, color: sparklineColor)
                    .frame(width: 64, height: 16)
            }
        }
    }
}

private struct DashboardScopeRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: TonicSpaceToken.two) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(TonicTextToken.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(TonicTypeToken.micro.weight(.semibold))
                    .foregroundStyle(TonicTextToken.primary)
                Text(detail)
                    .font(TonicTypeToken.micro)
                    .foregroundStyle(TonicTextToken.tertiary)
            }
        }
    }
}

private struct DashboardWhatGetsScannedPopover: View {
    var body: some View {
        VStack(alignment: .leading, spacing: TonicSpaceToken.two) {
            Text("What gets scanned")
                .font(TonicTypeToken.caption.weight(.semibold))
                .foregroundStyle(TonicTextToken.primary)

            Text("Smart Scan checks Space, Performance, and Apps to generate safe recommendations.")
                .font(TonicTypeToken.micro)
                .foregroundStyle(TonicTextToken.secondary)

            VStack(alignment: .leading, spacing: TonicSpaceToken.two) {
                DashboardScopeRow(icon: "externaldrive.fill", title: "Space", detail: "Cache, logs, temp files, large files")
                DashboardScopeRow(icon: "gauge", title: "Performance", detail: "Launch agents, login items, browser caches")
                DashboardScopeRow(icon: "app.badge", title: "Apps", detail: "Large apps, duplicates, leftovers")
            }
        }
        .glassSurface(radius: TonicRadiusToken.l, variant: .sunken)
    }
}

private struct DashboardScanLiveCounter: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(TonicTypeToken.micro)
                .foregroundStyle(TonicTextToken.tertiary)
            Text(value)
                .font(TonicTypeToken.micro.weight(.semibold).monospacedDigit())
                .foregroundStyle(TonicTextToken.primary)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DashboardScanStageStepper: View {
    let phase: SmartScanManager.ScanPhase

    var body: some View {
        HStack(spacing: TonicSpaceToken.one) {
            stageChip(title: "Space", icon: "externaldrive.fill", state: state(for: .scanningDisk))
            stageChip(title: "Performance", icon: "gauge", state: state(for: .analyzingSystem))
            stageChip(title: "Apps", icon: "app.badge", state: state(for: .checkingApps))
        }
    }

    private enum StageKey {
        case scanningDisk
        case analyzingSystem
        case checkingApps
    }

    private enum StageState {
        case pending
        case active
        case complete
    }

    private func state(for key: StageKey) -> StageState {
        switch phase {
        case .idle, .preparing:
            return .pending
        case .scanningDisk:
            return key == .scanningDisk ? .active : .pending
        case .analyzingSystem:
            if key == .scanningDisk { return .complete }
            return key == .analyzingSystem ? .active : .pending
        case .checkingApps:
            if key == .checkingApps { return .active }
            return .complete
        case .complete:
            return .complete
        }
    }

    private func stageChip(title: String, icon: String, state: StageState) -> some View {
        let role: TonicChipRole = switch state {
        case .pending:
            .semantic(.neutral)
        case .active:
            .world(.smartScanPurple)
        case .complete:
            .semantic(.success)
        }

        let glyph = state == .complete ? "checkmark" : icon

        return GlassChip(title: title, icon: glyph, role: role, strength: .subtle)
            .font(TonicTypeToken.micro.weight(.semibold))
            .frame(maxWidth: .infinity)
    }
}

private struct DashboardTopWinRow: View {
    let recommendation: Recommendation

    var body: some View {
        HStack(spacing: TonicSpaceToken.two) {
            priorityBadge
            Text(recommendation.title)
                .font(TonicTypeToken.micro.weight(.semibold))
                .foregroundStyle(TonicTextToken.primary)
                .lineLimit(1)
            Spacer()
            TrailingMetric(value: "+\(recommendation.scoreImpact)")
                .font(TonicTypeToken.micro.weight(.semibold))
        }
        .padding(.vertical, TonicSpaceToken.two)
        .padding(.horizontal, TonicSpaceToken.two)
        .contentShape(Rectangle())
    }

    private var priorityBadge: some View {
        let kind: TonicSemanticKind = switch recommendation.priority {
        case .critical, .high: .danger
        case .medium: .warning
        case .low: .info
        }

        return GlassChip(
            title: recommendation.priority.label,
            icon: recommendation.priority.icon,
            role: .semantic(kind),
            strength: .subtle
        )
        .font(TonicTypeToken.micro.weight(.semibold))
    }
}

// MARK: - System Snapshot Tile

private struct SystemSnapshotTile: View {
    let snapshot: SystemSnapshot?
    let isLoading: Bool
    let errorText: String?
    @Binding var isExpanded: Bool
    @Binding var serialRevealed: Bool
    @Binding var didCopy: Bool
    let onCopy: () -> Void
    let onExport: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.tonicTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: TonicSpaceToken.two) {
            header

            if isLoading {
                ScanLoadingState(message: "Loading system specs…")
            } else if let errorText {
                ErrorStatePanel(message: errorText)
            } else if let snapshot {
                rows(for: snapshot)
            } else {
                PlaceholderStatePanel(title: "System Specs", message: "Unavailable.")
            }
        }
        .accessibilityLabel("System specs")
    }

    private var header: some View {
        HStack(alignment: .top, spacing: TonicSpaceToken.two) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(theme.glowSoft)
                    .frame(width: 34, height: 34)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(TonicStrokeToken.subtle, lineWidth: 1)
                    )

                Image(systemName: "laptopcomputer")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(TonicTextToken.primary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot?.deviceDisplayName ?? "System Specs")
                    .font(TonicTypeToken.caption.weight(.semibold))
                    .foregroundStyle(TonicTextToken.primary)

                Text(snapshot?.osString ?? "")
                    .font(TonicTypeToken.micro)
                    .foregroundStyle(TonicTextToken.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: TonicSpaceToken.one) {
                Button(action: onCopy) {
                    Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(TonicTextToken.secondary)
                        .contentTransition(.opacity)
                        .accessibilityLabel(didCopy ? "Copied" : "Copy specs")
                }
                .buttonStyle(PressEffect(focusShape: .rounded(10)))

                Button(action: onExport) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(TonicTextToken.secondary)
                        .accessibilityLabel("Export specs")
                }
                .buttonStyle(PressEffect(focusShape: .rounded(10)))
            }
        }
    }

    @ViewBuilder
    private func rows(for snapshot: SystemSnapshot) -> some View {
        VStack(spacing: 0) {
            DashboardKeyValueRow(label: "Processor", value: snapshot.processorSummary)
            rowDivider
            DashboardKeyValueRow(label: "Memory", value: snapshot.memorySummary)
            rowDivider
            DashboardKeyValueRow(label: "Graphics", value: snapshot.graphicsSummary)
            rowDivider
            DashboardKeyValueRow(label: "Disks", value: snapshot.diskSummary)
            rowDivider
            DashboardKeyValueRow(label: "Display", value: snapshot.displaySummary)

            Button {
                if reduceMotion {
                    isExpanded.toggle()
                } else {
                    withAnimation(TonicMotionToken.stageEnterSpring) {
                        isExpanded.toggle()
                    }
                }
            } label: {
                HStack {
                    Text(isExpanded ? "Show less" : "Show more")
                        .font(TonicTypeToken.micro.weight(.semibold))
                        .foregroundStyle(theme.worldToken.light)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.worldToken.light)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .animation(reduceMotion ? .none : .easeInOut(duration: TonicMotionToken.med), value: isExpanded)
                }
                .padding(.vertical, TonicSpaceToken.two)
            }
            .buttonStyle(PressEffect(focusShape: .rounded(TonicRadiusToken.l)))
            .contentShape(Rectangle())

            if isExpanded {
                VStack(spacing: 0) {
                    rowDivider
                    DashboardKeyValueRow(label: "Model identifier", value: snapshot.modelIdentifier)
                    rowDivider
                    DashboardKeyValueRow(label: "Model year", value: snapshot.modelYear ?? "—")
                    rowDivider
                    serialRow(snapshot: snapshot)
                    rowDivider
                    DashboardKeyValueRow(label: "Uptime", value: snapshot.uptimeSummary)
                }
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(TonicGlassToken.fill)
        .clipShape(RoundedRectangle(cornerRadius: TonicRadiusToken.l))
    }

    private var rowDivider: some View {
        Divider().opacity(0.35)
    }

    private func serialRow(snapshot: SystemSnapshot) -> some View {
        HStack(spacing: TonicSpaceToken.two) {
            Text("Serial number")
                .font(TonicTypeToken.micro)
                .foregroundStyle(TonicTextToken.secondary)

            Spacer()

            Text(snapshot.serialDisplay(revealed: serialRevealed))
                .font(TonicTypeToken.micro.monospacedDigit())
                .foregroundStyle(TonicTextToken.primary)

            Button(serialRevealed ? "Hide" : "Reveal") {
                if reduceMotion {
                    serialRevealed.toggle()
                } else {
                    withAnimation(TonicMotionToken.springTap) {
                        serialRevealed.toggle()
                    }
                }
            }
            .font(TonicTypeToken.micro.weight(.semibold))
            .buttonStyle(.plain)
            .foregroundStyle(theme.accent)
            .accessibilityLabel(serialRevealed ? "Hide serial number" : "Reveal serial number")
        }
        .padding(.vertical, TonicSpaceToken.two)
        .padding(.horizontal, TonicSpaceToken.two)
    }
}

private struct DashboardKeyValueRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: TonicSpaceToken.two) {
            Text(label)
                .font(TonicTypeToken.micro)
                .foregroundStyle(TonicTextToken.secondary)

            Spacer()

            Text(value)
                .font(TonicTypeToken.micro.weight(.medium))
                .foregroundStyle(TonicTextToken.primary)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
        .padding(.vertical, TonicSpaceToken.two)
        .padding(.horizontal, TonicSpaceToken.two)
    }
}

// MARK: - Live Stats Tile

private struct LiveStatsTile: View {
    let cpuPercent: Int
    let memoryPressure: MemoryPressure
    let diskFreeText: String
    let cpuHistory: [Double]
    let onOpen: (() -> Void)?

    @Environment(\.tonicTheme) private var theme

    var body: some View {
        Group {
            if let onOpen {
                Button(action: onOpen) {
                    tileContent(showChevron: true)
                }
                .buttonStyle(PressEffect(focusShape: .rounded(TonicRadiusToken.xl)))
            } else {
                tileContent(showChevron: false)
            }
        }
        .accessibilityLabel("Live stats")
        .accessibilityHint(onOpen == nil ? "Activity is currently hidden in navigation" : "Opens Activity")
    }

    private func tileContent(showChevron: Bool) -> some View {
        VStack(alignment: .leading, spacing: TonicSpaceToken.two) {
            HStack(spacing: TonicSpaceToken.two) {
                Image(systemName: "gauge")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(theme.accent)

                Text("Live Stats")
                    .font(TonicTypeToken.caption.weight(.semibold))
                    .foregroundStyle(TonicTextToken.primary)

                Spacer()

                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(TonicTextToken.tertiary)
                }
            }

            VStack(spacing: TonicSpaceToken.two) {
                DashboardMiniMetricRow(label: "CPU", value: "\(cpuPercent)%")
                DashboardMiniMetricRow(label: "Memory", value: memoryPressure.rawValue)
                DashboardMiniMetricRow(label: "Disk", value: diskFreeText)
            }

            MiniSparkline(data: cpuHistory.isEmpty ? [30, 35, 32, 38, 36, 34, 37, 35, 33, 36] : cpuHistory, color: theme.worldToken.light)
                .frame(height: 32)
                .padding(.top, TonicSpaceToken.one)
        }
    }
}

private struct DashboardMiniMetricRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(TonicTypeToken.micro)
                .foregroundStyle(TonicTextToken.secondary)

            Spacer()

            Text(value)
                .font(TonicTypeToken.micro.weight(.semibold))
                .foregroundStyle(TonicTextToken.primary)
                .contentTransition(.numericText())
        }
    }
}

// MARK: - Health Score Popover

private struct DashboardHealthScoreExplanationPopover: View {
    var body: some View {
        VStack(alignment: .leading, spacing: TonicSpaceToken.two) {
            Text("Health Score")
                .font(TonicTypeToken.caption.weight(.semibold))
                .foregroundStyle(TonicTextToken.primary)

            Text("A quick snapshot of your Mac’s overall health, based on storage, memory pressure, and flagged recommendations.")
                .font(TonicTypeToken.micro)
                .foregroundStyle(TonicTextToken.secondary)

            VStack(alignment: .leading, spacing: TonicSpaceToken.one) {
                factorRow(icon: "internaldrive", title: "Disk space", detail: "Low free space reduces your score.")
                factorRow(icon: "memorychip", title: "Memory pressure", detail: "Sustained pressure indicates slowdowns.")
                factorRow(icon: "trash", title: "Junk files", detail: "Cache/logs/temp files you can safely remove.")
                factorRow(icon: "app.badge", title: "Apps & startup", detail: "Apps and agents that impact performance.")
            }

            Text("Tip: Run Smart Scan to see what’s impacting your score.")
                .font(TonicTypeToken.micro)
                .foregroundStyle(TonicTextToken.tertiary)
        }
        .glassSurface(radius: TonicRadiusToken.l, variant: .sunken)
    }

    private func factorRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: TonicSpaceToken.two) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(TonicTextToken.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(TonicTypeToken.micro.weight(.semibold))
                    .foregroundStyle(TonicTextToken.primary)
                Text(detail)
                    .font(TonicTypeToken.micro)
                    .foregroundStyle(TonicTextToken.tertiary)
            }
        }
    }
}

// MARK: - Widgets Tile

private struct WidgetsTile: View {
    let enabledConfigs: [WidgetConfiguration]
    let dataManager: WidgetDataManager
    let onCustomize: () -> Void

    @Environment(\.tonicTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: TonicSpaceToken.two) {
            HStack(spacing: TonicSpaceToken.two) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(theme.accent)

                Text("Widgets")
                    .font(TonicTypeToken.caption.weight(.semibold))
                    .foregroundStyle(TonicTextToken.primary)

                Spacer()

                CounterChip(title: "", value: "\(enabledConfigs.count)", world: .protectionMagenta, isActive: enabledConfigs.count > 0, isComplete: enabledConfigs.count > 0)
                    .accessibilityLabel("\(enabledConfigs.count) active widgets")
            }

            if enabledConfigs.isEmpty {
                BodyText("Add widgets to your menu bar for quick monitoring.")
                    .foregroundStyle(TonicTextToken.secondary)
            } else {
                HStack(spacing: TonicSpaceToken.two) {
                    ForEach(Array(enabledConfigs.prefix(4).enumerated()), id: \.element.id) { _, config in
                        WidgetMiniPreview(
                            config: config,
                            value: widgetPreviewValue(config),
                            sparklineData: sparklineData(for: config.type)
                        )
                    }
                }
                .padding(.vertical, 2)
            }

            SecondaryPillButton(title: "Customize", action: onCustomize)
        }
        .accessibilityLabel("Widgets")
        .accessibilityHint("Customize menu bar widgets")
    }

    private func sparklineData(for type: WidgetType) -> [Double] {
        switch type {
        case .cpu:
            let history = dataManager.cpuHistory.suffix(10)
            return history.isEmpty ? [30, 35, 32, 38, 36, 34, 37, 35, 33, 36] : Array(history)
        case .memory:
            let history = dataManager.memoryHistory.suffix(10)
            return history.isEmpty ? [60, 62, 58, 65, 63, 67, 64, 68, 66, 65] : Array(history)
        default:
            return [30, 35, 32, 38, 36, 34, 37, 35, 33, 36]
        }
    }

    private func widgetPreviewValue(_ config: WidgetConfiguration) -> String {
        let usePercent = config.valueFormat == .percentage
        switch config.type {
        case .cpu:
            return "\(Int(dataManager.cpuData.totalUsage))%"
        case .memory:
            if usePercent {
                return "\(Int(dataManager.memoryData.usagePercentage))%"
            } else {
                let usedGB = Double(dataManager.memoryData.usedBytes) / (1024 * 1024 * 1024)
                return String(format: "%.1f GB", usedGB)
            }
        case .disk:
            if let primary = dataManager.diskVolumes.first {
                if usePercent {
                    return "\(Int(primary.usagePercentage))%"
                } else {
                    let freeGB = primary.freeBytes / (1024 * 1024 * 1024)
                    return "\(freeGB)GB"
                }
            }
            return "—"
        case .network:
            return dataManager.networkData.downloadString
        case .gpu:
            if let usage = dataManager.gpuData.usagePercentage {
                return "\(Int(usage))%"
            }
            return "—"
        case .battery:
            return "\(Int(dataManager.batteryData.chargePercentage))%"
        case .weather:
            return "—"
        case .sensors:
            return "—"
        case .bluetooth:
            if let device = dataManager.bluetoothData.devicesWithBattery.first,
               let battery = device.primaryBatteryLevel {
                return "\(battery)%"
            }
            return "\(dataManager.bluetoothData.connectedDevices.count)"
        case .clock:
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: Date())
        }
    }
}

// MARK: - Recommendation Row (Modern)

private struct DashboardRecommendationRowModern: View {
    let recommendation: Recommendation
    let onOpen: () -> Void
    let onPrimaryAction: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false

    var body: some View {
        HStack(spacing: TonicSpaceToken.two) {
            Button(action: onOpen) {
                HStack(spacing: TonicSpaceToken.two) {
                    semanticBadge

                    VStack(alignment: .leading, spacing: 2) {
                        Text(recommendation.title)
                            .font(TonicTypeToken.micro.weight(.semibold))
                            .foregroundStyle(TonicTextToken.primary)
                            .lineLimit(1)

                        Text(recommendation.description)
                            .font(TonicTypeToken.micro)
                            .foregroundStyle(TonicTextToken.tertiary)
                            .lineLimit(1)
                    }

                    Spacer()

                    scoreChip
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            SecondaryPillButton(title: recommendation.actionText) {
                if reduceMotion {
                    onPrimaryAction()
                } else {
                    withAnimation(TonicMotionToken.springTap) {
                        onPrimaryAction()
                    }
                }
            }
        }
        .padding(.vertical, TonicSpaceToken.two)
        .padding(.horizontal, TonicSpaceToken.two)
        .background(hovering ? TonicGlassToken.fill.opacity(0.35) : .clear)
        .animation(reduceMotion ? .none : .easeInOut(duration: TonicMotionToken.fast), value: hovering)
        .onHover { hovering = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(recommendation.title), \(recommendation.priority.label) priority")
    }

    private var semanticBadge: some View {
        let kind: TonicSemanticKind = switch recommendation.priority {
        case .critical, .high: .danger
        case .medium: .warning
        case .low: .info
        }

        return GlassChip(
            title: recommendation.priority.label,
            icon: recommendation.priority.icon,
            role: .semantic(kind),
            strength: .subtle
        )
        .font(TonicTypeToken.micro.weight(.semibold))
    }

    private var scoreChip: some View {
        GlassChip(
            title: "+\(recommendation.scoreImpact) score",
            icon: "sparkles",
            role: .world(.smartScanPurple),
            strength: .subtle
        )
        .font(TonicTypeToken.micro.weight(.semibold))
    }
}

// MARK: - Helpers

private func abbreviatedRelativeTime(_ date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: date, relativeTo: Date())
}

// MARK: - Activity Row (Modern)

private struct DashboardActivityRowModern: View {
    let event: ActivityEvent

    var body: some View {
        HStack(spacing: TonicSpaceToken.two) {
            Image(systemName: event.category.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(TonicTextToken.secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(TonicTypeToken.micro.weight(.semibold))
                    .foregroundStyle(TonicTextToken.primary)
                    .lineLimit(1)

                Text(event.detail)
                    .font(TonicTypeToken.micro)
                    .foregroundStyle(TonicTextToken.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            Text(abbreviatedRelativeTime(event.timestamp))
                .font(TonicTypeToken.micro.monospacedDigit())
                .foregroundStyle(TonicTextToken.tertiary)
        }
        .padding(.vertical, TonicSpaceToken.two)
        .padding(.horizontal, TonicSpaceToken.two)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Export Sheet

private struct DashboardExportSheet: View {
    let title: String
    let bodyText: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var didCopy = false

    var body: some View {
        TonicThemeProvider(world: .smartScanPurple) {
            ZStack {
                WorldCanvasBackground()
                VStack(spacing: TonicSpaceToken.three) {
                    PageHeader(
                        title: title,
                        subtitle: "Copy or share this report",
                        trailing: AnyView(
                            HStack(spacing: TonicSpaceToken.one) {
                                IconOnlyButton(systemName: "xmark") { dismiss() }
                            }
                        )
                    )

                    GlassPanel(radius: TonicRadiusToken.container, variant: .sunken) {
                        ScrollView {
                            Text(bodyText)
                                .font(.system(size: 12, weight: .regular, design: .monospaced))
                                .foregroundStyle(TonicTextToken.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    HStack(spacing: TonicSpaceToken.two) {
                        SecondaryPillButton(title: didCopy ? "Copied" : "Copy") {
                            copyToPasteboard()
                        }

                        ShareLink(item: bodyText) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(PressEffect(focusShape: .capsule))

                        Spacer()
                    }
                }
                .padding(.horizontal, TonicSpaceToken.three)
                .padding(.bottom, TonicSpaceToken.three)
            }
        }
        .frame(minWidth: 720, minHeight: 520)
    }

    private func copyToPasteboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(bodyText, forType: .string)
        if reduceMotion {
            didCopy = true
        } else {
            withAnimation(TonicMotionToken.springTap) { didCopy = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if reduceMotion {
                didCopy = false
            } else {
                withAnimation(.easeInOut(duration: TonicMotionToken.med)) { didCopy = false }
            }
        }
    }
}

#Preview {
    DashboardHomeView(
        scanManager: SmartScanManager(),
        selectedDestination: .constant(.dashboard)
    )
    .frame(width: 1100, height: 800)
}
