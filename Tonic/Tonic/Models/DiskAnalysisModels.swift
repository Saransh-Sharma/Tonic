//
//  DiskAnalysisModels.swift
//  Tonic
//
//  Models for disk analysis functionality
//

import Foundation

/// Represents a file or folder on disk with size information
struct DiskItem: Identifiable, Hashable {
    let id: UUID = UUID()
    let name: String
    let path: String
    let size: Int64
    let type: DiskItemType
    var children: [DiskItem] = []
    var isExpanded: Bool = false

    var sizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var icon: String {
        switch type {
        case .directory:
            return "folder.fill"
        case .file:
            return "doc.fill"
        case .package:
            return "archivebox.fill"
        }
    }
}

enum DiskItemType {
    case file
    case directory
    case package
}

/// Represents a disk analysis result
struct DiskAnalysisResult {
    let rootPath: String
    let rootItem: DiskItem
    let totalSize: Int64
    let scanDate: Date
    let duration: TimeInterval

    var totalSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
}

/// Represents a category of file types
struct FileCategory: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let extensions: [String]
    var totalSize: Int64 = 0
    var itemCount: Int = 0
    let color: String

    var sizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }

    static let commonCategories: [FileCategory] = [
        FileCategory(name: "Images", extensions: ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "webp", "heic"], totalSize: 0, itemCount: 0, color: "blue"),
        FileCategory(name: "Videos", extensions: ["mp4", "mov", "avi", "mkv", "flv", "wmv", "webm"], totalSize: 0, itemCount: 0, color: "purple"),
        FileCategory(name: "Audio", extensions: ["mp3", "m4a", "wav", "flac", "aac", "ogg"], totalSize: 0, itemCount: 0, color: "orange"),
        FileCategory(name: "Documents", extensions: ["pdf", "doc", "docx", "txt", "rtf", "pages"], totalSize: 0, itemCount: 0, color: "gray"),
        FileCategory(name: "Archives", extensions: ["zip", "rar", "7z", "tar", "gz", "bz2"], totalSize: 0, itemCount: 0, color: "brown"),
    ]
}

/// Configuration for disk scanning
struct DiskScanConfiguration {
    var includeHiddenFiles: Bool = false
    var includeSystemFiles: Bool = false
    var maxDepth: Int = 5
    var excludePatterns: [String] = []
    var minimumFileSize: Int64 = 0

    static let `default` = DiskScanConfiguration()
}

// MARK: - Storage Intelligence Hub Models

enum StorageScanMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case full = "Full"
    case quick = "Quick"
    case targeted = "Targeted"

    var id: String { rawValue }
}

enum StorageScanStatus: String, Codable, Sendable {
    case idle
    case preparing
    case scanning
    case indexing
    case completed
    case cancelled
    case failed
}

enum StorageNodeKind: String, Codable, Sendable {
    case file
    case directory
    case package
    case volume
    case synthetic
}

enum StorageRiskLevel: String, Codable, CaseIterable, Sendable {
    case low
    case medium
    case high
    case protected
}

enum StorageFileType: String, Codable, CaseIterable, Sendable, Identifiable {
    case image = "Image"
    case video = "Video"
    case audio = "Audio"
    case document = "Document"
    case archive = "Archive"
    case developer = "Developer"
    case application = "Application"
    case other = "Other"

    var id: String { rawValue }
}

enum StorageLastOpenedWindow: String, Codable, CaseIterable, Sendable, Identifiable {
    case any = "Any"
    case last7Days = "Last 7 days"
    case last30Days = "Last 30 days"
    case last90Days = "Last 90 days"
    case olderThan90Days = "Older than 90 days"

    var id: String { rawValue }
}

enum StorageDomain: String, Codable, CaseIterable, Sendable, Identifiable {
    case system = "System"
    case applications = "Apps"
    case userFiles = "User Files"
    case developer = "Developer"
    case cloud = "Cloud"
    case other = "Other"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .system: return "gearshape.2"
        case .applications: return "app.badge"
        case .userFiles: return "folder"
        case .developer: return "hammer"
        case .cloud: return "icloud"
        case .other: return "tray.2"
        }
    }
}

