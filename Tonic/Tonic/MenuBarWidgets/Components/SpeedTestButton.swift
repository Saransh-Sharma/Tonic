//
//  SpeedTestButton.swift
//  Tonic
//
//  Button component for running network speed tests
//  Task ID: fn-2.8.11
//

import SwiftUI

// MARK: - Speed Test Button

/// Animated button for running network speed tests
public struct SpeedTestButton: View {

    // MARK: - Properties

    let isRunning: Bool
    let progress: Double
    let phase: SpeedTestPhase
    let action: () -> Void

    @State private var isPressed = false
    @State private var pulseRadius: CGFloat = 0

    // MARK: - Initialization

    public init(
        isRunning: Bool,
        progress: Double = 0,
        phase: SpeedTestPhase = .idle,
        action: @escaping () -> Void
    ) {
        self.isRunning = isRunning
        self.progress = progress
        self.phase = phase
        self.action = action
    }

    // MARK: - Body

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Left icon / progress indicator
                ZStack {
                    if isRunning {
                        // Circular progress
                        Circle()
                            .stroke(
                                DesignTokens.Colors.textTertiary.opacity(0.2),
                                lineWidth: 2
                            )

                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(
                                phaseColor,
                                style: StrokeStyle(lineWidth: 2, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 0.3), value: progress)
                    } else {
                        Image(systemName: "gauge.with.dots.needle.67percent")
                            .font(.title3)
                            .foregroundColor(phaseColor)
                    }

                    // Pulsing effect when running
                    if isRunning {
                        Circle()
                            .stroke(phaseColor.opacity(0.3), lineWidth: 1)
                            .scaleEffect(pulseRadius)
                            .opacity(2 - pulseRadius)
                            .onAppear {
                                withAnimation(.easeOut(duration: 1).repeatForever(autoreverses: false)) {
                                    pulseRadius = 2
                                }
                            }
                    }
                }
                .frame(width: 32, height: 32)

                // Text content
                VStack(alignment: .leading, spacing: 2) {
                    Text(isRunning ? phase.displayName : "Speed Test")
                        .font(DesignTokens.Typography.headlineSmall)
                        .fontWeight(.semibold)
                        .foregroundColor(isRunning ? DesignTokens.Colors.text : DesignTokens.Colors.textSecondary)

                    if isRunning {
                        Text("\(Int(progress * 100))%")
                            .font(DesignTokens.Typography.captionMedium)
                            .foregroundColor(DesignTokens.Colors.textTertiary)
                    } else {
                        Text("Test your connection speed")
                            .font(DesignTokens.Typography.captionMedium)
                            .foregroundColor(DesignTokens.Colors.textTertiary)
                    }
                }

                Spacer()

                // Right icon
                Image(systemName: isRunning ? "stop.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(isRunning ? TonicColors.error : phaseColor)
            }
            .padding(16)
            .background(buttonBackground)
            .overlay(buttonBorder)
        }
        .buttonStyle(.plain)
        .disabled(isRunning && phase == .complete)
    }

    // MARK: - Computed Properties

    private var phaseColor: Color {
        switch phase {
        case .idle:
            return DesignTokens.Colors.accent
        case .ping:
            return .purple
        case .download:
            return TonicColors.success
        case .upload:
            return .blue
        case .complete:
            return TonicColors.success
        }
    }

    private var buttonBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(isRunning ? phaseColor.opacity(0.1) : DesignTokens.Colors.backgroundSecondary.opacity(0.6))
    }

    private var buttonBorder: some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(
                isRunning ? phaseColor.opacity(0.3) : DesignTokens.Colors.border.opacity(0.5),
                lineWidth: 1
            )
    }
}

// MARK: - Speed Test Results Display

/// Display component for completed speed test results
public struct SpeedTestResults: View {
    let results: SpeedTestData

    public init(results: SpeedTestData) {
        self.results = results
    }

    public var body: some View {
        VStack(spacing: 16) {
            // Download result
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(TonicColors.success)
                        Text("Download")
                            .font(DesignTokens.Typography.captionMedium)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    }

                    if let speed = results.downloadSpeed {
                        Text(String(format: "%.1f Mbps", speed))
                            .font(DesignTokens.Typography.displaySmall)
                            .foregroundColor(TonicColors.success)
                    } else {
                        Text("--")
                            .font(DesignTokens.Typography.displaySmall)
                            .foregroundColor(DesignTokens.Colors.textTertiary)
                    }
                }

                Spacer()

                // Upload result
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("Upload")
                            .font(DesignTokens.Typography.captionMedium)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundColor(.blue)
                    }

                    if let speed = results.uploadSpeed {
                        Text(String(format: "%.1f Mbps", speed))
                            .font(DesignTokens.Typography.displaySmall)
                            .foregroundColor(.blue)
                    } else {
                        Text("--")
                            .font(DesignTokens.Typography.displaySmall)
                            .foregroundColor(DesignTokens.Colors.textTertiary)
                    }
                }
            }

            // Latency info
            if let ping = results.ping, let jitter = results.jitter {
                HStack(spacing: 20) {
                    HStack(spacing: 6) {
                        Image(systemName: "waveform.path")
                            .font(.caption)
                            .foregroundColor(DesignTokens.Colors.textTertiary)
                        Text("Ping: \(Int(ping * 1000))ms")
                            .font(DesignTokens.Typography.captionMedium)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "chart.line.flattrend")
                            .font(.caption)
                            .foregroundColor(DesignTokens.Colors.textTertiary)
                        Text("Jitter: \(Int(jitter * 1000))ms")
                            .font(DesignTokens.Typography.captionMedium)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    }

                    Spacer()
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(DesignTokens.Colors.backgroundSecondary.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(TonicColors.success.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Speed Test Gauge

/// Visual gauge showing speed test progress
public struct SpeedTestGauge: View {
    let progress: Double
    let phase: SpeedTestPhase
    let color: Color

    public init(progress: Double, phase: SpeedTestPhase, color: Color) {
        self.progress = progress
        self.phase = phase
        self.color = color
    }

    public var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(
                    DesignTokens.Colors.textTertiary.opacity(0.2),
                    lineWidth: 4
                )

            // Progress arc
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.3), value: progress)

            // Center icon
            Image(systemName: phase.icon)
                .font(.title3)
                .foregroundColor(color)
        }
        .frame(width: 44, height: 44)
    }
}

// MARK: - Preview

#Preview("Speed Test Components") {
    VStack(spacing: 20) {
        SpeedTestButton(
            isRunning: false,
            phase: .idle
        ) {
            print("Start test")
        }

        SpeedTestButton(
            isRunning: true,
            progress: 0.6,
            phase: .download
        ) {
            print("Cancel test")
        }

        SpeedTestResults(
            results: SpeedTestData(
                downloadSpeed: 245.8,
                uploadSpeed: 45.2,
                ping: 0.012,
                jitter: 0.003
            )
        )

        SpeedTestGauge(
            progress: 0.75,
            phase: .upload,
            color: .blue
        )
    }
    .padding()
    .frame(width: 360)
    .background(Color.black)
}
