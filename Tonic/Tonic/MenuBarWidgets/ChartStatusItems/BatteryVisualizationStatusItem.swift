//
//  BatteryVisualizationStatusItem.swift
//  Tonic
//
//  Status item for battery icon visualization with fill level
//  Task ID: fn-6-i4g.17
//

import AppKit
import SwiftUI

// MARK: - Battery Additional Info Mode

/// Options for additional battery information display
public enum BatteryAdditionalInfo: String, CaseIterable, Identifiable, Codable, Sendable {
    case none = "none"                  // Just the battery icon
    case percentageInside = "inside"    // Percentage text inside battery
    case percentageBeside = "beside"    // Percentage text beside battery
    case timeRemaining = "time"         // Time remaining beside battery

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .none: return "None"
        case .percentageInside: return "Percentage Inside"
        case .percentageBeside: return "Percentage Beside"
        case .timeRemaining: return "Time Remaining"
        }
    }
}

// MARK: - Battery Visualization Status Item

/// Status item that displays a battery icon with fill level in the menu bar
@MainActor
public final class BatteryVisualizationStatusItem: WidgetStatusItem {

    public override init(widgetType: WidgetType = .battery, configuration: WidgetConfiguration) {
        super.init(widgetType: widgetType, configuration: configuration)

        // Auto-hide on desktop Macs (no battery)
        if !WidgetDataManager.shared.batteryData.isPresent {
            hide()
        }
    }

    public override func createCompactView() -> AnyView {
        AnyView(
            BatteryVisualizationView(
                configuration: configuration
            )
        )
    }

    public override func createDetailView() -> AnyView {
        AnyView(BatteryDetailView())
    }
}

// MARK: - Battery Visualization View

/// Battery icon with fill level for menu bar
/// Features:
/// - Battery icon fills proportionally to percentage
/// - Charging indicator (bolt) when plugged in
/// - Optional percentage display (inside, beside, or none)
/// - Optional time remaining display
struct BatteryVisualizationView: View {
    let configuration: WidgetConfiguration
    @State private var dataManager = WidgetDataManager.shared

    /// Battery fill percentage (0-100)
    private var percentage: Double {
        dataManager.batteryData.chargePercentage
    }

    /// Whether the battery is charging
    private var isCharging: Bool {
        dataManager.batteryData.isCharging
    }

    /// Whether the battery is fully charged
    private var isCharged: Bool {
        dataManager.batteryData.isCharged
    }

    /// Whether battery is present
    private var isPresent: Bool {
        dataManager.batteryData.isPresent
    }

    /// The fill color based on percentage
    private var fillColor: Color {
        if configuration.accentColor == .utilization {
            // For battery, invert the utilization color (low = red, high = green)
            return configuration.accentColor.colorValue(forUtilization: 100 - percentage)
        }
        // Default battery colors
        switch percentage {
        case 80...: return .green
        case 20..<80: return .yellow
        default: return .red
        }
    }

    /// The additional info mode (defaults to percentageBeside)
    private var additionalInfo: BatteryAdditionalInfo {
        // Default to showing percentage beside the icon
        .percentageBeside
    }

    var body: some View {
        if isPresent {
            HStack(spacing: 3) {
                // Battery icon with fill
                batteryIcon

                // Additional info (if enabled)
                switch additionalInfo {
                case .none:
                    EmptyView()
                case .percentageInside:
                    EmptyView() // Handled inside batteryIcon
                case .percentageBeside:
                    Text("\(Int(percentage))%")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.primary)
                case .timeRemaining:
                    if let minutes = dataManager.batteryData.estimatedMinutesRemaining {
                        Text(formatTime(minutes))
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                }
            }
            .padding(.horizontal, 2)
            .frame(height: 22)
        } else {
            EmptyView()
        }
    }

