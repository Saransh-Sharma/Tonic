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

// MARK: - Speed Test Results Display (Compact WhyFi-style)

/// Compact display component for speed test results with diagnostic insights
public struct SpeedTestResults: View {
    let results: SpeedTestData
    let onRetest: (() -> Void)?
    let baselinePing: TimeInterval?  // Ping before speed test (for bufferbloat detection)

    public init(
        results: SpeedTestData,
        onRetest: (() -> Void)? = nil,
        baselinePing: TimeInterval? = nil
    ) {
        self.results = results
        self.onRetest = onRetest
        self.baselinePing = baselinePing
    }

    public var body: some View {
        VStack(spacing: 12) {
            // Speed Test Header
            HStack {
                Text("Speed Test")
                    .font(DesignTokens.Typography.captionEmphasized)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignTokens.Colors.textSecondary)

                Text("•")
                    .foregroundColor(DesignTokens.Colors.textTertiary)

                Text("Cloudflare")
                    .font(DesignTokens.Typography.captionMedium)
                    .foregroundColor(DesignTokens.Colors.textTertiary)

                Spacer()
            }

            // Compact speed display (WhyFi-style)
            HStack(alignment: .top, spacing: 20) {
                // Download speed
                VStack(spacing: 2) {
                    Text(downloadSpeedText)
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundColor(TonicColors.success)

                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down")
                            .font(.caption2)
                        Text("Mbps")
                            .font(DesignTokens.Typography.captionSmall)
                    }
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                }

                // Upload speed
                VStack(spacing: 2) {
                    Text(uploadSpeedText)
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundColor(.blue)

                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up")
                            .font(.caption2)
                        Text("Mbps")
                            .font(DesignTokens.Typography.captionSmall)
                    }
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                }

                Spacer()

