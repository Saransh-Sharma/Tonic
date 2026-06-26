//
//  DashboardSupport.swift
//  Tonic
//
//  Shared dashboard support types: Recommendation model, SmartScanManager, and
//  list-row components used by DashboardHomeView. (The legacy DashboardView
//  screen was removed; these supporting types remain in use.)
//

import SwiftUI
import IOKit.ps

// MARK: - Recommendation Model

struct Recommendation: Identifiable, Equatable {
    let id: UUID
    let title: String
    let description: String
    let type: RecommendationType
    let category: RecommendationCategory
    let priority: Priority
    let actionText: String
    let scanRecommendation: ScanRecommendation
    let scoreImpact: Int
    var isCompleted: Bool = false

    init(
        scanRecommendation: ScanRecommendation,
        type: RecommendationType,
        category: RecommendationCategory,
        priority: Priority,
        actionText: String
    ) {
        id = scanRecommendation.id
        title = scanRecommendation.title
        description = scanRecommendation.description
        self.type = type
        self.category = category
        self.priority = priority
        self.actionText = actionText
        self.scanRecommendation = scanRecommendation
        scoreImpact = scanRecommendation.scoreImpact
    }

    /// Category for grouping recommendations
    enum RecommendationCategory: String, CaseIterable {
        case cache = "Cache"
        case logs = "Logs"
        case system = "System"
        case apps = "Apps"
        case other = "Other"
    }

    enum RecommendationType {
        case clean
        case optimize
        case update
        case security

        var icon: String {
            switch self {
            case .clean: return "trash.fill"
            case .optimize: return "speedometer"
            case .update: return "arrow.up.circle.fill"
            case .security: return "checkmark.shield.fill"
            }
        }

        var color: Color {
            switch self {
            case .clean: return DesignTokens.Colors.accent
            case .optimize: return DesignTokens.Colors.info
            case .update: return DesignTokens.Colors.success
            case .security: return DesignTokens.Colors.error
            }
        }
    }

    /// RAG priority coding: High=red, Medium=orange, Low=blue/gray
    enum Priority: CaseIterable {
        case critical
        case high
        case medium
        case low

        var color: Color {
            switch self {
            case .critical: return DesignTokens.Colors.error
            case .high: return DesignTokens.Colors.error
            case .medium: return DesignTokens.Colors.warning
            case .low: return DesignTokens.Colors.info
            }
        }

        var backgroundColor: Color {
            switch self {
            case .critical: return DesignTokens.Colors.error.opacity(0.1)
            case .high: return DesignTokens.Colors.error.opacity(0.1)
            case .medium: return DesignTokens.Colors.warning.opacity(0.1)
            case .low: return DesignTokens.Colors.info.opacity(0.1)
            }
        }

        var label: String {
            switch self {
            case .critical: return "Critical"
            case .high: return "High"
            case .medium: return "Medium"
            case .low: return "Low"
            }
        }

        var icon: String {
            switch self {
            case .critical: return "exclamationmark.circle.fill"
            case .high: return "exclamationmark.triangle.fill"
            case .medium: return "info.circle.fill"
            case .low: return "checkmark.circle.fill"
            }
        }

        var sortOrder: Int {
            switch self {
            case .critical: return 0
            case .high: return 1
            case .medium: return 2
            case .low: return 3
            }
        }
    }

    static func == (lhs: Recommendation, rhs: Recommendation) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Smart Scan State Manager

@MainActor
class SmartScanManager: ObservableObject {
    @Published var isScanning = false
    @Published var scanProgress: Double = 0.0
    @Published var currentPhase: ScanPhase = .idle
    @Published var healthScore: Int = 0
    @Published var hasScanResult: Bool = false
    @Published var recommendations: [Recommendation] = []
    @Published var lastScanDate: Date?
    @Published var lastReclaimableBytes: Int64?
    @Published var scanStartDate: Date?
    @Published var spaceFoundBytes: Int64?
    @Published var appsScannedCount: Int?
    @Published var flaggedCount: Int?

    private let scanEngine = SmartScanEngine()
    private let activityLog = ActivityLogStore.shared
    private var scanTask: Task<Void, Never>?

    enum ScanPhase: String, CaseIterable {
        case idle = "Ready"
        case preparing = "Preparing"
        case scanningDisk = "Scanning disk"
        case checkingApps = "Checking apps"
        case analyzingSystem = "Analyzing system"
        case complete = "Complete"

