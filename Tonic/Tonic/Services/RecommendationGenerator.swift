//
//  RecommendationGenerator.swift
//  Tonic
//
//  Generates actionable recommendations from scan results
//  Prioritizes by importance and potential space savings
//

import Foundation
import OSLog

// MARK: - Recommendation Generator

final class RecommendationGenerator {
    private let logger = Logger(subsystem: "com.tonic.app", category: "RecommendationGenerator")
    private let scoreCalculator = HealthScoreCalculator()

    func generateRecommendations(from scanResult: ScanResult) -> [ScanRecommendation] {
        var recommendations: [ScanRecommendation] = []

        let basePenalties = scoreCalculator.penaltyBreakdown(
            diskUsage: nil,
            junkFiles: scanResult.junkFiles,
            performanceIssues: scanResult.performanceIssues,
            appIssues: scanResult.appIssues
        )

        // Generate recommendations for each category
        recommendations.append(contentsOf: generateJunkRecommendations(from: scanResult, basePenalties: basePenalties))
        recommendations.append(contentsOf: generatePerformanceRecommendations(from: scanResult, basePenalties: basePenalties))
        recommendations.append(contentsOf: generateAppRecommendations(from: scanResult, basePenalties: basePenalties))

        // Sort by priority (size saved, then safety)
        recommendations.sort { rec1, rec2 in
            let size1 = rec1.spaceToReclaim
            let size2 = rec2.spaceToReclaim
            if size1 == size2 {
                return rec1.safeToFix && !rec2.safeToFix
            }
            return size1 > size2
        }

        logger.info("Generated \(recommendations.count) recommendations from scan")
        return recommendations
    }

    // MARK: - Junk Recommendations

