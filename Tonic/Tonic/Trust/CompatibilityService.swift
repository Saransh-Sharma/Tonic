import Foundation

public struct ArtifactFetchResult: Equatable, Sendable {
    public var data: Data?
    public var eTag: String?
    public var notModified: Bool

    public init(data: Data?, eTag: String?, notModified: Bool = false) {
        self.data = data
        self.eTag = eTag
        self.notModified = notModified
    }
}

public protocol ArtifactLoading: Sendable {
    func fetch(url: URL, eTag: String?) async throws -> ArtifactFetchResult
}

public struct URLSessionArtifactLoader: ArtifactLoading, Sendable {
    private let session: URLSession

    public init(session: URLSession = .shared) { self.session = session }

    public func fetch(url: URL, eTag: String?) async throws -> ArtifactFetchResult {
        guard url.scheme?.lowercased() == "https" else { throw URLError(.unsupportedURL) }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalCacheData
        if let eTag { request.setValue(eTag, forHTTPHeaderField: "If-None-Match") }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if http.statusCode == 304 {
            return ArtifactFetchResult(data: nil, eTag: eTag, notModified: true)
        }
        guard http.statusCode == 200, data.count <= 2 * 1_024 * 1_024 else {
            throw URLError(.badServerResponse)
        }
        return ArtifactFetchResult(data: data, eTag: http.value(forHTTPHeaderField: "ETag"))
    }
}

public actor CompatibilityService {
    public static let refreshInterval: TimeInterval = 24 * 60 * 60

    private let verifier: SignedArtifactVerifier
    private let loader: any ArtifactLoading
    private let store: VersionedAtomicStore<CompatibilityCache>
    private let now: @Sendable () -> Date
    private var cache: CompatibilityCache

    public init(publicKeyData: Data, cacheURL: URL,
                loader: any ArtifactLoading = URLSessionArtifactLoader(),
                now: @escaping @Sendable () -> Date = { Date() }) throws {
        verifier = try SignedArtifactVerifier(publicKeyData: publicKeyData)
        self.loader = loader
        store = VersionedAtomicStore(fileURL: cacheURL, supportedVersion: 1, now: now)
        self.now = now
        cache = CompatibilityCache()
    }

    public func load(bundledEnvelopeData: Data? = nil) async {
        cache = await store.loadOrDefault(CompatibilityCache())
        guard cache.envelope == nil, let bundledEnvelopeData,
              let envelope = try? SignedArtifactCoding.decoder().decode(
                SignedArtifactEnvelope<CompatibilityManifest>.self,
                from: bundledEnvelopeData
              ),
              (try? verifier.verify(envelope, expectedKind: CompatibilityManifest.artifactKind, now: now())) != nil
        else { return }
        cache.envelope = envelope
        try? await store.save(cache)
    }

    public func refreshIfNeeded(from url: URL, force: Bool = false) async {
        let currentTime = now()
        if !force, let lastCheckedAt = cache.lastCheckedAt,
           currentTime.timeIntervalSince(lastCheckedAt) < Self.refreshInterval { return }
        do {
            let result = try await loader.fetch(url: url, eTag: cache.eTag)
            if let data = result.data {
                let candidate = try SignedArtifactCoding.decoder().decode(
                    SignedArtifactEnvelope<CompatibilityManifest>.self,
                    from: data
                )
                _ = try verifier.verify(
                    candidate,
                    expectedKind: CompatibilityManifest.artifactKind,
                    minimumRevision: cache.envelope?.body.revision,
                    now: currentTime
                )
                cache.envelope = candidate
            }
            cache.eTag = result.eTag ?? cache.eTag
            cache.lastCheckedAt = currentTime
            try await store.save(cache)
        } catch {
            // Network and verification failures deliberately retain only the
            // last valid, unexpired envelope. Decisions still fail closed.
            cache.lastCheckedAt = currentTime
            try? await store.save(cache)
        }
    }

    public func decision(for capability: TonicPrivateCapability,
                         runtime: CompatibilityRuntime = .current) -> PrivateCapabilityDecision {
        guard let envelope = cache.envelope,
              let manifest = try? verifier.verify(
                envelope,
                expectedKind: CompatibilityManifest.artifactKind,
                now: now()
              ) else {
            return .disabled(reason: "No current signed compatibility approval is available.")
        }
        return manifest.decision(for: capability, runtime: runtime)
    }
}

/// Process-wide compatibility authority. It owns the sole signed-manifest
/// service used by every quarantined private adapter and deliberately returns a
/// disabled decision when release trust configuration is absent.
public actor TonicCompatibilityAuthority {
    public static let shared = TonicCompatibilityAuthority()

    private let configuration: TonicArtifactTrustConfiguration?
    private let service: CompatibilityService?
    private var didStart = false

    public init(configuration: TonicArtifactTrustConfiguration? = TonicArtifactTrustConfiguration()) {
        self.configuration = configuration
        if let configuration {
            let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Tonic/Compatibility", isDirectory: true)
            service = try? CompatibilityService(publicKeyData: configuration.publicKeyData,
                cacheURL: root.appendingPathComponent("cache-v1.json"))
        } else {
            service = nil
        }
    }

    public func start() async {
        guard !didStart, let service, let configuration else { return }
        didStart = true
        await service.load()
        await service.refreshIfNeeded(from: configuration.compatibilityManifestURL)
    }

    public func decision(for capability: TonicPrivateCapability) async -> PrivateCapabilityDecision {
        await start()
        guard let service else {
            return .disabled(reason: "This build has no signed compatibility trust root.")
        }
        return await service.decision(for: capability)
    }
}
