//
//  ResetConfirmationSheet.swift
//  Tonic
//
//  Multi-step confirmation sheet for app reset with animated progress
//

import SwiftUI

// MARK: - Reset Confirmation Sheet

struct ResetConfirmationSheet: View {
    @Binding var isPresented: Bool
    @State private var resetService = AppResetService.shared
    @State private var confirmationText = ""
    @State private var phase: ResetPhase = .confirm
    @State private var countdown = 2
    @State private var countdownTimer: Timer?

    private enum ResetPhase {
        case confirm
        case inProgress
        case complete
    }

    var body: some View {
        VStack(spacing: 0) {
            switch phase {
            case .confirm:
                confirmationContent
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            case .inProgress:
                progressContent
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            case .complete:
                completionContent
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .frame(width: 480, height: phase == .confirm ? 520 : 420)
        .background(DesignTokens.Colors.background)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: phase)
    }

    // MARK: - Confirmation Phase

    private var confirmationContent: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Spacer()
                .frame(height: DesignTokens.Spacing.sm)

            // Warning icon
            ZStack {
                Circle()
                    .fill(TonicColors.error.opacity(0.15))
                    .frame(width: 72, height: 72)

                Circle()
                    .fill(TonicColors.error.opacity(0.08))
                    .frame(width: 88, height: 88)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(TonicColors.error)
            }
            .scaleIn()

            // Title
            VStack(spacing: DesignTokens.Spacing.xs) {
                Text("Reset Tonic?")
                    .font(DesignTokens.Typography.h2)
                    .foregroundColor(DesignTokens.Colors.textPrimary)

                Text("This action cannot be undone.")
                    .font(DesignTokens.Typography.subhead)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
            .fadeInSlideUp(delay: 0.05)

            // What will be removed
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text("This will permanently remove:")
                    .font(DesignTokens.Typography.captionEmphasized)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .padding(.horizontal, DesignTokens.Spacing.sm)

                VStack(spacing: DesignTokens.Spacing.xxs) {
                    ResetInfoRow(
                        icon: "gearshape.fill",
                        text: "All preferences and settings",
                        color: TonicColors.warning,
                        delay: 0.08
                    )

                    ResetInfoRow(
                        icon: "square.grid.2x2.fill",
                        text: "Widget configurations",
                        color: TonicColors.warning,
                        delay: 0.11
                    )

                    ResetInfoRow(
                        icon: "internaldrive.fill",
                        text: "Cache files (\(AppResetService.formatBytes(resetService.cacheSize)))",
                        color: TonicColors.warning,
                        delay: 0.14
                    )

                    ResetInfoRow(
                        icon: "folder.fill",
                        text: "App data (\(AppResetService.formatBytes(resetService.appDataSize)))",
                        color: TonicColors.warning,
                        delay: 0.17
                    )

                    if resetService.isHelperInstalled {
                        ResetInfoRow(
                            icon: "wrench.and.screwdriver.fill",
                            text: "Privileged helper tool",
                            color: TonicColors.warning,
                            delay: 0.20
                        )
                    }
                }
                .padding(DesignTokens.Spacing.sm)
                .background(DesignTokens.Colors.backgroundSecondary)
                .cornerRadius(DesignTokens.CornerRadius.medium)
            }
            .fadeInSlideUp(delay: 0.1)

            // Note about onboarding
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: "arrow.counterclockwise.circle")
                    .font(.system(size: 14))
                    .foregroundColor(DesignTokens.Colors.textTertiary)

                Text("After reset, you'll go through the initial setup again.")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            .fadeInSlideUp(delay: 0.15)

            // Type-to-confirm
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text("Type **RESET** to confirm:")
                    .font(DesignTokens.Typography.captionEmphasized)
                    .foregroundColor(DesignTokens.Colors.textSecondary)

