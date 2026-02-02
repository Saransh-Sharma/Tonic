//
//  PerGpuContainer.swift
//  Tonic
//
//  Per-GPU container with 4 gauges and 4 charts for Stats Master parity
//  Task ID: fn-8-v3b.6
//

import SwiftUI

// MARK: - Per GPU Container

/// Container view for a single GPU with gauges, charts, and expandable details
/// Matches Stats Master's multi-GPU architecture
///
/// Features:
/// - Title bar with model name, status indicator, and DETAILS toggle
/// - 4 half-circle gauges: Temperature, Utilization, Render, Tiler
/// - 4 mini line charts showing history for each metric
/// - Expandable details panel with vendor, cores, clock speeds, fan speed
public struct PerGpuContainer: View {

    // MARK: - Properties

    let gpuData: GPUData
    let temperatureHistory: [Double]
    let utilizationHistory: [Double]
    let renderHistory: [Double]
    let tilerHistory: [Double]

    @State private var isDetailsExpanded: Bool = false

    // MARK: - Constants

    private static let titleBarHeight: CGFloat = 24
    private static let gaugesRowHeight: CGFloat = 50
    private static let chartsRowHeight: CGFloat = 60

    // MARK: - Initializer

    public init(
        gpuData: GPUData,
        temperatureHistory: [Double] = [],
        utilizationHistory: [Double] = [],
        renderHistory: [Double] = [],
        tilerHistory: [Double] = []
    ) {
        self.gpuData = gpuData
        self.temperatureHistory = temperatureHistory
        self.utilizationHistory = utilizationHistory
        self.renderHistory = renderHistory
        self.tilerHistory = tilerHistory
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: PopoverConstants.itemSpacing) {
            // Title bar
            titleBar

            // Gauges row
            gaugesRow

            // Charts row
            chartsRow

            // Details panel (expandable)
            if isDetailsExpanded {
                detailsPanel
            }
        }
        .padding(PopoverConstants.horizontalPadding)
        .padding(.vertical, PopoverConstants.verticalPadding)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(PopoverConstants.innerCornerRadius)
    }

    // MARK: - Title Bar

    private var titleBar: some View {
        HStack(spacing: PopoverConstants.itemSpacing) {
            // Status indicator
            statusIndicator

            // GPU model name
            Text(gpuModelName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(DesignTokens.Colors.textPrimary)

            Spacer()

            // Details toggle button
            Button {
                withAnimation(PopoverConstants.fastAnimation) {
                    isDetailsExpanded.toggle()
                }
            } label: {
                Text(isDetailsExpanded ? "HIDE" : "DETAILS")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(isDetailsExpanded ? DesignTokens.Colors.accent : DesignTokens.Colors.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .frame(height: Self.titleBarHeight)
    }

    private var statusIndicator: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 6, height: 6)
    }

    private var statusColor: Color {
        if gpuData.temperature ?? 0 > 85 {
            return .red
        } else if gpuData.temperature ?? 0 > 70 {
            return .orange
        } else if gpuData.usagePercentage ?? 0 > 80 {
            return .orange
        }
        return .green
    }

    private var gpuModelName: String {
        if let model = gpuData.model, !model.isEmpty {
            return model
        }
        if let vendor = gpuData.vendor, !vendor.isEmpty {
            return "\(vendor) GPU"
        }
        return "GPU"
    }

    // MARK: - Gauges Row

    private var gaugesRow: some View {
        HStack(spacing: 10) {
            // Temperature gauge
            gpuGauge(
                value: gpuData.temperature ?? 0,
                maxValue: 100,
                label: "Temp",
                unit: "°C",
                color: temperatureColor(gpuData.temperature ?? 0)
            )

            // Utilization gauge
            gpuGauge(
                value: gpuData.usagePercentage ?? 0,
                maxValue: 100,
                label: "Util",
                unit: "%",
                color: utilizationColor(gpuData.usagePercentage ?? 0)
            )

            // Render utilization gauge (if available)
            if let renderUtil = gpuData.renderUtilization {
                gpuGauge(
                    value: renderUtil,
                    maxValue: 100,
                    label: "Render",
                    unit: "%",
                    color: utilizationColor(renderUtil)
                )
            } else {
                // Placeholder for render
                placeholderGauge(label: "Render")
            }

            // Tiler utilization gauge (if available)
            if let tilerUtil = gpuData.tilerUtilization {
                gpuGauge(
                    value: tilerUtil,
                    maxValue: 100,
                    label: "Tiler",
                    unit: "%",
                    color: utilizationColor(tilerUtil)
                )
            } else {
                // Placeholder for tiler
                placeholderGauge(label: "Tiler")
            }
        }
        .frame(height: Self.gaugesRowHeight)
    }

    private func gpuGauge(value: Double, maxValue: Double, label: String, unit: String, color: Color) -> some View {
        HalfCircleGaugeView(
            value: value,
            maxValue: maxValue,
            label: nil,
            unit: nil,
            color: color,
            size: CGSize(width: 50, height: 30),
            lineWidth: 6
        )
        .overlay(
            VStack(spacing: 0) {
                Text(label)
                    .font(.system(size: 7))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                Text("\(Int(value))\(unit)")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(color)
            }
                .offset(y: 8)
        )
    }

    private func placeholderGauge(label: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 7))
                .foregroundColor(DesignTokens.Colors.textTertiary)
            Text("N/A")
                .font(.system(size: 8))
                .foregroundColor(DesignTokens.Colors.textTertiary)
        }
        .frame(width: 50, height: 30)
    }

    // MARK: - Charts Row

    private var chartsRow: some View {
        HStack(spacing: 10) {
            // Temperature chart
            gpuChart(
                data: temperatureHistory,
                color: .orange,
                label: "Temp"
            )

            // Utilization chart
            gpuChart(
                data: utilizationHistory,
                color: .blue,
                label: "Util"
            )

            // Render chart
            if gpuData.renderUtilization != nil {
                gpuChart(
                    data: renderHistory,
                    color: .purple,
                    label: "Render"
                )
            } else {
                placeholderChart(label: "Render")
            }

            // Tiler chart
            if gpuData.tilerUtilization != nil {
                gpuChart(
                    data: tilerHistory,
                    color: .cyan,
                    label: "Tiler"
                )
            } else {
                placeholderChart(label: "Tiler")
            }
        }
        .frame(height: Self.chartsRowHeight)
    }

    private func gpuChart(data: [Double], color: Color, label: String) -> some View {
        VStack(spacing: 2) {
            NetworkSparklineChart(
                data: data,
                color: color,
                height: 35,
                showArea: false,
                lineWidth: 1
            )

            Text(label)
                .font(.system(size: 7))
                .foregroundColor(DesignTokens.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func placeholderChart(label: String) -> some View {
        VStack(spacing: 2) {
            Rectangle()
                .fill(Color.gray.opacity(0.1))
                .frame(height: 35)
                .overlay(
                    Text("No data")
                        .font(.system(size: 7))
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                )

            Text(label)
                .font(.system(size: 7))
                .foregroundColor(DesignTokens.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Details Panel

    private var detailsPanel: some View {
        VStack(spacing: PopoverConstants.compactSpacing) {
            Divider()

            // Grid of details
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: PopoverConstants.compactSpacing) {
                // Vendor
                if let vendor = gpuData.vendor {
                    detailItem("Vendor", value: vendor)
                }

                // Cores
                if let cores = gpuData.cores {
                    detailItem("Cores", value: "\(cores)")
                }

                // Core clock
                if let coreClock = gpuData.coreClock {
                    detailItem("Core Clock", value: "\(Int(coreClock)) MHz")
                }

                // Memory clock
                if let memClock = gpuData.memoryClock {
                    detailItem("Memory Clock", value: "\(Int(memClock)) MHz")
                }

                // Fan speed
                if let fanSpeed = gpuData.fanSpeed {
                    detailItem("Fan", value: "\(fanSpeed) RPM")
                }

                // Memory usage
                if let memUsage = gpuData.usedMemory, let memTotal = gpuData.totalMemory {
                    let usedGB = Double(memUsage) / 1_000_000_000
                    let totalGB = Double(memTotal) / 1_000_000_000
                    detailItem("Memory", value: String(format: "%.1f / %.1f GB", usedGB, totalGB))
                }

                // Current temperature
                if let temp = gpuData.temperature {
                    detailItem("Temperature", value: "\(Int(temp))°C", color: temperatureColor(temp))
                }

                // Current utilization
                if let util = gpuData.usagePercentage {
                    detailItem("Utilization", value: "\(Int(util))%", color: utilizationColor(util))
                }
            }
        }
        .padding(.top, PopoverConstants.compactSpacing)
    }

    private func detailItem(_ label: String, value: String, color: Color? = nil) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(DesignTokens.Colors.textSecondary)

            Spacer()

            Text(value)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(color ?? DesignTokens.Colors.textPrimary)
        }
    }

    // MARK: - Color Helpers

    private func temperatureColor(_ temp: Double) -> Color {
        switch temp {
        case 0..<60: return .green
        case 60..<75: return .orange
        default: return .red
        }
    }

    private func utilizationColor(_ util: Double) -> Color {
        switch util {
        case 0..<60: return .green
        case 60..<85: return .orange
        default: return .red
        }
    }
}

// MARK: - Preview

#Preview("Per GPU Container") {
    VStack(spacing: 16) {
        // Sample GPU with all data
        PerGpuContainer(
            gpuData: GPUData(
                usagePercentage: 65,
                usedMemory: 4_500_000_000,
                totalMemory: 8_000_000_000,
                temperature: 72,
                renderUtilization: 58,
                tilerUtilization: 42,
                coreClock: 1200,
                memoryClock: 1000,
                fanSpeed: 1200,
                vendor: "Apple",
                model: "M2 Max",
                cores: 38,
                isActive: true
            ),
            temperatureHistory: [45, 50, 55, 60, 58, 62, 65, 70, 72, 68],
            utilizationHistory: [40, 45, 50, 55, 60, 62, 65, 63, 65, 65],
            renderHistory: [35, 40, 42, 45, 50, 52, 55, 54, 58, 58],
            tilerHistory: [25, 30, 32, 35, 38, 40, 42, 40, 42, 42]
        )

        // GPU with partial data
        PerGpuContainer(
            gpuData: GPUData(
                usagePercentage: 35,
                usedMemory: 2_000_000_000,
                totalMemory: 8_000_000_000,
                temperature: 45,
                vendor: "Apple",
                model: "M2",
                cores: 10
            ),
            temperatureHistory: [40, 42, 43, 44, 45, 44, 43, 42, 45, 45],
            utilizationHistory: [20, 25, 28, 30, 32, 35, 33, 34, 35, 35]
        )
    }
    .padding()
    .background(Color(nsColor: .windowBackgroundColor))
}
