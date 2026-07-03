//
//  HomeView.swift
//  Tonic
//
//  Editorial Home: one calm status declaration, the system-identity strip, a short
//  "needs attention" triage list, and a compact live bento (CPU / MEM / DISK).
//  The home surface is a decision surface — not a dashboard of everything.
//

import SwiftUI

struct HomeView: View {
    @ObservedObject var scanManager: SmartScanManager
    @Binding var selectedDestination: NavigationDestination

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var data = WidgetDataManager.shared
    @State private var snapshot: SystemSnapshot?
    @State private var appeared = false
    @State private var liveSkeletonTimedOut = false
    @State private var toast: ToastData?
    @State private var quickActionRunning: String?
    @State private var missingPermissions: [TonicPermission] = []
    @State private var permissionBannerDismissed = false

    private var openRecommendations: [Recommendation] {
        scanManager.recommendations.filter { !$0.isCompleted }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: TonicDS.Space.section) {
                if !permissionBannerDismissed, !missingPermissions.isEmpty {
                    permissionsBanner
                }
                hero
                    .tonicAppear(appeared, index: 0, reduceMotion: reduceMotion)
                identity
                    .tonicAppear(appeared, index: 1, reduceMotion: reduceMotion)
                quickActions
                    .tonicAppear(appeared, index: 2, reduceMotion: reduceMotion)
                needsAttention
                    .tonicAppear(appeared, index: 3, reduceMotion: reduceMotion)
                HomeInsightsBand()
                    .tonicAppear(appeared, index: 4, reduceMotion: reduceMotion)
                liveBento
            }
            .frame(maxWidth: TonicDS.Layout.maxContentWidth)
            .frame(maxWidth: .infinity, alignment: .center)
            .tonicScreenHPadding()
            .padding(.top, TonicDS.Space.xxxl)
            .padding(.bottom, TonicDS.Space.section)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TonicDS.Colors.canvas)
        .tonicToast($toast)
        .onAppear {
            if !data.isMonitoring { data.startMonitoring() }
            appeared = true
            loadSnapshot()
            refreshPermissionHealth()
        }
    }

    // MARK: - Permission health

    private func refreshPermissionHealth() {
        Task {
            await PermissionManager.shared.checkAllPermissions()
            let statuses = PermissionManager.shared.permissionStatuses
            // Notifications stay optional until the user opts into alerts;
            // Full Disk Access and Accessibility gate core features.
            missingPermissions = [.fullDiskAccess, .accessibility].filter {
                statuses[$0] == .denied || statuses[$0] == .notDetermined
            }
        }
    }

    private var permissionsBanner: some View {
        AlertBanner(
            message: "\(missingPermissions.map(\.rawValue).joined(separator: " and ")) not granted — scans see less than they could.",
            actionTitle: "Fix",
            onAction: {
                selectedDestination = .settings
                NotificationCenter.default.post(
                    name: .openSettingsSection,
                    object: nil,
                    userInfo: [SettingsDeepLinkUserInfoKey.section: SettingsSection.permissions.rawValue]
                )
            },
            onDismiss: { permissionBannerDismissed = true }
        )
    }

    // MARK: - Quick actions

    /// One quiet utility row. Text actions only — Home's single pill belongs
    /// to Smart Scan. Every outcome lands as a toast with honest numbers.
    private var quickActions: some View {
        HStack(spacing: TonicDS.Space.lg) {
            MonoLabel("QUICK")
            quickAction("Empty Trash", id: "trash") {
                let result = await FileOperations.shared.emptyTrash()
                return result.filesProcessed == 0
                    ? "Trash was already empty."
                    : "Emptied Trash · \(Self.formatBytes(result.bytesFreed)) freed."
            }
            if !BuildCapabilities.current.requiresScopeAccess {
                quickAction("Free Purgeable Space", id: "purge") {
                    _ = try await SystemOptimization.shared.performAction(.freePurgeableSpace)
                    return "Asked macOS to reclaim purgeable space."
                }
            }
            quickAction("Flush DNS", id: "dns") {
                _ = try await SystemOptimization.shared.performAction(.flushDNS)
                return "DNS cache flushed."
            }
            if let forecast = DiskUsageHistoryStore.shared.forecast() {
                Spacer()
                MonoLabel("DISK FULL IN ~\(forecast.weeksUntilFull) WK AT CURRENT RATE")
                    .foregroundStyle(TonicDS.Colors.statusWarning)
            }
        }
    }

    private func quickAction(
        _ title: String,
        id: String,
        perform: @escaping () async throws -> String
    ) -> some View {
        HStack(spacing: TonicDS.Space.xs) {
            if quickActionRunning == id {
                ProgressView().controlSize(.mini)
            }
            TextAction(title, color: TonicDS.Colors.linkBlue) {
                guard quickActionRunning == nil else { return }
                quickActionRunning = id
                Task {
                    defer { quickActionRunning = nil }
                    do {
                        let message = try await perform()
                        toast = ToastData(message: message)
                        ActivityLogStore.shared.record(ActivityEvent(
                            category: .optimize,
                            title: title,
                            detail: message,
                            impact: .low
                        ))
                    } catch {
                        toast = ToastData(message: "\(title) failed: \(error.localizedDescription)")
                    }
                }
            }
            .disabled(quickActionRunning != nil)
        }
    }

    // MARK: - Hero

    // Per spec §Layout the dashboard is hero → identity → bento on canvas; the hero
    // carries the single primary action (no module band on the dashboard).
    private var hero: some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.lg) {
            VStack(alignment: .leading, spacing: TonicDS.Space.sm) {
                Text(heroTitle)
                    .tonicType(.heroDisplay)
                    .foregroundStyle(TonicDS.Colors.textPrimary)
                    // Numeric roll only when the headline is a measured value; plain
                    // phrase changes ("All clear." ↔ "Running hot") just cross-fade.
                    .contentTransition(heroState.isMeasured ? .numericText() : .opacity)
                    .animation(reduceMotion ? nil : TonicDS.Motion.present, value: heroTitle)
                    .fixedSize(horizontal: false, vertical: true)
                Text(heroSubtitle)
                    .tonicType(.bodyLarge)
                    .foregroundStyle(TonicDS.Colors.textMuted)
                if let scanned = lastScannedText {
                    MonoLabel(scanned)
                }
            }

            heroActions

            if scanManager.isScanning {
                TonicProgressBar(fraction: scanManager.scanProgress, color: TonicDS.Colors.ink)
                    .frame(maxWidth: 320)
            }
        }
    }

    @ViewBuilder
    private var heroActions: some View {
        HStack(spacing: TonicDS.Space.md) {
            if scanManager.isScanning {
                PrimaryPill("Stop", systemImage: "stop.fill") { scanManager.stopSmartScan() }
            } else if hasRecoverable {
                // Decision surface: lead with recovery, scan becomes the companion.
                PrimaryPill("Review \(Self.formatBytes(scanManager.lastReclaimableBytes ?? 0))",
                            systemImage: "arrow.up.bin") {
                    selectedDestination = .systemCleanup
                }
                TextAction("Rescan") { scanManager.startSmartScan() }
            } else {
                PrimaryPill("Run Smart Scan", systemImage: "sparkles") { scanManager.startSmartScan() }
                TextAction("What gets scanned?") { selectedDestination = .systemCleanup }
            }

            // Live-health declarations point at the instrument, not the cleaner.
            if heroState.leadsToMonitor && !scanManager.isScanning {
                TextAction("Open Monitor", color: TonicDS.Colors.linkBlue) {
                    selectedDestination = .liveMonitoring
                }
            }
        }
    }

    private var hasRecoverable: Bool {
        scanManager.hasScanResult && (scanManager.lastReclaimableBytes ?? 0) > 0
    }

    private var lastScannedText: String? {
        // The timestamp stays visible during a scan — the last known state doesn't
        // vanish just because a new reading is in progress.
        guard scanManager.hasScanResult, let date = scanManager.lastScanDate else { return nil }
        let fmt = RelativeDateTimeFormatter()
        fmt.unitsStyle = .full
        return "Last scanned · \(fmt.localizedString(for: date, relativeTo: Date()))"
    }

    /// The arbitrated declaration: live machine health outranks scan bookkeeping.
    private var heroState: SystemStatusArbiter.Declaration {
        SystemStatusArbiter.declare(
            .init(
                isScanning: scanManager.isScanning,
                scanPhase: scanManager.currentPhase.rawValue,
                scanProgress: scanManager.scanProgress,
                hasScanResult: scanManager.hasScanResult,
                reclaimableBytes: scanManager.lastReclaimableBytes ?? 0,
                recommendationCount: openRecommendations.count,
                memoryPressureCritical: data.hasLiveMetricSample && data.memoryData.pressure == .critical,
                diskFreeFraction: bootVolume.map { 1 - $0.usagePercentage / 100 },
                thermalThrottled: data.hasLiveMetricSample && data.cpuData.thermalLimit == true
            ),
            formatBytes: Self.formatBytes
        )
    }

    private var heroTitle: String { heroState.title }
    private var heroSubtitle: String { heroState.subtitle }

    // MARK: - Identity

    @ViewBuilder
    private var identity: some View {
        if let snapshot {
            SystemIdentityStrip(segments: [
                snapshot.deviceDisplayName,
                snapshot.processorSummary.components(separatedBy: " • ").first ?? snapshot.processorSummary,
                snapshot.memorySummary,
                snapshot.osString
            ])
        }
    }

    // MARK: - Needs attention

    private var needsAttention: some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.md) {
            MonoLabel("Needs attention\(openRecommendations.isEmpty ? "" : " · \(openRecommendations.count)")")

            if openRecommendations.isEmpty {
                emptyTriage
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(openRecommendations.prefix(4))) { rec in
                        triageRow(rec)
                        if rec.id != openRecommendations.prefix(4).last?.id { TonicHairline() }
                    }
                }
                .background(TonicDS.Colors.surface,
                            in: RoundedRectangle(cornerRadius: TonicDS.Radius.card, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: TonicDS.Radius.card, style: .continuous)
                        .strokeBorder(TonicDS.Colors.cardBorder, lineWidth: 1)
                )
            }
        }
    }

    private var emptyTriage: some View {
        HStack(spacing: TonicDS.Space.sm) {
            // Neutral glyph — status green stays on data readouts, never on chrome.
            Image(systemName: "checkmark.seal")
                .font(.system(size: 18, weight: .thin))
                .foregroundStyle(TonicDS.Colors.textMuted)
            Text("All clear — nothing needs your attention.")
                .tonicType(.body)
                .foregroundStyle(TonicDS.Colors.textMuted)
            Spacer()
        }
        .padding(TonicDS.Space.lg)
        .background(TonicDS.Colors.softStone,
                    in: RoundedRectangle(cornerRadius: TonicDS.Radius.sm, style: .continuous))
    }

    private func triageRow(_ rec: Recommendation) -> some View {
        SystemListRow(
            leading: {
                Image(systemName: rec.type.icon)
                    .font(.system(size: 14, weight: .regular))
                    .frame(width: 20)
                    .foregroundStyle(TonicDS.Colors.textMuted)
            },
            center: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(rec.title).tonicType(.body).foregroundStyle(TonicDS.Colors.textPrimary)
                        .lineLimit(1)
                    Text(rec.description).tonicType(.caption).foregroundStyle(TonicDS.Colors.textMuted)
                        .lineLimit(1)
                }
            },
            trailing: {
                HStack(spacing: TonicDS.Space.sm) {
                    // The chip states the *priority* — its color and its word agree.
                    // Category is already carried by the leading glyph and title.
                    StatusChip(triagePriorityWord(rec.priority),
                               level: triageLevel(rec.priority))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(TonicDS.Colors.textMuted)
                }
            },
            onTap: { route(for: rec) }
        )
    }

    private func triageLevel(_ priority: Recommendation.Priority) -> TonicDS.StatusLevel {
        switch priority {
        case .critical: return .critical
        case .high: return .caution
        case .medium: return .warning
        case .low: return .info
        }
    }

    private func triagePriorityWord(_ priority: Recommendation.Priority) -> String {
        switch priority {
        case .critical: return "Critical"
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }

    private func route(for rec: Recommendation) {
        // Land on the screen that can actually act on the recommendation.
        switch rec.type {
        case .update:
            selectedDestination = .appManager
        case .security:
            selectedDestination = .settings
            NotificationCenter.default.post(
                name: .openSettingsSection,
                object: nil,
                userInfo: [SettingsDeepLinkUserInfoKey.section: SettingsSection.permissions.rawValue]
            )
        case .clean, .optimize:
            selectedDestination = rec.category == .apps ? .appManager : .systemCleanup
        }
    }

    // MARK: - Live bento

    private var hasLiveHistory: Bool {
        !(data.cpuHistory.isEmpty && data.memoryHistory.isEmpty && data.diskHistory.isEmpty)
    }

    private var liveBento: some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.md) {
            MonoLabel("Live")
                .tonicAppear(appeared, index: 3, reduceMotion: reduceMotion)

            if !hasLiveHistory {
                if liveSkeletonTimedOut {
                    liveUnavailableNotice
                        .tonicAppear(appeared, index: 4, reduceMotion: reduceMotion)
                } else {
                    liveSkeleton
                        .tonicAppear(appeared, index: 4, reduceMotion: reduceMotion)
                        .task {
                            try? await Task.sleep(nanoseconds: 3_000_000_000)
                            if !Task.isCancelled && !hasLiveHistory { liveSkeletonTimedOut = true }
                        }
                }
            } else {
                TonicBentoGrid(minTileWidth: 220) {
                    GaugeCard(
                        label: "CPU", fraction: cpuFraction, displayValue: "",
                        metricMode: .percent, history: data.cpuHistory,
                        onTap: { selectedDestination = .liveMonitoring }
                    )
                    .tonicAppear(appeared, index: 4, reduceMotion: reduceMotion)
                    GaugeCard(
                        label: "Memory", fraction: memFraction, displayValue: "",
                        metricMode: .percent, history: data.memoryHistory,
                        onTap: { selectedDestination = .liveMonitoring }
                    )
                    .tonicAppear(appeared, index: 5, reduceMotion: reduceMotion)
                    GaugeCard(
                        label: "Disk used", fraction: diskFraction, displayValue: "",
                        metricMode: .percent, supportingText: "\(diskFreeString) free",
                        history: data.diskHistory,
                        onTap: { selectedDestination = .liveMonitoring }
                    )
                    .tonicAppear(appeared, index: 6, reduceMotion: reduceMotion)
                }

                // The signature console surface, teased on Home: a wide near-black
                // strip of live mono readouts that opens the instrument wall.
                consoleTeaser
                    .tonicAppear(appeared, index: 7, reduceMotion: reduceMotion)
            }
        }
    }

    private var consoleTeaser: some View {
        MonitoringConsole {
            HStack(spacing: TonicDS.Space.lg) {
                teaserReadout("CPU", "\(Int(data.cpuData.totalUsage))%",
                              TonicDS.Chart.utilization(data.cpuData.totalUsage))
                teaserReadout("MEM", "\(Int(data.memoryData.usagePercentage))%",
                              TonicDS.Chart.utilization(data.memoryData.usagePercentage))
                teaserReadout("NET ↓", data.networkData.downloadString, TonicDS.Chart.download)
                Spacer(minLength: TonicDS.Space.md)
                TextAction("Open Monitor", systemImage: "arrow.up.right",
                           color: TonicDS.Colors.onDarkMuted) {
                    selectedDestination = .liveMonitoring
                }
            }
        }
    }

    private func teaserReadout(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: TonicDS.Space.xs) {
            MonoLabel(label, color: TonicDS.Colors.onDarkMuted)
            Text(value)
                .tonicType(.monoLabel).monospacedDigit()
                .foregroundStyle(color)
                .contentTransition(.numericText())
        }
        .accessibilityElement(children: .combine)
    }

    private var liveUnavailableNotice: some View {
        DataCard {
            VStack(alignment: .leading, spacing: TonicDS.Space.xs) {
                MonoLabel("Live metrics unavailable")
                Text("No samples have arrived yet. Monitoring starts automatically — if this persists, check module settings.")
                    .tonicType(.caption)
                    .foregroundStyle(TonicDS.Colors.textMuted)
            }
        }
    }

    private var liveSkeleton: some View {
        TonicBentoGrid(minTileWidth: 220) {
            ForEach(["CPU", "Memory", "Disk used"], id: \.self) { label in
                DataCard {
                    VStack(alignment: .leading, spacing: TonicDS.Space.md) {
                        MonoLabel(label)
                        RoundedRectangle(cornerRadius: TonicDS.Radius.xs, style: .continuous)
                            .fill(TonicDS.Colors.hairline).frame(width: 88, height: 28).skeleton()
                        RoundedRectangle(cornerRadius: TonicDS.Radius.xs, style: .continuous)
                            .fill(TonicDS.Colors.hairline).frame(height: 40).skeleton()
                    }
                }
            }
        }
        .accessibilityLabel("Loading live metrics")
    }

    private var cpuFraction: Double { min(1, max(0, data.cpuData.totalUsage / 100)) }
    private var memFraction: Double { min(1, max(0, data.memoryData.usagePercentage / 100)) }
    private var bootVolume: DiskVolumeData? {
        data.diskVolumes.first(where: { $0.isBootVolume }) ?? data.diskVolumes.first
    }
    private var diskFraction: Double { min(1, max(0, (bootVolume?.usagePercentage ?? 0) / 100)) }
    private var diskFreeString: String {
        guard let v = bootVolume else { return "—" }
        return ByteCountFormatter.string(fromByteCount: Int64(v.freeBytes), countStyle: .file)
    }

    // MARK: - Helpers

    private func loadSnapshot() {
        Task.detached(priority: .utility) {
            let snap = try? SystemSnapshotProvider.fetch()
            await MainActor.run { self.snapshot = snap }
        }
    }

    private static func formatBytes(_ bytes: Int64) -> String {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useGB, .useMB]
        f.countStyle = .file
        return f.string(fromByteCount: bytes)
    }
}

