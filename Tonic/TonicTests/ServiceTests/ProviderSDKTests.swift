import XCTest
@testable import Tonic

private struct StubTonicProvider: TonicDataSourceProvider {
    let manifest = TonicDataSourceManifest(id: "test.provider", displayName: "Test", providerVersion: "1",
                                           capabilities: [.label])
    func snapshot(for request: TonicDataSourceRequest) async throws -> TonicDataSourceSnapshot {
        TonicDataSourceSnapshot(requestID: request.requestID, label: "Ready\n", status: .good)
    }
}

private actor CountingTonicProvider: TonicDataSourceProvider {
    nonisolated let manifest = TonicDataSourceManifest(id: "counting.provider", displayName: "Counter",
                                                       providerVersion: "1", minimumRefreshSeconds: 60,
                                                       capabilities: [.label])
    private var calls = 0
    func snapshot(for request: TonicDataSourceRequest) async throws -> TonicDataSourceSnapshot {
        calls += 1
        return TonicDataSourceSnapshot(requestID: request.requestID, label: "Call \(calls)")
    }
    func callCount() -> Int { calls }
}

private struct InvalidManifestProvider: TonicDataSourceProvider {
    let manifest: TonicDataSourceManifest
    func snapshot(for request: TonicDataSourceRequest) async throws -> TonicDataSourceSnapshot { .init() }
}

private struct FailingTonicProvider: TonicDataSourceProvider {
    let manifest = TonicDataSourceManifest(id: "failing.provider", displayName: "Failing",
                                           providerVersion: "1", capabilities: [.label])
    func snapshot(for request: TonicDataSourceRequest) async throws -> TonicDataSourceSnapshot {
        throw CocoaError(.fileReadUnknown)
    }
}

final class ProviderSDKTests: XCTestCase {
    func testSnapshotSanitizesControlCharactersAndLength() {
        let snapshot = TonicDataSourceSnapshot(label: String(repeating: "a", count: 100) + "\n")
        XCTAssertEqual(snapshot.label?.count, 64)
        XCTAssertFalse(snapshot.label?.contains("\n") == true)
    }

    func testRemotePolicyRequiresHTTPSAndBlocksPrivateHosts() {
        XCTAssertEqual(TonicRemoteProviderPolicy.validate(URL(string: "http://example.com")!, allowsPrivateNetwork: false), .httpsRequired)
        XCTAssertEqual(TonicRemoteProviderPolicy.validate(URL(string: "https://192.168.1.4/data")!, allowsPrivateNetwork: false), .privateNetworkBlocked)
        XCTAssertNil(TonicRemoteProviderPolicy.validate(URL(string: "https://example.com/data")!, allowsPrivateNetwork: false))
        XCTAssertEqual(TonicRemoteProviderPolicy.validateResolved(URL(string: "https://100.64.0.2/data")!,
                                                                  allowsPrivateNetwork: false), .privateNetworkBlocked)
    }

    func testJSONDepthAndNodeBounds() throws {
        XCTAssertTrue(TonicRemoteProviderPolicy.validateJSONShape(["label": "ok"]))
        var nested: Any = "value"
        for _ in 0..<12 { nested = [nested] }
        XCTAssertFalse(TonicRemoteProviderPolicy.validateJSONShape(nested))
    }

    func testRegistryUsesSharedProviderInterface() async throws {
        let registry = TonicProviderRegistry()
        try await registry.register(StubTonicProvider())
        let request = TonicDataSourceRequest(providerID: "test.provider")
        let snapshot = try await registry.snapshot(providerID: "test.provider", request: request)
        XCTAssertEqual(snapshot.label, "Ready")
        XCTAssertEqual(snapshot.requestID, request.requestID)
    }

    func testRegistryEnforcesManifestAndRefreshFloor() async throws {
        let registry = TonicProviderRegistry()
        let provider = CountingTonicProvider()
        try await registry.register(provider)
        let first = TonicDataSourceRequest(providerID: provider.manifest.id)
        let second = TonicDataSourceRequest(providerID: provider.manifest.id)
        let initial = try await registry.snapshot(providerID: provider.manifest.id, request: first)
        XCTAssertEqual(initial.label, "Call 1")
        let cached = try await registry.snapshot(providerID: provider.manifest.id, request: second)
        XCTAssertEqual(cached.label, "Call 1")
        XCTAssertEqual(cached.requestID, second.requestID)
        let callCount = await provider.callCount()
        XCTAssertEqual(callCount, 1)

        let invalid = InvalidManifestProvider(manifest: TonicDataSourceManifest(
            id: "bad provider id", displayName: "Bad", providerVersion: "1", capabilities: [.label]
        ))
        do {
            try await registry.register(invalid)
            XCTFail("Expected manifest rejection")
        } catch let error as TonicProviderRegistryError {
            XCTAssertEqual(error, .invalidManifest)
        }
    }

