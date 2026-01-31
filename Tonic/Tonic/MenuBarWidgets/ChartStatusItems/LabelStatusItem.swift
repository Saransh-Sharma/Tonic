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
        // TODO: Implement LabelWidgetView with configurable text
        return AnyView(
            Text(widgetType.displayName)
                .font(.system(size: 11))
                .foregroundColor(configuration.accentColor.colorValue(for: widgetType))
        )
    }

    public override func createDetailView() -> AnyView {
        // TODO: Implement text/label configuration view
        return AnyView(EmptyView())
    }
}
