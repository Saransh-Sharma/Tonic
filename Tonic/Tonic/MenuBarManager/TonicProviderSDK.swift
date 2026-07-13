import Foundation

public enum TonicProviderCoding {
    public static func encoder() -> JSONEncoder { let value = JSONEncoder(); value.dateEncodingStrategy = .iso8601; return value }
    public static func decoder() -> JSONDecoder { let value = JSONDecoder(); value.dateDecodingStrategy = .iso8601; return value }
}

public enum TonicProviderCapability: String, Codable, CaseIterable, Sendable {
    case label, symbol, image, accessibilityText, freshness, semanticStatus
}

public enum TonicProviderSemanticStatus: String, Codable, Sendable {
    case neutral, good, warning, critical, unavailable
}

public struct TonicProviderSchemaRange: Codable, Equatable, Hashable, Sendable {
    public var minimum: Int
    public var maximum: Int

    public init(minimum: Int, maximum: Int) {
        self.minimum = max(1, minimum)
        self.maximum = max(self.minimum, maximum)
    }

    public func overlap(with other: Self) -> Self? {
        let lower = max(minimum, other.minimum)
        let upper = min(maximum, other.maximum)
        return lower <= upper ? Self(minimum: lower, maximum: upper) : nil
    }

    public func contains(_ version: Int) -> Bool { (minimum...maximum).contains(version) }
    public static let hostSupported = Self(minimum: 1, maximum: 2)
    public static let versionOne = Self(minimum: 1, maximum: 1)
}

public struct TonicDataSourceManifest: Codable, Identifiable, Equatable, Sendable {
    public static let currentSchemaVersion = 1
    public var id: String
    public var schemaVersion: Int
    public var supportedSchemaRange: TonicProviderSchemaRange
    public var displayName: String
    public var providerVersion: String
    public var minimumRefreshSeconds: Double
    public var capabilities: Set<TonicProviderCapability>

    public init(id: String, schemaVersion: Int = Self.currentSchemaVersion,
                supportedSchemaRange: TonicProviderSchemaRange? = nil, displayName: String,
                providerVersion: String, minimumRefreshSeconds: Double = 60,
                capabilities: Set<TonicProviderCapability>) {
        self.id = id; self.schemaVersion = schemaVersion
        self.supportedSchemaRange = supportedSchemaRange ?? .init(minimum: schemaVersion, maximum: schemaVersion)
        self.displayName = displayName
        self.providerVersion = providerVersion
        self.minimumRefreshSeconds = max(15, minimumRefreshSeconds)
        self.capabilities = capabilities
    }

    private enum CodingKeys: String, CodingKey {
        case id, schemaVersion, supportedSchemaRange, displayName, providerVersion
        case minimumRefreshSeconds, capabilities
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        supportedSchemaRange = try container.decodeIfPresent(TonicProviderSchemaRange.self,
                                                               forKey: .supportedSchemaRange)
            ?? .init(minimum: schemaVersion, maximum: schemaVersion)
        displayName = try container.decode(String.self, forKey: .displayName)
        providerVersion = try container.decode(String.self, forKey: .providerVersion)
        minimumRefreshSeconds = max(15, try container.decodeIfPresent(Double.self,
                                                                       forKey: .minimumRefreshSeconds) ?? 60)
        capabilities = try container.decode(Set<TonicProviderCapability>.self, forKey: .capabilities)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(supportedSchemaRange, forKey: .supportedSchemaRange)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(providerVersion, forKey: .providerVersion)
        try container.encode(minimumRefreshSeconds, forKey: .minimumRefreshSeconds)
        try container.encode(capabilities.sorted { $0.rawValue < $1.rawValue }, forKey: .capabilities)
    }
}

public struct TonicDataSourceRequest: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1
    public var schemaVersion: Int
    public var requestID: UUID
    public var providerID: String
    public var requestedAt: Date
    public var localeIdentifier: String

    public init(schemaVersion: Int = Self.currentSchemaVersion, requestID: UUID = UUID(),
                providerID: String, requestedAt: Date = Date(),
                localeIdentifier: String = Locale.current.identifier) {
        self.schemaVersion = schemaVersion; self.requestID = requestID; self.providerID = providerID
        self.requestedAt = requestedAt; self.localeIdentifier = localeIdentifier
    }
}