struct StorageNodeChildrenSummary: Codable, Hashable, Sendable {
    let totalChildren: Int
    let loadedChildren: Int
    let hasMore: Bool
}

struct StorageNode: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let path: String
    let name: String
    let kind: StorageNodeKind
    let logicalBytes: Int64
    let physicalBytes: Int64
    let childrenSummary: StorageNodeChildrenSummary
    let riskLevel: StorageRiskLevel
    let ownerApp: String?
    let domain: StorageDomain
    let fileType: StorageFileType
    let volumeID: String?
    let volumeName: String?
    let filesystemID: String?
    let depth: Int
    let isHidden: Bool
    let isDirectory: Bool
    let lastAccess: Date?
    let lastOpenedAt: Date?
    let lastOpenedEstimated: Bool
    let lastSizeRefreshAt: Date?
    let reclaimableBytes: Int64
    let sizeIsEstimated: Bool

    var displayBytes: String {
        ByteCountFormatter.string(fromByteCount: logicalBytes, countStyle: .file)
    }

    var displayReclaimableBytes: String {
        ByteCountFormatter.string(fromByteCount: reclaimableBytes, countStyle: .file)
    }
}

extension StorageNode {
    private enum CodingKeys: String, CodingKey {
        case id
        case path
        case name
        case kind
        case logicalBytes
        case physicalBytes
        case childrenSummary
        case riskLevel
        case ownerApp
        case domain
        case fileType
        case volumeID
        case volumeName
        case filesystemID
        case depth
        case isHidden
        case isDirectory
        case lastAccess
        case lastOpenedAt
        case lastOpenedEstimated
        case lastSizeRefreshAt
        case reclaimableBytes
        case sizeIsEstimated
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        path = try container.decode(String.self, forKey: .path)
        name = try container.decode(String.self, forKey: .name)
        kind = try container.decode(StorageNodeKind.self, forKey: .kind)
        logicalBytes = try container.decode(Int64.self, forKey: .logicalBytes)
        physicalBytes = try container.decode(Int64.self, forKey: .physicalBytes)
        childrenSummary = try container.decode(StorageNodeChildrenSummary.self, forKey: .childrenSummary)
        riskLevel = try container.decode(StorageRiskLevel.self, forKey: .riskLevel)
        ownerApp = try container.decodeIfPresent(String.self, forKey: .ownerApp)
        domain = try container.decode(StorageDomain.self, forKey: .domain)
        fileType = try container.decode(StorageFileType.self, forKey: .fileType)
        volumeID = try container.decodeIfPresent(String.self, forKey: .volumeID)
        volumeName = try container.decodeIfPresent(String.self, forKey: .volumeName)
        filesystemID = try container.decodeIfPresent(String.self, forKey: .filesystemID)
        depth = try container.decode(Int.self, forKey: .depth)
        isHidden = try container.decode(Bool.self, forKey: .isHidden)
        isDirectory = try container.decode(Bool.self, forKey: .isDirectory)
        lastAccess = try container.decodeIfPresent(Date.self, forKey: .lastAccess)
        lastOpenedAt = try container.decodeIfPresent(Date.self, forKey: .lastOpenedAt)
        lastOpenedEstimated = try container.decode(Bool.self, forKey: .lastOpenedEstimated)
        lastSizeRefreshAt = try container.decodeIfPresent(Date.self, forKey: .lastSizeRefreshAt)
        reclaimableBytes = try container.decode(Int64.self, forKey: .reclaimableBytes)
        sizeIsEstimated = try container.decodeIfPresent(Bool.self, forKey: .sizeIsEstimated) ?? false
    }
}

struct StorageScanScope: Codable, Hashable, Sendable {
    let rootPath: String
    let targetedPaths: [String]
}

struct StorageScanSession: Identifiable, Codable, Sendable {
    let id: UUID
    let mode: StorageScanMode
    let scope: StorageScanScope
    let startAt: Date
    var endAt: Date?
    var status: StorageScanStatus
    var confidence: Double
    var scannedBytes: Int64
    var scannedItems: Int64
    var indexedDirectories: Int64
    var indexedNodes: Int64
    var stageDurations: [String: TimeInterval]
    var filesPerSecond: Double
    var directoriesPerSecond: Double
    var eventBatchesPerSecond: Double
    var avgBatchLatency: Double
    var energyMode: String
    var warnings: [String]
}

