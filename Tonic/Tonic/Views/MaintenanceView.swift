//
//  MaintenanceView.swift
//  Tonic
//
//  Unified Maintenance view combining Smart Scan and Deep Clean functionality
//  Task ID: fn-4-as7.8
//

import SwiftUI

// MARK: - Maintenance Tab

enum MaintenanceTab: String, CaseIterable, Identifiable {
    case scan = "Scan"
    case clean = "Clean"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .scan: return "sparkles"
        case .clean: return "trash"
        }
    }
}

// MARK: - Maintenance View

struct MaintenanceView: View {
    @State private var selectedTab: MaintenanceTab = .scan

    var body: some View {
        VStack(spacing: 0) {
            // Header with tab picker
            header

            Divider()

            // Tab content
            Group {
                switch selectedTab {
                case .scan:
                    ScanTabView()
                case .clean:
                    CleanTabView()
                }
            }
        }
        .background(DesignTokens.Colors.background)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Label("Maintenance", systemImage: "wrench.and.screwdriver")
                .font(DesignTokens.Typography.bodyEmphasized)

            Spacer()

            // Segmented tab picker
            Picker("Tab", selection: $selectedTab) {
                ForEach(MaintenanceTab.allCases) { tab in
                    Label(tab.rawValue, systemImage: tab.icon)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(DesignTokens.Colors.backgroundSecondary)
    }
}

// MARK: - Scan Tab View

struct ScanTabView: View {
    @State private var scanner = SmartScanEngine()
    @State private var isScanning = false
    @State private var currentStage: ScanStage = .preparing
    @State private var scanProgress: Double = 0
    @State private var stageSubtext: String = "Ready to scan"
    @State private var scanResult: SmartScanResult?
    @State private var showSummarySheet = false

    private let stages = ScanStage.allCases.filter { $0 != .complete }

    var body: some View {
        Group {
            if isScanning {
                scanningView
            } else if let result = scanResult {
                resultsView(result)
            } else {
                initialView
            }
        }
        .sheet(isPresented: $showSummarySheet) {
            if let result = scanResult {
                ScanSummarySheet(
                    result: result,
                    isPresented: $showSummarySheet,
                    onCleanNow: {
                        // Switch to clean tab would be handled by parent
                    },
                    onReview: {
                        showSummarySheet = false
                    }
                )
            }
        }
    }

    // MARK: - Initial View

    private var initialView: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Spacer()

            // Icon
            Image(systemName: "sparkles")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [DesignTokens.Colors.accent, DesignTokens.Colors.info],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Title and description
            VStack(spacing: DesignTokens.Spacing.xxs) {
                Text("Smart Scan")
                    .font(DesignTokens.Typography.h2)

                Text("Run a comprehensive scan of your disk, apps, and system")
                    .font(DesignTokens.Typography.subhead)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }

            // Scan stages preview
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                scanStagePreviewRow("Analyze disk usage", icon: "externaldrive.fill")
                scanStagePreviewRow("Check app health", icon: "app.badge")
                scanStagePreviewRow("Find cache & temp files", icon: "archivebox")
                scanStagePreviewRow("Detect hidden space", icon: "eye.slash")
            }
            .padding(DesignTokens.Spacing.md)
            .background(DesignTokens.Colors.backgroundSecondary)
            .cornerRadius(DesignTokens.CornerRadius.large)

            // Start button
            Button {
                Task { await startScan() }
            } label: {
                Label("Start Scan", systemImage: "play.fill")
                    .font(DesignTokens.Typography.bodyEmphasized)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
        }
        .padding(DesignTokens.Spacing.lg)
    }

