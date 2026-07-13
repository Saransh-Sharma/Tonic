import Foundation

public enum TonicProviderPermission: String, Codable, CaseIterable, Hashable, Sendable {
    case network
    case location
    case calendar
    case files
    case keychainSecret
    case executableProcess
}

public enum TonicMarketplaceProviderKind: String, Codable, Sendable {
    case remoteJSON
    case executableBundle
}

public struct TonicProviderCompatibility: Codable, Equatable, Sendable {
    public var minimumOSMajor: Int
    public var architectures: Set<String>
    public var editions: Set<String>

    public init(minimumOSMajor: Int = 26, architectures: Set<String> = ["arm64", "x86_64"],
                editions: Set<String> = ["direct", "store"]) {
        self.minimumOSMajor = minimumOSMajor
        self.architectures = architectures
        self.editions = editions
    }

    public func supportsCurrentHost(edition: DistributionEdition = .current) -> Bool {
        let architecture = CompatibilityRuntime.current.architecture
        return ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= minimumOSMajor
            && architectures.contains(architecture) && editions.contains(edition.rawValue)
    }

    private enum CodingKeys: String, CodingKey { case minimumOSMajor, architectures, editions }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        minimumOSMajor = try container.decode(Int.self, forKey: .minimumOSMajor)
        architectures = Set(try container.decode([String].self, forKey: .architectures))
        editions = Set(try container.decode([String].self, forKey: .editions))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(minimumOSMajor, forKey: .minimumOSMajor)
        try container.encode(architectures.sorted(), forKey: .architectures)
        try container.encode(editions.sorted(), forKey: .editions)
    }
}

public struct TonicProviderRelease: Codable, Equatable, Identifiable, Sendable {
    public var id: String { version }
    public var version: String
    public var kind: TonicMarketplaceProviderKind
    public var artifactURL: URL
    public var sha256: String
    public var expectedTeamIdentifier: String?
    public var schemaRange: TonicProviderSchemaRange
    public var permissions: Set<TonicProviderPermission>
    public var endpoints: [URL]
    public var minimumRefreshSeconds: Double
    public var publishedAt: Date

    public init(version: String, kind: TonicMarketplaceProviderKind, artifactURL: URL,
                sha256: String, expectedTeamIdentifier: String? = nil,
                schemaRange: TonicProviderSchemaRange = .versionOne,
                permissions: Set<TonicProviderPermission> = [], endpoints: [URL] = [],
                minimumRefreshSeconds: Double = 60, publishedAt: Date = Date()) {
        self.version = version
        self.kind = kind
        self.artifactURL = artifactURL
        self.sha256 = sha256.lowercased()
        self.expectedTeamIdentifier = expectedTeamIdentifier
        self.schemaRange = schemaRange
        self.permissions = permissions
        self.endpoints = endpoints
        self.minimumRefreshSeconds = max(15, minimumRefreshSeconds)
        self.publishedAt = publishedAt
    }

    private enum CodingKeys: String, CodingKey {
        case version, kind, artifactURL, sha256, expectedTeamIdentifier, schemaRange
        case permissions, endpoints, minimumRefreshSeconds, publishedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(String.self, forKey: .version)
        kind = try container.decode(TonicMarketplaceProviderKind.self, forKey: .kind)
        artifactURL = try container.decode(URL.self, forKey: .artifactURL)
        sha256 = try container.decode(String.self, forKey: .sha256).lowercased()
        expectedTeamIdentifier = try container.decodeIfPresent(String.self, forKey: .expectedTeamIdentifier)
        schemaRange = try container.decode(TonicProviderSchemaRange.self, forKey: .schemaRange)
        permissions = Set(try container.decode([TonicProviderPermission].self, forKey: .permissions))
        endpoints = try container.decode([URL].self, forKey: .endpoints)
        minimumRefreshSeconds = max(15, try container.decode(Double.self, forKey: .minimumRefreshSeconds))
        publishedAt = try container.decode(Date.self, forKey: .publishedAt)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(kind, forKey: .kind)
        try container.encode(artifactURL, forKey: .artifactURL)
        try container.encode(sha256, forKey: .sha256)
        try container.encodeIfPresent(expectedTeamIdentifier, forKey: .expectedTeamIdentifier)
        try container.encode(schemaRange, forKey: .schemaRange)
        try container.encode(permissions.sorted { $0.rawValue < $1.rawValue }, forKey: .permissions)
        try container.encode(endpoints, forKey: .endpoints)
        try container.encode(minimumRefreshSeconds, forKey: .minimumRefreshSeconds)
        try container.encode(publishedAt, forKey: .publishedAt)
    }
}

