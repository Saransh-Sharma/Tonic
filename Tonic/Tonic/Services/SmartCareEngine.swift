//
//  SmartCareEngine.swift
//  Tonic
//
//  Smart Care scanning pipeline inspired by CleanMyMac
//

import Foundation
import Darwin
import OSLog

@Observable
final class SmartCareEngine: @unchecked Sendable {
    private let logger = Logger(subsystem: "com.tonic.app", category: "SmartCareEngine")
    private let categoryScanner = ScanCategoryScanner()
    private let deepCleanEngine = DeepCleanEngine.shared
    private let hiddenSpaceScanner = HiddenSpaceScanner()
    private let sizeCache = DirectorySizeCache.shared

    private let progressWeights: [SmartCareDomain: Double] = [
        .cleanup: 0.53,
        .performance: 0.19,
        .applications: 0.28
    ]

    typealias DomainProgressUpdate = @Sendable (
        _ progress: Double,
        _ currentItem: String?,
        _ detail: String,
        _ counters: SmartScanLiveCounters?
    ) -> Void

    private actor ProgressEmitter {
        private let update: (SmartCareScanUpdate) -> Void
        private let progressWeights: [SmartCareDomain: Double]
        private var progressByDomain: [SmartCareDomain: Double] = [:]
        private var counters = SmartScanLiveCounters.zero

        init(update: @escaping (SmartCareScanUpdate) -> Void, progressWeights: [SmartCareDomain: Double]) {
            self.update = update
            self.progressWeights = progressWeights
        }

        func emit(
            domain: SmartCareDomain,
            title: String,
            detail: String,
            localProgress: Double,
            currentItem: String?,
            currentStage: SmartScanStage,
            completedStages: [SmartScanStage],
            counterSnapshot: SmartScanLiveCounters?
        ) {
            progressByDomain[domain] = localProgress
            if let counterSnapshot {
                counters.spaceBytesFound = max(counters.spaceBytesFound, counterSnapshot.spaceBytesFound)
                counters.performanceFlaggedCount = max(counters.performanceFlaggedCount, counterSnapshot.performanceFlaggedCount)
                counters.appsScannedCount = max(counters.appsScannedCount, counterSnapshot.appsScannedCount)
            }
            let total = progressByDomain.reduce(0.0) { partial, entry in
                let weight = progressWeights[entry.key] ?? 0
                return partial + (entry.value * weight)
            }
            let updateValue = SmartCareScanUpdate(
                domain: domain,
                title: title,
                detail: detail,
                progress: min(1.0, total),
                currentItem: currentItem,
                currentStage: currentStage,
                completedStages: completedStages,
                spaceBytesFound: counters.spaceBytesFound,
                performanceFlaggedCount: counters.performanceFlaggedCount,
                appsScannedCount: counters.appsScannedCount
            )
            Task { @MainActor in
                update(updateValue)
            }
        }
    }

    func runSmartCareScan(update: @escaping (SmartCareScanUpdate) -> Void) async -> SmartCareResult {
        let start = Date()
        var domainResults: [SmartCareDomain: SmartCareDomainResult] = [:]
        let emitter = ProgressEmitter(update: update, progressWeights: progressWeights)
        let emit: @Sendable (
            SmartCareDomain,
            String,
            String,
            Double,
            String?,
            SmartScanStage,
            [SmartScanStage],
            SmartScanLiveCounters?
        ) -> Void = { domain, title, detail, localProgress, currentItem, stage, completed, counterSnapshot in
            Task {
                await emitter.emit(
                    domain: domain,
                    title: title,
                    detail: detail,
                    localProgress: localProgress,
                    currentItem: currentItem,
                    currentStage: stage,
                    completedStages: completed,
                    counterSnapshot: counterSnapshot
                )
            }
        }

        logger.info("Starting Smart Care scan")

        emit(
            .cleanup,
            "Scanning Space...",
            "Preparing space scan",
            0,
            nil,
            .space,
            [],
            .zero
        )

        let cleanup = await scanCleanupAndClutter { local, currentItem, detail, counters in
            emit(
                .cleanup,
                "Scanning Space...",
                detail,
                local,
                currentItem,
                .space,
                [],
                counters
            )
        }

        domainResults[.cleanup] = cleanup
        emit(
            .cleanup,
            "Space scan complete",
            "Preparing Performance scan",
            1.0,
            nil,
            .space,
            [.space],
            SmartScanLiveCounters(spaceBytesFound: cleanup.totalSize, performanceFlaggedCount: 0, appsScannedCount: 0)
        )

        emit(
            .performance,
            "Scanning Performance...",
            "Preparing performance checks",
            0,
            nil,
            .performance,
            [.space],
            nil
        )

        let performance = await scanPerformance { local, currentItem, detail, counters in
            emit(
                .performance,
                "Scanning Performance...",
                detail,
                local,
                currentItem,
                .performance,
                [.space],
                counters
            )
        }

        domainResults[.performance] = performance
        emit(
            .performance,
            "Performance scan complete",
            "Preparing Apps scan",
            1.0,
            nil,
            .performance,
            [.space, .performance],
            SmartScanLiveCounters(spaceBytesFound: cleanup.totalSize, performanceFlaggedCount: performance.totalUnitCount, appsScannedCount: 0)
        )

        emit(
            .applications,
            "Scanning Apps...",
            "Preparing app lifecycle review",
            0,
            nil,
            .apps,
            [.space, .performance],
            nil
        )

        let applications = await scanApplications { local, currentItem, detail, counters in
            emit(
                .applications,
                "Scanning Apps...",
                detail,
                local,
                currentItem,
                .apps,
                [.space, .performance],
                counters
            )
        }

        domainResults[.applications] = applications

        update(SmartCareScanUpdate(
            domain: .applications,
            title: "Scan complete",
            detail: "Preparing your Smart Scan results",
            progress: 1.0,
            currentItem: nil,
            currentStage: .apps,
            completedStages: [.space, .performance, .apps],
            spaceBytesFound: cleanup.totalSize,
            performanceFlaggedCount: performance.totalUnitCount,
            appsScannedCount: applications.totalUnitCount
        ))

        let duration = Date().timeIntervalSince(start)
        logger.info("Smart Care scan finished in \(duration)s")

        return SmartCareResult(timestamp: Date(), duration: duration, domainResults: domainResults)
    }