                TextField("", text: $confirmationText)
                    .textFieldStyle(.plain)
                    .font(DesignTokens.Typography.subhead)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                    .padding(DesignTokens.Spacing.sm)
                    .background(DesignTokens.Colors.backgroundSecondary)
                    .cornerRadius(DesignTokens.CornerRadius.medium)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium)
                            .stroke(
                                confirmationText == "RESET" ? TonicColors.error : DesignTokens.Colors.separator,
                                lineWidth: 1
                            )
                    )
                    .animation(.easeInOut(duration: 0.2), value: confirmationText == "RESET")
            }
            .fadeInSlideUp(delay: 0.18)

            // Buttons
            HStack(spacing: DesignTokens.Spacing.md) {
                Button {
                    isPresented = false
                } label: {
                    Text("Cancel")
                        .font(DesignTokens.Typography.subhead)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignTokens.Spacing.sm)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button {
                    startReset()
                } label: {
                    Text("Reset App")
                        .font(DesignTokens.Typography.subhead)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignTokens.Spacing.sm)
                }
                .buttonStyle(.borderedProminent)
                .tint(TonicColors.error)
                .controlSize(.large)
                .disabled(confirmationText != "RESET")
                .opacity(confirmationText == "RESET" ? 1.0 : 0.5)
                .animation(.easeInOut(duration: 0.2), value: confirmationText == "RESET")
            }
            .fadeInSlideUp(delay: 0.22)

            Spacer()
                .frame(height: DesignTokens.Spacing.sm)
        }
        .padding(.horizontal, DesignTokens.Spacing.xl)
    }

    // MARK: - Progress Phase

    private var progressContent: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            Spacer()

            // Animated icon
            ZStack {
                Circle()
                    .fill(TonicColors.accent.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(TonicColors.accent)
                    .rotationEffect(.degrees(isResetting ? 360 : 0))
                    .animation(
                        .linear(duration: 1.5).repeatForever(autoreverses: false),
                        value: isResetting
                    )
            }

            VStack(spacing: DesignTokens.Spacing.xs) {
                Text("Resetting Tonic...")
                    .font(DesignTokens.Typography.h1)
                    .foregroundColor(DesignTokens.Colors.textPrimary)

                Text("Please wait while we clean everything up.")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }

            // Step checklist
            VStack(spacing: DesignTokens.Spacing.xs) {
                ForEach(AppResetService.ResetStep.allCases, id: \.rawValue) { step in
                    ResetStepRow(
                        step: step,
                        isCompleted: resetService.completedSteps.contains(step),
                        isCurrent: currentStep == step
                    )
                }
            }
            .padding(DesignTokens.Spacing.md)
            .background(DesignTokens.Colors.backgroundSecondary)
            .cornerRadius(DesignTokens.CornerRadius.large)

            // Progress bar
            VStack(spacing: DesignTokens.Spacing.xs) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(DesignTokens.Colors.backgroundSecondary)
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(TonicColors.accent)
                            .frame(width: geometry.size.width * currentProgress, height: 6)
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentProgress)
                    }
                }
                .frame(height: 6)
            }

            Spacer()
        }
        .padding(.horizontal, DesignTokens.Spacing.xl)
    }

    // MARK: - Completion Phase

    private var completionContent: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            Spacer()

            // Success icon
            ZStack {
                Circle()
                    .fill(TonicColors.success.opacity(0.15))
                    .frame(width: 88, height: 88)
                    .scaleEffect(completionScale)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: completionScale)

                Circle()
                    .fill(TonicColors.success.opacity(0.08))
                    .frame(width: 104, height: 104)
                    .scaleEffect(completionScale)
                    .animation(.spring(response: 0.6, dampingFraction: 0.5), value: completionScale)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundColor(TonicColors.success)
                    .scaleEffect(completionScale)
                    .animation(.spring(response: 0.4, dampingFraction: 0.5), value: completionScale)
            }

            VStack(spacing: DesignTokens.Spacing.xs) {
                Text("Reset Complete!")
                    .font(DesignTokens.Typography.h2)
                    .foregroundColor(DesignTokens.Colors.textPrimary)

                Text("Starting fresh in \(countdown)...")
                    .font(DesignTokens.Typography.subhead)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.3), value: countdown)
            }

            // Warnings if any
            if let warnings = completionWarnings, !warnings.isEmpty {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    ForEach(warnings, id: \.self) { warning in
                        HStack(spacing: DesignTokens.Spacing.xs) {
                            Image(systemName: "exclamationmark.circle")
                                .font(.system(size: 12))
                                .foregroundColor(TonicColors.warning)

                            Text(warning)
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(DesignTokens.Colors.textTertiary)
                        }
                    }
                }
                .padding(DesignTokens.Spacing.sm)
                .background(TonicColors.warning.opacity(0.1))
                .cornerRadius(DesignTokens.CornerRadius.medium)
            }

            Spacer()
        }
        .padding(.horizontal, DesignTokens.Spacing.xl)
        .onAppear {
            startCountdown()
        }
    }

    // MARK: - Computed Properties

    @State private var isResetting = false
    @State private var completionScale: CGFloat = 0.5

    private var currentStep: AppResetService.ResetStep? {
        if case .inProgress(let step, _) = resetService.state {
            return step
        }
        return nil
    }

    private var currentProgress: Double {
        if case .inProgress(_, let progress) = resetService.state {
            return progress
        }
        if case .completed = resetService.state {
            return 1.0
        }
        return 0.0
    }

    private var completionWarnings: [String]? {
        if case .completed(let warnings) = resetService.state {
            return warnings
        }
        return nil
    }

    // MARK: - Actions

    private func startReset() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            phase = .inProgress
        }

        // Start spinning animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isResetting = true
        }

        Task {
            await resetService.performReset()

            // Transition to completion
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                phase = .complete
                completionScale = 1.0
            }
        }
    }

    private func startCountdown() {
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            Task { @MainActor in
                if countdown > 1 {
                    withAnimation {
                        countdown -= 1
                    }
                } else {
                    timer.invalidate()
                    countdownTimer = nil
                    finishReset()
                }
            }
        }
    }

    private func finishReset() {
        isPresented = false

        // Brief delay for sheet dismissal animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Post notification to trigger onboarding
            NotificationCenter.default.post(
                name: NSNotification.Name("TonicDidCompleteReset"),
                object: nil
            )
            resetService.resetState()
        }
    }
}

