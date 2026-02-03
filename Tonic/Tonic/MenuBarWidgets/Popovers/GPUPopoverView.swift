//
//  GPUPopoverView.swift
//  Tonic
//
//  Stats Master-style GPU popover with per-GPU containers
//  Task ID: fn-6-i4g.36, fn-8-v3b.7
//

import SwiftUI
import OSLog

// MARK: - GPU Popover View

/// Complete Stats Master-style GPU popover with:
/// - Per-GPU containers with 4 gauges and 4 charts
/// - Multi-GPU support (stacks vertically)
/// - Expandable details panel for each GPU
/// - Activity Monitor integration
public struct GPUPopoverView: View {

    // MARK: - Properties

    @State private var dataManager = WidgetDataManager.shared
    @State private var temperatureUnit: TemperatureUnit = .celsius

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            ScrollView {
                VStack(spacing: PopoverConstants.sectionSpacing) {
                    if isGPUSupported {
                        // Per-GPU containers
                        gpuContainersSection
                    } else {
                        // Unsupported message
                        unsupportedSection
                    }
                }
                .padding(PopoverConstants.horizontalPadding)
                .padding(.vertical, PopoverConstants.verticalPadding)
            }
        }
        .frame(width: PopoverConstants.width, height: PopoverConstants.maxHeight)
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(PopoverConstants.cornerRadius)
        .onAppear {
            loadTemperatureUnit()
        }
        .onReceive(NotificationCenter.default.publisher(for: .widgetConfigurationDidUpdate)) { _ in
            loadTemperatureUnit()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: PopoverConstants.iconTextGap) {
            // Icon
            Image(systemName: PopoverConstants.Icons.gpu)
                .font(.title2)
                .foregroundColor(DesignTokens.Colors.accent)

            // Title
            Text("GPU")
                .font(PopoverConstants.headerTitleFont)
                .foregroundColor(DesignTokens.Colors.textPrimary)

            Spacer()

            // Activity Monitor button
            Button {
                openActivityMonitor()
            } label: {
                HStack(spacing: PopoverConstants.compactSpacing) {
                    Image(systemName: PopoverConstants.Icons.activityMonitor)
                        .font(.system(size: PopoverConstants.mediumIconSize))
                    Text("Activity Monitor")
                        .font(PopoverConstants.smallLabelFont)
                }
                .foregroundColor(DesignTokens.Colors.textSecondary)
            }
            .buttonStyle(.plain)

            // Settings button
            Button {
                // TODO: Open settings to GPU widget configuration
            } label: {
                Image(systemName: PopoverConstants.Icons.settings)
                    .font(.body)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - GPU Support Check

    private var isGPUSupported: Bool {
        #if arch(arm64)
        return true
        #else
        return dataManager.gpuData.usagePercentage != nil
        #endif
    }

    // MARK: - GPU Containers Section (fn-8-v3b.7)

    /// Displays PerGpuContainer for each GPU
    /// For Apple Silicon, this shows a single GPU (integrated)
    /// For multi-GPU systems, containers stack vertically
    private var gpuContainersSection: some View {
        VStack(spacing: PopoverConstants.sectionSpacing) {
            // Get list of GPUs (currently single GPU for Apple Silicon)
            ForEach(gpuList, id: \.timestamp) { gpuData in
                PerGpuContainer(
                    gpuData: gpuData,
                    temperatureHistory: dataManager.gpuTemperatureHistory,
                    utilizationHistory: dataManager.gpuHistory,
                    renderHistory: [], // TODO: Add render history tracking
                    tilerHistory: []   // TODO: Add tiler history tracking
                )
            }

            // Platform note
            #if arch(arm64)
            platformNote
            #endif
        }
    }

    private var gpuList: [GPUData] {
        // For Apple Silicon, we have a single integrated GPU
        // Future enhancement: detect multiple GPUs (Mac Pro with MPX modules)
        #if arch(arm64)
        return [dataManager.gpuData]
        #else
        if dataManager.gpuData.usagePercentage != nil {
            return [dataManager.gpuData]
        }
        return []
        #endif
    }

    private var platformNote: some View {
        VStack(alignment: .leading, spacing: PopoverConstants.compactSpacing) {
            HStack(spacing: 6) {
                Image(systemName: PopoverConstants.Icons.info)
                    .font(.system(size: 10))
                    .foregroundColor(DesignTokens.Colors.textTertiary)

                Text("Apple Silicon integrated GPU")
                    .font(.system(size: 10))
                    .foregroundColor(DesignTokens.Colors.textTertiary)

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(PopoverConstants.smallCornerRadius)
        }
    }

    // MARK: - Unsupported Section

    private var unsupportedSection: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: "info.circle")
                .font(.system(size: 40))
                .foregroundColor(DesignTokens.Colors.textSecondary)

            Text("GPU Monitoring Not Available")
                .font(.subheadline)
                .fontWeight(.semibold)

            Text("GPU monitoring requires Apple Silicon Mac or supported discrete GPU.")
                .font(.caption)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Helper Methods

    private func loadTemperatureUnit() {
        temperatureUnit = WidgetPreferences.shared.temperatureUnit
    }
}

// MARK: - Activity Monitor Launch Helper

/// Opens Activity Monitor using the modern NSWorkspace API
private func openActivityMonitor() {
    let paths = [
        "/System/Applications/Utilities/Activity Monitor.app",
        "/Applications/Utilities/Activity Monitor.app",
        "/System/Library/CoreServices/Applications/Activity Monitor.app"
    ]

    for path in paths {
        let url = URL(fileURLWithPath: path)
        if FileManager.default.fileExists(atPath: path) {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: url, configuration: config) { app, error in
                if let error = error {
                    os_log("Failed to open Activity Monitor: %@", log: .default, type: .error, error.localizedDescription)
                }
            }
            return
        }
    }
}

// MARK: - Preview

#Preview("GPU Popover") {
    GPUPopoverView()
}
