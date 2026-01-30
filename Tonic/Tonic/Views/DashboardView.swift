//
//  DashboardView.swift
//  Tonic
//
//  Redesigned dashboard with native macOS layouts
//  Task: fn-4-as7.7
//

import SwiftUI
import IOKit.ps

// MARK: - Activity Timeline Model

struct ActivityItem: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let type: ActivityType
    let title: String
    let description: String
    let impact: ImpactLevel

    enum ActivityType: String {
        case scan = "Scan"
        case clean = "Clean"
        case optimize = "Optimize"
        case alert = "Alert"
        case info = "Info"

        var icon: String {
            switch self {
            case .scan: return "magnifyingglass"
            case .clean: return "sparkles"
            case .optimize: return "gearshape.2"
            case .alert: return "exclamationmark.triangle.fill"
            case .info: return "info.circle"
            }
        }

        var color: Color {
            switch self {
            case .scan: return DesignTokens.Colors.accent
            case .clean: return DesignTokens.Colors.success
            case .optimize: return DesignTokens.Colors.accent
            case .alert: return DesignTokens.Colors.error
            case .info: return DesignTokens.Colors.textSecondary
            }
        }
    }

    enum ImpactLevel: String {
        case high = "High"
        case medium = "Medium"
        case low = "Low"

        var color: Color {
            switch self {
            case .high: return DesignTokens.Colors.error
            case .medium: return DesignTokens.Colors.warning
            case .low: return DesignTokens.Colors.success
            }
        }
    }

    static func == (lhs: ActivityItem, rhs: ActivityItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Recommendation Model

struct Recommendation: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let description: String
    let type: RecommendationType
    let category: RecommendationCategory
    let priority: Priority
    let actionText: String
    var isCompleted: Bool = false

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
    @Published var lastScanResult: ScanResult?
    @Published var healthScore: Int = 85
    @Published var activityHistory: [ActivityItem] = []
    @Published var recommendations: [Recommendation] = []

    private var systemMonitor = SystemMonitor()

    enum ScanPhase: String, CaseIterable {
        case idle = "Ready"
        case analyzing = "Analyzing system"
        case scanningJunk = "Scanning junk files"
        case checkingMemory = "Checking memory pressure"
        case evaluatingApps = "Evaluating applications"
        case complete = "Complete"

        var icon: String {
            switch self {
            case .idle: return "circle"
            case .analyzing: return "magnifyingglass"
            case .scanningJunk: return "doc.fill"
            case .checkingMemory: return "memorychip"
            case .evaluatingApps: return "app.badge"
            case .complete: return "checkmark.circle.fill"
            }
        }
    }

    init() {
        loadSampleData()
    }

    // MARK: - Smart Scan

    func startSmartScan() async {
        guard !isScanning else { return }
        isScanning = true
        scanProgress = 0.0

        // Phase 1: Analyzing
        currentPhase = .analyzing
        try? await Task.sleep(nanoseconds: 500_000_000)
        scanProgress = 0.2

        // Phase 2: Scanning junk files
        currentPhase = .scanningJunk
        try? await Task.sleep(nanoseconds: 800_000_000)
        scanProgress = 0.4

        // Phase 3: Checking memory
        currentPhase = .checkingMemory
        try? await Task.sleep(nanoseconds: 600_000_000)
        scanProgress = 0.6

        // Phase 4: Evaluating apps
        currentPhase = .evaluatingApps
        try? await Task.sleep(nanoseconds: 700_000_000)
        scanProgress = 0.8

        // Generate results
        let result = generateScanResult()
        lastScanResult = result
        healthScore = result.healthScore

        // Update recommendations based on scan
        updateRecommendations(from: result)

        // Add to activity
        let activity = ActivityItem(
            timestamp: Date(),
            type: .scan,
            title: "Smart Scan Completed",
            description: "Found \(formatBytes(result.totalReclaimableSpace)) of reclaimable space",
            impact: result.totalReclaimableSpace > 1_000_000_000 ? .high : .medium
        )
        activityHistory.insert(activity, at: 0)
        if activityHistory.count > 10 {
            activityHistory.removeLast()
        }

        scanProgress = 1.0
        currentPhase = .complete
        isScanning = false
    }

    // MARK: - Quick Actions

    func quickScan() async {
        await startSmartScan()
    }

    func quickClean() async {
        // Simulate quick clean
        let activity = ActivityItem(
            timestamp: Date(),
            type: .clean,
            title: "Quick Clean",
            description: "Cleaned temporary files and cache",
            impact: .medium
        )
        activityHistory.insert(activity, at: 0)

        // Update a recommendation
        if let index = recommendations.firstIndex(where: { $0.type == .clean }) {
            recommendations[index].isCompleted = true
        }
    }

    func quickOptimize() async {
        // Simulate optimization
        let activity = ActivityItem(
            timestamp: Date(),
            type: .optimize,
            title: "System Optimized",
            description: "Optimized memory and startup items",
            impact: .low
        )
        activityHistory.insert(activity, at: 0)
    }

    // MARK: - Helpers

    private func generateScanResult() -> ScanResult {
        // Simulated scan result - in production, this would use real data
        let junkSize = Int64.random(in: 500_000_000...3_000_000_000)
        let healthScore = max(Int(100 - (Int(junkSize) / 100_000_000)), 50)

        return ScanResult(
            id: UUID(),
            timestamp: Date(),
            healthScore: healthScore,
            junkFiles: JunkCategory(
                tempFiles: FileGroup(name: "Temporary Files", description: "App temp files", size: junkSize / 3, count: 1240),
                cacheFiles: FileGroup(name: "Cache Files", description: "Application cache", size: junkSize / 2, count: 850),
                logFiles: FileGroup(name: "Log Files", description: "Old log files", size: junkSize / 6, count: 320),
                trashItems: FileGroup(name: "Trash", description: "Items in trash", size: 0, count: 0),
                languageFiles: FileGroup(name: "Language Files", description: "Unused localizations", size: 150_000_000, count: 4500),
                oldFiles: FileGroup(name: "Old Files", description: "Files older than 90 days", size: 200_000_000, count: 150)
            ),
            performanceIssues: PerformanceCategory(
                launchAgents: FileGroup(name: "Launch Agents", description: "Disabled", size: 0, count: 0),
                loginItems: FileGroup(name: "Login Items", description: "5 items", size: 0, count: 5),
                browserCaches: FileGroup(name: "Browser Cache", description: "Chrome, Safari", size: 450_000_000, count: 1200),
                memoryIssues: ["High memory pressure detected"],
                diskFragmentation: nil
            ),
            appIssues: AppIssueCategory(
                unusedApps: [],
                largeApps: [],
                duplicateApps: [],
                orphanedFiles: []
            ),
            privacyIssues: PrivacyCategory(
                browserHistory: FileGroup(name: "Browser History", description: "History data", size: 25_000_000, count: 5000),
                downloadHistory: FileGroup(name: "Downloads", description: "Download history", size: 5_000_000, count: 150),
                recentDocuments: FileGroup(name: "Recent Documents", description: "Recent items", size: 1_000_000, count: 50),
                clipboardData: FileGroup(name: "Clipboard", description: "Clipboard data", size: 0, count: 0)
            ),
            totalReclaimableSpace: junkSize
        )
    }

    private func updateRecommendations(from result: ScanResult) {
        recommendations.removeAll()

        // Add junk file recommendation (Cache category)
        if result.junkFiles.totalSize > 100_000_000 {
            recommendations.append(Recommendation(
                title: "Clean Junk Files",
                description: formatBytes(result.junkFiles.totalSize) + " of junk files found",
                type: .clean,
                category: .cache,
                priority: result.junkFiles.totalSize > 1_000_000_000 ? .high : .medium,
                actionText: "Clean Now"
            ))
        }

        // Add memory recommendation (System category)
        if !result.performanceIssues.memoryIssues.isEmpty {
            recommendations.append(Recommendation(
                title: "Optimize Memory",
                description: "High memory pressure detected",
                type: .optimize,
                category: .system,
                priority: .high,
                actionText: "Optimize"
            ))
        }

        // Add login items recommendation (System category)
        if result.performanceIssues.loginItems.count > 3 {
            recommendations.append(Recommendation(
                title: "Review Login Items",
                description: "\(result.performanceIssues.loginItems.count) items slowing startup",
                type: .optimize,
                category: .system,
                priority: .medium,
                actionText: "Review"
            ))
        }

        // Add browser cache recommendation (Cache category)
        if result.performanceIssues.browserCaches.size > 100_000_000 {
            recommendations.append(Recommendation(
                title: "Clear Browser Cache",
                description: formatBytes(result.performanceIssues.browserCaches.size) + " of cached data",
                type: .clean,
                category: .cache,
                priority: .low,
                actionText: "Clear"
            ))
        }
    }

    private func loadSampleData() {
        // Sample activity history
        activityHistory = [
            ActivityItem(
                timestamp: Date().addingTimeInterval(-3600),
                type: .clean,
                title: "Cache Cleaned",
                description: "450 MB of browser cache removed",
                impact: .medium
            ),
            ActivityItem(
                timestamp: Date().addingTimeInterval(-86400),
                type: .scan,
                title: "Scheduled Scan",
                description: "System health is good",
                impact: .low
            ),
            ActivityItem(
                timestamp: Date().addingTimeInterval(-172800),
                type: .optimize,
                title: "Memory Optimized",
                description: "Freed 1.2 GB of memory",
                impact: .high
            ),
            ActivityItem(
                timestamp: Date().addingTimeInterval(-259200),
                type: .info,
                title: "Tonic Updated",
                description: "Version 0.1.0 installed",
                impact: .low
            )
        ]

        // Initial recommendations with categories
        recommendations = [
            Recommendation(
                title: "Clean Junk Files",
                description: "1.2 GB of junk files found",
                type: .clean,
                category: .cache,
                priority: .high,
                actionText: "Clean Now"
            ),
            Recommendation(
                title: "Review Login Items",
                description: "5 items slowing startup",
                type: .optimize,
                category: .system,
                priority: .medium,
                actionText: "Review"
            ),
            Recommendation(
                title: "Clear Browser Cache",
                description: "450 MB of cached data",
                type: .clean,
                category: .cache,
                priority: .low,
                actionText: "Clear"
            )
        ]
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
    @StateObject private var scanManager = SmartScanManager()
    @State private var widgetDataManager = WidgetDataManager.shared
    @State private var showWidgetCustomization = false
    @State private var showWidgetOnboarding = false
    @State private var showHealthScoreExplanation = false
    @State private var isActivityExpanded = false

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
        .sheet(isPresented: $showWidgetOnboarding) {
            WidgetOnboardingView()
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
                    .trim(from: 0, to: CGFloat(scanManager.healthScore) / 100)
                    .stroke(healthScoreColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: scanManager.healthScore)

                VStack(spacing: DesignTokens.Spacing.xxxs) {
                    Text("\(scanManager.healthScore)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(healthScoreColor)

                    Text(healthRatingText)
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
            }
            .padding(.vertical, DesignTokens.Spacing.sm)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("System health score: \(scanManager.healthScore) out of 100, \(healthRatingText)")

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
        switch scanManager.healthScore {
        case 90...100: return DesignTokens.Colors.success
        case 75..<90: return DesignTokens.Colors.success
        case 50..<75: return DesignTokens.Colors.warning
        default: return DesignTokens.Colors.error
        }
    }

    private var healthRatingText: String {
        switch scanManager.healthScore {
        case 90...100: return "Excellent"
        case 75..<90: return "Good"
        case 50..<75: return "Fair"
        case 25..<50: return "Poor"
        default: return "Critical"
        }
    }

    // MARK: - Smart Scan Button (Primary CTA)

    private var smartScanButton: some View {
        Button {
            if !scanManager.isScanning {
                Task {
                    await scanManager.startSmartScan()
                }
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
                            DashboardRecommendationRow(recommendation: recommendation) {
                                Task {
                                    await handleRecommendation(recommendation)
                                }
                            }

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

                if scanManager.activityHistory.count > 3 {
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
                ? Array(scanManager.activityHistory)
                : Array(scanManager.activityHistory.prefix(3))

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

// MARK: - Dashboard Recommendation Row Component (Native List Style)

struct DashboardRecommendationRow: View {
    let recommendation: Recommendation
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
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
        .accessibilityHint("Double tap to \(recommendation.actionText.lowercased())")
    }
}

// MARK: - Compact Activity Row Component

struct CompactActivityRow: View {
    let activity: ActivityItem

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            // Icon
            Image(systemName: activity.type.icon)
                .foregroundColor(activity.type.color)
                .font(.system(size: 14))
                .frame(width: 24, height: 24)

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(activity.title)
                    .font(DesignTokens.Typography.subhead)
                    .foregroundColor(DesignTokens.Colors.textPrimary)

                Text(activity.description)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .lineLimit(1)
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
        .accessibilityLabel("\(activity.title), \(activity.description), \(relativeTime)")
    }

    private var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: activity.timestamp, relativeTo: Date())
    }
}

// MARK: - Preview

#Preview {
    DashboardView()
        .frame(width: 900, height: 700)
}
