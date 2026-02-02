//
//  DiskPopoverView.swift
//  Tonic
//
//  Stats Master-style Disk popover with usage, I/O history, SMART, and details
//  Task ID: fn-6-i4g.37
//

import SwiftUI

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
/// - Disk usage summary (all volumes)
/// - I/O history line chart
/// - SMART health status
/// - I/O throughput metrics
/// - Top processes by disk I/O
public struct DiskPopoverView: View {

    // MARK: - Properties

    @State private var dataManager = WidgetDataManager.shared
    @State private var selectedVolume: DiskVolumeData?

    // MARK: - Computed Properties

    private var primaryVolume: DiskVolumeData? {
        dataManager.diskVolumes.first { $0.isBootVolume } ?? dataManager.diskVolumes.first
    }

    private var displayVolume: DiskVolumeData {
        selectedVolume ?? primaryVolume ?? createFallbackVolume()
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            ScrollView {
                VStack(spacing: PopoverConstants.sectionSpacing) {
                    // Volume Selector (if multiple volumes)
                    if dataManager.diskVolumes.count > 1 {
                        volumeSelectorSection
                        Divider()
                    }

                    // Usage Summary
                    usageSummarySection

                    Divider()

                    // I/O History Chart
                    ioHistorySection

                    Divider()

                    // SMART Status
                    smartStatusSection

                    Divider()

                    // I/O Metrics
                    ioMetricsSection

                    Divider()

                    // Top Processes
                    topProcessesSection
                }
                .padding(PopoverConstants.horizontalPadding)
                .padding(.vertical, PopoverConstants.verticalPadding)
            }
        }
        .frame(width: PopoverConstants.width, height: PopoverConstants.maxHeight)
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(PopoverConstants.cornerRadius)
        .onAppear {
            selectedVolume = primaryVolume
        }
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