    private func scanStagePreviewRow(_ text: String, icon: String) -> some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: icon)
                .foregroundColor(DesignTokens.Colors.accent)
                .frame(width: 24)

            Text(text)
                .font(DesignTokens.Typography.body)

            Spacer()
        }
    }

    // MARK: - Scanning View

    private var scanningView: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Spacer()

            // Progress indicators (both circular and linear)
            HStack(spacing: DesignTokens.Spacing.xl) {
                // Circular progress
                circularProgress

                // Linear progress and stage info
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    // Stage name
                    HStack(spacing: DesignTokens.Spacing.xxs) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text(currentStage.rawValue)
                            .font(DesignTokens.Typography.bodyEmphasized)
                    }

                    // Rapidly changing subtext
                    Text(stageSubtext)
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                        .lineLimit(1)
                        .animation(.none, value: stageSubtext)

                    // Linear progress bar
                    ProgressView(value: scanProgress)
                        .progressViewStyle(.linear)
                        .frame(width: 200)
                }
            }

            // Stage indicators (numbered circles)
            stageIndicators

            // Cancel button (always visible)
            Button("Cancel") {
                Task { await cancelScan() }
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Cancel scan")
            .accessibilityHint("Stops the scan and closes without saving results")

            Spacer()
        }
        .padding(DesignTokens.Spacing.lg)
    }

    private var circularProgress: some View {
        ZStack {
            Circle()
                .stroke(DesignTokens.Colors.separator.opacity(0.3), lineWidth: 8)
                .frame(width: 100, height: 100)

            Circle()
                .trim(from: 0, to: scanProgress)
                .stroke(
                    LinearGradient(
                        colors: [DesignTokens.Colors.accent, DesignTokens.Colors.info],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .frame(width: 100, height: 100)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: DesignTokens.AnimationDuration.fast), value: scanProgress)

            VStack(spacing: 2) {
                Text("\(Int(scanProgress * 100))%")
                    .font(DesignTokens.Typography.h3)
                    .monospacedDigit()
                Text("Complete")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
        }
    }

    private var stageIndicators: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            ForEach(Array(stages.enumerated()), id: \.element) { index, stage in
                VStack(spacing: DesignTokens.Spacing.xxxs) {
                    // Numbered circle
                    ZStack {
                        Circle()
                            .fill(stageCircleColor(for: stage))
                            .frame(width: 32, height: 32)

                        Text("\(index + 1)")
                            .font(DesignTokens.Typography.subheadEmphasized)
                            .foregroundColor(.white)
                    }

                    // Stage name
                    Text(stage.rawValue)
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(stageTextColor(for: stage))
                        .lineLimit(1)
                }
            }
        }
    }

    private func stageCircleColor(for stage: ScanStage) -> Color {
        if isStageComplete(stage) {
            return DesignTokens.Colors.success
        } else if currentStage == stage {
            return DesignTokens.Colors.accent
        } else {
            return DesignTokens.Colors.separator.opacity(0.5)
        }
    }

    private func stageTextColor(for stage: ScanStage) -> Color {
        if isStageComplete(stage) || currentStage == stage {
            return DesignTokens.Colors.textPrimary
        } else {
            return DesignTokens.Colors.textTertiary
        }
    }

    private func isStageComplete(_ stage: ScanStage) -> Bool {
        guard let currentIndex = stages.firstIndex(where: { $0 == currentStage }) else { return false }
        if let stageIndex = stages.firstIndex(where: { $0 == stage }) {
            return stageIndex < currentIndex
        }
        return false
    }

    // MARK: - Results View

    private func resultsView(_ result: SmartScanResult) -> some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.md) {
                // Summary cards
                HStack(spacing: DesignTokens.Spacing.md) {
                    // Space to reclaim card
                    resultCard(
                        icon: "arrow.down.circle.fill",
                        iconColor: DesignTokens.Colors.success,
                        title: "Space to Reclaim",
                        value: result.formattedTotalSpace,
                        subtitle: "can be safely removed"
                    )

                    // Health score card
                    resultCard(
                        icon: "heart.fill",
                        iconColor: result.healthScoreColor,
                        title: "System Health",
                        value: "\(result.systemHealthScore)/100",
                        subtitle: healthScoreMessage(result.systemHealthScore)
                    )
                }

                // Recommendations preview
                if !result.recommendations.isEmpty {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        Text("Recommendations")
                            .font(DesignTokens.Typography.bodyEmphasized)
                            .padding(.horizontal, DesignTokens.Spacing.sm)

                        ForEach(result.recommendations.prefix(3)) { rec in
                            recommendationPreviewRow(rec)
                        }

                        if result.recommendations.count > 3 {
                            Text("+ \(result.recommendations.count - 3) more")
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                                .padding(.horizontal, DesignTokens.Spacing.sm)
                        }
                    }
                    .padding(DesignTokens.Spacing.sm)
                    .background(DesignTokens.Colors.backgroundSecondary)
                    .cornerRadius(DesignTokens.CornerRadius.large)
                }

                // Action buttons
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Button("Clean Now") {
                        // Action handled by parent
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("Clean now")
                    .accessibilityHint("Proceeds with cleanup immediately")

                    Button("Review Details") {
                        showSummarySheet = true
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Review details")
                    .accessibilityHint("Shows detailed list of items to be cleaned")

                    Spacer()

                    Button("Scan Again") {
                        Task { await startScan() }
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Scan again")
                    .accessibilityHint("Starts a new scan")
                }
            }
            .padding(DesignTokens.Spacing.md)
        }
    }

    private func resultCard(icon: String, iconColor: Color, title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            HStack(spacing: DesignTokens.Spacing.xxs) {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                Text(title)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }

            Text(value)
                .font(DesignTokens.Typography.h2)
                .monospacedDigit()

            Text(subtitle)
                .font(DesignTokens.Typography.caption)
                .foregroundColor(DesignTokens.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignTokens.Spacing.md)
        .background(DesignTokens.Colors.backgroundSecondary)
        .cornerRadius(DesignTokens.CornerRadius.large)
    }

    private func recommendationPreviewRow(_ rec: ScanRecommendation) -> some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: rec.icon)
                .foregroundColor(rec.color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(rec.title)
                    .font(DesignTokens.Typography.subhead)
                Text(rec.formattedSpace)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }

            Spacer()

            if rec.safeToFix {
                Image(systemName: "checkmark.shield.fill")
                    .font(.caption)
                    .foregroundColor(DesignTokens.Colors.success)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.xxs)
    }

    private func healthScoreMessage(_ score: Int) -> String {
        switch score {
        case 90...100: return "Excellent!"
        case 75..<90: return "Good"
        case 50..<75: return "Fair"
        default: return "Needs attention"
        }
    }

    // MARK: - Actions

    private func startScan() async {
        isScanning = true
        scanResult = nil
        scanProgress = 0

        // Simulate rapid subtext updates
        let subtexts = [
            "Initializing scan components...",
            "Checking disk permissions...",
            "Scanning user cache directories...",
            "Analyzing application caches...",
            "Checking browser data...",
            "Scanning log files...",
            "Analyzing temporary files...",
            "Checking installed applications...",
            "Scanning app support directories...",
            "Looking for unused apps...",
            "Analyzing system caches...",
            "Checking hidden directories...",
            "Scanning development artifacts...",
            "Calculating space usage...",
            "Finalizing scan results..."
        ]

        var subtextIndex = 0

        for stage in stages {
            currentStage = stage

            // Update subtext rapidly during each stage
            let stageSteps = 5
            for step in 0..<stageSteps {
                stageSubtext = subtexts[subtextIndex % subtexts.count]
                subtextIndex += 1

                let progress = await scanner.runStage(stage)
                let stepProgress = Double(step + 1) / Double(stageSteps)
                scanProgress = progress * stepProgress

                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms for UI update
            }
        }

        currentStage = .complete
        scanProgress = 1.0

        let result = await scanner.finalizeScan()
        scanResult = result
        isScanning = false

        // Show summary sheet
        showSummarySheet = true
    }

    private func cancelScan() async {
        isScanning = false
        currentStage = .preparing
        scanProgress = 0
        stageSubtext = "Scan cancelled"
        scanResult = nil
    }
}

