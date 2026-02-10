import SwiftUI

enum SmartScanHubMode {
    case ready
    case scanning
    case running
    case results
}

struct SmartScanHubView: View {
    let mode: SmartScanHubMode
    let scanProgress: Double
    let runProgress: Double
    let currentStage: SmartScanStage
    let completedStages: [SmartScanStage]
    let counters: SmartScanLiveCounters
    let scanResult: SmartCareResult?
    let runSummaryText: String?
    let quickActionSheet: SmartScanQuickActionSheetState?
    let quickActionProgress: Double
    let quickActionSummary: SmartScanRunSummary?
    let quickActionIsRunning: Bool
    var currentScanItem: String? = nil
    let onStartScan: () -> Void
    let onStopScan: () -> Void
    let onRunSmartClean: () -> Void
    let onReviewCustomize: () -> Void
    let onReviewTarget: (SmartScanReviewTarget) -> Void
    let onTileAction: (SmartScanTileID, SmartScanTileActionKind) -> Void
    let onQuickActionStart: () -> Void
    let onQuickActionStop: () -> Void
    let onQuickActionDone: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let accessBroker = AccessBroker.shared

    // Collapsible hero state
    @State private var heroCompact = false

    // Staggered entrance state
    @State private var sectionsRevealed = false

    private let scrollCoordinateSpace = "smartScanScroll"

    var body: some View {
        ZStack {
            VStack(spacing: TonicSpaceToken.three) {
                PageHeader(
                    title: "Smart Scan",
                    subtitle: headerSubtitle,
                    showsBack: false,
                    searchText: nil,
                    onBack: nil,
                    trailing: nil
                )
                .frame(minHeight: 56)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: TonicSpaceToken.three) {
                        // Hero module with scroll tracking for collapse
                        if mode == .results && heroCompact {
                            compactHeroBar
                                .transition(.opacity)
                        } else {
                            ScanHeroModule(
                                state: heroState,
                                currentScanItem: currentScanItem
                            )
                            .transition(.opacity)
                        }

                        // Scroll offset tracker (invisible)
                        if mode == .results {
                            GeometryReader { geo in
                                Color.clear
                                    .preference(
                                        key: ScrollOffsetPreferenceKey.self,
                                        value: geo.frame(in: .named(scrollCoordinateSpace)).minY
                                    )
                            }
                            .frame(height: 0)
                        }

                        if mode == .scanning || mode == .running || mode == .results {
                            timelineAndCounters
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        if mode == .results {
                            resultsSections
                        }
                    }
                    .padding(.bottom, TonicSpaceToken.three)
                }
                .coordinateSpace(name: scrollCoordinateSpace)
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                    let shouldCompact = offset < -80
                    if shouldCompact != heroCompact {
                        if reduceMotion {
                            heroCompact = shouldCompact
                        } else {
                            withAnimation(TonicMotionToken.stageEnterSpring) {
                                heroCompact = shouldCompact
                            }
                        }
                    }
                }

                commandDock
            }
            .padding(.horizontal, TonicSpaceToken.three)
            .padding(.bottom, TonicSpaceToken.three)
            .padding(.top, 4)
            .animation(
                reduceMotion ? .none : TonicMotionToken.resultMetricSpring,
                value: mode
            )

