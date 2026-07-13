#if !TONIC_STORE

import Foundation
import CryptoKit

public struct ScriptProcessRequest: Equatable, Sendable {
    public var executableURL: URL
    public var arguments: [String]
    public var workingDirectoryURL: URL?
    public var environment: [String: String]
    public var timeoutSeconds: Double
}

public struct ScriptProcessResult: Equatable, Sendable {
    public var exitStatus: Int32?
    public var stdout: Data
    public var stderr: Data
    public var timedOut: Bool
    public var errorDescription: String?
}

public protocol ScriptProcessLaunching: Sendable {
    func run(_ request: ScriptProcessRequest) async -> ScriptProcessResult
}

private final class BoundedDataCollector: @unchecked Sendable {
    private let lock = NSLock()
    private let limit: Int
    private var storage = Data()

    init(limit: Int) { self.limit = limit }
    func append(_ data: Data) {
        lock.lock(); defer { lock.unlock() }
        guard storage.count < limit else { return }
        storage.append(data.prefix(limit - storage.count))
    }
    func value() -> Data { lock.withLock { storage } }
}

private final class RunningScriptProcess: @unchecked Sendable {
    let process: Process
    init(_ process: Process) { self.process = process }
    func terminate() { if process.isRunning { process.terminate() } }
    func wait() async {
        await withCheckedContinuation { continuation in
            if !process.isRunning { continuation.resume(); return }
            process.terminationHandler = { _ in continuation.resume() }
        }
    }
}

public actor SystemScriptProcessLauncher: ScriptProcessLaunching {
    public static let shared = SystemScriptProcessLauncher()
    public static let maximumOutputBytes = 16 * 1_024

    public func run(_ request: ScriptProcessRequest) async -> ScriptProcessResult {
        let process = Process()
        process.executableURL = request.executableURL
        process.arguments = request.arguments
        process.currentDirectoryURL = request.workingDirectoryURL
        process.environment = request.environment
        let stdoutPipe = Pipe(), stderrPipe = Pipe()
        let stdout = BoundedDataCollector(limit: Self.maximumOutputBytes)
        let stderr = BoundedDataCollector(limit: Self.maximumOutputBytes)
        stdoutPipe.fileHandleForReading.readabilityHandler = { stdout.append($0.availableData) }
        stderrPipe.fileHandleForReading.readabilityHandler = { stderr.append($0.availableData) }
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            return ScriptProcessResult(exitStatus: nil, stdout: stdout.value(), stderr: stderr.value(),
                                       timedOut: false, errorDescription: error.localizedDescription)
        }

        let running = RunningScriptProcess(process)
        let timedOut = await withTaskGroup(of: Bool.self) { group in
            group.addTask { await running.wait(); return false }
            group.addTask {
                try? await Task.sleep(for: .seconds(request.timeoutSeconds))
                return true
            }
            let first = await group.next() ?? false
            group.cancelAll()
            return first
        }
        if timedOut {
            running.terminate()
            await running.wait()
        }
        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil
        stdout.append(stdoutPipe.fileHandleForReading.readDataToEndOfFile())
        stderr.append(stderrPipe.fileHandleForReading.readDataToEndOfFile())
        return ScriptProcessResult(exitStatus: process.terminationStatus, stdout: stdout.value(),
                                   stderr: stderr.value(), timedOut: timedOut, errorDescription: nil)
    }
}

public enum ScriptExecutionError: String, Codable, Error, Equatable, Sendable {
    case invalidExecutable, invalidArguments, invalidEnvironment, invalidBookmark
    case reviewRequired, alreadyRunning, pausedAfterFailures, launchFailed, timedOut, nonZeroExit
}

public struct CustomItemScriptPolicy: Sendable {
    public static let minimalPATH = "/usr/bin:/bin:/usr/sbin:/sbin"
    public static let maximumArguments = 64
    public static let maximumArgumentBytes = 4_096
    public static let maximumEnvironmentEntries = 32

    public init() {}

