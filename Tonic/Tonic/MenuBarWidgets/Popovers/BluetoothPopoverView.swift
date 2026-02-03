//
//  BluetoothPopoverView.swift
//  Tonic
//
//  Stats Master-style Bluetooth popover with devices, battery, and signal
//  Task ID: fn-6-i4g.40
//

import SwiftUI

// MARK: - Bluetooth Popover View

/// Complete Stats Master-style Bluetooth popover with:
/// - Connection status and history chart
/// - Device list with battery levels
/// - Signal strength indicators
public struct BluetoothPopoverView: View {

    // MARK: - Properties

    @State private var dataManager = WidgetDataManager.shared

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            ScrollView {
                VStack(spacing: PopoverConstants.sectionSpacing) {
                    // Status Section
                    statusSection

                    Divider()

                    // Connection History Chart
                    historyChartSection

                    Divider()

                    // Connected Devices
                    devicesSection
                }
                .padding(PopoverConstants.horizontalPadding)
                .padding(.vertical, PopoverConstants.verticalPadding)
            }
        }
        .frame(width: PopoverConstants.width, height: PopoverConstants.maxHeight)
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(PopoverConstants.cornerRadius)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: PopoverConstants.iconTextGap) {
            // Icon
            Image(systemName: PopoverConstants.Icons.bluetooth)
                .font(.title2)
                .foregroundColor(statusColor)

            // Title
            Text("Bluetooth")
                .font(PopoverConstants.headerTitleFont)
                .foregroundColor(DesignTokens.Colors.textPrimary)

            Spacer()

            // Status indicator
            IndicatorDot(color: statusColor)

            Text(statusText)
                .font(.system(size: 11))
                .foregroundColor(DesignTokens.Colors.textSecondary)

            // Settings button
            Button {
                // TODO: Open settings to Bluetooth widget configuration
            } label: {
                Image(systemName: PopoverConstants.Icons.settings)
                    .font(.body)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Status Section

    private var statusSection: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            // Connection count metric
            VStack(spacing: PopoverConstants.compactSpacing) {
                Text("\(dataManager.bluetoothData.connectedDevices.count)")
                    .font(PopoverConstants.largeMetricFont)
                    .foregroundColor(statusColor)

                Text("Connected")
                    .font(.caption)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)

            // Devices with battery metric
            let devicesWithBattery = dataManager.bluetoothData.devicesWithBattery.count
            VStack(spacing: PopoverConstants.compactSpacing) {
                Text("\(devicesWithBattery)")
                    .font(PopoverConstants.largeMetricFont)
                    .foregroundColor(DesignTokens.Colors.accent)

                Text("With Battery")
                    .font(.caption)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - History Chart Section

    private var historyChartSection: some View {
        VStack(alignment: .leading, spacing: PopoverConstants.itemSpacing) {
            PopoverSectionHeader(title: "Connection History")

            NetworkSparklineChart(
                data: dataManager.bluetoothHistory,
                color: DesignTokens.Colors.accent,
                height: 60,
                showArea: true,
                lineWidth: 1.5
            )
        }
    }

    // MARK: - Devices Section

    private var devicesSection: some View {
        VStack(alignment: .leading, spacing: PopoverConstants.itemSpacing) {
            PopoverSectionHeader(title: "Devices")

            if dataManager.bluetoothData.connectedDevices.isEmpty {
                emptyDevicesView
            } else {
                VStack(spacing: 6) {
                    ForEach(dataManager.bluetoothData.connectedDevices) { device in
                        deviceCard(device: device)
                    }
                }
            }
        }
    }

    private var emptyDevicesView: some View {
        EmptyStateView(
            icon: "bluetooth.slash",
            title: emptyStateText
        )
    }

    private func deviceCard(device: BluetoothDevice) -> some View {
        HStack(spacing: PopoverConstants.itemSpacing) {
            // Device icon
            Image(systemName: device.deviceType.icon)
                .font(.system(size: 18))
                .foregroundColor(DesignTokens.Colors.accent)
                .frame(width: 28)

            // Device info
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                    .lineLimit(1)

                Text(device.deviceType.displayName)
                    .font(.caption2)
                    .foregroundColor(DesignTokens.Colors.textSecondary)

                // Multi-battery display for devices like AirPods
                if device.batteryLevels.count > 1 {
                    HStack(spacing: 8) {
                        ForEach(device.batteryLevels) { level in
                            miniBatteryIndicator(level: level)
                        }
                    }
                }
            }

            Spacer()

            // Single battery indicator for devices with only one battery
            if device.batteryLevels.count == 1, let level = device.batteryLevels.first {
                batteryIndicator(percentage: level.percentage)
            }

            // Signal strength
            if let signal = device.signalStrength {
                signalIndicator(rssi: signal)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(PopoverConstants.innerCornerRadius)
    }

    /// Mini battery indicator for multi-battery device components
    private func miniBatteryIndicator(level: BluetoothDevice.DeviceBatteryLevel) -> some View {
        HStack(spacing: 2) {
            Image(systemName: level.icon)
                .font(.system(size: 8))
                .foregroundColor(batteryColor(level.percentage))

            Text(level.label)
                .font(.system(size: 8))
                .foregroundColor(DesignTokens.Colors.textSecondary)

            Text("\(level.percentage)%")
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundColor(batteryColor(level.percentage))
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(4)
    }

    private func batteryIndicator(percentage: Int) -> some View {
        HStack(spacing: PopoverConstants.iconTextGap) {
            Image(systemName: batteryIcon(percentage))
                .font(.system(size: 10))
                .foregroundColor(batteryColor(percentage))

            Text("\(percentage)%")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(batteryColor(percentage))
        }
    }

    private func batteryIcon(_ percentage: Int) -> String {
        if percentage <= 10 {
            return "battery.0"
        } else if percentage <= 25 {
            return "battery.25"
        } else if percentage <= 50 {
            return "battery.50"
        } else if percentage <= 75 {
            return "battery.75"
        } else {
            return "battery.100"
        }
    }

    private func batteryColor(_ percentage: Int) -> Color {
        if percentage <= 10 {
            return .red
        } else if percentage <= 20 {
            return .orange
        } else if percentage <= 50 {
            return .yellow
        } else {
            return .green
        }
    }

    private func signalIndicator(rssi: Int) -> some View {
        // Convert RSSI to signal bars (typical range -30 to -90 dBm)
        let bars: Int
        if rssi >= -50 {
            bars = 4
        } else if rssi >= -60 {
            bars = 3
        } else if rssi >= -70 {
            bars = 2
        } else {
            bars = 1
        }

        return HStack(spacing: 1) {
            ForEach(0..<4, id: \.self) { index in
                Rectangle()
                    .fill(index < bars ? Color.blue : Color.secondary.opacity(0.3))
                    .frame(width: 3, height: CGFloat(4 + index * 2))
            }
        }
    }

    // MARK: - Computed Properties

    private var statusColor: Color {
        if !dataManager.bluetoothData.isBluetoothEnabled {
            return .red
        } else if dataManager.bluetoothData.connectedDevices.isEmpty {
            return .orange
        } else {
            return DesignTokens.Colors.accent
        }
    }

    private var statusText: String {
        if !dataManager.bluetoothData.isBluetoothEnabled {
            return "Off"
        } else if dataManager.bluetoothData.connectedDevices.isEmpty {
            return "No Devices"
        } else {
            return "On"
        }
    }

    private var emptyStateText: String {
        if !dataManager.bluetoothData.isBluetoothEnabled {
            return "Bluetooth is disabled"
        } else {
            return "No connected devices"
        }
    }
}

// MARK: - Bluetooth Device Type Extension

extension BluetoothDeviceType {
    var displayName: String {
        switch self {
        case .headphones: return "Headphones"
        case .speaker: return "Speaker"
        case .keyboard: return "Keyboard"
        case .mouse: return "Mouse"
        case .trackpad: return "Trackpad"
        case .gameController: return "Game Controller"
        case .watch: return "Watch"
        case .phone: return "Phone"
        case .tablet: return "Tablet"
        case .unknown: return "Bluetooth Device"
        }
    }
}

// MARK: - Preview

#Preview("Bluetooth Popover") {
    BluetoothPopoverView()
}