            // Quick action overlay with slide-up transition
            if quickActionSheet != nil {
                TonicGlassToken.baseVignette.opacity(colorScheme == .dark ? 1 : 0.7)
                    .background(.ultraThinMaterial.opacity(0.3))
                    .ignoresSafeArea()
                    .onTapGesture {
                        if !quickActionIsRunning {
                            onQuickActionDone()
                        }
                    }
                    .accessibilityLabel("Dismiss overlay")
                    .accessibilityAddTraits(.isButton)
                    .transition(.opacity)

                SmartScanQuickActionCard(
                    sheet: quickActionSheet!,
                    progress: quickActionProgress,
                    summary: quickActionSummary,
                    isRunning: quickActionIsRunning,
                    onStart: onQuickActionStart,
                    onStop: onQuickActionStop,
                    onDone: onQuickActionDone
                )
                .padding(TonicSpaceToken.four)
                .transition(
                    reduceMotion
                        ? .opacity
                        : .move(edge: .bottom).combined(with: .opacity)
                )
            }
        }
        .animation(
            reduceMotion ? .none : TonicMotionToken.modalPresentSpring,
            value: quickActionSheet != nil
        )
        .onAppear {
            // When returning to this screen with an already-complete result, mode may
            // still be `.results` and no mode-change event will fire. Ensure sections
            // become visible on reappear.
            guard mode == .results, !sectionsRevealed else { return }
            if reduceMotion {
                sectionsRevealed = true
            } else {
                withAnimation(TonicMotionToken.resultCardSpring) {
                    sectionsRevealed = true
                }
            }
        }
        .onChange(of: mode) { _, newMode in
            if newMode == .results {
                if reduceMotion {
                    sectionsRevealed = true
                } else {
                    // Slight delay to let the hero transition complete first
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(TonicMotionToken.resultCardSpring) {
                            sectionsRevealed = true
                        }
                    }
                }
            } else {
                sectionsRevealed = false
                heroCompact = false
            }
        }
    }

    // MARK: - Compact Hero Bar

    private var compactHeroBar: some View {
        HStack(spacing: TonicSpaceToken.two) {
            Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(TonicTextToken.primary)

            Text("Scan Complete")
                .font(TonicTypeToken.caption.weight(.semibold))
                .foregroundStyle(TonicTextToken.primary)

            Spacer()

            CounterChip(title: "", value: spaceResultMetric, world: .cleanupGreen, isComplete: true)
                .accessibilityLabel("Space: \(spaceResultMetric)")
            CounterChip(title: "", value: performanceResultMetric, world: .performanceOrange, isComplete: true)
                .accessibilityLabel("Performance: \(performanceResultMetric)")
            CounterChip(title: "", value: appsResultMetric, world: .applicationsBlue, isComplete: true)
                .accessibilityLabel("Apps: \(appsResultMetric)")
        }
        .padding(.horizontal, TonicSpaceToken.three)
        .padding(.vertical, TonicSpaceToken.two)
        .glassSurface(radius: TonicRadiusToken.l)
    }

    // MARK: - Subtitle

    private var headerSubtitle: String {
        if let runSummaryText {
            return runSummaryText
        }

        switch mode {
        case .ready:
            return "Ready"
        case .scanning:
            return "Scanning"
        case .running:
            return "Running Smart Clean"
        case .results:
            return "Results"
        }
    }

    // MARK: - Hero State

    private var heroState: ScanHeroState {
        switch mode {
        case .ready:
            return .ready
        case .scanning:
            return .scanning(progress: scanProgress)
        case .running:
            return .scanning(progress: runProgress)
        case .results:
            return .results(
                space: spaceResultMetric,
                performance: performanceResultMetric,
                apps: appsResultMetric
            )
        }
    }

    // MARK: - Timeline & Counters

    private var timelineAndCounters: some View {
        HStack(spacing: TonicSpaceToken.two) {
            stageBadge(for: .space)
            stageBadge(for: .performance)
            stageBadge(for: .apps)
        }
    }

    // MARK: - Results Sections (Staggered)

    private var resultsSections: some View {
        VStack(spacing: TonicSpaceToken.three) {
            if blockedItemsCount > 0 {
                HStack(spacing: TonicSpaceToken.two) {
                    Text("\(blockedItemsCount) recommendation\(blockedItemsCount == 1 ? "" : "s") need additional access.")
                        .font(TonicTypeToken.caption)
                        .foregroundStyle(TonicTextToken.secondary)
                    Spacer()
                    Button("Grant Access") {
                        _ = accessBroker.addScopeUsingOpenPanel()
                        accessBroker.refreshStatuses()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding(TonicSpaceToken.two)
                .background(TonicGlassToken.fill)
                .clipShape(RoundedRectangle(cornerRadius: TonicRadiusToken.m))
            }

            ForEach(Array(sectionModels.enumerated()), id: \.element.id) { index, section in
                pillarSectionView(for: section)
                    .opacity(sectionOpacity(for: index))
                    .offset(y: sectionOffset(for: index))
                    .animation(
                        reduceMotion ? .none : sectionAnimation(for: index),
                        value: sectionsRevealed
                    )
            }
        }
    }

    private func pillarSectionView(for section: SmartScanPillarSectionModel) -> some View {
        VStack(spacing: TonicSpaceToken.two) {
            PillarSectionHeader(
                title: section.title,
                subtitle: section.subtitle,
                summary: section.summary,
                sectionActionTitle: section.sectionActionTitle,
                world: section.world,
                sectionAccessibilityIdentifier: sectionAccessibilityIdentifier(for: section.pillar),
                onSectionAction: {
                    onReviewTarget(section.sectionReviewTarget)
                }
            )

            BentoGrid(
                world: section.world,
                tiles: section.tiles,
                onReview: onReviewTarget,
                onAction: onTileAction
            )
        }
        .padding(TonicSpaceToken.two)
        .background(sectionBackground(for: section.world))
        .glassSurface(
            radius: TonicRadiusToken.container,
            variant: colorScheme == .dark ? .sunken : .raised
        )
    }

    private func sectionOpacity(for index: Int) -> Double {
        sectionsRevealed ? 1 : 0
    }

    private func sectionOffset(for index: Int) -> CGFloat {
        sectionsRevealed ? 0 : 16
    }

    private func sectionAnimation(for index: Int) -> Animation {
        // Stagger: Space(0ms), Performance(80ms), Apps(160ms)
        TonicMotionToken.resultCardSpring
            .delay(Double(index) * TonicMotionToken.resultStaggerDelay)
    }

    // MARK: - Command Dock

    private var commandDock: some View {
        SmartScanCommandDock(
            mode: mode,
            summary: dockSummary,
            primaryEnabled: dockPrimaryEnabled,
            secondaryTitle: mode == .results ? "Customize" : nil,
            onSecondaryAction: mode == .results ? onReviewCustomize : nil,
            action: primaryCommandAction
        )
    }

    private var dockSummary: String {
        switch mode {
        case .ready:
            return "Run Smart Scan across Space, Performance, and Apps."
        case .scanning:
            return "Scanning: \(Int(scanProgress * 100))% • Space: \(formatBytes(counters.spaceBytesFound)) • Performance: \(counters.performanceFlaggedCount) items • Apps: \(counters.appsScannedCount) apps"
        case .running:
            return "Running Smart Clean: \(Int(runProgress * 100))%"
        case .results:
            if blockedItemsCount > 0 {
                return "Recommended: \(recommendedCount) tasks • Needs access: \(blockedItemsCount) • Space: \(spaceResultMetric)"
            }
            return "Recommended: \(recommendedCount) tasks • Space: \(spaceResultMetric) • Apps: \(appsResultMetric)"
        }
    }

    private var blockedItemsCount: Int {
        (scanResult?.domainResults.values.flatMap(\.items) ?? [])
            .filter { $0.accessState != .ready }
            .count
    }

    private var dockPrimaryEnabled: Bool {
        switch mode {
        case .ready, .scanning, .running:
            return true
        case .results:
            return scanResult != nil && !quickActionIsRunning && quickActionSheet == nil
        }
    }

    private func primaryCommandAction() {
        switch mode {
        case .ready:
            onStartScan()
        case .scanning, .running:
            onStopScan()
        case .results:
            onRunSmartClean()
        }
    }

    // MARK: - Metrics

    private var spaceResultMetric: String {
        guard let result = scanResult?.domainResults[.cleanup] else { return "0 KB" }
        return formatBytes(result.totalSize)
    }

    private var performanceResultMetric: String {
        guard let result = scanResult?.domainResults[.performance] else { return "0 items" }
        return "\(result.totalUnitCount) items"
    }

    private var appsResultMetric: String {
        guard let result = scanResult?.domainResults[.applications] else { return "0 apps" }
        return "\(result.totalUnitCount) apps"
    }

    private var recommendedCount: Int {
        guard let scanResult else { return 0 }
        return scanResult.domainResults.values
            .flatMap { $0.items }
            .filter { $0.safeToRun && $0.action.isRunnable && $0.isSmartSelected }
            .count
    }

    // MARK: - Section Models

    private var sectionModels: [SmartScanPillarSectionModel] {
        [spaceSection, performanceSection, appsSection]
    }

    private var spaceSection: SmartScanPillarSectionModel {
        let systemItems = cleanupItems(containing: "system junk")
        let trashItems = cleanupItems(containing: "trash")
        let hiddenItems = cleanupItems(containing: "hidden")
        let xcodeItems = cleanupItems(containing: "xcode")

        return SmartScanPillarSectionModel(
            pillar: .space,
            title: "Space",
            subtitle: "Cleanup + Clutter",
            summary: "\(spaceResultMetric) reclaimable",
            sectionActionTitle: "Review All Junk",
            sectionReviewTarget: .section(.space),
            world: .cleanupGreen,
            tiles: [
                SmartScanBentoTileModel(
                    id: .spaceSystemJunk,
                    size: .large,
                    metricTitle: formatBytes(totalSize(of: systemItems)),
                    title: "System Junk Found",
                    subtitle: "Clean up unneeded files generated by your system and applications.",
                    iconSymbols: ["gearshape.2.fill", "clock.fill", "doc.text.fill"],
                    reviewTarget: .tile(.spaceSystemJunk),
                    actions: [
                        .init(title: "Review", kind: .review),
                        .init(title: "Clean", kind: .clean, enabled: hasRunnable(systemItems) && executionActionsEnabled)
                    ]
                ),
                SmartScanBentoTileModel(
                    id: .spaceTrashBins,
                    size: .wide,
                    metricTitle: formatBytes(totalSize(of: trashItems)),
                    title: "Trash Bins Found",
                    subtitle: "Delete the contents of your trash bins to reclaim drive space.",
                    iconSymbols: ["trash.fill"],
                    reviewTarget: .tile(.spaceTrashBins),
                    actions: [
                        .init(title: "Review", kind: .review),
                        .init(title: "Clean", kind: .clean, enabled: hasRunnable(trashItems) && executionActionsEnabled)
                    ]
                ),
                SmartScanBentoTileModel(
                    id: .spaceExtraBinaries,
                    size: .small,
                    metricTitle: formatBytes(totalSize(of: hiddenItems)),
                    title: "Extra Binaries Found",
                    subtitle: "Extra binary artifacts detected.",
                    iconSymbols: ["terminal.fill"],
                    reviewTarget: .tile(.spaceExtraBinaries),
                    actions: [.init(title: "Review", kind: .review)]
                ),
                SmartScanBentoTileModel(
                    id: .spaceXcodeJunk,
                    size: .small,
                    metricTitle: formatBytes(totalSize(of: xcodeItems)),
                    title: "Xcode Junk Found",
                    subtitle: "Developer caches and simulator runtimes.",
                    iconSymbols: ["hammer.fill", "chevron.left.forwardslash.chevron.right"],
                    reviewTarget: .tile(.spaceXcodeJunk),
                    actions: [.init(title: "Review", kind: .review)]
                )
            ]
        )
    }

    private var performanceSection: SmartScanPillarSectionModel {
        let maintenanceItems = performanceItems(named: "Maintenance Tasks")
        let loginItems = performanceItems(named: "Login Items")
        let backgroundItems = performanceItems(named: "Background Items")

        return SmartScanPillarSectionModel(
            pillar: .performance,
            title: "Performance",
            subtitle: "Optimize + Startup Control",
            summary: "\(performanceResultMetric) affecting startup",
            sectionActionTitle: "View All Tasks",
            sectionReviewTarget: .section(.performance),
            world: .performanceOrange,
            tiles: [
                SmartScanBentoTileModel(
                    id: .performanceMaintenanceTasks,
                    size: .large,
                    metricTitle: "\(maintenanceItems.count) Tasks",
                    title: "Maintenance Tasks Recommended",
                    subtitle: "Run curated maintenance tasks to keep your Mac responsive.",
                    iconSymbols: ["wrench.and.screwdriver.fill", "sparkles"],
                    reviewTarget: .tile(.performanceMaintenanceTasks),
                    actions: [
                        .init(title: "Review", kind: .review),
                        .init(title: "Run Tasks", kind: .run, enabled: hasRunnable(maintenanceItems) && executionActionsEnabled)
                    ]
                ),
                SmartScanBentoTileModel(
                    id: .performanceLoginItems,
                    size: .wide,
                    metricTitle: "\(loginItems.count) Items",
                    title: "Login Items Found",
                    subtitle: "Review applications that open automatically when you start your Mac.",
                    iconSymbols: ["person.crop.circle.badge.clock", "app.badge.fill"],
                    reviewTarget: .tile(.performanceLoginItems),
                    actions: [.init(title: "Review", kind: .review)]
                ),
                SmartScanBentoTileModel(
                    id: .performanceBackgroundItems,
                    size: .wide,
                    metricTitle: "\(backgroundItems.count) Items",
                    title: "Background Items Found",
                    subtitle: "Review background processes allowed to run continuously.",
                    iconSymbols: ["bolt.horizontal.circle.fill"],
                    reviewTarget: .tile(.performanceBackgroundItems),
                    actions: [.init(title: "Review", kind: .review)]
                )
            ]
        )
    }

    private var appsSection: SmartScanPillarSectionModel {
        let allApps = applicationsItems
        let updatesItems: [SmartCareItem] = []
        let unusedItems = allApps.filter { $0.title.lowercased().contains("unused") }
        let leftoversItems = allApps.filter { $0.title.lowercased().contains("orphaned") }
        let installationItems = allApps.filter {
            let title = $0.title.lowercased()
            return title.contains("installation") || title.contains("large")
        }

        return SmartScanPillarSectionModel(
            pillar: .apps,
            title: "Apps",
            subtitle: "Uninstall + Updates + Leftovers",
            summary: "\(appsResultMetric) found",
            sectionActionTitle: "Manage My Applications",
            sectionReviewTarget: .section(.apps),
            world: .applicationsBlue,
            tiles: [
                SmartScanBentoTileModel(
                    id: .appsUpdates,
                    size: .large,
                    metricTitle: "\(updatesItems.count) Updates",
                    title: "Application Updates Available",
                    subtitle: "Update software to stay current with features and compatibility fixes.",
                    iconSymbols: ["square.and.arrow.down.fill", "arrow.triangle.2.circlepath"],
                    reviewTarget: .tile(.appsUpdates),
                    actions: [
                        .init(title: "Review", kind: .review),
                        .init(title: "Update", kind: .update, enabled: hasRunnable(updatesItems) && executionActionsEnabled)
                    ]
                ),
                SmartScanBentoTileModel(
                    id: .appsUnused,
                    size: .wide,
                    metricTitle: "\(unusedItems.count) Unused",
                    title: "Unused Applications Found",
                    subtitle: "You may not need these apps and they still consume disk space.",
                    iconSymbols: ["folder.fill"],
                    reviewTarget: .tile(.appsUnused),
                    actions: [.init(title: "Review", kind: .review)]
                ),
                SmartScanBentoTileModel(
                    id: .appsLeftovers,
                    size: .small,
                    metricTitle: formatBytes(totalSize(of: leftoversItems)),
                    title: "App Leftovers Found",
                    subtitle: "Orphaned support files from removed apps.",
                    iconSymbols: ["trash.square.fill"],
                    reviewTarget: .tile(.appsLeftovers),
                    actions: [
                        .init(title: "Review", kind: .review),
                        .init(title: "Remove", kind: .remove, enabled: hasRunnable(leftoversItems) && executionActionsEnabled)
                    ]
                ),
                SmartScanBentoTileModel(
                    id: .appsInstallationFiles,
                    size: .small,
                    metricTitle: formatBytes(totalSize(of: installationItems)),
                    title: "Installation Files Found",
                    subtitle: "Installer payloads and package artifacts.",
                    iconSymbols: ["shippingbox.fill"],
                    reviewTarget: .tile(.appsInstallationFiles),
                    actions: [
                        .init(title: "Review", kind: .review),
                        .init(title: "Remove", kind: .remove, enabled: hasRunnable(installationItems) && executionActionsEnabled)
                    ]
                )
            ]
        )
    }

    // MARK: - Data Helpers

    private func cleanupItems(containing text: String) -> [SmartCareItem] {
        scanResult?.domainResults[.cleanup]?.groups
            .filter { $0.title.lowercased().contains(text) }
            .flatMap(\.items) ?? []
    }

    private func performanceItems(named group: String) -> [SmartCareItem] {
        scanResult?.domainResults[.performance]?.groups.first(where: { $0.title == group })?.items ?? []
    }

    private var applicationsItems: [SmartCareItem] {
        scanResult?.domainResults[.applications]?.items ?? []
    }

    private func hasRunnable(_ items: [SmartCareItem]) -> Bool {
        items.contains { $0.safeToRun && $0.action.isRunnable }
    }

    private var executionActionsEnabled: Bool {
        mode == .results && !quickActionIsRunning && quickActionSheet == nil
    }

    private func totalSize(of items: [SmartCareItem]) -> Int64 {
        items.reduce(0) { $0 + $1.size }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    // MARK: - Stage Badges

    private func stageBadge(for stage: SmartScanStage) -> some View {
        LiveCounterChip(
            label: stage.rawValue,
            value: stageValue(for: stage),
            isActive: currentStage == stage && mode == .scanning,
            isComplete: completedStages.contains(stage) || mode == .results || mode == .running
        )
    }

    private func stageValue(for stage: SmartScanStage) -> String? {
        switch mode {
        case .ready:
            return nil
        case .scanning:
            guard completedStages.contains(stage) else { return nil }
            return valueForCompletedStage(stage)
        case .running, .results:
            return valueForCompletedStage(stage)
        }
    }

    private func valueForCompletedStage(_ stage: SmartScanStage) -> String {
        switch stage {
        case .space:
            return formatBytes(counters.spaceBytesFound)
        case .performance:
            return "\(counters.performanceFlaggedCount) items"
        case .apps:
            return "\(counters.appsScannedCount) apps"
        }
    }

    // MARK: - Section Background

    private func sectionBackground(for world: TonicWorld) -> some View {
        ZStack {
            if colorScheme == .light {
                TonicNeutralToken.neutral1
                world.token.mid.opacity(0.04)
                RadialGradient(
                    colors: [world.token.light.opacity(0.08), .clear],
                    center: .topLeading,
                    startRadius: 22,
                    endRadius: 320
                )
            } else {
                TonicCanvasTokens.fill(for: world, colorScheme: colorScheme)
                TonicCanvasTokens.tint(for: world, colorScheme: colorScheme)
                RadialGradient(
                    colors: [TonicCanvasTokens.edgeGlow(for: world, colorScheme: colorScheme), .clear],
                    center: .topLeading,
                    startRadius: 24,
                    endRadius: 340
                )
            }
        }
    }

    private func sectionAccessibilityIdentifier(for pillar: SmartScanPillar) -> String {
        switch pillar {
        case .space:
            return "smartscan.review.space"
        case .performance:
            return "smartscan.review.performance"
        case .apps:
            return "smartscan.review.apps"
        }
    }
}

// MARK: - Scroll Offset Preference Key

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
