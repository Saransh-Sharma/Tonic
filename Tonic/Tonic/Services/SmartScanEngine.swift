//
//  SmartScanEngine.swift
//  Tonic
//
//  Core scanning engine for Smart Scan feature
//  Task ID: fn-1.17
//

import Foundation
import OSLog

// MARK: - Smart Scan Engine

@Observable
final class SmartScanEngine: @unchecked Sendable {
    private let logger = Logger(subsystem: "com.tonic.app", category: "SmartScan")
    private let diskScanner = DiskScanner()
    private let fileManager = FileManager.default
    private let lock = NSLock()

    private let categoryScanner = ScanCategoryScanner()
    private let healthScoreCalculator = HealthScoreCalculator()
    private let recommendationGenerator = RecommendationGenerator()

    private var _currentStage: ScanStage = .preparing
    private var _scanData: ScanData = .init()

    var currentStage: ScanStage {
        get { lock.locked { _currentStage } }
        set { lock.locked { _currentStage = newValue } }
    }

    // MARK: - Partial Results (for live UI)

    var partialSpaceFoundBytes: Int64? {
        lock.locked { _scanData.junkFiles?.totalSize }
    }

    var partialFlaggedCount: Int? {
        lock.locked {
            var hasAny = false
            var total = 0

            if let junk = _scanData.junkFiles {
                hasAny = true
                total += junk.totalFiles
            }

            if let performance = _scanData.performanceIssues {
                hasAny = true
                total += performance.launchAgents.count
                total += performance.loginItems.count
                total += performance.browserCaches.count
            }

            if let apps = _scanData.appIssues {
                hasAny = true
                total += apps.unusedApps.count
                total += apps.largeApps.count
                total += apps.duplicateApps.count
                total += apps.orphanedFiles.count
            }

            return hasAny ? total : nil
        }
    }

    private struct ScanData {
        var diskUsage: DiskUsageSummary?
        var junkFiles: JunkCategory?
        var performanceIssues: PerformanceCategory?
        var appIssues: AppIssueCategory?
        var recommendations: [ScanRecommendation] = []
        var stageProgress: Double = 0
    }

    // MARK: - Stage Execution

    func runStage(_ stage: ScanStage) async -> Double {
        currentStage = stage

        var accumulatedProgress = 0.0

        switch stage {
        case .preparing:
            accumulatedProgress = await runPreparationStage()

        case .scanningDisk:
            accumulatedProgress = await runDiskScanStage()

        case .checkingApps:
            accumulatedProgress = await runAppCheckStage()

        case .analyzingSystem:
            accumulatedProgress = await runSystemAnalysisStage()

        case .complete:
            break
        }

        return min(accumulatedProgress, 0.95)
    }

    // MARK: - Preparation Stage

    private func runPreparationStage() async -> Double {
        logger.info("Running preparation stage")

        // Initialize scan data
        lock.locked { _scanData = ScanData() }

        // Get total disk space
        if let totalSpace = getTotalDiskSpace() {
            _scanData.diskUsage = DiskUsageSummary(
                totalSpace: totalSpace.total,
                usedSpace: totalSpace.used,
                freeSpace: totalSpace.free,
                homeDirectorySize: 0,
                cacheSize: 0,
                logSize: 0,
                tempSize: 0
            )
        }

        return ScanStage.preparing.progressWeight
    }

    // MARK: - Disk Scan Stage

    private func runDiskScanStage() async -> Double {
        logger.info("Running disk scan stage")

        // Scan junk files using category scanner
        let junkFiles = await categoryScanner.scanJunkFiles()
        lock.locked { _scanData.junkFiles = junkFiles }

        // Update disk usage with junk file totals
        if let existing = _scanData.diskUsage {
            _scanData.diskUsage = DiskUsageSummary(
                totalSpace: existing.totalSpace,
                usedSpace: existing.usedSpace,
                freeSpace: existing.freeSpace,
                homeDirectorySize: 0,
                cacheSize: junkFiles.cacheFiles.size,
                logSize: junkFiles.logFiles.size,
                tempSize: junkFiles.tempFiles.size
            )
        }

        let baseProgress = ScanStage.preparing.progressWeight
        return baseProgress + ScanStage.scanningDisk.progressWeight
    }

    // MARK: - App Check Stage

    private func runAppCheckStage() async -> Double {
        logger.info("Running app check stage")

        // Scan app issues using category scanner
        let appIssues = await categoryScanner.scanAppIssues()
        lock.locked { _scanData.appIssues = appIssues }

        let baseProgress = ScanStage.preparing.progressWeight + ScanStage.scanningDisk.progressWeight
        return baseProgress + ScanStage.checkingApps.progressWeight
    }

