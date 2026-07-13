import Foundation

final class RecoveryProcessBox: @unchecked Sendable {
    let process: Process
    init(_ process: Process) { self.process = process }
    func wait() async {
        await withCheckedContinuation { continuation in
            if !process.isRunning { continuation.resume() }
            else { process.terminationHandler = { _ in continuation.resume() } }
        }
    }
    func terminate() { if process.isRunning { process.terminate() } }
}

final class RecoveryOutputCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()
    private let limit: Int

    init(limit: Int = 8 * 1_024) {
        self.limit = max(0, limit)
    }

    func append(_ value: Data) { lock.withLock {
        guard data.count < limit else { return }
        data.append(value.prefix(limit - data.count))
    } }
    func value() -> Data { lock.withLock { data } }
}

struct RecoveryBoundedProcessResult: Sendable {
    var terminationStatus: Int32
    var stdout: Data
    var stderr: Data
    var timedOut: Bool
}

enum RecoveryBoundedProcessRunner {
    static func run(executable: String, arguments: [String], timeout: Duration,
                    outputLimit: Int) async throws -> RecoveryBoundedProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        let stdout = RecoveryOutputCollector(limit: outputLimit)
        let stderr = RecoveryOutputCollector(limit: outputLimit)
        stdoutPipe.fileHandleForReading.readabilityHandler = { stdout.append($0.availableData) }
        stderrPipe.fileHandleForReading.readabilityHandler = { stderr.append($0.availableData) }
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            throw error
        }

        let box = RecoveryProcessBox(process)
        let timedOut = await withTaskGroup(of: Bool.self) { group in
            group.addTask { await box.wait(); return false }
            group.addTask { try? await Task.sleep(for: timeout); return true }
            let first = await group.next() ?? false
            group.cancelAll()
            if first { box.terminate() }
            return first
        }

        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil
        stdout.append((try? stdoutPipe.fileHandleForReading.readToEnd()) ?? Data())
        stderr.append((try? stderrPipe.fileHandleForReading.readToEnd()) ?? Data())
        return RecoveryBoundedProcessResult(
            terminationStatus: process.terminationStatus,
            stdout: stdout.value(),
            stderr: stderr.value(),
            timedOut: timedOut
        )
    }
}

public struct RecoveryOperationResult: Equatable, Sendable {
    public var succeeded: Bool
    public var detail: String
    public var affectedItems: Int

    public init(succeeded: Bool, detail: String, affectedItems: Int = 0) {
        self.succeeded = succeeded
        self.detail = detail
        self.affectedItems = affectedItems
    }
}

public typealias RecoveryActionHandler = @Sendable (RecoveryActionID) async -> RecoveryOperationResult
public typealias RecoveryStepConfirmation = @MainActor @Sendable (RecoveryStep) async -> Bool
public typealias RecoveryProgressHandler = @MainActor @Sendable (RecoveryStepResult) -> Void

public actor RecoveryLocalActionRunner {
    public static let shared = RecoveryLocalActionRunner()

    public func perform(_ action: RecoveryActionID) async -> RecoveryOperationResult {
        let invocation: (String, [String])?
        switch action {
        case .restartUserService(let service):
            invocation = ("/usr/bin/killall", [service.rawValue])
        case .rebuildLaunchServices:
            invocation = (
                "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister",
                ["-kill", "-r", "-domain", "local", "-domain", "system", "-domain", "user"]
            )
        default:
            invocation = nil
        }
        guard let invocation else {
            return RecoveryOperationResult(succeeded: false,
                                           detail: String(localized: "This action requires the privileged helper."))
        }
        do {
            let result = try await RecoveryBoundedProcessRunner.run(
                executable: invocation.0,
                arguments: invocation.1,
                timeout: .seconds(60),
                outputLimit: 8 * 1_024
            )
            let combined = result.stdout + result.stderr
            let output = String(decoding: combined.prefix(4_096), as: UTF8.self)
            let succeeded = !result.timedOut && result.terminationStatus == 0
            return RecoveryOperationResult(succeeded: succeeded,
                detail: result.timedOut ? String(localized: "The local recovery operation timed out.")
                    : (output.isEmpty ? (succeeded ? String(localized: "Operation completed.") : String(localized: "Operation failed.")) : output),
                affectedItems: succeeded ? 1 : 0)
        } catch {
            return RecoveryOperationResult(succeeded: false, detail: error.localizedDescription)
        }
    }
}

