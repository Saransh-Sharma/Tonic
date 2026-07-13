import CryptoKit
import Foundation

public struct TonicArtifactTrustConfiguration: Sendable {
    public var publicKeyData: Data
    public var marketplaceCatalogURL: URL
    public var compatibilityManifestURL: URL

    public init?(bundle: Bundle = .main) {
        guard let encoded = bundle.object(forInfoDictionaryKey: "TonicArtifactPublicKey") as? String,
              let publicKeyData = Data(base64Encoded: encoded), publicKeyData.count == 32,
              let catalog = bundle.object(forInfoDictionaryKey: "TonicMarketplaceCatalogURL") as? String,
              let marketplaceCatalogURL = URL(string: catalog), marketplaceCatalogURL.scheme == "https",
              let compatibility = bundle.object(forInfoDictionaryKey: "TonicCompatibilityManifestURL") as? String,
              let compatibilityManifestURL = URL(string: compatibility), compatibilityManifestURL.scheme == "https"
        else { return nil }
        self.publicKeyData = publicKeyData
        self.marketplaceCatalogURL = marketplaceCatalogURL
        self.compatibilityManifestURL = compatibilityManifestURL
    }
}

public enum TonicMarketplaceError: LocalizedError, Equatable, Sendable {
    case catalogUnavailable
    case entryUnavailable
    case releaseRevoked
    case incompatibleHost
    case unsupportedSchema
    case permissionReviewRequired
    case invalidArtifactURL
    case artifactTooLarge
    case hashMismatch
    case executableUnavailableInStore

    public var errorDescription: String? {
        switch self {
        case .catalogUnavailable: String(localized: "The signed provider catalog is unavailable or invalid.")
        case .entryUnavailable: String(localized: "This provider release is unavailable.")
        case .releaseRevoked: String(localized: "This provider release has been revoked and cannot run.")
        case .incompatibleHost: String(localized: "This provider is not compatible with this Mac or Tonic edition.")
        case .unsupportedSchema: String(localized: "This provider does not support a compatible data schema.")
        case .permissionReviewRequired: String(localized: "Review the provider's changed permissions before installing.")
        case .invalidArtifactURL: String(localized: "The provider artifact must use an approved HTTPS address.")
        case .artifactTooLarge: String(localized: "The provider artifact exceeds Tonic's size limit.")
        case .hashMismatch: String(localized: "The provider artifact does not match the signed catalog digest.")
        case .executableUnavailableInStore: String(localized: "Executable providers are unavailable in the Mac App Store edition.")
        }
    }
}