// MARK: - Status arbitration

/// Resolves the one hero declaration from everything the app knows: live machine
/// health outranks scan results, which outrank the invitation to scan. Pure and
/// value-typed so the priority ladder is unit-testable.
enum SystemStatusArbiter {
    struct Inputs {
        var isScanning: Bool
        var scanPhase: String
        var scanProgress: Double
        var hasScanResult: Bool
        var reclaimableBytes: Int64
        var recommendationCount: Int
        var memoryPressureCritical: Bool
        /// 0...1 free fraction of the boot volume; nil when unknown.
        var diskFreeFraction: Double?
        var thermalThrottled: Bool
    }

    struct Declaration: Equatable {
        let title: String
        let subtitle: String
        /// Measured values roll numerically; phrases cross-fade.
        let isMeasured: Bool
        /// Live-health declarations offer Monitor as the companion destination.
        let leadsToMonitor: Bool
    }

    static func declare(_ inputs: Inputs, formatBytes: (Int64) -> String) -> Declaration {
        if inputs.isScanning {
            return Declaration(
                title: "Scanning…",
                subtitle: "\(inputs.scanPhase) · \(Int(inputs.scanProgress * 100))%",
                isMeasured: true, leadsToMonitor: false
            )
        }

        // Live health first — the machine's present state outranks scan bookkeeping.
        if inputs.thermalThrottled {
            return Declaration(
                title: "Running hot",
                subtitle: "The CPU is being thermally throttled. Check what's working so hard.",
                isMeasured: false, leadsToMonitor: true
            )
        }
        if inputs.memoryPressureCritical {
            return Declaration(
                title: "Memory under pressure",
                subtitle: "macOS is compressing and swapping aggressively. Closing something helps.",
                isMeasured: false, leadsToMonitor: true
            )
        }
        if let free = inputs.diskFreeFraction, free < 0.05 {
            return Declaration(
                title: "Disk almost full",
                subtitle: "Under 5% free on the boot volume. A Smart Scan can recover space.",
                isMeasured: false, leadsToMonitor: false
            )
        }

        if inputs.hasScanResult, inputs.reclaimableBytes > 0 {
            let n = inputs.recommendationCount
            return Declaration(
                title: "\(formatBytes(inputs.reclaimableBytes)) to recover",
                subtitle: n > 0
                    ? "\(n) recommendation\(n == 1 ? "" : "s") from your last scan."
                    : "Recoverable space found in your last scan.",
                isMeasured: true, leadsToMonitor: false
            )
        }

        guard inputs.hasScanResult else {
            return Declaration(
                title: "Ready when you are",
                subtitle: "Run a Smart Scan to check space, performance, and apps.",
                isMeasured: false, leadsToMonitor: false
            )
        }

        return Declaration(
            title: "All clear.",
            subtitle: "Nothing to recover right now — your Mac is in good shape.",
            isMeasured: false, leadsToMonitor: false
        )
    }
}