                // Retest button
                if let onRetest = onRetest {
                    Button(action: onRetest) {
                        Text("Retest")
                            .font(DesignTokens.Typography.captionMedium)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(DesignTokens.Colors.backgroundSecondary.opacity(0.8))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(DesignTokens.Colors.separator.opacity(0.5), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            // Diagnostic insight (if applicable)
            if let insight = generateDiagnosticInsight() {
                DiagnosticInsightView(insight: insight)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(DesignTokens.Colors.backgroundSecondary.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(DesignTokens.Colors.separator.opacity(0.5), lineWidth: 1)
        )
    }

    private var downloadSpeedText: String {
        if let speed = results.downloadSpeed {
            return String(format: "%.1f", speed)
        }
        return "--"
    }

    private var uploadSpeedText: String {
        if let speed = results.uploadSpeed {
            return String(format: "%.1f", speed)
        }
        return "--"
    }

    private func generateDiagnosticInsight() -> DiagnosticInsight? {
        // Bufferbloat detection
        if let baseline = baselinePing, let loadedPing = results.ping {
            let baselineMs = baseline * 1000
            let loadedMs = loadedPing * 1000
            let ratio = loadedMs / max(baselineMs, 1)

            if ratio > 5 && loadedMs > 50 {
                return DiagnosticInsight(
                    message: "Lag under load: router ping spiked from \(Int(baselineMs))ms to \(Int(loadedMs))ms (\(String(format: "%.1f", ratio))x) while maxing out your connection. This causes lag for everyone else on the network during heavy usage.",
                    highlightedValues: [
                        ("\(Int(baselineMs))ms", TonicColors.success),
                        ("\(Int(loadedMs))ms", TonicColors.warning),
                        ("(\(String(format: "%.1f", ratio))x)", TonicColors.warning)
                    ],
                    severity: ratio > 10 ? .critical : .warning
                )
            }
        }

        // Speed quality assessment
        if let download = results.downloadSpeed, download < 25 {
            return DiagnosticInsight(
                message: "Download speed is below 25 Mbps. This may cause buffering when streaming HD video. Consider checking for network congestion or upgrading your plan.",
                highlightedValues: [],
                severity: .warning
            )
        }

        // Upload/download asymmetry
        if let download = results.downloadSpeed, let upload = results.uploadSpeed {
            if download > 0 && upload > 0 && download / upload > 20 {
                return DiagnosticInsight(
                    message: "Upload is significantly slower than download. This is typical for most ISPs but may affect video calls and file uploads.",
                    highlightedValues: [],
                    severity: .info
                )
            }
        }

        return nil
    }
}

// MARK: - Diagnostic Insight Model

public struct DiagnosticInsight {
    let message: String
    let highlightedValues: [(String, Color)]
    let severity: DiagnosticSeverity

    public enum DiagnosticSeverity {
        case info
        case warning
        case critical

        var color: Color {
            switch self {
            case .info: return DesignTokens.Colors.textSecondary
            case .warning: return TonicColors.warning
            case .critical: return TonicColors.error
            }
        }

        var backgroundColor: Color {
            switch self {
            case .info: return DesignTokens.Colors.backgroundSecondary
            case .warning: return TonicColors.warning.opacity(0.15)
            case .critical: return TonicColors.error.opacity(0.15)
            }
        }
    }
}

// MARK: - Diagnostic Insight View

public struct DiagnosticInsightView: View {
    let insight: DiagnosticInsight

    public var body: some View {
        Text(attributedMessage)
            .font(DesignTokens.Typography.captionSmall)
            .foregroundColor(DesignTokens.Colors.textSecondary)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(insight.severity.backgroundColor)
            )
    }

    private var attributedMessage: AttributedString {
        var result = AttributedString(insight.message)

        // Highlight specific values with colors
        for (value, color) in insight.highlightedValues {
            if let range = result.range(of: value) {
                result[range].foregroundColor = color
                result[range].font = .system(size: 11, weight: .semibold, design: .monospaced)
            }
        }

        return result
    }
}

// MARK: - Legacy Speed Test Results (kept for compatibility)

/// Legacy display component for completed speed test results
public struct SpeedTestResultsLegacy: View {
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

// MARK: - Compact Speed Test Button (WhyFi-style)

/// Compact button for running speed tests - just icon and text
public struct CompactSpeedTestButton: View {
    let isRunning: Bool
    let progress: Double
    let action: () -> Void

    @State private var pulseScale: CGFloat = 1.0

    public init(
        isRunning: Bool,
        progress: Double = 0,
        action: @escaping () -> Void
    ) {
        self.isRunning = isRunning
        self.progress = progress
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isRunning {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.caption)
                }
                Text(isRunning ? "Testing... \(Int(progress * 100))%" : "Run Speed Test")
                    .font(DesignTokens.Typography.captionMedium)
            }
            .foregroundColor(DesignTokens.Colors.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(DesignTokens.Colors.backgroundSecondary.opacity(0.8))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(DesignTokens.Colors.separator.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isRunning)
    }
}

// MARK: - Preview

#Preview("Speed Test Components") {
    ScrollView {
        VStack(spacing: 20) {
            Text("Compact Speed Test Button (WhyFi-style)")
                .font(.caption)
                .foregroundColor(.secondary)

            CompactSpeedTestButton(
                isRunning: false,
                action: { print("Start test") }
            )

            CompactSpeedTestButton(
                isRunning: true,
                progress: 0.45,
                action: { print("Running...") }
            )

            Divider()

            Text("Speed Test Results with Diagnostic Insight")
                .font(.caption)
                .foregroundColor(.secondary)

            SpeedTestResults(
                results: SpeedTestData(
                    downloadSpeed: 63.8,
                    uploadSpeed: 62.3,
                    ping: 0.062,
                    jitter: 0.008
                ),
                onRetest: { print("Retest") },
                baselinePing: 0.002  // 2ms baseline, 62ms under load = bufferbloat
            )

            Divider()

            Text("Full Speed Test Button (Original)")
                .font(.caption)
                .foregroundColor(.secondary)

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
        }
        .padding()
    }
    .frame(width: 380, height: 600)
    .background(Color.black)
}
