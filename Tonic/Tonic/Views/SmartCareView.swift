//
//  SmartCareView.swift
//  Tonic
//
//  Smart Care experience inspired by CleanMyMac flow
//

import SwiftUI
import AppKit

struct SmartCareView: View {
    @State private var engine = SmartCareEngine()
    @State private var phase: SmartCarePhase = .idle
    @State private var scanProgress: Double = 0
    @State private var activeHighlight = SmartCareHighlight(
        domain: .cleanup,
        title: "Ready to scan",
        detail: "Press Scan to begin",
        currentItem: nil
    )
    @State private var scanResult: SmartCareResult?
    @State private var selectedItems: Set<UUID> = []
    @State private var reviewDomain: SmartCareDomain?
    @State private var reviewCleanupGroupId: UUID?
    @State private var reviewPerformanceSection: PerformanceManagerSection?
    @State private var runProgress: Double = 0
    @State private var runSummary: SmartCareRunSummary?
    @State private var scanTask: Task<Void, Never>?
    @State private var runTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            SmartCareBackgroundView()

            VStack(spacing: 0) {
                header
                Divider().opacity(0.2)
                content
            }
        }
        .sheet(item: $reviewDomain, onDismiss: {
            reviewCleanupGroupId = nil
            reviewPerformanceSection = nil
        }) { domain in
            if let result = domainResult(for: domain) {
                SmartCareDomainReviewView(
                    domainResult: result,
                    focusGroupId: domain == .cleanup ? reviewCleanupGroupId : nil,
                    focusPerformanceSection: domain == .performance ? reviewPerformanceSection : nil,
                    selectedItems: $selectedItems,
                    onDone: { reviewDomain = nil },
                    onRunItems: { items in
                        startCustomRun(items: items)
                    }
                )
            } else {
                Text("Review data is unavailable.")
                    .padding()
            }
        }
        .onDisappear {
            scanTask?.cancel()
            runTask?.cancel()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            if phase != .idle {
                Button {
                    resetFlow()
                } label: {
                    Label("Start Over", systemImage: "arrow.counterclockwise")
                        .font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundColor(.white.opacity(0.85))
            }

            Spacer()

            Text("Smart Care")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))

            Spacer()

            if let summary = runSummary {
                Text(summary.formattedSummary)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            } else {
                Text(phase.headerStatus)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background(SmartCareTheme.headerBackground)
    }

    // MARK: - Content

    private var content: some View {
        VStack(spacing: 24) {
            switch phase {
            case .idle:
                idleContent
            case .scanning:
                scanningContent
            case .results:
                resultsContent
            case .running:
                runningContent
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var idleContent: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(SmartCareTheme.accentGradient)

                Text("Welcome back!")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(.white)

                Text("Run a quick, intelligent scan to clean up and optimize your Mac.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }

            SmartCarePrimaryButton(title: "Scan", icon: "magnifyingglass") {
                startScanFlow()
            }

            Spacer()
        }
    }

    private var scanningContent: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text(activeHighlight.title)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white)

                Text(activeHighlight.detail)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))

                if let current = activeHighlight.currentItem {
                    Text(current)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.55))
                }
            }
            .multilineTextAlignment(.center)

            ProgressView(value: scanProgress)
                .progressViewStyle(.linear)
                .frame(width: 260)
                .tint(SmartCareTheme.accent)

            SmartCareGridView(
                cards: buildCardData(),
                domains: primaryDomains,
                activeDomain: activeHighlight.domain,
                mode: .scanning,
                highlight: activeHighlight,
                onToggle: { _ in },
                onReview: { _ in }
            )

            SmartCarePrimaryButton(title: "Stop", icon: "stop.fill", isProminent: false) {
                stopScan()
            }
        }
    }

    private var resultsContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                VStack(spacing: 6) {
                    Text("Your tasks are ready to run. Look what we found:")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)

                    Text("Review any category, or run the smartly selected tasks.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.65))
                }
                .multilineTextAlignment(.center)

                if let cleanupResult {
                    CleanupSectionView(
                        result: cleanupResult,
                        onReviewAll: { openCleanupReview(groupId: nil) },
                        onReviewGroup: { group in openCleanupReview(groupId: group.id) },
                        onCleanGroup: { group in startGroupRun(group) }
                    )
                }

                if let performanceResult {
                    PerformanceSectionView(
                        result: performanceResult,
                        onViewAllTasks: { openPerformanceReview(section: .maintenanceTasks) },
                        onReviewMaintenance: { openPerformanceReview(section: .maintenanceTasks) },
                        onRunMaintenance: { startPerformanceMaintenanceRun() },
                        onReviewLoginItems: { openPerformanceReview(section: .loginItems) },
                        onReviewBackgroundItems: { openPerformanceReview(section: .backgroundItems) }
                    )
                }

                SmartCareCompactGridView(
                    cards: buildCardData(),
                    domains: compactDomains,
                    onToggle: toggleDomainSelection,
                    onReview: { domain in
                        reviewCleanupGroupId = nil
                        reviewPerformanceSection = nil
                        reviewDomain = domain
                    }
                )

                SmartCarePrimaryButton(title: runButtonTitle, icon: "play.fill") {
                    startRunFlow()
                }
                .disabled(!hasRunnableSelection)
                .opacity(hasRunnableSelection ? 1 : 0.5)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var runningContent: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text("Running selected tasks...")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)

                Text("We are applying the smartly selected actions.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.65))
            }

            ProgressView(value: runProgress)
                .progressViewStyle(.linear)
                .frame(width: 280)
                .tint(SmartCareTheme.accent)

            SmartCareGridView(
                cards: buildCardData(),
                domains: primaryDomains,
                activeDomain: nil,
                mode: .running,
                highlight: nil,
                onToggle: { _ in },
                onReview: { _ in }
            )

            SmartCarePrimaryButton(title: "Stop", icon: "stop.fill", isProminent: false) {
                stopRun()
            }
        }
    }

    // MARK: - Actions

    private func startScanFlow() {
        scanTask?.cancel()
        runSummary = nil
        scanProgress = 0
        scanResult = nil
        selectedItems.removeAll()
        phase = .scanning

        scanTask = Task {
            let result = await engine.runSmartCareScan { update in
                Task { @MainActor in
                    scanProgress = update.progress
                    activeHighlight = SmartCareHighlight(
                        domain: update.domain,
                        title: update.title,
                        detail: update.detail,
                        currentItem: update.currentItem
                    )
                }
            }

            await MainActor.run {
                scanResult = result
                applyDefaultSelections()
                phase = .results
                scanProgress = 1.0
            }
        }
    }

    private func stopScan() {
        scanTask?.cancel()
        scanProgress = 0
        phase = .idle
    }

    private func startRunFlow() {
        runTask?.cancel()
        runProgress = 0
        runSummary = nil
        phase = .running

        runTask = Task {
            await runSelectedTasks()
            await MainActor.run { phase = .results }
        }
    }

    private func openCleanupReview(groupId: UUID?) {
        reviewCleanupGroupId = groupId
        reviewPerformanceSection = nil
        reviewDomain = .cleanup
    }

    private func openPerformanceReview(section: PerformanceManagerSection) {
        reviewCleanupGroupId = nil
        reviewPerformanceSection = section
        reviewDomain = .performance
    }

    private func startPerformanceMaintenanceRun() {
        guard let performance = performanceResult else { return }
        guard let maintenanceGroup = performance.groups.first(where: { $0.title == PerformanceManagerSection.maintenanceTasks.groupTitle }) else { return }
        startGroupRun(maintenanceGroup)
    }

    private func startGroupRun(_ group: SmartCareGroup) {
        let smartItems = group.items.filter { $0.isSmartSelected && $0.safeToRun && $0.action.isRunnable }
        let fallbackItems = group.items.filter { $0.safeToRun && $0.action.isRunnable }
        let items = smartItems.isEmpty ? fallbackItems : smartItems
        startCustomRun(items: items)
    }

    private func startCustomRun(items: [SmartCareItem]) {
        guard !items.isEmpty else { return }

        runTask?.cancel()
        runProgress = 0
        runSummary = nil
        phase = .running

        runTask = Task {
            await performRun(items: items)
            await MainActor.run { phase = .results }
        }
    }

    private func stopRun() {
        runTask?.cancel()
        phase = .results
    }

    private func resetFlow() {
        scanTask?.cancel()
        runTask?.cancel()
        scanResult = nil
        scanProgress = 0
        runProgress = 0
        runSummary = nil
        selectedItems.removeAll()
        reviewDomain = nil
        reviewCleanupGroupId = nil
        reviewPerformanceSection = nil
        phase = .idle
    }

    // MARK: - Selection

    private func applyDefaultSelections() {
        guard let result = scanResult else { return }
        let smartIds = result.domainResults.values
            .flatMap { $0.items }
            .filter { $0.isSmartSelected }
            .map { $0.id }
        selectedItems = Set(smartIds)
    }

    private func toggleDomainSelection(_ domain: SmartCareDomain) {
        let domainItems = items(for: domain)
        guard !domainItems.isEmpty else { return }

        let selectedInDomain = domainItems.filter { selectedItems.contains($0.id) }
        if selectedInDomain.isEmpty {
            let smartItems = domainItems.filter { $0.isSmartSelected }
            let ids = (smartItems.isEmpty ? domainItems : smartItems).map { $0.id }
            selectedItems.formUnion(ids)
        } else {
            selectedItems.subtract(domainItems.map { $0.id })
        }
    }

    private var hasRunnableSelection: Bool {
        !selectedRunnableItems.isEmpty
    }

    private var selectedRunnableItems: [SmartCareItem] {
        guard let result = scanResult else { return [] }
        return result.domainResults.values
            .flatMap { $0.items }
            .filter { selectedItems.contains($0.id) && $0.safeToRun && $0.action.isRunnable }
    }

    private var runButtonTitle: String {
        let total = selectedRunnableItems.count
        return total > 0 ? "Run \(total) Tasks" : "Run"
    }

    // MARK: - Run Logic

    private func runSelectedTasks() async {
        await performRun(items: selectedRunnableItems)
    }

    private func performRun(items: [SmartCareItem]) async {
        guard !items.isEmpty else { return }

        var bytesFreed: Int64 = 0
        var errors = 0

        for (index, item) in items.enumerated() {
            switch item.action {
            case .delete(let paths):
                let uniquePaths = Array(Set(paths))
                let result = await FileOperations.shared.deleteFiles(atPaths: uniquePaths)
                bytesFreed += result.bytesFreed
                errors += result.errors.count
            case .runOptimization(let action):
                do {
                    let result = try await SystemOptimization.shared.performAction(action)
                    bytesFreed += result.bytesFreed
                } catch {
                    errors += 1
                }
            case .none:
                break
            }

            await MainActor.run {
                runProgress = Double(index + 1) / Double(items.count)
            }
        }

        let scoreGain = items.reduce(0) { $0 + $1.scoreImpact }
        await MainActor.run {
            runSummary = SmartCareRunSummary(
                tasksRun: items.count,
                spaceFreed: bytesFreed,
                errors: errors,
                scoreImprovement: scoreGain
            )
        }
    }

    // MARK: - Data Helpers

    private var primaryDomains: [SmartCareDomain] {
        [.cleanup, .performance, .applications]
    }

    private var compactDomains: [SmartCareDomain] {
        [.applications]
    }

    private var cleanupResult: SmartCareDomainResult? {
        domainResult(for: .cleanup)
    }

    private var performanceResult: SmartCareDomainResult? {
        domainResult(for: .performance)
    }

    private func domainResult(for domain: SmartCareDomain) -> SmartCareDomainResult? {
        scanResult?.domainResults[domain]
    }

    private func items(for domain: SmartCareDomain) -> [SmartCareItem] {
        domainResult(for: domain)?.items ?? []
    }

    private func isDomainSelected(_ domain: SmartCareDomain) -> Bool {
        items(for: domain).contains(where: { selectedItems.contains($0.id) })
    }

    private func buildCardData() -> [SmartCareDomain: SmartCareCardData] {
        SmartCareDomain.allCases.reduce(into: [:]) { result, domain in
            result[domain] = cardData(for: domain)
        }
    }

    private func cardData(for domain: SmartCareDomain) -> SmartCareCardData {
        guard let result = scanResult?.domainResults[domain] else {
            return SmartCareCardData(
                domain: domain,
                title: domain.title,
                primaryValue: "—",
                secondaryValue: "Scanning",
                detail: "",
                scoreImpact: 0,
                isSelected: false,
                reviewAvailable: false
            )
        }

        switch domain {
        case .cleanup:
            let total = result.totalSize
            return SmartCareCardData(
                domain: domain,
                title: domain.title,
                primaryValue: total > 0 ? formatBytes(total) : "No junk",
                secondaryValue: total > 0 ? "to clean" : "found",
                detail: total > 0 ? "\(result.totalUnitCount) items" : "You're all set",
                scoreImpact: result.scoreImpact,
                isSelected: isDomainSelected(domain),
                reviewAvailable: !result.items.isEmpty
            )
        case .performance:
            let count = result.totalUnitCount
            return SmartCareCardData(
                domain: domain,
                title: domain.title,
                primaryValue: "\(count) tasks",
                secondaryValue: "to run",
                detail: "Tune system services",
                scoreImpact: result.scoreImpact,
                isSelected: isDomainSelected(domain),
                reviewAvailable: !result.items.isEmpty
            )
        case .applications:
            let count = result.totalUnitCount
            return SmartCareCardData(
                domain: domain,
                title: domain.title,
                primaryValue: count == 0 ? "No issues" : "\(count) items",
                secondaryValue: "to review",
                detail: count == 0 ? "Apps look good" : "Updates & cleanup",
                scoreImpact: result.scoreImpact,
                isSelected: isDomainSelected(domain),
                reviewAvailable: !result.items.isEmpty
            )
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Supporting Models

enum SmartCarePhase {
    case idle
    case scanning
    case results
    case running

    var headerStatus: String {
        switch self {
        case .idle: return "Ready"
        case .scanning: return "Scanning"
        case .results: return "Results"
        case .running: return "Running"
        }
    }
}

struct SmartCareCardData {
    let domain: SmartCareDomain
    let title: String
    let primaryValue: String
    let secondaryValue: String
    let detail: String
    let scoreImpact: Int
    let isSelected: Bool
    let reviewAvailable: Bool
}

struct SmartCareHighlight {
    let domain: SmartCareDomain
    let title: String
    let detail: String
    let currentItem: String?
}

struct SmartCareRunSummary {
    let tasksRun: Int
    let spaceFreed: Int64
    let errors: Int
    let scoreImprovement: Int

    var formattedSummary: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        let sizeStr = formatter.string(fromByteCount: spaceFreed)
        let errorStr = errors > 0 ? " · \(errors) errors" : ""
        return "Freed \(sizeStr) · Score +\(scoreImprovement)\(errorStr)"
    }
}

// MARK: - Theme

private enum SmartCareTheme {
    static let accent = Color(red: 0.92, green: 0.23, blue: 0.78)
    static let accentSoft = Color(red: 0.78, green: 0.32, blue: 0.88)

    static let backgroundGradient = LinearGradient(
        colors: [
            Color(red: 0.18, green: 0.05, blue: 0.33),
            Color(red: 0.33, green: 0.10, blue: 0.48),
            Color(red: 0.22, green: 0.07, blue: 0.40)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let glowGradient = RadialGradient(
        colors: [Color.white.opacity(0.18), Color.clear],
        center: .topLeading,
        startRadius: 60,
        endRadius: 380
    )

    static let headerBackground = Color.black.opacity(0.25)

    static let accentGradient = LinearGradient(
        colors: [accent, accentSoft],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func cardGradient(for domain: SmartCareDomain) -> LinearGradient {
        switch domain {
        case .cleanup:
            return LinearGradient(
                colors: [Color(red: 0.26, green: 0.74, blue: 0.52), Color(red: 0.14, green: 0.45, blue: 0.34)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .performance:
            return LinearGradient(
                colors: [Color(red: 0.96, green: 0.64, blue: 0.30), Color(red: 0.55, green: 0.22, blue: 0.16)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .applications:
            return LinearGradient(
                colors: [Color(red: 0.36, green: 0.64, blue: 0.95), Color(red: 0.20, green: 0.24, blue: 0.60)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Background

private struct SmartCareBackgroundView: View {
    var body: some View {
        ZStack {
            SmartCareTheme.backgroundGradient
                .ignoresSafeArea()
            SmartCareTheme.glowGradient
                .ignoresSafeArea()
        }
    }
}

// MARK: - Primary Button

private struct SmartCarePrimaryButton: View {
    let title: String
    let icon: String
    var isProminent: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(
                        isProminent
                        ? AnyShapeStyle(SmartCareTheme.accentGradient)
                        : AnyShapeStyle(Color.white.opacity(0.2))
                    )
                    .shadow(color: SmartCareTheme.accent.opacity(isProminent ? 0.45 : 0.2), radius: 12, x: 0, y: 8)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Cleanup Section

private struct CleanupSectionView: View {
    let result: SmartCareDomainResult
    let onReviewAll: () -> Void
    let onReviewGroup: (SmartCareGroup) -> Void
    let onCleanGroup: (SmartCareGroup) -> Void

    private var sortedGroups: [SmartCareGroup] {
        result.groups
            .filter { !$0.items.isEmpty }
            .sorted { groupSize($0) > groupSize($1) }
    }

    private var totalSizeText: String {
        formatBytes(result.totalSize)
    }

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 10) {
                Text(result.totalSize > 0 ? "There are \(totalSizeText) of junk files on your Mac." : "Your Mac looks clean.")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Button("Review All Junk", action: onReviewAll)
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.18))
                    .clipShape(Capsule())
                    .disabled(result.items.isEmpty)
                    .opacity(result.items.isEmpty ? 0.5 : 1)
            }
            .frame(maxWidth: .infinity)

            if sortedGroups.isEmpty {
                Text("No cleanup items found.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.vertical, 24)
            } else {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)],
                    spacing: 16
                ) {
                    ForEach(sortedGroups) { group in
                        CleanupGroupCard(
                            group: group,
                            sizeText: formatBytes(groupSize(group)),
                            iconName: iconName(for: group),
                            onReview: { onReviewGroup(group) },
                            onClean: { onCleanGroup(group) }
                        )
                        .frame(height: cardHeight(for: group))
                    }
                }
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.08, green: 0.38, blue: 0.16), Color(red: 0.05, green: 0.22, blue: 0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private func cardHeight(for group: SmartCareGroup) -> CGFloat {
        let index = sortedGroups.firstIndex(where: { $0.id == group.id }) ?? 0
        return index == 0 ? 210 : 150
    }

    private func groupSize(_ group: SmartCareGroup) -> Int64 {
        group.items.reduce(0) { $0 + $1.size }
    }

    private func iconName(for group: SmartCareGroup) -> String {
        let title = group.title.lowercased()
        if title.contains("xcode") { return "hammer.fill" }
        if title.contains("trash") { return "trash.fill" }
        if title.contains("cache") { return "bolt.circle.fill" }
        if title.contains("log") { return "doc.text.fill" }
        if title.contains("language") { return "globe" }
        if title.contains("binary") { return "square.stack.3d.up.fill" }
        if title.contains("mail") { return "envelope.fill" }
        if title.contains("project") { return "folder.fill" }
        if title.contains("hidden") { return "eye.slash.fill" }
        return "sparkles"
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

private struct CleanupGroupCard: View {
    let group: SmartCareGroup
    let sizeText: String
    let iconName: String
    let onReview: () -> Void
    let onClean: () -> Void

    private var hasRunnableItems: Bool {
        group.items.contains { $0.safeToRun && $0.action.isRunnable }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.16), Color.white.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(group.items.isEmpty ? group.title : "\(sizeText) of \(group.title) Found")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)

                        Text(group.description)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.75))
                            .lineLimit(3)
                    }

                    Spacer()

                    Image(systemName: iconName)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(10)
                        .background(Color.white.opacity(0.18))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Spacer()

                HStack(spacing: 10) {
                    Button("Review", action: onReview)
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.22))
                        .clipShape(Capsule())
                        .disabled(group.items.isEmpty)
                        .opacity(group.items.isEmpty ? 0.5 : 1)

                    if hasRunnableItems {
                        Button("Clean", action: onClean)
                            .buttonStyle(.plain)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(red: 0.05, green: 0.22, blue: 0.10))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Color.white.opacity(0.85))
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(16)
        }
    }
}

private enum PerformanceManagerSection: String, CaseIterable, Identifiable {
    case maintenanceTasks
    case loginItems
    case backgroundItems

    var id: String { rawValue }

    var groupTitle: String {
        switch self {
        case .maintenanceTasks: return "Maintenance Tasks"
        case .loginItems: return "Login Items"
        case .backgroundItems: return "Background Items"
        }
    }

    var sidebarTitle: String {
        groupTitle
    }

    var description: String {
        switch self {
        case .maintenanceTasks:
            return "Essential Mac care includes both general and specific tasks that help you keep your software and hardware in shape. Run your maintenance activities in one place."
        case .loginItems:
            return "Manage the list of applications that get automatically opened every time you log in. Don't make your Mac waste its performance on the processes you don't need."
        case .backgroundItems:
            return "Manage the list of processes and applications that run in the background. You may not need or want part of them."
        }
    }

    var primaryButtonTitle: String {
        switch self {
        case .maintenanceTasks: return "Run"
        case .loginItems, .backgroundItems: return "Remove"
        }
    }

    var emptySelectionText: String {
        switch self {
        case .maintenanceTasks: return "No Tasks Selected"
        case .loginItems, .backgroundItems: return "No Items Selected"
        }
    }
}

private struct PerformanceSectionView: View {
    let result: SmartCareDomainResult
    let onViewAllTasks: () -> Void
    let onReviewMaintenance: () -> Void
    let onRunMaintenance: () -> Void
    let onReviewLoginItems: () -> Void
    let onReviewBackgroundItems: () -> Void

    private var maintenanceGroup: SmartCareGroup {
        group(for: .maintenanceTasks)
    }

    private var loginGroup: SmartCareGroup {
        group(for: .loginItems)
    }

    private var backgroundGroup: SmartCareGroup {
        group(for: .backgroundItems)
    }

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 10) {
                Text("Apply curated recommendations\nor run performance tasks manually.")
                    .font(.system(size: 26, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)

                Button("View All Tasks", action: onViewAllTasks)
                    .buttonStyle(.plain)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 26)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            HStack(alignment: .top, spacing: 16) {
                maintenanceCard
                    .frame(width: 470, height: 450)

                VStack(spacing: 16) {
                    detailCard(
                        title: loginGroup.items.isEmpty ? "No Login Items Found" : "You Have \(loginGroup.items.count) Login Items",
                        subtitle: "Review the list of applications that open automatically when you start up your Mac. You may want to disable some of them.",
                        rightContent: {
                            HStack(spacing: 10) {
                                ForEach(Array(loginGroup.items.prefix(3)), id: \.id) { item in
                                    AppIconView(path: item.paths.first)
                                        .frame(width: 52, height: 52)
                                }
                            }
                        },
                        onReview: onReviewLoginItems,
                        reviewEnabled: !loginGroup.items.isEmpty
                    )

                    detailCard(
                        title: backgroundGroup.items.isEmpty ? "No Background Items Found" : "\(backgroundGroup.items.count) Background Items Found",
                        subtitle: "Review the list of background processes that are allowed to run on your Mac. Do you need all of them?",
                        rightContent: {
                            Image(systemName: "rocket.fill")
                                .font(.system(size: 34, weight: .semibold))
                                .foregroundColor(Color(red: 0.98, green: 0.73, blue: 0.36))
                                .frame(width: 52, height: 52)
                                .background(Color.white.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        },
                        onReview: onReviewBackgroundItems,
                        reviewEnabled: !backgroundGroup.items.isEmpty
                    )
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.36, green: 0.12, blue: 0.06), Color(red: 0.55, green: 0.16, blue: 0.07)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private var maintenanceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(maintenanceGroup.items.isEmpty ? "No Maintenance Tasks Recommended" : "\(maintenanceGroup.items.count) Maintenance Tasks Recommended")
                .font(.system(size: 51, weight: .bold))
                .foregroundColor(.white)

            Text("Your weekly maintenance cocktail is ready to be served! Run these tasks to keep your Mac in shape.")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.86))
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            HStack(spacing: 10) {
                ForEach(Array(maintenanceGroup.items.prefix(3)), id: \.id) { item in
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.16))
                        .frame(width: 86, height: 86)
                        .overlay(
                            Image(systemName: maintenanceIcon(for: item))
                                .font(.system(size: 34, weight: .semibold))
                                .foregroundColor(Color(red: 1.0, green: 0.8, blue: 0.36))
                        )
                }
            }

            Spacer()

            HStack(spacing: 10) {
                sectionActionButton(
                    title: "Review",
                    foreground: .white,
                    background: Color.white.opacity(0.16),
                    enabled: !maintenanceGroup.items.isEmpty,
                    action: onReviewMaintenance
                )
                sectionActionButton(
                    title: "Run Tasks",
                    foreground: Color(red: 0.33, green: 0.11, blue: 0.07),
                    background: Color.white.opacity(0.95),
                    enabled: maintenanceGroup.items.contains(where: { $0.safeToRun && $0.action.isRunnable }),
                    action: onRunMaintenance
                )
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.11))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private func detailCard(
        title: String,
        subtitle: String,
        @ViewBuilder rightContent: () -> some View,
        onReview: @escaping () -> Void,
        reviewEnabled: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.system(size: 33, weight: .bold))
                        .foregroundColor(.white)

                    Text(subtitle)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.86))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)
                rightContent()
            }

            Spacer(minLength: 8)

            HStack {
                Spacer()
                sectionActionButton(
                    title: "Review",
                    foreground: .white,
                    background: Color.white.opacity(0.16),
                    enabled: reviewEnabled,
                    action: onReview
                )
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 214)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.11))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private func sectionActionButton(
        title: String,
        foreground: Color,
        background: Color,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(foreground)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .opacity(enabled ? 1 : 0.45)
            .disabled(!enabled)
    }

    private func maintenanceIcon(for item: SmartCareItem) -> String {
        let title = item.title.lowercased()
        if title.contains("dns") { return "network" }
        if title.contains("purgeable") { return "externaldrive.badge.minus" }
        if title.contains("spotlight") { return "magnifyingglass" }
        if title.contains("permissions") { return "wrench.and.screwdriver" }
        if title.contains("mail") { return "envelope.badge" }
        return "bolt.fill"
    }

    private func group(for section: PerformanceManagerSection) -> SmartCareGroup {
        result.groups.first(where: { $0.title == section.groupTitle }) ??
            SmartCareGroup(domain: .performance, title: section.groupTitle, description: section.description, items: [])
    }
}