public actor TonicMarketplaceService {
    public static let maximumCatalogBytes = 2 * 1_024 * 1_024
    public static let maximumRemoteDescriptorBytes = 512 * 1_024

    private let verifier: SignedArtifactVerifier
    private let loader: any ArtifactLoading
    private let store: VersionedAtomicStore<TonicMarketplaceState>
    private let catalogStore: VersionedAtomicStore<TonicMarketplaceCatalogCache>
    private let artifactRoot: URL
    private let now: @Sendable () -> Date
    private var state: TonicMarketplaceState
    private var catalogEnvelope: SignedArtifactEnvelope<TonicMarketplaceCatalog>?

    public init(publicKeyData: Data, stateURL: URL,
                loader: any ArtifactLoading = URLSessionArtifactLoader(),
                now: @escaping @Sendable () -> Date = { Date() }) throws {
        verifier = try SignedArtifactVerifier(publicKeyData: publicKeyData)
        self.loader = loader
        store = VersionedAtomicStore(fileURL: stateURL)
        catalogStore = VersionedAtomicStore(fileURL: stateURL.deletingPathExtension()
            .appendingPathExtension("catalog.json"))
        artifactRoot = stateURL.deletingLastPathComponent().appendingPathComponent("Artifacts", isDirectory: true)
        self.now = now
        state = .init()
    }

    public func load() async {
        state = await store.loadOrDefault(.init())
        let cached = await catalogStore.loadOrDefault(.init())
        guard let envelope = cached.envelope,
              let catalog = try? verifier.verify(envelope,
                  expectedKind: TonicMarketplaceCatalog.artifactKind,
                  minimumRevision: state.catalogRevision,
                  now: now()),
              (try? validate(catalog)) != nil else {
            catalogEnvelope = nil
            return
        }
        catalogEnvelope = envelope
        await applyRevocations(from: catalog)
        try? await store.save(state)
    }

    public func acceptCatalog(_ data: Data) async throws {
        guard data.count <= Self.maximumCatalogBytes else { throw TonicMarketplaceError.catalogUnavailable }
        let envelope = try SignedArtifactCoding.decoder().decode(
            SignedArtifactEnvelope<TonicMarketplaceCatalog>.self, from: data)
        let catalog = try verifier.verify(envelope, expectedKind: TonicMarketplaceCatalog.artifactKind,
                                          minimumRevision: state.catalogRevision, now: now())
        try validate(catalog)
        catalogEnvelope = envelope
        state.catalogRevision = envelope.body.revision
        state.lastRefresh = now()
        await applyRevocations(from: catalog)
        try await catalogStore.save(.init(envelope: envelope))
        try await store.save(state)
    }

    public func refresh(from url: URL) async throws {
        guard url.scheme?.lowercased() == "https" else { throw TonicMarketplaceError.invalidArtifactURL }
        let result = try await loader.fetch(url: url, eTag: nil)
        guard let data = result.data else { throw TonicMarketplaceError.catalogUnavailable }
        try await acceptCatalog(data)
        _ = await installAutomaticUpdates()
    }

    public func visibleEntries(edition: DistributionEdition = .current) -> [TonicMarketplaceEntry] {
        guard let catalog = verifiedCatalog() else { return [] }
        return catalog.entries.filter { entry in
            guard entry.compatibility.supportsCurrentHost(edition: edition),
                  let release = entry.latestRelease,
                  release.schemaRange.overlap(with: .hostSupported) != nil else { return false }
            return edition == .direct || release.kind == .remoteJSON
        }
    }

    public func installPlan(entryID: String, edition: DistributionEdition = .current) throws -> TonicProviderInstallPlan {
        guard let catalog = verifiedCatalog(),
              let entry = catalog.entries.first(where: { $0.id == entryID }),
              let release = entry.latestRelease else { throw TonicMarketplaceError.entryUnavailable }
        guard entry.compatibility.supportsCurrentHost(edition: edition) else { throw TonicMarketplaceError.incompatibleHost }
        guard release.schemaRange.overlap(with: .hostSupported) != nil else { throw TonicMarketplaceError.unsupportedSchema }
        guard edition == .direct || release.kind == .remoteJSON else {
            throw TonicMarketplaceError.executableUnavailableInStore
        }
        guard !catalog.revokedReleaseIDs.contains(releaseID(entryID, release.version)) else {
            throw TonicMarketplaceError.releaseRevoked
        }
        let prior = state.installed[entryID]
        let expansion = release.permissions.subtracting(prior?.approvedPermissions ?? [])
        let policyUnchanged = prior.map {
            $0.installedRelease.expectedTeamIdentifier == release.expectedTeamIdentifier
                && $0.installedRelease.kind == release.kind
                && Set($0.installedRelease.endpoints) == Set(release.endpoints)
                && $0.installedRelease.permissions == release.permissions
                && $0.installedRelease.schemaRange == release.schemaRange
                && $0.installedRelease.minimumRefreshSeconds == release.minimumRefreshSeconds
        } ?? false
        return TonicProviderInstallPlan(entryID: entryID, release: release,
            permissionsToApprove: expansion, replacesVersion: prior?.installedRelease.version,
            canInstallAutomatically: prior != nil && expansion.isEmpty && policyUnchanged)
    }

    public func automaticUpdatePlans(edition: DistributionEdition = .current) -> [TonicProviderInstallPlan] {
        visibleEntries(edition: edition).compactMap { entry in
            guard let installed = state.installed[entry.id],
                  let latest = entry.latestRelease,
                  installed.installedRelease.version != latest.version,
                  let plan = try? installPlan(entryID: entry.id, edition: edition),
                  plan.canInstallAutomatically else { return nil }
            return plan
        }
    }

    @discardableResult
    public func installAutomaticUpdates(edition: DistributionEdition = .current) async
        -> [TonicProviderInstallReceipt] {
        var receipts: [TonicProviderInstallReceipt] = []
        for plan in automaticUpdatePlans(edition: edition) {
            do {
                let receipt: TonicProviderInstallReceipt
                switch plan.release.kind {
                case .remoteJSON:
                    receipt = try await installRemote(plan)
                case .executableBundle:
                    #if TONIC_STORE
                    continue
                    #else
                    receipt = try await installExecutable(plan)
                    #endif
                }
                receipts.append(receipt)
            } catch {
                if var installed = state.installed[plan.entryID] {
                    installed.health = TonicProviderDiagnostic(
                        providerID: plan.entryID,
                        state: .invalidPayload,
                        detail: String(localized: "The reviewed automatic update failed closed; the current release remains active."),
                        checkedAt: now()
                    )
                    state.installed[plan.entryID] = installed
                    try? await store.save(state)
                }
                receipts.append(TonicProviderInstallReceipt(
                    providerID: plan.entryID,
                    version: plan.release.version,
                    installedAt: now(),
                    succeeded: false,
                    detail: String(localized: "Automatic update failed closed; the current release was preserved.")
                ))
            }
        }
        return receipts
    }

    public func approve(_ plan: TonicProviderInstallPlan) async throws {
        guard plan.permissionsToApprove.isSubset(of: plan.release.permissions) else {
            throw TonicMarketplaceError.permissionReviewRequired
        }
        let prior = state.installed[plan.entryID]
        let health = TonicProviderDiagnostic(providerID: plan.entryID, state: .healthy,
                                              detail: "The reviewed release is approved for installation.", checkedAt: now())
        state.installed[plan.entryID] = TonicMarketplaceInstalledState(
            providerID: plan.entryID, installedRelease: plan.release,
            approvedPermissions: plan.release.permissions, approvalRevision: state.catalogRevision,
            rollbackRelease: prior?.installedRelease, health: health)
        try await store.save(state)
    }

    /// Installs a reviewed remote-provider descriptor only after the release
    /// bytes match the signed catalog hash and every reviewed endpoint/policy
    /// still matches the catalog entry.
    public func installRemote(_ plan: TonicProviderInstallPlan) async throws -> TonicProviderInstallReceipt {
        guard plan.release.kind == .remoteJSON else { throw TonicMarketplaceError.entryUnavailable }
        let data = try await download(plan.release.artifactURL, limit: Self.maximumRemoteDescriptorBytes)
        try Self.verifySHA256(data: data, expectedHex: plan.release.sha256)
        let configuration = try TonicProviderCoding.decoder().decode(TonicRemoteProviderConfiguration.self, from: data)
        guard configuration.manifest.id == plan.entryID,
              configuration.manifest.supportedSchemaRange.overlap(with: .hostSupported) != nil,
              plan.release.endpoints.contains(configuration.endpoint),
              configuration.refreshInterval >= plan.release.minimumRefreshSeconds,
              configuration.secretIdentifier == nil else {
            throw TonicMarketplaceError.permissionReviewRequired
        }
        let retained = retainedRemoteArtifactURL(providerID: plan.entryID, version: plan.release.version)
        try FileManager.default.createDirectory(at: retained.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try data.write(to: retained, options: [.atomic, .completeFileProtection])
        try await MainActor.run { try TonicRemoteProviderStore.shared.addReviewed(configuration) }
        try await approve(plan)
        return TonicProviderInstallReceipt(providerID: plan.entryID, version: plan.release.version,
            installedAt: now(), succeeded: true, detail: "Installed the reviewed remote provider atomically.")
    }

    #if !TONIC_STORE
    /// Installs a catalog-hosted executable bundle into Tonic's Application
    /// Support directory. The archive path, extraction tool, destination, and
    /// signing identity are all fixed by Tonic rather than supplied by a provider.
    public func installExecutable(_ plan: TonicProviderInstallPlan) async throws -> TonicProviderInstallReceipt {
        guard plan.release.kind == .executableBundle,
              let expectedTeam = plan.release.expectedTeamIdentifier, !expectedTeam.isEmpty else {
            throw TonicMarketplaceError.entryUnavailable
        }
        let archive = try await download(plan.release.artifactURL, limit: 50 * 1_024 * 1_024)
        try Self.verifySHA256(data: archive, expectedHex: plan.release.sha256)
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Tonic/Marketplace", isDirectory: true)
        let staging = root.appendingPathComponent("Staging/\(UUID().uuidString)", isDirectory: true)
        let archiveURL = staging.appendingPathComponent("provider.zip")
        defer { try? FileManager.default.removeItem(at: staging) }
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        try archive.write(to: archiveURL, options: [.atomic, .completeFileProtection])
        try runFixedTool("/usr/bin/ditto", arguments: ["-x", "-k", archiveURL.path, staging.path])
        let bundles = try FileManager.default.contentsOfDirectory(at: staging,
            includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
            .filter { $0.pathExtension == "tonicprovider" }
        guard bundles.count == 1, let bundle = bundles.first else { throw TonicMarketplaceError.entryUnavailable }
        let resolvedStaging = staging.resolvingSymlinksInPath().standardizedFileURL
        let resolvedBundle = bundle.resolvingSymlinksInPath().standardizedFileURL
        guard resolvedBundle.path.hasPrefix(resolvedStaging.path + "/"),
              try Self.containsNoSymbolicLinks(bundle) else {
            throw TonicMarketplaceError.entryUnavailable
        }
        try runFixedTool("/usr/sbin/spctl", arguments: ["-a", "-t", "execute", bundle.path])
        let installedRoot = root.appendingPathComponent("Installed/\(plan.entryID)", isDirectory: true)
        try FileManager.default.createDirectory(at: installedRoot, withIntermediateDirectories: true)
        let destination = installedRoot.appendingPathComponent("\(plan.release.version).tonicprovider")
        let temporary = installedRoot.appendingPathComponent(".install-\(UUID().uuidString).tonicprovider")
        try FileManager.default.copyItem(at: bundle, to: temporary)
        _ = try await TonicExecutableProvider(bundleURL: temporary, advancedDeveloperMode: false,
            expectedTeamIdentifier: expectedTeam)
        if FileManager.default.fileExists(atPath: destination.path) {
            _ = try FileManager.default.replaceItemAt(destination, withItemAt: temporary)
        } else {
            try FileManager.default.moveItem(at: temporary, to: destination)
        }
        try await TonicExecutableProviderStore.shared.add(bundleURL: destination,
            advancedDeveloperMode: false, expectedTeamIdentifier: expectedTeam)
        try await approve(plan)
        return TonicProviderInstallReceipt(providerID: plan.entryID, version: plan.release.version,
            installedAt: now(), succeeded: true, detail: "Installed a signed and notarized provider bundle.")
    }
    #endif

    public func rollback(providerID: String) async -> TonicProviderRelease? {
        guard var installed = state.installed[providerID], let prior = installed.rollbackRelease else { return nil }
        do {
            switch prior.kind {
            case .remoteJSON:
                let data = try Data(contentsOf: retainedRemoteArtifactURL(
                    providerID: providerID, version: prior.version))
                try Self.verifySHA256(data: data, expectedHex: prior.sha256)
                let configuration = try TonicProviderCoding.decoder().decode(
                    TonicRemoteProviderConfiguration.self, from: data)
                guard configuration.manifest.id == providerID,
                      prior.endpoints.contains(configuration.endpoint),
                      configuration.refreshInterval >= prior.minimumRefreshSeconds,
                      configuration.secretIdentifier == nil else {
                    throw TonicMarketplaceError.permissionReviewRequired
                }
                try await MainActor.run { try TonicRemoteProviderStore.shared.addReviewed(configuration) }
            case .executableBundle:
                #if TONIC_STORE
                throw TonicMarketplaceError.executableUnavailableInStore
                #else
                guard let team = prior.expectedTeamIdentifier else {
                    throw TonicMarketplaceError.entryUnavailable
                }
                let bundle = executableArtifactURL(providerID: providerID, version: prior.version)
                try await TonicExecutableProviderStore.shared.add(
                    bundleURL: bundle, advancedDeveloperMode: false, expectedTeamIdentifier: team)
                #endif
            }
            installed.rollbackRelease = installed.installedRelease
            installed.installedRelease = prior
            installed.health = TonicProviderDiagnostic(providerID: providerID, state: .healthy,
                detail: "Rolled back to the previous reviewed release.", checkedAt: now())
            state.installed[providerID] = installed
            try await store.save(state)
            return prior
        } catch {
            installed.health = TonicProviderDiagnostic(providerID: providerID, state: .invalidPayload,
                detail: "Rollback failed closed; the active release was left unchanged.", checkedAt: now())
            state.installed[providerID] = installed
            try? await store.save(state)
            return nil
        }
    }

    public func rollbackProviderIDs() -> Set<String> {
        Set(state.installed.compactMap { $0.value.rollbackRelease == nil ? nil : $0.key })
    }

    public nonisolated static func verifySHA256(data: Data, expectedHex: String) throws {
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard digest == expectedHex.lowercased() else { throw TonicMarketplaceError.hashMismatch }
    }

    public func diagnostics() -> [TonicProviderDiagnostic] {
        state.installed.values.map(\.health).sorted { $0.providerID < $1.providerID }
    }

    private func verifiedCatalog() -> TonicMarketplaceCatalog? {
        guard let catalogEnvelope else { return nil }
        return try? verifier.verify(catalogEnvelope, expectedKind: TonicMarketplaceCatalog.artifactKind,
                                    minimumRevision: state.catalogRevision, now: now())
    }

    private func validate(_ catalog: TonicMarketplaceCatalog) throws {
        guard Set(catalog.entries.map(\.id)).count == catalog.entries.count else {
            throw TonicMarketplaceError.catalogUnavailable
        }
        for entry in catalog.entries {
            guard entry.id == entry.manifest.id, TonicProviderManifestPolicy.isValid(entry.manifest) else {
                throw TonicMarketplaceError.catalogUnavailable
            }
            for release in entry.releases {
                guard Self.isSafePathComponent(release.version),
                      release.artifactURL.scheme?.lowercased() == "https",
                      release.sha256.count == 64,
                      release.sha256.allSatisfy({ $0.isHexDigit }),
                      release.schemaRange.overlap(with: .hostSupported) != nil else {
                    throw TonicMarketplaceError.catalogUnavailable
                }
                if release.kind == .executableBundle {
                    guard release.expectedTeamIdentifier?.isEmpty == false,
                          release.permissions.contains(.executableProcess) else {
                        throw TonicMarketplaceError.catalogUnavailable
                    }
                }
                guard release.endpoints.allSatisfy({ $0.scheme?.lowercased() == "https" }) else {
                    throw TonicMarketplaceError.catalogUnavailable
                }
            }
        }
    }

    private func applyRevocations(from catalog: TonicMarketplaceCatalog) async {
        for (id, value) in state.installed where catalog.revokedReleaseIDs.contains(releaseID(id, value.installedRelease.version)) {
            var updated = value
            updated.health = TonicProviderDiagnostic(providerID: id, state: .revokedVersion,
                detail: "This signed catalog revoked the installed release. The provider is paused.", checkedAt: now())
            state.installed[id] = updated
            await TonicProviderRegistry.shared.unregister(id: id)
        }
    }

    private func releaseID(_ providerID: String, _ version: String) -> String { "\(providerID)@\(version)" }

    private func retainedRemoteArtifactURL(providerID: String, version: String) -> URL {
        artifactRoot.appendingPathComponent("Remote", isDirectory: true)
            .appendingPathComponent(providerID, isDirectory: true)
            .appendingPathComponent("\(version).json")
    }

    #if !TONIC_STORE
    private func executableArtifactURL(providerID: String, version: String) -> URL {
        artifactRoot.deletingLastPathComponent()
            .appendingPathComponent("Installed", isDirectory: true)
            .appendingPathComponent(providerID, isDirectory: true)
            .appendingPathComponent("\(version).tonicprovider", isDirectory: true)
    }
    #endif

    private nonisolated static func isSafePathComponent(_ value: String) -> Bool {
        guard (1...64).contains(value.count), value != ".", value != "..",
              value.unicodeScalars.first.map(CharacterSet.alphanumerics.contains) == true,
              value.unicodeScalars.last.map(CharacterSet.alphanumerics.contains) == true else { return false }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
        return value.unicodeScalars.allSatisfy(allowed.contains) && !value.contains("..")
    }

    private func download(_ url: URL, limit: Int) async throws -> Data {
        guard url.scheme?.lowercased() == "https" else { throw TonicMarketplaceError.invalidArtifactURL }
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              http.expectedContentLength <= 0 || http.expectedContentLength <= Int64(limit) else {
            throw TonicMarketplaceError.artifactTooLarge
        }
        var data = Data()
        data.reserveCapacity(min(max(Int(http.expectedContentLength), 0), limit))
        for try await byte in bytes {
            guard data.count < limit else { throw TonicMarketplaceError.artifactTooLarge }
            data.append(byte)
        }
        return data
    }

    #if !TONIC_STORE
    private func runFixedTool(_ path: String, arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        let semaphore = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in semaphore.signal() }
        try process.run()
        guard semaphore.wait(timeout: .now() + 30) == .success else {
            if process.isRunning { process.terminate() }
            throw TonicMarketplaceError.entryUnavailable
        }
        guard process.terminationReason == .exit, process.terminationStatus == 0 else {
            throw TonicMarketplaceError.entryUnavailable
        }
    }

    private nonisolated static func containsNoSymbolicLinks(_ root: URL) throws -> Bool {
        let keys: [URLResourceKey] = [.isSymbolicLinkKey]
        guard let enumerator = FileManager.default.enumerator(
            at: root, includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles], errorHandler: { _, _ in false }
        ) else { return false }
        for case let value as URL in enumerator {
            if try value.resourceValues(forKeys: Set(keys)).isSymbolicLink == true { return false }
        }
        return true
    }
    #endif
}

public actor TonicMarketplaceRuntime {
    public static let shared = TonicMarketplaceRuntime()
    private var didStart = false

    public func start() async {
        guard !didStart else { return }
        didStart = true
        guard let trust = TonicArtifactTrustConfiguration() else { return }
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Tonic/Marketplace", isDirectory: true)
        guard let service = try? TonicMarketplaceService(
            publicKeyData: trust.publicKeyData,
            stateURL: root.appendingPathComponent("state-v1.json")
        ) else { return }
        await service.load()
        try? await service.refresh(from: trust.marketplaceCatalogURL)
    }
}
