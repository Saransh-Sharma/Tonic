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

    func generateRecommendations(from scanResult: ScanResult) -> [ScanRecommendation] {
        var recommendations: [ScanRecommendation] = []

        // Generate recommendations for each category
        recommendations.append(contentsOf: generateJunkRecommendations(from: scanResult.junkFiles))
        recommendations.append(contentsOf: generatePerformanceRecommendations(from: scanResult.performanceIssues))
        recommendations.append(contentsOf: generateAppRecommendations(from: scanResult.appIssues))
        recommendations.append(contentsOf: generatePrivacyRecommendations(from: scanResult.privacyIssues))

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

    private func generateJunkRecommendations(from junkFiles: JunkCategory) -> [ScanRecommendation] {
        var recommendations: [ScanRecommendation] = []

        // Temporary files
        if junkFiles.tempFiles.size > 50 * 1024 * 1024 {
            let rec = ScanRecommendation(
                type: .tempFiles,
                title: "Clear Temporary Files",
                description: "Remove \(formatFileCount(junkFiles.tempFiles.count)) temporary files (\(formatSize(junkFiles.tempFiles.size))). These are safe to delete.",
                actionable: true,
                safeToFix: true,
                spaceToReclaim: junkFiles.tempFiles.size,
                affectedPaths: junkFiles.tempFiles.paths
            )
            recommendations.append(rec)
        }

        // Cache files
        if junkFiles.cacheFiles.size > 100 * 1024 * 1024 {
            let rec = ScanRecommendation(
                type: .cache,
                title: "Clear Application Caches",
                description: "Remove \(formatFileCount(junkFiles.cacheFiles.count)) cache files (\(formatSize(junkFiles.cacheFiles.size))). Apps will rebuild cache as needed.",
                actionable: true,
                safeToFix: true,
                spaceToReclaim: junkFiles.cacheFiles.size,
                affectedPaths: junkFiles.cacheFiles.paths
            )
            recommendations.append(rec)
        }

        // Log files
        if junkFiles.logFiles.size > 50 * 1024 * 1024 {
            let rec = ScanRecommendation(
                type: .logs,
                title: "Clear Old Log Files",
                description: "Remove \(formatFileCount(junkFiles.logFiles.count)) log files (\(formatSize(junkFiles.logFiles.size))). Old logs are safe to delete.",
                actionable: true,
                safeToFix: true,
                spaceToReclaim: junkFiles.logFiles.size,
                affectedPaths: junkFiles.logFiles.paths
            )
            recommendations.append(rec)
        }

        // Trash items
        if junkFiles.trashItems.size > 10 * 1024 * 1024 {
            let rec = ScanRecommendation(
                type: .trash,
                title: "Empty Trash",
                description: "Permanently remove \(formatFileCount(junkFiles.trashItems.count)) items from Trash (\(formatSize(junkFiles.trashItems.size))).",
                actionable: true,
                safeToFix: true,
                spaceToReclaim: junkFiles.trashItems.size,
                affectedPaths: junkFiles.trashItems.paths
            )
            recommendations.append(rec)
        }

        // Language files
        if junkFiles.languageFiles.size > 50 * 1024 * 1024 {
            let rec = ScanRecommendation(
                type: .languageFiles,
                title: "Remove Unused Language Files",
                description: "Remove \(formatFileCount(junkFiles.languageFiles.count)) language files (\(formatSize(junkFiles.languageFiles.size))). Keep only languages you use.",
                actionable: true,
                safeToFix: false,
                spaceToReclaim: junkFiles.languageFiles.size,
                affectedPaths: junkFiles.languageFiles.paths
            )
            recommendations.append(rec)
        }

        // Old files
        if junkFiles.oldFiles.size > 100 * 1024 * 1024 {
            let rec = ScanRecommendation(
                type: .oldFiles,
                title: "Remove Old Downloads",
                description: "Delete \(formatFileCount(junkFiles.oldFiles.count)) old files in Downloads folder (\(formatSize(junkFiles.oldFiles.size))).",
                actionable: true,
                safeToFix: false,
                spaceToReclaim: junkFiles.oldFiles.size,
                affectedPaths: junkFiles.oldFiles.paths
            )
            recommendations.append(rec)
        }

        return recommendations
    }

    // MARK: - Performance Recommendations

    private func generatePerformanceRecommendations(from performanceIssues: PerformanceCategory) -> [ScanRecommendation] {
        var recommendations: [ScanRecommendation] = []

        // Browser caches
        if performanceIssues.browserCaches.size > 500 * 1024 * 1024 {
            let rec = ScanRecommendation(
                type: .cache,
                title: "Clear Browser Caches",
                description: "Remove \(formatFileCount(performanceIssues.browserCaches.count)) browser cache files (\(formatSize(performanceIssues.browserCaches.size))). Browsers will faster.",
                actionable: true,
                safeToFix: true,
                spaceToReclaim: performanceIssues.browserCaches.size,
                affectedPaths: performanceIssues.browserCaches.paths
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
                affectedPaths: performanceIssues.launchAgents.paths
            )
            recommendations.append(rec)
        }

        return recommendations
    }

    // MARK: - App Recommendations

    private func generateAppRecommendations(from appIssues: AppIssueCategory) -> [ScanRecommendation] {
        var recommendations: [ScanRecommendation] = []

        // Unused apps
        if !appIssues.unusedApps.isEmpty {
            let totalSize = appIssues.unusedApps.reduce(0) { $0 + $1.totalSize }
            let rec = ScanRecommendation(
                type: .oldApps,
                title: "Uninstall Unused Applications",
                description: "Found \(appIssues.unusedApps.count) unused apps (\(formatSize(totalSize))). Remove to free up space.",
                actionable: true,
                safeToFix: false,
                spaceToReclaim: totalSize,
                affectedPaths: appIssues.unusedApps.map { $0.path.path }
            )
            recommendations.append(rec)
        }

        // Duplicate apps
        if !appIssues.duplicateApps.isEmpty {
            let totalSize = appIssues.duplicateApps.reduce(0) { $0 + $1.totalSize }
            let rec = ScanRecommendation(
                type: .oldApps,
                title: "Remove Duplicate Applications",
                description: "Found \(appIssues.duplicateApps.count) apps with multiple versions (\(formatSize(totalSize))). Keep only the latest version.",
                actionable: true,
                safeToFix: false,
                spaceToReclaim: totalSize,
                affectedPaths: appIssues.duplicateApps.flatMap { dup in
                    dup.versions.dropFirst().map { $0.path.path }
                }
            )
            recommendations.append(rec)
        }

        // Large apps
        if !appIssues.largeApps.isEmpty {
            let rec = ScanRecommendation(
                type: .largeApps,
                title: "Review Large Applications",
                description: "Found \(appIssues.largeApps.count) very large apps. Consider if you need them all.",
                actionable: true,
                safeToFix: false,
                spaceToReclaim: 0,
                affectedPaths: appIssues.largeApps.map { $0.path.path }
            )
            recommendations.append(rec)
        }

        // Orphaned files
        if !appIssues.orphanedFiles.isEmpty {
            let totalSize = appIssues.orphanedFiles.reduce(0) { $0 + $1.size }
            let rec = ScanRecommendation(
                type: .oldApps,
                title: "Remove Orphaned Application Files",
                description: "Found \(appIssues.orphanedFiles.count) files from uninstalled apps (\(formatSize(totalSize))). Safe to remove.",
                actionable: true,
                safeToFix: true,
                spaceToReclaim: totalSize,
                affectedPaths: appIssues.orphanedFiles.map { $0.path }
            )
            recommendations.append(rec)
        }

        return recommendations
    }

    // MARK: - Privacy Recommendations

    private func generatePrivacyRecommendations(from privacyIssues: PrivacyCategory) -> [ScanRecommendation] {
        var recommendations: [ScanRecommendation] = []

        // Browser history
        if privacyIssues.browserHistory.size > 100 * 1024 * 1024 {
            let rec = ScanRecommendation(
                type: .privacyData,
                title: "Clear Browser History",
                description: "Remove \(formatFileCount(privacyIssues.browserHistory.count)) browser history entries (\(formatSize(privacyIssues.browserHistory.size))). Improves privacy.",
                actionable: true,
                safeToFix: false,
                spaceToReclaim: privacyIssues.browserHistory.size,
                affectedPaths: privacyIssues.browserHistory.paths
            )
            recommendations.append(rec)
        }

        // Download history
        if privacyIssues.downloadHistory.size > 1024 * 1024 * 1024 {
            let rec = ScanRecommendation(
                type: .privacyData,
                title: "Clean Up Old Downloads",
                description: "Remove \(formatFileCount(privacyIssues.downloadHistory.count)) old downloaded files (\(formatSize(privacyIssues.downloadHistory.size))). Frees space and improves privacy.",
                actionable: true,
                safeToFix: false,
                spaceToReclaim: privacyIssues.downloadHistory.size,
                affectedPaths: privacyIssues.downloadHistory.paths
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
}
