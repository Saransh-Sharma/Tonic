//
//  AccessScopeModels.swift
//  Tonic
//
//  Security-scoped authorization models for Store Edition.
//

import Foundation

public enum AccessScopeKind: String, Codable, CaseIterable, Sendable {
    case startupDisk
    case applications
    case home
    case externalVolume
    case folder
}

public enum AccessScopeStatus: String, Codable, CaseIterable, Sendable {
    case active
    case staleBookmark
    case disconnected
    case invalid
}

public enum ScopeAccessState: String, Codable, CaseIterable, Sendable {
    case ready
    case needsAccess
    case limited
}

public enum ScopeBlockedReason: String, Codable, CaseIterable, Sendable {
    case missingScope
    case staleBookmark
    case disconnectedScope
    case sandboxReadDenied
    case sandboxWriteDenied
    case macOSProtected

    var userMessage: String {
        switch self {
        case .missingScope:
            return "Grant access to this location to continue."
        case .staleBookmark:
            return "This saved access is stale and must be re-authorized."
        case .disconnectedScope:
            return "The selected scope is unavailable (for example, an external drive is disconnected)."
        case .sandboxReadDenied:
            return "Tonic cannot read this location in the current sandbox configuration."
        case .sandboxWriteDenied:
            return "Tonic cannot modify this location in the current sandbox configuration."
        case .macOSProtected:
            return "This location is protected by macOS."
        }
    }
}

public struct AccessScope: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var displayName: String
    public var rootPath: String
    public var kind: AccessScopeKind
    public var bookmarkData: Data
    public var addedAt: Date
    public var lastVerifiedAt: Date?

    public init(
        id: UUID = UUID(),
        displayName: String,
        rootPath: String,
        kind: AccessScopeKind,
        bookmarkData: Data,
        addedAt: Date = Date(),
        lastVerifiedAt: Date? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.rootPath = rootPath
        self.kind = kind
        self.bookmarkData = bookmarkData
        self.addedAt = addedAt
        self.lastVerifiedAt = lastVerifiedAt
    }
}

public struct ScopeAccessEvaluation: Sendable {
    public let state: ScopeAccessState
    public let reason: ScopeBlockedReason?
    public let scope: AccessScope?

    public init(state: ScopeAccessState, reason: ScopeBlockedReason?, scope: AccessScope?) {
        self.state = state
        self.reason = reason
        self.scope = scope
    }
}

public struct ScopeCoverageSummary: Sendable {
    public let state: ScopeAccessState
    public let coveredPaths: [String]
    public let blockedPaths: [String: ScopeBlockedReason]

    public init(state: ScopeAccessState, coveredPaths: [String], blockedPaths: [String: ScopeBlockedReason]) {
        self.state = state
        self.coveredPaths = coveredPaths
        self.blockedPaths = blockedPaths
    }
}

public enum ScopeCoverageTier: String, Sendable {
    case minimal = "Minimal"
    case standard = "Standard"
    case fullMac = "Full Mac"
}