    func testRegistryPausesFailuresUntilReviewedResume() async throws {
        let registry = TonicProviderRegistry(); try await registry.register(FailingTonicProvider())
        let request = TonicDataSourceRequest(providerID: "failing.provider")
        for _ in 0..<3 { _ = try? await registry.snapshot(providerID: "failing.provider", request: request) }
        do {
            _ = try await registry.snapshot(providerID: "failing.provider", request: request)
            XCTFail("Expected paused provider")
        } catch let error as TonicProviderRegistryError { XCTAssertEqual(error, .pausedAfterFailures) }
        await registry.resumeAfterReview(providerID: "failing.provider")
        let paused = await registry.isPaused(providerID: "failing.provider")
        XCTAssertFalse(paused)
    }

    @MainActor
    func testReviewedRemoteConfigurationPersistsOnlySecretIdentifier() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let file = directory.appendingPathComponent("providers.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = TonicRemoteProviderStore(fileURL: file)
        let manifest = TonicDataSourceManifest(id: "remote.test", displayName: "Remote", providerVersion: "1",
                                               capabilities: [.label])
        try store.addReviewed(.init(manifest: manifest, endpoint: URL(string: "https://example.com/value")!,
                                    refreshInterval: 300, secretIdentifier: "secret.reference"))
        let data = try Data(contentsOf: file)
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(text.contains("secret.reference"))
        XCTAssertFalse(text.contains("Bearer"))
        XCTAssertEqual(store.configurations.count, 1)
    }


    #if !TONIC_STORE
    @MainActor
    func testExecutableProviderRejectsPathTraversalAndUnsignedBundleNeedsHashApproval() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathExtension("tonicprovider")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let providerManifest = TonicDataSourceManifest(id: "local.test", displayName: "Local", providerVersion: "1",
                                                       capabilities: [.label])
        let traversal = TonicExecutableProviderBundleManifest(provider: providerManifest,
                                                               executableRelativePath: "../escape")
        try JSONEncoder().encode(traversal).write(to: root.appendingPathComponent("provider.json"))
        do {
            _ = try await TonicExecutableProvider(bundleURL: root, advancedDeveloperMode: true)
            XCTFail("Expected traversal rejection")
        } catch let error as TonicExecutableProviderError { XCTAssertEqual(error, .invalidBundle) }

        let executable = root.appendingPathComponent("provider")
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
        try JSONEncoder().encode(TonicExecutableProviderBundleManifest(provider: providerManifest,
                                                                        executableRelativePath: "provider"))
            .write(to: root.appendingPathComponent("provider.json"))
        do {
            _ = try await TonicExecutableProvider(bundleURL: root, advancedDeveloperMode: false)
            XCTFail("Expected signature rejection")
        } catch let error as TonicExecutableProviderError { XCTAssertEqual(error, .invalidSignature) }
    }

    @MainActor
    func testApprovedUnsignedProviderRunsOutOfProcessAndReturnsSanitizedSnapshot() async throws {
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let root = parent.appendingPathComponent("Sample.tonicprovider")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parent) }
        let manifest = TonicDataSourceManifest(id: "unsigned.sample", displayName: "Unsigned", providerVersion: "1",
                                               capabilities: [.label])
        try TonicProviderCoding.encoder().encode(TonicExecutableProviderBundleManifest(
            provider: manifest, executableRelativePath: "provider"))
            .write(to: root.appendingPathComponent("provider.json"))
        let executable = root.appendingPathComponent("provider")
        try Data("#!/bin/sh\nread request\nprintf '{\"schemaVersion\":1,\"label\":\"Ready\",\"generatedAt\":\"2026-07-12T00:00:00Z\",\"status\":\"good\"}\\n'\n".utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
        let approvals = TonicProviderApprovalStore(fileURL: parent.appendingPathComponent("approvals.json"))
        let hash: String
        do {
            _ = try await TonicExecutableProvider(bundleURL: root, advancedDeveloperMode: true, approvalStore: approvals)
            XCTFail("Expected immutable hash review")
            return
        } catch TonicExecutableProviderError.approvalRequired(let requiredHash) { hash = requiredHash }
        approvals.approve(codeHash: hash)
        let provider = try await TonicExecutableProvider(bundleURL: root, advancedDeveloperMode: true,
                                                         approvalStore: approvals)
        let snapshot = try await provider.snapshot(for: .init(providerID: manifest.id))
        XCTAssertEqual(snapshot.label, "Ready")
        XCTAssertEqual(snapshot.status, .good)

        let persistedURL = parent.appendingPathComponent("installed.json")
        let store = TonicExecutableProviderStore(fileURL: persistedURL, approvalStore: approvals)
        try await store.add(bundleURL: root, advancedDeveloperMode: true)
        XCTAssertEqual(store.configurations.map(\.manifest.id), [manifest.id])
        let persisted = String(decoding: try Data(contentsOf: persistedURL), as: UTF8.self)
        XCTAssertTrue(persisted.contains(manifest.id))
        XCTAssertTrue(persisted.contains(hash))
        store.remove(id: manifest.id)
    }
    #endif
}
