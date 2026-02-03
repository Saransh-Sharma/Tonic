//
//  NetworkAnimations.swift
//  Tonic
//
//  Animation modifiers and effects for network widget
//  Task ID: fn-2.8.13
//

import SwiftUI

// MARK: - Animated Metric Value

/// View modifier that animates numeric value changes
public struct AnimatedMetricValue: ViewModifier {
    @State private var displayedValue: Double
    let targetValue: Double
    let format: String

    init(value: Double, format: String = "%.1f") {
        self._displayedValue = State(initialValue: value)
        self.targetValue = value
        self.format = format
    }

    public func body(content: Content) -> some View {
        Text(String(format: format, displayedValue))
            .contentTransition(.numericText())
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    displayedValue = targetValue
                }
            }
            .onChange(of: targetValue) { _, newValue in
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    displayedValue = newValue
                }
            }
    }
}

extension View {
    /// Apply animated value display to a Text view
    public func animatedMetric(_ value: Double, format: String = "%.1f") -> some View {
        self.modifier(AnimatedMetricValue(value: value, format: format))
    }
}

// MARK: - Pulse Animation

/// Pulsing animation for status indicators
public struct PulseView: View {
    let isActive: Bool
    let color: Color
    let size: CGFloat

    @State private var scale: CGFloat = 1
    @State private var opacity: Double = 1

    public init(isActive: Bool = true, color: Color = .blue, size: CGFloat = 12) {
        self.isActive = isActive
        self.color = color
        self.size = size
    }

    public var body: some View {
        ZStack {
            // Pulsing rings
            if isActive {
                ForEach(0..<2) { i in
                    Circle()
                        .stroke(color.opacity(0.5), lineWidth: 2)
                        .frame(width: size, height: size)
                        .scaleEffect(scale + CGFloat(i) * 0.3)
                        .opacity(opacity)
                }
            }

            // Core dot
            Circle()
                .fill(color)
                .frame(width: size * 0.6, height: size * 0.6)
        }
        .onAppear {
            if isActive {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                    scale = 1.5
                    opacity = 0
                }
            }
        }
    }
}

// MARK: - Shimmer Effect

/// Shimmer effect for loading states
public struct ShimmerView: View {
    @State private var phase: CGFloat = 0

    let width: CGFloat
    let height: CGFloat

    public init(width: CGFloat = 100, height: CGFloat = 12) {
        self.width = width
        self.height = height
    }

    public var body: some View {
        GeometryReader { geometry in
            LinearGradient(
                colors: [
                    Color.gray.opacity(0.1),
                    Color.gray.opacity(0.3),
                    Color.gray.opacity(0.1)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: width, height: height)
            .cornerRadius(4)
            .offset(x: -geometry.size.width + (phase * geometry.size.width * 2))
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
        }
        .frame(width: width, height: height)
    }
}

// MARK: - Bounce Animation

/// Bounce animation for new data indicators
public struct BounceView: View {
    let trigger: Bool

    @State private var isBouncing = false

    public init(trigger: Bool = false) {
        self.trigger = trigger
    }

    public var body: some View {
        EmptyView()
            .onChange(of: trigger) { _, _ in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    isBouncing = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation {
                        isBouncing = false
                    }
                }
            }
    }
}

extension View {
    /// Apply bounce animation when trigger changes
    public func bounce(when trigger: Bool) -> some View {
        self.scaleEffect(isBouncing(when: trigger) ? 1.1 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: trigger)
    }

    private func isBouncing(when trigger: Bool) -> Bool {
        trigger
    }
}

// MARK: - Slide In Animation

/// Slide-in animation for list items
public struct SlideInView<Content: View>: View {
    let delay: Double
    let direction: Edge
    @ViewBuilder let content: () -> Content

    @State private var isVisible = false

    public init(delay: Double = 0, direction: Edge = .leading, @ViewBuilder content: @escaping () -> Content) {
        self.delay = delay
        self.direction = direction
        self.content = content
    }

    public var body: some View {
        content()
            .offset(offsetForDirection)
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(delay)) {
                    isVisible = true
                }
            }
    }

    private var offsetForDirection: CGSize {
        if !isVisible {
            switch direction {
            case .leading:
                return CGSize(width: -20, height: 0)
            case .trailing:
                return CGSize(width: 20, height: 0)
            case .top:
                return CGSize(width: 0, height: -20)
            case .bottom:
                return CGSize(width: 0, height: 20)
            }
        }
        return .zero
    }
}

