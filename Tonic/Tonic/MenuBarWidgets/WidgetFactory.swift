//
//  WidgetFactory.swift
//  Tonic
//
//  Factory for creating widget status items based on data source and visualization type
//

import AppKit
import SwiftUI

/// Factory for creating widget status items
/// Bridges data sources (WidgetType) with visualizations (VisualizationType)
@MainActor
public final class WidgetFactory {

    /// Creates the appropriate status item for the given widget type and visualization
    /// - Parameters:
    ///   - type: The data source type (cpu, memory, etc.)
    ///   - visualization: The visualization type (mini, lineChart, etc.)
    ///   - configuration: The widget configuration
    /// - Returns: A configured WidgetStatusItem subclass
    public static func createWidget(
        for type: WidgetType,
        visualization: VisualizationType,
        configuration: WidgetConfiguration
    ) -> WidgetStatusItem {

        // Validate that the visualization is compatible with the data source
        guard type.compatibleVisualizations.contains(visualization) else {
            // Fall back to default visualization for this type
            return createWidget(
                for: type,
                visualization: type.defaultVisualization,
                configuration: configuration
            )
        }

        switch visualization {
        case .mini:
            return createMiniWidget(type: type, configuration: configuration)

        case .lineChart:
            return LineChartStatusItem(widgetType: type, configuration: configuration)

        case .barChart:
            return BarChartStatusItem(widgetType: type, configuration: configuration)

        case .pieChart:
            return PieChartStatusItem(widgetType: type, configuration: configuration)

        case .tachometer:
            return TachometerStatusItem(widgetType: type, configuration: configuration)

        case .stack:
            return StackStatusItem(widgetType: type, configuration: configuration)

        case .speed:
            return SpeedStatusItem(widgetType: type, configuration: configuration)

        case .networkChart:
            return NetworkChartStatusItem(widgetType: type, configuration: configuration)

        case .batteryDetails:
            return BatteryDetailsStatusItem(widgetType: type, configuration: configuration)

        case .label, .state, .text:
            return LabelStatusItem(widgetType: type, configuration: configuration)
        }
    }

    /// Creates a mini widget (the original widget type)
    /// This preserves backward compatibility with the existing widget system
    private static func createMiniWidget(
        type: WidgetType,
        configuration: WidgetConfiguration
    ) -> WidgetStatusItem {
        // Use the base WidgetStatusItem for all widget types
        // The base class handles different types through its widgetType property
        // Special handling for sensors which has custom views
        if type == .sensors {
            return SensorsStatusItem(widgetType: type, configuration: configuration)
        }
        return WidgetStatusItem(widgetType: type, configuration: configuration)
    }

    /// Get the estimated width for a widget with the given visualization
    public static func estimatedWidth(
        for type: WidgetType,
        visualization: VisualizationType,
        displayMode: WidgetDisplayMode
    ) -> CGFloat {
        // Base width from visualization
        var width = visualization.estimatedWidth

        // Add sparkline width for detailed mode on mini widgets
        if visualization == .mini && displayMode == .detailed {
            width += 40 // Sparkline width
        }

        return width
    }
}
