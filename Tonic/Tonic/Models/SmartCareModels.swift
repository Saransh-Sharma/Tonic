//
//  SmartCareModels.swift
//  Tonic
//
//  Domain models for Smart Care scan and review experience
//

import Foundation
import SwiftUI

// MARK: - Smart Scan Pillar

enum SmartScanStage: String, CaseIterable, Identifiable, Sendable {
    case space = "Space"
    case performance = "Performance"
    case apps = "Apps"

    var id: String { rawValue }
}

struct SmartScanLiveCounters: Sendable {
    var spaceBytesFound: Int64
    var performanceFlaggedCount: Int
    var appsScannedCount: Int

    static let zero = SmartScanLiveCounters(spaceBytesFound: 0, performanceFlaggedCount: 0, appsScannedCount: 0)
}

// MARK: - Smart Care Domain

enum SmartCareDomain: String, CaseIterable, Identifiable, Sendable {
    case cleanup
    case performance
    case applications

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cleanup: return "Cleanup"
        case .performance: return "Performance"
        case .applications: return "Applications"
        }
    }

    var icon: String {
        switch self {
        case .cleanup: return "trash.fill"
        case .performance: return "bolt.fill"
        case .applications: return "app.badge.fill"
        }
    }
}

// MARK: - Smart Care Action

enum SmartCareAction: Hashable, Sendable {
    case delete(paths: [String])
    case runOptimization(OptimizationAction)
    case none

    var isRunnable: Bool {
        switch self {
        case .delete, .runOptimization:
            return true
        case .none:
            return false
        }
    }
}

// MARK: - Smart Care Data Class

/// Classifies an item by recoverability policy. Personal files are routed to the
/// macOS Trash (recoverable via Put Back / in-app Restore); system junk is removed
/// permanently so the reclaimed space is actually freed immediately.
enum SmartCareDataClass: String, Hashable, Sendable {
    /// User-owned, irreplaceable content (duplicates, large/old files, downloads,
    /// mail attachments, app leftovers). Deleted to Trash, never permanently.
    case personal
    /// Regenerable system junk (caches, logs, temp files, dev artifacts). Removed
    /// permanently — trashing it would not free space until the Trash is emptied.
    case systemJunk

    /// Whether deleting this class requires the review-before-removing sheet.
    var requiresReview: Bool { self == .personal }

    /// Whether deletion is recoverable (moved to Trash) vs permanent.
    var isRecoverable: Bool { self == .personal }
}

// MARK: - Smart Care Selection

enum SmartCareSelectionPolicy: Hashable, Sendable {
    case standard
    case keepOneCopy

    func validatedSelection(proposed: Set<String>, orderedChildIDs: [String]) -> Set<String> {
        guard self == .keepOneCopy, orderedChildIDs.count > 1 else {
            return proposed
        }

        let validIDs = Set(orderedChildIDs)
        var selection = proposed.intersection(validIDs)
        guard selection.count >= orderedChildIDs.count else {
            return selection
        }

        selection.remove(orderedChildIDs[0])
        return selection
    }
}

enum SmartCareSelectionProjection {
    static func uniqueOrderedPaths(_ paths: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for path in paths where !seen.contains(path) {
            seen.insert(path)
            result.append(path)
        }
        return result
    }

    static func selectedDeletePaths(for item: SmartCareItem, selectedChildIDs: Set<String>) -> [String] {
        let paths = uniqueOrderedPaths(item.paths)
        let validatedSelection = item.selectionPolicy.validatedSelection(
            proposed: selectedChildIDs,
            orderedChildIDs: paths
        )
        return paths.filter { validatedSelection.contains($0) }
    }

    static func projectedSize(for item: SmartCareItem, selectedPathCount: Int, totalPathCount: Int) -> Int64 {
        guard item.size > 0, selectedPathCount > 0 else { return 0 }
        let fullCount = max(totalPathCount, 1)
        let denominator = item.selectionPolicy == .keepOneCopy ? max(fullCount - 1, 1) : fullCount
        let proportion = min(1, Double(selectedPathCount) / Double(denominator))
        return max(1, Int64((Double(item.size) * proportion).rounded()))
    }
}

// MARK: - Smart Care Item

struct SmartCareItem: Identifiable, Hashable, Sendable {
    let id: UUID
    let domain: SmartCareDomain
    let groupId: UUID
    let title: String
    let subtitle: String
    let size: Int64
    let count: Int
    let safeToRun: Bool
    let isSmartSelected: Bool
    let action: SmartCareAction
    let paths: [String]
    let scoreImpact: Int
    let accessState: ScopeAccessState
    let blockedReason: ScopeBlockedReason?
    let selectionPolicy: SmartCareSelectionPolicy
    let dataClass: SmartCareDataClass