    // MARK: - Cleanup

    private func scanCleanupAndClutter(update: @escaping DomainProgressUpdate) async -> SmartCareDomainResult {
        let start = Date()
        let categories: [DeepCleanCategory] = [
            .systemCache,
            .userCache,
            .tempFiles,
            .browserCache,
            .trash,
        ]

        let deepCleanWeight = 0.72
        let extraWeight = 1.0 - deepCleanWeight

        let deepStart = Date()
        let results = await scanDeepCleanCategories(categories) { progress, currentItem, detail, bytesSoFar in
            update(
                progress * deepCleanWeight,
                currentItem,
                detail,
                SmartScanLiveCounters(spaceBytesFound: bytesSoFar, performanceFlaggedCount: 0, appsScannedCount: 0)
            )
        }
        logger.info("Deep clean categories finished in \(Date().timeIntervalSince(deepStart))s")
        let deepCleanBytes = results.values.reduce(0) { $0 + $1.totalSize }

        update(
            deepCleanWeight + extraWeight * 0.10,
            "Finalizing",
            "Analyzing extra cleanup targets",
            SmartScanLiveCounters(spaceBytesFound: deepCleanBytes, performanceFlaggedCount: 0, appsScannedCount: 0)
        )

        async let junkFilesTask = categoryScanner.scanJunkFiles()
        async let hiddenTask = scanHiddenSpace()
        async let downloadsSplitTask = scanDownloadsSplit(thresholdDays: 30)

        let junkFiles = await junkFilesTask
        update(
            deepCleanWeight + extraWeight * 0.35,
            "Finding extra junk",
            "Scanning hidden space",
            SmartScanLiveCounters(spaceBytesFound: deepCleanBytes + junkFiles.totalSize, performanceFlaggedCount: 0, appsScannedCount: 0)
        )
        let hiddenStart = Date()
        let hiddenResult = await hiddenTask
        logger.info("Hidden space scan finished in \(Date().timeIntervalSince(hiddenStart))s")
        let hiddenBytes = hiddenResult?.totalHiddenSize ?? 0
        update(
            deepCleanWeight + extraWeight * 0.70,
            "Finding extra junk",
            "Scanning downloads",
            SmartScanLiveCounters(
                spaceBytesFound: deepCleanBytes + junkFiles.totalSize + hiddenBytes,
                performanceFlaggedCount: 0,
                appsScannedCount: 0
            )
        )
        let downloadsSplit = await downloadsSplitTask
        let userLogGroup = buildLogGroup(
            name: "User Log Files",
            description: "Application log files",
            basePaths: [FileManager.default.homeDirectoryForCurrentUser.path + "/Library/Logs"]
        )
        let systemLogGroup = buildLogGroup(
            name: "System Log Files",
            description: "System log files",
            basePaths: ["/Library/Logs", "/var/log"]
        )

        let cleanupTotal = results.values.reduce(0) { $0 + $1.totalSize } +
            junkFiles.totalSize +
            hiddenBytes +
            downloadsSplit.recent.size +
            downloadsSplit.old.size +
            userLogGroup.size +
            systemLogGroup.size
        update(
            1.0,
            nil,
            "Cleanup scan complete",
            SmartScanLiveCounters(spaceBytesFound: cleanupTotal, performanceFlaggedCount: 0, appsScannedCount: 0)
        )
        logger.info("Cleanup scan finished in \(Date().timeIntervalSince(start))s")

        let systemGroupId = UUID()
        let downloadsGroupId = UUID()
        let trashGroupId = UUID()
        let developerGroupId = UUID()
        let hiddenGroupId = UUID()

        let systemItems: [SmartCareItem?] = [
            makeDeepCleanItem(domain: .cleanup, groupId: systemGroupId, result: results[.userCache], overrideTitle: "User Cache Files"),
            makeDeepCleanItem(domain: .cleanup, groupId: systemGroupId, result: results[.tempFiles], overrideTitle: "Temporary Files"),
            makeFileGroupItem(
                domain: .cleanup,
                groupId: systemGroupId,
                title: "User Log Files",
                subtitle: userLogGroup.description,
                group: userLogGroup,
                safeToRun: true,
                smartlySelected: userLogGroup.size > 0
            ),
            makeFileGroupItem(
                domain: .cleanup,
                groupId: systemGroupId,
                title: "System Log Files",
                subtitle: systemLogGroup.description,
                group: systemLogGroup,
                safeToRun: true,
                smartlySelected: systemLogGroup.size > 0
            ),
            makeDeepCleanItem(domain: .cleanup, groupId: systemGroupId, result: results[.systemCache], overrideTitle: "System Cache Files"),
            makeDeepCleanItem(domain: .cleanup, groupId: systemGroupId, result: results[.browserCache], overrideTitle: "Browser Cache"),
            makeFileGroupItem(
                domain: .cleanup,
                groupId: systemGroupId,
                title: "Language Files",
                subtitle: junkFiles.languageFiles.description,
                group: junkFiles.languageFiles,
                safeToRun: false,
                smartlySelected: false
            ),
            placeholderItem(domain: .cleanup, groupId: systemGroupId, title: "Broken Login Items"),
            placeholderItem(domain: .cleanup, groupId: systemGroupId, title: "Universal Binaries"),
            placeholderItem(domain: .cleanup, groupId: systemGroupId, title: "iOS Device Backups"),
            placeholderItem(domain: .cleanup, groupId: systemGroupId, title: "Document Versions"),
            placeholderItem(domain: .cleanup, groupId: systemGroupId, title: "Deleted Users"),
            placeholderItem(domain: .cleanup, groupId: systemGroupId, title: "Broken Preferences")
        ]

        let downloadsItems: [SmartCareItem?] = [
            makeFileGroupItem(
                domain: .cleanup,
                groupId: downloadsGroupId,
                title: "Downloads",
                subtitle: downloadsSplit.recent.description,
                group: downloadsSplit.recent,
                safeToRun: true,
                smartlySelected: downloadsSplit.recent.size > 0
            ),
            makeFileGroupItem(
                domain: .cleanup,
                groupId: downloadsGroupId,
                title: "Old Downloads",
                subtitle: downloadsSplit.old.description,
                group: downloadsSplit.old,
                safeToRun: true,
                smartlySelected: downloadsSplit.old.size > 0
            )
        ]

        let trashTitle = FileManager.default.displayName(atPath: "/")
        let trashAccessGranted = canAccessTrash()
        let trashSubtitle = trashAccessGranted ? "Empty trash" : "Grant Full Disk Access to scan Trash"
        let trashItems = [
            makeDeepCleanItem(
                domain: .cleanup,
                groupId: trashGroupId,
                result: results[.trash],
                overrideTitle: trashTitle,
                overrideSubtitle: trashSubtitle,
                overrideSafeToRun: trashAccessGranted
            )
        ]

        let developerItems = buildXcodeItems(groupId: developerGroupId)

        var ledger = PathLedger()

        let systemItemsDeduped = dedupeItems(systemItems.compactMap { $0 }, ledger: &ledger)
        let downloadsItemsDeduped = dedupeItems(downloadsItems.compactMap { $0 }, ledger: &ledger)
        let trashItemsDeduped = dedupeItems(trashItems.compactMap { $0 }, ledger: &ledger)
        let developerItemsDeduped = dedupeItems(developerItems.compactMap { $0 }, ledger: &ledger)
        let hiddenItemsDeduped = dedupeItems(buildHiddenSpaceItems(domain: .cleanup, groupId: hiddenGroupId, result: hiddenResult), ledger: &ledger)

        let groups = [
            SmartCareGroup(
                id: systemGroupId,
                domain: .cleanup,
                title: "System Junk",
                description: "Cached files and logs that build up over time",
                items: systemItemsDeduped
            ),
            SmartCareGroup(
                id: UUID(),
                domain: .cleanup,
                title: "Mail Attachments",
                description: "Large attachments stored by Mail",
                items: []
            ),
            SmartCareGroup(
                id: downloadsGroupId,
                domain: .cleanup,
                title: "Downloads",
                description: "Downloads and aging files",
                items: downloadsItemsDeduped
            ),
            SmartCareGroup(
                id: trashGroupId,
                domain: .cleanup,
                title: "Trash Bins",
                description: "Items already in the Trash",
                items: trashItemsDeduped
            ),
            SmartCareGroup(
                id: developerGroupId,
                domain: .cleanup,
                title: "Xcode Junk",
                description: "Build artifacts and development caches",
                items: developerItemsDeduped
            ),
            SmartCareGroup(
                id: hiddenGroupId,
                domain: .cleanup,
                title: "Hidden Space",
                description: "Artifacts hidden inside projects and caches",
                items: hiddenItemsDeduped
            )
        ]

        return SmartCareDomainResult(domain: .cleanup, groups: groups)
    }