// MARK: - Scan Summary Sheet

struct ScanSummarySheet: View {
    let result: SmartScanResult
    @Binding var isPresented: Bool
    let onCleanNow: () -> Void
    let onReview: () -> Void

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            // Header
            HStack {
                Text("Scan Complete")
                    .font(DesignTokens.Typography.h3)
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
                .buttonStyle(.plain)
            }

            // Summary
            VStack(spacing: DesignTokens.Spacing.sm) {
                HStack {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
                        Text("Space to Reclaim")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                        Text(result.formattedTotalSpace)
                            .font(DesignTokens.Typography.h2)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: DesignTokens.Spacing.xxxs) {
                        Text("Issues Found")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                        Text("\(result.recommendations.count)")
                            .font(DesignTokens.Typography.h2)
                    }
                }
                .padding(DesignTokens.Spacing.md)
                .background(DesignTokens.Colors.backgroundSecondary)
                .cornerRadius(DesignTokens.CornerRadius.medium)

                Text("Scan completed in \(result.formattedDuration)")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }

            Spacer()

            // Action buttons
            HStack(spacing: DesignTokens.Spacing.sm) {
                Button("Review") {
                    onReview()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Review details")
                .accessibilityHint("Shows detailed list of items to be cleaned")

                Button("Clean Now") {
                    onCleanNow()
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Clean now")
                .accessibilityHint("Proceeds with cleanup immediately")
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .frame(width: 400, height: 300)
    }
}

// MARK: - Clean Tab View

struct CleanTabView: View {
    @State private var deepCleanEngine = DeepCleanEngine.shared
    @State private var collectorBin = CollectorBin.shared
    @State private var scanResults: [DeepCleanResult] = []
    @State private var selectedCategories: Set<DeepCleanCategory> = []
    @State private var expandedCategories: Set<DeepCleanCategory> = []
    @State private var isScanning = false
    @State private var isCleaning = false
    @State private var showConfirmation = false

    private var totalReclaimSize: Int64 {
        scanResults
            .filter { selectedCategories.contains($0.category) }
            .reduce(0) { $0 + $1.totalSize }
    }

    private var formattedTotalReclaim: String {
        ByteCountFormatter.string(fromByteCount: totalReclaimSize, countStyle: .file)
    }

    var body: some View {
        VStack(spacing: 0) {
            if isScanning {
                scanningView
            } else if scanResults.isEmpty {
                initialView
            } else {
                resultsView
            }

            // Total reclaim footer (always visible when results exist)
            if !scanResults.isEmpty && !isScanning {
                totalReclaimFooter
            }
        }
        .alert("Confirm Cleanup", isPresented: $showConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clean", role: .destructive) {
                Task { await performClean() }
            }
        } message: {
            Text("This will permanently delete \(formattedTotalReclaim) of data from \(selectedCategories.count) categories. Items will be moved to the Collector Bin first.")
        }
    }

    // MARK: - Initial View

    private var initialView: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Spacer()

            Image(systemName: "trash")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [DesignTokens.Colors.warning, DesignTokens.Colors.error],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: DesignTokens.Spacing.xxs) {
                Text("Deep Clean")
                    .font(DesignTokens.Typography.h2)

                Text("Scan for and remove unnecessary files to free up disk space")
                    .font(DesignTokens.Typography.subhead)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }

            // Category preview
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text("Categories")
                    .font(DesignTokens.Typography.captionEmphasized)
                    .foregroundColor(DesignTokens.Colors.textSecondary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DesignTokens.Spacing.xxs) {
                    ForEach(DeepCleanCategory.allCases) { category in
                        HStack(spacing: DesignTokens.Spacing.xxs) {
                            Image(systemName: category.icon)
                                .foregroundColor(DesignTokens.Colors.accent)
                                .frame(width: 16)
                            Text(category.rawValue)
                                .font(DesignTokens.Typography.caption)
                            Spacer()
                        }
                    }
                }
            }
            .padding(DesignTokens.Spacing.md)
            .background(DesignTokens.Colors.backgroundSecondary)
            .cornerRadius(DesignTokens.CornerRadius.large)

            Button {
                Task { await scanCategories() }
            } label: {
                Label("Scan for Junk", systemImage: "magnifyingglass")
                    .font(DesignTokens.Typography.bodyEmphasized)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
        }
        .padding(DesignTokens.Spacing.lg)
    }

    // MARK: - Scanning View

    private var scanningView: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)

            VStack(spacing: DesignTokens.Spacing.xxs) {
                Text("Scanning...")
                    .font(DesignTokens.Typography.bodyEmphasized)

                if let category = deepCleanEngine.currentScanningCategory {
                    Text(category)
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
            }

            Spacer()
        }
    }

    // MARK: - Results View

    private var resultsView: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.sm) {
                // Selection controls
                HStack {
                    Button("Select All") {
                        selectedCategories = Set(scanResults.map { $0.category })
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityLabel("Select all categories")
                    .accessibilityHint("Selects all cleanup categories")

                    Button("Deselect All") {
                        selectedCategories.removeAll()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityLabel("Deselect all categories")
                    .accessibilityHint("Deselects all cleanup categories")

                    Spacer()

                    Button {
                        Task { await scanCategories() }
                    } label: {
                        Label("Rescan", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.horizontal, DesignTokens.Spacing.sm)

                // Category list using PreferenceList pattern
                PreferenceList {
                    ForEach(groupedResults, id: \.key) { group, results in
                        PreferenceSection(header: group) {
                            ForEach(results) { result in
                                cleanCategoryRow(result)
                            }
                        }
                    }
                }
            }
            .padding(DesignTokens.Spacing.md)
        }
    }

    private var groupedResults: [(key: String, value: [DeepCleanResult])] {
        let systemCategories: [DeepCleanCategory] = [.systemCache, .userCache, .logFiles, .tempFiles]
        let appCategories: [DeepCleanCategory] = [.browserCache, .downloads, .trash]
        let devCategories: [DeepCleanCategory] = [.development, .docker, .xcode]

        var groups: [(key: String, value: [DeepCleanResult])] = []

        let system = scanResults.filter { systemCategories.contains($0.category) }
        if !system.isEmpty {
            groups.append(("System", system))
        }

        let apps = scanResults.filter { appCategories.contains($0.category) }
        if !apps.isEmpty {
            groups.append(("Applications", apps))
        }

        let dev = scanResults.filter { devCategories.contains($0.category) }
        if !dev.isEmpty {
            groups.append(("Development", dev))
        }

        return groups
    }

    @ViewBuilder
    private func cleanCategoryRow(_ result: DeepCleanResult) -> some View {
        let isSelected = selectedCategories.contains(result.category)
        let isExpanded = expandedCategories.contains(result.category)

        VStack(spacing: 0) {
            // Main row
            HStack(spacing: DesignTokens.Spacing.sm) {
                // Checkbox
                Button {
                    toggleSelection(result.category)
                } label: {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? DesignTokens.Colors.accent : DesignTokens.Colors.textSecondary)
                }
                .buttonStyle(.plain)

                // Icon
                Image(systemName: result.category.icon)
                    .foregroundColor(DesignTokens.Colors.accent)
                    .frame(width: 24)

                // Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.category.rawValue)
                        .font(DesignTokens.Typography.body)

                    Text(result.category.description)
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }

                Spacer()

                // Size and expand button
                VStack(alignment: .trailing, spacing: 2) {
                    Text(result.formattedSize)
                        .font(DesignTokens.Typography.monoSubhead)
                        .foregroundColor(result.totalSize > 0 ? DesignTokens.Colors.textPrimary : DesignTokens.Colors.textTertiary)

                    Text("\(result.itemCount) items")
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }

                // Expand/collapse button
                if !result.paths.isEmpty {
                    Button {
                        toggleExpansion(result.category)
                    } label: {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, DesignTokens.Spacing.sm)
            .padding(.horizontal, DesignTokens.Spacing.md)
            .background(isSelected ? DesignTokens.Colors.accent.opacity(0.1) : Color.clear)
            .contentShape(Rectangle())
            .onTapGesture {
                toggleSelection(result.category)
            }

            // Expanded file list
            if isExpanded {
                expandedFileList(result)
            }

            Divider()
                .padding(.leading, DesignTokens.Spacing.md + 24 + DesignTokens.Spacing.sm)
        }
    }

    private func expandedFileList(_ result: DeepCleanResult) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(result.paths.prefix(10).enumerated()), id: \.offset) { _, path in
                HStack(spacing: DesignTokens.Spacing.xxs) {
                    Image(systemName: "doc")
                        .font(.caption)
                        .foregroundColor(DesignTokens.Colors.textTertiary)

                    Text(shortenPath(path))
                        .font(DesignTokens.Typography.monoCaption)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()
                }
                .padding(.vertical, DesignTokens.Spacing.xxxs)
                .padding(.horizontal, DesignTokens.Spacing.xl)
            }

            if result.paths.count > 10 {
                Text("+ \(result.paths.count - 10) more files")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                    .padding(.horizontal, DesignTokens.Spacing.xl)
                    .padding(.vertical, DesignTokens.Spacing.xxxs)
            }
        }
        .padding(.bottom, DesignTokens.Spacing.sm)
        .background(DesignTokens.Colors.backgroundTertiary.opacity(0.5))
    }

    private func shortenPath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    // MARK: - Total Reclaim Footer

    private var totalReclaimFooter: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Total to Clean")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                Text(formattedTotalReclaim)
                    .font(DesignTokens.Typography.h3)
                    .monospacedDigit()
            }

            Spacer()

            Button {
                showConfirmation = true
            } label: {
                Label("Clean Selected", systemImage: "trash")
                    .font(DesignTokens.Typography.bodyEmphasized)
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedCategories.isEmpty || isCleaning)
        }
        .padding(DesignTokens.Spacing.md)
        .background(DesignTokens.Colors.backgroundSecondary)
    }

    // MARK: - Actions

    private func toggleSelection(_ category: DeepCleanCategory) {
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }
    }

    private func toggleExpansion(_ category: DeepCleanCategory) {
        withAnimation(DesignTokens.Animation.fast) {
            if expandedCategories.contains(category) {
                expandedCategories.remove(category)
            } else {
                expandedCategories.insert(category)
            }
        }
    }

    private func scanCategories() async {
        isScanning = true
        scanResults = []
        selectedCategories = []
        expandedCategories = []

        scanResults = await deepCleanEngine.scanAllCategories()

        // Auto-select categories with items
        selectedCategories = Set(scanResults.filter { $0.totalSize > 0 }.map { $0.category })

        isScanning = false
    }

    private func performClean() async {
        isCleaning = true

        // Add to collector bin first
        let pathsToClean = scanResults
            .filter { selectedCategories.contains($0.category) }
            .flatMap { $0.paths }

        // Add to Collector Bin for safety
        let _ = await collectorBin.addToBin(atPaths: pathsToClean)

        // Perform actual cleaning
        let categoriesToClean = Array(selectedCategories)
        let _ = await deepCleanEngine.cleanCategories(categoriesToClean)

        // Rescan to update results
        await scanCategories()

        isCleaning = false
    }
}

// MARK: - Preview

#Preview("Maintenance View") {
    MaintenanceView()
        .frame(width: 800, height: 600)
}

#Preview("Scan Tab") {
    ScanTabView()
        .frame(width: 700, height: 500)
}

#Preview("Clean Tab") {
    CleanTabView()
        .frame(width: 700, height: 500)
}