public actor RecoveryExecutionActor {
    private let performAction: RecoveryActionHandler
    private let now: @Sendable () -> Date

    public init(now: @escaping @Sendable () -> Date = { Date() }) {
        self.performAction = RecoveryExecutionActor.productionHandler
        self.now = now
    }

    public init(performAction: @escaping RecoveryActionHandler,
                now: @escaping @Sendable () -> Date = { Date() }) {
        self.performAction = performAction
        self.now = now
    }

    public func execute(_ plan: RecoveryPlan,
                        confirm: @escaping RecoveryStepConfirmation,
                        progress: @escaping RecoveryProgressHandler,
                        revalidate: @escaping @Sendable () async -> Void = {}) async -> RecoveryExecutionResult {
        var results: [RecoveryStepResult] = []
        var stoppedAfterFailure = false
        for step in plan.selectedSteps {
            if step.isReportOnly {
                let current = now()
                let result = RecoveryStepResult(stepID: step.id, action: step.action, status: .reportOnly,
                    detail: String(localized: "This edition provides diagnosis and guided recovery without performing the system change."),
                    startedAt: current, completedAt: current)
                results.append(result)
                await progress(result)
                continue
            }
            if step.action.isDisruptive {
                let approved = await confirm(step)
                if !approved {
                    let current = now()
                    let result = RecoveryStepResult(stepID: step.id, action: step.action, status: .skipped,
                        detail: String(localized: "The user declined the focused confirmation."), startedAt: current, completedAt: current)
                    results.append(result)
                    await progress(result)
                    continue
                }
            }
            let started = now()
            let raw = await performAction(step.action)
            let result = RecoveryStepResult(stepID: step.id, action: step.action,
                status: raw.succeeded ? .succeeded : .failed, detail: raw.detail,
                startedAt: started, completedAt: now(), affectedItems: raw.affectedItems)
            results.append(result)
            await progress(result)
            if raw.succeeded { await revalidate() }
            else { stoppedAfterFailure = true; break }
        }
        return RecoveryExecutionResult(planID: plan.id, results: results, stoppedAfterFailure: stoppedAfterFailure)
    }

    private static let productionHandler: RecoveryActionHandler = { action in
        #if TONIC_STORE
        return RecoveryOperationResult(succeeded: false,
            detail: String(localized: "The Mac App Store edition provides guided recovery for this operation."))
        #else
        if let operation = privilegedOperation(for: action) {
            let result = await TonicHelperClient.shared.perform(operation)
            return RecoveryOperationResult(succeeded: result.succeeded, detail: result.detail,
                                           affectedItems: result.affectedItems)
        }
        return await RecoveryLocalActionRunner.shared.perform(action)
        #endif
    }

    #if !TONIC_STORE
    private static func privilegedOperation(for action: RecoveryActionID) -> TonicPrivilegedOperation? {
        switch action {
        case .refreshDNS: .refreshDNS
        case .renewPrimaryNetwork: .renewPrimaryNetworkService
        case .rebuildSpotlightStartupDisk: .rebuildSpotlight(scope: .startupDisk)
        case .rebuildLaunchServices, .restartUserService: nil
        case .restartSystemService(let service): .restartSystemService(service: service)
        case .reclaimLocalSnapshots: .deleteLocalTimeMachineSnapshots
        case .purgeDocumentRevisions(let days): .purgeStaleDocumentRevisions(minimumAgeDays: days)
        case .purgeStaleSystemData(let domain, let days):
            .purgeStaleSystemData(domain: domain, minimumAgeDays: days)
        }
    }
    #endif
}