        var icon: String {
            switch self {
            case .idle: return "circle"
            case .preparing: return "gearshape.2"
            case .scanningDisk: return "externaldrive.fill"
            case .checkingApps: return "app.badge"
            case .analyzingSystem: return "chart.line.uptrend.xyaxis"
            case .complete: return "checkmark.circle.fill"
            }
        }
    }

    init() {
    }

    // MARK: - Smart Scan

    func startSmartScan() {
        guard scanTask == nil else { return }

        scanTask = Task {
            await runSmartScan()
        }
    }

    func stopSmartScan() {
        scanTask?.cancel()
        isScanning = false
        scanProgress = 0.0
        currentPhase = .idle
        scanStartDate = nil
    }

    private func runSmartScan() async {
        guard !isScanning else {
            scanTask = nil
            return
        }

        isScanning = true
        scanStartDate = Date()
        scanProgress = 0.0
        currentPhase = .preparing

        spaceFoundBytes = nil
        appsScannedCount = nil
        flaggedCount = nil

        defer {
            scanTask = nil
        }

        let stages: [ScanStage] = [.preparing, .scanningDisk, .analyzingSystem, .checkingApps]
        for stage in stages {
            if Task.isCancelled { break }
            currentPhase = mapPhase(from: stage)
            scanProgress = await scanEngine.runStage(stage)
            if Task.isCancelled { break }
            refreshLiveCounters()
        }

        if Task.isCancelled {
            isScanning = false
            scanProgress = 0.0
            currentPhase = .idle
            scanStartDate = nil
            return
        }

        let result = await scanEngine.finalizeScan()
        healthScore = result.systemHealthScore
        hasScanResult = true
        lastScanDate = Date()
        lastReclaimableBytes = result.totalSpaceToReclaim
        updateRecommendations(from: result)

        spaceFoundBytes = result.totalSpaceToReclaim
        flaggedCount = recommendations.filter { !$0.isCompleted }.count

        let detail = "Found \(formatBytes(result.totalSpaceToReclaim)) reclaimable · Score +\(result.systemHealthScore) · Duration \(formatDuration(result.scanDuration))"
        let event = ActivityEvent(
            category: .scan,
            title: "Smart Scan completed",
            detail: detail,
            impact: activityImpact(for: result.totalSpaceToReclaim)
        )
        activityLog.record(event)

        scanProgress = 1.0
        currentPhase = .complete
        isScanning = false
        scanStartDate = nil
    }

    private func refreshLiveCounters() {
        if let bytes = scanEngine.partialSpaceFoundBytes {
            spaceFoundBytes = bytes
        }
        flaggedCount = scanEngine.partialFlaggedCount
    }

    // MARK: - Quick Actions

    func quickScan() async {
        startSmartScan()
    }

    func quickClean() async {
        // Simulate quick clean
        let event = ActivityEvent(
            category: .clean,
            title: "Quick Clean completed",
            detail: "Cleaned temporary files and cache",
            impact: .medium
        )
        activityLog.record(event)

        // Update a recommendation
        if let index = recommendations.firstIndex(where: { $0.type == .clean }) {
            recommendations[index].isCompleted = true
        }
    }

    func quickOptimize() async {
        // Simulate optimization
        let event = ActivityEvent(
            category: .optimize,
            title: "System optimized",
            detail: "Optimized memory and startup items",
            impact: .low
        )
        activityLog.record(event)
    }

    // MARK: - Helpers

    private func updateRecommendations(from result: SmartScanResult) {
        recommendations = result.recommendations.map { recommendation(from: $0) }
    }

    private func mapPhase(from stage: ScanStage) -> ScanPhase {
        switch stage {
        case .preparing: return .preparing
        case .scanningDisk: return .scanningDisk
        case .checkingApps: return .checkingApps
        case .analyzingSystem: return .analyzingSystem
        case .complete: return .complete
        }
    }

    private func recommendation(from scanRecommendation: ScanRecommendation) -> Recommendation {
        Recommendation(
            scanRecommendation: scanRecommendation,
            type: recommendationType(for: scanRecommendation),
            category: recommendationCategory(for: scanRecommendation),
            priority: recommendationPriority(for: scanRecommendation),
            actionText: actionText(for: scanRecommendation)
        )
    }

    private func recommendationType(for scanRecommendation: ScanRecommendation) -> Recommendation.RecommendationType {
        switch scanRecommendation.type {
        case .launchAgents: return .optimize
        case .cache, .logs, .tempFiles, .trash, .oldFiles, .languageFiles, .duplicates, .oldApps, .largeApps, .largeFiles, .hiddenSpace:
            return .clean
        }
    }

