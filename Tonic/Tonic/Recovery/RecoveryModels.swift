import Foundation

public enum RecoverySeverity: String, Codable, CaseIterable, Sendable {
    case healthy
    case information
    case warning
    case critical
}

public enum RecoveryDiagnosticID: String, Codable, CaseIterable, Sendable {
    case dns
    case network
    case spotlight
    case launchServices
    case finder
    case dock
    case systemUIServer
    case printing
    case audio
    case bluetooth
    case timeMachine
    case systemCaches
    case diagnosticReports
    case packageUpdates
}

public enum TonicUserService: String, Codable, CaseIterable, Hashable, Sendable {
    case finder = "Finder"
    case dock = "Dock"
    case systemUIServer = "SystemUIServer"
}

public enum RecoveryActionID: Codable, Equatable, Hashable, Sendable {
    case refreshDNS
    case renewPrimaryNetwork
    case rebuildSpotlightStartupDisk
    case rebuildLaunchServices
    case restartUserService(service: TonicUserService)
    case restartSystemService(service: TonicSystemService)
    case reclaimLocalSnapshots
    case purgeDocumentRevisions(minimumAgeDays: Int)
    case purgeStaleSystemData(domain: TonicCleanupDomain, minimumAgeDays: Int)

    public var title: String {
        switch self {
        case .refreshDNS: String(localized: "Refresh DNS resolution")
        case .renewPrimaryNetwork: String(localized: "Renew the active network service")
        case .rebuildSpotlightStartupDisk: String(localized: "Rebuild the startup-disk Spotlight index")
        case .rebuildLaunchServices: String(localized: "Rebuild application registration")
        case .restartUserService(let service): String(localized: "Restart \(service.rawValue)")
        case .restartSystemService(let service): String(localized: "Restart \(service.title)")
        case .reclaimLocalSnapshots: String(localized: "Reclaim local Time Machine snapshots")
        case .purgeDocumentRevisions: String(localized: "Remove stale document revisions")
        case .purgeStaleSystemData(let domain, _): String(localized: "Remove stale \(domain.title.lowercased())")
        }
    }

    public var requiresPrivilege: Bool {
        switch self {
        case .restartUserService, .rebuildLaunchServices: false
        default: true
        }
    }

    public var isDisruptive: Bool {
        switch self {
        case .refreshDNS, .purgeDocumentRevisions, .purgeStaleSystemData: false
        default: true
        }
    }

    public var estimatedDurationSeconds: Int {
        switch self {
        case .rebuildSpotlightStartupDisk: 300
        case .reclaimLocalSnapshots: 180
        case .purgeDocumentRevisions, .purgeStaleSystemData: 90
        default: 15
        }
    }

}

public extension TonicSystemService {
    var title: String {
        switch self {
        case .dnsResponder: String(localized: "DNS responder")
        case .audio: String(localized: "audio service")
        case .bluetooth: String(localized: "Bluetooth service")
        case .printing: String(localized: "print service")
        case .timeMachine: String(localized: "Time Machine service")
        }
    }
}

public extension TonicCleanupDomain {
    var title: String {
        switch self {
        case .systemCaches: String(localized: "System Caches")
        case .diagnosticReports: String(localized: "Diagnostic Reports")
        case .packageUpdates: String(localized: "Package Update Residue")
        }
    }
}

public struct RecoveryDiagnostic: Codable, Equatable, Identifiable, Sendable {
    public var id: RecoveryDiagnosticID
    public var title: String
    public var detail: String
    public var evidence: String
    public var severity: RecoverySeverity
    public var suggestedAction: RecoveryActionID?

    public init(id: RecoveryDiagnosticID, title: String, detail: String, evidence: String,
                severity: RecoverySeverity, suggestedAction: RecoveryActionID? = nil) {
        self.id = id
        self.title = title
        self.detail = detail
        self.evidence = evidence
        self.severity = severity
        self.suggestedAction = suggestedAction
    }
}

public struct RecoveryStep: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var action: RecoveryActionID
    public var reason: String
    public var expectedImpact: String
    public var recoveryBehavior: String
    public var isSelected: Bool
    public var isReportOnly: Bool

    public init(id: UUID = UUID(), action: RecoveryActionID, reason: String,
                expectedImpact: String, recoveryBehavior: String,
                isSelected: Bool = true, isReportOnly: Bool = false) {
        self.id = id
        self.action = action
        self.reason = reason
        self.expectedImpact = expectedImpact
        self.recoveryBehavior = recoveryBehavior
        self.isSelected = isSelected
        self.isReportOnly = isReportOnly
    }
}

public struct RecoveryPlan: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var createdAt: Date
    public var diagnosticsRevision: UUID
    public var steps: [RecoveryStep]

    public init(id: UUID = UUID(), createdAt: Date = Date(), diagnosticsRevision: UUID = UUID(),
                steps: [RecoveryStep]) {
        self.id = id
        self.createdAt = createdAt
        self.diagnosticsRevision = diagnosticsRevision
        self.steps = steps
    }

    public var selectedSteps: [RecoveryStep] { steps.filter(\.isSelected) }
}

public enum RecoveryStepStatus: String, Codable, Sendable {
    case succeeded
    case failed
    case skipped
    case reportOnly
}

public struct RecoveryStepResult: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID { stepID }
    public var stepID: UUID
    public var action: RecoveryActionID
    public var status: RecoveryStepStatus
    public var detail: String
    public var startedAt: Date
    public var completedAt: Date
    public var affectedItems: Int

    public init(stepID: UUID, action: RecoveryActionID, status: RecoveryStepStatus,
                detail: String, startedAt: Date, completedAt: Date, affectedItems: Int = 0) {
        self.stepID = stepID
        self.action = action
        self.status = status
        self.detail = detail
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.affectedItems = affectedItems
    }
}

public struct RecoveryExecutionResult: Codable, Equatable, Sendable {
    public var planID: UUID
    public var results: [RecoveryStepResult]
    public var stoppedAfterFailure: Bool

    public init(planID: UUID, results: [RecoveryStepResult], stoppedAfterFailure: Bool) {
        self.planID = planID
        self.results = results
        self.stoppedAfterFailure = stoppedAfterFailure
    }

    public var succeededCount: Int { results.filter { $0.status == .succeeded }.count }
    public var failedCount: Int { results.filter { $0.status == .failed }.count }
}