    private func scanDeepCleanCategories(
        _ categories: [DeepCleanCategory],
        update: @escaping @Sendable (_ progress: Double, _ currentItem: String?, _ detail: String, _ bytesSoFar: Int64) -> Void
    ) async -> [DeepCleanCategory: DeepCleanResult] {
        let maxConcurrent = 3
        var results: [DeepCleanCategory: DeepCleanResult] = [:]
        var completed = 0
        var index = 0
        var bytesSoFar: Int64 = 0

        await withTaskGroup(of: (DeepCleanCategory, DeepCleanResult).self) { group in
            func enqueueNext() {
                guard index < categories.count else { return }
                let category = categories[index]
                index += 1
                group.addTask { [deepCleanEngine] in
                    let result = await deepCleanEngine.scanCategory(category)
                    return (category, result)
                }
            }

            for _ in 0..<min(maxConcurrent, categories.count) {
                enqueueNext()
            }

            while let (category, result) = await group.next() {
                results[category] = result
                completed += 1
                bytesSoFar += result.totalSize
                let progress = Double(completed) / Double(max(1, categories.count))
                update(progress, category.rawValue, category.description, bytesSoFar)
                enqueueNext()
            }
        }

        return results
    }

    private func buildCleanupItems(
        domain: SmartCareDomain,
        groupId: UUID,
        results: [DeepCleanCategory: DeepCleanResult],
        categories: [DeepCleanCategory]
    ) -> [SmartCareItem?] {
        categories.map { category in
            makeDeepCleanItem(domain: domain, groupId: groupId, result: results[category])
        }
    }