// MARK: - Animated Connection Status

/// Animated view showing connection status with smooth transitions
public struct AnimatedConnectionStatus: View {
    let isConnected: Bool

    @State private var pulseScale: CGFloat = 1
    @State private var glowOpacity: Double = 0

    public init(isConnected: Bool) {
        self.isConnected = isConnected
    }

    public var body: some View {
        ZStack {
            // Glow effect
            Circle()
                .fill(statusColor.opacity(0.3))
                .frame(width: 32, height: 32)
                .scaleEffect(pulseScale)
                .opacity(glowOpacity)

            // Core circle
            Circle()
                .fill(statusColor)
                .frame(width: 16, height: 16)
        }
        .onAppear {
            if isConnected {
                startPulse()
            }
        }
        .onChange(of: isConnected) { _, newValue in
            if newValue {
                startPulse()
            } else {
                stopPulse()
            }
        }
    }

    private var statusColor: Color {
        isConnected ? TonicColors.success : TonicColors.error
    }

    private func startPulse() {
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            pulseScale = 1.5
            glowOpacity = 1
        }
    }

    private func stopPulse() {
        withAnimation {
            pulseScale = 1
            glowOpacity = 0
        }
    }
}

// MARK: - Value Change Indicator

/// Small indicator showing whether a value increased or decreased
public struct ValueChangeIndicator: View {
    enum ChangeType {
        case up, down, neutral
    }

    let change: ChangeType
    let color: Color

    public init(up: Bool?, color: Color = .secondary) {
        if let up = up {
            self.change = up ? .up : .down
        } else {
            self.change = .neutral
        }
        self.color = color
    }

    public var body: some View {
        Image(systemName: iconName)
            .font(.caption2)
            .foregroundColor(color)
            .padding(2)
            .background(
                Circle()
                    .fill(color.opacity(0.15))
            )
    }

    private var iconName: String {
        switch change {
        case .up: return "arrow.up.right"
        case .down: return "arrow.down.right"
        case .neutral: return "minus"
        }
    }
}

// MARK: - Progress Ring

/// Circular progress ring for speed test phases
public struct ProgressRing: View {
    let progress: Double
    let color: Color
    let lineWidth: CGFloat

    @State private var animateProgress = false

    public init(progress: Double, color: Color = .blue, lineWidth: CGFloat = 3) {
        self.progress = progress
        self.color = color
        self.lineWidth = lineWidth
    }

    public var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(
                    color.opacity(0.2),
                    style: StrokeStyle(lineWidth: lineWidth)
                )

            // Progress arc
            Circle()
                .trim(from: 0, to: animateProgress ? progress : 0)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.5), value: animateProgress)
        }
        .onAppear {
            animateProgress = true
        }
        .onChange(of: progress) { _, _ in
            animateProgress = true
        }
    }
}

// MARK: - Preview

#Preview("Network Animations") {
    VStack(spacing: 24) {
        HStack(spacing: 20) {
            PulseView(isActive: true, color: .green)
            PulseView(isActive: true, color: .yellow)
            PulseView(isActive: false, color: .red)
        }

        VStack(alignment: .leading, spacing: 8) {
            Text("Shimmer Loading")
                .font(.caption)
            ShimmerView(width: 200, height: 16)
            ShimmerView(width: 150, height: 12)
        }

        HStack(spacing: 16) {
            ProgressRing(progress: 0.25, color: .blue)
            ProgressRing(progress: 0.5, color: .green)
            ProgressRing(progress: 0.75, color: .orange)
            ProgressRing(progress: 1.0, color: .red)
        }

        HStack(spacing: 16) {
            AnimatedConnectionStatus(isConnected: true)
            AnimatedConnectionStatus(isConnected: false)
        }

        HStack(spacing: 16) {
            ValueChangeIndicator(up: true, color: .green)
            ValueChangeIndicator(up: false, color: .red)
            ValueChangeIndicator(up: nil, color: .gray)
        }
    }
    .padding()
    .frame(width: 300)
    .background(Color.black)
}
