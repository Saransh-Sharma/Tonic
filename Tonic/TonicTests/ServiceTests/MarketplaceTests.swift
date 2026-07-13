import CryptoKit
import XCTest
@testable import Tonic

private struct MarketplaceProviderStub: TonicDataSourceProvider {
    let manifest: TonicDataSourceManifest
    func snapshot(for request: TonicDataSourceRequest) async throws -> TonicDataSourceSnapshot {
        TonicDataSourceSnapshot(requestID: request.requestID, label: "stub")
    }
}

final class MarketplaceTests: XCTestCase {
    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    func testSchemaRangeNegotiatesAndPreservesV1ManifestDecoding() throws {
        let legacy = #"{"id":"remote.legacy","schemaVersion":1,"displayName":"Legacy","providerVersion":"1","minimumRefreshSeconds":60,"capabilities":["label"]}"#.data(using: .utf8)!
        let manifest = try JSONDecoder().decode(TonicDataSourceManifest.self, from: legacy)
        XCTAssertEqual(manifest.supportedSchemaRange, .versionOne)
        XCTAssertEqual(TonicProviderSchemaRange(minimum: 1, maximum: 3).overlap(with: .hostSupported),
                       .init(minimum: 1, maximum: 2))
    }

    func testArtifactHashMustMatch() {
        let data = Data("trusted".utf8)
        XCTAssertNoThrow(try TonicMarketplaceService.verifySHA256(
            data: data, expectedHex: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()))
        XCTAssertThrowsError(try TonicMarketplaceService.verifySHA256(data: data,
            expectedHex: String(repeating: "0", count: 64)))
    }

    func testProviderIdentifiersRejectPathTraversalComponents() {
        let invalid = ["..", ".hidden", "trailing.", "a..b", "a/b"]
        for id in invalid {
            let manifest = TonicDataSourceManifest(id: id, displayName: "Unsafe",
                providerVersion: "1", capabilities: [.label])
            XCTAssertFalse(TonicProviderManifestPolicy.isValid(manifest), id)
        }
    }

    func testStoreFiltersExecutableCatalogEntries() async throws {
        let key = Curve25519.Signing.PrivateKey()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let service = try TonicMarketplaceService(publicKeyData: key.publicKey.rawRepresentation, stateURL: root)
        await service.load()
        let manifest = TonicDataSourceManifest(id: "remote.sample", displayName: "Sample",
                                                providerVersion: "1", capabilities: [.label])
        let remote = TonicProviderRelease(version: "1", kind: .remoteJSON,
            artifactURL: URL(string: "https://example.com/provider.json")!, sha256: String(repeating: "a", count: 64))
        let executable = TonicProviderRelease(version: "2", kind: .executableBundle,
            artifactURL: URL(string: "https://example.com/provider.zip")!, sha256: String(repeating: "b", count: 64),
            expectedTeamIdentifier: "CJ43UNM3AR", permissions: [.executableProcess])
        let catalog = TonicMarketplaceCatalog(entries: [
            .init(id: "remote.sample", providerName: "Remote", publisherName: "Tonic",
                  manifest: manifest, releases: [remote]),
            .init(id: "exec.sample", providerName: "Exec", publisherName: "Tonic",
                  manifest: TonicDataSourceManifest(id: "exec.sample", displayName: "Exec", providerVersion: "2", capabilities: [.label]),
                  releases: [executable])
        ])
        let body = SignedArtifactBody(kind: TonicMarketplaceCatalog.artifactKind, revision: 1,
            validity: .init(issuedAt: Date().addingTimeInterval(-10), expiresAt: Date().addingTimeInterval(600)),
            payload: catalog)
        let signed = try SignedArtifactTestSupport.sign(body: body, privateKey: key)
        try await service.acceptCatalog(SignedArtifactCoding.canonicalData(for: signed))
        let entries = await service.visibleEntries(edition: .store)
        XCTAssertEqual(entries.map(\.id), ["remote.sample"])
    }

    func testShippingCatalogContainsInstallableFirstPartyRemoteProvider() throws {
        let catalogURL = repositoryRoot.appendingPathComponent("Marketplace/catalog-unsigned.json")
        let artifactURL = repositoryRoot
            .appendingPathComponent("Marketplace/Artifacts/remote.tonic-release-1.0.0.json")
        let envelope = try SignedArtifactCoding.decoder().decode(
            SignedArtifactEnvelope<TonicMarketplaceCatalog>.self, from: Data(contentsOf: catalogURL))
        let entry = try XCTUnwrap(envelope.body.payload.entries.first {
            $0.id == "remote.tonic-release"
        })
        let release = try XCTUnwrap(entry.latestRelease)
        let data = try Data(contentsOf: artifactURL)

        XCTAssertEqual(release.kind, .remoteJSON)
        XCTAssertEqual(entry.compatibility.editions, ["direct", "store"])
        XCTAssertNoThrow(try TonicMarketplaceService.verifySHA256(data: data, expectedHex: release.sha256))
        let configuration = try TonicProviderCoding.decoder().decode(
            TonicRemoteProviderConfiguration.self, from: data)
        XCTAssertEqual(configuration.manifest.id, entry.id)
        XCTAssertTrue(release.endpoints.contains(configuration.endpoint))
        XCTAssertFalse(configuration.allowsPrivateNetwork)
    }