    private enum DeepCleanSplit {
        case logs
    }

    private func makeDeepCleanItem(
        domain: SmartCareDomain,
        groupId: UUID,
        result: DeepCleanResult?,
        overrideTitle: String? = nil,
        overrideSubtitle: String? = nil,
        overrideSafeToRun: Bool? = nil,
        split: DeepCleanSplit? = nil
    ) -> SmartCareItem? {
        guard let result else { return nil }
        if result.category == .trash {
            let trashPaths = fetchTrashContents()
            let safeToRun = overrideSafeToRun ?? true
            return makeItem(
                domain: domain,
                groupId: groupId,
                title: overrideTitle ?? result.category.rawValue,
                subtitle: overrideSubtitle ?? result.category.description,
                size: result.totalSize,
                count: trashPaths.count,
                safeToRun: safeToRun,
                paths: trashPaths,
                smartlySelected: safeToRun && result.totalSize > 0,
                action: safeToRun ? .delete(paths: trashPaths) : .none
            )
        }
        let title = overrideTitle ?? result.category.rawValue
        let subtitle = overrideSubtitle ?? result.category.description
        let paths = split == .logs ? splitLogPaths(result.paths) : result.paths
        let size = split == .logs ? calculateSize(paths) : result.totalSize
        let count = max(paths.count, result.itemCount)
        let safeToRun = overrideSafeToRun ?? result.safeToDelete

        return makeItem(
            domain: domain,
            groupId: groupId,
            title: title,
            subtitle: subtitle,
            size: size,
            count: count,
            safeToRun: safeToRun,
            paths: paths,
            smartlySelected: safeToRun && size > 0,
            action: safeToRun ? .delete(paths: paths) : .none
        )
    }

    private func makeFileGroupItem(
        domain: SmartCareDomain,
        groupId: UUID,
        title: String,
        subtitle: String,
        group: FileGroup,
        safeToRun: Bool,
        smartlySelected: Bool
    ) -> SmartCareItem {
        makeItem(
            domain: domain,
            groupId: groupId,
            title: title,
            subtitle: subtitle,
            size: group.size,
            count: group.count,
            safeToRun: safeToRun,
            paths: group.paths,
            smartlySelected: smartlySelected,
            action: safeToRun ? .delete(paths: group.paths) : .none
        )
    }

    // MARK: - Performance

    private func scanPerformance(update: @escaping DomainProgressUpdate) async -> SmartCareDomainResult {
        let start = Date()
        update(
            0.12,
            nil,
            "Checking maintenance tasks",
            SmartScanLiveCounters(spaceBytesFound: 0, performanceFlaggedCount: 0, appsScannedCount: 0)
        )

        let maintenanceGroupId = UUID()
        let loginGroupId = UUID()
        let backgroundGroupId = UUID()

        let maintenanceActions: [OptimizationAction] = [
            .flushDNS,
            .freePurgeableSpace,
            .reindexSpotlight,
            .repairDiskPermissions,
            .speedUpMail
        ]

        let maintenanceItems = maintenanceActions.map { action in
            makeItem(
                domain: .performance,
                groupId: maintenanceGroupId,
                title: action.rawValue,
                subtitle: action.description,
                size: 0,
                count: 1,
                safeToRun: true,
                paths: [],
                smartlySelected: true,
                action: .runOptimization(action)
            )
        }

        update(
            0.45,
            nil,
            "Reviewing login items",
            SmartScanLiveCounters(spaceBytesFound: 0, performanceFlaggedCount: maintenanceItems.count, appsScannedCount: 0)
        )
        let loginItems = await scanLoginItemsDetailed().map { entry in
            makeItem(
                domain: .performance,
                groupId: loginGroupId,
                title: entry.name,
                subtitle: "Opens automatically when you log in",
                size: 0,
                count: 1,
                safeToRun: false,
                paths: [entry.path],
                smartlySelected: false,
                action: .none
            )
        }

        update(
            0.75,
            nil,
            "Reviewing background items",
            SmartScanLiveCounters(
                spaceBytesFound: 0,
                performanceFlaggedCount: maintenanceItems.count + loginItems.count,
                appsScannedCount: 0
            )
        )
        let backgroundItems = scanBackgroundItemsDetailed().map { entry in
            makeItem(
                domain: .performance,
                groupId: backgroundGroupId,
                title: entry.title,
                subtitle: entry.subtitle,
                size: sizeForPath(entry.path),
                count: 1,
                safeToRun: entry.safeToRemove,
                paths: [entry.path],
                smartlySelected: false,
                action: entry.safeToRemove ? .delete(paths: [entry.path]) : .none
            )
        }

        update(
            1.0,
            nil,
            "Performance scan complete",
            SmartScanLiveCounters(
                spaceBytesFound: 0,
                performanceFlaggedCount: maintenanceItems.count + loginItems.count + backgroundItems.count,
                appsScannedCount: 0
            )
        )
        logger.info("Performance scan finished in \(Date().timeIntervalSince(start))s")

        let groups: [SmartCareGroup] = [
            SmartCareGroup(
                id: maintenanceGroupId,
                domain: .performance,
                title: "Maintenance Tasks",
                description: "Essential Mac care includes both general and specific tasks that help keep your software and hardware in shape.",
                items: maintenanceItems
            ),
            SmartCareGroup(
                id: loginGroupId,
                domain: .performance,
                title: "Login Items",
                description: "Manage the list of applications that get automatically opened every time you log in.",
                items: loginItems
            ),
            SmartCareGroup(
                id: backgroundGroupId,
                domain: .performance,
                title: "Background Items",
                description: "Manage the list of processes and applications that run in the background.",
                items: backgroundItems
            )
        ]

        return SmartCareDomainResult(domain: .performance, groups: groups)
    }

