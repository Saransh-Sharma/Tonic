//
//  ChartScale.swift
//  Tonic
//
//  Resolves the vertical scale for popover console charts from the persisted
//  popup settings, so the Scaling preference actually drives rendering.
//

import SwiftUI

/// Maps the popup `ScalingMode` to an explicit chart ceiling.
///
/// Percent-based series (CPU, memory, GPU, battery) can pin to 0–100 (`.none`)
/// or a user-chosen ceiling (`.fixed`). Rate and temperature series have no
/// meaningful fixed ceiling and always auto-scale regardless of the setting.
public enum ChartScale {
    /// The maximum value the chart should normalize against, or `nil` to
    /// auto-scale to the data's own range.
    public static func resolvedMax(
        mode: PopupSettings.ScalingMode,
        fixedValue: Double,
        isPercentSeries: Bool
    ) -> Double? {
        guard isPercentSeries else { return nil }
        switch mode {
        case .auto: return nil
        case .none: return 100
        case .fixed: return max(10, min(200, fixedValue))
        }
    }
}

public extension WidgetType {
    /// Whether this module's popover history series is a 0–100 percentage,
    /// making fixed/pinned scaling meaningful.
    var hasPercentHistory: Bool {
        switch self {
        case .cpu, .memory, .gpu, .battery: return true
        case .disk, .network, .sensors, .bluetooth, .clock, .weather, .tonic: return false
        }
    }
}

public extension PopupSettings {
    /// Effective console width in points (already clamped on init/decode).
    var resolvedPopoverWidth: CGFloat { CGFloat(popoverWidth) }

    /// The chart ceiling for a widget's history series under these settings.
    func chartFixedMax(for widgetType: WidgetType) -> Double? {
        ChartScale.resolvedMax(mode: scalingMode,
                               fixedValue: fixedScaleValue,
                               isPercentSeries: widgetType.hasPercentHistory)
    }
}