private struct AppIconView: View {
    let path: String?

    var body: some View {
        if let path, !path.isEmpty {
            Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.12))
                .overlay(
                    Image(systemName: "app.fill")
                        .foregroundColor(.white.opacity(0.75))
                )
        }
    }
}

// MARK: - Grid View

private struct SmartCareGridView: View {
    let cards: [SmartCareDomain: SmartCareCardData]
    let domains: [SmartCareDomain]
    let activeDomain: SmartCareDomain?
    let mode: SmartCareGridMode
    let highlight: SmartCareHighlight?
    let onToggle: (SmartCareDomain) -> Void
    let onReview: (SmartCareDomain) -> Void

    var body: some View {
        let spacing: CGFloat = 18
        let columns = [
            GridItem(.flexible(), spacing: spacing),
            GridItem(.flexible(), spacing: spacing)
        ]
        let cardHeight: CGFloat = mode == .results ? 175 : 165
        let rows = max(Int(ceil(Double(domains.count) / 2.0)), 1)
        let baseHeight = CGFloat(rows) * cardHeight + CGFloat(max(rows - 1, 0)) * spacing
        let gridHeight = baseHeight + (mode == .scanning ? 30 : 0)

        LazyVGrid(columns: columns, spacing: spacing) {
            ForEach(domains, id: \.self) { domain in
                smartCard(domain, height: cardHeight)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .frame(height: gridHeight)
    }

    @ViewBuilder
    private func smartCard(_ domain: SmartCareDomain, height: CGFloat) -> some View {
        SmartCareCardView(
            domain: domain,
            data: cards[domain],
            isActive: activeDomain == domain,
            mode: mode,
            highlight: highlight,
            onToggle: { onToggle(domain) },
            onReview: { onReview(domain) }
        )
        .frame(height: mode == .scanning && activeDomain == domain ? height + 30 : height)
    }
}

private struct SmartCareCompactGridView: View {
    let cards: [SmartCareDomain: SmartCareCardData]
    let domains: [SmartCareDomain]
    let onToggle: (SmartCareDomain) -> Void
    let onReview: (SmartCareDomain) -> Void

    var body: some View {
        let spacing: CGFloat = 18
        let columns = [
            GridItem(.flexible(), spacing: spacing),
            GridItem(.flexible(), spacing: spacing),
            GridItem(.flexible(), spacing: spacing)
        ]
        let cardHeight: CGFloat = 165
        let rows = max(Int(ceil(Double(domains.count) / 3.0)), 1)
        let baseHeight = CGFloat(rows) * cardHeight + CGFloat(max(rows - 1, 0)) * spacing

        LazyVGrid(columns: columns, spacing: spacing) {
            ForEach(domains, id: \.self) { domain in
                SmartCareCardView(
                    domain: domain,
                    data: cards[domain],
                    isActive: false,
                    mode: .results,
                    highlight: nil,
                    onToggle: { onToggle(domain) },
                    onReview: { onReview(domain) }
                )
                .frame(height: cardHeight)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .frame(height: baseHeight)
    }
}

private enum SmartCareGridMode {
    case scanning
    case results
    case running
}

// MARK: - Card View

private struct SmartCareCardView: View {
    let domain: SmartCareDomain
    let data: SmartCareCardData?
    let isActive: Bool
    let mode: SmartCareGridMode
    let highlight: SmartCareHighlight?
    let onToggle: () -> Void
    let onReview: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 18)
                .fill(SmartCareTheme.cardGradient(for: domain))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(isActive ? 0.7 : 0.15), lineWidth: isActive ? 2 : 1)
                )
                .shadow(color: Color.black.opacity(isActive ? 0.35 : 0.2), radius: isActive ? 16 : 10, x: 0, y: 8)

            Image(systemName: domain.icon)
                .font(.system(size: 64, weight: .bold))
                .foregroundColor(.white.opacity(0.22))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(12)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    if mode == .results, let data = data {
                        Button(action: onToggle) {
                            Image(systemName: data.isSelected ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(.white)
                                .padding(6)
                                .background(Color.white.opacity(0.18))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(domain.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                    }

                    Spacer()
                }

                Spacer()

                if mode == .scanning, isActive, let highlight = highlight {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(highlight.title)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)

                        Text(highlight.detail)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.75))

                        if let currentItem = highlight.currentItem {
                            Text(currentItem)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                } else if let data = data, mode != .scanning {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(data.primaryValue)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)

                        Text(data.secondaryValue)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))

                        Text(data.detail)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.65))
                    }

                    Spacer(minLength: 8)

                    HStack(spacing: 8) {
                        if data.scoreImpact > 0, mode == .results {
                            Text("Score +\(data.scoreImpact)")
                                .font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(6)
                                .foregroundColor(.white)
                        }

                        Spacer()

                        if data.reviewAvailable, mode == .results {
                            Button("Review") { onReview() }
                                .buttonStyle(.plain)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(domain.title)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        Text("Scanning...")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            .padding(16)
        }
        .scaleEffect(isActive && mode == .scanning ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isActive)
    }
}