    // MARK: - System Analysis Stage

    private func runSystemAnalysisStage() async -> Double {
        logger.info("Running system analysis stage")

        // Scan performance issues using category scanner
        let performanceIssues = await categoryScanner.scanPerformanceIssues()
        lock.locked { _scanData.performanceIssues = performanceIssues }

        let baseProgress = ScanStage.preparing.progressWeight +
                          ScanStage.scanningDisk.progressWeight +
                          ScanStage.checkingApps.progressWeight
        return baseProgress + ScanStage.analyzingSystem.progressWeight
    }

    // MARK: - Finalize Scan

    func finalizeScan() async -> SmartScanResult {
        let startTime = Date()

        let scanResult = await generateComprehensiveScanResult()
        let duration = Date().timeIntervalSince(startTime)

        logger.info("Scan completed in \(duration)s")

        // Convert to SmartScanResult for backward compatibility
        let recommendations = recommendationGenerator.generateRecommendations(from: scanResult)
        let totalSpace = scanResult.totalReclaimableSpace

        return SmartScanResult(
            timestamp: Date(),
            scanDuration: duration,
            diskUsage: lock.locked { _scanData.diskUsage } ?? createDefaultDiskUsage(),
            recommendations: recommendations,
            totalSpaceToReclaim: totalSpace,
            systemHealthScore: scanResult.healthScore
        )
    }

    // Generate comprehensive ScanResult using new category scanner
    private func generateComprehensiveScanResult() async -> ScanResult {
        let diskUsage = lock.locked { _scanData.diskUsage } ?? createDefaultDiskUsage()

        // Get scan categories
        let junkFiles = lock.locked { _scanData.junkFiles } ?? JunkCategory(
            tempFiles: FileGroup(name: "Temp", description: ""),
            cacheFiles: FileGroup(name: "Cache", description: ""),
            logFiles: FileGroup(name: "Logs", description: ""),
            trashItems: FileGroup(name: "Trash", description: ""),
            languageFiles: FileGroup(name: "Languages", description: ""),
            oldFiles: FileGroup(name: "Old", description: "")
        )

        let performanceIssues = lock.locked { _scanData.performanceIssues } ?? PerformanceCategory(
            launchAgents: FileGroup(name: "Launch Agents", description: ""),
            loginItems: FileGroup(name: "Login Items", description: ""),
            browserCaches: FileGroup(name: "Browser Cache", description: ""),
            memoryIssues: [],
            diskFragmentation: nil
        )

        let appIssues = lock.locked { _scanData.appIssues } ?? AppIssueCategory(
            unusedApps: [],
            largeApps: [],
            duplicateApps: [],
            orphanedFiles: []
        )

        let legacyHealthScore = healthScoreCalculator.calculateScore(
            diskUsage: diskUsage,
            junkFiles: junkFiles,
            performanceIssues: performanceIssues,
            appIssues: appIssues
        )
        // Use scan-derived score only for Smart Scan to ensure stable results
        // when the scan findings haven't changed.
        let systemHealthScore = legacyHealthScore

        // Calculate total reclaimable space from all categories
        let unusedAppsSize = appIssues.unusedApps.reduce(Int64(0)) { $0 + $1.totalSize }
        let largeAppsSize = appIssues.largeApps.reduce(Int64(0)) { $0 + $1.totalSize }
        let duplicateAppsSize = appIssues.duplicateApps.reduce(Int64(0)) { $0 + $1.totalSize }
        let orphanedFilesSize = appIssues.orphanedFiles.reduce(Int64(0)) { $0 + $1.size }

        let totalReclaimableSpace = junkFiles.totalSize +
                                   performanceIssues.browserCaches.size +
                                   performanceIssues.launchAgents.size +
                                   performanceIssues.loginItems.size +
                                   unusedAppsSize +
                                   largeAppsSize +
                                   duplicateAppsSize +
                                   orphanedFilesSize

        return ScanResult(
            id: UUID(),
            timestamp: Date(),
            healthScore: systemHealthScore,
            junkFiles: junkFiles,
            performanceIssues: performanceIssues,
            appIssues: appIssues,
            totalReclaimableSpace: totalReclaimableSpace
        )
    }

    private func calculateSystemHealthScore(fallbackScore: Int) async -> Int {
        await ensureSystemMetrics()
        let metrics = await snapshotSystemMetrics()
        guard metrics.cpuUsagePercent > 0 || metrics.memoryUsedPercent > 0 || metrics.diskUsedPercent != nil else {
            return fallbackScore
        }
        return healthScoreCalculator.calculateSystemScore(metrics: metrics).score
    }

