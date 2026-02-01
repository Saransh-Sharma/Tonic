//
//  CircularGaugeView.swift
//  Tonic
//
//  Full circular gauge for multi-segment data visualization
//  Displays System/User/Idle split like Stats Master CPU dashboard
//  Task ID: fn-6-i4g.30
//

import SwiftUI

// MARK: - Circular Gauge View

/// Full circular gauge for displaying usage breakdown with colored segments
/// Ideal for: CPU (System/User/Idle), Memory breakdown, disk usage
///
/// Example:
/// ```swift
/// CircularGaugeView(
///     segments: [
///         (45, Color.red),      // System
///         (32, Color.blue),     // User
///         (23, Color.gray)      // Idle
///     ],
///     centerText: "68%",
///     centerSubtitle: "Total",
///     size: 70
/// )
/// ```
public struct CircularGaugeView: View {
    // MARK: - Properties

    private let segments: [(value: Double, color: Color)]
    private let centerText: String
    private let centerSubtitle: String?
    private let size: CGFloat
    private let lineWidth: CGFloat

    // MARK: - Computed Properties

    private var totalValue: Double {
        let total = segments.reduce(0) { $0 + $1.value }
        return max(total, 0.001) // Avoid division by zero
    }

    // MARK: - Initializer

    /// Initialize a circular gauge
    /// - Parameters:
    ///   - segments: Array of value-color pairs representing data segments
    ///   - centerText: Text to display in center (e.g., "68%")
    ///   - centerSubtitle: Optional smaller text below center text
    ///   - size: Width/height of the gauge (default: 70)
    ///   - lineWidth: Stroke width of the gauge ring (default: 12)
    public init(
        segments: [(value: Double, color: Color)],
        centerText: String,
        centerSubtitle: String? = nil,
        size: CGFloat = 70,
        lineWidth: CGFloat = 12
    ) {
        self.segments = segments
        self.centerText = centerText
        self.centerSubtitle = centerSubtitle
        self.size = size
        self.lineWidth = lineWidth
    }

    /// Convenience initializer with GaugeSegment array
    public init(
        segments: [GaugeSegment],
        centerText: String,
        centerSubtitle: String? = nil,
        size: CGFloat = 70,
        lineWidth: CGFloat = 12
    ) {
        self.segments = segments.map { ($0.value, $0.color) }
        self.centerText = centerText
        self.centerSubtitle = centerSubtitle
        self.size = size
        self.lineWidth = lineWidth
    }

    // MARK: - Body

    public var body: some View {
        ZStack {
            // Background circle
            backgroundCircle

            // Draw segments
            segmentArcs

            // Center text
            centerTextView
        }
        .frame(width: size, height: size)
    }

    // MARK: - View Components

    private var backgroundCircle: some View {
        Circle()
            .stroke(Color(nsColor: .separatorColor).opacity(0.2), lineWidth: lineWidth)
            .frame(width: size, height: size)
    }

    private var segmentArcs: some View {
        // Calculate cumulative start angles for each segment
        var cumulativeAngle: Double = 0
        let angles: [(start: Double, end: Double, value: Double, color: Color)] = segments.map { segment in
            let startAngle = cumulativeAngle
            let segmentAngle = (segment.value / totalValue) * 360
            cumulativeAngle += segmentAngle
            return (startAngle, cumulativeAngle, segment.value, segment.color)
        }

        return Group {
            ForEach(Array(angles.enumerated()), id: \.offset) { _, angles in
                segmentArc(
                    startAngle: angles.start,
                    endAngle: angles.end,
                    color: angles.color,
                    value: angles.value
                )
            }
        }
    }

    private func segmentArc(startAngle: Double, endAngle: Double, color: Color, value: Double) -> some View {
        let startFraction = startAngle / 360
        let endFraction = endAngle / 360

        return Circle()
            .trim(from: startFraction, to: endFraction)
            .stroke(
                color,
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt)
            )
            .frame(width: size, height: size)
            .rotationEffect(.degrees(-90))
            .animation(.easeInOut(duration: 0.3), value: value)
    }

    private var centerTextView: some View {
        VStack(spacing: 2) {
            Text(centerText)
                .font(.system(size: size * 0.2, weight: .semibold))
                .foregroundColor(DesignTokens.Colors.textPrimary)

            if let subtitle = centerSubtitle {
                Text(subtitle)
                    .font(.system(size: size * 0.13, weight: .regular))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
        }
    }
}

// MARK: - CPU Circular Gauge (Convenience)

/// Pre-configured circular gauge for CPU usage display
public struct CPUCircularGaugeView: View {
    private let systemUsage: Double
    private let userUsage: Double
    private let idleUsage: Double
    private let size: CGFloat

