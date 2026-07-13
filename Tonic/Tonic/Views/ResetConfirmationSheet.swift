//
//  ResetConfirmationSheet.swift
//  Tonic
//
//  Multi-step confirmation sheet for app reset. Rebuilt on the editorial TonicDS layer:
//  SheetChrome scaffold, carved type, mono section labels, flat surfaces. Status color
//  appears only where it reports genuine state (the destructive warning, step results);
//  the process chrome stays neutral ink.
//

import SwiftUI

// MARK: - Reset Confirmation Sheet

struct ResetConfirmationSheet: View {
    @Binding var isPresented: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var resetService = AppResetService.shared
    @State private var confirmationText = ""
    @State private var phase: ResetPhase = .confirm
    @State private var countdown = 2
    @State private var isResetting = false

    private enum ResetPhase {
        case confirm
        case inProgress
        case complete
    }

    var body: some View {
        Group {
            switch phase {
            case .confirm: confirmationContent
            case .inProgress: progressContent
            case .complete: completionContent
            }
        }
        .frame(width: 480)
        .frame(minHeight: 320)
        .tonicSheetBackground()
        .animation(reduceMotion ? nil : TonicDS.Motion.present, value: phase)
    }

    // MARK: - Confirmation Phase

    private var confirmationContent: some View {
        SheetChrome(title: "Reset Tonic?", onClose: { isPresented = false }) {
            VStack(alignment: .leading, spacing: TonicDS.Space.lg) {
                // Warning banner — a genuine critical state, so status color is warranted.
                HStack(spacing: TonicDS.Space.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(TonicDS.Colors.statusCritical)
                    Text("This action cannot be undone.")
                        .tonicType(.body)
                        .foregroundStyle(TonicDS.Colors.textPrimary)
                    Spacer()
                }
                .padding(TonicDS.Space.md)
                .background(TonicDS.Colors.statusCritical.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: TonicDS.Radius.md, style: .continuous))

                // What will be removed
                VStack(alignment: .leading, spacing: TonicDS.Space.sm) {
                    MonoLabel("Will be permanently removed")
                    VStack(spacing: 0) {
                        ResetInfoRow(icon: "gearshape.fill", text: "All preferences and settings")
                        ResetInfoRow(icon: "square.grid.2x2.fill", text: "Widget configurations")
                        ResetInfoRow(icon: "internaldrive.fill",
                                     text: "Cache files (\(AppResetService.formatBytes(resetService.cacheSize)))")
                        ResetInfoRow(icon: "folder.fill",
                                     text: "App data (\(AppResetService.formatBytes(resetService.appDataSize)))")
                    }
                    .padding(TonicDS.Space.md)
                    .background(TonicDS.Colors.softStone,
                                in: RoundedRectangle(cornerRadius: TonicDS.Radius.md, style: .continuous))
                }

                // Onboarding note
                HStack(spacing: TonicDS.Space.xs) {
                    Image(systemName: "arrow.counterclockwise.circle")
                        .font(.system(size: 13))
                        .foregroundStyle(TonicDS.Colors.textMuted)
                    Text("After reset, you'll go through the initial setup again.")
                        .tonicType(.caption)
                        .foregroundStyle(TonicDS.Colors.textMuted)
                }

                // Type-to-confirm
                VStack(alignment: .leading, spacing: TonicDS.Space.xs) {
                    MonoLabel("Type RESET to confirm")
                    TextField("", text: $confirmationText)
                        .textFieldStyle(.plain)
                        .tonicType(.body)
                        .foregroundStyle(TonicDS.Colors.textPrimary)
                        .padding(TonicDS.Space.sm)
                        .background(TonicDS.Colors.surface,
                                    in: RoundedRectangle(cornerRadius: TonicDS.Radius.sm, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: TonicDS.Radius.sm, style: .continuous)
                                .stroke(isConfirmed ? TonicDS.Colors.statusCritical : TonicDS.Colors.hairline,
                                        lineWidth: 1)
                        )
                        .animation(reduceMotion ? nil : .easeInOut(duration: TonicDS.Motion.fast), value: isConfirmed)
                }
            }
        } footer: {
            TextAction("Cancel") { isPresented = false }
            DestructiveButton(title: "Reset App", enabled: isConfirmed) { startReset() }
        }
    }

    // MARK: - Progress Phase

    private var progressContent: some View {
        VStack(spacing: TonicDS.Space.xl) {
            Spacer()

            ZStack {
                Circle()
                    .fill(TonicDS.Colors.rowHover(0.06))
                    .frame(width: 80, height: 80)
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(TonicDS.Colors.textPrimary)
            }

            VStack(spacing: TonicDS.Space.xs) {
                Text("Resetting Tonic…")
                    .tonicType(.cardHeading)
                    .foregroundStyle(TonicDS.Colors.textPrimary)
                Text("Please wait while we clean everything up.")
                    .tonicType(.caption)
                    .foregroundStyle(TonicDS.Colors.textMuted)
            }

            VStack(spacing: TonicDS.Space.xs) {
                ForEach(AppResetService.ResetStep.allCases, id: \.rawValue) { step in
                    ResetStepRow(step: step,
                                 isCompleted: resetService.completedSteps.contains(step),
                                 isCurrent: currentStep == step)
                }
            }
            .padding(TonicDS.Space.md)
            .background(TonicDS.Colors.softStone,
                        in: RoundedRectangle(cornerRadius: TonicDS.Radius.lg, style: .continuous))

            TonicProgressBar(fraction: currentProgress, color: TonicDS.Colors.ink)

            Spacer()
        }
        .padding(.horizontal, TonicDS.Space.xl)
        .padding(.vertical, TonicDS.Space.lg)
    }

    // MARK: - Completion Phase

    private var completionContent: some View {
        VStack(spacing: TonicDS.Space.xl) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48, weight: .medium))
                .foregroundStyle(TonicDS.Colors.statusSuccess)

            VStack(spacing: TonicDS.Space.xs) {
                Text("Reset complete")
                    .tonicType(.cardHeading)
                    .foregroundStyle(TonicDS.Colors.textPrimary)
                Text("Starting fresh in \(countdown)…")
                    .tonicType(.body)
                    .foregroundStyle(TonicDS.Colors.textMuted)
                    .contentTransition(.numericText())
                    .animation(reduceMotion ? nil : .easeInOut(duration: TonicDS.Motion.slow), value: countdown)
            }

            if let warnings = completionWarnings, !warnings.isEmpty {
                VStack(alignment: .leading, spacing: TonicDS.Space.xs) {
                    ForEach(warnings, id: \.self) { warning in
                        HStack(spacing: TonicDS.Space.xs) {
                            Image(systemName: "exclamationmark.circle")
                                .font(.system(size: 12))
                                .foregroundStyle(TonicDS.Colors.statusWarning)
                            Text(warning)
                                .tonicType(.caption)
                                .foregroundStyle(TonicDS.Colors.textMuted)
                        }
                    }
                }
                .padding(TonicDS.Space.sm)
                .background(TonicDS.Colors.statusWarning.opacity(0.1),
                            in: RoundedRectangle(cornerRadius: TonicDS.Radius.md, style: .continuous))
            }

            Spacer()
        }
        .padding(.horizontal, TonicDS.Space.xl)
        .padding(.vertical, TonicDS.Space.lg)
        .onAppear { startCountdown() }
    }

    // MARK: - Computed Properties

    private var isConfirmed: Bool { confirmationText == "RESET" }

    private var currentStep: AppResetService.ResetStep? {
        if case .inProgress(let step, _) = resetService.state { return step }
        return nil
    }

    private var currentProgress: Double {
        if case .inProgress(_, let progress) = resetService.state { return progress }
        if case .completed = resetService.state { return 1.0 }
        return 0.0
    }

    private var completionWarnings: [String]? {
        if case .completed(let warnings) = resetService.state { return warnings }
        return nil
    }

    // MARK: - Actions

    private func startReset() {
        withAnimation(reduceMotion ? nil : TonicDS.Motion.present) { phase = .inProgress }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { isResetting = true }
        Task {
            await resetService.performReset()
            withAnimation(reduceMotion ? nil : TonicDS.Motion.present) { phase = .complete }
        }
    }

    private func startCountdown() {
        Task { @MainActor in
            while countdown > 1 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                withAnimation(reduceMotion ? nil : TonicDS.Motion.numeric) {
                    countdown -= 1
                }
            }

            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            finishReset()
        }
    }

    private func finishReset() {
        isPresented = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NotificationCenter.default.post(name: NSNotification.Name("TonicDidCompleteReset"), object: nil)
            resetService.resetState()
        }
    }
}

