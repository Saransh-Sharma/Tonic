#if !TONIC_STORE

import CryptoKit
import Foundation
import Security

public struct TonicExecutableProviderBundleManifest: Codable, Equatable, Sendable {
    public var provider: TonicDataSourceManifest
    public var executableRelativePath: String
}

public enum TonicExecutableProviderError: Error, Equatable {
    case invalidBundle, invalidSignature, approvalRequired(String), alreadyRunning
    case launchFailed, timedOut, responseTooLarge, malformedResponse, pausedAfterFailures
}

public struct TonicExecutableProviderConfiguration: Codable, Identifiable, Equatable, Sendable {
    public var id: String { manifest.id }
    public var manifest: TonicDataSourceManifest
    public var bundleBookmark: Data
    public var usesDeveloperMode: Bool
    public var approvedCodeHash: String
    public var addedAt: Date
}

@MainActor
@Observable
public final class TonicExecutableProviderStore {
    public static let shared = TonicExecutableProviderStore()
    public private(set) var configurations: [TonicExecutableProviderConfiguration]
    private let fileURL: URL
    private let approvalStore: TonicProviderApprovalStore
    private var scopedURLs: [String: URL] = [:]
    private var providers: [String: TonicExecutableProvider] = [:]

    init(fileURL: URL? = nil, approvalStore: TonicProviderApprovalStore = .shared) {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Tonic", isDirectory: true)
        self.fileURL = fileURL ?? root.appendingPathComponent("ExecutableProviders.json")
        self.approvalStore = approvalStore
        configurations = (try? Data(contentsOf: self.fileURL)).flatMap {
            try? TonicProviderCoding.decoder().decode([TonicExecutableProviderConfiguration].self, from: $0)
        } ?? []
    }

    public func add(bundleURL: URL, advancedDeveloperMode: Bool,
                    expectedTeamIdentifier: String? = nil) async throws {
        let bookmark = try bundleURL.bookmarkData(options: [.withSecurityScope],
                                                  includingResourceValuesForKeys: nil, relativeTo: nil)
        let scoped = bundleURL.startAccessingSecurityScopedResource()
        do {
            let provider = try await TonicExecutableProvider(bundleURL: bundleURL,
                advancedDeveloperMode: advancedDeveloperMode, approvalStore: approvalStore,
                expectedTeamIdentifier: expectedTeamIdentifier)
            guard TonicProviderManifestPolicy.isValid(provider.manifest),
                  !provider.manifest.id.hasPrefix("tonic."), !provider.manifest.id.hasPrefix("remote.") else {
                throw TonicExecutableProviderError.invalidBundle
            }
            if configurations.contains(where: { $0.manifest.id == provider.manifest.id }) {
                await TonicProviderRegistry.shared.unregister(id: provider.manifest.id)
            }
            try await TonicProviderRegistry.shared.register(provider)
            providers[provider.manifest.id] = provider
            configurations.removeAll { $0.manifest.id == provider.manifest.id }
            configurations.append(TonicExecutableProviderConfiguration(
                manifest: provider.manifest, bundleBookmark: bookmark,
                usesDeveloperMode: advancedDeveloperMode, approvedCodeHash: provider.codeHash, addedAt: Date()))
            if let prior = scopedURLs.removeValue(forKey: provider.manifest.id) {
                prior.stopAccessingSecurityScopedResource()
            }
            if scoped { scopedURLs[provider.manifest.id] = bundleURL }
            persist()
        } catch {
            if scoped { bundleURL.stopAccessingSecurityScopedResource() }
            throw error
        }
    }

    public func registerPersisted() {
        for configuration in configurations {
            Task { @MainActor in
                var stale = false
                guard let url = try? URL(resolvingBookmarkData: configuration.bundleBookmark,
                    options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &stale), !stale else { return }
                let scoped = url.startAccessingSecurityScopedResource()
                do {
                    let provider = try await TonicExecutableProvider(bundleURL: url,
                        advancedDeveloperMode: configuration.usesDeveloperMode, approvalStore: approvalStore)
                    guard provider.codeHash == configuration.approvedCodeHash else {
                        throw TonicExecutableProviderError.approvalRequired(provider.codeHash)
                    }
                    try await TonicProviderRegistry.shared.register(provider)
                    providers[configuration.manifest.id] = provider
                    if scoped { scopedURLs[configuration.manifest.id] = url }
                } catch {
                    if scoped { url.stopAccessingSecurityScopedResource() }
                }
            }
        }
    }