// MARK: - Review View

private struct SmartCareDomainReviewView: View {
    let domainResult: SmartCareDomainResult
    let focusGroupId: UUID?
    let focusPerformanceSection: PerformanceManagerSection?
    @Binding var selectedItems: Set<UUID>
    let onDone: () -> Void
    let onRunItems: ([SmartCareItem]) -> Void

    var body: some View {
        Group {
            switch domainResult.domain {
            case .cleanup:
                CleanupManagerView(
                    domainResult: domainResult,
                    focusGroupId: focusGroupId,
                    selectedItems: $selectedItems,
                    onDone: onDone,
                    onRunItems: onRunItems
                )
            case .applications:
                ApplicationsManagerView(domainResult: domainResult, selectedItems: $selectedItems, onDone: onDone)
            case .performance:
                PerformanceManagerView(
                    domainResult: domainResult,
                    focusSection: focusPerformanceSection,
                    selectedItems: $selectedItems,
                    onDone: onDone,
                    onRunItems: onRunItems
                )
            }
        }
    }
}

// MARK: - Cleanup Manager

private struct CleanupManagerView: View {
    let domainResult: SmartCareDomainResult
    let focusGroupId: UUID?
    @Binding var selectedItems: Set<UUID>
    let onDone: () -> Void
    let onRunItems: ([SmartCareItem]) -> Void

