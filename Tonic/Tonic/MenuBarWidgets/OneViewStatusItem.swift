//
//  OneViewStatusItem.swift
//  Tonic
//
//  Unified menu bar item that combines all enabled widgets into a single view
//  Task ID: fn-6-i4g.11
//

import AppKit
import SwiftUI
import os

// MARK: - One View Status Item

/// Single status item that displays all enabled widgets in a compact horizontal grid
/// When clicked, shows a unified popover with all widget details
@MainActor
public final class OneViewStatusItem: WidgetStatusItem {

    private let logger = Logger(subsystem: "com.tonic.app", category: "OneViewStatusItem")

    /// Maximum number of widgets to show in menu bar before showing overflow indicator
    private let maxVisibleWidgets = 6

    public init() {
        // Create a dummy configuration for OneView - it's not widget-type specific
        let oneViewConfig = WidgetConfiguration(
            type: .cpu, // Placeholder, won't be used
            isEnabled: true,
            position: -1,
            displayMode: .compact,
            showLabel: false,
            valueFormat: .percentage,
            accentColor: .system
        )

        super.init(widgetType: .cpu, configuration: oneViewConfig)
        self.logger.info("🔵 Initializing OneView unified status item")
    }

    // MARK: - View Creation

    /// Create the compact OneView that shows all widgets horizontally
    public override func createCompactView() -> AnyView {
        AnyView(
            OneViewCompactView(maxVisibleWidgets: maxVisibleWidgets)
        )
    }

    /// Create the unified detail view (popover content)
    public override func createDetailView() -> AnyView {
        AnyView(
            OneViewDetailView()
                .frame(width: 400, height: 500)
        )
    }

    /// Update the OneView when widgets change
    public func refreshWidgetList() {
        let enabledCount = WidgetPreferences.shared.enabledWidgets.count

        objectWillChange.send()
        // Force view refresh
        refresh()

        logger.debug("🔄 OneView refreshed - \(enabledCount) widgets")
    }
}

// MARK: - One View Compact View

/// Compact horizontal grid view shown in the menu bar
struct OneViewCompactView: View {
    @Environment(\.colorScheme) private var colorScheme
    let maxVisibleWidgets: Int

    private var enabledWidgets: [WidgetConfiguration] {
        WidgetPreferences.shared.enabledWidgets.sorted { $0.position < $1.position }
    }

    private var visibleWidgets: [WidgetConfiguration] {
        Array(enabledWidgets.prefix(maxVisibleWidgets))
    }

    private var showOverflow: Bool {
        enabledWidgets.count > maxVisibleWidgets
    }

