//
//  BatteryDetailsStatusItem.swift
//  Tonic
//
//  Status item for extended battery information
//

import AppKit
import SwiftUI

/// Status item that displays detailed battery information in the menu bar
@MainActor
public final class BatteryDetailsStatusItem: WidgetStatusItem {

    public override func createCompactView() -> AnyView {
        let dataManager = WidgetDataManager.shared
        let battery = dataManager.batteryData

        return AnyView(
            BatteryDetailsWidgetView(
                batteryData: battery,
                config: BatteryDetailsConfig(
                    showPercentage: true,
                    showTimeRemaining: true,
                    showHealth: false,
                    showCycleCount: false,
                    showPowerSource: true,
                    displayMode: .compact
                )
            )
        )
    }

    public override func createDetailView() -> AnyView {
        // Use Stats Master-style BatteryPopoverView
        return AnyView(BatteryPopoverView())
    }
}