extension StorageScanSession {
    private enum CodingKeys: String, CodingKey {
        case id
        case mode
        case scope
        case startAt
        case endAt
        case status
        case confidence
        case scannedBytes
        case scannedItems
        case indexedDirectories
        case indexedNodes
        case stageDurations
        case filesPerSecond
        case directoriesPerSecond
        case eventBatchesPerSecond
        case avgBatchLatency
        case energyMode
        case warnings
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        mode = try container.decode(StorageScanMode.self, forKey: .mode)
        scope = try container.decode(StorageScanScope.self, forKey: .scope)
        startAt = try container.decode(Date.self, forKey: .startAt)
        endAt = try container.decodeIfPresent(Date.self, forKey: .endAt)
        status = try container.decode(StorageScanStatus.self, forKey: .status)
        confidence = try container.decode(Double.self, forKey: .confidence)
        scannedBytes = try container.decode(Int64.self, forKey: .scannedBytes)
        scannedItems = try container.decode(Int64.self, forKey: .scannedItems)
        indexedDirectories = try container.decodeIfPresent(Int64.self, forKey: .indexedDirectories) ?? 0
        indexedNodes = try container.decodeIfPresent(Int64.self, forKey: .indexedNodes) ?? 0
        stageDurations = try container.decodeIfPresent([String: TimeInterval].self, forKey: .stageDurations) ?? [:]
        filesPerSecond = try container.decodeIfPresent(Double.self, forKey: .filesPerSecond) ?? 0
        directoriesPerSecond = try container.decodeIfPresent(Double.self, forKey: .directoriesPerSecond) ?? 0
        eventBatchesPerSecond = try container.decodeIfPresent(Double.self, forKey: .eventBatchesPerSecond) ?? 0
        avgBatchLatency = try container.decodeIfPresent(Double.self, forKey: .avgBatchLatency) ?? 0
        energyMode = try container.decodeIfPresent(String.self, forKey: .energyMode) ?? "adaptive"
        warnings = try container.decodeIfPresent([String].self, forKey: .warnings) ?? []
    }
}

enum StorageInsightCategory: String, Codable, CaseIterable, Sendable, Identifiable {
    case hidden = "Hidden Space"
    case purgeable = "Purgeable Space"
    case unknown = "Unknown Space"
    case system = "System"
    case applications = "Applications"
    case user = "User Files"
    case cleanup = "Cleanup Opportunity"

    var id: String { rawValue }
}

struct StorageInsight: Identifiable, Codable, Sendable {
    let id: UUID
    let category: StorageInsightCategory
    let bytes: Int64
    let confidence: Double
    let explanation: String
    let recommendedActions: [String]
    var blockedReason: ScopeBlockedReason?
}

enum CleanupActionType: String, Codable, CaseIterable, Sendable {
    case moveToTrash
    case secureDelete
    case excludeForever
}

