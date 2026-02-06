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
    let onStartScan: () -> Void
    let onStopScan: () -> Void
    let onRunSmartClean: () -> Void
    let onReviewCustomize: () -> Void
    let onReviewTarget: (SmartScanReviewTarget) -> Void

    var body: some View {
        VStack(spacing: TonicSpaceToken.three) {
            PageHeader(
                title: "Smart Scan",
                subtitle: headerSubtitle,
                showsBack: false,
                searchText: nil,
                onBack: nil,
                trailing: nil
            )

            ScrollView(showsIndicators: false) {
                VStack(spacing: TonicSpaceToken.three) {
                    ScanHeroModule(state: heroState)

                    if mode == .scanning || mode == .running || mode == .results {
                        timelineAndCounters
                    }

                    if mode == .results {
                        pillarCards
                    }
                }
                .padding(.bottom, TonicSpaceToken.three)
            }

            footer
        }
        .padding(TonicSpaceToken.three)
    }

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

    private var timelineAndCounters: some View {
        VStack(spacing: TonicSpaceToken.two) {
            ScanTimelineStepper(
                stages: SmartScanStage.allCases.map(\.rawValue),
                activeIndex: activeStageIndex,
                completed: Set(completedStageIndexes)
            )

            HStack(spacing: TonicSpaceToken.two) {
                LiveCounterChip(label: "Space", value: formatBytes(counters.spaceBytesFound))
                LiveCounterChip(label: "Performance", value: "\(counters.performanceFlaggedCount) items")
                LiveCounterChip(label: "Apps", value: "\(counters.appsScannedCount) apps")
            }
        }
    }

    private var pillarCards: some View {
        VStack(spacing: TonicSpaceToken.two) {
            ResultPillarCard(
                title: "Space",
                metric: spaceResultMetric,
                summary: "Cleanup + Clutter",
                preview: spaceContributors,
                reviewTitle: "Review Space",
                world: .cleanupGreen,
                reviewAccessibilityIdentifier: "smartscan.review.space",
                onReviewSection: { onReviewTarget(.section(.space)) },
                onReviewContributor: { contributor in
                    onReviewTarget(.contributor(id: contributor.id))
                }
            )

            ResultPillarCard(
                title: "Performance",
                metric: performanceResultMetric,
                summary: "Optimize + Startup Control",
                preview: performanceContributors,
                reviewTitle: "Review Performance",
                world: .performanceOrange,
                reviewAccessibilityIdentifier: "smartscan.review.performance",
                onReviewSection: { onReviewTarget(.section(.performance)) },
                onReviewContributor: { contributor in
                    onReviewTarget(.contributor(id: contributor.id))
                }
            )

            ResultPillarCard(
                title: "Apps",
                metric: appsResultMetric,
                summary: "Uninstall + Updates + Leftovers",
                preview: appContributors,
                reviewTitle: "Review Apps",
                world: .applicationsBlue,
                reviewAccessibilityIdentifier: "smartscan.review.apps",
                onReviewSection: { onReviewTarget(.section(.apps)) },
                onReviewContributor: { contributor in
                    onReviewTarget(.contributor(id: contributor.id))
                }
            )
        }
    }

    @ViewBuilder
    private var footer: some View {
        switch mode {
        case .ready:
            PrimaryScanButton(title: "Scan", icon: "magnifyingglass", action: onStartScan)
        case .scanning, .running:
            SecondaryPillButton(title: "Stop", action: onStopScan)
        case .results:
            StickyActionBar(
                summary: "Recommended: \(recommendedCount) tasks • Space: \(spaceResultMetric) • Apps: \(appsResultMetric)",
                variant: .cleanUp,
                enabled: scanResult != nil,
                secondaryTitle: "Review & Customize",
                onSecondaryAction: onReviewCustomize,
                secondaryAccessibilityIdentifier: "smartscan.review.customize",
                action: onRunSmartClean
            )
        }
    }

    private var activeStageIndex: Int {
        SmartScanStage.allCases.firstIndex(of: currentStage) ?? 0
    }

    private var completedStageIndexes: [Int] {
        completedStages.compactMap { SmartScanStage.allCases.firstIndex(of: $0) }
    }

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

    private var spaceContributors: [ResultContributor] {
        guard let cleanup = scanResult?.domainResults[.cleanup] else {
            return []
        }

        let sorted = cleanup.groups
            .filter { !$0.items.isEmpty }
            .sorted { left, right in
                groupSize(left) > groupSize(right)
            }
            .prefix(3)

        return sorted.map { group in
            ResultContributor(
                id: spaceContributorID(for: group.title),
                title: group.title,
                subtitle: group.description,
                metric: formatBytes(groupSize(group))
            )
        }
    }

    private var performanceContributors: [ResultContributor] {
        let performance = scanResult?.domainResults[.performance]
        let maintenanceCount = itemCount(in: performance, named: "Maintenance Tasks")
        let backgroundCount = itemCount(in: performance, named: "Background Items")
        let loginCount = itemCount(in: performance, named: "Login Items")

        return [
            ResultContributor(
                id: "maintenanceTasks",
                title: "Maintenance Tasks",
                subtitle: "Run optimization routines",
                metric: "\(maintenanceCount)"
            ),
            ResultContributor(
                id: "backgroundItems",
                title: "Background Items",
                subtitle: "Review background processes",
                metric: "\(backgroundCount)"
            ),
            ResultContributor(
                id: "loginItems",
                title: "Login Items",
                subtitle: "Review startup apps",
                metric: "\(loginCount)"
            )
        ]
    }

    private var appContributors: [ResultContributor] {
        guard let apps = scanResult?.domainResults[.applications] else {
            return []
        }

        let items = apps.items
        let uninstallerCount = items.filter { item in
            let title = item.title.lowercased()
            return title.contains("unused") || title.contains("duplicate") || title.contains("large")
        }.reduce(0) { $0 + $1.count }

        let leftoversCount = items.first(where: { $0.title.lowercased().contains("orphaned") })?.count ?? 0

        return [
            ResultContributor(
                id: "uninstaller",
                title: "Uninstaller",
                subtitle: "Unused, duplicate, and large apps",
                metric: "\(uninstallerCount)"
            ),
            ResultContributor(
                id: "updater",
                title: "Updater",
                subtitle: "Outdated applications",
                metric: "0"
            ),
            ResultContributor(
                id: "leftovers",
                title: "Leftovers",
                subtitle: "Orphaned support files",
                metric: "\(leftoversCount)"
            )
        ]
    }

    private func itemCount(in result: SmartCareDomainResult?, named groupTitle: String) -> Int {
        result?.groups.first(where: { $0.title == groupTitle })?.items.count ?? 0
    }

    private func groupSize(_ group: SmartCareGroup) -> Int64 {
        group.items.reduce(0) { $0 + $1.size }
    }

    private func spaceContributorID(for groupTitle: String) -> String {
        let lowercased = groupTitle.lowercased()
        if lowercased.contains("xcode") {
            return "xcodeJunk"
        }
        if lowercased.contains("download") {
            return "downloads"
        }
        if lowercased.contains("duplicate") {
            return "duplicates"
        }
        return "downloads"
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