    public func validate(_ definition: CustomMenuBarScript, unattended: Bool,
                         reviewApproved: Bool) -> ScriptExecutionError? {
        guard definition.executable.hasPrefix("/"), !definition.executable.contains("\0") else {
            return .invalidExecutable
        }
        guard definition.arguments.count <= Self.maximumArguments,
              definition.arguments.allSatisfy({ $0.utf8.count <= Self.maximumArgumentBytes && !$0.contains("\0") }) else {
            return .invalidArguments
        }
        guard definition.environmentAllowlist.count <= Self.maximumEnvironmentEntries,
              definition.environmentAllowlist.allSatisfy({ key, value in
                  key.range(of: #"^[A-Za-z_][A-Za-z0-9_]*$"#, options: .regularExpression) != nil
                      && value.utf8.count <= Self.maximumArgumentBytes && !value.contains("\0")
              }) else { return .invalidEnvironment }
        if unattended && !reviewApproved { return .reviewRequired }
        if definition.isPaused || definition.failureCount >= 3 { return .pausedAfterFailures }
        return nil
    }

    public func environment(for definition: CustomMenuBarScript) -> [String: String] {
        ["PATH": Self.minimalPATH].merging(definition.environmentAllowlist) { _, reviewed in reviewed }
    }
}

public struct ScriptExecutionReceipt: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var scriptID: UUID
    public var startedAt: Date
    public var duration: TimeInterval
    public var exitStatus: Int32?
    public var stdout: String
    public var stderr: String
    public var error: ScriptExecutionError?
    public var mappedLabel: String?
    public var succeeded: Bool { error == nil && exitStatus == 0 }
}

public actor ScriptExecutionActor {
    private let launcher: any ScriptProcessLaunching
    private let policy: CustomItemScriptPolicy
    private let now: @Sendable () -> Date
    private var runningIDs = Set<UUID>()
    private var failureCounts: [UUID: Int] = [:]

    public init(launcher: any ScriptProcessLaunching = SystemScriptProcessLauncher.shared,
                policy: CustomItemScriptPolicy = .init(), now: @escaping @Sendable () -> Date = { Date() }) {
        self.launcher = launcher; self.policy = policy; self.now = now
    }

    public func execute(_ definition: CustomMenuBarScript, unattended: Bool = false,
                        reviewApproved: Bool = false) async -> ScriptExecutionReceipt {
        let started = now()
        if runningIDs.contains(definition.id) {
            return receipt(definition, started, result: nil, error: .alreadyRunning)
        }
        var effective = definition
        effective.failureCount = max(effective.failureCount, failureCounts[definition.id] ?? 0)
        effective.isPaused = effective.failureCount >= 3
        if let error = policy.validate(effective, unattended: unattended, reviewApproved: reviewApproved) {
            return receipt(effective, started, result: nil, error: error)
        }
        guard let prepared = makeRequest(effective) else {
            registerFailure(effective.id)
            return receipt(effective, started, result: nil, error: .invalidBookmark)
        }
        defer { prepared.scopedURLs.forEach { $0.stopAccessingSecurityScopedResource() } }
        runningIDs.insert(effective.id)
        defer { runningIDs.remove(effective.id) }
        let result = await launcher.run(prepared.request)
        let error: ScriptExecutionError? = result.timedOut ? .timedOut
            : result.errorDescription != nil ? .launchFailed
            : result.exitStatus == 0 ? nil : .nonZeroExit
        if error == nil { failureCounts[effective.id] = 0 } else { registerFailure(effective.id) }
        return receipt(effective, started, result: result, error: error)
    }

    public func resumeAfterReview(scriptID: UUID) { failureCounts[scriptID] = 0 }
    public func isPaused(scriptID: UUID) -> Bool { (failureCounts[scriptID] ?? 0) >= 3 }

    private func makeRequest(_ definition: CustomMenuBarScript) -> (request: ScriptProcessRequest, scopedURLs: [URL])? {
        var arguments = definition.arguments
        var scopedURLs: [URL] = []
        switch definition.source {
        case .inline(let command): arguments.append(command)
        case .securityScopedBookmark(let data):
            guard let url = resolve(data) else { return nil }
            scopedURLs.append(url); arguments.append(url.path)
        }
        var workingDirectory: URL?
        if let data = definition.workingDirectoryBookmark {
            guard let url = resolve(data) else { return nil }
            scopedURLs.append(url); workingDirectory = url
        }
        let request = ScriptProcessRequest(executableURL: URL(fileURLWithPath: definition.executable),
                                    arguments: arguments, workingDirectoryURL: workingDirectory,
                                    environment: policy.environment(for: definition),
                                    timeoutSeconds: min(max(definition.timeoutSeconds, 1), 300))
        return (request, scopedURLs)
    }

    private func resolve(_ data: Data) -> URL? {
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: [.withSecurityScope],
                                 relativeTo: nil, bookmarkDataIsStale: &stale), !stale,
              url.startAccessingSecurityScopedResource() else { return nil }
        return url
    }

    private func registerFailure(_ id: UUID) { failureCounts[id, default: 0] += 1 }

    private func receipt(_ definition: CustomMenuBarScript, _ started: Date,
                         result: ScriptProcessResult?, error: ScriptExecutionError?) -> ScriptExecutionReceipt {
        let stdout = sanitized(result?.stdout ?? Data())
        return ScriptExecutionReceipt(id: UUID(), scriptID: definition.id, startedAt: started,
            duration: max(0, now().timeIntervalSince(started)), exitStatus: result?.exitStatus,
            stdout: stdout, stderr: sanitized(result?.stderr ?? Data()), error: error,
            mappedLabel: definition.mapsFirstOutputLineToLabel && error == nil ? mappedLabel(stdout) : nil)
    }

    private func sanitized(_ data: Data) -> String {
        String(decoding: data.prefix(SystemScriptProcessLauncher.maximumOutputBytes), as: UTF8.self)
    }
    private func mappedLabel(_ output: String) -> String? {
        let line = output.split(whereSeparator: { $0.isNewline }).first.map(String.init) ?? ""
        let clean = String(line.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) }).trimmingCharacters(in: .whitespaces)
        return clean.isEmpty ? nil : String(clean.prefix(48))
    }
}

