//
//  BatteryDetailsWidgetView.swift
//  Tonic
//
//  Battery Details widget for comprehensive battery information
//  Matches Stats Master's Battery Details functionality
//  Task ID: fn-5-v8r.12
//

import SwiftUI

// MARK: - Battery Details Config

/// Configuration for battery details display
public struct BatteryDetailsConfig: Sendable, Equatable {
    public let showPercentage: Bool
    public let showTimeRemaining: Bool
    public let showHealth: Bool
    public let showCycleCount: Bool
    public let showPowerSource: Bool
    public let displayMode: BatteryDisplayMode

    public init(
        showPercentage: Bool = true,
        showTimeRemaining: Bool = true,
        showHealth: Bool = false,
        showCycleCount: Bool = false,
        showPowerSource: Bool = true,
        displayMode: BatteryDisplayMode = .compact
    ) {
        self.showPercentage = showPercentage
        self.showTimeRemaining = showTimeRemaining
        self.showHealth = showHealth
        self.showCycleCount = showCycleCount
        self.showPowerSource = showPowerSource
        self.displayMode = displayMode
    }
}

/// Display mode for battery details
public enum BatteryDisplayMode: String, Sendable, Equatable {
    case compact     // Percentage + icon
    case detailed    // Multiple rows of info
    case graphical   // Large pie chart with details
}

// MARK: - Battery Details Widget View

/// Battery details widget showing extended battery information
public struct BatteryDetailsWidgetView: View {
    let batteryData: BatteryData
    let config: BatteryDetailsConfig

    public init(
        batteryData: BatteryData,
        config: BatteryDetailsConfig = BatteryDetailsConfig()
    ) {
        self.batteryData = batteryData
        self.config = config
    }

    public var body: some View {
        Group {
            switch config.displayMode {
            case .compact:
                compactView
            case .detailed:
                detailedView
            case .graphical:
                graphicalView
            }
        }
    }

    // MARK: - Display Modes

    private var compactView: some View {
        HStack(spacing: 6) {
            // Battery icon with percentage
            ZStack {
                // Battery outline
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color.primary.opacity(0.5), lineWidth: 1)
                    .frame(width: 24, height: 11)

                // Fill
                GeometryReader { geometry in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(batteryColor)
                        .frame(width: geometry.size.width * CGFloat(batteryData.chargePercentage / 100), height: 7)
                }
                .frame(width: 22, height: 9)
                .offset(x: -11)

                // Charging indicator
                if batteryData.isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 6))
                        .foregroundColor(.white)
                }
            }
            .frame(width: 28, height: 14)

            // Percentage
            if config.showPercentage {
                Text("\(Int(batteryData.chargePercentage))%")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(batteryColor)
            }

            // Time remaining
            if config.showTimeRemaining, let minutes = batteryData.estimatedMinutesRemaining {
                Text(timeString(from: minutes))
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        }
        .frame(height: 22)
        .padding(.horizontal, 4)
    }

    private var detailedView: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Main row: icon + percentage + time
            HStack(spacing: 8) {
                batteryIcon

                Text("\(Int(batteryData.chargePercentage))%")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(batteryColor)

                if batteryData.isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 10))
                        .foregroundColor(batteryColor)
                }

                if config.showTimeRemaining, let minutes = batteryData.estimatedMinutesRemaining {
                    Spacer()
                    Text(timeString(from: minutes))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            // Secondary info row
            HStack(spacing: 12) {
                if config.showHealth {
                    healthBadge
                }

                if config.showCycleCount, let cycles = batteryData.cycleCount {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 8))
                        Text("\(cycles)")
                            .font(.system(size: 9))
                    }
                    .foregroundColor(.secondary)
                }

                if config.showPowerSource {
                    powerSourceIndicator
                }
            }
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    private var graphicalView: some View {
        HStack(spacing: 16) {
            // Large pie chart
            ZStack {
                Circle()
                    .stroke(batteryColor.opacity(0.2), lineWidth: 6)
                    .frame(width: 60, height: 60)

                Circle()
                    .trim(from: 0, to: batteryData.chargePercentage / 100)
                    .stroke(
                        batteryColor,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 60, height: 60)
                    .animation(.easeInOut(duration: 0.3), value: batteryData.chargePercentage)

                // Center content
                VStack(spacing: 0) {
                    if batteryData.isCharging {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 10))
                            .foregroundColor(batteryColor)
                    }

                    Text("\(Int(batteryData.chargePercentage))")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(batteryColor)

                    Text("%")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            // Details column
            VStack(alignment: .leading, spacing: 6) {
                if config.showTimeRemaining, let minutes = batteryData.estimatedMinutesRemaining {
                    detailRow(icon: "clock", label: "Time Left", value: timeString(from: minutes))
                }

                if config.showHealth {
                    detailRow(icon: "heart.fill", label: "Health", value: healthDescription)
                }

                if config.showCycleCount, let cycles = batteryData.cycleCount {
                    detailRow(icon: "arrow.clockwise", label: "Cycles", value: "\(cycles)")
                }

                detailRow(icon: "plug", label: "Source", value: powerSourceDescription)
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
    }

    // MARK: - Components

    private var batteryIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2)
                .stroke(Color.primary.opacity(0.5), lineWidth: 1)
                .frame(width: 20, height: 10)

            GeometryReader { geometry in
                RoundedRectangle(cornerRadius: 1)
                    .fill(batteryColor)
                    .frame(width: geometry.size.width * CGFloat(batteryData.chargePercentage / 100), height: 6)
            }
            .frame(width: 18, height: 8)

            RoundedRectangle(cornerRadius: 1)
                .fill(Color.primary.opacity(0.5))
                .frame(width: 2, height: 4)
                .offset(x: 11)
        }
        .frame(width: 24, height: 12)
    }

    private var healthBadge: some View {
        Text(healthDescription)
            .font(.system(size: 8, weight: .medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(healthColor.opacity(0.2))
            .foregroundColor(healthColor)
            .cornerRadius(4)
    }

    private var powerSourceIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: batteryData.isCharging ? "bolt.fill" : "battery.100")
                .font(.system(size: 8))
            Text(powerSourceDescription)
                .font(.system(size: 9))
        }
        .foregroundColor(.secondary)
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(.system(size: 7))
                    .foregroundColor(.secondary)

                Text(value)
                    .font(.system(size: 10, weight: .medium))
            }

            Spacer()
        }
    }

    // MARK: - Computed Properties

    private var batteryColor: Color {
        guard batteryData.isPresent else { return .gray }
        if batteryData.isCharging { return .blue }
        switch batteryData.chargePercentage {
        case 0..<20: return .red
        case 20..<50: return .orange
        default: return .green
        }
    }

    private var healthColor: Color {
        switch batteryData.health {
        case .good: return .green
        case .fair: return .orange
        case .poor: return .red
        case .unknown: return .gray
        }
    }

    private var healthDescription: String {
        batteryData.health.description
    }

    private var powerSourceDescription: String {
        if batteryData.isCharging {
            return "Charging"
        } else if batteryData.isCharged {
            return "Fully Charged"
        } else {
            return "Battery"
        }
    }

    private func timeString(from minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
    }
}