public struct TonicMarketplaceEntry: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var providerName: String
    public var publisherName: String
    public var localizedDescriptions: [String: String]
    public var manifest: TonicDataSourceManifest
    public var compatibility: TonicProviderCompatibility
    public var releases: [TonicProviderRelease]

    public init(id: String, providerName: String, publisherName: String,
                localizedDescriptions: [String: String] = [:], manifest: TonicDataSourceManifest,
                compatibility: TonicProviderCompatibility = .init(), releases: [TonicProviderRelease]) {
        self.id = id
        self.providerName = providerName
        self.publisherName = publisherName
        self.localizedDescriptions = localizedDescriptions
        self.manifest = manifest
        self.compatibility = compatibility
        self.releases = releases
    }

    public var latestRelease: TonicProviderRelease? {
        releases.max { $0.publishedAt < $1.publishedAt }
    }
}

public struct TonicMarketplaceCatalog: Codable, Equatable, Sendable {
    public static let artifactKind = "tonic.marketplace.catalog"
    public var entries: [TonicMarketplaceEntry]
    public var revokedReleaseIDs: Set<String>

    public init(entries: [TonicMarketplaceEntry] = [], revokedReleaseIDs: Set<String> = []) {
        self.entries = entries
        self.revokedReleaseIDs = revokedReleaseIDs
    }

    private enum CodingKeys: String, CodingKey { case entries, revokedReleaseIDs }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        entries = try container.decode([TonicMarketplaceEntry].self, forKey: .entries)
        revokedReleaseIDs = Set(try container.decodeIfPresent([String].self, forKey: .revokedReleaseIDs) ?? [])
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(entries, forKey: .entries)
        try container.encode(revokedReleaseIDs.sorted(), forKey: .revokedReleaseIDs)
    }
}

public struct TonicProviderInstallPlan: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var entryID: String
    public var release: TonicProviderRelease
    public var permissionsToApprove: Set<TonicProviderPermission>
    public var replacesVersion: String?
    public var canInstallAutomatically: Bool

    public init(id: UUID = UUID(), entryID: String, release: TonicProviderRelease,
                permissionsToApprove: Set<TonicProviderPermission>, replacesVersion: String? = nil,
                canInstallAutomatically: Bool) {
        self.id = id
        self.entryID = entryID
        self.release = release
        self.permissionsToApprove = permissionsToApprove
        self.replacesVersion = replacesVersion
        self.canInstallAutomatically = canInstallAutomatically
    }
}

public struct TonicProviderInstallReceipt: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var providerID: String
    public var version: String
    public var installedAt: Date
    public var succeeded: Bool
    public var detail: String

    public init(id: UUID = UUID(), providerID: String, version: String,
                installedAt: Date = Date(), succeeded: Bool, detail: String) {
        self.id = id; self.providerID = providerID; self.version = version
        self.installedAt = installedAt; self.succeeded = succeeded; self.detail = detail
    }
}

public enum TonicProviderHealthState: String, Codable, Sendable {
    case healthy, staleResponse, timeout, invalidPayload, pausedFailures, revokedVersion
    case permissionExpansion, unsupportedSchema, signatureFailure, hostIncompatible
}

public struct TonicProviderDiagnostic: Codable, Equatable, Identifiable, Sendable {
    public var id: String { providerID }
    public var providerID: String
    public var state: TonicProviderHealthState
    public var detail: String
    public var checkedAt: Date

    public init(providerID: String, state: TonicProviderHealthState, detail: String, checkedAt: Date = Date()) {
        self.providerID = providerID; self.state = state; self.detail = detail; self.checkedAt = checkedAt
    }
}

public struct TonicMarketplaceInstalledState: Codable, Equatable, Sendable {
    public var providerID: String
    public var installedRelease: TonicProviderRelease
    public var approvedPermissions: Set<TonicProviderPermission>
    public var approvalRevision: Int64
    public var rollbackRelease: TonicProviderRelease?
    public var health: TonicProviderDiagnostic
}

public struct TonicMarketplaceState: Codable, Equatable, Sendable {
    public var catalogRevision: Int64
    public var installed: [String: TonicMarketplaceInstalledState]
    public var lastRefresh: Date?

    public init(catalogRevision: Int64 = 0, installed: [String: TonicMarketplaceInstalledState] = [:],
                lastRefresh: Date? = nil) {
        self.catalogRevision = catalogRevision; self.installed = installed; self.lastRefresh = lastRefresh
    }
}

public struct TonicMarketplaceCatalogCache: Codable, Equatable, Sendable {
    public var envelope: SignedArtifactEnvelope<TonicMarketplaceCatalog>?

    public init(envelope: SignedArtifactEnvelope<TonicMarketplaceCatalog>? = nil) {
        self.envelope = envelope
    }
}
