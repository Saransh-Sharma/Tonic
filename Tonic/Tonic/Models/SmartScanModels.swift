//
//  SmartScanModels.swift
//  Tonic
//
//  Shared models for Smart Scan / Smart Care
//

import Foundation
import SwiftUI

// MARK: - Scan Stage

public enum ScanStage: String, CaseIterable, Identifiable {
    case preparing = "Preparing"
    case scanningDisk = "Scanning Disk"
    case checkingApps = "Checking Apps"
    case analyzingSystem = "Analyzing System"
    case complete = "Complete"

    public var id: String { rawValue }

    var icon: String {
        switch self {
        case .preparing: return "gearshape.2"
        case .scanningDisk: return "externaldrive.fill"
        case .checkingApps: return "app.badge"
        case .analyzingSystem: return "chart.line.uptrend.xyaxis"
        case .complete: return "checkmark.circle.fill"
        }
    }

    var progressWeight: Double {
        switch self {
        case .preparing: return 0.05
        case .scanningDisk: return 0.40
        case .checkingApps: return 0.30
        case .analyzingSystem: return 0.25
        case .complete: return 0.0
        }
    }
}

// MARK: - Scan Recommendation

public struct ScanRecommendation: Identifiable, Hashable, Sendable {
    public let id = UUID()
    let type: RecommendationType
    let title: String
    let description: String
    let actionable: Bool
    let safeToFix: Bool
    let spaceToReclaim: Int64
    let affectedPaths: [String]
    let scoreImpact: Int

    enum RecommendationType: String, CaseIterable {
        case cache = "Cache"
        case logs = "Logs"
        case tempFiles = "Temporary Files"
        case trash = "Trash"
        case oldFiles = "Old Files"
        case languageFiles = "Language Files"
        case duplicates = "Duplicates"
        case oldApps = "Unused Apps"
        case largeApps = "Large Apps"
        case largeFiles = "Large Files"
        case hiddenSpace = "Hidden Space"
        case launchAgents = "Launch Agents"
    }

    var formattedSpace: String {
        ByteCountFormatter.string(fromByteCount: spaceToReclaim, countStyle: .file)
    }

    var icon: String {
        switch type {
        case .cache: return "archivebox"
        case .logs: return "doc.text"
        case .tempFiles: return "clock"
        case .trash: return "trash"
        case .oldFiles: return "calendar"
        case .languageFiles: return "globe"
        case .duplicates: return "doc.on.doc"
        case .oldApps: return "app.badge"
        case .largeApps: return "arrow.up.app"
        case .largeFiles: return "arrow.up.doc"
        case .hiddenSpace: return "eye.slash"
        case .launchAgents: return "play.circle"
        }
    }

    var color: Color {
        switch type {
        case .cache, .tempFiles: return .blue
        case .logs: return .orange
        case .trash, .oldFiles: return .purple
        case .languageFiles: return .cyan
        case .duplicates: return .red
        case .oldApps, .largeApps: return .green
        case .largeFiles: return .yellow
        case .hiddenSpace: return .gray
        case .launchAgents: return .indigo
        }
    }
}

// MARK: - Smart Scan Result

public struct SmartScanResult: Sendable {
    let timestamp: Date
    let scanDuration: TimeInterval
    let diskUsage: DiskUsageSummary
    let recommendations: [ScanRecommendation]
    let totalSpaceToReclaim: Int64
    let systemHealthScore: Int // 0-100

    var formattedTotalSpace: String {
        ByteCountFormatter.string(fromByteCount: totalSpaceToReclaim, countStyle: .file)
    }

    var formattedDuration: String {
        String(format: "%.1f seconds", scanDuration)
    }

    var healthScoreColor: Color {
        switch systemHealthScore {
        case 80...100: return TonicColors.success
        case 60..<80: return TonicColors.warning
        default: return TonicColors.error
        }
    }
}

// MARK: - Disk Usage Summary

public struct DiskUsageSummary: Sendable {
    let totalSpace: Int64
    let usedSpace: Int64
    let freeSpace: Int64
    let homeDirectorySize: Int64
    let cacheSize: Int64
    let logSize: Int64
    let tempSize: Int64

    var usedPercentage: Double {
        guard totalSpace > 0 else { return 0 }
        return Double(usedSpace) / Double(totalSpace) * 100
    }

    var formattedTotalSpace: String {
        ByteCountFormatter.string(fromByteCount: totalSpace, countStyle: .file)
    }

    var formattedUsedSpace: String {
        ByteCountFormatter.string(fromByteCount: usedSpace, countStyle: .file)
    }

    var formattedFreeSpace: String {
        ByteCountFormatter.string(fromByteCount: freeSpace, countStyle: .file)
    }

    var formattedCacheSize: String {
        ByteCountFormatter.string(fromByteCount: cacheSize, countStyle: .file)
    }

    var formattedLogSize: String {
        ByteCountFormatter.string(fromByteCount: logSize, countStyle: .file)
    }

    var formattedTempSize: String {
        ByteCountFormatter.string(fromByteCount: tempSize, countStyle: .file)
    }
}

// MARK: - Fix Result

struct FixResult {
    let itemsFixed: Int
    let spaceFreed: Int64
    let errors: Int

    var message: String {
        let spaceStr = ByteCountFormatter.string(fromByteCount: spaceFreed, countStyle: .file)
        if errors > 0 {
            return "Fixed \(itemsFixed) items, freed \(spaceStr). \(errors) items had errors."
        }
        return "Successfully fixed \(itemsFixed) items and freed \(spaceStr)!"
    }
}