public struct TonicDataSourceSnapshot: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1
    public var schemaVersion: Int
    public var requestID: UUID?
    public var label: String?
    public var symbolName: String?
    public var imageReference: URL?
    public var accessibilityText: String?
    public var generatedAt: Date
    public var expiresAt: Date?
    public var status: TonicProviderSemanticStatus

    public init(schemaVersion: Int = Self.currentSchemaVersion, requestID: UUID? = nil,
                label: String? = nil, symbolName: String? = nil, imageReference: URL? = nil,
                accessibilityText: String? = nil, generatedAt: Date = Date(), expiresAt: Date? = nil,
                status: TonicProviderSemanticStatus = .neutral) {
        self.schemaVersion = schemaVersion; self.requestID = requestID
        self.label = Self.sanitize(label, limit: 64); self.symbolName = Self.sanitize(symbolName, limit: 128)
        self.imageReference = imageReference; self.accessibilityText = Self.sanitize(accessibilityText, limit: 256)
        self.generatedAt = generatedAt; self.expiresAt = expiresAt; self.status = status
    }

    public var isFresh: Bool { expiresAt.map { $0 > Date() } ?? true }

    private static func sanitize(_ value: String?, limit: Int) -> String? {
        guard let value else { return nil }
        let clean = String(value.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) })
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? nil : String(clean.prefix(limit))
    }
}

public protocol TonicDataSourceProvider: Sendable {
    var manifest: TonicDataSourceManifest { get }
    func snapshot(for request: TonicDataSourceRequest) async throws -> TonicDataSourceSnapshot
}

public enum TonicProviderRegistryError: Error, Equatable {
    case duplicateID, unknownProvider, invalidManifest, pausedAfterFailures
}

public enum TonicProviderManifestPolicy {
    public static func isValid(_ manifest: TonicDataSourceManifest) -> Bool {
        guard manifest.supportedSchemaRange.overlap(with: .hostSupported) != nil,
              (1...128).contains(manifest.id.count), (1...80).contains(manifest.displayName.count),
              (1...64).contains(manifest.providerVersion.count), manifest.minimumRefreshSeconds >= 15,
              !manifest.capabilities.isEmpty else { return false }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
        let boundary = CharacterSet.alphanumerics
        return manifest.id.unicodeScalars.allSatisfy(allowed.contains)
            && manifest.id.unicodeScalars.first.map(boundary.contains) == true
            && manifest.id.unicodeScalars.last.map(boundary.contains) == true
            && !manifest.id.contains("..")
    }
}

public actor TonicProviderRegistry {
    public static let shared = TonicProviderRegistry()
    private var providers: [String: any TonicDataSourceProvider] = [:]
    private var cachedSnapshots: [String: TonicDataSourceSnapshot] = [:]
    private var fetchedAt: [String: Date] = [:]
    private var failureCounts: [String: Int] = [:]

    public init() {}
    public func register(_ provider: any TonicDataSourceProvider) throws {
        guard TonicProviderManifestPolicy.isValid(provider.manifest) else {
            throw TonicProviderRegistryError.invalidManifest
        }
        guard providers[provider.manifest.id] == nil else { throw TonicProviderRegistryError.duplicateID }
        providers[provider.manifest.id] = provider
    }
    public func unregister(id: String) {
        providers.removeValue(forKey: id); cachedSnapshots.removeValue(forKey: id); fetchedAt.removeValue(forKey: id)
        failureCounts.removeValue(forKey: id)
    }
    public func manifests() -> [TonicDataSourceManifest] { providers.values.map(\.manifest).sorted { $0.id < $1.id } }
    public func snapshot(providerID: String, request: TonicDataSourceRequest) async throws -> TonicDataSourceSnapshot {
        guard let provider = providers[providerID] else { throw TonicProviderRegistryError.unknownProvider }
        guard failureCounts[providerID, default: 0] < 3 else {
            throw TonicProviderRegistryError.pausedAfterFailures
        }
        guard provider.manifest.supportedSchemaRange.contains(request.schemaVersion),
              TonicProviderSchemaRange.hostSupported.contains(request.schemaVersion),
              request.providerID == providerID else { throw TonicProviderRegistryError.invalidManifest }
        if let fetched = fetchedAt[providerID], let cached = cachedSnapshots[providerID],
           Date().timeIntervalSince(fetched) < provider.manifest.minimumRefreshSeconds {
            var response = cached; response.requestID = request.requestID; return response
        }
        do {
            let snapshot = try await provider.snapshot(for: request)
            cachedSnapshots[providerID] = snapshot; fetchedAt[providerID] = Date(); failureCounts[providerID] = 0
            return snapshot
        } catch {
            failureCounts[providerID, default: 0] += 1
            throw error
        }
    }
    public func resumeAfterReview(providerID: String) { failureCounts[providerID] = 0 }
    public func isPaused(providerID: String) -> Bool { failureCounts[providerID, default: 0] >= 3 }
}

