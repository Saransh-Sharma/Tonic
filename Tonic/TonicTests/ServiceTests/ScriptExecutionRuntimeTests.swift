#if !TONIC_STORE

import XCTest
@testable import Tonic

private actor StubScriptLauncher: ScriptProcessLaunching {
    var result: ScriptProcessResult
    var delay: Duration
    init(result: ScriptProcessResult, delay: Duration = .zero) { self.result = result; self.delay = delay }
    func run(_ request: ScriptProcessRequest) async -> ScriptProcessResult {
        try? await Task.sleep(for: delay)
        return result
    }
}

final class ScriptExecutionRuntimeTests: XCTestCase {
    private func definition(id: UUID = UUID(), failures: Int = 0) -> CustomMenuBarScript {
        CustomMenuBarScript(id: id, source: .inline("printf 'ok\\nsecond'"), executable: "/bin/zsh",
                            arguments: ["-c"], environmentAllowlist: ["TONIC_MODE": "reviewed"],
                            timeoutSeconds: 5, mapsFirstOutputLineToLabel: true, failureCount: failures)
    }

    func testPolicyRequiresReviewForUnattendedAndRejectsRelativeExecutable() {
        let policy = CustomItemScriptPolicy()
        XCTAssertEqual(policy.validate(definition(), unattended: true, reviewApproved: false), .reviewRequired)
        var invalid = definition(); invalid.executable = "zsh"
        XCTAssertEqual(policy.validate(invalid, unattended: false, reviewApproved: false), .invalidExecutable)
        XCTAssertEqual(policy.environment(for: definition())["PATH"], CustomItemScriptPolicy.minimalPATH)
    }

    func testSuccessfulExecutionMapsOneSanitizedLine() async {
        let launcher = StubScriptLauncher(result: .init(exitStatus: 0, stdout: Data("hello\nignored".utf8),
                                                         stderr: Data(), timedOut: false, errorDescription: nil))
        let actor = ScriptExecutionActor(launcher: launcher)
        let receipt = await actor.execute(definition())
        XCTAssertTrue(receipt.succeeded)
        XCTAssertEqual(receipt.mappedLabel, "hello")
    }

    func testThreeFailuresPauseUntilReviewedResume() async {
        let id = UUID()
        let launcher = StubScriptLauncher(result: .init(exitStatus: 1, stdout: Data(), stderr: Data("bad".utf8),
                                                         timedOut: false, errorDescription: nil))
        let actor = ScriptExecutionActor(launcher: launcher)
        for _ in 0..<3 { _ = await actor.execute(definition(id: id)) }
        let isPaused = await actor.isPaused(scriptID: id)
        XCTAssertTrue(isPaused)
        let paused = await actor.execute(definition(id: id))
        XCTAssertEqual(paused.error, .pausedAfterFailures)
        await actor.resumeAfterReview(scriptID: id)
        let isResumed = await actor.isPaused(scriptID: id)
        XCTAssertFalse(isResumed)
    }

    func testOverlappingExecutionIsRejected() async {
        let id = UUID()
        let launcher = StubScriptLauncher(result: .init(exitStatus: 0, stdout: Data(), stderr: Data(),
                                                         timedOut: false, errorDescription: nil),
                                          delay: .milliseconds(150))
        let actor = ScriptExecutionActor(launcher: launcher)
        let script = definition(id: id)
        async let first = actor.execute(script)
        try? await Task.sleep(for: .milliseconds(20))
        let second = await actor.execute(script)
        XCTAssertEqual(second.error, .alreadyRunning)
        _ = await first
    }

    func testTimeoutProducesFailureReceipt() async {
        let launcher = StubScriptLauncher(result: .init(exitStatus: 15, stdout: Data(), stderr: Data(),
                                                         timedOut: true, errorDescription: nil))
        let receipt = await ScriptExecutionActor(launcher: launcher).execute(definition())
        XCTAssertEqual(receipt.error, .timedOut)
        XCTAssertFalse(receipt.succeeded)
    }

    @MainActor
    func testReviewedFingerprintInvalidatesWhenCommandChanges() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let file = directory.appendingPathComponent("scripts.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CustomItemScriptStore(fileURL: file)
        var script = definition()
        store.save(script)
        store.approveReviewedExecution(id: script.id)
        XCTAssertTrue(store.isReviewed(id: script.id))
        script.failureCount = 1
        store.save(script)
        XCTAssertTrue(store.isReviewed(id: script.id), "runtime failure state must not invalidate the reviewed command")
        store.setSchedule(scriptID: script.id, interval: 300)
        store.setMappedLabel("safe label", scriptID: script.id)
        let reloaded = CustomItemScriptStore(fileURL: file)
        XCTAssertEqual(reloaded.scheduleIntervals[script.id], 300)
        XCTAssertEqual(reloaded.mappedLabels[script.id], "safe label")
        script.arguments.append("--changed")
        store.save(script)
        XCTAssertFalse(store.isReviewed(id: script.id))
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
    }
}

#endif
