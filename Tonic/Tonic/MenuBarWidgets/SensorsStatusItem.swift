//
//  SensorsStatusItem.swift
//  Tonic
//
//  Status item for sensors data source
//

import AppKit
import SwiftUI

/// Status item for displaying sensor data (temperatures, fan speeds)
@MainActor
public final class SensorsStatusItem: WidgetStatusItem {

    public override func createCompactView() -> AnyView {
        let dataManager = WidgetDataManager.shared
        let sensorsData = dataManager.sensorsData

        // Default mini view shows first temperature
        if let firstTemp = sensorsData.temperatures.first {
            return AnyView(
                HStack(spacing: 4) {
                    Image(systemName: widgetType.icon)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(configuration.accentColor.colorValue(for: widgetType))

                    Text("\(Int(firstTemp.value))°C")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.primary)

                    if configuration.showLabel {
                        Text(firstTemp.name)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 4)
                .frame(height: 22)
            )
        } else {
            return AnyView(
                HStack(spacing: 4) {
                    Image(systemName: widgetType.icon)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(configuration.accentColor.colorValue(for: widgetType))

                    Text("--°C")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 4)
                .frame(height: 22)
            )
        }
    }

    public override func createDetailView() -> AnyView {
        return AnyView(SensorsDetailView())
    }
}

// MARK: - Sensors Detail View

/// Detail view for sensors showing all temperatures and fan speeds
struct SensorsDetailView: View {
    @State private var dataManager = WidgetDataManager.shared

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "thermometer")
                    .font(.title2)
                    .foregroundColor(TonicColors.accent)

                Text("Sensors")
                    .font(.headline)

                Spacer()
            }
            .padding()

            // Temperature section
            if !dataManager.sensorsData.temperatures.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Temperatures")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)

                    ForEach(dataManager.sensorsData.temperatures.prefix(10), id: \.id) { sensor in
                        sensorRow(name: sensor.name, value: "\(Int(sensor.value))°C", color: temperatureColor(sensor.value))
                    }
                }
            }

            // Fan section
            if !dataManager.sensorsData.fans.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Fans")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)

                    ForEach(dataManager.sensorsData.fans.prefix(5), id: \.id) { fan in
                        sensorRow(name: fan.name, value: "\(fan.rpm) RPM", color: .blue)
                    }
                }
            }

            if dataManager.sensorsData.temperatures.isEmpty && dataManager.sensorsData.fans.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "sensor")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No sensor data available")
                        .foregroundColor(.secondary)
                }
                .padding()
            }

            Spacer()
        }
        .frame(width: 300, height: 200)
        .padding()
    }

    private func sensorRow(name: String, value: String, color: Color) -> some View {
        HStack {
            Text(name)
                .font(.system(.body, design: .monospaced))
                .lineLimit(1)

            Spacer()

            Text(value)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(color)
        }
        .padding(.horizontal)
    }

    private func temperatureColor(_ value: Double) -> Color {
        if value >= 85 {
            return .red
        } else if value >= 70 {
            return .orange
        } else if value >= 50 {
            return .yellow
        } else {
            return .green
        }
    }
}