    public init(
        systemUsage: Double,
        userUsage: Double,
        idleUsage: Double = 0,
        size: CGFloat = 70
    ) {
        self.systemUsage = systemUsage
        self.userUsage = userUsage
        self.idleUsage = idleUsage
        self.size = size
    }

    public var body: some View {
        let totalUsage = systemUsage + userUsage

        CircularGaugeView(
            segments: [
                (systemUsage, Color(red: 1.0, green: 0.3, blue: 0.2)),  // System - red
                (userUsage, Color(red: 0.2, green: 0.5, blue: 1.0)),    // User - blue
                (idleUsage, Color.gray.opacity(0.3))                     // Idle - gray
            ],
            centerText: "\(Int(totalUsage))%",
            centerSubtitle: "Usage",
            size: size
        )
    }
}

// MARK: - Memory Circular Gauge (Convenience)

/// Pre-configured circular gauge for memory usage display
public struct MemoryCircularGaugeView: View {
    private let appUsage: Double
    private let wiredUsage: Double
    private let compressedUsage: Double
    private let freeUsage: Double
    private let size: CGFloat

    public init(
        appUsage: Double,
        wiredUsage: Double,
        compressedUsage: Double = 0,
        freeUsage: Double = 0,
        size: CGFloat = 70
    ) {
        self.appUsage = appUsage
        self.wiredUsage = wiredUsage
        self.compressedUsage = compressedUsage
        self.freeUsage = freeUsage
        self.size = size
    }

    public var body: some View {
        let totalUsed = appUsage + wiredUsage + compressedUsage
        let total = totalUsed + freeUsage
        let percentage = total > 0 ? Int((totalUsed / total) * 100) : 0

        CircularGaugeView(
            segments: [
                (appUsage, Color(red: 0.2, green: 0.6, blue: 1.0)),      // App - blue
                (wiredUsage, Color(red: 0.3, green: 0.7, blue: 0.4)),    // Wired - green
                (compressedUsage, Color(red: 1.0, green: 0.6, blue: 0.0)), // Compressed - orange
                (freeUsage, Color.gray.opacity(0.3))                      // Free - gray
            ],
            centerText: "\(percentage)%",
            centerSubtitle: "Used",
            size: size
        )
    }
}

// MARK: - Preview

#Preview("Circular Gauge") {
    VStack(spacing: 32) {
        // Basic usage
        HStack(spacing: 24) {
            CircularGaugeView(
                segments: [
                    (45, Color(red: 1.0, green: 0.3, blue: 0.2)),
                    (32, Color(red: 0.2, green: 0.5, blue: 1.0)),
                    (23, Color.gray.opacity(0.3))
                ],
                centerText: "68%",
                centerSubtitle: "Total"
            )

            CircularGaugeView(
                segments: [
                    (25, Color(red: 1.0, green: 0.3, blue: 0.2)),
                    (55, Color(red: 0.2, green: 0.5, blue: 1.0)),
                    (20, Color.gray.opacity(0.3))
                ],
                centerText: "80%",
                centerSubtitle: "Usage"
            )

            CircularGaugeView(
                segments: [
                    (10, Color(red: 1.0, green: 0.3, blue: 0.2)),
                    (15, Color(red: 0.2, green: 0.5, blue: 1.0)),
                    (75, Color.gray.opacity(0.3))
                ],
                centerText: "25%",
                centerSubtitle: "Load"
            )
        }

        // Different sizes
        HStack(spacing: 24) {
            CircularGaugeView(
                segments: [(50, .blue), (30, .green), (20, .gray)],
                centerText: "50%",
                size: 50
            )

            CircularGaugeView(
                segments: [(50, .blue), (30, .green), (20, .gray)],
                centerText: "50%",
                size: 70
            )

            CircularGaugeView(
                segments: [(50, .blue), (30, .green), (20, .gray)],
                centerText: "50%",
                size: 90
            )
        }

        // CPU gauges
        HStack(spacing: 24) {
            CPUCircularGaugeView(
                systemUsage: 15,
                userUsage: 45,
                idleUsage: 40,
                size: 70
            )

            CPUCircularGaugeView(
                systemUsage: 25,
                userUsage: 60,
                idleUsage: 15,
                size: 70
            )
        }

        // Memory gauges
        HStack(spacing: 24) {
            MemoryCircularGaugeView(
                appUsage: 8,
                wiredUsage: 2,
                compressedUsage: 1,
                freeUsage: 5,
                size: 70
            )
        }

        // Dark mode preview
        HStack(spacing: 24) {
            CircularGaugeView(
                segments: [
                    (35, Color(red: 1.0, green: 0.3, blue: 0.2)),
                    (50, Color(red: 0.2, green: 0.5, blue: 1.0)),
                    (15, Color.gray.opacity(0.3))
                ],
                centerText: "85%",
                centerSubtitle: "CPU"
            )
            .background(Color.black.opacity(0.8))
            .cornerRadius(12)
        }
    }
    .padding()
}
