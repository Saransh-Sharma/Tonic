//
//  StackStatusItem.swift
//  Tonic
//
//  Status item for stacked sensor readings visualization
//

import AppKit
import SwiftUI

/// Status item that displays stacked sensor readings in the menu bar
@MainActor
public final class StackStatusItem: WidgetStatusItem {

    public override func createCompactView() -> AnyView {
        let dataManager = WidgetDataManager.shared

        switch widgetType {
        case .bluetooth:
            return AnyView(
                BluetoothStackView(
                    data: dataManager.bluetoothData,
                    configuration: configuration
                )
            )

        case .sensors:
            // Sensors stack view showing temperatures
            return AnyView(
                SensorsStackView(
                    data: dataManager.sensorsData,
                    configuration: configuration
                )
            )

        case .clock:
            return AnyView(
                ClockStackView(configuration: configuration)
            )

        default:
            return AnyView(
                Text("Stack")
                    .font(.system(size: 11))
                    .foregroundColor(configuration.accentColor.colorValue(for: widgetType))
            )
        }
    }

    public override func createDetailView() -> AnyView {
        switch widgetType {
        case .bluetooth:
            return AnyView(BluetoothDetailView())
        case .sensors:
            return AnyView(SensorsDetailView())
        case .clock:
            return AnyView(ClockDetailView())
        default:
            return AnyView(EmptyView())
        }
    }
}

// MARK: - Sensors Stack View

/// Stack visualization showing multiple sensor temperatures
struct SensorsStackView: View {
    let data: SensorsData
    let configuration: WidgetConfiguration

    var body: some View {
        HStack(spacing: 6) {
            if data.temperatures.isEmpty {
                Image(systemName: "thermometer")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            } else {
                ForEach(data.temperatures.prefix(3), id: \.id) { sensor in
                    VStack(spacing: 2) {
                        Text(sensorLabel(sensor.name))
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)

                        Text("\(Int(sensor.value))°")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(temperatureColor(sensor.value))
                    }
                }
            }
        }
        .padding(.horizontal, 4)
        .frame(height: 22)
    }

    private func sensorLabel(_ name: String) -> String {
        // Shorten sensor names for compact display
        if name.lowercased().contains("cpu") { return "CPU" }
        if name.lowercased().contains("gpu") { return "GPU" }
        if name.lowercased().contains("ssd") { return "SSD" }
        if name.lowercased().contains("mem") { return "RAM" }
        return String(name.prefix(3))
    }

    private func temperatureColor(_ value: Double) -> Color {
        if value >= 85 {
            return .red
        } else if value >= 70 {
            return .orange
        } else if value >= 50 {
            return .yellow
        } else {
            return configuration.accentColor.colorValue(for: .sensors)
        }
    }
}
