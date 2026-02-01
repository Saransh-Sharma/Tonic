//
//  DiskWidgetView.swift
//  Tonic
//
//  Disk monitoring widget views
//  Task ID: fn-2.7
//  Updated: fn-6-i4g.18 - Standardized popover layout
//

import SwiftUI
import Charts

// MARK: - Disk Compact View

/// Compact menu bar view for Disk widget
public struct DiskCompactView: View {
    let usagePercentage: Double
    let isActive: Bool

    public init(usagePercentage: Double, isActive: Bool) {
        self.usagePercentage = usagePercentage
        self.isActive = isActive
    }

    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "internaldrive")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(usageColor)

            Text("\(Int(usagePercentage))%")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.primary)

            // Activity indicator when disk is active
            if isActive {
                Circle()
                    .fill(usageColor)
                    .frame(width: 6, height: 6)
                    .overlay(
                        Circle()
                            .stroke(usageColor, lineWidth: 1)
                            .blur(radius: 2)
                    )
            }
        }
        .padding(.horizontal, 4)
        .frame(height: 22)
    }

    private var usageColor: Color {
        switch usagePercentage {
        case 0..<70: return TonicColors.success
        case 70..<90: return TonicColors.warning
        default: return TonicColors.error
        }
    }
}

// MARK: - Disk Detail View

/// Detailed popover view for Disk widget
/// Uses standardized PopoverTemplate for consistent layout
public struct DiskDetailView: View {

    @State private var dataManager = WidgetDataManager.shared

    public init() {}

    public var body: some View {
        PopoverTemplate(
            icon: PopoverConstants.Icons.disk,
            title: PopoverConstants.Names.disk,
            headerValue: primaryDisk.map { "\(Int($0.usagePercentage))%" } ?? "--",
            headerColor: primaryUsageColor
        ) {
            // Primary disk overview
            primaryDiskSection

            // All volumes
            volumesSection

            // I/O activity
            ioActivitySection

            // Per-app usage
            perAppSection
        }
    }

    private var primaryDisk: DiskVolumeData? {
        dataManager.diskVolumes.first(where: { $0.isBootVolume })
    }

    private var primaryUsageColor: Color {
        guard let primary = primaryDisk else { return .gray }
        switch primary.usagePercentage {
        case 0..<70: return TonicColors.success
        case 70..<90: return TonicColors.warning
        default: return TonicColors.error
        }
    }

    private var primaryDiskSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            if let primary = primaryDisk {
                HStack(spacing: DesignTokens.Spacing.lg) {
                    // Circular progress
                    ZStack {
                        CircularProgress(
                            percentage: primary.usagePercentage,
                            size: 80,
                            lineWidth: 10,
                            color: primaryUsageColor
                        )

                        VStack(spacing: 2) {
                            Text("\(Int(primary.usagePercentage))%")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(primaryUsageColor)

                            Text("used")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        VStack(alignment: .leading, spacing: 4) {
                            Image(systemName: "internaldrive")
                                .foregroundColor(.secondary)
                            Text(primary.name)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Used:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatBytes(primary.usedBytes))
                                .font(.caption)
                                .fontWeight(.medium)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Free:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatBytes(primary.freeBytes))
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(TonicColors.success)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatBytes(primary.totalBytes))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(PopoverConstants.innerCornerRadius)
    }

    private var volumesSection: some View {
        TitledPopoverSection(title: "All Volumes") {
            VStack(spacing: 10) {
                ForEach(dataManager.diskVolumes) { volume in
                    volumeRow(volume)
                }
            }
        }
    }

    private func volumeRow(_ volume: DiskVolumeData) -> some View {
        VStack(spacing: PopoverConstants.itemSpacing) {
            HStack {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: volume.isBootVolume ? "internaldrive.fill" : "externaldrive")
                        .foregroundColor(volume.isBootVolume ? primaryUsageColor : .secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(volume.name)
                            .font(.caption)
                            .fontWeight(.medium)

                        if volume.isBootVolume {
                            Text("Boot Volume")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    Text("\(Int(volume.usagePercentage))%")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(colorForUsage(volume.usagePercentage))
                }
            }

            // Progress bar
            UsageBar(percentage: volume.usagePercentage, color: colorForUsage(volume.usagePercentage), height: 6)
        }
    }

    private var ioActivitySection: some View {
        PopoverSection {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: dataManager.primaryDiskActivity ? "arrow.left.arrow.right" : "stop.circle")
                    .font(.title2)
                    .foregroundColor(dataManager.primaryDiskActivity ? .blue : .secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Disk Activity")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(dataManager.primaryDiskActivity ? "I/O in progress" : "Idle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if dataManager.primaryDiskActivity {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
        }
    }

    private var perAppSection: some View {
        ProcessListWidgetView(widgetType: .disk, maxCount: 5)
    }

    private func colorForUsage(_ percentage: Double) -> Color {
        switch percentage {
        case 0..<70: return TonicColors.success
        case 70..<90: return TonicColors.warning
        default: return TonicColors.error
        }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}

// MARK: - Disk Status Item

/// Manages the Disk widget's NSStatusItem
@MainActor
public final class DiskStatusItem: WidgetStatusItem {

    public override init(widgetType: WidgetType = .disk, configuration: WidgetConfiguration) {
        super.init(widgetType: widgetType, configuration: configuration)
    }

    // Uses base WidgetStatusItem.createCompactView() which respects configuration

    public override func createDetailView() -> AnyView {
        AnyView(DiskDetailView())
    }
}

// MARK: - Preview

#Preview("Disk Detail") {
    DiskDetailView()
}
