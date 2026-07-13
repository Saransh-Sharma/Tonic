import SwiftUI

struct RecoveryCenterView: View {
    @State private var coordinator = RecoveryPlanCoordinator()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: TonicDS.Space.lg) {
                introduction
                if coordinator.diagnostics.isEmpty {
                    emptyState
                } else {
                    diagnostics
                    if let plan = coordinator.plan { planReview(plan) }
                    if !coordinator.results.isEmpty { results }
                }
            }
            .padding(.bottom, TonicDS.Space.xxl)
        }
        .confirmationDialog(
            coordinator.pendingConfirmation?.action.title ?? "Confirm recovery step",
            isPresented: Binding(get: { coordinator.pendingConfirmation != nil }, set: { shown in
                if !shown && coordinator.pendingConfirmation != nil { coordinator.resolveConfirmation(false) }
            }),
            titleVisibility: .visible
        ) {
            Button("Continue with this step") { coordinator.resolveConfirmation(true) }
            Button("Skip this step", role: .cancel) { coordinator.resolveConfirmation(false) }
        } message: {
            if let step = coordinator.pendingConfirmation {
                Text("\(step.expectedImpact) \(step.recoveryBehavior)")
            }
        }
        .onDisappear { coordinator.cancelPendingConfirmation() }
    }

    private var introduction: some View {
        ModuleBand(band: .green) {
            HStack(alignment: .top, spacing: TonicDS.Space.lg) {
                Image(systemName: "wrench.and.screwdriver")
                    .font(.system(size: 38, weight: .thin))
                    .foregroundStyle(TonicDS.Colors.onDark)
                VStack(alignment: .leading, spacing: TonicDS.Space.sm) {
                    Text("Recovery Center").tonicType(.sectionDisplay).foregroundStyle(TonicDS.Colors.onDark)
                    Text("Diagnose first. Review every change. Preserve your Mac’s configuration.")
                        .tonicType(.bodyLarge).foregroundStyle(TonicDS.Colors.onDarkMuted)
                    PrimaryPill(coordinator.state == .diagnosing ? "Diagnosing…" : "Run Diagnostics",
                                systemImage: "stethoscope", onDark: true,
                                isDisabled: coordinator.state == .diagnosing || coordinator.state == .executing) {
                        coordinator.diagnose()
                    }
                }
                Spacer()
            }
        }
    }

    private var emptyState: some View {
        TonicInlineNotice(message: "Recovery actions appear only when a diagnostic provides concrete evidence.", tone: .info)
    }

    private var diagnostics: some View {
        VStack(alignment: .leading, spacing: 0) {
            MonoLabel("Diagnostic evidence")
                .padding(.bottom, TonicDS.Space.xs)
            TonicHairline()
            ForEach(coordinator.diagnostics) { diagnostic in
                HStack(alignment: .top, spacing: TonicDS.Space.md) {
                    Image(systemName: diagnostic.severity == .healthy ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(diagnostic.severity == .healthy ? TonicDS.Colors.statusSuccess : TonicDS.Colors.statusWarning)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(diagnostic.title).font(.system(size: 13, weight: .semibold))
                        Text(diagnostic.detail).tonicType(.caption).foregroundStyle(TonicDS.Colors.textMuted)
                    }
                    Spacer()
                    Text(diagnostic.evidence).tonicType(.monoLabel).foregroundStyle(TonicDS.Colors.textMuted)
                }
                .padding(.vertical, TonicDS.Space.sm)
                .accessibilityElement(children: .combine)
                TonicHairline()
            }
        }
    }

    private func planReview(_ plan: RecoveryPlan) -> some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.md) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Reviewed recovery plan").tonicType(.cardHeading)
                    Text("Steps run in order and stop at the first failure.")
                        .tonicType(.caption).foregroundStyle(TonicDS.Colors.textMuted)
                }
                Spacer()
                PrimaryPill(coordinator.state == .executing ? "Running…" : "Run Reviewed Plan",
                            systemImage: "play.fill",
                            isDisabled: coordinator.state == .executing || plan.selectedSteps.isEmpty) {
                    coordinator.runReviewedPlan()
                }
            }
            ForEach(plan.steps) { step in
                HStack(alignment: .top, spacing: TonicDS.Space.md) {
                    Toggle("", isOn: Binding(get: { step.isSelected }, set: { coordinator.setSelected(stepID: step.id, selected: $0) }))
                        .labelsHidden()
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(step.action.title).font(.system(size: 13, weight: .semibold))
                            if step.isReportOnly { StatusChip("Guidance", level: .info) }
                            if step.action.isDisruptive { StatusChip("Interrupts briefly", level: .warning) }
                        }
                        Text(step.reason).tonicType(.caption).foregroundStyle(TonicDS.Colors.textMuted)
                        Text(step.expectedImpact).tonicType(.caption)
                    }
                    Spacer()
                    Text("~\(step.action.estimatedDurationSeconds)s")
                        .tonicType(.monoLabel).foregroundStyle(TonicDS.Colors.textMuted)
                }
                .padding(TonicDS.Space.md)
                .background(TonicDS.Colors.softStone, in: RoundedRectangle(cornerRadius: TonicDS.Radius.md))
            }
        }
    }

    private var results: some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.sm) {
            MonoLabel("Plan receipts")
            ForEach(coordinator.results) { result in
                TonicInlineNotice(message: "\(result.action.title): \(result.detail)",
                                  tone: result.status == .failed ? .warning : .info)
            }
        }
    }
}