    private func ensureSystemMetrics() async {
        let hasMonitoring = await MainActor.run {
            WidgetDataManager.shared.isMonitoring
        }
        if !hasMonitoring {
            await MainActor.run {
                WidgetDataManager.shared.startMonitoring()
            }
        }

        let snapshot = await MainActor.run {
            (WidgetDataManager.shared.cpuData, WidgetDataManager.shared.memoryData, WidgetDataManager.shared.diskVolumes)
        }

        let hasData = snapshot.0.totalUsage > 0 || snapshot.1.totalBytes > 0 || !snapshot.2.isEmpty
        if !hasData {
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
    }

    private func snapshotSystemMetrics() async -> HealthScoreCalculator.SystemHealthMetrics {
        await MainActor.run {
            let cpu = WidgetDataManager.shared.cpuData
            let memory = WidgetDataManager.shared.memoryData
            let disk = WidgetDataManager.shared.diskVolumes.first(where: { $0.isBootVolume }) ?? WidgetDataManager.shared.diskVolumes.first
            let sensors = WidgetDataManager.shared.sensorsData

            let cpuTemp = cpu.temperature ?? sensors.temperatures.map({ $0.value }).max()
            let diskReadMBps = (disk?.readBytesPerSecond ?? 0) / 1_000_000
            let diskWriteMBps = (disk?.writeBytesPerSecond ?? 0) / 1_000_000

            return HealthScoreCalculator.SystemHealthMetrics(
                cpuUsagePercent: cpu.totalUsage,
                memoryUsedPercent: memory.usagePercentage,
                memoryPressure: memory.pressure,
                diskUsedPercent: disk?.usagePercentage,
                cpuTemperatureCelsius: cpuTemp,
                diskReadMBps: diskReadMBps,
                diskWriteMBps: diskWriteMBps
            )
        }
    }

    // MARK: - Fix Actions

    func fixRecommendations(_ recommendations: [ScanRecommendation]) async -> FixResult {
        logger.info("Fixing \(recommendations.count) recommendations")

        var itemsFixed = 0
        var spaceFreed: Int64 = 0
        var errors = 0
        let fileOps = FileOperations.shared

        for recommendation in recommendations where recommendation.safeToFix {
            for path in recommendation.affectedPaths {
                // Get size before deletion
                let attrs = try? fileManager.attributesOfItem(atPath: path)
                let size = (attrs?[.size] as? Int64) ?? 0

                // Delete using FileOperations
                let result = await fileOps.deleteFiles(atPaths: [path])

                if result.success {
                    itemsFixed += result.filesProcessed
                    spaceFreed += size
                } else {
                    errors += result.errors.count
                }
            }
        }

        return FixResult(itemsFixed: itemsFixed, spaceFreed: spaceFreed, errors: errors)
    }

    // MARK: - Helper Methods

    private func getTotalDiskSpace() -> (total: Int64, used: Int64, free: Int64)? {
        guard let attrs = try? fileManager.attributesOfFileSystem(forPath: "/") else {
            return nil
        }

        let total = (attrs[.systemSize] as? UInt64) ?? 0
        let free = (attrs[.systemFreeSize] as? UInt64) ?? 0

        return (Int64(total), Int64(total - free), Int64(free))
    }



    private func createDefaultDiskUsage() -> DiskUsageSummary {
        return DiskUsageSummary(
            totalSpace: 512 * 1024 * 1024 * 1024,
            usedSpace: 256 * 1024 * 1024 * 1024,
            freeSpace: 256 * 1024 * 1024 * 1024,
            homeDirectorySize: 100 * 1024 * 1024 * 1024,
            cacheSize: 0,
            logSize: 0,
            tempSize: 0
        )
    }

    // MARK: - Utilities

    private func isAppInstalled(_ appName: String) -> Bool {
        let appPaths = [
            "/Applications/\(appName).app",
            FileManager.default.homeDirectoryForCurrentUser.path + "/Applications/\(appName).app"
        ]
        return appPaths.contains { fileManager.fileExists(atPath: $0) }
    }

    private func getFileSize(_ path: String) -> Int64? {
        return (try? fileManager.attributesOfItem(atPath: path)[.size] as? Int64) ?? nil
    }
}

// MARK: - Async Reduce Extension

extension Sequence {
    func asyncReduce<Result>(
        _ initialResult: Result,
        _ updateAccumulatingResult: (Result, Element) async -> Result
    ) async -> Result {
        var result = initialResult
        for element in self {
            result = await updateAccumulatingResult(result, element)
        }
        return result
    }
}
