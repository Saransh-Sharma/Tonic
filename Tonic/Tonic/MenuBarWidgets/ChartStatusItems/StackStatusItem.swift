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
        // TODO: Implement StackWidgetView with sensor data
        return AnyView(
            Text("Stack")
                .font(.system(size: 11))
                .foregroundColor(configuration.accentColor.colorValue(for: widgetType))
        )
    }

    public override func createDetailView() -> AnyView {
        // TODO: Implement sensor details view
        return AnyView(EmptyView())
    }
}
