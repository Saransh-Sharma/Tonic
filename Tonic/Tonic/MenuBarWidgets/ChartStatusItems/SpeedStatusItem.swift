//
//  SpeedStatusItem.swift
//  Tonic
//
//  Status item for network speed visualization
//

import AppKit
import SwiftUI

/// Status item that displays network up/down speeds in the menu bar
@MainActor
public final class SpeedStatusItem: WidgetStatusItem {

    public override func createCompactView() -> AnyView {
        let dataManager = WidgetDataManager.shared
        let config = SpeedWidgetConfig(
            displayMode: configuration.displayMode == .detailed ? .oneRow : .twoRows,
            iconMode: .arrows,
            showUnits: true,
            showIcon: true
        )
        return AnyView(
            SpeedWidgetView(
                networkData: dataManager.networkData,
                config: config
            )
        )
    }

    public override func createDetailView() -> AnyView {
        // Use SwiftUI NetworkPopoverView
        return AnyView(NetworkPopoverView())
    }
}
