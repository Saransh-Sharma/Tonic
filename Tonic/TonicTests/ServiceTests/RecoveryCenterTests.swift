import XCTest
@testable import Tonic

private struct StubRecoveryProbe: RecoveryProbing {
    let value: RecoveryProbeSnapshot
    func snapshot() async -> RecoveryProbeSnapshot { value }
}

final class RecoveryCenterTests: XCTestCase {
    func testBoundedProcessRunnerDrainsOutputWithoutWaitingForExitFirst() async throws {
        let result = try await RecoveryBoundedProcessRunner.run(
            executable: "/usr/bin/printf",
            arguments: ["diagnostic output"],
            timeout: .seconds(1),
            outputLimit: 64
        )

        XCTAssertFalse(result.timedOut)
        XCTAssertEqual(result.terminationStatus, 0)
        XCTAssertEqual(String(decoding: result.stdout, as: UTF8.self), "diagnostic output")
        XCTAssertTrue(result.stderr.isEmpty)
    }

    func testBoundedProcessRunnerStopsAndCapsNoisyCommand() async throws {
        let result = try await RecoveryBoundedProcessRunner.run(
            executable: "/usr/bin/yes",
            arguments: [],
            timeout: .milliseconds(50),
            outputLimit: 1_024
        )

        XCTAssertTrue(result.timedOut)
        XCTAssertLessThanOrEqual(result.stdout.count, 1_024)
        XCTAssertLessThanOrEqual(result.stderr.count, 1_024)
    }

    func testPlannerRecommendsOnlyFailedDiagnostics() async {
        let probe = StubRecoveryProbe(value: .init(
            dnsHealthy: false, networkHealthy: true, spotlightHealthy: false,
            launchServicesHealthy: true,
            userServices: [.finder: true, .dock: true, .systemUIServer: true],
            systemServices: [.audio: true, .bluetooth: true, .printing: true],
            timeMachineHealthy: true
        ))
        let diagnostics = await RecoveryDiagnosticActor(probe: probe).diagnose()
        let plan = RecoveryPlanBuilder.makePlan(diagnostics: diagnostics, edition: .direct,
                                                now: Date(timeIntervalSince1970: 1))
        XCTAssertEqual(plan.steps.map(\.action), [.refreshDNS, .rebuildSpotlightStartupDisk])
    }

    func testStorePlanIsTruthfullyReportOnly() {
        let diagnostics = [RecoveryDiagnostic(id: .dns, title: "DNS", detail: "Failed", evidence: "Failed",
                                              severity: .warning, suggestedAction: .refreshDNS)]
        let plan = RecoveryPlanBuilder.makePlan(diagnostics: diagnostics, edition: .store)
        XCTAssertTrue(plan.steps.first?.isReportOnly == true)
    }

    func testExecutionStopsAfterFirstFailure() async {
        let calls = LockedCounter()
        let executor = RecoveryExecutionActor(performAction: { _ in
            let count = calls.increment()
            return RecoveryOperationResult(succeeded: count == 1,
                                           detail: count == 1 ? "ok" : "failed")
        })
        let plan = RecoveryPlan(steps: [
            RecoveryStep(action: .refreshDNS, reason: "a", expectedImpact: "", recoveryBehavior: ""),
            RecoveryStep(action: .renewPrimaryNetwork, reason: "b", expectedImpact: "", recoveryBehavior: ""),
            RecoveryStep(action: .rebuildSpotlightStartupDisk, reason: "c", expectedImpact: "", recoveryBehavior: "")
        ])
        let result = await executor.execute(plan, confirm: { _ in true }, progress: { _ in })
        XCTAssertEqual(result.results.count, 2)
        XCTAssertTrue(result.stoppedAfterFailure)
        XCTAssertEqual(calls.value, 2)
    }

    func testHelperPolicyRejectsUnboundedCleanupAge() {
        let invalid = TonicHelperRequest(operation: .purgeStaleSystemData(domain: .systemCaches, minimumAgeDays: 1))
        XCTAssertEqual(TonicHelperPolicy.validated(invalid), .invalidArgument)
        let valid = TonicHelperRequest(operation: .purgeStaleSystemData(domain: .systemCaches, minimumAgeDays: 30))
        XCTAssertNil(TonicHelperPolicy.validated(valid))
    }
}

private final class LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = 0
    func increment() -> Int { lock.withLock { storage += 1; return storage } }
    var value: Int { lock.withLock { storage } }
}