    init(
        id: UUID = UUID(),
        domain: SmartCareDomain,
        groupId: UUID,
        title: String,
        subtitle: String,
        size: Int64,
        count: Int,
        safeToRun: Bool,
        isSmartSelected: Bool,
        action: SmartCareAction,
        paths: [String],
        scoreImpact: Int,
        accessState: ScopeAccessState = .ready,
        blockedReason: ScopeBlockedReason? = nil,
        selectionPolicy: SmartCareSelectionPolicy = .standard,
        dataClass: SmartCareDataClass = .systemJunk
    ) {
        self.id = id
        self.domain = domain
        self.groupId = groupId
        self.title = title
        self.subtitle = subtitle
        self.size = size
        self.count = count
        self.safeToRun = safeToRun
        self.isSmartSelected = isSmartSelected
        self.action = action
        self.paths = paths
        self.scoreImpact = scoreImpact
        self.accessState = accessState
        self.blockedReason = blockedReason
        self.selectionPolicy = selectionPolicy
        self.dataClass = dataClass
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var effectiveCount: Int {
        count > 0 ? count : 1
    }
}

// MARK: - Smart Care Group

/// Structured reason a group has no actionable items, so views can render the
/// right empty state without string-matching the description copy.
enum SmartCareEmptyState: String, Hashable, Sendable {
    case nothingFound
    case needsAccess
    case partial
    case labsPreview
}

struct SmartCareGroup: Identifiable, Hashable, Sendable {
    let id: UUID
    let domain: SmartCareDomain
    let title: String
    let description: String
    let items: [SmartCareItem]
    let emptyState: SmartCareEmptyState?

    init(
        id: UUID = UUID(),
        domain: SmartCareDomain,
        title: String,
        description: String,
        items: [SmartCareItem],
        emptyState: SmartCareEmptyState? = nil
    ) {
        self.id = id
        self.domain = domain
        self.title = title
        self.description = description
        self.items = items
        self.emptyState = emptyState
    }
}

// MARK: - Smart Care Domain Result

struct SmartCareDomainResult: Sendable {
    let domain: SmartCareDomain
    let groups: [SmartCareGroup]

    var items: [SmartCareItem] {
        groups.flatMap { $0.items }
    }

    var totalSize: Int64 {
        items.reduce(0) { $0 + $1.size }
    }

    var totalUnitCount: Int {
        items.reduce(0) { $0 + $1.effectiveCount }
    }

    var scoreImpact: Int {
        items.reduce(0) { $0 + $1.scoreImpact }
    }

    var hasRunnableItems: Bool {
        items.contains(where: { $0.safeToRun && $0.action.isRunnable })
    }
}

// MARK: - Smart Care Result

struct SmartCareResult: Sendable {
    let timestamp: Date
    let duration: TimeInterval
    let domainResults: [SmartCareDomain: SmartCareDomainResult]
    /// Finder-vs-du analysis from the hidden-space scan: where "missing"
    /// space actually went (snapshots, purgeable, sparse files).
    var hiddenSpaceReport: DiskDiscrepancyReport?

    var totalScoreImpact: Int {
        domainResults.values.reduce(0) { $0 + $1.scoreImpact }
    }

    var totalReclaimableSize: Int64 {
        domainResults.values.reduce(0) { $0 + $1.totalSize }
    }
}

// MARK: - Smart Care Scan Update

struct SmartCareScanUpdate: Sendable {
    let domain: SmartCareDomain
    let title: String
    let detail: String
    let progress: Double
    let currentItem: String?
    let currentStage: SmartScanStage
    let completedStages: [SmartScanStage]
    let spaceBytesFound: Int64
    let performanceFlaggedCount: Int
    let appsScannedCount: Int

    var liveCounters: SmartScanLiveCounters {
        SmartScanLiveCounters(
            spaceBytesFound: spaceBytesFound,
            performanceFlaggedCount: performanceFlaggedCount,
            appsScannedCount: appsScannedCount
        )
    }

    init(
        domain: SmartCareDomain,
        title: String,
        detail: String,
        progress: Double,
        currentItem: String?,
        currentStage: SmartScanStage = .space,
        completedStages: [SmartScanStage] = [],
        spaceBytesFound: Int64 = 0,
        performanceFlaggedCount: Int = 0,
        appsScannedCount: Int = 0
    ) {
        self.domain = domain
        self.title = title
        self.detail = detail
        self.progress = progress
        self.currentItem = currentItem
        self.currentStage = currentStage
        self.completedStages = completedStages
        self.spaceBytesFound = spaceBytesFound
        self.performanceFlaggedCount = performanceFlaggedCount
        self.appsScannedCount = appsScannedCount
    }
}