    /// Battery icon with custom fill level
    private var batteryIcon: some View {
        ZStack {
            // Battery outline
            BatteryShape()
                .stroke(Color.primary.opacity(0.6), lineWidth: 1)
                .frame(width: 24, height: 12)

            // Battery fill
            BatteryFillShape(fillPercentage: percentage / 100)
                .fill(fillColor)
                .frame(width: 24, height: 12)

            // Charging bolt overlay
            if isCharging && !isCharged {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 0.5, x: 0, y: 0)
            }

            // Percentage inside (if that mode is selected)
            if additionalInfo == .percentageInside && !isCharging {
                Text("\(Int(percentage))")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 0.5, x: 0, y: 0)
            }
        }
    }

    /// Format time remaining as a string
    private func formatTime(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            if mins == 0 {
                return "\(hours)h"
            }
            return "\(hours):\(String(format: "%02d", mins))"
        }
    }
}

// MARK: - Battery Shape

/// Custom shape for battery outline
struct BatteryShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        // Main battery body
        let bodyWidth = rect.width - 3 // Leave room for terminal
        let cornerRadius: CGFloat = 2

        // Body rectangle
        let bodyRect = CGRect(x: 0, y: 0, width: bodyWidth, height: rect.height)
        path.addRoundedRect(in: bodyRect, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))

        // Terminal (positive end)
        let terminalWidth: CGFloat = 2
        let terminalHeight: CGFloat = rect.height * 0.4
        let terminalY = (rect.height - terminalHeight) / 2
        let terminalRect = CGRect(x: bodyWidth, y: terminalY, width: terminalWidth, height: terminalHeight)
        path.addRoundedRect(in: terminalRect, cornerSize: CGSize(width: 1, height: 1))

        return path
    }
}

// MARK: - Battery Fill Shape

/// Custom shape for battery fill level
struct BatteryFillShape: Shape {
    var fillPercentage: Double

    var animatableData: Double {
        get { fillPercentage }
        set { fillPercentage = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        // Calculate fill dimensions
        let bodyWidth = rect.width - 3 // Same as BatteryShape
        let inset: CGFloat = 2
        let fillWidth = max(0, (bodyWidth - inset * 2) * fillPercentage)
        let fillHeight = rect.height - inset * 2
        let cornerRadius: CGFloat = 1

        // Fill rectangle
        let fillRect = CGRect(x: inset, y: inset, width: fillWidth, height: fillHeight)
        path.addRoundedRect(in: fillRect, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))

        return path
    }
}

// MARK: - Battery Detail View (Extended)

/// Extended battery detail view showing more information
struct BatteryVisualizationDetailView: View {
    @State private var dataManager = WidgetDataManager.shared