@MainActor
@Observable
public final class CustomItemScriptStore {
    public static let shared = CustomItemScriptStore()

    private struct Envelope: Codable {
        var version = 3
        var definitions: [CustomMenuBarScript] = []
        var reviewedFingerprints: [UUID: String] = [:]
        var scheduleIntervals: [UUID: TimeInterval] = [:]
        var mappedLabels: [UUID: String] = [:]

        private enum CodingKeys: String, CodingKey { case version, definitions, reviewedFingerprints, scheduleIntervals, mappedLabels }
        init(definitions: [CustomMenuBarScript] = [], reviewedFingerprints: [UUID: String] = [:],
             scheduleIntervals: [UUID: TimeInterval] = [:], mappedLabels: [UUID: String] = [:]) {
            self.definitions = definitions; self.reviewedFingerprints = reviewedFingerprints
            self.scheduleIntervals = scheduleIntervals; self.mappedLabels = mappedLabels
        }
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
            definitions = try container.decodeIfPresent([CustomMenuBarScript].self, forKey: .definitions) ?? []
            reviewedFingerprints = try container.decodeIfPresent([UUID: String].self, forKey: .reviewedFingerprints) ?? [:]
            scheduleIntervals = try container.decodeIfPresent([UUID: TimeInterval].self, forKey: .scheduleIntervals) ?? [:]
            mappedLabels = try container.decodeIfPresent([UUID: String].self, forKey: .mappedLabels) ?? [:]
        }
    }

    public private(set) var definitions: [CustomMenuBarScript]
    private var reviewedFingerprints: [UUID: String]
    public private(set) var scheduleIntervals: [UUID: TimeInterval]
    public private(set) var mappedLabels: [UUID: String]
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Tonic", isDirectory: true)
        self.fileURL = fileURL ?? root.appendingPathComponent("CustomItemScripts.json")
        if let data = try? Data(contentsOf: self.fileURL),
           let envelope = try? JSONDecoder().decode(Envelope.self, from: data) {
            definitions = envelope.definitions; reviewedFingerprints = envelope.reviewedFingerprints
            scheduleIntervals = envelope.scheduleIntervals
            mappedLabels = envelope.mappedLabels
        } else {
            definitions = []; reviewedFingerprints = [:]; scheduleIntervals = [:]; mappedLabels = [:]
        }
    }

    public func definition(id: UUID) -> CustomMenuBarScript? { definitions.first { $0.id == id } }

    public func save(_ definition: CustomMenuBarScript) {
        if let index = definitions.firstIndex(where: { $0.id == definition.id }) {
            if fingerprint(definitions[index]) != fingerprint(definition) { reviewedFingerprints.removeValue(forKey: definition.id) }
            definitions[index] = definition
        } else { definitions.append(definition) }
        persist()
    }

    public func remove(id: UUID) {
        definitions.removeAll { $0.id == id }; reviewedFingerprints.removeValue(forKey: id)
        scheduleIntervals.removeValue(forKey: id); mappedLabels.removeValue(forKey: id); persist()
    }

    public func approveReviewedExecution(id: UUID) {
        guard let definition = definition(id: id) else { return }
        reviewedFingerprints[id] = fingerprint(definition); persist()
    }

    public func isReviewed(id: UUID) -> Bool {
        guard let definition = definition(id: id) else { return false }
        return reviewedFingerprints[id] == fingerprint(definition)
    }

    public func setSchedule(scriptID: UUID, interval: TimeInterval?) {
        if let interval { scheduleIntervals[scriptID] = min(max(interval, 60), 86_400) }
        else { scheduleIntervals.removeValue(forKey: scriptID) }
        persist()
    }

    public func setMappedLabel(_ label: String, scriptID: UUID) {
        mappedLabels[scriptID] = String(label.prefix(48)); persist()
    }

    private func fingerprint(_ definition: CustomMenuBarScript) -> String {
        var reviewedDefinition = definition
        reviewedDefinition.failureCount = 0
        reviewedDefinition.isPaused = false
        let encoder = JSONEncoder()
        // Dictionary order is not a semantic part of the reviewed command.
        // Stable key ordering prevents an unchanged environment allowlist from
        // spuriously invalidating unattended-execution approval after reload.
        encoder.outputFormatting = [.sortedKeys]
        let data = (try? encoder.encode(reviewedDefinition)) ?? Data()
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func persist() {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(Envelope(definitions: definitions,
                                                         reviewedFingerprints: reviewedFingerprints,
                                                         scheduleIntervals: scheduleIntervals,
                                                         mappedLabels: mappedLabels))
            try data.write(to: fileURL, options: .atomic)
        } catch { /* surfaced when execution cannot resolve a definition */ }
    }
}

