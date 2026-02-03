//
//  MemoryPressureGaugeView.swift
//  Tonic
//
//  Memory pressure gauge with 3-color arc for Stats Master parity
//  Green: 0-50%, Yellow: 50-80%, Red: 80-100%
//  Task ID: fn-8-v3b.3
//

import SwiftUI

// MARK: - Memory Pressure Gauge View

/// Circular gauge for memory pressure visualization with 3-color arc
/// Matches Stats Master design with color-coded zones:
/// - Green: 0-50% (normal)
/// - Yellow: 50-80% (warning)
/// - Red: 80-100% (critical)
///
/// Example:
/// ```swift
/// MemoryPressureGaugeView(
///     pressurePercentage: 65,
///     size: 80
/// )
/// ```
public struct MemoryPressureGaugeView: View {
    // MARK: - Properties

    /// Memory pressure percentage (0-100)
    private let pressurePercentage: Double

    /// Memory pressure level (if available)
    private let pressureLevel: MemoryPressure?

    /// Size of the gauge (width and height)
    private let size: CGFloat

    /// Width of the gauge stroke
    private let lineWidth: CGFloat

    // MARK: - Constants

    private static let greenThreshold: Double = 50.0
    private static let yellowThreshold: Double = 80.0

    // MARK: - Initializer

    /// Initialize a memory pressure gauge
    /// - Parameters:
    ///   - pressurePercentage: Memory pressure percentage (0-100)
    ///   - pressureLevel: Optional MemoryPressure enum value
    ///   - size: Width/height of the gauge (default: 80)
    ///   - lineWidth: Stroke width of the gauge ring (default: 10)
    public init(
        pressurePercentage: Double,
        pressureLevel: MemoryPressure? = nil,
        size: CGFloat = 80,
        lineWidth: CGFloat = 10
    ) {
        self.pressurePercentage = max(0, min(100, pressurePercentage))
        self.pressureLevel = pressureLevel
        self.size = size
        self.lineWidth = lineWidth
    }

    // MARK: - Body

    public var body: some View {
        ZStack {
            // Background track
            backgroundTrack

            // Three-segment arc
            coloredArcs

            // Needle indicator
            needle

            // Center text
            centerText
        }
        .frame(width: size, height: size)
    }

    // MARK: - View Components

    private var backgroundTrack: some View {
        Circle()
            .stroke(
                Color(nsColor: .separatorColor).opacity(0.2),
                lineWidth: lineWidth
            )
            .frame(width: size, height: size)
    }

    private var coloredArcs: some View {
        ZStack {
            // Green arc (0-50%): 0 to 180 degrees
            greenArc

            // Yellow arc (50-80%): 180 to 288 degrees
            yellowArc

            // Red arc (80-100%): 288 to 360 degrees
            redArc
        }
    }

    private var greenArc: some View {
        let startAngle = Angle.degrees(-90)
        let endAngle = Angle.degrees(-90 + (180 * Self.greenThreshold / 100))

        return Circle()
            .trim(from: 0, to: 0.5) // 50% of circle = 180 degrees
            .stroke(
                TonicColors.success,
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt)
            )
            .frame(width: size, height: size)
            .rotationEffect(.degrees(-90))
    }

    private var yellowArc: some View {
        let yellowRange = Self.yellowThreshold - Self.greenThreshold // 30%
        let yellowFraction = yellowRange / 100 // 0.3
        let greenFraction = Self.greenThreshold / 100 // 0.5

        return Circle()
            .trim(from: greenFraction, to: greenFraction + yellowFraction)
            .stroke(
                TonicColors.warning,
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt)
            )
            .frame(width: size, height: size)
            .rotationEffect(.degrees(-90))
    }

    private var redArc: some View {
        let redRange = 100 - Self.yellowThreshold // 20%
        let redFraction = redRange / 100 // 0.2
        let yellowEndFraction = Self.yellowThreshold / 100 // 0.8

        return Circle()
            .trim(from: yellowEndFraction, to: yellowEndFraction + redFraction)
            .stroke(
                TonicColors.error,
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt)
            )
            .frame(width: size, height: size)
            .rotationEffect(.degrees(-90))
    }

    private var needle: some View {
        let rotationAngle = (pressurePercentage / 100) * 360 - 90

        return ZStack {
            // Needle line
            Rectangle()
                .fill(Color(nsColor: .labelColor))
                .frame(width: 2, height: size / 2 - lineWidth)
                .offset(y: -size / 4 + lineWidth / 2)

            // Center dot
            Circle()
                .fill(Color(nsColor: .labelColor))
                .frame(width: 6, height: 6)
        }
        .rotationEffect(.degrees(rotationAngle))
        .animation(.easeInOut(duration: 0.3), value: pressurePercentage)
    }

    private var centerText: some View {
        VStack(spacing: 2) {
            Text(pressureText)
                .font(.system(size: size * 0.18, weight: .semibold))
                .foregroundColor(textColor)

            Text(pressureLevelText)
                .font(.system(size: size * 0.11, weight: .medium))
                .foregroundColor(textColor.opacity(0.8))
        }
    }

    // MARK: - Computed Properties

    private var pressureText: String {
        return "\(Int(pressurePercentage))%"
    }

    private var pressureLevelText: String {
        if let level = pressureLevel {
            return level.displayName
        }
        // Calculate from percentage
        switch pressurePercentage {
        case 0..<Self.greenThreshold:
            return "Normal"
        case Self.greenThreshold..<Self.yellowThreshold:
            return "Warning"
        default:
            return "Critical"
        }
    }

    private var textColor: Color {
        switch pressurePercentage {
        case 0..<Self.greenThreshold:
            return TonicColors.success
        case Self.greenThreshold..<Self.yellowThreshold:
            return TonicColors.warning
        default:
            return TonicColors.error
        }
    }
}