    var body: some View {
        HStack(spacing: 2) {
            // Show each widget in compact form
            ForEach(visibleWidgets) { config in
                OneViewWidgetCell(config: config)
                    .frame(width: 30, height: 22)

                // Add divider between widgets (but not after last visible)
                if config.type != visibleWidgets.last?.type {
                    Divider()
                        .frame(height: 12)
                }
            }

            // Overflow indicator if needed
            if showOverflow {
                Text("...")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 20, height: 22)
            }
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - One View Widget Cell

/// Single cell showing one widget's compact representation
struct OneViewWidgetCell: View {
    let config: WidgetConfiguration

    private var accentColor: Color {
        config.accentColor.colorValue(for: config.type)
    }

    private var dataManager: WidgetDataManager {
        WidgetDataManager.shared
    }

    var body: some View {
        VStack(spacing: 0) {
            // Icon
            Image(systemName: config.type.icon)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(accentColor)

            // Value
            Text(widgetValue)
                .font(.system(size: 7, weight: .medium, design: .monospaced))
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity)
    }

    private var widgetValue: String {
        let usePercent = config.valueFormat == .percentage

        switch config.type {
        case .cpu:
            return "\(Int(dataManager.cpuData.totalUsage))%"

        case .memory:
            if usePercent {
                return "\(Int(dataManager.memoryData.usagePercentage))%"
            } else {
                let usedGB = Double(dataManager.memoryData.usedBytes) / (1024 * 1024 * 1024)
                return String(format: "%.0f", usedGB)
            }

        case .disk:
            if let primary = dataManager.diskVolumes.first {
                if usePercent {
                    return "\(Int(primary.usagePercentage))%"
                } else {
                    let freeGB = primary.freeBytes / (1024 * 1024 * 1024)
                    return "\(freeGB)"
                }
            }
            return "--"

        case .network:
            // Show abbreviated speed
            let downloadSpeed = dataManager.networkData.downloadBytesPerSecond
            if downloadSpeed > 1_000_000 {
                return String(format: "%.0fM", downloadSpeed / 1_000_000)
            } else if downloadSpeed > 1000 {
                return String(format: "%.0fK", downloadSpeed / 1000)
            }
            return "\(Int(downloadSpeed))"

        case .gpu:
            if let usage = dataManager.gpuData.usagePercentage {
                return "\(Int(usage))%"
            }
            return "--"

        case .battery:
            if dataManager.batteryData.isPresent {
                return "\(Int(dataManager.batteryData.chargePercentage))%"
            }
            return "--"

        case .weather:
            // Would show weather icon/value
            return "--"

        case .sensors:
            if let temp = dataManager.sensorsData.temperatures.first {
                return String(format: "%.0f", temp.value)
            }
            return "--"

        case .bluetooth:
            if dataManager.bluetoothData.isBluetoothEnabled {
                if let device = dataManager.bluetoothData.devicesWithBattery.first,
                   let battery = device.primaryBatteryLevel {
                    return "\(battery)%"
                }
                return "\(dataManager.bluetoothData.connectedDevices.count)"
            }
            return "Off"

        case .clock:
            // Return current time
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: Date())
        }
    }
}

// MARK: - One View Detail View

/// Unified popover showing all widget details in a scrollable list
struct OneViewDetailView: View {
    @Environment(\.colorScheme) private var colorScheme

    private var enabledWidgets: [WidgetConfiguration] {
        WidgetPreferences.shared.enabledWidgets.sorted { $0.position < $1.position }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignTokens.Colors.accent)

                Text("System Overview")
                    .font(DesignTokens.Typography.h3)

                Spacer()

                Text("\(enabledWidgets.count) widgets")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
            .padding()
            .background(DesignTokens.Colors.backgroundSecondary)

            Divider()

            // Scrollable widget list
            ScrollView {
                VStack(spacing: DesignTokens.Spacing.sm) {
                    ForEach(enabledWidgets) { config in
                        OneViewDetailCard(config: config)
                    }
                }
                .padding()
            }
        }
        .background(DesignTokens.Colors.background)
    }
}

// MARK: - One View Detail Card

/// Single widget detail card in the unified popover
struct OneViewDetailCard: View {
    let config: WidgetConfiguration

    private var accentColor: Color {
        config.accentColor.colorValue(for: config.type)
    }

