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

    struct SystemHealthMetrics {
        let cpuUsagePercent: Double
        let memoryUsedPercent: Double
        let memoryPressure: MemoryPressure
        let diskUsedPercent: Double?
        let cpuTemperatureCelsius: Double?
        let diskReadMBps: Double
        let diskWriteMBps: Double
    }

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

    // MARK: - System Health Score (Mole parity)

    func calculateSystemScore(metrics: SystemHealthMetrics) -> (score: Int, message: String) {
        let cpuNormalThreshold = 30.0
        let cpuHighThreshold = 70.0
        let memNormalThreshold = 50.0
        let memHighThreshold = 80.0
        let memPressureWarnPenalty = 5.0
        let memPressureCritPenalty = 15.0
        let diskWarnThreshold = 70.0
        let diskCritThreshold = 90.0
        let thermalNormalThreshold = 60.0
        let thermalHighThreshold = 85.0
        let ioNormalThreshold = 50.0
        let ioHighThreshold = 150.0

        let healthCPUWeight = 30.0
        let healthMemWeight = 25.0
        let healthDiskWeight = 20.0
        let healthThermalWeight = 15.0
        let healthIOWeight = 10.0

        var score = 100.0
        var issues: [String] = []

        // CPU penalty
        if metrics.cpuUsagePercent > cpuNormalThreshold {
            let cpuPenalty: Double
            if metrics.cpuUsagePercent > cpuHighThreshold {
                cpuPenalty = healthCPUWeight * (metrics.cpuUsagePercent - cpuNormalThreshold) / cpuHighThreshold
            } else {
                cpuPenalty = (healthCPUWeight / 2) * (metrics.cpuUsagePercent - cpuNormalThreshold) / (cpuHighThreshold - cpuNormalThreshold)
            }
            score -= cpuPenalty
            if metrics.cpuUsagePercent > cpuHighThreshold {
                issues.append("High CPU")
            }
        }

        // Memory penalty
        if metrics.memoryUsedPercent > memNormalThreshold {
            let memPenalty: Double
            if metrics.memoryUsedPercent > memHighThreshold {
                memPenalty = healthMemWeight * (metrics.memoryUsedPercent - memNormalThreshold) / memNormalThreshold
            } else {
                memPenalty = (healthMemWeight / 2) * (metrics.memoryUsedPercent - memNormalThreshold) / (memHighThreshold - memNormalThreshold)
            }
            score -= memPenalty
            if metrics.memoryUsedPercent > memHighThreshold {
                issues.append("High Memory")
            }
        }

        // Memory pressure penalty
        switch metrics.memoryPressure {
        case .warning:
            score -= memPressureWarnPenalty
            issues.append("Memory Pressure")
        case .critical:
            score -= memPressureCritPenalty
            issues.append("Critical Memory")
        case .normal:
            break
        }

        // Disk penalty
        if let diskUsage = metrics.diskUsedPercent, diskUsage > diskWarnThreshold {
            let diskPenalty: Double
            if diskUsage > diskCritThreshold {
                diskPenalty = healthDiskWeight * (diskUsage - diskWarnThreshold) / (100 - diskWarnThreshold)
            } else {
                diskPenalty = (healthDiskWeight / 2) * (diskUsage - diskWarnThreshold) / (diskCritThreshold - diskWarnThreshold)
            }
            score -= diskPenalty
            if diskUsage > diskCritThreshold {
                issues.append("Disk Almost Full")
            }
        }

        // Thermal penalty
        if let cpuTemp = metrics.cpuTemperatureCelsius, cpuTemp > thermalNormalThreshold {
            if cpuTemp > thermalHighThreshold {
                score -= healthThermalWeight
                issues.append("Overheating")
            } else {
                let thermalPenalty = healthThermalWeight * (cpuTemp - thermalNormalThreshold) / (thermalHighThreshold - thermalNormalThreshold)
                score -= thermalPenalty
            }
        }

        // Disk IO penalty (MB/s)
        let totalIO = metrics.diskReadMBps + metrics.diskWriteMBps
        if totalIO > ioNormalThreshold {
            let ioPenalty: Double
            if totalIO > ioHighThreshold {
                ioPenalty = healthIOWeight
                issues.append("Heavy Disk IO")
            } else {
                ioPenalty = healthIOWeight * (totalIO - ioNormalThreshold) / (ioHighThreshold - ioNormalThreshold)
            }
            score -= ioPenalty
        }

        score = max(0, min(100, score))

        let rating: String
        switch score {
        case 90...:
            rating = "Excellent"
        case 75..<90:
            rating = "Good"
        case 60..<75:
            rating = "Fair"
        case 40..<60:
            rating = "Poor"
        default:
            rating = "Critical"
        }

        let message = issues.isEmpty ? rating : "\(rating): \(issues.joined(separator: ", "))"
        logger.info("System health score calculated: \(Int(score))/100 (\(message))")

        return (Int(score), message)
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
