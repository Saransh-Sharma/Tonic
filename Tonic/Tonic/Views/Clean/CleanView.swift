//
//  CleanView.swift
//  Tonic
//
//  The unified Clean domain — Smart Scan (guided), Storage (manual explore of scan
//  findings), and History (restore). One review → clean → undo model. Drives the
//  preserved SmartCareSessionStore + CleanupHistoryStore.
//

import SwiftUI

enum CleanTab: String, CaseIterable, Hashable {
    case smartScan = "Smart Scan"
    case storage = "Storage"
    case history = "History"
}

struct CleanView: View {
    @ObservedObject var session: SmartCareSessionStore
    var initialTab: CleanTab = .smartScan

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var tab: CleanTab = .smartScan
    @State private var didSetInitial = false
    @State private var toast: ToastData?
    @State private var historyBatches: [CleanupHistoryBatch] = []
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.lg) {
            header
                .tonicAppear(appeared, index: 0, reduceMotion: reduceMotion)
            runNotice
                .tonicAppear(appeared, index: 1, reduceMotion: reduceMotion)
            Group {
                switch tab {
                case .smartScan: smartScanTab
                case .storage: storageTab
                case .history: historyTab
                }
            }
            .id(tab)
            .transition(.opacity)
            .animation(reduceMotion ? nil : TonicDS.Motion.present, value: tab)
            .tonicAppear(appeared, index: 2, reduceMotion: reduceMotion)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: TonicDS.Layout.maxContentWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .tonicScreenHPadding()
        .padding(.vertical, TonicDS.Space.xxl)
        .background(TonicDS.Colors.canvas)
        .tonicToast($toast)
        .onAppear {
            if !didSetInitial { tab = initialTab; didSetInitial = true }
            refreshHistory()
            appeared = true
        }
        .onChange(of: session.runSummary?.recoveryBatchID) { _, _ in handleRunSummary() }
        .sheet(isPresented: reviewBinding) { reviewSheet }
    }

    // MARK: - Header

    private var header: some View {
        // A compact deep-green identity band frames the whole module; the tab bar sits on
        // canvas below it, so every tab reads as content within Clean (band → canvas → band).
        // featureHeading here, not sectionDisplay — the oversized voice belongs to the tab body.
        VStack(alignment: .leading, spacing: TonicDS.Space.md) {
            ModuleBand(band: .green) {
                VStack(alignment: .leading, spacing: TonicDS.Space.xxs) {
                    MonoLabel("Clean", color: TonicDS.Colors.onDarkMuted)
                    Text("Review before cleaning · Runs locally · Restore supported")
                        .tonicType(.featureHeading)
                        .foregroundStyle(TonicDS.Colors.onDark)
                }
            }
            TonicTabBar(tabs: CleanTab.allCases, selection: $tab) { $0.rawValue }
        }
    }

    @ViewBuilder
    private var runNotice: some View {
        if let summary = session.runSummary, summary.errors > 0 {
            TonicInlineNotice(
                message: "\(summary.formattedSummary) · \(summary.errors) task\(summary.errors == 1 ? "" : "s") need review.",
                tone: .warning
            )
        } else if let message = session.runSummary?.message {
            TonicInlineNotice(message: message, tone: .info)
        }
    }

    // MARK: - Smart Scan tab

    @ViewBuilder
    private var smartScanTab: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: TonicDS.Space.lg) {
                switch session.hubMode {
                case .ready:
                    readyBand
                    checksPreview
                case .scanning, .running:
                    progressBand
                case .results:
                    resultsSummary
                    resultsCards
                }
            }
            .padding(.bottom, TonicDS.Space.xxl)
        }
    }

    private var readyBand: some View {
        ModuleBand(band: .green) {
            VStack(alignment: .leading, spacing: TonicDS.Space.lg) {
                Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                    .font(.system(size: 40, weight: .thin))
                    .foregroundStyle(TonicDS.Colors.onDark)
                VStack(alignment: .leading, spacing: TonicDS.Space.sm) {
                    Text("Smart Scan").tonicType(.sectionDisplay).foregroundStyle(TonicDS.Colors.onDark)
                    Text("Run an intelligent scan across Space, Performance, and Apps.")
                        .tonicType(.bodyLarge).foregroundStyle(TonicDS.Colors.onDarkMuted)
                }
                HStack(spacing: TonicDS.Space.md) {
                    PrimaryPill("Run Smart Scan", systemImage: "sparkles", onDark: true) { session.startScan() }
                    TextAction("What gets scanned?", color: TonicDS.Colors.onDark) {}
                }
            }
        }
    }

    private var checksPreview: some View {
        TonicBentoGrid(minTileWidth: 240) {
            checkCard("Space", "trash", "Cache, logs, large files, hidden space")
            checkCard("Performance", "bolt", "Startup agents, background load")
            checkCard("Apps", "app.badge", "Large or old apps and leftovers")
        }
    }

    private func checkCard(_ title: String, _ icon: String, _ desc: String) -> some View {
        ScanCategoryCard {
            VStack(alignment: .leading, spacing: TonicDS.Space.sm) {
                Image(systemName: icon).font(.system(size: 18, weight: .thin))
                    .foregroundStyle(TonicDS.Colors.textMuted)
                Text(title).tonicType(.featureHeading).foregroundStyle(TonicDS.Colors.textPrimary)
                Text(desc).tonicType(.caption).foregroundStyle(TonicDS.Colors.textMuted)
            }
        }
        .tonicHoverLift()
    }

    private var progressBand: some View {
        ModuleBand(band: .green) {
            VStack(alignment: .leading, spacing: TonicDS.Space.lg) {
                HStack {
                    Text(session.hubMode == .running ? "Cleaning…" : "Scanning…")
                        .tonicType(.sectionDisplay).foregroundStyle(TonicDS.Colors.onDark)
                    Spacer()
                    Button { session.stopCurrentOperation() } label: {
                        Text("Stop").tonicType(.button).foregroundStyle(TonicDS.Colors.onDark)
                            .padding(.horizontal, 14).padding(.vertical, 6)
                            .overlay(Capsule().strokeBorder(TonicDS.Colors.hairlineOnDark, lineWidth: 1))
                    }
                    .buttonStyle(TonicPressStyle()).tonicPointerCursor()
                }

                // Stage row
                HStack(spacing: TonicDS.Space.lg) {
                    ForEach(SmartScanStage.allCases) { stage in
                        HStack(spacing: TonicDS.Space.xs) {
                            Circle().fill(stageColor(stage)).frame(width: 6, height: 6)
                            Text(stage.rawValue.uppercased()).tonicType(.monoLabel)
                                .foregroundStyle(stage == session.currentStage ? TonicDS.Colors.onDark : TonicDS.Colors.onDarkMuted)
                        }
                    }
                }

                // Live counters
                HStack(spacing: TonicDS.Space.xxl) {
                    counter("SPACE FOUND", Self.bytes(session.liveCounters.spaceBytesFound))
                    counter("FLAGGED", "\(session.liveCounters.performanceFlaggedCount)")
                    counter("APPS", "\(session.liveCounters.appsScannedCount)")
                }

                // Progress bar
                progressBar(session.hubMode == .running ? session.runProgress : session.scanProgress)

                if let item = session.currentScanItem {
                    Text(item).tonicType(.monoLabel).foregroundStyle(TonicDS.Colors.onDarkMuted)
                        .lineLimit(1).truncationMode(.middle)
                }
            }
        }
    }

    private func counter(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).tonicType(.metric).monospacedDigit().foregroundStyle(TonicDS.Colors.onDark)
                .contentTransition(.numericText())
            Text(label).tonicType(.monoLabel).foregroundStyle(TonicDS.Colors.onDarkMuted)
        }
    }

    private func progressBar(_ value: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(TonicDS.Colors.hairlineOnDark).frame(height: 4)
                Capsule().fill(TonicDS.Colors.onDark)
                    .frame(width: max(0, min(1, value)) * geo.size.width, height: 4)
            }
        }
        .frame(height: 4)
    }

    private func stageColor(_ stage: SmartScanStage) -> Color {
        if session.completedStages.contains(stage) { return TonicDS.Colors.statusSuccess }
        if stage == session.currentStage { return TonicDS.Colors.onDark }
        return TonicDS.Colors.onDarkMuted
    }

    private var resultsSummary: some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.md) {
            ModuleBand(band: .green) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: TonicDS.Space.xs) {
                        Text("Scan complete").tonicType(.monoLabel).foregroundStyle(TonicDS.Colors.onDarkMuted)
                        Metric(Self.bytes(session.scanResult?.totalReclaimableSize ?? 0), unit: "recoverable", color: TonicDS.Colors.onDark)
                    }
                    Spacer()
                    PrimaryPill("Run Smart Clean", systemImage: "sparkles", onDark: true) { session.runSmartClean() }
                }
            }
            if let summary = session.runSummary {
                Text(summary.formattedSummary).tonicType(.body).foregroundStyle(TonicDS.Colors.textMuted)
            }
        }
    }

    private var resultsCards: some View {
        TonicBentoGrid(minTileWidth: 260) {
            ForEach(Array(SmartCareDomain.allCases.enumerated()), id: \.element) { index, domain in
                if let result = session.scanResult?.domainResults[domain], !result.items.isEmpty {
                    domainCard(domain, result)
                        .tonicAppear(appeared, index: index, reduceMotion: reduceMotion)
                }
            }
        }
    }

    private func domainCard(_ domain: SmartCareDomain, _ result: SmartCareDomainResult) -> some View {
        ScanCategoryCard {
            VStack(alignment: .leading, spacing: TonicDS.Space.sm) {
                HStack(alignment: .firstTextBaseline) {
                    Text(domain.title).tonicType(.featureHeading).foregroundStyle(TonicDS.Colors.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .layoutPriority(1)
                    Spacer()
                    Metric(Self.bytes(result.totalSize), color: TonicDS.Colors.textPrimary)
                        .fixedSize(horizontal: true, vertical: false)
                }
                TonicHairline()
                ForEach(result.items.prefix(3)) { item in
                    HStack(spacing: TonicDS.Space.xs) {
                        Image(systemName: "checkmark").font(.system(size: 10, weight: .bold))
                            .foregroundStyle(TonicDS.Colors.statusSuccess)
                        Text(item.title).tonicType(.caption).foregroundStyle(TonicDS.Colors.textPrimary).lineLimit(1)
                        Spacer()
                        Text(Self.bytes(item.size)).tonicType(.monoLabel).foregroundStyle(TonicDS.Colors.textMuted)
                    }
                }
                if result.items.count > 3 {
                    TextAction("Review \(result.items.count) items", color: TonicDS.Colors.linkBlue) { tab = .storage }
                }
            }
        }
    }

    // MARK: - Storage tab (manual explore of scan findings)

    @ViewBuilder
    private var storageTab: some View {
        if let result = session.scanResult {
            let items = result.domainResults.values.flatMap { $0.items }.sorted { $0.size > $1.size }
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(items.prefix(60)) { item in
                        storageRow(item)
                        TonicHairline()
                    }
                }
            }
        } else if session.hubMode == .scanning || session.hubMode == .running {
            // A scan is populating findings — honest skeleton rows, never invented data.
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(0..<10, id: \.self) { _ in
                        storageRowSkeleton
                        TonicHairline()
                    }
                }
            }
            .accessibilityLabel("Scanning storage")
        } else {
            TonicEmptyState(
                systemImage: "externaldrive",
                title: "Nothing to explore yet",
                message: "Run a Smart Scan to explore recoverable storage by size.",
                actionTitle: "Run Smart Scan",
                onAction: { tab = .smartScan; session.startScan() }
            )
        }
    }

    private func storageRow(_ item: SmartCareItem) -> some View {
        SystemListRow(
            leading: {
                Image(systemName: item.domain.icon).font(.system(size: 14)).frame(width: 20)
                    .foregroundStyle(TonicDS.Colors.textMuted)
            },
            center: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title).tonicType(.body).foregroundStyle(TonicDS.Colors.textPrimary).lineLimit(1)
                    Text(item.subtitle).tonicType(.caption).foregroundStyle(TonicDS.Colors.textMuted).lineLimit(1)
                }
            },
            trailing: {
                Text(Self.bytes(item.size)).tonicType(.monoLabel).foregroundStyle(TonicDS.Colors.textPrimary)
                    .monospacedDigit()
            }
        )
    }

    private var storageRowSkeleton: some View {
        HStack(spacing: TonicDS.Space.md) {
            RoundedRectangle(cornerRadius: TonicDS.Radius.xs, style: .continuous)
                .fill(TonicDS.Colors.hairline).frame(width: 20, height: 20).skeleton()
            VStack(alignment: .leading, spacing: TonicDS.Space.xs) {
                RoundedRectangle(cornerRadius: TonicDS.Radius.xs, style: .continuous)
                    .fill(TonicDS.Colors.hairline).frame(width: 200, height: 12).skeleton()
                RoundedRectangle(cornerRadius: TonicDS.Radius.xs, style: .continuous)
                    .fill(TonicDS.Colors.hairline).frame(width: 120, height: 10).skeleton()
            }
            Spacer()
            RoundedRectangle(cornerRadius: TonicDS.Radius.xs, style: .continuous)
                .fill(TonicDS.Colors.hairline).frame(width: 56, height: 12).skeleton()
        }
        .padding(.horizontal, TonicDS.Space.md)
        .frame(minHeight: TonicDS.Layout.minRowHeight)
    }

    // MARK: - History tab

    @ViewBuilder
    private var historyTab: some View {
        if historyBatches.isEmpty {
            TonicEmptyState(
                systemImage: "clock.arrow.circlepath",
                title: "No cleanup history",
                message: "Items you clean will appear here, ready to restore."
            )
        } else {
            ScrollView(showsIndicators: false) {
                VStack(spacing: TonicDS.Space.md) {
                    ForEach(historyBatches) { batch in
                        historyCard(batch)
                    }
                }
                .padding(.bottom, TonicDS.Space.xl)
            }
        }
    }

    private func historyCard(_ batch: CleanupHistoryBatch) -> some View {
        DataCard {
            VStack(alignment: .leading, spacing: TonicDS.Space.sm) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(batch.title).tonicType(.featureHeading).foregroundStyle(TonicDS.Colors.textPrimary)
                        Text(batch.date.formatted(date: .abbreviated, time: .shortened))
                            .tonicType(.caption).foregroundStyle(TonicDS.Colors.textMuted)
                    }
                    Spacer()
                    Metric(batch.formattedTotalSize, color: TonicDS.Colors.textPrimary)
                }
                if batch.hasRecoverable {
                    TonicHairline()
                    HStack {
                        Text("\(batch.recoverableEntries.count) recoverable")
                            .tonicType(.caption).foregroundStyle(TonicDS.Colors.textMuted)
                        Spacer()
                        TextAction("Restore", color: TonicDS.Colors.linkBlue) { restore(batch) }
                    }
                }
            }
        }
    }

    // MARK: - Review sheet

    private var reviewBinding: Binding<Bool> {
        Binding(get: { session.pendingReview != nil }, set: { if !$0 { session.cancelPendingReview() } })
    }

    @ViewBuilder
    private var reviewSheet: some View {
        if let review = session.pendingReview {
            SheetChrome(title: "Review before cleaning", onClose: { session.cancelPendingReview() }) {
                VStack(spacing: 0) {
                    ForEach(review.items) { item in
                        HStack(spacing: TonicDS.Space.sm) {
                            Image(systemName: item.domain.icon).font(.system(size: 13)).frame(width: 18)
                                .foregroundStyle(TonicDS.Colors.textMuted)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title).tonicType(.body).foregroundStyle(TonicDS.Colors.textPrimary).lineLimit(1)
                                Text(item.subtitle).tonicType(.caption).foregroundStyle(TonicDS.Colors.textMuted).lineLimit(1)
                            }
                            Spacer()
                            Text(Self.bytes(item.size)).tonicType(.monoLabel).foregroundStyle(TonicDS.Colors.textPrimary)
                        }
                        .frame(minHeight: 40)
                        TonicHairline()
                    }
                }
            } footer: {
                TextAction("Cancel") { session.cancelPendingReview() }
                PrimaryPill("Move to Trash") { session.confirmPendingReview() }
            }
            .frame(width: 520, height: 560)
        }
    }

    // MARK: - Actions

    private func handleRunSummary() {
        guard let summary = session.runSummary else { return }
        if summary.hasRecoverable, let batchID = summary.recoveryBatchID {
            toast = ToastData(
                message: summary.formattedSummary,
                actionTitle: "Undo",
                action: {
                    Task { _ = await CleanupHistoryStore.shared.restoreBatch(batchID); await MainActor.run { refreshHistory() } }
                }
            )
        } else if summary.tasksRun > 0 {
            toast = ToastData(message: summary.formattedSummary)
        }
        refreshHistory()
    }

    private func restore(_ batch: CleanupHistoryBatch) {
        Task {
            _ = await CleanupHistoryStore.shared.restoreBatch(batch.id)
            await MainActor.run { refreshHistory() }
        }
    }

    private func refreshHistory() {
        historyBatches = CleanupHistoryStore.shared.batches
    }

    private static func bytes(_ value: Int64) -> String {
        let f = ByteCountFormatter(); f.allowedUnits = [.useGB, .useMB, .useKB]; f.countStyle = .file
        return f.string(fromByteCount: value)
    }
}
