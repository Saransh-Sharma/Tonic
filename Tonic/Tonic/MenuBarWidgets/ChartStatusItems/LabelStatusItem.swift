//
//  LabelStatusItem.swift
//  Tonic
//
//  Status item for label/state/text visualizations
//

import AppKit
import SwiftUI

/// Status item that displays custom labels or text in the menu bar
@MainActor
public final class LabelStatusItem: WidgetStatusItem {

    public override func createCompactView() -> AnyView {
        let dataManager = WidgetDataManager.shared

        // Handle state visualization for Bluetooth
        if widgetType == .bluetooth && configuration.visualizationType == .state {
            return AnyView(
                BluetoothStateView(
                    data: dataManager.bluetoothData,
                    configuration: configuration
                )
            )
        }

        // Handle text visualization for Clock
        if widgetType == .clock && configuration.visualizationType == .text {
            return AnyView(
                ClockTextView(configuration: configuration)
            )
        }

        // Handle label visualization for Clock
        if widgetType == .clock && configuration.visualizationType == .label {
            return AnyView(
                ClockLabelView(configuration: configuration)
            )
        }

        // Default label display
        return AnyView(
            Text(widgetType.displayName)
                .font(.system(size: 11))
                .foregroundColor(configuration.accentColor.colorValue(for: widgetType))
        )
    }

    public override func createDetailView() -> AnyView {
        switch widgetType {
        case .bluetooth:
            return AnyView(BluetoothDetailView())
        case .clock:
            return AnyView(ClockDetailView())
        default:
            return AnyView(EmptyView())
        }
    }
}
