import Foundation
import Security
import Darwin

private final class TonicRemoteRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var redirectCounts: [Int: Int] = [:]
    let allowsPrivateNetwork: Bool
    init(allowsPrivateNetwork: Bool) { self.allowsPrivateNetwork = allowsPrivateNetwork }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        let count = lock.withLock { redirectCounts[task.taskIdentifier, default: 0] += 1; return redirectCounts[task.taskIdentifier] ?? 0 }
        guard let url = request.url, count <= TonicRemoteProviderPolicy.maximumRedirects,
              TonicRemoteProviderPolicy.validateResolved(url, allowsPrivateNetwork: allowsPrivateNetwork) == nil else {
            completionHandler(nil); return
        }
        completionHandler(request)
    }
}

public struct TonicRemoteProviderConfiguration: Codable, Equatable, Sendable, Identifiable {
    public var id: String { manifest.id }
    public var manifest: TonicDataSourceManifest
    public var endpoint: URL
    public var refreshInterval: Double
    public var secretIdentifier: String?
    public var allowsPrivateNetwork: Bool
    public var reviewedAt: Date

    public init(manifest: TonicDataSourceManifest, endpoint: URL, refreshInterval: Double,
                secretIdentifier: String? = nil, allowsPrivateNetwork: Bool = false,
                reviewedAt: Date = Date()) {
        self.manifest = manifest; self.endpoint = endpoint
        self.refreshInterval = max(manifest.minimumRefreshSeconds, refreshInterval)
        self.secretIdentifier = secretIdentifier; self.allowsPrivateNetwork = allowsPrivateNetwork
        self.reviewedAt = reviewedAt
    }
}

@MainActor
@Observable
public final class TonicRemoteProviderStore {
    public static let shared = TonicRemoteProviderStore()
    public private(set) var configurations: [TonicRemoteProviderConfiguration]
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Tonic", isDirectory: true)
        self.fileURL = fileURL ?? root.appendingPathComponent("RemoteProviders.json")
        configurations = (try? Data(contentsOf: self.fileURL)).flatMap {
            try? TonicProviderCoding.decoder().decode([TonicRemoteProviderConfiguration].self, from: $0)
        } ?? []
    }

    public func addReviewed(_ configuration: TonicRemoteProviderConfiguration) throws {
        if let error = TonicRemoteProviderPolicy.validate(configuration.endpoint,
                                                           allowsPrivateNetwork: configuration.allowsPrivateNetwork) { throw error }
        guard TonicProviderManifestPolicy.isValid(configuration.manifest),
              configuration.manifest.id.hasPrefix("remote.") else {
            throw TonicRemoteProviderError.unsupportedSchema
        }
        configurations.removeAll { $0.manifest.id == configuration.manifest.id }
        configurations.append(configuration); persist()
        Task { try? await register(configuration) }
    }

    public func remove(id: String) {
        let secretIdentifier = configurations.first(where: { $0.manifest.id == id })?.secretIdentifier
        configurations.removeAll { $0.manifest.id == id }; persist()
        if let secretIdentifier { try? TonicProviderSecretStore().delete(identifier: secretIdentifier) }
        Task { await TonicProviderRegistry.shared.unregister(id: id) }
    }

    public func registerPersisted() {
        for configuration in configurations { Task { try? await register(configuration) } }
    }

    private func register(_ configuration: TonicRemoteProviderConfiguration) async throws {
        guard configuration.manifest.id.hasPrefix("remote.") else {
            throw TonicRemoteProviderError.unsupportedSchema
        }
        let provider = try TonicRemoteJSONProvider(configuration: configuration)
        do { try await TonicProviderRegistry.shared.register(provider) }
        catch TonicProviderRegistryError.duplicateID {
            await TonicProviderRegistry.shared.unregister(id: configuration.manifest.id)
            try await TonicProviderRegistry.shared.register(provider)
        }
    }

    private func persist() {
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? TonicProviderCoding.encoder().encode(configurations).write(to: fileURL, options: .atomic)
    }
}

public enum TonicRemoteProviderError: Error, Equatable {
    case httpsRequired, privateNetworkBlocked, tooManyRedirects, responseTooLarge
    case invalidStatus(Int), invalidJSON, excessiveDepth, unsupportedSchema, secretUnavailable
}

public enum TonicRemoteProviderPolicy {
    public static let maximumResponseBytes = 256 * 1_024
    public static let maximumRedirects = 3
    public static let maximumJSONDepth = 8
    public static let maximumJSONNodes = 512

