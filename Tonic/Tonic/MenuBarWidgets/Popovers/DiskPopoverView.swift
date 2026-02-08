//
//  DiskPopoverView.swift
//  Tonic
//
//  Stats Master-style Disk popover with per-disk containers and top processes
//  Task ID: fn-8-v3b.9
//

import SwiftUI
import OSLog

// MARK: - DiskVolumeData Hashable Conformance

extension DiskVolumeData: Hashable {
    public static func == (lhs: DiskVolumeData, rhs: DiskVolumeData) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.path == rhs.path &&
        lhs.usedBytes == rhs.usedBytes &&
        lhs.totalBytes == rhs.totalBytes
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(path)
    }
}

// MARK: - Disk Popover View

/// Complete Stats Master-style Disk popover with:
/// - Per-disk containers with dual-line read/write charts
/// - Top processes by disk I/O
public struct DiskPopoverView: View {

    // MARK: - Properties

    @State private var dataManager = WidgetDataManager.shared
    @State private var isProcessesExpanded: Bool = true

    // Configurable top process count
    private var topProcessCount: Int {
        WidgetPreferences.shared.widgetConfigs
            .first(where: { $0.type == .disk })?
            .moduleSettings.disk.topProcessCount ?? 8
    }

    // MARK: - Computed Properties

    private var primaryVolume: DiskVolumeData? {
        dataManager.diskVolumes.first { $0.isBootVolume } ?? dataManager.diskVolumes.first
    }

    // Use shared history from WidgetDataManager (boot volume only)
    // NOTE: Current implementation tracks shared history for the boot volume.
    // Per-volume history tracking would require separate circular buffers per volume,
    // which is a more significant change to WidgetDataManager.
    // Future enhancement: Add volume-specific history tracking for multi-volume systems.
    private var diskReadHistory: [Double] {
        dataManager.diskReadHistory
    }

    private var diskWriteHistory: [Double] {
        dataManager.diskWriteHistory
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            ScrollView {
                VStack(spacing: PopoverConstants.sectionSpacing) {
                    // Per-disk containers (stacked vertically)
                    ForEach(dataManager.diskVolumes) { volume in
                        PerDiskContainer(
                            diskData: volume,
                            readHistory: volume.isBootVolume ? diskReadHistory : [],
                            writeHistory: volume.isBootVolume ? diskWriteHistory : []
                        )
                    }

                    SoftDivider()

                    // Top Processes section
                    topProcessesSection
                }
                .padding(PopoverConstants.horizontalPadding)
                .padding(.vertical, PopoverConstants.verticalPadding)
            }
        }
        .frame(width: PopoverConstants.width, height: PopoverConstants.maxHeight)
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(PopoverConstants.cornerRadius)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: PopoverConstants.iconTextGap) {
            // Icon
            Image(systemName: PopoverConstants.Icons.disk)
                .font(.title2)
                .foregroundColor(DesignTokens.Colors.accent)

            // Title
            Text("Disk")
                .font(PopoverConstants.headerTitleFont)
                .foregroundColor(DesignTokens.Colors.textPrimary)

            Spacer()

            // Activity Monitor button (icon-only to prevent header overflow)
            HoverableButton(systemImage: PopoverConstants.Icons.activityMonitor) {
                openActivityMonitor()
            }

            // Settings button
            HoverableButton(systemImage: PopoverConstants.Icons.settings) {
                SettingsDeepLinkNavigator.openModuleSettings(.disk)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Top Processes Section

    // MARK: - Top Processes Section
    // NOTE: Process I/O shows cumulative bytes (diskReadBytes/diskWriteBytes from proc_pid_rusage).
    // Future enhancement: Track per-process deltas over time to display I/O rates (bytes/sec).
    // This would require maintaining process state across samples in WidgetDataManager.

    private var topProcessesSection: some View {
        VStack(alignment: .leading, spacing: PopoverConstants.itemSpacing) {
            // Section header with expand/collapse
            Button {
                withAnimation(PopoverConstants.fastAnimation) {
                    isProcessesExpanded.toggle()
                }
            } label: {
                HStack(spacing: PopoverConstants.compactSpacing) {
                    Text("Top Disk I/O")
                        .font(PopoverConstants.sectionTitleFont)
                        .foregroundColor(DesignTokens.Colors.textSecondary)

                    Spacer()

                    Image(systemName: isProcessesExpanded ? "chevron.down" : "chevron.right")
                        .font(PopoverConstants.smallLabelFont)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
            }
            .buttonStyle(.plain)

            // Process list (if expanded)
            if isProcessesExpanded {
                if let processes = primaryVolume?.topProcesses, !processes.isEmpty {
                    VStack(spacing: PopoverConstants.compactSpacing) {
                        // Header row
                        processHeaderRow

                        SoftDivider()

                        // Process rows
                        ForEach(processes.prefix(topProcessCount)) { process in
                            diskProcessRow(process)
                        }
                    }
                    .padding(PopoverConstants.compactSpacing)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(PopoverConstants.innerCornerRadius)
                } else {
                    EmptyStateView(icon: "app.dashed", title: "No process data available")
                }
            }
        }
    }

    private var processHeaderRow: some View {
        HStack(spacing: PopoverConstants.compactSpacing) {
            Text("Process")
                .font(PopoverConstants.processHeaderFont)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .frame(width: 100, alignment: .leading)

            Spacer()

            Text("Read (Total)")
                .font(PopoverConstants.processHeaderFont)
                .foregroundColor(PopoverConstants.readColor)
                .frame(width: 70, alignment: .trailing)

            Text("Write (Total)")
                .font(PopoverConstants.processHeaderFont)
                .foregroundColor(PopoverConstants.writeColor)
                .frame(width: 70, alignment: .trailing)
        }
    }

    private func diskProcessRow(_ process: ProcessUsage) -> some View {
        HStack(spacing: PopoverConstants.compactSpacing) {
            // App icon if available
            if let icon = process.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 14, height: 14)
            } else {
                Image(systemName: "app.fill")
                    .font(PopoverConstants.smallLabelFont)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .frame(width: 14, height: 14)
            }

            // Process name
            Text(process.name)
                .font(PopoverConstants.smallLabelFont)
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .frame(width: 90, alignment: .leading)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            // Read bytes (cumulative)
            if let readBytes = process.diskReadBytes {
                Text(formatByteCount(readBytes))
                    .font(PopoverConstants.processValueFont)
                    .foregroundColor(PopoverConstants.readColor)
                    .frame(width: 70, alignment: .trailing)
            } else {
                Text("--")
                    .font(PopoverConstants.processValueFont)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .frame(width: 70, alignment: .trailing)
            }

            // Write bytes (cumulative)
            if let writeBytes = process.diskWriteBytes {
                Text(formatByteCount(writeBytes))
                    .font(PopoverConstants.processValueFont)
                    .foregroundColor(PopoverConstants.writeColor)
                    .frame(width: 70, alignment: .trailing)
            } else {
                Text("--")
                    .font(PopoverConstants.processValueFont)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .frame(width: 70, alignment: .trailing)
            }
        }
    }

    // MARK: - Helper Methods

    private func formatByteCount(_ bytes: UInt64) -> String {
        let b = Double(bytes)
        if b >= 1_000_000_000 {
            return String(format: "%.1fG", b / 1_000_000_000)
        } else if b >= 1_000_000 {
            return String(format: "%.1fM", b / 1_000_000)
        } else if b >= 1_000 {
            return String(format: "%.1fK", b / 1_000)
        } else {
            return "\(bytes)B"
        }
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

#Preview("Disk Popover") {
    DiskPopoverView()
}
