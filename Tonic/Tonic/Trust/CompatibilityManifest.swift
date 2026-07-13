import Darwin
import Foundation

public enum TonicPrivateCapability: String, Codable, CaseIterable, Sendable {
    case automaticSpaceContexts
    case foreignMenuProxy
    case systemNowPlaying
}

public struct CompatibilityRuntime: Codable, Equatable, Sendable {
    public var osBuild: String
    public var architecture: String

    public init(osBuild: String, architecture: String) {
        self.osBuild = osBuild
        self.architecture = architecture
    }

    public static var current: CompatibilityRuntime {
        CompatibilityRuntime(osBuild: Self.kernelBuild(), architecture: Self.machineArchitecture())
    }

    private static func kernelBuild() -> String {
        var size = 0
        guard sysctlbyname("kern.osversion", nil, &size, nil, 0) == 0, size > 1 else {
            return ProcessInfo.processInfo.operatingSystemVersionString
        }
        var bytes = [CChar](repeating: 0, count: size)
        guard sysctlbyname("kern.osversion", &bytes, &size, nil, 0) == 0 else {
            return ProcessInfo.processInfo.operatingSystemVersionString
        }
        let utf8 = bytes.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return String(decoding: utf8, as: UTF8.self)
    }

    private static func machineArchitecture() -> String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "unknown"
        #endif
    }
}

public struct CompatibilityRule: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var capability: TonicPrivateCapability
    public var allowedBuilds: Set<String>
    public var allowedArchitectures: Set<String>
    public var isEnabled: Bool
    public var reason: String

    public init(id: String, capability: TonicPrivateCapability,
                allowedBuilds: Set<String>, allowedArchitectures: Set<String> = ["arm64", "x86_64"],
                isEnabled: Bool, reason: String) {
        self.id = id
        self.capability = capability
        self.allowedBuilds = allowedBuilds
        self.allowedArchitectures = allowedArchitectures
        self.isEnabled = isEnabled
        self.reason = reason
    }

    public func matches(_ runtime: CompatibilityRuntime) -> Bool {
        allowedBuilds.contains(runtime.osBuild) && allowedArchitectures.contains(runtime.architecture)
    }

    private enum CodingKeys: String, CodingKey {
        case id, capability, allowedBuilds, allowedArchitectures, isEnabled, reason
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        capability = try container.decode(TonicPrivateCapability.self, forKey: .capability)
        allowedBuilds = Set(try container.decode([String].self, forKey: .allowedBuilds))
        allowedArchitectures = Set(try container.decode([String].self, forKey: .allowedArchitectures))
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        reason = try container.decode(String.self, forKey: .reason)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(capability, forKey: .capability)
        try container.encode(allowedBuilds.sorted(), forKey: .allowedBuilds)
        try container.encode(allowedArchitectures.sorted(), forKey: .allowedArchitectures)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(reason, forKey: .reason)
    }
}

public struct CompatibilityManifest: Codable, Equatable, Sendable {
    public static let artifactKind = "tonic.compatibility"

    public var rules: [CompatibilityRule]

    public init(rules: [CompatibilityRule]) {
        self.rules = rules
    }

    public func decision(for capability: TonicPrivateCapability,
                         runtime: CompatibilityRuntime = .current) -> PrivateCapabilityDecision {
        guard let rule = rules.first(where: { $0.capability == capability && $0.matches(runtime) }) else {
            return .disabled(reason: "Tonic has not validated this capability for macOS build \(runtime.osBuild).")
        }
        return rule.isEnabled ? .enabled(ruleID: rule.id) : .disabled(reason: rule.reason)
    }
}

public enum PrivateCapabilityDecision: Equatable, Sendable {
    case enabled(ruleID: String)
    case disabled(reason: String)

    public var isEnabled: Bool {
        if case .enabled = self { return true }
        return false
    }
}

public struct CompatibilityCache: Codable, Equatable, Sendable {
    public var envelope: SignedArtifactEnvelope<CompatibilityManifest>?
    public var eTag: String?
    public var lastCheckedAt: Date?

    public init(envelope: SignedArtifactEnvelope<CompatibilityManifest>? = nil,
                eTag: String? = nil, lastCheckedAt: Date? = nil) {
        self.envelope = envelope
        self.eTag = eTag
        self.lastCheckedAt = lastCheckedAt
    }
}