    private func recommendationCategory(for scanRecommendation: ScanRecommendation) -> Recommendation.RecommendationCategory {
        switch scanRecommendation.type {
        case .cache, .tempFiles: return .cache
        case .logs: return .logs
        case .oldApps, .largeApps: return .apps
        case .launchAgents: return .system
        case .trash, .oldFiles, .languageFiles, .duplicates, .largeFiles, .hiddenSpace: return .other
        }
    }

    private func recommendationPriority(for scanRecommendation: ScanRecommendation) -> Recommendation.Priority {
        let bytes = scanRecommendation.spaceToReclaim
        if bytes >= 1_000_000_000 { return .high }
        if bytes >= 250_000_000 { return .medium }
        if bytes > 0 { return .low }
        switch scanRecommendation.type {
        case .launchAgents:
            return .medium
        default:
            return .low
        }
    }

    private func actionText(for scanRecommendation: ScanRecommendation) -> String {
        switch recommendationType(for: scanRecommendation) {
        case .clean: return "Clean Now"
        case .optimize: return "Optimize"
        case .update: return "Update"
        case .security: return "Review"
        }
    }

    private func activityImpact(for reclaimableBytes: Int64) -> ActivityImpact {
        if reclaimableBytes >= 1_000_000_000 { return .high }
        if reclaimableBytes >= 250_000_000 { return .medium }
        return .low
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        String(format: "%.1fs", seconds)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}


// MARK: - Dashboard Recommendation Row Component (Native List Style)

struct DashboardRecommendationRow: View {
    let recommendation: Recommendation
    let showDetails: () -> Void
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Button(action: showDetails) {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    // Priority icon with background tint
                    ZStack {
                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.small)
                            .fill(recommendation.priority.backgroundColor)
                            .frame(width: 32, height: 32)

                        Image(systemName: recommendation.priority.icon)
                            .foregroundColor(recommendation.priority.color)
                            .font(.system(size: 14))
                    }

                    // Content
                    VStack(alignment: .leading, spacing: 2) {
                        Text(recommendation.title)
                            .font(DesignTokens.Typography.subhead)
                            .foregroundColor(DesignTokens.Colors.textPrimary)

                        Text(recommendation.description)
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    }

                    Spacer()

                    // Priority badge
                    Text(recommendation.priority.label)
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(recommendation.priority.color)
                        .padding(.horizontal, DesignTokens.Spacing.xxs)
                        .padding(.vertical, 2)
                        .background(recommendation.priority.backgroundColor)
                        .cornerRadius(DesignTokens.CornerRadius.small)

                    // Score impact badge
                    Text("Score +\(recommendation.scoreImpact)")
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(DesignTokens.Colors.accent)
                        .padding(.horizontal, DesignTokens.Spacing.xxs)
                        .padding(.vertical, 2)
                        .background(DesignTokens.Colors.accent.opacity(0.12))
                        .cornerRadius(DesignTokens.CornerRadius.small)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Action Button
            Button(action: action) {
                Text(recommendation.actionText)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, DesignTokens.Spacing.sm)
                    .padding(.vertical, DesignTokens.Spacing.xxs)
                    .background(DesignTokens.Colors.accent)
                    .cornerRadius(DesignTokens.CornerRadius.small)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(isHovered ? DesignTokens.Colors.unemphasizedSelectedContentBackground.opacity(0.5) : Color.clear)
        .onHover { hovering in
            withAnimation(DesignTokens.Animation.fast) {
                isHovered = hovering
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(recommendation.title), \(recommendation.priority.label) priority")
        .accessibilityHint("Double tap to view details or \(recommendation.actionText.lowercased())")
    }
}

// MARK: - Compact Activity Row Component

struct CompactActivityRow: View {
    let activity: ActivityEvent

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            // Icon
            Image(systemName: activity.category.icon)
                .foregroundColor(activity.category.color)
                .font(.system(size: 14))
                .frame(width: 24, height: 24)

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(activity.title)
                    .font(DesignTokens.Typography.subhead)
                    .foregroundColor(DesignTokens.Colors.textPrimary)

                Text(activity.detail)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            // Time
            Text(relativeTime)
                .font(DesignTokens.Typography.caption)
                .foregroundColor(DesignTokens.Colors.textTertiary)
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(activity.title), \(activity.detail), \(relativeTime)")
    }

    private var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: activity.timestamp, relativeTo: Date())
    }
}