    private struct PerformanceLoginEntry {
        let name: String
        let path: String
    }

    private struct PerformanceBackgroundEntry {
        let title: String
        let subtitle: String
        let path: String
        let safeToRemove: Bool
    }

    private func scanLoginItemsDetailed() async -> [PerformanceLoginEntry] {
        var seen = Set<String>()
        var items: [PerformanceLoginEntry] = []

        // Prefer ServiceManagement-backed data through existing manager.
        await LoginItemsManager.shared.fetchLoginItems()
        let managerItems = await MainActor.run { LoginItemsManager.shared.loginItems }
        for item in managerItems {
            let path = item.path.path
            guard !seen.contains(path) else { continue }
            seen.insert(path)
            items.append(PerformanceLoginEntry(name: item.name, path: path))
        }

        // Fallback to legacy plist entries.
        let loginItemsPath = NSHomeDirectory() + "/Library/Preferences/com.apple.loginitems.plist"
        if let plistData = FileManager.default.contents(atPath: loginItemsPath),
           let plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any],
           let loginItemsArray = plist["AutoLaunchedApplicationDictionary"] as? [[String: Any]] {
            for item in loginItemsArray {
                guard let path = item["Path"] as? String else { continue }
                guard !seen.contains(path) else { continue }
                seen.insert(path)

                let url = URL(fileURLWithPath: path)
                let name = url.deletingPathExtension().lastPathComponent
                items.append(PerformanceLoginEntry(name: name, path: path))
            }
        }

        return items.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private func scanBackgroundItemsDetailed() -> [PerformanceBackgroundEntry] {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser.path
        let userLaunchAgentsPath = home + "/Library/LaunchAgents"
        let launchPaths = [
            userLaunchAgentsPath,
            "/Library/LaunchAgents",
            "/Library/LaunchDaemons"
        ]

        var entries: [PerformanceBackgroundEntry] = []
        var seenPaths = Set<String>()

        for basePath in launchPaths where fileManager.fileExists(atPath: basePath) {
            guard let contents = try? fileManager.contentsOfDirectory(
                at: URL(fileURLWithPath: basePath),
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }

            for url in contents where url.pathExtension == "plist" {
                let fullPath = url.path
                guard !seenPaths.contains(fullPath) else { continue }
                seenPaths.insert(fullPath)

                entries.append(
                    PerformanceBackgroundEntry(
                        title: url.lastPathComponent,
                        subtitle: basePath,
                        path: fullPath,
                        safeToRemove: basePath == userLaunchAgentsPath
                    )
                )
            }
        }

        return entries.sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }

    // MARK: - Applications

    private func scanApplications(update: @escaping DomainProgressUpdate) async -> SmartCareDomainResult {
        let start = Date()
        update(
            0.2,
            nil,
            "Reviewing installed applications",
            SmartScanLiveCounters(spaceBytesFound: 0, performanceFlaggedCount: 0, appsScannedCount: 0)
        )
        let appIssues = await categoryScanner.scanAppIssues()
        let duplicateVersionsCount = appIssues.duplicateApps.reduce(0) { $0 + $1.versions.count }
        let scannedAppsCount = appIssues.unusedApps.count + duplicateVersionsCount + appIssues.largeApps.count
        update(
            1.0,
            nil,
            "Applications scan complete",
            SmartScanLiveCounters(
                spaceBytesFound: 0,
                performanceFlaggedCount: 0,
                appsScannedCount: scannedAppsCount
            )
        )
        logger.info("Applications scan finished in \(Date().timeIntervalSince(start))s")

        let groupId = UUID()
        let items: [SmartCareItem] = [
            makeAppIssueItem(
                domain: .applications,
                groupId: groupId,
                title: "Unused Apps",
                subtitle: "Applications you rarely open",
                apps: appIssues.unusedApps,
                safeToRun: false
            ),
            makeAppIssueItem(
                domain: .applications,
                groupId: groupId,
                title: "Duplicate Apps",
                subtitle: "Multiple versions of the same app",
                duplicateGroups: appIssues.duplicateApps,
                safeToRun: false
            ),
            makeAppIssueItem(
                domain: .applications,
                groupId: groupId,
                title: "Large Apps",
                subtitle: "High disk usage applications",
                apps: appIssues.largeApps,
                safeToRun: false
            ),
            makeOrphanedItem(domain: .applications, groupId: groupId, orphaned: appIssues.orphanedFiles)
        ].compactMap { $0 }.filter { $0.size > 0 || $0.count > 0 }

        let groups = items.isEmpty ? [] : [
            SmartCareGroup(
                id: groupId,
                domain: .applications,
                title: "Vital Updates",
                description: "Updates, duplicates, and cleanup suggestions",
                items: items
            )
        ]

        return SmartCareDomainResult(domain: .applications, groups: groups)
    }