    private var dataManager: WidgetDataManager {
        WidgetDataManager.shared
    }

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            // Icon with background
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: config.type.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(accentColor)
            }

            // Widget info
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
                Text(config.type.displayName)
                    .font(DesignTokens.Typography.bodyEmphasized)
                    .foregroundColor(DesignTokens.Colors.textPrimary)

                Text(widgetDetailText)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }

            Spacer()

            // Main value
            VStack(alignment: .trailing, spacing: DesignTokens.Spacing.xxxs) {
                Text(mainValue)
                    .font(DesignTokens.Typography.h3)
                    .foregroundColor(accentColor)

                Text(secondaryValue)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
        }
        .padding()
        .background(DesignTokens.Colors.backgroundSecondary)
        .cornerRadius(DesignTokens.CornerRadius.medium)
    }

    private var mainValue: String {
        let usePercent = config.valueFormat == .percentage

        switch config.type {
        case .cpu:
            return "\(Int(dataManager.cpuData.totalUsage))%"
        case .memory:
            if usePercent {
                return "\(Int(dataManager.memoryData.usagePercentage))%"
            } else {
                let usedGB = Double(dataManager.memoryData.usedBytes) / (1024 * 1024 * 1024)
                return String(format: "%.1f GB", usedGB)
            }
        case .disk:
            if let primary = dataManager.diskVolumes.first {
                if usePercent {
                    return "\(Int(primary.usagePercentage))%"
                } else {
                    let freeGB = primary.freeBytes / (1024 * 1024 * 1024)
                    return "\(freeGB) GB"
                }
            }
            return "--"
        case .network:
            return dataManager.networkData.downloadString
        case .gpu:
            if let usage = dataManager.gpuData.usagePercentage {
                return "\(Int(usage))%"
            }
            return "--"
        case .battery:
            if dataManager.batteryData.isPresent {
                return "\(Int(dataManager.batteryData.chargePercentage))%"
            }
            return "N/A"
        case .weather:
            return "--°"
        case .sensors:
            if let temp = dataManager.sensorsData.temperatures.first {
                return String(format: "%.1f°", temp.value)
            }
            return "--"

        case .bluetooth:
            if dataManager.bluetoothData.isBluetoothEnabled {
                if let device = dataManager.bluetoothData.devicesWithBattery.first,
                   let battery = device.primaryBatteryLevel {
                    return "\(battery)%"
                }
                return "\(dataManager.bluetoothData.connectedDevices.count)"
            }
            return "Off"

        case .clock:
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            return formatter.string(from: Date())
        }
    }

    private var secondaryValue: String {
        switch config.type {
        case .cpu:
            let activeCores = dataManager.cpuData.perCoreUsage.filter { $0 > 0 }.count
            return "\(activeCores) cores active"
        case .memory:
            let totalGB = Double(dataManager.memoryData.totalBytes) / (1024 * 1024 * 1024)
            return String(format: "%.1f GB total", totalGB)
        case .disk:
            if let primary = dataManager.diskVolumes.first {
                let totalGB = primary.totalBytes / (1024 * 1024 * 1024)
                return "\(totalGB) GB total"
            }
            return "--"
        case .network:
            return "↑ " + dataManager.networkData.uploadString
        case .gpu:
            return dataManager.gpuData.usagePercentage.map { _ in "Integrated" } ?? "Not available"
        case .battery:
            if dataManager.batteryData.isPresent {
                let timeStr: String
                if dataManager.batteryData.isCharging {
                    timeStr = "Charging"
                } else if let minutes = dataManager.batteryData.estimatedMinutesRemaining {
                    let hours = minutes / 60
                    let mins = minutes % 60
                    timeStr = hours > 0 ? "\(hours)h \(mins)m" : "\(mins)m"
                } else {
                    timeStr = "--"
                }
                return timeStr
            }
            return "Not present"
        case .weather:
            return "Current weather"
        case .sensors:
            let count = dataManager.sensorsData.temperatures.count
            return "\(count) sensor\(count == 1 ? "" : "s")"

        case .bluetooth:
            let connected = dataManager.bluetoothData.connectedDevices.count
            return "\(connected) connected"

        case .clock:
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE, MMM d"
            return formatter.string(from: Date())
        }
    }

    private var widgetDetailText: String {
        switch config.type {
        case .cpu:
            return "Processor utilization"
        case .memory:
            return "Memory usage"
        case .disk:
            return "Disk space"
        case .network:
            return "Network activity"
        case .gpu:
            return "Graphics utilization"
        case .battery:
            return "Power status"
        case .weather:
            return "Local conditions"
        case .sensors:
            return "Temperature sensors"
        case .bluetooth:
            return "Bluetooth devices"

        case .clock:
            return "Current time"
        }
    }
}
