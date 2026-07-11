//
//  CleanView.swift
//  Tonic
//
//  The unified Clean domain — Smart Scan (guided), Storage (manual explore of scan
//  findings), and History (restore). One review → clean → undo model. Drives the
//  preserved SmartCareSessionStore + CleanupHistoryStore.
//

import AppKit
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
    @State private var revealedRecoverableBytes: Int64 = 0
    @State private var showAllStorage = false

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
        .tonicCanvas()
        // Undo toasts hold longer than informational ones — the undo window is a promise.
        .tonicToast($toast, autoDismiss: 10)
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
            ModuleBand(band: .green, contentPadding: TonicDS.Space.lg) {
                VStack(alignment: .leading, spacing: TonicDS.Space.xxs) {
                    MonoLabel("Clean", color: TonicDS.Colors.onDarkMuted)
                    Text(headerSubtitle)
                        .tonicType(.featureHeading)
                        .foregroundStyle(TonicDS.Colors.onDark)
                }
            }
            TonicTabBar(tabs: CleanTab.allCases, selection: $tab) { $0.rawValue }
        }
    }

    private var headerSubtitle: String {
        switch tab {
        case .smartScan: return "Review before cleaning · Runs locally · Restore supported"
        case .storage: return "Explore recoverable storage by size"
        case .history: return "Restore items from past cleanups"
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
        // Mono labels, not feature headings — the ready band's sectionDisplay is the
        // one oversized voice on this surface; the preview cards stay quiet.
        ScanCategoryCard {
            VStack(alignment: .leading, spacing: TonicDS.Space.sm) {
                Image(systemName: icon).font(.system(size: 18, weight: .thin))
                    .foregroundStyle(TonicDS.Colors.textMuted)
                MonoLabel(title, color: TonicDS.Colors.textPrimary)
                Text(desc).tonicType(.caption).foregroundStyle(TonicDS.Colors.textMuted)
            }
        }
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

                // Stage annunciator row
                HStack(spacing: TonicDS.Space.lg) {
                    ForEach(SmartScanStage.allCases) { stage in
                        HStack(spacing: TonicDS.Space.xs) {
                            StatusDot(stageColor(stage))
                            Text(stage.rawValue.uppercased()).tonicType(.monoLabel)
                                .foregroundStyle(stage == session.currentStage ? TonicDS.Colors.onDark : TonicDS.Colors.onDarkMuted)
                        }
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(stageAccessibilityText)
                .onChange(of: session.currentStage) { _, stage in
                    guard session.hubMode == .scanning else { return }
                    AccessibilityNotification.Announcement("Scanning \(stage.rawValue)").post()
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
                        .help(item)
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
        TonicProgressBar(
            fraction: value,
            color: TonicDS.Colors.onDark,
            trackColor: TonicDS.Colors.hairlineOnDark,
            height: 4
        )
    }

    private func stageColor(_ stage: SmartScanStage) -> Color {
        if session.completedStages.contains(stage) { return TonicDS.Colors.statusSuccess }
        if stage == session.currentStage { return TonicDS.Colors.onDark }
        return TonicDS.Colors.onDarkMuted
    }

    private var stageAccessibilityText: String {
        let done = SmartScanStage.allCases.filter { session.completedStages.contains($0) }
        var parts = ["Currently scanning \(session.currentStage.rawValue)"]
        if !done.isEmpty { parts.append("completed: \(done.map(\.rawValue).joined(separator: ", "))") }
        return parts.joined(separator: ". ")
    }

    private var resultsSummary: some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.md) {
            ModuleBand(band: .green) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: TonicDS.Space.xs) {
                        Text("Scan complete").tonicType(.monoLabel).foregroundStyle(TonicDS.Colors.onDarkMuted)
                        // The proof moment: the recovered total rolls up from zero once —
                        // the one piece of earned drama in the scan story.
                        Metric(Self.bytes(revealedRecoverableBytes), unit: "recoverable", color: TonicDS.Colors.onDark)
                        if let detail = resultsDetailLine {
                            Text(detail).tonicType(.caption).foregroundStyle(TonicDS.Colors.onDarkMuted)
                        }
                    }
                    Spacer()
                    PrimaryPill("Run Smart Clean", systemImage: "sparkles", onDark: true) { session.runSmartClean() }
                }
            }
            if let summary = session.runSummary {
                Text(summary.formattedSummary).tonicType(.body).foregroundStyle(TonicDS.Colors.textMuted)
            }
        }
        .onAppear { revealRecoverableTotal() }
        .onChange(of: session.scanResult?.totalReclaimableSize) { _, _ in revealRecoverableTotal() }
    }

    private var resultsDetailLine: String? {
        guard let result = session.scanResult else { return nil }
        let itemCount = result.domainResults.values.reduce(0) { $0 + $1.items.count }
        guard itemCount > 0 else { return nil }
        let domainCount = result.domainResults.values.filter { !$0.items.isEmpty }.count
        return "\(itemCount) item\(itemCount == 1 ? "" : "s") across \(domainCount) categor\(domainCount == 1 ? "y" : "ies") · review before cleaning"
    }

    private func revealRecoverableTotal() {
        let total = session.scanResult?.totalReclaimableSize ?? 0
        guard revealedRecoverableBytes != total else { return }
        if reduceMotion {
            revealedRecoverableBytes = total
            return
        }
        revealedRecoverableBytes = 0
        withAnimation(.easeOut(duration: 0.6)) { revealedRecoverableBytes = total }
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
            let visible = showAllStorage ? items : Array(items.prefix(60))
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    storageTrendCard
                        .padding(.horizontal, TonicDS.Space.md)
                        .padding(.bottom, TonicDS.Space.md)
                    whatGrewCard
                        .padding(.horizontal, TonicDS.Space.md)
                        .padding(.bottom, TonicDS.Space.md)
                    DiskMapCard()
                        .padding(.horizontal, TonicDS.Space.md)
                        .padding(.bottom, TonicDS.Space.md)
                    if let report = result.hiddenSpaceReport, report.hasDiscrepancy {
                        hiddenSpaceCard(report)
                            .padding(.horizontal, TonicDS.Space.md)
                            .padding(.bottom, TonicDS.Space.md)
                    }
                    MonoLabel("\(items.count) items · sorted by size, largest first")
                        .padding(.horizontal, TonicDS.Space.md)
                        .padding(.bottom, TonicDS.Space.sm)
                    ForEach(visible) { item in
                        storageRow(item)
                        TonicHairline()
                    }
                    if !showAllStorage && items.count > 60 {
                        TextAction("Show all \(items.count) items", color: TonicDS.Colors.linkBlue) {
                            showAllStorage = true
                        }
                        .padding(.horizontal, TonicDS.Space.md)
                        .padding(.vertical, TonicDS.Space.sm)
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
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: TonicDS.Space.md) {
                    DiskMapCard()
                        .padding(.horizontal, TonicDS.Space.md)
                        .padding(.top, TonicDS.Space.md)
                    TonicEmptyState(
                        systemImage: "externaldrive",
                        title: "Nothing to explore yet",
                        message: "Run a Smart Scan to explore recoverable storage by size.",
                        actionTitle: "Run Smart Scan",
                        onAction: { tab = .smartScan; session.startScan() }
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, TonicDS.Space.xl)
                }
            }
        }
    }

    /// Disk-usage trend over the trailing 90 days with the conservative
    /// "full in ~N weeks" forecast. Quiet and honest while history accrues.
    @ViewBuilder
    private var storageTrendCard: some View {
        let store = DiskUsageHistoryStore.shared
        let samples = store.samples(days: 90)
        if samples.count >= 2, let latest = samples.last {
            let total = latest.usedBytes + latest.freeBytes
            let fraction = total > 0 ? Double(latest.usedBytes) / Double(total) : 0
            VStack(alignment: .leading, spacing: TonicDS.Space.xs) {
                ChartCard(
                    label: "STORAGE · 90 DAYS",
                    displayValue: Self.bytes(latest.usedBytes),
                    unit: "used",
                    history: samples.map { Double($0.usedBytes) },
                    fraction: fraction
                )
                if let forecast = store.forecast() {
                    MonoLabel("AT THIS RATE · FULL IN ~\(forecast.weeksUntilFull) WK · +\(Self.bytes(forecast.bytesPerDay))/DAY")
                        .foregroundStyle(TonicDS.status(forFraction: max(fraction, 0.76)))
                        .padding(.horizontal, TonicDS.Space.xs)
                } else {
                    MonoLabel("\(samples.count) DAILY SAMPLES · TREND STEADY OR STILL FORMING")
                        .padding(.horizontal, TonicDS.Space.xs)
                }
            }
        }
    }

    /// Where new usage came from: the largest directory growth between the
    /// last two scan snapshots. Quiet until two snapshots exist.
    @ViewBuilder
    private var whatGrewCard: some View {
        let growth = DirectorySnapshotStore.shared.topGrowth()
        if !growth.isEmpty {
            DataCard(lift: false) {
                VStack(alignment: .leading, spacing: TonicDS.Space.sm) {
                    MonoLabel("WHAT GREW SINCE LAST SCAN")
                    ForEach(growth, id: \.path) { entry in
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(entry.displayName).tonicType(.body)
                                    .foregroundStyle(TonicDS.Colors.textPrimary)
                                    .lineLimit(1)
                                Text("now \(Self.bytes(entry.currentSize))").tonicType(.micro)
                                    .foregroundStyle(TonicDS.Colors.textMuted)
                            }
                            Spacer()
                            Text("+\(Self.bytes(entry.delta))")
                                .tonicType(.monoLabel).monospacedDigit()
                                .foregroundStyle(TonicDS.Colors.statusCaution)
                        }
                    }
                }
            }
        }
    }

    /// Read-only explainer for space Finder reports but files don't account
    /// for: APFS snapshots, purgeable space, sparse files. Honest reporting —
    /// no delete actions here until each cause has a safe mechanism.
    private func hiddenSpaceCard(_ report: DiskDiscrepancyReport) -> some View {
        DataCard(lift: false) {
            VStack(alignment: .leading, spacing: TonicDS.Space.sm) {
                MonoLabel("WHERE DID MY SPACE GO?")
                HStack(spacing: TonicDS.Space.xl) {
                    VStack(alignment: .leading, spacing: 2) {
                        MonoLabel("REPORTED USED")
                        Metric(Self.bytes(report.finderUsedSpace), color: TonicDS.Colors.textPrimary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        MonoLabel("ON-DISK FILES")
                        Metric(Self.bytes(report.duUsedSpace), color: TonicDS.Colors.textPrimary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        MonoLabel("UNACCOUNTED")
                        Metric(report.formattedDiscrepancy, color: TonicDS.Colors.statusWarning)
                    }
                }
                if !report.possibleCauses.isEmpty {
                    TonicHairline()
                    ForEach(Array(report.possibleCauses.enumerated()), id: \.offset) { _, cause in
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(cause.name).tonicType(.body)
                                    .foregroundStyle(TonicDS.Colors.textPrimary)
                                Text(cause.description).tonicType(.caption)
                                    .foregroundStyle(TonicDS.Colors.textMuted)
                            }
                            Spacer()
                            Text(cause.formattedSize).tonicType(.monoLabel).monospacedDigit()
                                .foregroundStyle(TonicDS.Colors.textPrimary)
                        }
                    }
                }
            }
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
        .help(item.paths.first ?? item.subtitle)
        .contextMenu {
            if let first = item.paths.first {
                Button("Reveal in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: first)])
                }
                Button("Copy Path\(item.paths.count > 1 ? "s" : "")") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(item.paths.joined(separator: "\n"), forType: .string)
                }
            }
        }
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
                message: "Every clean is staged here first — you can restore items until you empty the batch."
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
                TonicHairline()
                HStack {
                    // Batch state at a glance: total items and how many can still come back.
                    Text("\(batch.entries.count) item\(batch.entries.count == 1 ? "" : "s") · \(batch.recoverableEntries.count) recoverable")
                        .tonicType(.caption).foregroundStyle(TonicDS.Colors.textMuted)
                    Spacer()
                    if batch.hasRecoverable {
                        TextAction("Restore", color: TonicDS.Colors.textPrimary) { restore(batch) }
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
