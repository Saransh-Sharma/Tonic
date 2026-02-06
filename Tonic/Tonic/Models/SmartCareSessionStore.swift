import Foundation
import SwiftUI

struct SmartScanQuickActionSheetState: Identifiable {
    let id = UUID()
    let tileID: SmartScanTileID
    let action: SmartScanTileActionKind
    let scope: SmartScanQuickActionScope
    let title: String
    let subtitle: String
    let items: [SmartCareItem]
    let estimatedSpace: Int64
}

@MainActor
final class SmartCareSessionStore: ObservableObject {
    @Published var destination: Destination = .smartScan
    @Published var hubMode: SmartScanHubMode = .ready
    @Published var scanProgress: Double = 0
    @Published var runProgress: Double = 0
    @Published var currentStage: SmartScanStage = .space
    @Published var completedStages: [SmartScanStage] = []
    @Published var liveCounters: SmartScanLiveCounters = .zero
    @Published var scanResult: SmartCareResult?
    @Published var recommendedItemIDs: Set<UUID> = []
    @Published var selectedItemIDs: Set<UUID> = []
    @Published private(set) var runSummary: SmartScanRunSummary?
    @Published var quickActionSheet: SmartScanQuickActionSheetState?
    @Published var quickActionProgress: Double = 0
    @Published var quickActionSummary: SmartScanRunSummary?
    @Published var quickActionIsRunning = false

    private let engine = SmartCareEngine()
    private var scanTask: Task<Void, Never>?
    private var runTask: Task<Void, Never>?
    private var quickActionTask: Task<Void, Never>?

    deinit {
        scanTask?.cancel()
        runTask?.cancel()
        quickActionTask?.cancel()
    }

    var runSummaryText: String? {
        runSummary?.formattedSummary
    }

    var activeWorld: TonicWorld {
        switch destination {
        case .smartScan:
            return .smartScanPurple
        case .manager(let route):
            switch route {
            case .space(let focus):
                switch focus {
                case .clutter:
                    return .clutterTeal
                case .spaceRoot, .cleanup:
                    return .cleanupGreen
                }
            case .performance:
                return .performanceOrange
            case .apps:
                return .applicationsBlue
            }
        }
    }

    func reviewCustomize() {
        guard scanResult != nil else { return }
        destination = .manager(.space(.spaceRoot))
    }

    func review(target: SmartScanReviewTarget) {
        guard scanResult != nil else { return }
        destination = SmartScanDeepLinkMapper.destination(for: target)
    }

    func showHub() {
        destination = .smartScan
    }

