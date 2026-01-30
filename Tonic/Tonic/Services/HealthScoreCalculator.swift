//
//  HealthScoreCalculator.swift
//  Tonic
//
//  Comprehensive health scoring algorithm for system analysis
//  Calculates 0-100 health score based on multiple system factors
//

import Foundation
import OSLog

// MARK: - Health Score Calculator

final class HealthScoreCalculator {
    private let logger = Logger(subsystem: "com.tonic.app", category: "HealthScoreCalculator")

    // Score weightings (total 100 points available)
    private let diskUsageWeight = 30
    private let cacheWeight = 25
    private let junkFilesWeight = 20
    private let appIssuesWeight = 15
    private let orphanedFilesWeight = 10
    private let privacyWeight = 5

    func calculateScore(
        diskUsage: DiskUsageSummary?,
        junkFiles: JunkCategory,
        performanceIssues: PerformanceCategory,
        appIssues: AppIssueCategory,
        privacyIssues: PrivacyCategory
    ) -> Int {
        var score = 100

        // Deduct for disk usage (0-30 points)
        let diskPenalty = calculateDiskPenalty(diskUsage: diskUsage)
        score -= diskPenalty

        // Deduct for cache size (0-25 points)
        let cachePenalty = calculateCachePenalty(performanceIssues: performanceIssues)
        score -= cachePenalty

        // Deduct for junk files (0-20 points)
        let junkPenalty = calculateJunkPenalty(junkFiles: junkFiles)
        score -= junkPenalty

        // Deduct for app issues (0-15 points)
        let appPenalty = calculateAppPenalty(appIssues: appIssues)
        score -= appPenalty

        // Deduct for orphaned files (0-10 points)
        let orphanedPenalty = calculateOrphanedPenalty(appIssues: appIssues)
        score -= orphanedPenalty

        // Deduct for privacy issues (0-5 points)
        let privacyPenalty = calculatePrivacyPenalty(privacyIssues: privacyIssues)
        score -= privacyPenalty

        logger.info(
            "Health score calculated: \(max(score, 0))/100 (disk: -\(diskPenalty), cache: -\(cachePenalty), junk: -\(junkPenalty), app: -\(appPenalty), orphaned: -\(orphanedPenalty), privacy: -\(privacyPenalty))"
        )

        return max(score, 0)
    }

    // MARK: - Penalty Calculations

    private func calculateDiskPenalty(diskUsage: DiskUsageSummary?) -> Int {
        guard let usage = diskUsage else { return 5 }

        let usedPercent = usage.usedPercentage

        // Tiered penalty based on disk usage percentage
        switch usedPercent {
        case 0...50:
            return 0 // Excellent
        case 50...70:
            return 5 // Good
        case 70...80:
            return 10 // Fair
        case 80...90:
            return 20 // Poor
        case 90...95:
            return 25 // Critical
        default:
            return 30 // Extremely Critical
        }
    }

    private func calculateCachePenalty(performanceIssues: PerformanceCategory) -> Int {
        let cacheSize = performanceIssues.browserCaches.size

        // Penalty increases with cache size
        switch cacheSize {
        case 0..<(1024 * 1024 * 1024): // < 1GB
            return 0
        case (1024 * 1024 * 1024)..<(2 * 1024 * 1024 * 1024): // 1-2GB
            return 5
        case (2 * 1024 * 1024 * 1024)..<(5 * 1024 * 1024 * 1024): // 2-5GB
            return 10
        case (5 * 1024 * 1024 * 1024)..<(10 * 1024 * 1024 * 1024): // 5-10GB
            return 15
        default: // > 10GB
            return 25
        }
    }

    private func calculateJunkPenalty(junkFiles: JunkCategory) -> Int {
        let totalJunkSize = junkFiles.totalSize
        let totalJunkCount = junkFiles.totalFiles

        // Factor in both size and count
        let sizePenalty: Int
        switch totalJunkSize {
        case 0..<(500 * 1024 * 1024): // < 500MB
            sizePenalty = 0
        case (500 * 1024 * 1024)..<(1024 * 1024 * 1024): // 500MB-1GB
            sizePenalty = 3
        case (1024 * 1024 * 1024)..<(5 * 1024 * 1024 * 1024): // 1-5GB
            sizePenalty = 8
        case (5 * 1024 * 1024 * 1024)..<(10 * 1024 * 1024 * 1024): // 5-10GB
            sizePenalty = 15
        default: // > 10GB
            sizePenalty = 20
        }

        // Count penalty (many small files can also degrade performance)
        let countPenalty = min(totalJunkCount / 1000, 5)

        return min(sizePenalty + countPenalty, junkFilesWeight)
    }

    private func calculateAppPenalty(appIssues: AppIssueCategory) -> Int {
        var penalty = 0

        // Penalty for unused apps
        let unusedAppPenalty = min(appIssues.unusedApps.count * 2, 5)
        penalty += unusedAppPenalty

        // Penalty for large apps
        let largeAppPenalty = min(appIssues.largeApps.count, 5)
        penalty += largeAppPenalty

        // Penalty for duplicate apps
        let duplicatePenalty = min(appIssues.duplicateApps.count * 3, 5)
        penalty += duplicatePenalty

        return min(penalty, appIssuesWeight)
    }

    private func calculateOrphanedPenalty(appIssues: AppIssueCategory) -> Int {
        let orphanedCount = appIssues.orphanedFiles.count
        let orphanedSize = appIssues.orphanedFiles.reduce(0) { $0 + $1.size }

        // Penalty increases with number and size of orphaned files
        let countPenalty = min(orphanedCount / 5, 5)
        let sizePenalty: Int
        switch orphanedSize {
        case 0..<(100 * 1024 * 1024): // < 100MB
            sizePenalty = 0
        case (100 * 1024 * 1024)..<(500 * 1024 * 1024): // 100-500MB
            sizePenalty = 2
        case (500 * 1024 * 1024)..<(1024 * 1024 * 1024): // 500MB-1GB
            sizePenalty = 4
        default: // > 1GB
            sizePenalty = 5
        }

        return min(countPenalty + sizePenalty, orphanedFilesWeight)
    }

    private func calculatePrivacyPenalty(privacyIssues: PrivacyCategory) -> Int {
        let browserHistorySize = privacyIssues.browserHistory.size
        let downloadHistorySize = privacyIssues.downloadHistory.size

        // Privacy penalty based on sensitive data presence
        var penalty = 0

        if browserHistorySize > 100 * 1024 * 1024 {
            penalty += 2
        }

        if downloadHistorySize > 1024 * 1024 * 1024 {
            penalty += 2
        }

        return min(penalty, privacyWeight)
    }

    // MARK: - Helper Methods

    func scoreToRating(_ score: Int) -> ScanResult.HealthRating {
        switch score {
        case 90...100:
            return .excellent
        case 75..<90:
            return .good
        case 50..<75:
            return .fair
        case 25..<50:
            return .poor
        default:
            return .critical
        }
    }

    func ratingDescription(_ rating: ScanResult.HealthRating) -> String {
        switch rating {
        case .excellent:
            return "Your system is in excellent health"
        case .good:
            return "Your system is in good condition"
        case .fair:
            return "Your system could use some optimization"
        case .poor:
            return "Your system needs attention"
        case .critical:
            return "Your system requires immediate attention"
        }
    }
}
