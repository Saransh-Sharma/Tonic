#if !TONIC_STORE

import SwiftUI

struct PrivilegedOperationReview: Identifiable {
    let id = UUID()
    let title: String
    let operation: TonicPrivilegedOperation
    let scope: String
    let impact: String
    let warning: String
}

struct PrivilegedOperationReviewSheet: View {
    let review: PrivilegedOperationReview
    let onComplete: (TonicHelperResult?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var isRunning = false
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label(review.title, systemImage: "lock.shield").font(.title2.bold())
            Text("Tonic will ask its signed privileged helper to perform this fixed operation.")
                .foregroundStyle(.secondary)
            reviewRow("Scope", review.scope)
            reviewRow("Expected impact", review.impact)
            reviewRow("Safety", review.warning)
            if let message { Text(message).font(.callout).foregroundStyle(.orange) }
            HStack {
                Button("Cancel") { dismiss() }.buttonStyle(.bordered).disabled(isRunning)
                Spacer()
                PrimaryPill(isRunning ? "Working…" : "Confirm and Run", isDisabled: isRunning) { run() }
            }
        }
        .padding(28).frame(width: 560)
    }

    private func reviewRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased()).font(.caption.bold()).foregroundStyle(.secondary)
            Text(value).textSelection(.enabled)
        }
    }

    private func run() {
        isRunning = true
        Task { @MainActor in
            let helper = TonicHelperClient.shared
            helper.refreshStatus()
            guard helper.status == .enabled else {
                do {
                    try helper.register()
                    message = "Approve Tonic’s helper in Login Items, then run this reviewed operation again."
                } catch { message = error.localizedDescription }
                isRunning = false; onComplete(nil); return
            }
            let result: TonicHelperResult
            switch review.operation {
            case .setFanMode(let fanID, let automatic, _):
                result = await helper.setFanMode(fanID: fanID, automatic: automatic)
            case .setFanTargetRPM(let fanID, let rpm, _):
                result = await helper.setFanTargetRPM(fanID: fanID, rpm: rpm)
            case .restoreAutomaticFanControl:
                result = await helper.restoreAutomaticFanControl()
            default:
                result = await helper.perform(review.operation)
            }
            isRunning = false; onComplete(result); dismiss()
        }
    }
}

#endif
