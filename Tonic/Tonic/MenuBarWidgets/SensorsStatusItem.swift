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
        return AnyView(SensorsPopoverView())
    }
}