// MARK: - Destructive Button

/// A destructive confirm action. Reads as critical (an honest signal of a dangerous,
/// irreversible operation) rather than the standard ink primary pill.
private struct DestructiveButton: View {
    let title: String
    let enabled: Bool
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Text(title)
                .tonicType(.button)
                .foregroundStyle(TonicDS.Colors.onDark)
                .padding(.vertical, 10)
                .padding(.horizontal, TonicDS.Space.lg)
                .background(enabled ? TonicDS.Colors.statusCritical : TonicDS.Colors.textMuted,
                            in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .tonicPointerCursor()
        .animation(reduceMotion ? nil : TonicDS.Motion.press, value: enabled)
    }
}

// MARK: - Reset Info Row

private struct ResetInfoRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: TonicDS.Space.sm) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(TonicDS.Colors.textMuted)
                .frame(width: 20)
            Text(text)
                .tonicType(.body)
                .foregroundStyle(TonicDS.Colors.textPrimary)
            Spacer()
        }
        .frame(minHeight: 32)
    }
}

// MARK: - Reset Step Row

private struct ResetStepRow: View {
    let step: AppResetService.ResetStep
    let isCompleted: Bool
    let isCurrent: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: TonicDS.Space.sm) {
            ZStack {
                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(TonicDS.Colors.statusSuccess)
                        .transition(.scale.combined(with: .opacity))
                } else if isCurrent {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 18, height: 18)
                } else {
                    Circle()
                        .stroke(TonicDS.Colors.hairline, lineWidth: 1.5)
                        .frame(width: 18, height: 18)
                }
            }
            .frame(width: 22, height: 22)
            .animation(reduceMotion ? nil : TonicDS.Motion.press, value: isCompleted)

            Image(systemName: step.icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(stepColor)
                .frame(width: 18)

            Text(step.displayName)
                .tonicType(.body)
                .foregroundStyle(stepColor)

            Spacer()
        }
        .frame(minHeight: 32)
        .opacity(isCompleted || isCurrent ? 1.0 : 0.5)
        .animation(reduceMotion ? nil : TonicDS.Motion.press, value: isCurrent)
        .animation(reduceMotion ? nil : TonicDS.Motion.press, value: isCompleted)
    }

    private var stepColor: Color {
        if isCompleted { return TonicDS.Colors.statusSuccess }
        if isCurrent { return TonicDS.Colors.textPrimary }
        return TonicDS.Colors.textMuted
    }
}
