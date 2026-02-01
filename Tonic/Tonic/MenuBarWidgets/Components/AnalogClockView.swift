//
//  AnalogClockView.swift
//  Tonic
//
//  Optional analog clock face component for Clock widget
//  Task ID: fn-6-i4g.51
//

import SwiftUI

// MARK: - Analog Clock View

/// An analog clock face with hour, minute, and second hands
/// Optionally styled to match Tonic's design system
public struct AnalogClockView: View {

    // MARK: - Properties

    /// The date/time to display
    let date: Date

    /// Size of the clock face
    var size: CGFloat = 120

    /// Whether to show the second hand
    var showSecondHand: Bool = true

    /// Accent color for the clock
    var accentColor: Color = DesignTokens.Colors.accent

    // MARK: - Body

    public var body: some View {
        ZStack {
            // Clock face background
            Circle()
                .fill(Color(nsColor: .controlBackgroundColor))
                .frame(width: size, height: size)

            // Clock face border
            Circle()
                .stroke(
                    DesignTokens.Colors.textSecondary.opacity(0.2),
                    lineWidth: 2
                )
                .frame(width: size, height: size)

            // Hour markers
            ForEach(0..<12) { i in
                hourMarker(at: i)
            }

            // Minute markers
            ForEach(0..<60) { i in
                if i % 5 != 0 {
                    minuteMarker(at: i)
                }
            }

            // Hour hand
            hourHand

            // Minute hand
            minuteHand

            // Second hand (optional)
            if showSecondHand {
                secondHand
            }

            // Center dot
            centerDot
        }
        .frame(width: size, height: size)
    }

    // MARK: - Clock Components

    private func hourMarker(at index: Int) -> some View {
        Rectangle()
            .fill(DesignTokens.Colors.textSecondary)
            .frame(width: 2, height: 10)
            .offset(y: -(size / 2 - 12))
            .rotationEffect(.degrees(Double(index) * 30))
    }

    private func minuteMarker(at index: Int) -> some View {
        Rectangle()
            .fill(DesignTokens.Colors.textSecondary.opacity(0.3))
            .frame(width: 1, height: 5)
            .offset(y: -(size / 2 - 8))
            .rotationEffect(.degrees(Double(index) * 6))
    }

    private var hourHand: some View {
        Rectangle()
            .fill(DesignTokens.Colors.textPrimary)
            .frame(width: 4, height: size / 3.5)
            .offset(y: -size / 7)
            .rotationEffect(.degrees(hourAngle))
            .shadow(radius: 1)
    }

    private var minuteHand: some View {
        Rectangle()
            .fill(DesignTokens.Colors.textPrimary)
            .frame(width: 2.5, height: size / 2.8)
            .offset(y: -size / 5.6)
            .rotationEffect(.degrees(minuteAngle))
            .shadow(radius: 1)
    }

    private var secondHand: some View {
        Rectangle()
            .fill(accentColor)
            .frame(width: 1, height: size / 2.4)
            .offset(y: -size / 4.8)
            .rotationEffect(.degrees(secondAngle))
    }

    private var centerDot: some View {
        ZStack {
            Circle()
                .fill(accentColor)
                .frame(width: 8, height: 8)

            Circle()
                .fill(Color.white)
                .frame(width: 3, height: 3)
        }
    }

    // MARK: - Angle Calculations

    private var hourAngle: Double {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        // Convert to degrees: each hour = 30 degrees, each minute adds 0.5 degrees
        return Double((hour % 12) * 30) + Double(minute) * 0.5 - 90
    }

    private var minuteAngle: Double {
        let calendar = Calendar.current
        let minute = calendar.component(.minute, from: date)
        let second = calendar.component(.second, from: date)
        // Convert to degrees: each minute = 6 degrees, each second adds 0.1 degrees
        return Double(minute) * 6 + Double(second) * 0.1 - 90
    }

    private var secondAngle: Double {
        let calendar = Calendar.current
        let second = calendar.component(.second, from: date)
        // Convert to degrees: each second = 6 degrees
        return Double(second) * 6 - 90
    }

    // MARK: - Initialization

    public init(date: Date, size: CGFloat = 120, showSecondHand: Bool = true, accentColor: Color = DesignTokens.Colors.accent) {
        self.date = date
        self.size = size
        self.showSecondHand = showSecondHand
        self.accentColor = accentColor
    }
}

// MARK: - Compact Analog Clock (Small Variant)

/// A smaller analog clock for compact displays
public struct CompactAnalogClockView: View {
    let date: Date
    var size: CGFloat = 60

    public var body: some View {
        AnalogClockView(
            date: date,
            size: size,
            showSecondHand: false,
            accentColor: DesignTokens.Colors.accent
        )
    }

    public init(date: Date, size: CGFloat = 60) {
        self.date = date
        self.size = size
    }
}

// MARK: - Preview

#Preview("Analog Clock") {
    VStack(spacing: 20) {
        // Full size analog clock
        AnalogClockView(date: Date(), size: 120)

        // Compact variant
        HStack(spacing: 20) {
            CompactAnalogClockView(date: Date(), size: 60)
            CompactAnalogClockView(date: Date().addingTimeInterval(3600), size: 60)
            CompactAnalogClockView(date: Date().addingTimeInterval(-3600), size: 60)
        }
    }
    .padding()
}