@MainActor
public final class ScriptExecutionCoordinator {
    public static let shared = ScriptExecutionCoordinator()
    private let store: CustomItemScriptStore
    private let executor: ScriptExecutionActor
    private var scheduleTimer: Timer?
    private var lastScheduledRun: [UUID: Date] = [:]

    init(store: CustomItemScriptStore = .shared, executor: ScriptExecutionActor = .init()) {
        self.store = store; self.executor = executor
    }

    public func startSchedules() {
        guard scheduleTimer == nil else { return }
        let now = Date()
        for id in store.scheduleIntervals.keys { lastScheduledRun[id] = now }
        scheduleTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in await self?.runDueSchedules() }
        }
    }

    private func runDueSchedules(now: Date = Date()) async {
        for (scriptID, interval) in store.scheduleIntervals {
            guard let last = lastScheduledRun[scriptID] else {
                lastScheduledRun[scriptID] = now
                continue
            }
            guard now.timeIntervalSince(last) >= interval else { continue }
            lastScheduledRun[scriptID] = now
            _ = await executeReviewed(scriptID: scriptID)
        }
    }

    public func executeReviewed(scriptID: UUID) async -> ScriptExecutionReceipt? {
        guard let definition = store.definition(id: scriptID) else { return nil }
        let receipt = await executor.execute(definition, unattended: true,
                                             reviewApproved: store.isReviewed(id: scriptID))
        ActionReceiptStore.shared.record(ActionReceipt(
            tool: .menuBar, title: receipt.succeeded ? "Custom script completed" : "Custom script failed",
            detail: receipt.error?.rawValue ?? "Exited with status \(receipt.exitStatus ?? 0).",
            status: receipt.succeeded ? .success : .failed, affectedItems: 1,
            metadata: ["scriptID": scriptID.uuidString, "duration": String(receipt.duration),
                       "stdout": receipt.stdout, "stderr": receipt.stderr]
        ))
        var updated = definition
        let countedErrors: Set<ScriptExecutionError> = [.invalidBookmark, .launchFailed, .timedOut, .nonZeroExit]
        let countsAsFailure = receipt.error.map(countedErrors.contains) ?? false
        if receipt.succeeded { updated.failureCount = 0 }
        else if countsAsFailure { updated.failureCount = min(3, definition.failureCount + 1) }
        updated.isPaused = updated.failureCount >= 3
        store.save(updated)
        if let label = receipt.mappedLabel {
            store.setMappedLabel(label, scriptID: scriptID)
            MenuBarOwnedItemCoordinator.shared.refreshScriptLabel(scriptID: scriptID, label: label)
        }
        return receipt
    }

    public func resumeAfterReview(scriptID: UUID) async {
        guard var definition = store.definition(id: scriptID) else { return }
        definition.failureCount = 0; definition.isPaused = false
        store.save(definition); store.approveReviewedExecution(id: scriptID)
        await executor.resumeAfterReview(scriptID: scriptID)
    }
}

#endif
