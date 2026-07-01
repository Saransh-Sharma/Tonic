//
//  SmartScanManager.swift
//  Tonic
//
//  Smart Scan state manager. Extracted from the legacy DashboardSupport.swift view
//  file so it survives the presentation-layer rewrite. Owns scan lifecycle, progress,
//  health score, and the derived recommendation list consumed by Home and Clean.
//

import SwiftUI

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
