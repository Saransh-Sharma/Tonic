//
//  BluetoothStatusItem.swift
//  Tonic
//
//  Status item for Bluetooth data source
//  Task ID: fn-6-i4g.15
//

import AppKit
import SwiftUI

/// Status item for displaying Bluetooth device data
@MainActor
public final class BluetoothStatusItem: WidgetStatusItem {

    public override func createCompactView() -> AnyView {
        let dataManager = WidgetDataManager.shared
        let bluetoothData = dataManager.bluetoothData

        // Show Bluetooth state or first device with battery
        if !bluetoothData.isBluetoothEnabled {
            return AnyView(
                HStack(spacing: 4) {
                    Image(systemName: "bluetooth.slash")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)

                    Text("Off")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 4)
                .frame(height: 22)
            )
        }

        // Show first device with battery or connected count
        if let device = bluetoothData.devicesWithBattery.first,
           let battery = device.primaryBatteryLevel {
            return AnyView(
                HStack(spacing: 4) {
                    Image(systemName: device.deviceType.icon)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(configuration.accentColor.colorValue(for: widgetType))

                    Text("\(battery)%")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.primary)

                    if configuration.showLabel {
                        Text(device.name)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 4)
                .frame(height: 22)
            )
        } else {
            let connectedCount = bluetoothData.connectedDevices.count
            return AnyView(
                HStack(spacing: 4) {
                    Image(systemName: "bluetooth")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(configuration.accentColor.colorValue(for: widgetType))

                    Text("\(connectedCount)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.primary)

                    if configuration.showLabel {
                        Text("devices")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 4)
                .frame(height: 22)
            )
        }
    }

    public override func createDetailView() -> AnyView {
        return AnyView(BluetoothDetailView())
    }
}

// MARK: - Bluetooth Detail View

/// Detail view for Bluetooth showing all devices and their status
struct BluetoothDetailView: View {
    @State private var dataManager = WidgetDataManager.shared

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "bluetooth")
                    .font(.title2)
                    .foregroundColor(TonicColors.accent)

                Text("Bluetooth")
                    .font(.headline)

                Spacer()

                // Bluetooth status indicator
                Circle()
                    .fill(dataManager.bluetoothData.isBluetoothEnabled ? Color.green : Color.red)
                    .frame(width: 8, height: 8)

                Text(dataManager.bluetoothData.isBluetoothEnabled ? "On" : "Off")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()

            if !dataManager.bluetoothData.isBluetoothEnabled {
                VStack(spacing: 8) {
                    Image(systemName: "bluetooth.slash")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("Bluetooth is disabled")
                        .foregroundColor(.secondary)
                }
                .padding()
            } else if dataManager.bluetoothData.devices.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "bluetooth")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No paired devices")
                        .foregroundColor(.secondary)
                }
                .padding()
            } else {
                // Connected devices section
                let connected = dataManager.bluetoothData.connectedDevices
                if !connected.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Connected")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)

                        ForEach(connected) { device in
                            deviceRow(device: device)
                        }
                    }
                }

                // Paired but not connected devices
                let paired = dataManager.bluetoothData.devices.filter { $0.isPaired && !$0.isConnected }
                if !paired.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Paired")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .padding(.top, 8)

                        ForEach(paired.prefix(5)) { device in
                            deviceRow(device: device)
                        }
                    }
                }
            }

            Spacer()
        }
        .frame(width: 300, height: 250)
        .padding()
    }

    private func deviceRow(device: BluetoothDevice) -> some View {
        HStack(spacing: 12) {
            // Device icon
            Image(systemName: device.deviceType.icon)
                .font(.system(size: 16))
                .foregroundColor(device.isConnected ? TonicColors.accent : .secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.system(.body))
                    .lineLimit(1)

                if !device.batteryLevels.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(device.batteryLevels) { battery in
                            HStack(spacing: 2) {
                                Text(battery.label)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("\(battery.percentage)%")
                                    .font(.caption)
                                    .foregroundColor(batteryColor(battery.percentage))
                            }
                        }
                    }
                }
            }

            Spacer()

            // Connection status
            if device.isConnected {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
            }

            // RSSI indicator if available
            if let rssi = device.rssi {
                signalStrengthView(rssi: rssi)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }

    private func signalStrengthView(rssi: Int) -> some View {
        // Convert RSSI to signal bars (typical range -30 to -90 dBm)
        let bars: Int
        if rssi >= -50 {
            bars = 3
        } else if rssi >= -70 {
            bars = 2
        } else {
            bars = 1
        }

        return HStack(spacing: 1) {
            ForEach(0..<3, id: \.self) { index in
                Rectangle()
                    .fill(index < bars ? Color.primary : Color.secondary.opacity(0.3))
                    .frame(width: 3, height: CGFloat(4 + index * 3))
            }
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
}

// MARK: - Bluetooth Stack View for Stack Visualization

/// Stack visualization showing multiple Bluetooth device batteries
struct BluetoothStackView: View {
    let data: BluetoothData
    let configuration: WidgetConfiguration

    var body: some View {
        HStack(spacing: 6) {
            if !data.isBluetoothEnabled {
                Image(systemName: "bluetooth.slash")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            } else if data.devicesWithBattery.isEmpty {
                Image(systemName: "bluetooth")
                    .font(.system(size: 12))
                    .foregroundColor(configuration.accentColor.colorValue(for: .bluetooth))
            } else {
                ForEach(data.devicesWithBattery.prefix(3)) { device in
                    if let battery = device.primaryBatteryLevel {
                        VStack(spacing: 2) {
                            Image(systemName: device.deviceType.icon)
                                .font(.system(size: 10))
                                .foregroundColor(batteryColor(battery))

                            Text("\(battery)%")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 4)
        .frame(height: 22)
    }

    private func batteryColor(_ percentage: Int) -> Color {
        if percentage <= 10 {
            return .red
        } else if percentage <= 20 {
            return .orange
        } else {
            return configuration.accentColor.colorValue(for: .bluetooth)
        }
    }
}

// MARK: - Bluetooth State View for State Visualization

/// State visualization showing simple connected/disconnected indicator
struct BluetoothStateView: View {
    let data: BluetoothData
    let configuration: WidgetConfiguration

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(stateColor)
                .frame(width: 8, height: 8)

            if configuration.showLabel {
                Text(stateText)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 4)
        .frame(height: 22)
    }

    private var stateColor: Color {
        if !data.isBluetoothEnabled {
            return .red
        } else if data.connectedDevices.isEmpty {
            return .orange
        } else {
            return .green
        }
    }

    private var stateText: String {
        if !data.isBluetoothEnabled {
            return "Off"
        } else if data.connectedDevices.isEmpty {
            return "No devices"
        } else {
            return "\(data.connectedDevices.count) connected"
        }
    }
}