    public func remove(id: String) {
        configurations.removeAll { $0.manifest.id == id }
        if let url = scopedURLs.removeValue(forKey: id) { url.stopAccessingSecurityScopedResource() }
        persist()
        Task { await TonicProviderRegistry.shared.unregister(id: id) }
        providers.removeValue(forKey: id)
    }

    public func resumeAfterReview(id: String) async {
        await providers[id]?.resumeAfterReview()
        await TonicProviderRegistry.shared.resumeAfterReview(providerID: id)
    }

    private func persist() {
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? TonicProviderCoding.encoder().encode(configurations).write(to: fileURL, options: .atomic)
    }
}

@MainActor
public final class TonicProviderApprovalStore {
    public static let shared = TonicProviderApprovalStore()
    private let fileURL: URL
    private var approvedHashes = Set<String>()

    init(fileURL: URL? = nil) {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Tonic", isDirectory: true)
        self.fileURL = fileURL ?? root.appendingPathComponent("ApprovedProviderHashes.json")
        if let data = try? Data(contentsOf: self.fileURL),
           let values = try? JSONDecoder().decode(Set<String>.self, from: data) { approvedHashes = values }
    }
    public func approve(codeHash: String) { approvedHashes.insert(codeHash); persist() }
    public func isApproved(codeHash: String) -> Bool { approvedHashes.contains(codeHash) }
    private func persist() {
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(approvedHashes).write(to: fileURL, options: .atomic)
    }
}

private final class ProviderProcessBox: @unchecked Sendable {
    let process: Process
    init(_ process: Process) { self.process = process }
    func wait() async { await withCheckedContinuation { continuation in
        if !process.isRunning { continuation.resume() }
        else { process.terminationHandler = { _ in continuation.resume() } }
    } }
    func terminate() { if process.isRunning { process.terminate() } }
}

private final class ProviderOutputCollector: @unchecked Sendable {
    private let lock = NSLock(); private var data = Data(); private let limit: Int
    init(limit: Int) { self.limit = limit }
    func append(_ chunk: Data) { lock.withLock {
        if data.count <= limit { data.append(chunk.prefix(limit + 1 - data.count)) }
    } }
    func value() -> Data { lock.withLock { data } }
}