public actor TonicBuiltInMetricsProvider: TonicDataSourceProvider {
    public enum Kind: String, CaseIterable, Sendable { case battery, cpu, memory, network, weather }
    public nonisolated let manifest: TonicDataSourceManifest
    private let kind: Kind

    public init(kind: Kind) {
        self.kind = kind
        manifest = TonicDataSourceManifest(id: "tonic.\(kind.rawValue)", displayName: kind.rawValue.capitalized,
            providerVersion: "1", minimumRefreshSeconds: kind == .weather ? 300 : 15,
            capabilities: [.label, .symbol, .accessibilityText, .freshness, .semanticStatus])
    }

    public func snapshot(for request: TonicDataSourceRequest) async throws -> TonicDataSourceSnapshot {
        let values = await MainActor.run { () -> (String, String, String, TonicProviderSemanticStatus) in
            let manager = WidgetDataManager.shared
            switch kind {
            case .battery:
                let percent = Int(manager.batteryData.chargePercentage.rounded())
                return (manager.batteryData.isPresent ? "\(percent)%" : "—", "battery.100percent",
                        manager.batteryData.isPresent ? "Battery \(percent) percent" : "Battery unavailable",
                        percent < 15 ? .warning : .neutral)
            case .cpu:
                let percent = Int(manager.cpuData.totalUsage.rounded())
                return ("\(percent)%", "cpu", "CPU usage \(percent) percent", percent > 90 ? .critical : .neutral)
            case .memory:
                let percent = manager.memoryData.totalBytes > 0
                    ? Int((Double(manager.memoryData.usedBytes) / Double(manager.memoryData.totalBytes) * 100).rounded()) : 0
                return ("\(percent)%", "memorychip", "Memory usage \(percent) percent", percent > 90 ? .warning : .neutral)
            case .network:
                let down = ByteCountFormatter.string(fromByteCount: Int64(manager.networkData.downloadBytesPerSecond), countStyle: .file)
                return ("↓\(down)/s", "network", "Network download \(down) per second", manager.networkData.isConnected ? .good : .unavailable)
            case .weather:
                guard let weather = manager.weatherData else { return ("—", "cloud", "Weather unavailable", .unavailable) }
                let temp = Int(weather.temperature.rounded())
                return ("\(temp)°", "cloud.sun", "Weather temperature \(temp) degrees", .neutral)
            }
        }
        return TonicDataSourceSnapshot(requestID: request.requestID, label: values.0, symbolName: values.1,
                                       accessibilityText: values.2, generatedAt: Date(),
                                       expiresAt: Date().addingTimeInterval(manifest.minimumRefreshSeconds), status: values.3)
    }
}

public enum TonicBuiltInProviderBootstrap {
    public static func registerAll(in registry: TonicProviderRegistry = .shared) async {
        for kind in TonicBuiltInMetricsProvider.Kind.allCases {
            do { try await registry.register(TonicBuiltInMetricsProvider(kind: kind)) }
            catch TonicProviderRegistryError.duplicateID { continue }
            catch { continue }
        }
    }
}