    private var battery: BatteryData {
        dataManager.batteryData
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            if battery.isPresent {
                contentView
            } else {
                noBatteryView
            }
        }
        .frame(width: 300, height: 340)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack {
            // Battery icon
            ZStack {
                BatteryShape()
                    .stroke(batteryColor.opacity(0.8), lineWidth: 1.5)
                    .frame(width: 32, height: 16)

                BatteryFillShape(fillPercentage: battery.chargePercentage / 100)
                    .fill(batteryColor)
                    .frame(width: 32, height: 16)

                if battery.isCharging && !battery.isCharged {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                }
            }

            Text("Battery")
                .font(.headline)

            Spacer()

            Text("\(Int(battery.chargePercentage))%")
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(batteryColor)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var contentView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Large visual indicator
                largeIndicator

                // Status info
                statusSection

                Divider()

                // Health info
                healthSection

                // Additional stats
                statsSection
            }
            .padding()
        }
    }

    private var largeIndicator: some View {
        ZStack {
            // Large battery icon
            BatteryShape()
                .stroke(Color(nsColor: .separatorColor), lineWidth: 2)
                .frame(width: 80, height: 40)

            BatteryFillShape(fillPercentage: battery.chargePercentage / 100)
                .fill(batteryColor.gradient)
                .frame(width: 80, height: 40)

            if battery.isCharging && !battery.isCharged {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 1)
            }
        }
    }

    private var statusSection: some View {
        HStack(spacing: 24) {
            VStack {
                Text(battery.isCharging ? "Charging" : "On Battery")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(Int(battery.chargePercentage))%")
                    .font(.title2)
                    .fontWeight(.bold)
            }

            if let minutes = battery.estimatedMinutesRemaining {
                VStack {
                    Text(battery.isCharging ? "Full in" : "Remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatTime(minutes))
                        .font(.title2)
                        .fontWeight(.bold)
                }
            }
        }
    }

    private var healthSection: some View {
        HStack {
            Image(systemName: "heart.fill")
                .foregroundColor(healthColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("Battery Health")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(healthDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(healthLabel)
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(healthColor.opacity(0.2))
                .foregroundColor(healthColor)
                .cornerRadius(4)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    private var statsSection: some View {
        VStack(spacing: 8) {
            if let cycleCount = battery.cycleCount {
                statRow(label: "Cycle Count", value: "\(cycleCount)")
            }
            if let temp = battery.temperature {
                statRow(label: "Temperature", value: String(format: "%.1f C", temp))
            }
            if let wattage = battery.chargerWattage, battery.isCharging {
                statRow(label: "Charger", value: String(format: "%.0f W", wattage))
            }
            if let optimized = battery.optimizedCharging {
                statRow(label: "Optimized Charging", value: optimized ? "On" : "Off")
            }
        }
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(.caption, design: .monospaced))
        }
    }

    private var noBatteryView: some View {
        VStack(spacing: 16) {
            Image(systemName: "desktopcomputer")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text("No Battery Detected")
                .font(.subheadline)
                .fontWeight(.semibold)

            Text("This widget is for portable Macs only")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var batteryColor: Color {
        switch battery.chargePercentage {
        case 80...: return .green
        case 20..<80: return .yellow
        default: return .red
        }
    }

    private var healthColor: Color {
        switch battery.health {
        case .good: return .green
        case .fair: return .yellow
        case .poor, .unknown: return .orange
        }
    }

    private var healthLabel: String {
        switch battery.health {
        case .good: return "Good"
        case .fair: return "Fair"
        case .poor: return "Poor"
        case .unknown: return "Unknown"
        }
    }

    private var healthDescription: String {
        switch battery.health {
        case .good: return "Battery is functioning normally"
        case .fair: return "Battery capacity has decreased"
        case .poor: return "Battery should be replaced soon"
        case .unknown: return "Unable to determine battery health"
        }
    }

    private func formatTime(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)h \(mins)m"
        }
    }
}

// MARK: - Preview

#Preview("Battery Visualization") {
    BatteryVisualizationView(
        configuration: WidgetConfiguration.default(for: .battery, at: 0)
    )
    .frame(width: 50, height: 22)
    .background(Color(nsColor: .windowBackgroundColor))
}

#Preview("Battery Shape") {
    VStack(spacing: 20) {
        // 100%
        ZStack {
            BatteryShape()
                .stroke(Color.primary, lineWidth: 1)
                .frame(width: 40, height: 20)
            BatteryFillShape(fillPercentage: 1.0)
                .fill(.green)
                .frame(width: 40, height: 20)
        }

        // 50%
        ZStack {
            BatteryShape()
                .stroke(Color.primary, lineWidth: 1)
                .frame(width: 40, height: 20)
            BatteryFillShape(fillPercentage: 0.5)
                .fill(.yellow)
                .frame(width: 40, height: 20)
        }

        // 20%
        ZStack {
            BatteryShape()
                .stroke(Color.primary, lineWidth: 1)
                .frame(width: 40, height: 20)
            BatteryFillShape(fillPercentage: 0.2)
                .fill(.red)
                .frame(width: 40, height: 20)
        }
    }
    .padding()
}

#Preview("Battery Detail") {
    BatteryVisualizationDetailView()
        .frame(width: 300, height: 340)
}