    func startScan() {
        scanTask?.cancel()
        runTask?.cancel()
        quickActionTask?.cancel()

        destination = .smartScan
        hubMode = .scanning
        runSummary = nil
        scanResult = nil
        selectedItemIDs.removeAll()
        recommendedItemIDs.removeAll()

        scanProgress = 0
        runProgress = 0
        currentStage = .space
        completedStages = []
        liveCounters = .zero
        quickActionSheet = nil
        quickActionProgress = 0
        quickActionSummary = nil
        quickActionIsRunning = false

        scanTask = Task { [weak self] in
            guard let self else { return }
            let result = await self.engine.runSmartCareScan { update in
                Task { @MainActor [weak self] in
                    guard let self, self.hubMode == .scanning else { return }
                    self.scanProgress = update.progress
                    self.currentStage = update.currentStage
                    self.completedStages = update.completedStages
                    self.liveCounters = update.liveCounters
                }
            }

            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.scanResult = result
                self.recommendedItemIDs = Set(
                    result.domainResults.values
                        .flatMap { $0.items }
                        .filter { $0.safeToRun && $0.action.isRunnable && $0.isSmartSelected }
                        .map(\.id)
                )
                self.hubMode = .results
                self.currentStage = .apps
                self.completedStages = SmartScanStage.allCases
                self.scanProgress = 1
                self.liveCounters = SmartScanLiveCounters(
                    spaceBytesFound: result.domainResults[.cleanup]?.totalSize ?? 0,
                    performanceFlaggedCount: result.domainResults[.performance]?.totalUnitCount ?? 0,
                    appsScannedCount: result.domainResults[.applications]?.totalUnitCount ?? 0
                )
            }
        }
    }

    func stopCurrentOperation() {
        if quickActionIsRunning {
            stopQuickActionRun()
            return
        }

        switch hubMode {
        case .scanning:
            scanTask?.cancel()
            hubMode = .ready
            scanProgress = 0
            currentStage = .space
            completedStages = []
            liveCounters = .zero
        case .running:
            runTask?.cancel()
            hubMode = scanResult == nil ? .ready : .results
            runProgress = 0
        case .ready, .results:
            break
        }
    }

    func runSmartClean() {
        guard !quickActionIsRunning, quickActionSheet == nil else { return }
        guard let scanResult else { return }

        let recommended = runnableItems(in: scanResult, from: recommendedItemIDs)
        if !recommended.isEmpty {
            startRun(with: recommended)
            return
        }

        let fallback = scanResult.domainResults.values
            .flatMap { $0.items }
            .filter { $0.safeToRun && $0.action.isRunnable }
        startRun(with: fallback)
    }

    func runSelected(_ requestedItems: [SmartCareItem]) {
        guard !quickActionIsRunning, quickActionSheet == nil else { return }
        startRun(with: requestedItems)
    }

    func presentQuickAction(for tile: SmartScanTileID, action: SmartScanTileActionKind) {
        guard hubMode == .results, let scanResult else { return }
        guard !quickActionIsRunning, hubMode != .running else { return }

        let items = quickActionItems(for: tile, in: scanResult)
        let runnable = items.filter { $0.safeToRun && $0.action.isRunnable }
        quickActionSheet = SmartScanQuickActionSheetState(
            tileID: tile,
            action: action,
            scope: .tile(tile),
            title: quickActionTitle(for: tile, action: action),
            subtitle: quickActionSubtitle(for: tile, action: action, runnableCount: runnable.count),
            items: runnable,
            estimatedSpace: runnable.reduce(0) { $0 + $1.size }
        )
        quickActionProgress = 0
        quickActionSummary = nil
    }

    func startQuickActionRun() {
        guard let quickActionSheet else { return }
        guard !quickActionIsRunning, hubMode != .running else { return }

        if quickActionSheet.items.isEmpty {
            quickActionSummary = SmartScanRunSummary(
                tasksRun: 0,
                spaceFreed: 0,
                errors: 0,
                scoreImprovement: 0,
                message: "No runnable items available for this action."
            )
            return
        }

        quickActionTask?.cancel()
        quickActionProgress = 0
        quickActionSummary = nil
        quickActionIsRunning = true

        quickActionTask = Task { [weak self] in
            guard let self else { return }
            let summary = await self.performRun(items: quickActionSheet.items) { progress in
                self.quickActionProgress = progress
            }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.quickActionIsRunning = false
                self.quickActionProgress = 1
                self.quickActionSummary = summary
            }
        }
    }

    func stopQuickActionRun() {
        quickActionTask?.cancel()
        quickActionTask = nil
        quickActionIsRunning = false
        quickActionProgress = 0
        quickActionSummary = nil
    }

    func dismissQuickActionSummary() {
        quickActionTask?.cancel()
        quickActionTask = nil
        quickActionIsRunning = false
        quickActionProgress = 0
        quickActionSummary = nil
        quickActionSheet = nil
    }

    private func startRun(with requestedItems: [SmartCareItem]) {
        guard !quickActionIsRunning else { return }
        let items = requestedItems.filter { $0.safeToRun && $0.action.isRunnable }
        guard !items.isEmpty else { return }

        runTask?.cancel()
        destination = .smartScan
        hubMode = .running
        runProgress = 0
        runSummary = nil

        runTask = Task { [weak self] in
            guard let self else { return }
            let summary = await self.performRun(items: items) { progress in
                self.runProgress = progress
            }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.runSummary = summary
                self.runProgress = 1
                self.hubMode = .results
            }
        }
    }

    private func runnableItems(in result: SmartCareResult, from ids: Set<UUID>) -> [SmartCareItem] {
        result.domainResults.values
            .flatMap { $0.items }
            .filter { ids.contains($0.id) && $0.safeToRun && $0.action.isRunnable }
    }

    private func quickActionItems(for tile: SmartScanTileID, in result: SmartCareResult) -> [SmartCareItem] {
        let cleanup = result.domainResults[.cleanup]
        let performance = result.domainResults[.performance]
        let applications = result.domainResults[.applications]

        func cleanupItems(containing value: String) -> [SmartCareItem] {
            cleanup?.groups
                .filter { $0.title.lowercased().contains(value) }
                .flatMap(\.items) ?? []
        }

        func performanceItems(named group: String) -> [SmartCareItem] {
            performance?.groups.first(where: { $0.title == group })?.items ?? []
        }

        switch tile {
        case .spaceSystemJunk:
            return cleanupItems(containing: "system junk")
        case .spaceTrashBins:
            return cleanupItems(containing: "trash")
        case .spaceExtraBinaries:
            return cleanupItems(containing: "hidden")
        case .spaceXcodeJunk:
            return cleanupItems(containing: "xcode")
        case .performanceMaintenanceTasks:
            return performanceItems(named: "Maintenance Tasks")
        case .performanceLoginItems:
            return performanceItems(named: "Login Items")
        case .performanceBackgroundItems:
            return performanceItems(named: "Background Items")
        case .appsUpdates:
            return []
        case .appsUnused:
            return applications?.items.filter { $0.title.lowercased().contains("unused") } ?? []
        case .appsLeftovers:
            return applications?.items.filter { $0.title.lowercased().contains("orphaned") } ?? []
        case .appsInstallationFiles:
            return applications?.items.filter { $0.title.lowercased().contains("installation") || $0.title.lowercased().contains("large") } ?? []
        }
    }

    private func quickActionTitle(for tile: SmartScanTileID, action: SmartScanTileActionKind) -> String {
        let verb: String
        switch action {
        case .review: verb = "Review"
        case .clean: verb = "Clean"
        case .remove: verb = "Remove"
        case .run: verb = "Run"
        case .update: verb = "Update"
        }

        let subject: String
        switch tile {
        case .spaceSystemJunk: subject = "System Junk"
        case .spaceTrashBins: subject = "Trash Bins"
        case .spaceExtraBinaries: subject = "Extra Binaries"
        case .spaceXcodeJunk: subject = "Xcode Junk"
        case .performanceMaintenanceTasks: subject = "Maintenance Tasks"
        case .performanceLoginItems: subject = "Login Items"
        case .performanceBackgroundItems: subject = "Background Items"
        case .appsUpdates: subject = "App Updates"
        case .appsUnused: subject = "Unused Apps"
        case .appsLeftovers: subject = "App Leftovers"
        case .appsInstallationFiles: subject = "Installation Files"
        }

        return "\(verb) \(subject)"
    }

    private func quickActionSubtitle(for tile: SmartScanTileID, action: SmartScanTileActionKind, runnableCount: Int) -> String {
        if runnableCount == 0 {
            return "No runnable items were found for this tile."
        }

        let noun: String
        switch tile.pillar {
        case .space: noun = "cleanup items"
        case .performance: noun = "tasks"
        case .apps: noun = "app actions"
        }

        return "About to \(action.rawValue) \(runnableCount) \(noun)."
    }

    private func performRun(
        items: [SmartCareItem],
        progressUpdate: @MainActor @escaping (Double) -> Void
    ) async -> SmartScanRunSummary {
        var bytesFreed: Int64 = 0
        var errors = 0

        for (index, item) in items.enumerated() {
            if Task.isCancelled {
                break
            }

            switch item.action {
            case .delete(let paths):
                let uniquePaths = Array(Set(paths))
                let result = await FileOperations.shared.deleteFiles(atPaths: uniquePaths)
                bytesFreed += result.bytesFreed
                errors += result.errors.count
            case .runOptimization(let action):
                do {
                    let result = try await SystemOptimization.shared.performAction(action)
                    bytesFreed += result.bytesFreed
                } catch {
                    errors += 1
                }
            case .none:
                break
            }

            await MainActor.run {
                progressUpdate(Double(index + 1) / Double(items.count))
            }
        }

        let scoreGain = items.reduce(0) { $0 + $1.scoreImpact }
        return SmartScanRunSummary(
            tasksRun: items.count,
            spaceFreed: bytesFreed,
            errors: errors,
            scoreImprovement: scoreGain
        )
    }
}

struct SmartScanRunSummary {
    let tasksRun: Int
    let spaceFreed: Int64
    let errors: Int
    let scoreImprovement: Int
    var message: String? = nil

    var formattedSummary: String {
        if let message {
            return message
        }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        let sizeString = formatter.string(fromByteCount: spaceFreed)
        let errorString = errors > 0 ? " · \(errors) errors" : ""
        return "Ran \(tasksRun) tasks · Freed \(sizeString) · Score +\(scoreImprovement)\(errorString)"
    }
}