    @State private var selectedGroupId: UUID
    @State private var selectedItemId: UUID?
    @State private var selectionPreset: SelectionPreset = .smartly
    @State private var sortOption: SortOption = .size
    @State private var searchText: String = ""

    init(
        domainResult: SmartCareDomainResult,
        focusGroupId: UUID?,
        selectedItems: Binding<Set<UUID>>,
        onDone: @escaping () -> Void,
        onRunItems: @escaping ([SmartCareItem]) -> Void
    ) {
        self.domainResult = domainResult
        self.focusGroupId = focusGroupId
        self._selectedItems = selectedItems
        self.onDone = onDone
        self.onRunItems = onRunItems

        let initialGroupId = focusGroupId ?? domainResult.groups.first?.id ?? UUID()
        let initialGroup = domainResult.groups.first(where: { $0.id == initialGroupId }) ?? domainResult.groups.first
        self._selectedGroupId = State(initialValue: initialGroupId)
        self._selectedItemId = State(initialValue: initialGroup?.items.first?.id)
    }

    private var groups: [SmartCareGroup] {
        domainResult.groups.isEmpty ? [SmartCareGroup(domain: .cleanup, title: "System Junk", description: "No items found", items: [])] : domainResult.groups
    }

    private var selectedGroup: SmartCareGroup? {
        groups.first(where: { $0.id == selectedGroupId }) ?? groups.first
    }