    func testVerifiedCatalogSurvivesOfflineRelaunch() async throws {
        let key = Curve25519.Signing.PrivateKey()
        let stateURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathExtension("json")
        let catalog = makeCatalog(providerID: "remote.cached", version: "1")
        let first = try TonicMarketplaceService(publicKeyData: key.publicKey.rawRepresentation,
                                                stateURL: stateURL)
        await first.load()
        try await first.acceptCatalog(signedCatalog(catalog, key: key, revision: 1))

        let relaunched = try TonicMarketplaceService(publicKeyData: key.publicKey.rawRepresentation,
                                                     stateURL: stateURL)
        await relaunched.load()

        let entries = await relaunched.visibleEntries(edition: .store)
        XCTAssertEqual(entries.map(\.id), ["remote.cached"])
    }

    func testAutomaticUpdatesRequireAnExactlyUnchangedReviewedPolicy() async throws {
        let key = Curve25519.Signing.PrivateKey()
        let stateURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathExtension("json")
        let service = try TonicMarketplaceService(publicKeyData: key.publicKey.rawRepresentation,
                                                  stateURL: stateURL)
        await service.load()
        try await service.acceptCatalog(signedCatalog(
            makeCatalog(providerID: "remote.autoupdate", version: "1"), key: key, revision: 1))
        let original = try await service.installPlan(entryID: "remote.autoupdate", edition: .store)
        try await service.approve(original)

        try await service.acceptCatalog(signedCatalog(
            makeCatalog(providerID: "remote.autoupdate", version: "2"), key: key, revision: 2))
        var updates = await service.automaticUpdatePlans(edition: .store)
        XCTAssertEqual(updates.map(\.release.version), ["2"])
        XCTAssertTrue(updates[0].canInstallAutomatically)

        try await service.acceptCatalog(signedCatalog(
            makeCatalog(providerID: "remote.autoupdate", version: "3", permissions: [.network]),
            key: key, revision: 3))
        updates = await service.automaticUpdatePlans(edition: .store)
        XCTAssertTrue(updates.isEmpty)
        let expanded = try await service.installPlan(entryID: "remote.autoupdate", edition: .store)
        XCTAssertEqual(expanded.permissionsToApprove, [.network])
        XCTAssertFalse(expanded.canInstallAutomatically)
    }

    func testSignedRevocationUnregistersTheActiveProvider() async throws {
        let providerID = "remote.revocation-\(UUID().uuidString.lowercased())"
        let key = Curve25519.Signing.PrivateKey()
        let stateURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathExtension("json")
        let service = try TonicMarketplaceService(publicKeyData: key.publicKey.rawRepresentation,
                                                  stateURL: stateURL)
        await service.load()
        let catalog = makeCatalog(providerID: providerID, version: "1")
        try await service.acceptCatalog(signedCatalog(catalog, key: key, revision: 1))
        let plan = try await service.installPlan(entryID: providerID, edition: .store)
        try await service.approve(plan)
        try await TonicProviderRegistry.shared.register(MarketplaceProviderStub(
            manifest: catalog.entries[0].manifest))

        var revoked = catalog
        revoked.revokedReleaseIDs = ["\(providerID)@1"]
        try await service.acceptCatalog(signedCatalog(revoked, key: key, revision: 2))

        let manifests = await TonicProviderRegistry.shared.manifests()
        let diagnostics = await service.diagnostics()
        XCTAssertFalse(manifests.contains { $0.id == providerID })
        XCTAssertEqual(diagnostics.first?.state, .revokedVersion)
    }

    private func makeCatalog(providerID: String, version: String,
                             permissions: Set<TonicProviderPermission> = []) -> TonicMarketplaceCatalog {
        let manifest = TonicDataSourceManifest(id: providerID, displayName: "Provider",
            providerVersion: version, capabilities: [.label])
        let release = TonicProviderRelease(version: version, kind: .remoteJSON,
            artifactURL: URL(string: "https://example.com/\(providerID)-\(version).json")!,
            sha256: String(repeating: "a", count: 64), permissions: permissions,
            endpoints: [URL(string: "https://example.com/value.json")!], minimumRefreshSeconds: 60)
        return TonicMarketplaceCatalog(entries: [
            .init(id: providerID, providerName: "Provider", publisherName: "Tonic",
                  manifest: manifest, releases: [release])
        ])
    }

    private func signedCatalog(_ catalog: TonicMarketplaceCatalog,
                               key: Curve25519.Signing.PrivateKey,
                               revision: Int64) throws -> Data {
        let body = SignedArtifactBody(kind: TonicMarketplaceCatalog.artifactKind, revision: revision,
            validity: .init(issuedAt: Date().addingTimeInterval(-10), expiresAt: Date().addingTimeInterval(600)),
            payload: catalog)
        return try SignedArtifactCoding.canonicalData(for: SignedArtifactTestSupport.sign(body: body, privateKey: key))
    }
}
