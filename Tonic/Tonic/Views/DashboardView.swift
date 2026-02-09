//
//  DashboardView.swift
//  Tonic
//
//  Redesigned dashboard with native macOS layouts
//  Task: fn-4-as7.7
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

// MARK: - Main Dashboard View

struct DashboardView: View {
    @ObservedObject var scanManager: SmartScanManager
    @State private var widgetDataManager = WidgetDataManager.shared
    @State private var showWidgetCustomization = false
    @State private var showHealthScoreExplanation = false
    @State private var isActivityExpanded = false
    @State private var activityStore = ActivityLogStore.shared
    @State private var detailRecommendation: ScanRecommendation?
    @State private var showingRecommendationDetail = false

    init(scanManager: SmartScanManager) {
        self.scanManager = scanManager
    }

    var body: some View {
        ScrollView {
            HStack(alignment: .top, spacing: DesignTokens.Spacing.lg) {
                // Left Column
                VStack(spacing: DesignTokens.Spacing.md) {
                    // Health Ring with explanation
                    healthRingSection

                    // Primary CTA: Smart Scan (only one!)
                    smartScanButton

                    // Real-time stats using MetricRow
                    realTimeStatsSection
                }
                .frame(minWidth: 280, maxWidth: 320)

                // Right Column
                VStack(spacing: DesignTokens.Spacing.md) {
                    // Recommendations grouped by category with RAG priority
                    if !scanManager.recommendations.filter({ !$0.isCompleted }).isEmpty {
                        recommendationsSection
                    }

                    // Recent Activity (collapsed by default)
                    activitySection
                }
                .frame(maxWidth: .infinity)
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .background(DesignTokens.Colors.background)
        .sheet(isPresented: $showWidgetCustomization) {
            WidgetCustomizationView()
        }
        .sheet(isPresented: $showingRecommendationDetail, onDismiss: {
            detailRecommendation = nil
        }) {
            if let recommendation = detailRecommendation {
                RecommendationDetailView(
                    recommendation: recommendation,
                    isPresented: $showingRecommendationDetail
                )
            }
        }
        .onAppear {
            if !widgetDataManager.isMonitoring {
                widgetDataManager.startMonitoring()
            }
        }
    }

    // MARK: - Health Ring Section

    private var healthRingSection: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            // Health Ring
            ZStack {
                Circle()
                    .stroke(DesignTokens.Colors.separator.opacity(0.3), lineWidth: 10)
                    .frame(width: 140, height: 140)

                Circle()
                    .trim(from: 0, to: CGFloat(displayHealthScore) / 100)
                    .stroke(healthScoreColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: displayHealthScore)

                VStack(spacing: DesignTokens.Spacing.xxxs) {
                    Text(displayHealthScoreText)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(healthScoreColor)

                    Text(healthRatingText)
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
            }
            .padding(.vertical, DesignTokens.Spacing.sm)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(healthScoreAccessibilityLabel)

            // Health Score Explanation Button
            Button {
                showHealthScoreExplanation.toggle()
            } label: {
                HStack(spacing: DesignTokens.Spacing.xxxs) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                    Text("How is this calculated?")
                        .font(DesignTokens.Typography.caption)
                }
                .foregroundColor(DesignTokens.Colors.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Health score explanation")
            .accessibilityHint("Shows how the health score is calculated")
            .popover(isPresented: $showHealthScoreExplanation, arrowEdge: .bottom) {
                healthScoreExplanationPopover
            }
        }
        .frame(maxWidth: .infinity)
        .padding(DesignTokens.Spacing.md)
        .background(DesignTokens.Colors.backgroundSecondary)
        .cornerRadius(DesignTokens.CornerRadius.medium)
    }

    private var healthScoreExplanationPopover: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Health Score Calculation")
                .font(DesignTokens.Typography.bodyEmphasized)
                .foregroundColor(DesignTokens.Colors.textPrimary)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                healthFactorRow(icon: "internaldrive", label: "Disk Space", description: "Available storage on your system")
                healthFactorRow(icon: "memorychip", label: "Memory Pressure", description: "RAM usage and availability")
                healthFactorRow(icon: "trash", label: "Junk Files", description: "Cache, logs, and temporary files")
                healthFactorRow(icon: "app.badge", label: "Startup Items", description: "Login items affecting boot time")
            }

            Text("Score ranges: 90-100 Excellent, 75-89 Good, 50-74 Fair, <50 Poor")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(DesignTokens.Colors.textTertiary)
        }
        .padding(DesignTokens.Spacing.md)
        .frame(width: 280)
    }

    private func healthFactorRow(icon: String, label: String, description: String) -> some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(DesignTokens.Colors.accent)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(DesignTokens.Typography.subhead)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                Text(description)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
        }
    }

    private var healthScoreColor: Color {
        if !scanManager.hasScanResult {
            return DesignTokens.Colors.textSecondary
        }
        switch scanManager.healthScore {
        case 90...100: return DesignTokens.Colors.success
        case 75..<90: return DesignTokens.Colors.success
        case 50..<75: return DesignTokens.Colors.warning
        default: return DesignTokens.Colors.error
        }
    }

    private var healthRatingText: String {
        if !scanManager.hasScanResult {
            return "Not Scanned"
        }
        switch scanManager.healthScore {
        case 90...100: return "Excellent"
        case 75..<90: return "Good"
        case 50..<75: return "Fair"
        case 25..<50: return "Poor"
        default: return "Critical"
        }
    }

    private var displayHealthScore: Int {
        scanManager.hasScanResult ? scanManager.healthScore : 0
    }

    private var displayHealthScoreText: String {
        scanManager.hasScanResult ? "\(scanManager.healthScore)" : "--"
    }

    private var healthScoreAccessibilityLabel: String {
        if scanManager.hasScanResult {
            return "System health score: \(scanManager.healthScore) out of 100, \(healthRatingText)"
        }
        return "System health score: not scanned yet"
    }

    // MARK: - Smart Scan Button (Primary CTA)

    private var smartScanButton: some View {
        Button {
            if !scanManager.isScanning {
                scanManager.startSmartScan()
            }
        } label: {
            HStack(spacing: DesignTokens.Spacing.sm) {
                if scanManager.isScanning {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .medium))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(scanManager.isScanning ? "Scanning..." : "Smart Scan")
                        .font(DesignTokens.Typography.bodyEmphasized)

                    if scanManager.isScanning {
                        Text(scanManager.currentPhase.rawValue)
                            .font(DesignTokens.Typography.caption)
                            .opacity(0.9)
                    } else {
                        Text("Analyze your system")
                            .font(DesignTokens.Typography.caption)
                            .opacity(0.8)
                    }
                }

                Spacer()

                if scanManager.isScanning {
                    Text("\(Int(scanManager.scanProgress * 100))%")
                        .font(DesignTokens.Typography.monoSubhead)
                }
            }
            .foregroundColor(.white)
            .padding(DesignTokens.Spacing.md)
            .frame(maxWidth: .infinity)
            .background(DesignTokens.Colors.accent)
            .cornerRadius(DesignTokens.CornerRadius.medium)
        }
        .buttonStyle(.plain)
        .disabled(scanManager.isScanning)
        .accessibilityLabel(scanManager.isScanning ? "Scanning, \(Int(scanManager.scanProgress * 100)) percent complete" : "Start Smart Scan")
    }

    // MARK: - Real-time Stats Section

    private var realTimeStatsSection: some View {
        VStack(spacing: 0) {
            // CPU
            MetricRow(
                icon: "cpu",
                title: "CPU",
                value: formatCPU(),
                iconColor: cpuColor,
                sparklineData: Array(widgetDataManager.cpuHistory.suffix(10)),
                sparklineColor: cpuColor
            )

            Divider()
                .padding(.leading, DesignTokens.Spacing.sm + 24 + DesignTokens.Spacing.sm)

            // Memory
            MetricRow(
                icon: "memorychip",
                title: "Memory",
                value: formatMemory(),
                iconColor: memoryColor,
                sparklineData: Array(widgetDataManager.memoryHistory.suffix(10)),
                sparklineColor: memoryColor
            )

            Divider()
                .padding(.leading, DesignTokens.Spacing.sm + 24 + DesignTokens.Spacing.sm)

            // Disk
            MetricRow(
                icon: "internaldrive",
                title: "Disk",
                value: formatDisk(),
                iconColor: diskColor
            )
        }
        .background(DesignTokens.Colors.backgroundSecondary)
        .cornerRadius(DesignTokens.CornerRadius.medium)
    }

    private func formatCPU() -> String {
        "\(Int(widgetDataManager.cpuData.totalUsage))%"
    }

    private var cpuColor: Color {
        let usage = widgetDataManager.cpuData.totalUsage
        if usage < 50 { return DesignTokens.Colors.success }
        if usage < 80 { return DesignTokens.Colors.warning }
        return DesignTokens.Colors.error
    }

    private func formatMemory() -> String {
        let used = widgetDataManager.memoryData.usedBytes
        let total = widgetDataManager.memoryData.totalBytes
        let usedGB = Double(used) / (1024 * 1024 * 1024)
        let totalGB = Double(total) / (1024 * 1024 * 1024)
        return String(format: "%.1f / %.0f GB", usedGB, totalGB)
    }

    private var memoryColor: Color {
        switch widgetDataManager.memoryData.pressure {
        case .normal: return DesignTokens.Colors.success
        case .warning: return DesignTokens.Colors.warning
        case .critical: return DesignTokens.Colors.error
        }
    }

    private func formatDisk() -> String {
        guard let bootVolume = widgetDataManager.diskVolumes.first(where: { $0.isBootVolume }) else {
            return "--"
        }
        let freeGB = Double(bootVolume.freeBytes) / (1024 * 1024 * 1024)
        return String(format: "%.0f GB free", freeGB)
    }

    private var diskColor: Color {
        guard let bootVolume = widgetDataManager.diskVolumes.first(where: { $0.isBootVolume }) else {
            return DesignTokens.Colors.textSecondary
        }
        let usagePercent = bootVolume.usagePercentage
        if usagePercent < 70 { return DesignTokens.Colors.success }
        if usagePercent < 90 { return DesignTokens.Colors.warning }
        return DesignTokens.Colors.error
    }


    // MARK: - Recommendations Section

    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Recommendations")
                .font(DesignTokens.Typography.h3)
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .padding(.horizontal, DesignTokens.Spacing.sm)

            // Group recommendations by category
            let activeRecommendations = scanManager.recommendations.filter { !$0.isCompleted }
            let groupedRecommendations = Dictionary(grouping: activeRecommendations) { $0.category }

            VStack(spacing: 0) {
                ForEach(Array(Recommendation.RecommendationCategory.allCases), id: \.self) { category in
                    let categoryRecommendations = groupedRecommendations[category] ?? []
                    if !categoryRecommendations.isEmpty {
                        // Category header
                        HStack {
                            Text(category.rawValue)
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                            Spacer()
                        }
                        .padding(.horizontal, DesignTokens.Spacing.md)
                        .padding(.vertical, DesignTokens.Spacing.xs)
                        .background(DesignTokens.Colors.backgroundTertiary.opacity(0.5))

                        // Recommendations in this category, sorted by priority
                        let sortedRecommendations = categoryRecommendations.sorted { $0.priority.sortOrder < $1.priority.sortOrder }
                        ForEach(Array(sortedRecommendations.enumerated()), id: \.element.id) { index, recommendation in
                            DashboardRecommendationRow(
                                recommendation: recommendation,
                                showDetails: {
                                    detailRecommendation = recommendation.scanRecommendation
                                    showingRecommendationDetail = true
                                },
                                action: {
                                    Task {
                                        await handleRecommendation(recommendation)
                                    }
                                }
                            )

                            if index < sortedRecommendations.count - 1 {
                                Divider()
                                    .padding(.leading, DesignTokens.Spacing.md + 36)
                            }
                        }
                    }
                }
            }
            .background(DesignTokens.Colors.backgroundSecondary)
            .cornerRadius(DesignTokens.CornerRadius.medium)
        }
    }

    private func handleRecommendation(_ recommendation: Recommendation) async {
        switch recommendation.type {
        case .clean:
            await scanManager.quickClean()
        case .optimize:
            await scanManager.quickOptimize()
        case .update, .security:
            break
        }
    }

    // MARK: - Activity Section

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            // Header with View All link
            HStack {
                Text("Recent Activity")
                    .font(DesignTokens.Typography.h3)
                    .foregroundColor(DesignTokens.Colors.textPrimary)

                Spacer()

                if activityStore.entries.count > 3 {
                    Button {
                        withAnimation(DesignTokens.Animation.fast) {
                            isActivityExpanded.toggle()
                        }
                    } label: {
                        Text(isActivityExpanded ? "Show Less" : "View All")
                            .font(DesignTokens.Typography.subhead)
                            .foregroundColor(DesignTokens.Colors.accent)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isActivityExpanded ? "Show less activity history" : "View all activity history")
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)

            // Activity list (collapsed: 3 items, expanded: all)
            let visibleActivities = isActivityExpanded
                ? Array(activityStore.entries)
                : Array(activityStore.entries.prefix(3))

            if visibleActivities.isEmpty {
                emptyActivityState
            } else {
                VStack(spacing: 0) {
                    ForEach(visibleActivities) { activity in
                        CompactActivityRow(activity: activity)

                        if activity.id != visibleActivities.last?.id {
                            Divider()
                                .padding(.leading, DesignTokens.Spacing.md + 32)
                        }
                    }
                }
                .background(DesignTokens.Colors.backgroundSecondary)
                .cornerRadius(DesignTokens.CornerRadius.medium)
            }
        }
    }

    private var emptyActivityState: some View {
        VStack(alignment: .center, spacing: DesignTokens.Spacing.xs) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 20))
                .foregroundColor(DesignTokens.Colors.textTertiary)

            Text("No activity yet")
                .font(DesignTokens.Typography.subheadEmphasized)
                .foregroundColor(DesignTokens.Colors.textPrimary)

            Text("Run a Smart Scan to get started.")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(DesignTokens.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(DesignTokens.Spacing.md)
        .background(DesignTokens.Colors.backgroundSecondary)
        .cornerRadius(DesignTokens.CornerRadius.medium)
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

// MARK: - Preview

#Preview {
    DashboardView(scanManager: SmartScanManager())
        .frame(width: 900, height: 700)
}