    public static func validate(_ url: URL, allowsPrivateNetwork: Bool) -> TonicRemoteProviderError? {
        guard url.scheme?.lowercased() == "https" else { return .httpsRequired }
        guard let host = url.host?.lowercased(), !host.isEmpty else { return .invalidJSON }
        if !allowsPrivateNetwork && isPrivateHost(host) { return .privateNetworkBlocked }
        return nil
    }

    static func isPrivateHost(_ host: String) -> Bool {
        if host == "localhost" || host.hasSuffix(".local") || host == "::1" { return true }
        let octets = host.split(separator: ".").compactMap { Int($0) }
        guard octets.count == 4 else { return false }
        return octets[0] == 10 || octets[0] == 127
            || (octets[0] == 192 && octets[1] == 168)
            || (octets[0] == 172 && (16...31).contains(octets[1]))
            || (octets[0] == 169 && octets[1] == 254)
    }

    static func validateResolved(_ url: URL, allowsPrivateNetwork: Bool) -> TonicRemoteProviderError? {
        if let error = validate(url, allowsPrivateNetwork: allowsPrivateNetwork) { return error }
        guard !allowsPrivateNetwork, let host = url.host else { return nil }
        return resolvesToPrivateOrReservedAddress(host) ? .privateNetworkBlocked : nil
    }

    static func resolvesToPrivateOrReservedAddress(_ host: String) -> Bool {
        var hints = addrinfo(ai_flags: AI_ADDRCONFIG, ai_family: AF_UNSPEC,
                             ai_socktype: SOCK_STREAM, ai_protocol: IPPROTO_TCP,
                             ai_addrlen: 0, ai_canonname: nil, ai_addr: nil, ai_next: nil)
        var result: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, nil, &hints, &result) == 0, let first = result else { return false }
        defer { freeaddrinfo(first) }
        var cursor: UnsafeMutablePointer<addrinfo>? = first
        while let info = cursor?.pointee {
            if info.ai_family == AF_INET, let address = info.ai_addr {
                let sin = UnsafeRawPointer(address).assumingMemoryBound(to: sockaddr_in.self).pointee
                let value = UInt32(bigEndian: sin.sin_addr.s_addr)
                let bytes = [UInt8((value >> 24) & 0xff), UInt8((value >> 16) & 0xff),
                             UInt8((value >> 8) & 0xff), UInt8(value & 0xff)]
                if isPrivateOrReservedIPv4(bytes) { return true }
            } else if info.ai_family == AF_INET6, let address = info.ai_addr {
                let sin6 = UnsafeRawPointer(address).assumingMemoryBound(to: sockaddr_in6.self).pointee
                let bytes = withUnsafeBytes(of: sin6.sin6_addr) { Array($0) }
                if isPrivateOrReservedIPv6(bytes) { return true }
            }
            cursor = info.ai_next
        }
        return false
    }

    private static func isPrivateOrReservedIPv4(_ bytes: [UInt8]) -> Bool {
        guard bytes.count == 4 else { return true }
        let a = bytes[0], b = bytes[1]
        return a == 0 || a == 10 || a == 127 || a >= 224
            || (a == 100 && (64...127).contains(b))
            || (a == 169 && b == 254) || (a == 172 && (16...31).contains(b))
            || (a == 192 && (b == 0 || b == 168)) || (a == 198 && (b == 18 || b == 19))
    }

    private static func isPrivateOrReservedIPv6(_ bytes: [UInt8]) -> Bool {
        guard bytes.count == 16 else { return true }
        if bytes.allSatisfy({ $0 == 0 }) || bytes == Array(repeating: 0, count: 15) + [1] { return true }
        if bytes[0] & 0xfe == 0xfc || (bytes[0] == 0xfe && bytes[1] & 0xc0 == 0x80) || bytes[0] == 0xff {
            return true
        }
        if bytes.prefix(10).allSatisfy({ $0 == 0 }), bytes[10] == 0xff, bytes[11] == 0xff {
            return isPrivateOrReservedIPv4(Array(bytes.suffix(4)))
        }
        return false
    }

    static func validateJSONShape(_ object: Any) -> Bool {
        var nodes = 0
        func visit(_ value: Any, depth: Int) -> Bool {
            nodes += 1
            guard nodes <= maximumJSONNodes, depth <= maximumJSONDepth else { return false }
            if let values = value as? [Any] { return values.allSatisfy { visit($0, depth: depth + 1) } }
            if let values = value as? [String: Any] { return values.values.allSatisfy { visit($0, depth: depth + 1) } }
            return value is String || value is NSNumber || value is NSNull
        }
        return visit(object, depth: 0)
    }
}