    private func generateJunkRecommendations(
        from scanResult: ScanResult,
        basePenalties: HealthScoreCalculator.ScorePenaltyBreakdown
    ) -> [ScanRecommendation] {
        var recommendations: [ScanRecommendation] = []
        let junkFiles = scanResult.junkFiles

        // Temporary files
        if junkFiles.tempFiles.size > 50 * 1024 * 1024 {
            let updated = JunkCategory(
                tempFiles: FileGroup(name: junkFiles.tempFiles.name, description: junkFiles.tempFiles.description),
                cacheFiles: junkFiles.cacheFiles,
                logFiles: junkFiles.logFiles,
                trashItems: junkFiles.trashItems,
                languageFiles: junkFiles.languageFiles,
                oldFiles: junkFiles.oldFiles
            )
            let impact = junkScoreImpact(
                basePenalties: basePenalties,
                updatedJunk: updated,
                scanResult: scanResult
            )
            let rec = ScanRecommendation(
                type: .tempFiles,
                title: "Clear Temporary Files",
                description: "Remove \(formatFileCount(junkFiles.tempFiles.count)) temporary files (\(formatSize(junkFiles.tempFiles.size))). These are safe to delete.",
                actionable: true,
                safeToFix: true,
                spaceToReclaim: junkFiles.tempFiles.size,
                affectedPaths: junkFiles.tempFiles.paths,
                scoreImpact: impact
            )
            recommendations.append(rec)
        }

        // Cache files
        if junkFiles.cacheFiles.size > 100 * 1024 * 1024 {
            let updated = JunkCategory(
                tempFiles: junkFiles.tempFiles,
                cacheFiles: FileGroup(name: junkFiles.cacheFiles.name, description: junkFiles.cacheFiles.description),
                logFiles: junkFiles.logFiles,
                trashItems: junkFiles.trashItems,
                languageFiles: junkFiles.languageFiles,
                oldFiles: junkFiles.oldFiles
            )
            let impact = junkScoreImpact(
                basePenalties: basePenalties,
                updatedJunk: updated,
                scanResult: scanResult
            )
            let rec = ScanRecommendation(
                type: .cache,
                title: "Clear Application Caches",
                description: "Remove \(formatFileCount(junkFiles.cacheFiles.count)) cache files (\(formatSize(junkFiles.cacheFiles.size))). Apps will rebuild cache as needed.",
                actionable: true,
                safeToFix: true,
                spaceToReclaim: junkFiles.cacheFiles.size,
                affectedPaths: junkFiles.cacheFiles.paths,
                scoreImpact: impact
            )
            recommendations.append(rec)
        }

        // Log files
        if junkFiles.logFiles.size > 50 * 1024 * 1024 {
            let updated = JunkCategory(
                tempFiles: junkFiles.tempFiles,
                cacheFiles: junkFiles.cacheFiles,
                logFiles: FileGroup(name: junkFiles.logFiles.name, description: junkFiles.logFiles.description),
                trashItems: junkFiles.trashItems,
                languageFiles: junkFiles.languageFiles,
                oldFiles: junkFiles.oldFiles
            )
            let impact = junkScoreImpact(
                basePenalties: basePenalties,
                updatedJunk: updated,
                scanResult: scanResult
            )
            let rec = ScanRecommendation(
                type: .logs,
                title: "Clear Old Log Files",
                description: "Remove \(formatFileCount(junkFiles.logFiles.count)) log files (\(formatSize(junkFiles.logFiles.size))). Old logs are safe to delete.",
                actionable: true,
                safeToFix: true,
                spaceToReclaim: junkFiles.logFiles.size,
                affectedPaths: junkFiles.logFiles.paths,
                scoreImpact: impact
            )
            recommendations.append(rec)
        }

        // Trash items
        if junkFiles.trashItems.size > 10 * 1024 * 1024 {
            let updated = JunkCategory(
                tempFiles: junkFiles.tempFiles,
                cacheFiles: junkFiles.cacheFiles,
                logFiles: junkFiles.logFiles,
                trashItems: FileGroup(name: junkFiles.trashItems.name, description: junkFiles.trashItems.description),
                languageFiles: junkFiles.languageFiles,
                oldFiles: junkFiles.oldFiles
            )
            let impact = junkScoreImpact(
                basePenalties: basePenalties,
                updatedJunk: updated,
                scanResult: scanResult
            )
            let rec = ScanRecommendation(
                type: .trash,
                title: "Empty Trash",
                description: "Permanently remove \(formatFileCount(junkFiles.trashItems.count)) items from Trash (\(formatSize(junkFiles.trashItems.size))).",
                actionable: true,
                safeToFix: true,
                spaceToReclaim: junkFiles.trashItems.size,
                affectedPaths: junkFiles.trashItems.paths,
                scoreImpact: impact
            )
            recommendations.append(rec)
        }

        // Language files
        if junkFiles.languageFiles.size > 50 * 1024 * 1024 {
            let updated = JunkCategory(
                tempFiles: junkFiles.tempFiles,
                cacheFiles: junkFiles.cacheFiles,
                logFiles: junkFiles.logFiles,
                trashItems: junkFiles.trashItems,
                languageFiles: FileGroup(name: junkFiles.languageFiles.name, description: junkFiles.languageFiles.description),
                oldFiles: junkFiles.oldFiles
            )
            let impact = junkScoreImpact(
                basePenalties: basePenalties,
                updatedJunk: updated,
                scanResult: scanResult
            )
            let rec = ScanRecommendation(
                type: .languageFiles,
                title: "Remove Unused Language Files",
                description: "Remove \(formatFileCount(junkFiles.languageFiles.count)) language files (\(formatSize(junkFiles.languageFiles.size))). Keep only languages you use.",
                actionable: true,
                safeToFix: false,
                spaceToReclaim: junkFiles.languageFiles.size,
                affectedPaths: junkFiles.languageFiles.paths,
                scoreImpact: impact
            )
            recommendations.append(rec)
        }

        // Old files
        if junkFiles.oldFiles.size > 100 * 1024 * 1024 {
            let updated = JunkCategory(
                tempFiles: junkFiles.tempFiles,
                cacheFiles: junkFiles.cacheFiles,
                logFiles: junkFiles.logFiles,
                trashItems: junkFiles.trashItems,
                languageFiles: junkFiles.languageFiles,
                oldFiles: FileGroup(name: junkFiles.oldFiles.name, description: junkFiles.oldFiles.description)
            )
            let impact = junkScoreImpact(
                basePenalties: basePenalties,
                updatedJunk: updated,
                scanResult: scanResult
            )
            let rec = ScanRecommendation(
                type: .oldFiles,
                title: "Remove Old Downloads",
                description: "Delete \(formatFileCount(junkFiles.oldFiles.count)) old files in Downloads folder (\(formatSize(junkFiles.oldFiles.size))).",
                actionable: true,
                safeToFix: false,
                spaceToReclaim: junkFiles.oldFiles.size,
                affectedPaths: junkFiles.oldFiles.paths,
                scoreImpact: impact
            )
            recommendations.append(rec)
        }

        return recommendations
    }

    // MARK: - Performance Recommendations