// MARK: - Memory Pressure Extension

extension MemoryPressure {
    /// Display name for the memory pressure level
    var displayName: String {
        switch self {
        case .normal:
            return "Normal"
        case .warning:
            return "Warning"
        case .critical:
            return "Critical"
        }
    }

    /// Approximate percentage for this pressure level
    var approximatePercentage: Double {
        switch self {
        case .normal:
            return 25
        case .warning:
            return 65
        case .critical:
            return 90
        }
    }
}

// MARK: - Preview

#Preview("Memory Pressure Gauge") {
    VStack(spacing: 32) {
        Text("Memory Pressure Gauge")
            .font(.headline)
            .foregroundColor(.secondary)

        // Normal pressure levels (green zone)
        HStack(spacing: 24) {
            MemoryPressureGaugeView(pressurePercentage: 10, size: 80)
            MemoryPressureGaugeView(pressurePercentage: 25, size: 80)
            MemoryPressureGaugeView(pressurePercentage: 45, size: 80)
        }

        // Warning pressure levels (yellow zone)
        HStack(spacing: 24) {
            MemoryPressureGaugeView(pressurePercentage: 55, size: 80)
            MemoryPressureGaugeView(pressurePercentage: 65, size: 80)
            MemoryPressureGaugeView(pressurePercentage: 75, size: 80)
        }

        // Critical pressure levels (red zone)
        HStack(spacing: 24) {
            MemoryPressureGaugeView(pressurePercentage: 85, size: 80)
            MemoryPressureGaugeView(pressurePercentage: 92, size: 80)
            MemoryPressureGaugeView(pressurePercentage: 98, size: 80)
        }

        // With MemoryPressure enum
        HStack(spacing: 24) {
            MemoryPressureGaugeView(
                pressurePercentage: MemoryPressure.normal.approximatePercentage,
                pressureLevel: .normal,
                size: 80
            )
            MemoryPressureGaugeView(
                pressurePercentage: MemoryPressure.warning.approximatePercentage,
                pressureLevel: .warning,
                size: 80
            )
            MemoryPressureGaugeView(
                pressurePercentage: MemoryPressure.critical.approximatePercentage,
                pressureLevel: .critical,
                size: 80
            )
        }

        // Different sizes
        HStack(spacing: 24) {
            MemoryPressureGaugeView(pressurePercentage: 65, size: 60)
            MemoryPressureGaugeView(pressurePercentage: 65, size: 80)
            MemoryPressureGaugeView(pressurePercentage: 65, size: 100)
        }

        // Dark mode preview
        HStack(spacing: 24) {
            MemoryPressureGaugeView(pressurePercentage: 25, size: 80)
                .background(Color.black.opacity(0.8))
                .cornerRadius(12)

            MemoryPressureGaugeView(pressurePercentage: 65, size: 80)
                .background(Color.black.opacity(0.8))
                .cornerRadius(12)

            MemoryPressureGaugeView(pressurePercentage: 90, size: 80)
                .background(Color.black.opacity(0.8))
                .cornerRadius(12)
        }
    }
    .padding()
}
