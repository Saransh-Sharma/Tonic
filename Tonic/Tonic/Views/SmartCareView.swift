import SwiftUI

struct SmartCareView: View {
    @ObservedObject var smartCareSession: SmartCareSessionStore
    @State private var dismissedSnackbarBatchID: UUID?

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
                .id(smartCareSession.destination)
                .transition(.opacity.combined(with: .scale(scale: 0.995)))
            }
            .overlay(alignment: .bottom) {
                undoSnackbar
            }
        }
        .tonicGlassRenderingMode(defaultGlassRenderingMode)
        .tonicForceLegacyGlass(false)
        .animation(AtelierMotion.standard, value: smartCareSession.destination)
        .sheet(item: $smartCareSession.pendingReview) { review in
            SmartCleanReviewSheet(
                review: review,
                onConfirm: { smartCareSession.confirmPendingReview() },
                onCancel: { smartCareSession.cancelPendingReview() }
            )
        }
    }

    @ViewBuilder
    private var undoSnackbar: some View {
        if let summary = activeRecoverableSummary,
           let batchID = summary.recoveryBatchID,
           dismissedSnackbarBatchID != batchID {
            UndoCleanupSnackbar(
                spaceFreed: summary.spaceFreed,
                recoverableCount: summary.recoverableCount,
                onUndo: {
                    smartCareSession.undoCleanup(batchID: batchID)
                    dismissedSnackbarBatchID = batchID
                },
                onDismiss: { dismissedSnackbarBatchID = batchID }
            )
            .padding(.bottom, TonicSpaceToken.three)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .id(batchID)
        }
    }

    /// The most recent summary that produced recoverable (trashed) items.
    private var activeRecoverableSummary: SmartScanRunSummary? {
        if let summary = smartCareSession.runSummary, summary.hasRecoverable {
            return summary
        }
        if let summary = smartCareSession.quickActionSummary, summary.hasRecoverable {
            return summary
        }
        return nil
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
            currentScanItem: smartCareSession.currentScanItem,
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

    private var defaultGlassRenderingMode: TonicGlassRenderingMode {
        if #available(macOS 26.0, *) {
            return .liquid
        } else {
            return .legacy
        }
    }
}

// MARK: - Undo Cleanup Snackbar

/// Transient "Cleaned X · Undo" toast shown after a cleanup that moved personal
/// files to the Trash. Auto-dismisses; Undo restores the batch.
struct UndoCleanupSnackbar: View {
    let spaceFreed: Int64
    let recoverableCount: Int
    let onUndo: () -> Void
    let onDismiss: () -> Void

    private var freedText: String {
        ByteCountFormatter.string(fromByteCount: spaceFreed, countStyle: .file)
    }

    var body: some View {
        HStack(spacing: TonicSpaceToken.two) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 1) {
                Text("Cleaned \(freedText)")
                    .font(TonicTypeToken.micro.weight(.semibold))
                    .foregroundStyle(TonicTextToken.primary)
                Text("\(recoverableCount) item\(recoverableCount == 1 ? "" : "s") moved to Trash")
                    .font(TonicTypeToken.micro)
                    .foregroundStyle(TonicTextToken.tertiary)
            }

            Divider().frame(height: 22).opacity(0.4)

            Button(action: onUndo) {
                Text("Undo")
                    .font(TonicTypeToken.micro.weight(.semibold))
                    .foregroundStyle(TonicTextToken.primary)
            }
            .buttonStyle(.plain)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(TonicTextToken.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, TonicSpaceToken.three)
        .padding(.vertical, TonicSpaceToken.two)
        .glassSurface(radius: TonicRadiusToken.l)
        .shadow(color: .black.opacity(0.25), radius: 16, y: 6)
        .task {
            // Auto-dismiss after a few seconds.
            try? await Task.sleep(nanoseconds: 8 * 1_000_000_000)
            onDismiss()
        }
    }
}

// MARK: - Smart Clean Review Sheet

/// Shown before a cleanup that includes personal files. Lists the personal items
/// that will be moved to the Trash (recoverable) and notes any junk removed
/// permanently. Pure-junk cleans skip this sheet entirely.
struct SmartCleanReviewSheet: View {
    let review: SmartCleanReviewState
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: TonicSpaceToken.three) {
            HStack(spacing: TonicSpaceToken.two) {
                Image(systemName: "arrow.up.bin")
                    .font(.system(size: 22))
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Review before removing")
                        .font(TonicTypeToken.body.weight(.semibold))
                        .foregroundStyle(TonicTextToken.primary)
                    Text("\(review.personalCount) personal item\(review.personalCount == 1 ? "" : "s") · \(review.formattedPersonalSize) will be moved to the Trash")
                        .font(TonicTypeToken.micro)
                        .foregroundStyle(TonicTextToken.tertiary)
                }
                Spacer()
            }

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(review.personalItems) { item in
                        reviewRow(item)
                        if item.id != review.personalItems.last?.id {
                            Divider().opacity(0.4)
                        }
                    }
                }
            }
            .frame(maxHeight: 260)
            .glassSurface(radius: TonicRadiusToken.m)

            if !review.junkItems.isEmpty {
                Label("\(review.junkItems.count) system-junk item\(review.junkItems.count == 1 ? "" : "s") will be removed permanently to reclaim space.", systemImage: "info.circle")
                    .font(TonicTypeToken.micro)
                    .foregroundStyle(TonicTextToken.tertiary)
            }

            HStack(spacing: TonicSpaceToken.two) {
                Spacer()
                SecondaryPillButton(title: "Cancel", action: onCancel)
                PrimaryActionButton(title: "Move to Trash & Clean", icon: "trash") {
                    onConfirm()
                }
            }
        }
        .padding(TonicSpaceToken.four)
        .frame(width: 460)
        .background(WorldCanvasBackground().ignoresSafeArea())
    }

    private func reviewRow(_ item: SmartCareItem) -> some View {
        HStack(spacing: TonicSpaceToken.two) {
            Image(systemName: "doc")
                .font(.system(size: 13))
                .foregroundStyle(TonicTextToken.tertiary)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(TonicTypeToken.micro.weight(.medium))
                    .foregroundStyle(TonicTextToken.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(item.subtitle)
                    .font(TonicTypeToken.micro)
                    .foregroundStyle(TonicTextToken.tertiary)
                    .lineLimit(1)
            }
            Spacer()
            Text(item.formattedSize)
                .font(TonicTypeToken.micro)
                .foregroundStyle(TonicTextToken.secondary)
            if let first = item.paths.first {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: first)])
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(TonicTextToken.tertiary)
                }
                .buttonStyle(.plain)
                .help("Reveal in Finder")
            }
        }
        .padding(.vertical, TonicSpaceToken.one)
        .padding(.horizontal, TonicSpaceToken.two)
    }
}

#Preview {
    SmartCareView(smartCareSession: SmartCareSessionStore())
}