struct CleanupCandidate: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    let nodeId: String
    let path: String
    let actionType: CleanupActionType
    let estimatedReclaimBytes: Int64
    let riskLevel: StorageRiskLevel
    let safeReason: String
    let blockedReason: ScopeBlockedReason?
    let selected: Bool

    private enum CodingKeys: String, CodingKey {
        case id
        case nodeId
        case path
        case actionType
        case estimatedReclaimBytes
        case riskLevel
        case safeReason
        case blockedReason
        case selected
    }

    init(
        id: UUID,
        nodeId: String,
        path: String,
        actionType: CleanupActionType,
        estimatedReclaimBytes: Int64,
        riskLevel: StorageRiskLevel,
        safeReason: String,
        blockedReason: ScopeBlockedReason?,
        selected: Bool
    ) {
        self.id = id
        self.nodeId = nodeId
        self.path = path
        self.actionType = actionType
        self.estimatedReclaimBytes = estimatedReclaimBytes
        self.riskLevel = riskLevel
        self.safeReason = safeReason
        self.blockedReason = blockedReason
        self.selected = selected
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        nodeId = try container.decode(String.self, forKey: .nodeId)
        path = try container.decode(String.self, forKey: .path)
        actionType = try container.decode(CleanupActionType.self, forKey: .actionType)
        estimatedReclaimBytes = try container.decode(Int64.self, forKey: .estimatedReclaimBytes)
        riskLevel = try container.decode(StorageRiskLevel.self, forKey: .riskLevel)
        safeReason = try container.decode(String.self, forKey: .safeReason)
        selected = try container.decode(Bool.self, forKey: .selected)

        if let typed = try container.decodeIfPresent(ScopeBlockedReason.self, forKey: .blockedReason) {
            blockedReason = typed
        } else if let legacy = try container.decodeIfPresent(String.self, forKey: .blockedReason) {
            blockedReason = Self.mapLegacyBlockedReason(legacy)
        } else {
            blockedReason = nil
        }
    }

    private static func mapLegacyBlockedReason(_ value: String) -> ScopeBlockedReason? {
        if let exact = ScopeBlockedReason(rawValue: value) {
            return exact
        }

        let normalized = value.lowercased()
        if normalized.contains("duplicate") || normalized.contains("excluded") {
            return .missingScope
        }
        if normalized.contains("protected") {
            return .macOSProtected
        }
        if normalized.contains("write") {
            return .sandboxWriteDenied
        }
        if normalized.contains("stale") {
            return .staleBookmark
        }
        if normalized.contains("disconnect") {
            return .disconnectedScope
        }
        if normalized.contains("scope") || normalized.contains("access") {
            return .missingScope
        }
        return nil
    }
}

struct CleanupCandidateGroup: Identifiable, Sendable {
    let id: String
    let domain: StorageDomain
    let actionType: CleanupActionType
    let items: [CleanupCandidate]
    let reclaimableBytes: Int64
}

struct CleanupExecutionResult: Codable, Sendable {
    let cleanedBytes: Int64
    let cleanedItems: Int
    let excludedItems: Int
    let excludedBytes: Int64
    let failedItems: Int
    let failures: [String]
    let beforeUsedBytes: Int64?
    let afterUsedBytes: Int64?
    let completedAt: Date
}

struct CleanupPlan: Identifiable, Codable, Sendable {
    let id: UUID
    let items: [CleanupCandidate]
    let mode: CleanupActionType
    let dryRunResult: CleanupExecutionResult?
    let executionResult: CleanupExecutionResult?
    let undoToken: String?
}

struct StorageReclaimPack: Identifiable, Codable, Sendable {
    let id: UUID
    let title: String
    let rationale: String
    let reclaimableBytes: Int64
    let paths: [String]
    let riskLevel: StorageRiskLevel
}

struct GuidedCleanupStep: Identifiable, Sendable {
    let id: UUID
    let title: String
    let subtitle: String
    let packs: [StorageReclaimPack]
    let totalBytes: Int64
}

struct StorageScanHistoryEntry: Identifiable, Codable, Sendable {
    let id: UUID
    let finishedAt: Date
    let rootPath: String
    let mode: StorageScanMode
    let reclaimedBytes: Int64
    let scannedBytes: Int64
    let confidence: Double
    let volumeUsedBytes: Int64?
    let volumeTotalBytes: Int64?
    let domainBreakdown: [String: Int64]?
    let scanDuration: TimeInterval?
}

struct StorageFilterState: Codable, Sendable {
    var minBytes: Int64 = 0
    var domains: Set<StorageDomain> = Set(StorageDomain.allCases)
    var riskLevels: Set<StorageRiskLevel> = Set(StorageRiskLevel.allCases)
    var fileTypes: Set<StorageFileType> = Set(StorageFileType.allCases)
    var volumes: Set<String> = []
    var includeHidden: Bool = false
    var includeSystem: Bool = true
    var onlyReclaimable: Bool = false
    var minAgeDays: Int?
    var lastOpenedWindow: StorageLastOpenedWindow = .any
    var lastOpenedIsStrict: Bool = false
    var ownerApps: Set<String> = []
    var searchText: String = ""
}

