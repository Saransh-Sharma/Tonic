import SwiftUI

struct SmartCareView: View {
    @ObservedObject var smartCareSession: SmartCareSessionStore

    var body: some View {
        TonicThemeProvider(world: smartCareSession.activeWorld) {
            ZStack {
                WorldCanvasBackground()

                Group {
                    switch smartCareSession.destination {
                    case .smartScan:
                        hubView
                    case .manager(let route):
                        managerView(for: route)
                    }
                }
            }
        }
    }

    private var hubView: some View {
        SmartScanHubView(
            mode: smartCareSession.hubMode,
            scanProgress: smartCareSession.scanProgress,
            runProgress: smartCareSession.runProgress,
            currentStage: smartCareSession.currentStage,
            completedStages: smartCareSession.completedStages,
            counters: smartCareSession.liveCounters,
            scanResult: smartCareSession.scanResult,
            runSummaryText: smartCareSession.runSummaryText,
            quickActionSheet: smartCareSession.quickActionSheet,
            quickActionProgress: smartCareSession.quickActionProgress,
            quickActionSummary: smartCareSession.quickActionSummary,
            quickActionIsRunning: smartCareSession.quickActionIsRunning,
            onStartScan: smartCareSession.startScan,
            onStopScan: smartCareSession.stopCurrentOperation,
            onRunSmartClean: smartCareSession.runSmartClean,
            onReviewCustomize: smartCareSession.reviewCustomize,
            onReviewTarget: smartCareSession.review(target:),
            onTileAction: smartCareSession.presentQuickAction(for:action:),
            onQuickActionStart: smartCareSession.startQuickActionRun,
            onQuickActionStop: smartCareSession.stopQuickActionRun,
            onQuickActionDone: smartCareSession.dismissQuickActionSummary
        )
    }

    @ViewBuilder
    private func managerView(for route: ManagerRoute) -> some View {
        switch route {
        case .space(let focus):
            SpaceManagerView(
                domainResult: smartCareSession.scanResult?.domainResults[.cleanup],
                focus: focus,
                selectedItemIDs: selectedItemIDsBinding,
                onBack: {
                    smartCareSession.showHub()
                },
                onRunSelected: { items in
                    smartCareSession.runSelected(items)
                }
            )
        case .performance(let focus):
            PerformanceManagerView(
                domainResult: smartCareSession.scanResult?.domainResults[.performance],
                focus: focus,
                selectedItemIDs: selectedItemIDsBinding,
                onBack: {
                    smartCareSession.showHub()
                },
                onRunSelected: { items in
                    smartCareSession.runSelected(items)
                }
            )
        case .apps(let focus):
            AppsManagerView(
                domainResult: smartCareSession.scanResult?.domainResults[.applications],
                focus: focus,
                selectedItemIDs: selectedItemIDsBinding,
                onBack: {
                    smartCareSession.showHub()
                },
                onRunSelected: { items in
                    smartCareSession.runSelected(items)
                }
            )
        }
    }
    
    private var selectedItemIDsBinding: Binding<Set<UUID>> {
        Binding(
            get: { smartCareSession.selectedItemIDs },
            set: { smartCareSession.selectedItemIDs = $0 }
        )
    }
}

#Preview {
    SmartCareView(smartCareSession: SmartCareSessionStore())
}
