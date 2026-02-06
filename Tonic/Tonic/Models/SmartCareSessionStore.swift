import Foundation
import SwiftUI

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

    private let engine = SmartCareEngine()
    private var scanTask: Task<Void, Never>?
    private var runTask: Task<Void, Never>?

    deinit {
        scanTask?.cancel()
        runTask?.cancel()
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
        startRun(with: requestedItems)
    }

    private func startRun(with requestedItems: [SmartCareItem]) {
        let items = requestedItems.filter { $0.safeToRun && $0.action.isRunnable }
        guard !items.isEmpty else { return }

        runTask?.cancel()
        destination = .smartScan
        hubMode = .running
        runProgress = 0
        runSummary = nil

        runTask = Task { [weak self] in
            guard let self else { return }
            let summary = await self.performRun(items: items)
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

    private func performRun(items: [SmartCareItem]) async -> SmartScanRunSummary {
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
                self.runProgress = Double(index + 1) / Double(items.count)
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

    var formattedSummary: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        let sizeString = formatter.string(fromByteCount: spaceFreed)
        let errorString = errors > 0 ? " · \(errors) errors" : ""
        return "Ran \(tasksRun) tasks · Freed \(sizeString) · Score +\(scoreImprovement)\(errorString)"
    }
}
