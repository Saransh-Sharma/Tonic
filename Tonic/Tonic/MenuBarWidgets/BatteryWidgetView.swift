//
//  BatteryWidgetView.swift
//  Tonic
//
//  Battery monitoring widget views
//  Task ID: fn-2.15
//  Updated: fn-6-i4g.18 - Standardized popover layout
//

import SwiftUI
import IOKit.ps

// MARK: - Battery Compact View

/// Compact menu bar view for Battery widget
public struct BatteryCompactView: View {

    @State private var dataManager = WidgetDataManager.shared

    public init() {}

    public var body: some View {
        HStack(spacing: 4) {
            let battery = dataManager.batteryData
            if battery.isPresent {
                Image(systemName: batteryIcon(for: battery))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(batteryColor(for: battery))

                Text("\(Int(battery.chargePercentage))%")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.primary)

                // Charging indicator
                if battery.isCharging && !battery.isCharged {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.green)
                }
            } else {
                // No battery - this widget should hide on desktop Macs
                EmptyView()
            }
        }
        .padding(.horizontal, 4)
        .frame(height: 22)
    }

    private func batteryIcon(for battery: BatteryData) -> String {
        if battery.isCharging {
            return "battery.100.bolt"
        }

        let percentage = battery.chargePercentage
        switch percentage {
        case 80...: return "battery.100"
        case 50..<80: return "battery.75"
        case 25..<50: return "battery.50"
        case 10..<25: return "battery.25"
        default: return "battery.0"
        }
    }

    private func batteryColor(for battery: BatteryData) -> Color {
        switch battery.chargePercentage {
        case 50...: return .green
        case 20..<50: return .yellow
        default: return .red
        }
    }
}

// MARK: - Battery Detail View

/// Detailed popover view for Battery widget
/// Uses standardized PopoverTemplate for consistent layout
public struct BatteryDetailView: View {

    @State private var dataManager = WidgetDataManager.shared

    public init() {}

    public var body: some View {
        let battery = dataManager.batteryData

        PopoverTemplate(
            icon: PopoverConstants.Icons.battery,
            title: PopoverConstants.Names.battery,
            headerValue: battery.isPresent ? "\(Int(battery.chargePercentage))%" : nil,
            headerColor: battery.isPresent ? batteryColor(for: battery) : .gray
        ) {
            if battery.isPresent {
                contentView(battery: battery)
            } else {
                noBatteryView
            }
        }
    }

    private func contentView(battery: BatteryData) -> some View {
        VStack(spacing: PopoverConstants.sectionSpacing) {
            // Large percentage display
            VStack(spacing: DesignTokens.Spacing.sm) {
                ZStack {
                    CircularProgress(
                        percentage: battery.chargePercentage,
                        size: 120,
                        lineWidth: 8,
                        color: batteryColor(for: battery)
                    )

                    VStack(spacing: 4) {
                        Text("\(Int(battery.chargePercentage))%")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(batteryColor(for: battery))

                        if battery.isCharging && !battery.isCharged {
                            Image(systemName: "bolt.fill")
                                .foregroundColor(.green)
                        }

                        Text(battery.isCharging ? "Charging" : "On Battery")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Time remaining
            if let minutes = battery.estimatedMinutesRemaining {
                PopoverSection {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        Image(systemName: "clock")
                            .foregroundColor(.secondary)

                        if battery.isCharging {
                            Text("\(minutes) min until full")
                                .font(.subheadline)
                        } else {
                            Text("\(timeString(minutes)) remaining")
                                .font(.subheadline)
                        }

                        Spacer()
                    }
                }
            }

            // Health status
            healthSection(battery: battery)
        }
    }

    private var noBatteryView: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
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
    }

    private func healthSection(battery: BatteryData) -> some View {
        PopoverSection {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "heart.fill")
                    .foregroundColor(healthColor(for: battery))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Battery Health")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(healthText(for: battery))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
        }
    }

    private func healthColor(for battery: BatteryData) -> Color {
        switch battery.health {
        case .good: return .green
        case .fair: return .yellow
        case .poor, .unknown: return .orange
        }
    }

    private func healthText(for battery: BatteryData) -> String {
        switch battery.health {
        case .good: return "Good"
        case .fair: return "Fair"
        case .poor: return "Poor - Consider replacing"
        case .unknown: return "Unknown"
        }
    }

    private func timeString(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)h \(mins)m"
        }
    }

    private func batteryColor(for battery: BatteryData) -> Color {
        switch battery.chargePercentage {
        case 50...: return .green
        case 20..<50: return .yellow
        default: return .red
        }
    }
}

// MARK: - Battery Status Item

/// Manages the Battery widget's NSStatusItem
/// Automatically hides on desktop Macs (no battery detected)
@MainActor
public final class BatteryStatusItem: WidgetStatusItem {

    public override init(widgetType: WidgetType = .battery, configuration: WidgetConfiguration) {
        super.init(widgetType: widgetType, configuration: configuration)

        // Auto-hide on desktop Macs
        if !WidgetDataManager.shared.batteryData.isPresent {
            hide()
        }
    }

    // Uses base WidgetStatusItem.createCompactView() which respects configuration

    public override func createDetailView() -> AnyView {
        AnyView(BatteryPopoverView())
    }
}

// MARK: - Preview

#Preview("Battery Detail") {
    BatteryDetailView()
}