            // Activity Monitor button
            Button {
                NSWorkspace.shared.launchApplication("Activity Monitor")
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
                // TODO: Open settings to Disk widget configuration
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

    // MARK: - Volume Selector Section

    private var volumeSelectorSection: some View {
        VStack(alignment: .leading, spacing: PopoverConstants.itemSpacing) {
            PopoverSectionHeader(title: "Select Volume")

            Picker("Volume", selection: $selectedVolume) {
                ForEach(dataManager.diskVolumes) { volume in
                    Text(volume.name).tag(volume as DiskVolumeData?)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Usage Summary Section

    private var usageSummarySection: some View {
        VStack(alignment: .leading, spacing: PopoverConstants.itemSpacing) {
            PopoverSectionHeader(title: "Storage Usage")

            HStack(spacing: 16) {
                // Donut chart for used/free
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.15), lineWidth: 12)
                        .frame(width: 70, height: 70)

                    Circle()
                        .trim(from: 0, to: displayVolume.usagePercentage / 100)
                        .stroke(
                            usageColor(for: displayVolume.usagePercentage),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 70, height: 70)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.3), value: displayVolume.usagePercentage)

                    VStack(spacing: 2) {
                        Text("\(Int(displayVolume.usagePercentage))%")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(DesignTokens.Colors.textPrimary)
                        Text("Used")
                            .font(.system(size: 9))
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    }
                }
                .frame(width: 70, height: 70)

                // Volume details
                VStack(alignment: .leading, spacing: 6) {
                    Text(displayVolume.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(DesignTokens.Colors.textPrimary)

                    if displayVolume.isBootVolume {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 9))
                            Text("Boot Volume")
                                .font(.system(size: 9))
                        }
                        .foregroundColor(DesignTokens.Colors.accent)
                    }

                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(red: 1.0, green: 0.3, blue: 0.2))
                            .frame(width: 6, height: 6)
                        Text("Used:")
                            .font(.system(size: 10))
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                        Text(ByteCountFormatter.string(fromByteCount: Int64(displayVolume.usedBytes), countStyle: .binary))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(DesignTokens.Colors.textPrimary)
                    }

                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 6, height: 6)
                        Text("Free:")
                            .font(.system(size: 10))
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                        Text(ByteCountFormatter.string(fromByteCount: Int64(displayVolume.freeBytes), countStyle: .binary))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(DesignTokens.Colors.textPrimary)
                    }

                    Text("Total: \(ByteCountFormatter.string(fromByteCount: Int64(displayVolume.totalBytes), countStyle: .binary))")
                        .font(.system(size: 9))
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }

                Spacer()
            }
        }
    }

    // MARK: - I/O History Section

    private var ioHistorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("I/O Activity")
                .font(PopoverConstants.sectionTitleFont)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            HStack(spacing: 12) {
                // Read activity
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Text("Read")
                            .font(.system(size: 10))
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    }

                    if let readBps = displayVolume.readBytesPerSecond {
                        Text(formatBytesPerSecond(readBps))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(DesignTokens.Colors.textPrimary)
                    } else {
                        Text("--")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    }

                    DiskIOSparkline(
                        data: ioReadHistory,
                        color: .green
                    )
                    .frame(height: 30)
                }
                .frame(maxWidth: .infinity)

                Divider()
                    .frame(height: 40)

                // Write activity
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 6, height: 6)
                        Text("Write")
                            .font(.system(size: 10))
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    }

                    if let writeBps = displayVolume.writeBytesPerSecond {
                        Text(formatBytesPerSecond(writeBps))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(DesignTokens.Colors.textPrimary)
                    } else {
                        Text("--")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    }

                    DiskIOSparkline(
                        data: ioWriteHistory,
                        color: .orange
                    )
                    .frame(height: 30)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - SMART Status Section

    private var smartStatusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Drive Health")
                .font(PopoverConstants.sectionTitleFont)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            if let smart = displayVolume.smartData {
                HStack(spacing: 16) {
                    // Health indicator
                    HStack(spacing: 8) {
                        Circle()
                            .fill(healthColor(smart.healthStatus))
                            .frame(width: 10, height: 10)

                        Text(smart.healthStatus.rawValue)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(DesignTokens.Colors.textPrimary)
                    }

                    Spacer()

                    // Temperature
                    if let temp = smart.temperature {
                        HStack(spacing: 4) {
                            Image(systemName: "thermometer")
                                .font(.system(size: 10))
                            Text("\(Int(temp))°C")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(DesignTokens.Colors.textPrimary)
                        }
                    }

                    // Percentage used
                    if let percentageUsed = smart.percentageUsed {
                        Text("Used: \(Int(percentageUsed))%")
                            .font(.system(size: 10))
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    }
                }
                .padding(.vertical, 4)

                // SMART details row
                HStack(spacing: 16) {
                    if smart.powerOnHours > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 9))
                            Text(smart.powerOnTimeString)
                                .font(.system(size: 9))
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                        }
                    }

                    if smart.powerCycles > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 9))
                            Text("\(smart.powerCycles) cycles")
                                .font(.system(size: 9))
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                        }
                    }

                    Spacer()
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 10))
                    Text("SMART data not available")
                        .font(.system(size: 10))
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
            }
        }
    }

    // MARK: - I/O Metrics Section

    private var ioMetricsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("I/O Metrics")
                .font(PopoverConstants.sectionTitleFont)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            HStack(spacing: 20) {
                // Read IOPS
                metricItem(
                    label: "Read IOPS",
                    value: displayVolume.readIOPS,
                    formatter: { iops in
                        if iops >= 1000 {
                            return String(format: "%.1fK", iops / 1000)
                        }
                        return String(format: "%.0f", iops)
                    },
                    color: .green
                )

                // Write IOPS
                metricItem(
                    label: "Write IOPS",
                    value: displayVolume.writeIOPS,
                    formatter: { iops in
                        if iops >= 1000 {
                            return String(format: "%.1fK", iops / 1000)
                        }
                        return String(format: "%.0f", iops)
                    },
                    color: .orange
                )

                // Total IOPS
                if let totalIOPS = displayVolume.totalIOPS {
                    metricValue(label: "Total IOPS", value: String(format: "%.0f", totalIOPS))
                } else {
                    metricValue(label: "Total IOPS", value: "--")
                }
            }
        }
    }

    private func metricItem(label: String, value: Double?, formatter: (Double) -> String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                Text(label)
                    .font(.system(size: 9))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }

            if let value = value {
                Text(formatter(value))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(DesignTokens.Colors.textPrimary)
            } else {
                Text("--")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func metricValue(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(DesignTokens.Colors.textSecondary)

            Text(value)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(DesignTokens.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Top Processes Section

    private var topProcessesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Top Disk I/O")
                .font(PopoverConstants.sectionTitleFont)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            if let processes = displayVolume.topProcesses, !processes.isEmpty {
                VStack(spacing: 6) {
                    ForEach(processes.prefix(5)) { process in
                        diskProcessRow(process)
                    }
                }
            } else {
                Text("No process data available")
                    .font(.system(size: 10))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            }
        }
    }

    private func diskProcessRow(_ process: ProcessUsage) -> some View {
        HStack(spacing: 8) {
            // App icon if available
            if let icon = process.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 14, height: 14)
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: 10))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .frame(width: 14, height: 14)
            }

            // Process name
            Text(process.name)
                .font(.system(size: 10))
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .frame(width: 70, alignment: .leading)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            // Read bytes
            if let readBytes = process.diskReadBytes {
                Text(formatByteCount(readBytes))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Color.green)
            }

            // Write bytes
            if let writeBytes = process.diskWriteBytes {
                Text(formatByteCount(writeBytes))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Color.orange)
            }
        }
    }

    // MARK: - Helper Properties

    private var ioReadHistory: [Double] {
        // Create a simulated I/O history based on current read rate
        // In production, this would come from a tracked history
        let baseValue = displayVolume.readBytesPerSecond ?? 0
        return (0..<20).map { _ in
            baseValue * Double.random(in: 0.5...1.5)
        }
    }

    private var ioWriteHistory: [Double] {
        let baseValue = displayVolume.writeBytesPerSecond ?? 0
        return (0..<20).map { _ in
            baseValue * Double.random(in: 0.5...1.5)
        }
    }

    // MARK: - Helper Methods

    private func usageColor(for percentage: Double) -> Color {
        switch percentage {
        case 0..<70: return TonicColors.success
        case 70..<90: return TonicColors.warning
        default: return TonicColors.error
        }
    }

    private func healthColor(_ status: DiskHealthStatus) -> Color {
        switch status {
        case .good: return TonicColors.success
        case .warning: return TonicColors.warning
        case .critical: return TonicColors.error
        case .unknown: return Color.gray
        }
    }

    private func formatBytesPerSecond(_ bytesPerSecond: Double) -> String {
        let bps = abs(bytesPerSecond)
        if bps >= 1_000_000_000 {
            return String(format: "%.1f GB/s", bps / 1_000_000_000)
        } else if bps >= 1_000_000 {
            return String(format: "%.1f MB/s", bps / 1_000_000)
        } else if bps >= 1_000 {
            return String(format: "%.1f KB/s", bps / 1_000)
        } else {
            return String(format: "%.0f B/s", bps)
        }
    }

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

    private func createFallbackVolume() -> DiskVolumeData {
        DiskVolumeData(
            name: "Unknown",
            path: "/",
            usedBytes: 0,
            totalBytes: 1,
            isBootVolume: false,
            isInternal: true,
            isActive: false
        )
    }
}

// MARK: - Disk I/O Sparkline Component

/// Mini sparkline for I/O history display
struct DiskIOSparkline: View {
    let data: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let maxVal = data.max() ?? 1
            let stepX = width / max(1, CGFloat(data.count - 1))

            Path { path in
                guard let first = data.first else { return }
                let startY = height - (first / (maxVal * 1.2)) * height
                path.move(to: CGPoint(x: 0, y: startY))

                for (index, value) in data.dropFirst().enumerated() {
                    let x = CGFloat(index + 1) * stepX
                    let y = height - (value / (maxVal * 1.2)) * height
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
    }
}

// MARK: - Preview

#Preview("Disk Popover") {
    DiskPopoverView()
}
