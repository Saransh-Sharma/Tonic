import Foundation
import Observation

@MainActor
@Observable
public final class RecoveryPlanCoordinator {
    public enum State: Equatable {
        case ready
        case diagnosing
        case planReady
        case executing
        case completed
        case failed(String)
    }

    public private(set) var state: State = .ready
    public private(set) var diagnostics: [RecoveryDiagnostic] = []
    public private(set) var plan: RecoveryPlan?
    public private(set) var results: [RecoveryStepResult] = []
    public private(set) var pendingConfirmation: RecoveryStep?

    private let diagnosticsActor: RecoveryDiagnosticActor
    private let executor: RecoveryExecutionActor
    private var confirmationContinuation: CheckedContinuation<Bool, Never>?

    public init(diagnosticsActor: RecoveryDiagnosticActor = RecoveryDiagnosticActor(),
                executor: RecoveryExecutionActor = RecoveryExecutionActor()) {
        self.diagnosticsActor = diagnosticsActor
        self.executor = executor
    }

    public func diagnose() {
        guard state != .diagnosing, state != .executing else { return }
        state = .diagnosing
        Task { [weak self] in
            guard let self else { return }
            let diagnostics = await diagnosticsActor.diagnose()
            self.diagnostics = diagnostics
            self.plan = RecoveryPlanBuilder.makePlan(diagnostics: diagnostics)
            self.results = []
            self.state = .planReady
        }
    }

    public func setSelected(stepID: UUID, selected: Bool) {
        guard var plan, let index = plan.steps.firstIndex(where: { $0.id == stepID }) else { return }
        plan.steps[index].isSelected = selected
        self.plan = plan
    }

    public func runReviewedPlan() {
        guard let plan, !plan.selectedSteps.isEmpty, state != .executing else { return }
        state = .executing
        results = []
        Task { [weak self] in
            guard let self else { return }
            let execution = await executor.execute(plan, confirm: { [weak self] step in
                guard let self else { return false }
                return await self.requestConfirmation(for: step)
            }, progress: { [weak self] result in
                guard let self else { return }
                self.results.append(result)
                self.recordReceipt(result)
            }, revalidate: { [diagnosticsActor] in
                _ = await diagnosticsActor.diagnose()
            })
            self.recordAggregateReceipt(execution)
            self.state = execution.failedCount == 0 ? .completed : .failed("Recovery stopped after a failed step.")
            self.diagnostics = await diagnosticsActor.diagnose()
        }
    }

    public func resolveConfirmation(_ approved: Bool) {
        pendingConfirmation = nil
        let continuation = confirmationContinuation
        confirmationContinuation = nil
        continuation?.resume(returning: approved)
    }

    public func cancelPendingConfirmation() { resolveConfirmation(false) }

    private func requestConfirmation(for step: RecoveryStep) async -> Bool {
        pendingConfirmation = step
        return await withCheckedContinuation { continuation in
            confirmationContinuation = continuation
        }
    }

    private func recordReceipt(_ result: RecoveryStepResult) {
        let receiptStatus: ActionReceiptStatus = switch result.status {
        case .succeeded, .reportOnly: .success
        case .failed: .failed
        case .skipped: .partial
        }
        ActionReceiptStore.shared.record(ActionReceipt(
            tool: .smartCare,
            title: result.action.title,
            detail: result.detail,
            status: receiptStatus,
            startedAt: result.startedAt,
            completedAt: result.completedAt,
            affectedItems: result.affectedItems,
            metadata: ["recoveryStatus": result.status.rawValue]
        ))
    }

    private func recordAggregateReceipt(_ execution: RecoveryExecutionResult) {
        ActionReceiptStore.shared.record(ActionReceipt(
            tool: .smartCare,
            title: execution.failedCount == 0 ? "Recovery plan completed" : "Recovery plan stopped",
            detail: "\(execution.succeededCount) completed · \(execution.failedCount) failed · \(execution.results.count - execution.succeededCount - execution.failedCount) skipped or guided",
            status: execution.failedCount == 0 ? .success : .partial,
            affectedItems: execution.results.reduce(0) { $0 + $1.affectedItems },
            metadata: ["planID": execution.planID.uuidString,
                       "stoppedAfterFailure": String(execution.stoppedAfterFailure)]
        ))
    }
}