enum ScanEvent: Sendable {
    case phaseStarted(String)
    case progress(filesScanned: Int64, bytesScanned: Int64, currentPath: String)
    case nodeIndexed(StorageNode)
    case nodeIndexedBatch([StorageNode])
    case insightReady(StorageInsight)
    case warning(String)
    case completed(StorageScanSession)
    case cancelled
}

struct ScanPerformancePolicy: Sendable {
    var minWorkers: Int
    var maxWorkers: Int
    var maxBatchSize: Int
    var progressEmitInterval: TimeInterval
    var eventBatchSize: Int
    var eventEmitInterval: TimeInterval
    var energyMode: String

    static let adaptiveDefault = ScanPerformancePolicy(
        minWorkers: 2,
        maxWorkers: 8,
        maxBatchSize: 512,
        progressEmitInterval: 0.35,
        eventBatchSize: 200,
        eventEmitInterval: 0.2,
        energyMode: "adaptive"
    )
}

struct ScanProgressSnapshot: Sendable {
    var scannedItems: Int64
    var scannedBytes: Int64
    var indexedDirectories: Int64
    var indexedNodes: Int64
    var currentPath: String
}

struct StorageDomainDelta: Identifiable, Sendable {
    let id: String
    let domain: StorageDomain
    let bytesDelta: Int64
}

struct StorageTimeShiftSummary: Sendable {
    let baselineDate: Date
    let totalBytesDelta: Int64
    let reclaimableBytesDelta: Int64
    let domainDeltas: [StorageDomainDelta]
    let narrative: String
}

struct StorageForecast: Sendable {
    let estimatedDaysToFull: Int?
    let projectedFullDate: Date?
    let avgDailyGrowthBytes: Int64
    let confidence: Double
    let narrative: String
}

enum StorageAnomalySeverity: String, Sendable {
    case info
    case warning
    case critical
}

struct StorageAnomaly: Identifiable, Sendable {
    let id: UUID
    let detectedAt: Date
    let path: String
    let bytesDelta: Int64
    let severity: StorageAnomalySeverity
    let likelyCause: String
    let recommendation: String
}

enum StoragePersona: String, CaseIterable, Identifiable, Sendable {
    case developer = "Developer"
    case creator = "Creator"
    case gamer = "Gamer"
    case office = "Office User"

    var id: String { rawValue }
}

struct StoragePersonaBundle: Identifiable, Sendable {
    let id: UUID
    let persona: StoragePersona
    let title: String
    let rationale: String
    let reclaimableBytes: Int64
    let candidatePaths: [String]
    let riskLevel: StorageRiskLevel
}

enum HygieneFrequency: String, CaseIterable, Identifiable, Sendable {
    case weekly = "Weekly"
    case biweekly = "Biweekly"
    case monthly = "Monthly"

    var id: String { rawValue }
}

struct StorageHygieneRoutine: Identifiable, Sendable {
    let id: UUID
    let title: String
    let description: String
    let frequency: HygieneFrequency
    var isEnabled: Bool
    var nextRunAt: Date?
    var lastRunAt: Date?
    let guardrails: [String]
    let templateAction: CleanupActionType
}

struct StorageLiveHotspot: Identifiable, Sendable {
    let id: UUID
    let path: String
    let bytesPerSecond: Int64
    let estimatedReadMBps: Double
    let estimatedWriteMBps: Double
    let sourceLabel: String
    let riskLevel: StorageRiskLevel
    let sourceConfidence: StorageTelemetryConfidence
}

struct StorageVolumeIOHistoryPoint: Identifiable, Sendable {
    let id: UUID
    let date: Date
    let readMBps: Double
    let writeMBps: Double
    let utilization: Double
}

struct StorageProcessDelta: Identifiable, Sendable {
    let id: UUID
    let processName: String
    let bytesPerSecond: Int64
    let paths: [String]
    let observedAt: Date
    let sourceConfidence: StorageTelemetryConfidence
}

enum StorageTelemetryConfidence: String, Codable, Sendable {
    case measured
    case estimated
}