public actor TonicExecutableProvider: TonicDataSourceProvider {
    public nonisolated let manifest: TonicDataSourceManifest
    public let bundleURL: URL
    public let executableURL: URL
    public nonisolated let codeHash: String
    private var isRunning = false
    private var failureCount = 0
    private let responseLimit = 256 * 1_024
    private let timeoutSeconds: Double

    public init(bundleURL: URL, advancedDeveloperMode: Bool = false,
                approvalStore: TonicProviderApprovalStore? = nil,
                expectedTeamIdentifier: String? = nil,
                timeoutSeconds: Double = 15) async throws {
        guard bundleURL.pathExtension == "tonicprovider" else { throw TonicExecutableProviderError.invalidBundle }
        let manifestURL = bundleURL.appendingPathComponent("provider.json")
        let manifestSize = (try? manifestURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard manifestSize > 0, manifestSize <= 64 * 1_024 else { throw TonicExecutableProviderError.invalidBundle }
        let data = try Data(contentsOf: manifestURL)
        let bundleManifest = try TonicProviderCoding.decoder().decode(TonicExecutableProviderBundleManifest.self, from: data)
        guard bundleManifest.provider.supportedSchemaRange.overlap(with: .hostSupported) != nil,
              !bundleManifest.executableRelativePath.hasPrefix("/"),
              !bundleManifest.executableRelativePath.contains("..") else { throw TonicExecutableProviderError.invalidBundle }
        let bundleRoot = bundleURL.standardizedFileURL.resolvingSymlinksInPath()
        let executable = bundleURL.appendingPathComponent(bundleManifest.executableRelativePath)
            .standardizedFileURL.resolvingSymlinksInPath()
        guard executable.path.hasPrefix(bundleRoot.path + "/"),
              FileManager.default.isExecutableFile(atPath: executable.path) else { throw TonicExecutableProviderError.invalidBundle }
        let hash = try Self.hash(executable)
        let signed = Self.hasDeveloperIDSignature(executable, expectedTeamIdentifier: expectedTeamIdentifier)
        if !signed {
            guard advancedDeveloperMode else { throw TonicExecutableProviderError.invalidSignature }
            let approved = await MainActor.run {
                (approvalStore ?? TonicProviderApprovalStore.shared).isApproved(codeHash: hash)
            }
            guard approved else { throw TonicExecutableProviderError.approvalRequired(hash) }
        }
        manifest = bundleManifest.provider; self.bundleURL = bundleURL; executableURL = executable
        codeHash = hash; self.timeoutSeconds = min(max(timeoutSeconds, 1), 60)
    }

    public func snapshot(for request: TonicDataSourceRequest) async throws -> TonicDataSourceSnapshot {
        guard failureCount < 3 else { throw TonicExecutableProviderError.pausedAfterFailures }
        guard !isRunning else { throw TonicExecutableProviderError.alreadyRunning }
        isRunning = true; defer { isRunning = false }
        do {
            let snapshot = try await launch(request)
            failureCount = 0
            return snapshot
        } catch {
            failureCount += 1
            throw error
        }
    }

    public func resumeAfterReview() { failureCount = 0 }

    private func launch(_ request: TonicDataSourceRequest) async throws -> TonicDataSourceSnapshot {
        let process = Process(); let input = Pipe(), output = Pipe(), errors = Pipe()
        let responseCollector = ProviderOutputCollector(limit: responseLimit)
        let errorCollector = ProviderOutputCollector(limit: 16 * 1_024)
        output.fileHandleForReading.readabilityHandler = { responseCollector.append($0.availableData) }
        errors.fileHandleForReading.readabilityHandler = { errorCollector.append($0.availableData) }
        process.executableURL = executableURL; process.arguments = []
        process.currentDirectoryURL = bundleURL
        process.environment = ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin"]
        process.standardInput = input; process.standardOutput = output; process.standardError = errors
        do { try process.run() } catch { throw TonicExecutableProviderError.launchFailed }
        var payload = try TonicProviderCoding.encoder().encode(request); payload.append(0x0A)
        try input.fileHandleForWriting.write(contentsOf: payload); try input.fileHandleForWriting.close()
        let box = ProviderProcessBox(process)
        let timedOut = await withTaskGroup(of: Bool.self) { group in
            group.addTask { await box.wait(); return false }
            let timeout = self.timeoutSeconds
            group.addTask { try? await Task.sleep(for: .seconds(timeout)); return true }
            let first = await group.next() ?? false; group.cancelAll(); return first
        }
        if timedOut {
            box.terminate(); await box.wait()
            output.fileHandleForReading.readabilityHandler = nil; errors.fileHandleForReading.readabilityHandler = nil
            throw TonicExecutableProviderError.timedOut
        }
        output.fileHandleForReading.readabilityHandler = nil; errors.fileHandleForReading.readabilityHandler = nil
        responseCollector.append((try? output.fileHandleForReading.readToEnd()) ?? Data())
        errorCollector.append((try? errors.fileHandleForReading.readToEnd()) ?? Data())
        let response = responseCollector.value()
        guard response.count <= responseLimit else { throw TonicExecutableProviderError.responseTooLarge }
        let lines = response.split(separator: 0x0A, omittingEmptySubsequences: true)
        guard lines.count == 1, let line = lines.first else {
            throw TonicExecutableProviderError.malformedResponse
        }
        let snapshot = try TonicProviderCoding.decoder().decode(TonicDataSourceSnapshot.self, from: Data(line))
        guard manifest.supportedSchemaRange.contains(snapshot.schemaVersion),
              TonicProviderSchemaRange.hostSupported.contains(snapshot.schemaVersion) else {
            throw TonicExecutableProviderError.malformedResponse
        }
        return TonicDataSourceSnapshot(schemaVersion: snapshot.schemaVersion, requestID: request.requestID,
            label: snapshot.label, symbolName: snapshot.symbolName, imageReference: snapshot.imageReference,
            accessibilityText: snapshot.accessibilityText, generatedAt: snapshot.generatedAt,
            expiresAt: snapshot.expiresAt, status: snapshot.status)
    }

    private static func hash(_ url: URL) throws -> String {
        let digest = SHA256.hash(data: try Data(contentsOf: url, options: .mappedIfSafe))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func hasDeveloperIDSignature(_ url: URL, expectedTeamIdentifier: String?) -> Bool {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess, let code else { return false }
        var requirement: SecRequirement?
        let teamClause = expectedTeamIdentifier.map { " and certificate leaf[subject.OU] = \"\($0)\"" } ?? ""
        let text = "anchor apple generic and certificate leaf[field.1.2.840.113635.100.6.1.13] exists\(teamClause)"
        guard SecRequirementCreateWithString(text as CFString, [], &requirement) == errSecSuccess,
              let requirement else { return false }
        return SecStaticCodeCheckValidity(code, [], requirement) == errSecSuccess
    }
}

#endif