    private func makeAppIssueItem(
        domain: SmartCareDomain,
        groupId: UUID,
        title: String,
        subtitle: String,
        apps: [AppMetadata],
        safeToRun: Bool
    ) -> SmartCareItem? {
        guard !apps.isEmpty else { return nil }
        let totalSize = apps.reduce(0) { $0 + $1.totalSize }
        return makeItem(
            domain: domain,
            groupId: groupId,
            title: title,
            subtitle: subtitle,
            size: totalSize,
            count: apps.count,
            safeToRun: safeToRun,
            paths: apps.map { $0.path.path },
            smartlySelected: false,
            action: .none
        )
    }

    private func makeAppIssueItem(
        domain: SmartCareDomain,
        groupId: UUID,
        title: String,
        subtitle: String,
        duplicateGroups: [DuplicateAppGroup],
        safeToRun: Bool
    ) -> SmartCareItem? {
        guard !duplicateGroups.isEmpty else { return nil }
        let totalSize = duplicateGroups.reduce(0) { $0 + $1.totalSize }
        let paths = duplicateGroups.flatMap { $0.versions.map { $0.path.path } }
        return makeItem(
            domain: domain,
            groupId: groupId,
            title: title,
            subtitle: subtitle,
            size: totalSize,
            count: duplicateGroups.count,
            safeToRun: safeToRun,
            paths: paths,
            smartlySelected: false,
            action: .none
        )
    }

    private func makeOrphanedItem(domain: SmartCareDomain, groupId: UUID, orphaned: [OrphanedFile]) -> SmartCareItem? {
        guard !orphaned.isEmpty else { return nil }
        let totalSize = orphaned.reduce(0) { $0 + $1.size }
        return makeItem(
            domain: domain,
            groupId: groupId,
            title: "Orphaned Files",
            subtitle: "Leftover files from removed apps",
            size: totalSize,
            count: orphaned.count,
            safeToRun: true,
            paths: orphaned.map { $0.path },
            smartlySelected: totalSize > 0,
            action: .delete(paths: orphaned.map { $0.path })
        )
    }

    // MARK: - Clutter

    // merged into scanCleanupAndClutter

    private func buildHiddenSpaceItems(
        domain: SmartCareDomain,
        groupId: UUID,
        result: HiddenSpaceScanResult?
    ) -> [SmartCareItem] {
        guard let result else { return [] }

        let grouped = Dictionary(grouping: result.hiddenItems, by: { $0.type })
        let safeTypes: Set<HiddenSpaceItem.HiddenItemType> = [.nodeModules, .buildArtifacts, .cache, .virtualEnvironment, .logs]

        return grouped.compactMap { type, items in
            if type == .docker { return nil }
            let totalSize = items.reduce(0) { $0 + $1.size }
            guard totalSize > 0 else { return nil }
            let safe = safeTypes.contains(type)
            let smart = safe && totalSize > 25 * 1024 * 1024
            let paths = items.map { $0.path }

            return makeItem(
                domain: domain,
                groupId: groupId,
                title: type.rawValue,
                subtitle: "\(items.count) locations",
                size: totalSize,
                count: items.count,
                safeToRun: safe,
                paths: paths,
                smartlySelected: smart,
                action: safe ? .delete(paths: paths) : .none
            )
        }
        .sorted { $0.size > $1.size }
    }

    private func buildProjectArtifactItems(
        domain: SmartCareDomain,
        groupId: UUID,
        results: [ProjectArtifactResult]
    ) -> [SmartCareItem] {
        let items = results.compactMap { result -> SmartCareItem? in
            if result.projectType == .docker { return nil }
            let projectPrefix = result.projectPath.hasSuffix("/") ? result.projectPath : result.projectPath + "/"
            let safeArtifacts = result.artifacts
                .filter { $0.type.isSafeToDelete }
                .filter { $0.path.hasPrefix(projectPrefix) }
            guard !safeArtifacts.isEmpty else { return nil }
            let totalSize = safeArtifacts.reduce(0) { $0 + $1.size }
            let paths = safeArtifacts.map { $0.path }

            return makeItem(
                domain: domain,
                groupId: groupId,
                title: (result.projectPath as NSString).lastPathComponent,
                subtitle: "\(result.projectType.rawValue) · \(safeArtifacts.count) items",
                size: totalSize,
                count: safeArtifacts.count,
                safeToRun: true,
                paths: paths,
                smartlySelected: totalSize > 50 * 1024 * 1024,
                action: .delete(paths: paths)
            )
        }

        return items.sorted { $0.size > $1.size }.prefix(30).map { $0 }
    }

    private func buildXcodeItems(groupId: UUID) -> [SmartCareItem?] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let entries: [(title: String, subtitle: String, path: String)] = [
            ("Xcode Simulators Runtime", "Simulators and runtimes", home + "/Library/Developer/CoreSimulator"),
            ("iOS Device Support", "Device support files", home + "/Library/Developer/Xcode/iOS DeviceSupport"),
            ("Derived Data", "Build artifacts and indexes", home + "/Library/Developer/Xcode/DerivedData"),
            ("Archives", "Xcode archives", home + "/Library/Developer/Xcode/Archives"),
            ("Xcode Caches", "Xcode cache files", home + "/Library/Caches/com.apple.dt.Xcode")
        ]