    private var filteredItems: [SmartCareItem] {
        guard let group = selectedGroup else { return [] }
        let base = group.items.filter { searchText.isEmpty || $0.title.localizedCaseInsensitiveContains(searchText) }
        switch sortOption {
        case .size: return base.sorted { $0.size > $1.size }
        case .name: return base.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
    }

    private var selectedItem: SmartCareItem? {
        if let id = selectedItemId {
            return filteredItems.first(where: { $0.id == id }) ?? filteredItems.first
        }
        return filteredItems.first
    }

    var body: some View {
        VStack(spacing: 0) {
            reviewHeader(title: "Cleanup Manager", searchText: $searchText, sortOption: $sortOption, onDone: onDone)
            Divider()
            HStack(spacing: 0) {
                groupSidebar
                Divider()
                itemColumn
                Divider()
                detailColumn
            }
            Divider()
            selectionFooter(
                items: domainResult.items,
                selectedItems: $selectedItems,
                onDone: onDone,
                primaryTitle: "Clean Up",
                onPrimary: handleCleanUp
            )
        }
        .frame(width: 980, height: 600)
        .background(Color(nsColor: .windowBackgroundColor))
        .onChange(of: selectedGroupId) { _, _ in
            selectedItemId = selectedGroup?.items.first?.id
        }
    }

    private var groupSidebar: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(groups) { group in
                    Button {
                        selectedGroupId = group.id
                    } label: {
                        HStack {
                            Text(group.title)
                                .font(.system(size: 13, weight: .semibold))
                            Spacer()
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selectedGroupId == group.id ? Color.purple.opacity(0.15) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
        }
        .frame(width: 200)
    }

    private var itemColumn: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(filteredItems) { item in
                    Button {
                        selectedItemId = item.id
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.purple)
                                .font(.system(size: 16))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.primary)
                                Text(item.formattedSize)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(item.formattedSize)
                                .font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.purple.opacity(0.15))
                                .cornerRadius(8)
                                .foregroundColor(.purple)
                        }
                        .padding(10)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }

                if filteredItems.isEmpty {
                    Text("No items found")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 12)
                }
            }
            .padding(12)
        }
        .frame(width: 320)
    }

    private var detailColumn: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let item = selectedItem {
                Text(item.title)
                    .font(.system(size: 16, weight: .semibold))

                Text(item.subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                if selectedGroup?.title == "Trash Bins",
                   item.subtitle.localizedCaseInsensitiveContains("Full Disk Access") {
                    Button("Open Full Disk Access Settings") {
                        openFullDiskAccessSettings()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                }

                HStack(spacing: 8) {
                    Text("Select:")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)

                    Menu(selectionPreset.title) {
                        ForEach(SelectionPreset.allCases, id: \.self) { preset in
                            Button(preset.title) {
                                selectionPreset = preset
                                applySelectionPreset(preset)
                            }
                        }
                    }
                    .menuStyle(.borderlessButton)
                }

                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(item.paths.prefix(20), id: \.self) { path in
                            HStack(spacing: 10) {
                                Button {
                                    toggleItemSelection(item)
                                } label: {
                                    Image(systemName: selectedItems.contains(item.id) ? "checkmark.square.fill" : "square")
                                        .foregroundColor(.purple)
                                }
                                .buttonStyle(.plain)

                                Image(systemName: "folder")
                                    .foregroundColor(.secondary)

                                Text(shortenPath(path))
                                    .font(.system(size: 12))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)

                                Spacer()
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
            } else {
                Text("Select an item to review")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func applySelectionPreset(_ preset: SelectionPreset) {
        let items = selectedGroup?.items ?? []
        switch preset {
        case .smartly:
            let ids = items.filter { $0.isSmartSelected }.map { $0.id }
            selectedItems.subtract(items.map { $0.id })
            selectedItems.formUnion(ids)
        case .all:
            selectedItems.formUnion(items.map { $0.id })
        case .none:
            selectedItems.subtract(items.map { $0.id })
        }
    }

    private func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }

    private func toggleItemSelection(_ item: SmartCareItem) {
        if selectedItems.contains(item.id) {
            selectedItems.remove(item.id)
        } else {
            selectedItems.insert(item.id)
        }
    }

    private func handleCleanUp() {
        let runnableItems = domainResult.items.filter {
            selectedItems.contains($0.id) && $0.safeToRun && $0.action.isRunnable
        }
        guard !runnableItems.isEmpty else { return }
        onRunItems(runnableItems)
        onDone()
    }
}

// MARK: - Applications Manager

private struct ApplicationsManagerView: View {
    let domainResult: SmartCareDomainResult
    @Binding var selectedItems: Set<UUID>
    let onDone: () -> Void

    @State private var selectedItemId: UUID?
    @State private var selectionPreset: SelectionPreset = .all
    @State private var sortOption: AppSortOption = .lastOpened
    @State private var searchText: String = ""

    private var items: [SmartCareItem] {
        let base = domainResult.items.filter { searchText.isEmpty || $0.title.localizedCaseInsensitiveContains(searchText) }
        switch sortOption {
        case .lastOpened:
            return base
        case .name:
            return base.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
    }

    private var selectedItem: SmartCareItem? {
        if let id = selectedItemId {
            return items.first(where: { $0.id == id }) ?? items.first
        }
        return items.first
    }

    var body: some View {
        VStack(spacing: 0) {
            reviewHeader(title: "Applications Manager", searchText: $searchText, sortOption: nil, onDone: onDone, trailing: {
                AnyView(
                    Menu {
                        ForEach(AppSortOption.allCases, id: \.self) { option in
                            Button(option.title) { sortOption = option }
                        }
                    } label: {
                        Label("Sort by: \(sortOption.title)", systemImage: "arrow.up.arrow.down")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .menuStyle(.borderlessButton)
                )
            })
            Divider()
            HStack(spacing: 0) {
                sidebar
                Divider()
                detailColumn
            }
            Divider()
            selectionFooter(items: domainResult.items, selectedItems: $selectedItems, onDone: onDone)
        }
        .frame(width: 980, height: 600)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Vital Updates")
                    .font(.system(size: 15, weight: .semibold))
                Text("We use AI to prioritize updates from thousands of applications. Smart Care picks the most critical updates for you.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    Text("Select:")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Menu(selectionPreset.title) {
                        ForEach(SelectionPreset.allCases, id: \.self) { preset in
                            Button(preset.title) {
                                selectionPreset = preset
                                applySelectionPreset(preset)
                            }
                        }
                    }
                    .menuStyle(.borderlessButton)
                }
            }
            .padding(16)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(items) { item in
                        Button {
                            selectedItemId = item.id
                        } label: {
                            HStack(spacing: 10) {
                                Button {
                                    toggleItemSelection(item)
                                } label: {
                                    Image(systemName: selectedItems.contains(item.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(.purple)
                                }
                                .buttonStyle(.plain)

                                Image(systemName: "app.fill")
                                    .foregroundColor(.purple)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .font(.system(size: 13, weight: .semibold))
                                    Text("Version \(item.subtitle)")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding(10)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 320)
    }

    private var detailColumn: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let item = selectedItem {
                Text(item.title)
                    .font(.system(size: 22, weight: .semibold))

                VStack(alignment: .leading, spacing: 6) {
                    detailRow("Source", value: "Other")
                    detailRow("Version", value: item.subtitle.isEmpty ? "—" : item.subtitle)
                    detailRow("Update Size", value: item.formattedSize)
                }

                Divider()

                Text("What's New:")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)

                Text("Release notes are not available for this update yet.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            } else {
                Text("Select an update to preview")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func applySelectionPreset(_ preset: SelectionPreset) {
        switch preset {
        case .smartly, .all:
            selectedItems.formUnion(domainResult.items.map { $0.id })
        case .none:
            selectedItems.subtract(domainResult.items.map { $0.id })
        }
    }

    private func toggleItemSelection(_ item: SmartCareItem) {
        if selectedItems.contains(item.id) {
            selectedItems.remove(item.id)
        } else {
            selectedItems.insert(item.id)
        }
    }

    private func detailRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium))
        }
    }
}

// MARK: - Performance Manager

private struct PerformanceManagerView: View {
    let domainResult: SmartCareDomainResult
    let focusSection: PerformanceManagerSection?
    @Binding var selectedItems: Set<UUID>
    let onDone: () -> Void
    let onRunItems: ([SmartCareItem]) -> Void

    @State private var selectedSection: PerformanceManagerSection
    @State private var sortOption: PerformanceSortOption = .name
    @State private var selectionPreset: SelectionPreset = .none
    @State private var removedItemIDs: Set<UUID> = []
    @State private var isApplyingPrimaryAction = false
    @State private var actionMessage: String?

    private let accent = Color(red: 0.95, green: 0.20, blue: 0.78)

    init(
        domainResult: SmartCareDomainResult,
        focusSection: PerformanceManagerSection?,
        selectedItems: Binding<Set<UUID>>,
        onDone: @escaping () -> Void,
        onRunItems: @escaping ([SmartCareItem]) -> Void
    ) {
        self.domainResult = domainResult
        self.focusSection = focusSection
        self._selectedItems = selectedItems
        self.onDone = onDone
        self.onRunItems = onRunItems
        self._selectedSection = State(initialValue: focusSection ?? .maintenanceTasks)
    }

    private var activeGroup: SmartCareGroup {
        domainResult.groups.first(where: { $0.title == selectedSection.groupTitle }) ??
            SmartCareGroup(domain: .performance, title: selectedSection.groupTitle, description: selectedSection.description, items: [])
    }

    private var sectionItems: [SmartCareItem] {
        let base = activeGroup.items.filter { !removedItemIDs.contains($0.id) }
        switch sortOption {
        case .name:
            return base.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
    }

    private var selectedSectionItems: [SmartCareItem] {
        sectionItems.filter { selectedItems.contains($0.id) }
    }

    private var selectedRunnableItems: [SmartCareItem] {
        selectedSectionItems.filter { $0.safeToRun && $0.action.isRunnable }
    }

    private var footerTitle: String {
        guard !selectedSectionItems.isEmpty else { return selectedSection.emptySelectionText }
        switch selectedSection {
        case .maintenanceTasks:
            return selectedSectionItems.count == 1 ? "1 Task Selected" : "\(selectedSectionItems.count) Tasks Selected"
        case .loginItems, .backgroundItems:
            return selectedSectionItems.count == 1 ? "1 Item Selected" : "\(selectedSectionItems.count) Items Selected"
        }
    }

    private var primaryActionEnabled: Bool {
        switch selectedSection {
        case .maintenanceTasks:
            return !selectedRunnableItems.isEmpty && !isApplyingPrimaryAction
        case .loginItems, .backgroundItems:
            return !selectedSectionItems.isEmpty && !isApplyingPrimaryAction
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            managerHeader
            Divider()
            HStack(spacing: 0) {
                sidebar
                Divider()
                contentPane
            }
            Divider()
            footer
        }
        .frame(width: 1120, height: 680)
        .background(Color.white)
        .onChange(of: selectedSection) { _, _ in
            selectionPreset = .none
            actionMessage = nil
        }
    }

    private var managerHeader: some View {
        HStack {
            Button {
                onDone()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(accent)
                    Text("Back")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.black)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Performance Manager")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.black)

            Spacer()

            HStack(spacing: 24) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(accent)

                Menu {
                    ForEach(PerformanceSortOption.allCases, id: \.self) { option in
                        Button(option.title) { sortOption = option }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("Sort by:")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.black)
                        Text(sortOption.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(accent)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(accent)
                    }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(PerformanceManagerSection.allCases) { section in
                Button {
                    selectedSection = section
                } label: {
                    HStack {
                        Text(section.sidebarTitle)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black.opacity(0.88))
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(selectedSection == section ? accent.opacity(0.16) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(14)
        .frame(width: 260)
    }

    private var contentPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(selectedSection.groupTitle)
                    .font(.system(size: 46, weight: .bold))
                    .foregroundColor(.black)

                Text(selectedSection.description)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if selectedSection != .maintenanceTasks {
                HStack(spacing: 10) {
                    Text("Select:")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                    Menu(selectionPreset.title) {
                        ForEach(SelectionPreset.allCases, id: \.self) { preset in
                            Button(preset.title) {
                                selectionPreset = preset
                                applySelectionPreset(preset)
                            }
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(accent)
                }
            }

            if let actionMessage, !actionMessage.isEmpty {
                Text(actionMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(sectionItems) { item in
                        PerformanceManagerRow(
                            item: item,
                            section: selectedSection,
                            isSelected: selectedItems.contains(item.id),
                            accent: accent,
                            onToggle: { toggleItemSelection(item) }
                        )
                    }

                    if sectionItems.isEmpty {
                        Text("No items found.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 12)
                    }
                }
                .padding(.bottom, 12)
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var footer: some View {
        ZStack {
            Text(footerTitle)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity, alignment: .center)

            HStack {
                Spacer()
                Button(selectedSection.primaryButtonTitle) {
                    performPrimaryAction()
                }
                .buttonStyle(.plain)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white.opacity(primaryActionEnabled ? 1 : 0.65))
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
                .background(primaryActionEnabled ? accent.opacity(0.92) : accent.opacity(0.28))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .disabled(!primaryActionEnabled)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
    }

    private func toggleItemSelection(_ item: SmartCareItem) {
        if selectedItems.contains(item.id) {
            selectedItems.remove(item.id)
        } else {
            selectedItems.insert(item.id)
        }
    }

    private func applySelectionPreset(_ preset: SelectionPreset) {
        let ids = sectionItems.map { $0.id }
        switch preset {
        case .smartly:
            let smart = sectionItems.filter { $0.isSmartSelected }.map { $0.id }
            selectedItems.subtract(ids)
            selectedItems.formUnion(smart)
        case .all:
            selectedItems.formUnion(ids)
        case .none:
            selectedItems.subtract(ids)
        }
    }

    private func performPrimaryAction() {
        switch selectedSection {
        case .maintenanceTasks:
            guard !selectedRunnableItems.isEmpty else { return }
            onRunItems(selectedRunnableItems)
            onDone()
        case .loginItems, .backgroundItems:
            let selected = selectedSectionItems
            guard !selected.isEmpty else { return }
            isApplyingPrimaryAction = true
            actionMessage = nil

            Task {
                var removedIDs: [UUID] = []
                var failures = 0

                for item in selected {
                    guard let path = item.paths.first, !path.isEmpty else {
                        failures += 1
                        continue
                    }

                    let removed: Bool
                    switch selectedSection {
                    case .loginItems:
                        removed = await removeLoginItem(atPath: path)
                    case .backgroundItems:
                        removed = await removeBackgroundItem(atPath: path)
                    case .maintenanceTasks:
                        removed = false
                    }

                    if removed {
                        removedIDs.append(item.id)
                    } else {
                        failures += 1
                    }
                }

                await MainActor.run {
                    removedItemIDs.formUnion(removedIDs)
                    selectedItems.subtract(selected.map { $0.id })
                    isApplyingPrimaryAction = false
                    actionMessage = failures == 0
                        ? "Removed \(removedIDs.count) item(s)."
                        : "Removed \(removedIDs.count) item(s), \(failures) failed."
                }
            }
        }
    }

    private func removeLoginItem(atPath path: String) async -> Bool {
        do {
            try await LoginItemsManager.shared.removeLoginItem(atPath: path)
            return true
        } catch {
            return false
        }
    }

    private func removeBackgroundItem(atPath path: String) async -> Bool {
        let result = await FileOperations.shared.deleteFiles(atPaths: [path])
        return result.errors.isEmpty
    }
}

private enum PerformanceSortOption: String, CaseIterable {
    case name

    var title: String {
        switch self {
        case .name: return "Name"
        }
    }
}

private struct PerformanceManagerRow: View {
    let item: SmartCareItem
    let section: PerformanceManagerSection
    let isSelected: Bool
    let accent: Color
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(accent, lineWidth: 1.5)
                    .frame(width: 22, height: 22)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(accent)
                            .opacity(isSelected ? 1 : 0)
                    )
            }
            .buttonStyle(.plain)

            rowIcon
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black)
                if !item.subtitle.isEmpty {
                    Text(item.subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            if section == .maintenanceTasks {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .frame(width: 22, height: 22)
                    .overlay(
                        Text("i")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.black.opacity(0.8))
                    )
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var rowIcon: some View {
        switch section {
        case .maintenanceTasks:
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 1.0, green: 0.69, blue: 0.21), Color(red: 0.93, green: 0.33, blue: 0.20)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Image(systemName: maintenanceIcon)
                        .foregroundColor(.white)
                )
        case .loginItems:
            if let path = item.paths.first {
                Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .overlay(Image(systemName: "app.fill").foregroundColor(.secondary))
            }
        case .backgroundItems:
            if let path = item.paths.first {
                Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.12))
                    .overlay(
                        Image(systemName: "doc.text.fill")
                            .foregroundColor(.gray)
                    )
            }
        }
    }

    private var maintenanceIcon: String {
        let title = item.title.lowercased()
        if title.contains("dns") { return "network" }
        if title.contains("purgeable") { return "externaldrive.badge.minus" }
        if title.contains("spotlight") { return "magnifyingglass" }
        if title.contains("permissions") { return "wrench.and.screwdriver" }
        if title.contains("mail") { return "envelope.badge" }
        return "bolt.fill"
    }
}

// MARK: - Review Helpers

private func reviewHeader(
    title: String,
    searchText: Binding<String>,
    sortOption: Binding<SortOption>?,
    onDone: @escaping () -> Void,
    showsSearch: Bool = true,
    trailing: (() -> AnyView)? = nil
) -> some View {
    HStack {
        Button { onDone() } label: {
            Label("Back", systemImage: "chevron.left")
        }
        .buttonStyle(.plain)

        Spacer()

        Text(title)
            .font(.system(size: 15, weight: .semibold))

        Spacer()

        HStack(spacing: 12) {
            if showsSearch {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search", text: searchText)
                    .textFieldStyle(.plain)
                    .frame(width: 160)
            }

            if let sortOption {
                Menu {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Button(option.title) { sortOption.wrappedValue = option }
                    }
                } label: {
                    Label("Sort by: \(sortOption.wrappedValue.title)", systemImage: "arrow.up.arrow.down")
                        .font(.system(size: 12, weight: .medium))
                }
                .menuStyle(.borderlessButton)
            }

            if let trailing {
                trailing()
            }
        }
    }
    .padding(16)
    .background(Color(nsColor: .controlBackgroundColor))
}

private func selectionFooter(
    items: [SmartCareItem],
    selectedItems: Binding<Set<UUID>>,
    onDone: @escaping () -> Void,
    primaryTitle: String = "Done",
    onPrimary: (() -> Void)? = nil
) -> some View {
    let selected = items.filter { selectedItems.wrappedValue.contains($0.id) }
    let totalSize = selected.reduce(0) { $0 + $1.size }
    let formattedSize = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    let title = selected.isEmpty ? "No Items Selected" : "\(selected.count) Items Selected"
    let primaryAction = onPrimary ?? onDone

    return HStack {
        Text("\(title) | \(formattedSize)")
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.secondary)

        Spacer()

        Button(primaryTitle) { primaryAction() }
            .buttonStyle(.borderedProminent)
            .disabled(selected.isEmpty && onPrimary != nil)
    }
    .padding(12)
    .background(Color(nsColor: .controlBackgroundColor))
}

private func shortenPath(_ path: String) -> String {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    if path.hasPrefix(home) {
        return "~" + path.dropFirst(home.count)
    }
    return path
}

private enum SelectionPreset: String, CaseIterable {
    case smartly
    case all
    case none

    var title: String {
        switch self {
        case .smartly: return "Smartly"
        case .all: return "All"
        case .none: return "None"
        }
    }
}

private enum SortOption: String, CaseIterable {
    case size
    case name

    var title: String {
        switch self {
        case .size: return "Size"
        case .name: return "Name"
        }
    }
}

private enum AppSortOption: String, CaseIterable {
    case lastOpened
    case name

    var title: String {
        switch self {
        case .lastOpened: return "Last Opened"
        case .name: return "Name"
        }
    }
}

private struct SmartCareItemRow: View {
    let item: SmartCareItem
    let isSelected: Bool
    let onToggle: () -> Void
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? SmartCareTheme.accent : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)

                Text(item.subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(item.formattedSize)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: isSelected ? .selectedContentBackgroundColor : .controlBackgroundColor))
        )
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
    }
}

// MARK: - Preview

#Preview {
    SmartCareView()
        .frame(width: 900, height: 700)
}