    private func generatePerformanceRecommendations(
        from scanResult: ScanResult,
        basePenalties: HealthScoreCalculator.ScorePenaltyBreakdown
    ) -> [ScanRecommendation] {
        var recommendations: [ScanRecommendation] = []
        let performanceIssues = scanResult.performanceIssues

        // Browser caches
        if performanceIssues.browserCaches.size > 500 * 1024 * 1024 {
            let updatedPerformance = PerformanceCategory(
                launchAgents: performanceIssues.launchAgents,
                loginItems: performanceIssues.loginItems,
                browserCaches: FileGroup(name: performanceIssues.browserCaches.name, description: performanceIssues.browserCaches.description),
                memoryIssues: performanceIssues.memoryIssues,
                diskFragmentation: performanceIssues.diskFragmentation
            )
            let impact = cacheScoreImpact(
                basePenalties: basePenalties,
                updatedPerformance: updatedPerformance,
                scanResult: scanResult
            )
            let rec = ScanRecommendation(
                type: .cache,
                title: "Clear Browser Caches",
                description: "Remove \(formatFileCount(performanceIssues.browserCaches.count)) browser cache files (\(formatSize(performanceIssues.browserCaches.size))). Browsers will faster.",
                actionable: true,
                safeToFix: true,
                spaceToReclaim: performanceIssues.browserCaches.size,
                affectedPaths: performanceIssues.browserCaches.paths,
                scoreImpact: impact
            )
            recommendations.append(rec)
        }

        // Launch agents
        if performanceIssues.launchAgents.count > 0 {
            let rec = ScanRecommendation(
                type: .launchAgents,
                title: "Review Launch Agents",
                description: "Found \(performanceIssues.launchAgents.count) launch agents. Review and disable unnecessary ones.",
                actionable: true,
                safeToFix: false,
                spaceToReclaim: 0,
                affectedPaths: performanceIssues.launchAgents.paths,
                scoreImpact: 0
            )
            recommendations.append(rec)
        }

        return recommendations
    }

    // MARK: - App Recommendations

    private func generateAppRecommendations(
        from scanResult: ScanResult,
        basePenalties: HealthScoreCalculator.ScorePenaltyBreakdown
    ) -> [ScanRecommendation] {
        var recommendations: [ScanRecommendation] = []
        let appIssues = scanResult.appIssues

        // Unused apps
        if !appIssues.unusedApps.isEmpty {
            let totalSize = appIssues.unusedApps.reduce(0) { $0 + $1.totalSize }
            let updatedAppIssues = AppIssueCategory(
                unusedApps: [],
                largeApps: appIssues.largeApps,
                duplicateApps: appIssues.duplicateApps,
                orphanedFiles: appIssues.orphanedFiles
            )
            let impact = appScoreImpact(
                basePenalties: basePenalties,
                updatedAppIssues: updatedAppIssues,
                scanResult: scanResult
            )
            let rec = ScanRecommendation(
                type: .oldApps,
                title: "Uninstall Unused Applications",
                description: "Found \(appIssues.unusedApps.count) unused apps (\(formatSize(totalSize))). Remove to free up space.",
                actionable: true,
                safeToFix: false,
                spaceToReclaim: totalSize,
                affectedPaths: appIssues.unusedApps.map { $0.path.path },
                scoreImpact: impact
            )
            recommendations.append(rec)
        }

        // Duplicate apps
        if !appIssues.duplicateApps.isEmpty {
            let totalSize = appIssues.duplicateApps.reduce(0) { $0 + $1.totalSize }
            let updatedAppIssues = AppIssueCategory(
                unusedApps: appIssues.unusedApps,
                largeApps: appIssues.largeApps,
                duplicateApps: [],
                orphanedFiles: appIssues.orphanedFiles
            )
            let impact = appScoreImpact(
                basePenalties: basePenalties,
                updatedAppIssues: updatedAppIssues,
                scanResult: scanResult
            )
            let rec = ScanRecommendation(
                type: .oldApps,
                title: "Remove Duplicate Applications",
                description: "Found \(appIssues.duplicateApps.count) apps with multiple versions (\(formatSize(totalSize))). Keep only the latest version.",
                actionable: true,
                safeToFix: false,
                spaceToReclaim: totalSize,
                affectedPaths: appIssues.duplicateApps.flatMap { dup in
                    dup.versions.dropFirst().map { $0.path.path }
                },
                scoreImpact: impact
            )
            recommendations.append(rec)
        }

        // Large apps
        if !appIssues.largeApps.isEmpty {
            let updatedAppIssues = AppIssueCategory(
                unusedApps: appIssues.unusedApps,
                largeApps: [],
                duplicateApps: appIssues.duplicateApps,
                orphanedFiles: appIssues.orphanedFiles
            )
            let impact = appScoreImpact(
                basePenalties: basePenalties,
                updatedAppIssues: updatedAppIssues,
                scanResult: scanResult
            )
            let rec = ScanRecommendation(
                type: .largeApps,
                title: "Review Large Applications",
                description: "Found \(appIssues.largeApps.count) very large apps. Consider if you need them all.",
                actionable: true,
                safeToFix: false,
                spaceToReclaim: 0,
                affectedPaths: appIssues.largeApps.map { $0.path.path },
                scoreImpact: impact
            )
            recommendations.append(rec)
        }

        // Orphaned files
        if !appIssues.orphanedFiles.isEmpty {
            let totalSize = appIssues.orphanedFiles.reduce(0) { $0 + $1.size }
            let updatedAppIssues = AppIssueCategory(
                unusedApps: appIssues.unusedApps,
                largeApps: appIssues.largeApps,
                duplicateApps: appIssues.duplicateApps,
                orphanedFiles: []
            )
            let impact = orphanedScoreImpact(
                basePenalties: basePenalties,
                updatedAppIssues: updatedAppIssues,
                scanResult: scanResult
            )
            let rec = ScanRecommendation(
                type: .oldApps,
                title: "Remove Orphaned Application Files",
                description: "Found \(appIssues.orphanedFiles.count) files from uninstalled apps (\(formatSize(totalSize))). Safe to remove.",
                actionable: true,
                safeToFix: true,
                spaceToReclaim: totalSize,
                affectedPaths: appIssues.orphanedFiles.map { $0.path },
                scoreImpact: impact
            )
            recommendations.append(rec)
        }

        return recommendations
    }

