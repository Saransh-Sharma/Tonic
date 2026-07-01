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

    private var openRecommendations: [Recommendation] {
        scanManager.recommendations.filter { !$0.isCompleted }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: TonicDS.Space.section) {
                hero
                identity
                needsAttention
                liveBento
            }
            .frame(maxWidth: TonicDS.Layout.maxContentWidth)
            .frame(maxWidth: .infinity, alignment: .center)
            .tonicScreenHPadding()
            .padding(.top, TonicDS.Space.xxxl)
            .padding(.bottom, TonicDS.Space.section)
            .tonicAppear(appeared, reduceMotion: reduceMotion)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TonicDS.Colors.canvas)
        .onAppear {
            if !data.isMonitoring { data.startMonitoring() }
            appeared = true
            loadSnapshot()
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.lg) {
            VStack(alignment: .leading, spacing: TonicDS.Space.sm) {
                Text(heroTitle)
                    .tonicType(.heroDisplay)
                    .foregroundStyle(TonicDS.Colors.textPrimary)
                    // Numeric roll only when the headline is a measured value; plain
                    // phrase changes ("All clear." ↔ "Ready when you are") just cross-fade.
                    .contentTransition(hasRecoverable ? .numericText() : .opacity)
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
        }
    }

    private var hasRecoverable: Bool {
        scanManager.hasScanResult && (scanManager.lastReclaimableBytes ?? 0) > 0
    }

    private var lastScannedText: String? {
        guard !scanManager.isScanning, scanManager.hasScanResult, let date = scanManager.lastScanDate else { return nil }
        let fmt = RelativeDateTimeFormatter()
        fmt.unitsStyle = .full
        return "Last scanned · \(fmt.localizedString(for: date, relativeTo: Date()))"
    }

    private var heroTitle: String {
        if scanManager.isScanning { return "Scanning…" }
        guard scanManager.hasScanResult else { return "Ready when you are" }
        let bytes = scanManager.lastReclaimableBytes ?? 0
        if bytes > 0 { return "\(Self.formatBytes(bytes)) to recover" }
        return "All clear."
    }

    private var heroSubtitle: String {
        if scanManager.isScanning {
            return "\(scanManager.currentPhase.rawValue) · \(Int(scanManager.scanProgress * 100))%"
        }
        guard scanManager.hasScanResult else {
            return "Run a Smart Scan to check space, performance, and apps."
        }
        let n = openRecommendations.count
        if n > 0 { return "\(n) recommendation\(n == 1 ? "" : "s") from your last scan." }
        return "Nothing to recover right now — your Mac is in good shape."
    }

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
            Image(systemName: "checkmark.seal")
                .font(.system(size: 18, weight: .thin))
                .foregroundStyle(TonicDS.Colors.statusSuccess)
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
                    StatusChip(rec.category.rawValue, color: triageColor(rec.priority))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(TonicDS.Colors.textMuted)
                }
            },
            onTap: { route(for: rec) }
        )
    }

    private func triageColor(_ priority: Recommendation.Priority) -> Color {
        switch priority {
        case .critical: return TonicDS.Colors.statusCritical
        case .high: return TonicDS.Colors.statusCaution
        case .medium: return TonicDS.Colors.statusWarning
        case .low: return TonicDS.Colors.statusInfo
        }
    }

    private func route(for rec: Recommendation) {
        selectedDestination = rec.category == .apps ? .appManager : .systemCleanup
    }

    // MARK: - Live bento

    private var liveBento: some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.md) {
            MonoLabel("Live")
            TonicBentoGrid(minTileWidth: 220) {
                GaugeCard(
                    label: "CPU",
                    fraction: cpuFraction,
                    displayValue: "",
                    metricMode: .percent,
                    history: data.cpuHistory,
                    onTap: { selectedDestination = .liveMonitoring }
                )
                GaugeCard(
                    label: "Memory",
                    fraction: memFraction,
                    displayValue: "",
                    metricMode: .percent,
                    history: data.memoryHistory,
                    onTap: { selectedDestination = .liveMonitoring }
                )
                GaugeCard(
                    label: "Disk used",
                    fraction: diskFraction,
                    displayValue: "",
                    metricMode: .percent,
                    supportingText: "\(diskFreeString) free",
                    history: data.diskHistory,
                    onTap: { selectedDestination = .liveMonitoring }
                )
            }
        }
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