// MARK: - Reset Info Row

private struct ResetInfoRow: View {
    let icon: String
    let text: String
    let color: Color
    let delay: TimeInterval

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(color)
                .frame(width: 20)

            Text(text)
                .font(DesignTokens.Typography.caption)
                .foregroundColor(DesignTokens.Colors.textPrimary)

            Spacer()
        }
        .padding(.vertical, DesignTokens.Spacing.xxs)
        .fadeInSlideUp(delay: delay)
    }
}

// MARK: - Reset Step Row

private struct ResetStepRow: View {
    let step: AppResetService.ResetStep
    let isCompleted: Bool
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            // Status indicator
            ZStack {
                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(TonicColors.success)
                        .transition(.scale.combined(with: .opacity))
                } else if isCurrent {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 18, height: 18)
                } else {
                    Circle()
                        .stroke(DesignTokens.Colors.separator, lineWidth: 1.5)
                        .frame(width: 18, height: 18)
                }
            }
            .frame(width: 22, height: 22)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isCompleted)

            // Step icon
            Image(systemName: step.icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(stepColor)
                .frame(width: 18)

            // Step text
            Text(step.displayName)
                .font(DesignTokens.Typography.caption)
                .foregroundColor(stepColor)
                .fontWeight(isCurrent ? .medium : .regular)

            Spacer()
        }
        .padding(.vertical, DesignTokens.Spacing.xxs)
        .opacity(isCompleted || isCurrent ? 1.0 : 0.5)
        .animation(.easeInOut(duration: 0.2), value: isCurrent)
        .animation(.easeInOut(duration: 0.2), value: isCompleted)
    }

    private var stepColor: Color {
        if isCompleted { return TonicColors.success }
        if isCurrent { return DesignTokens.Colors.textPrimary }
        return DesignTokens.Colors.textTertiary
    }
}