// MARK: - Animated Charging Indicator

@Observable
@MainActor
public final class ChargingAnimationState {
    public var isAnimating: Bool = false
    private var animationPhase: Double = 0

    public init(isCharging: Bool = false) {
        self.isAnimating = isCharging
    }

    public func startChargingAnimation() {
        isAnimating = true
    }

    public func stopChargingAnimation() {
        isAnimating = false
    }

    public var boltOpacity: Double {
        isAnimating ? 0.5 + 0.5 * sin(animationPhase * .pi) : 1.0
    }
}

// MARK: - Preview

#Preview("Battery Details Widget") {
    VStack(spacing: 24) {
        // Compact mode
        VStack(alignment: .leading, spacing: 4) {
            Text("Compact Mode")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                BatteryDetailsWidgetView(
                    batteryData: BatteryData(
                        isPresent: true,
                        isCharging: false,
                        chargePercentage: 85,
                        estimatedMinutesRemaining: 240
                    ),
                    config: BatteryDetailsConfig(displayMode: .compact)
                )

                BatteryDetailsWidgetView(
                    batteryData: BatteryData(
                        isPresent: true,
                        isCharging: true,
                        chargePercentage: 45,
                        estimatedMinutesRemaining: 90
                    ),
                    config: BatteryDetailsConfig(displayMode: .compact)
                )

                BatteryDetailsWidgetView(
                    batteryData: BatteryData(
                        isPresent: true,
                        isCharging: false,
                        chargePercentage: 15,
                        estimatedMinutesRemaining: 30
                    ),
                    config: BatteryDetailsConfig(displayMode: .compact)
                )
            }
        }

        // Detailed mode
        VStack(alignment: .leading, spacing: 4) {
            Text("Detailed Mode")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                BatteryDetailsWidgetView(
                    batteryData: BatteryData(
                        isPresent: true,
                        isCharging: false,
                        chargePercentage: 72,
                        estimatedMinutesRemaining: 185,
                        health: .good
                    ),
                    config: BatteryDetailsConfig(
                        showHealth: true,
                        showPowerSource: true,
                        displayMode: .detailed
                    )
                )
            }
        }

        // Graphical mode
        VStack(alignment: .leading, spacing: 4) {
            Text("Graphical Mode")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                BatteryDetailsWidgetView(
                    batteryData: BatteryData(
                        isPresent: true,
                        isCharging: true,
                        chargePercentage: 62,
                        estimatedMinutesRemaining: 120,
                        health: .fair,
                        cycleCount: 342
                    ),
                    config: BatteryDetailsConfig(
                        showHealth: true,
                        showCycleCount: true,
                        displayMode: .graphical
                    )
                )
            }
        }

        // No battery state
        BatteryDetailsWidgetView(
            batteryData: BatteryData(isPresent: false),
            config: BatteryDetailsConfig(displayMode: .compact)
        )
    }
    .padding()
}
