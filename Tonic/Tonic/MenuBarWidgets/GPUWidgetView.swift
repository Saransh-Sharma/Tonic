//
//  GPUWidgetView.swift
//  Tonic
//
//  GPU monitoring widget views
//  Task ID: fn-2.5
//  Updated: fn-6-i4g.18 - Standardized popover layout
//

import SwiftUI
import Charts

// MARK: - GPU Compact View

/// Compact menu bar view for GPU widget
public struct GPUCompactView: View {

    @State private var dataManager = WidgetDataManager.shared

    public init() {}

    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "video.bubble.left.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.blue)

            if let usage = dataManager.gpuData.usagePercentage {
                Text("\(Int(usage))%")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.primary)
            } else {
                Text("--")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 4)
        .frame(height: 22)
    }
}

// MARK: - GPU Detail View

/// Detailed popover view for GPU widget
/// Uses standardized PopoverTemplate for consistent layout
public struct GPUDetailView: View {

    @State private var dataManager = WidgetDataManager.shared

    public init() {}

    public var body: some View {
        PopoverTemplate(
            icon: PopoverConstants.Icons.gpu,
            title: PopoverConstants.Names.gpu,
            headerValue: dataManager.gpuData.usagePercentage.map { "\(Int($0))%" },
            headerColor: .blue
        ) {
            if isGPUSupported {
                // GPU usage
                gpuUsageSection

                // Memory usage
                if let memoryPercentage = dataManager.gpuData.memoryUsagePercentage {
                    gpuMemorySection(memoryPercentage)
                }

                // Temperature
                if let temperature = dataManager.gpuData.temperature {
                    gpuTemperatureSection(temperature)
                }
            } else {
                // Unsupported message
                unsupportedSection
            }
        }
    }

    private var isGPUSupported: Bool {
        #if arch(arm64)
        return true
        #else
        return dataManager.gpuData.usagePercentage != nil
        #endif
    }

    private var gpuUsageSection: some View {
        TitledPopoverSection(title: "GPU Usage") {
            if let usage = dataManager.gpuData.usagePercentage {
                VStack(alignment: .leading, spacing: PopoverConstants.itemSpacing) {
                    HStack(alignment: .lastTextBaseline, spacing: DesignTokens.Spacing.sm) {
                        Text("\(Int(usage))%")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.blue)

                        Text("utilization")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Usage bar
                    UsageBar(percentage: usage, color: .blue)

                    // Info note
                    #if arch(arm64)
                    Text("Apple Silicon integrated GPU")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    #endif
                }
            }
        }
    }

    private func gpuMemorySection(_ percentage: Double) -> some View {
        TitledPopoverSection(title: "GPU Memory") {
            HStack(spacing: DesignTokens.Spacing.sm) {
                if let used = dataManager.gpuData.usedMemory,
                   let total = dataManager.gpuData.totalMemory {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(Int(percentage))%")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.purple)

                        Text("used")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(formatBytes(used))
                            .font(.caption)
                            .fontWeight(.medium)

                        Text("of \(formatBytes(total))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("Unified Memory")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Spacer()
                }
            }

            // Memory bar
            if let used = dataManager.gpuData.usedMemory,
               let total = dataManager.gpuData.totalMemory {
                UsageBar(percentage: percentage, color: .purple)
            }
        }
    }

    private func gpuTemperatureSection(_ temperature: Double) -> some View {
        PopoverSection {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "thermometer")
                    .font(.title2)
                    .foregroundColor(temperatureColor(temperature))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Temperature")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text("\(Int(temperature))°C")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(temperatureText(temperature))
                    .font(.caption)
                    .foregroundColor(temperatureColor(temperature))
            }
        }
    }

    private var unsupportedSection: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: "info.circle")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text("GPU Monitoring Not Available")
                .font(.subheadline)
                .fontWeight(.semibold)

            Text("GPU monitoring requires Apple Silicon Mac or supported discrete GPU.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private func temperatureColor(_ temp: Double) -> Color {
        switch temp {
        case 0..<60: return TonicColors.success
        case 60..<75: return TonicColors.warning
        default: return TonicColors.error
        }
    }

    private func temperatureText(_ temp: Double) -> String {
        switch temp {
        case 0..<60: return "Normal"
        case 60..<75: return "Warm"
        default: return "Hot"
        }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory)
    }
}

// MARK: - GPU Status Item

/// Manages the GPU widget's NSStatusItem
@MainActor
public final class GPUStatusItem: WidgetStatusItem {

    public override init(widgetType: WidgetType = .gpu, configuration: WidgetConfiguration) {
        super.init(widgetType: widgetType, configuration: configuration)

        // Auto-hide on Intel Macs if GPU data unavailable
        #if !arch(arm64)
        if WidgetDataManager.shared.gpuData.usagePercentage == nil {
            hide()
        }
        #endif
    }

    // Uses base WidgetStatusItem.createCompactView() which respects configuration

    public override func createDetailView() -> AnyView {
        AnyView(GPUDetailView())
    }
}

// MARK: - Preview

#Preview("GPU Detail") {
    GPUDetailView()
}
