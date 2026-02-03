//
//  MemoryVisualizationStatusItem.swift
//  Tonic
//
//  Status item for memory visualization (two-row used/total display)
//  Task ID: fn-6-i4g.17
//

import AppKit
import SwiftUI

// MARK: - Memory Visualization Status Item

/// Status item that displays a two-row memory visualization in the menu bar
/// Shows used memory on top row and total memory on bottom row
@MainActor
public final class MemoryVisualizationStatusItem: WidgetStatusItem {

    public override func createCompactView() -> AnyView {
        AnyView(
            MemoryVisualizationView(
                configuration: configuration
            )
        )
    }

    public override func createDetailView() -> AnyView {
        AnyView(MemoryDetailView())
    }
}

// MARK: - Memory Visualization View

/// Two-row memory display for menu bar
/// Top row: Used memory (e.g., "8.2 GB")
/// Bottom row: Total memory (e.g., "16 GB")
/// Order can be toggled via configuration
struct MemoryVisualizationView: View {
    let configuration: WidgetConfiguration
    @State private var dataManager = WidgetDataManager.shared

    /// Whether to show the memory chip icon
    private var showSymbol: Bool {
        configuration.showLabel
    }

    /// The accent color for the widget
    private var accentColor: Color {
        let percentage = dataManager.memoryData.usagePercentage
        if configuration.accentColor == .utilization {
            return configuration.accentColor.colorValue(forUtilization: percentage)
        } else if configuration.accentColor == .pressure {
            let pressure = mapMemoryPressureToLevel(dataManager.memoryData.pressure)
            return configuration.accentColor.colorValue(forPressure: pressure)
        }
        return configuration.accentColor.colorValue(for: .memory)
    }

    /// Map MemoryPressure to MemoryPressureLevel for color calculation
    private func mapMemoryPressureToLevel(_ pressure: MemoryPressure) -> MemoryPressureLevel {
        switch pressure {
        case .normal: return .nominal
        case .warning: return .warning
        case .critical: return .critical
        }
    }

    var body: some View {
        HStack(spacing: 3) {
            // Optional memory icon
            if showSymbol {
                Image(systemName: "memorychip")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(accentColor)
            }

            // Two-row memory display
            VStack(alignment: .trailing, spacing: 0) {
                // Top row: Used memory
                Text(usedMemoryString)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(.primary)

                // Bottom row: Total memory
                Text(totalMemoryString)
                    .font(.system(size: 8, weight: .regular, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 4)
        .frame(height: 22)
    }

    /// Format used memory as a string (e.g., "8.2 GB")
    private var usedMemoryString: String {
        let usedBytes = dataManager.memoryData.usedBytes
        return formatBytes(usedBytes)
    }

    /// Format total memory as a string (e.g., "16 GB")
    private var totalMemoryString: String {
        let totalBytes = dataManager.memoryData.totalBytes
        return formatBytes(totalBytes)
    }

    /// Format bytes to a human-readable string
    private func formatBytes(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / (1024 * 1024 * 1024)
        if gb >= 10 {
            return String(format: "%.0f GB", gb)
        } else {
            return String(format: "%.1f GB", gb)
        }
    }
}

// MARK: - Preview

#Preview("Memory Visualization") {
    MemoryVisualizationView(
        configuration: WidgetConfiguration.default(for: .memory, at: 0)
    )
    .frame(width: 60, height: 22)
    .background(Color(nsColor: .windowBackgroundColor))
}