        return entries.map { entry in
            let exists = FileManager.default.fileExists(atPath: entry.path)
            let paths = exists ? [entry.path] : []
            let size = exists ? sizeForPath(entry.path) : 0
            let smart = exists && size > 0
            let action: SmartCareAction = exists ? .delete(paths: paths) : .none

            return makeItem(
                domain: .cleanup,
                groupId: groupId,
                title: entry.title,
                subtitle: entry.subtitle,
                size: size,
                count: paths.isEmpty ? 0 : 1,
                safeToRun: exists,
                paths: paths,
                smartlySelected: smart,
                action: action
            )
        }
    }

    private struct DownloadsSplit {
        let recent: FileGroup
        let old: FileGroup
    }

    private func scanDownloadsSplit(thresholdDays: Int) async -> DownloadsSplit {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser.path
        let downloadsPath = home + "/Downloads"
        let thresholdDate = Date().addingTimeInterval(-TimeInterval(thresholdDays * 24 * 3600))

        var recentPaths: [String] = []
        var oldPaths: [String] = []
        var recentSize: Int64 = 0
        var oldSize: Int64 = 0

        guard let contents = try? fileManager.contentsOfDirectory(
            at: URL(fileURLWithPath: downloadsPath),
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return DownloadsSplit(
                recent: FileGroup(name: "Downloads", description: "Recent downloads", paths: [], size: 0, count: 0),
                old: FileGroup(name: "Old Downloads", description: "Old downloads", paths: [], size: 0, count: 0)
            )
        }

        for url in contents {
            guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]) else {
                continue
            }
            let modDate = values.contentModificationDate ?? Date.distantPast
            let isOld = modDate < thresholdDate
            let size = sizeForPath(url.path)

            if isOld {
                oldPaths.append(url.path)
                oldSize += size
            } else {
                recentPaths.append(url.path)
                recentSize += size
            }
        }

        return DownloadsSplit(
            recent: FileGroup(name: "Downloads", description: "Recent downloads", paths: recentPaths, size: recentSize, count: recentPaths.count),
            old: FileGroup(name: "Old Downloads", description: "Old downloads", paths: oldPaths, size: oldSize, count: oldPaths.count)
        )
    }

    private func scanHiddenSpace() async -> HiddenSpaceScanResult? {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser.path
        var scanRoots = [home]
        let devRoots = [
            home + "/Developer",
            home + "/Developers",
            home + "/Projects",
            home + "/Project",
            home + "/Code",
            home + "/Workspace",
            home + "/Workspaces"
        ]
        scanRoots.append(contentsOf: devRoots)
        scanRoots = Array(Set(scanRoots.filter { fileManager.fileExists(atPath: $0) }))
        var allItems: [HiddenSpaceItem] = []
        var totalSize: Int64 = 0
        var duration: TimeInterval = 0
        var report = DiskDiscrepancyReport(finderUsedSpace: 0, duUsedSpace: 0, discrepancy: 0, possibleCauses: [])

        for root in scanRoots {
            if let result = try? await hiddenSpaceScanner.scanPath(root, includeDotfiles: true) {
                allItems.append(contentsOf: result.hiddenItems)
                totalSize += result.totalHiddenSize
                duration += result.scanDuration
                report = result.discrepancyReport
            }
        }

        return HiddenSpaceScanResult(
            timestamp: Date(),
            scanDuration: duration,
            hiddenItems: allItems,
            totalHiddenSize: totalSize,
            itemCount: allItems.count,
            discrepancyReport: report
        )
    }

    private func buildLogGroup(name: String, description: String, basePaths: [String]) -> FileGroup {
        let fileManager = FileManager.default
        var paths: [String] = []
        var totalSize: Int64 = 0

        for base in basePaths where fileManager.fileExists(atPath: base) {
            guard let contents = try? fileManager.contentsOfDirectory(
                at: URL(fileURLWithPath: base),
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            for url in contents {
                let size = sizeForPath(url.path)
                if size > 0 {
                    paths.append(url.path)
                    totalSize += size
                }
            }
        }

        return FileGroup(name: name, description: description, paths: paths, size: totalSize, count: paths.count)
    }

    private func placeholderItem(domain: SmartCareDomain, groupId: UUID, title: String) -> SmartCareItem {
        makeItem(
            domain: domain,
            groupId: groupId,
            title: title,
            subtitle: "",
            size: 0,
            count: 0,
            safeToRun: false,
            paths: [],
            smartlySelected: false,
            action: .none
        )
    }

    private struct PathLedger {
        private(set) var roots: [String] = []

        mutating func uniquePaths(from paths: [String]) -> [String] {
            let normalized = paths.compactMap { normalize($0) }
            let sorted = normalized.sorted { $0.count < $1.count }
            var accepted: [String] = []
            for path in sorted {
                if overlaps(path) { continue }
                roots.append(path)
                accepted.append(path)
            }
            return accepted
        }

        private func overlaps(_ path: String) -> Bool {
            for root in roots {
                if path == root { return true }
                if path.hasPrefix(root + "/") { return true }
                if root.hasPrefix(path + "/") { return true }
            }
            return false
        }

        private func normalize(_ path: String) -> String? {
            let url = URL(fileURLWithPath: path)
            return url.standardizedFileURL.resolvingSymlinksInPath().path
        }
    }

    private func dedupeItems(_ items: [SmartCareItem], ledger: inout PathLedger) -> [SmartCareItem] {
        items.compactMap { item in
            guard !item.paths.isEmpty else { return item }
            let uniquePaths = ledger.uniquePaths(from: item.paths)
            guard !uniquePaths.isEmpty else { return nil }
            let size = uniquePaths.reduce(0) { $0 + sizeForPath($1) }
            let action: SmartCareAction
            switch item.action {
            case .delete:
                action = .delete(paths: uniquePaths)
            default:
                action = item.action
            }
            let scoreImpact = estimateScoreImpact(bytes: size, isSafe: item.safeToRun)
            return SmartCareItem(
                id: item.id,
                domain: item.domain,
                groupId: item.groupId,
                title: item.title,
                subtitle: item.subtitle,
                size: size,
                count: uniquePaths.count,
                safeToRun: item.safeToRun,
                isSmartSelected: item.isSmartSelected,
                action: action,
                paths: uniquePaths,
                scoreImpact: scoreImpact
            )
        }
    }

    private func sizeForPath(_ path: String) -> Int64 {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: path, isDirectory: &isDirectory) {
            if isDirectory.boolValue {
                return sizeCache.size(for: path, includeHidden: true) ?? 0
            }
            let url = URL(fileURLWithPath: path)
            if let values = try? url.resourceValues(forKeys: [.fileSizeKey]) {
                return Int64(values.fileSize ?? 0)
            }
        }
        return 0
    }

    private func calculateSize(_ paths: [String]) -> Int64 {
        paths.reduce(0) { $0 + sizeForPath($1) }
    }

    private func splitLogPaths(_ paths: [String]) -> [String] {
        let userPrefix = FileManager.default.homeDirectoryForCurrentUser.path + "/Library/Logs"
        return paths.filter { $0.hasPrefix(userPrefix) }
    }

    // MARK: - Helpers

    private func makeItem(
        domain: SmartCareDomain,
        groupId: UUID,
        title: String,
        subtitle: String,
        size: Int64,
        count: Int,
        safeToRun: Bool,
        paths: [String],
        smartlySelected: Bool,
        action: SmartCareAction
    ) -> SmartCareItem {
        let impact = estimateScoreImpact(bytes: size, isSafe: safeToRun)
        return SmartCareItem(
            domain: domain,
            groupId: groupId,
            title: title,
            subtitle: subtitle,
            size: size,
            count: count,
            safeToRun: safeToRun,
            isSmartSelected: smartlySelected,
            action: action,
            paths: paths,
            scoreImpact: impact
        )
    }

    private func estimateScoreImpact(bytes: Int64, isSafe: Bool) -> Int {
        guard isSafe, bytes > 0 else { return 0 }
        let gb = Double(bytes) / (1024 * 1024 * 1024)
        let raw = Int(round(gb * 4))
        return max(1, min(12, raw))
    }

    private func fetchTrashContents() -> [String] {
        let fileManager = FileManager.default
        var roots: [String] = []

        if let trashURL = fileManager.urls(for: .trashDirectory, in: .userDomainMask).first {
            roots.append(trashURL.path)
        }

        let homeTrash = fileManager.homeDirectoryForCurrentUser.path + "/.Trash"
        if fileManager.fileExists(atPath: homeTrash) {
            roots.append(homeTrash)
        }

        let uid = getuid()
        if let volumeURLs = try? fileManager.contentsOfDirectory(
            at: URL(fileURLWithPath: "/Volumes"),
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            for volume in volumeURLs {
                let values = try? volume.resourceValues(forKeys: [.isDirectoryKey])
                guard values?.isDirectory == true else { continue }
                let trashPath = volume.path + "/.Trashes/\(uid)"
                if fileManager.fileExists(atPath: trashPath) {
                    roots.append(trashPath)
                }
                let altTrash = volume.path + "/.Trash"
                if fileManager.fileExists(atPath: altTrash) {
                    roots.append(altTrash)
                }
            }
        }

        let uniqueRoots = Array(Set(roots))
        var items: [String] = []
        for root in uniqueRoots {
            guard let contents = try? fileManager.contentsOfDirectory(
                at: URL(fileURLWithPath: root),
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
                options: [.skipsPackageDescendants]
            ) else { continue }
            items.append(contentsOf: contents.map { $0.path })
        }

        return items
    }

    private func canAccessTrash() -> Bool {
        let fileManager = FileManager.default
        let homeTrash = fileManager.homeDirectoryForCurrentUser.path + "/.Trash"
        if fileManager.isReadableFile(atPath: homeTrash) {
            return true
        }
        if let trashURL = fileManager.urls(for: .trashDirectory, in: .userDomainMask).first,
           fileManager.isReadableFile(atPath: trashURL.path) {
            return true
        }
        let uid = getuid()
        if let volumeURLs = try? fileManager.contentsOfDirectory(
            at: URL(fileURLWithPath: "/Volumes"),
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            for volume in volumeURLs {
                let values = try? volume.resourceValues(forKeys: [.isDirectoryKey])
                guard values?.isDirectory == true else { continue }
                let trashPath = volume.path + "/.Trashes/\(uid)"
                if fileManager.isReadableFile(atPath: trashPath) {
                    return true
                }
            }
        }
        return false
    }
}