public struct TonicProviderSecretStore: Sendable {
    public static let service = "com.saransh.tonic.providers"
    public init() {}

    public func save(_ secret: Data, identifier: String) throws {
        let query = base(identifier)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: secret] as CFDictionary)
        if status == errSecItemNotFound {
            var add = query
            add[kSecValueData as String] = secret
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            let addStatus = SecItemAdd(add as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw CocoaError(.fileWriteUnknown) }
        } else if status != errSecSuccess { throw CocoaError(.fileWriteUnknown) }
    }

    public func read(identifier: String) throws -> Data? {
        var query = base(identifier)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw CocoaError(.fileReadUnknown) }
        return result as? Data
    }

    public func delete(identifier: String) throws {
        let status = SecItemDelete(base(identifier) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw CocoaError(.fileWriteUnknown) }
    }

    private func base(_ identifier: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: Self.service,
         kSecAttrAccount as String: identifier, kSecUseDataProtectionKeychain as String: true]
    }
}

public actor TonicRemoteJSONProvider: TonicDataSourceProvider {
    public nonisolated let manifest: TonicDataSourceManifest
    private let configuration: TonicRemoteProviderConfiguration
    private let secrets: TonicProviderSecretStore
    private let session: URLSession

    public init(configuration: TonicRemoteProviderConfiguration,
                secrets: TonicProviderSecretStore = .init(), session: URLSession? = nil) throws {
        if let error = TonicRemoteProviderPolicy.validate(configuration.endpoint,
                                                           allowsPrivateNetwork: configuration.allowsPrivateNetwork) { throw error }
        self.configuration = configuration; manifest = configuration.manifest
        self.secrets = secrets
        if let session { self.session = session }
        else {
            let config = URLSessionConfiguration.ephemeral
            config.httpMaximumConnectionsPerHost = 1
            config.requestCachePolicy = .reloadIgnoringLocalCacheData
            self.session = URLSession(configuration: config,
                                      delegate: TonicRemoteRedirectDelegate(allowsPrivateNetwork: configuration.allowsPrivateNetwork),
                                      delegateQueue: nil)
        }
    }

    public func snapshot(for request: TonicDataSourceRequest) async throws -> TonicDataSourceSnapshot {
        if let error = TonicRemoteProviderPolicy.validateResolved(configuration.endpoint,
                                                                  allowsPrivateNetwork: configuration.allowsPrivateNetwork) {
            throw error
        }
        var urlRequest = URLRequest(url: configuration.endpoint, cachePolicy: .reloadIgnoringLocalCacheData,
                                    timeoutInterval: 15)
        urlRequest.httpMethod = "GET"; urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        if let identifier = configuration.secretIdentifier {
            guard let secret = try secrets.read(identifier: identifier),
                  let value = String(data: secret, encoding: .utf8) else { throw TonicRemoteProviderError.secretUnavailable }
            urlRequest.setValue("Bearer \(value)", forHTTPHeaderField: "Authorization")
        }
        let (bytes, response) = try await session.bytes(for: urlRequest)
        guard let http = response as? HTTPURLResponse else { throw TonicRemoteProviderError.invalidJSON }
        guard (200...299).contains(http.statusCode) else { throw TonicRemoteProviderError.invalidStatus(http.statusCode) }
        var data = Data(); data.reserveCapacity(min(http.expectedContentLength > 0 ? Int(http.expectedContentLength) : 0,
                                                    TonicRemoteProviderPolicy.maximumResponseBytes))
        for try await byte in bytes {
            guard data.count < TonicRemoteProviderPolicy.maximumResponseBytes else { throw TonicRemoteProviderError.responseTooLarge }
            data.append(byte)
        }
        let object = try JSONSerialization.jsonObject(with: data)
        guard TonicRemoteProviderPolicy.validateJSONShape(object) else { throw TonicRemoteProviderError.excessiveDepth }
        let snapshot = try TonicProviderCoding.decoder().decode(TonicDataSourceSnapshot.self, from: data)
        guard snapshot.schemaVersion == TonicDataSourceSnapshot.currentSchemaVersion else {
            throw TonicRemoteProviderError.unsupportedSchema
        }
        return TonicDataSourceSnapshot(schemaVersion: snapshot.schemaVersion, requestID: request.requestID,
                                       label: snapshot.label, symbolName: snapshot.symbolName,
                                       imageReference: snapshot.imageReference,
                                       accessibilityText: snapshot.accessibilityText,
                                       generatedAt: snapshot.generatedAt, expiresAt: snapshot.expiresAt,
                                       status: snapshot.status)
    }
}