    // MARK: - Helper Methods

    private func formatSize(_ bytes: Int64) -> String {
        let gb = Double(bytes) / (1024 * 1024 * 1024)
        if gb >= 1 {
            return String(format: "%.1f GB", gb)
        }

        let mb = Double(bytes) / (1024 * 1024)
        if mb >= 1 {
            return String(format: "%.0f MB", mb)
        }

        let kb = Double(bytes) / 1024
        return String(format: "%.0f KB", kb)
    }

    private func formatFileCount(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1f K", Double(count) / 1000)
        }
        return "\(count)"
    }

    private func junkScoreImpact(
        basePenalties: HealthScoreCalculator.ScorePenaltyBreakdown,
        updatedJunk: JunkCategory,
        scanResult: ScanResult
    ) -> Int {
        let updated = scoreCalculator.penaltyBreakdown(
            diskUsage: nil,
            junkFiles: updatedJunk,
            performanceIssues: scanResult.performanceIssues,
            appIssues: scanResult.appIssues
        )
        return max(0, basePenalties.junk - updated.junk)
    }

    private func cacheScoreImpact(
        basePenalties: HealthScoreCalculator.ScorePenaltyBreakdown,
        updatedPerformance: PerformanceCategory,
        scanResult: ScanResult
    ) -> Int {
        let updated = scoreCalculator.penaltyBreakdown(
            diskUsage: nil,
            junkFiles: scanResult.junkFiles,
            performanceIssues: updatedPerformance,
            appIssues: scanResult.appIssues
        )
        return max(0, basePenalties.cache - updated.cache)
    }

    private func appScoreImpact(
        basePenalties: HealthScoreCalculator.ScorePenaltyBreakdown,
        updatedAppIssues: AppIssueCategory,
        scanResult: ScanResult
    ) -> Int {
        let updated = scoreCalculator.penaltyBreakdown(
            diskUsage: nil,
            junkFiles: scanResult.junkFiles,
            performanceIssues: scanResult.performanceIssues,
            appIssues: updatedAppIssues
        )
        return max(0, basePenalties.app - updated.app)
    }

    private func orphanedScoreImpact(
        basePenalties: HealthScoreCalculator.ScorePenaltyBreakdown,
        updatedAppIssues: AppIssueCategory,
        scanResult: ScanResult
    ) -> Int {
        let updated = scoreCalculator.penaltyBreakdown(
            diskUsage: nil,
            junkFiles: scanResult.junkFiles,
            performanceIssues: scanResult.performanceIssues,
            appIssues: updatedAppIssues
        )
        return max(0, basePenalties.orphaned - updated.orphaned)
    }
}
