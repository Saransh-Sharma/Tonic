//
//  ProcessListComponents.swift
//  Tonic
//
//  Process monitoring UI components for widget popovers
//  Task ID: fn-6-i4g.9
//

import SwiftUI
import AppKit

// MARK: - Process List Widget View

/// A reusable process monitoring list view for widget popovers
/// Shows top processes for CPU, Memory, Network, and Disk usage
public struct ProcessListWidgetView: View {

    // MARK: - Configuration

    let widgetType: WidgetType
    let maxCount: Int

    // MARK: - State

    @State private var dataManager = WidgetDataManager.shared

    // MARK: - Initialization

    public init(widgetType: WidgetType, maxCount: Int = 5) {
        self.widgetType = widgetType
        self.maxCount = maxCount
    }

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            header

            if processes.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(processes.enumerated()), id: \.element.id) { index, process in
                        ProcessListRow(
                            process: process,
                            widgetType: widgetType,
                            rank: index + 1
                        )

                        if index < processes.count - 1 {
                            Divider()
                                .padding(.leading, 56)
                        }
                    }
                }
            }

            // Activity Monitor link
            activityMonitorLink
        }
        .padding(DesignTokens.Spacing.xs)
        .background(DesignTokens.Colors.backgroundSecondary)
        .cornerRadius(DesignTokens.CornerRadius.medium)
    }

    // MARK: - View Components

    private var header: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: widgetType.icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(headerColor)

                Text(headerTitle)
                    .font(DesignTokens.Typography.captionEmphasized)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }

            Spacer()

            if !processes.isEmpty {
                Text("\(processes.count)")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(DesignTokens.Colors.backgroundTertiary)
                    .cornerRadius(10)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.xs)
    }

    private var headerTitle: String {
        switch widgetType {
        case .cpu:
            return "Top CPU Processes"
        case .memory:
            return "Top Memory"
        case .network:
            return "Top Network"
        case .disk:
            return "Top Disk I/O"
        default:
            return "Top Processes"
        }
    }

    private var headerColor: Color {
        switch widgetType {
        case .cpu: return .blue
        case .memory: return DesignTokens.Colors.success
        case .network: return .cyan
        case .disk: return DesignTokens.Colors.warning
        default: return DesignTokens.Colors.accent
        }
    }

    private var emptyState: some View {
        HStack {
            Spacer()

            VStack(spacing: 6) {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(DesignTokens.Colors.textTertiary)

                Text("No process data available")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            .padding(DesignTokens.Spacing.md)

            Spacer()
        }
    }

    private var activityMonitorLink: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.leading, 56)

            Button {
                NSWorkspace.shared.launchApplication("Activity Monitor")
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 10))
                    Text("Open in Activity Monitor")
                        .font(DesignTokens.Typography.caption)
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 9))
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                }
                .foregroundColor(DesignTokens.Colors.textSecondary)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
        }
    }

    // MARK: - Computed Properties

    private var processes: [AnyProcess] {
        switch widgetType {
        case .cpu:
            return dataManager.topCPUApps.prefix(maxCount).map { AnyProcess($0) }
        case .memory:
            return dataManager.topMemoryApps.prefix(maxCount).map { AnyProcess($0) }
        case .network:
            guard let topProcesses = dataManager.networkData.topProcesses else {
                return []
            }
            return topProcesses.prefix(maxCount).map { AnyProcess($0) }
        case .disk:
            guard let primaryDisk = dataManager.diskVolumes.first(where: { $0.isBootVolume }),
                  let topProcesses = primaryDisk.topProcesses else {
                return []
            }
            return topProcesses.prefix(maxCount).map { AnyProcess($0) }
        default:
            return []
        }
    }
}

// MARK: - Process List Row

/// A row component for displaying a single process in the widget popover
struct ProcessListRow: View {
    let process: AnyProcess
    let widgetType: WidgetType
    let rank: Int

    @State private var isHovered = false

    var body: some View {
        Button {
            NSWorkspace.shared.launchApplication("Activity Monitor")
        } label: {
            HStack(spacing: DesignTokens.Spacing.sm) {
                // Rank badge
                rankBadge

                // App icon
                appIconView

                // Process info
                VStack(alignment: .leading, spacing: 2) {
                    Text(process.name)
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Text(valueLabel)
                            .font(DesignTokens.Typography.monoCaption)
                            .foregroundColor(DesignTokens.Colors.textSecondary)

                        if let percentage = percentageValue {
                            Text("(\(Int(percentage))%)")
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(DesignTokens.Colors.textTertiary)
                        }
                    }
                }

                Spacer()

                // Visual usage indicator
                usageIndicator
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            isHovered
                ? Color(nsColor: .selectedContentBackgroundColor)
                : Color.clear
        )
        .onHover { hovering in
            withAnimation(DesignTokens.Animation.fast) {
                isHovered = hovering
            }
        }
    }

    private var rankBadge: some View {
        Text("\(rank)")
            .font(DesignTokens.Typography.monoCaption)
            .foregroundColor(rankColor)
            .frame(width: 18)
    }

    private var rankColor: Color {
        switch rank {
        case 1: return DesignTokens.Colors.warning
        case 2: return Color.gray.opacity(0.7)
        case 3: return Color.orange.opacity(0.8)
        default: return DesignTokens.Colors.textTertiary
        }
    }

    private var appIconView: some View {
        Group {
            if let nsImage = process.icon {
                Image(nsImage: nsImage)
                    .resizable()
                    .frame(width: 24, height: 24)
                    .cornerRadius(5)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(DesignTokens.Colors.backgroundTertiary)
                        .frame(width: 24, height: 24)

                    Image(systemName: "app.fill")
                        .font(.system(size: 10))
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                }
            }
        }
    }

    private var valueLabel: String {
        switch widgetType {
        case .cpu:
            if let cpuUsage = process.cpuUsage {
                return "\(Int(cpuUsage))% CPU"
            }
            return "N/A"

        case .memory:
            if let memoryBytes = process.memoryBytes {
                return ByteCountFormatter.string(
                    fromByteCount: Int64(memoryBytes),
                    countStyle: .memory
                )
            }
            return "N/A"

        case .network:
            if let networkBytes = process.networkBytes, networkBytes > 0 {
                let formatter = ByteCountFormatter()
                formatter.allowedUnits = [.useKB, .useMB, .useGB]
                formatter.countStyle = .binary
                return formatter.string(fromByteCount: Int64(networkBytes))
            }
            return "N/A"

        case .disk:
            if let readBytes = process.diskReadBytes, let writeBytes = process.diskWriteBytes {
                let total = readBytes + writeBytes
                if total > 0 {
                    let formatter = ByteCountFormatter()
                    formatter.allowedUnits = [.useKB, .useMB, .useGB]
                    formatter.countStyle = .binary
                    return formatter.string(fromByteCount: Int64(total))
                }
            }
            return "N/A"

        default:
            return "N/A"
        }
    }

    private var percentageValue: Double? {
        switch widgetType {
        case .cpu:
            return process.cpuUsage

        case .memory:
            if let memoryBytes = process.memoryBytes {
                let totalMemory = WidgetDataManager.shared.memoryData.totalBytes
                if totalMemory > 0 {
                    return (Double(memoryBytes) / Double(totalMemory)) * 100
                }
            }
            return nil

        default:
            return nil
        }
    }

    private var usageIndicator: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 2)
                    .fill(DesignTokens.Colors.separator.opacity(0.4))
                    .frame(height: 4)

                // Fill
                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor)
                    .frame(width: max(0, geometry.size.width * barPercentage), height: 4)
            }
        }
        .frame(width: 60, height: 4)
    }

    private var barPercentage: Double {
        switch widgetType {
        case .cpu:
            if let cpuUsage = process.cpuUsage {
                return min(cpuUsage / 100, 1.0)
            }
            return 0

        case .memory:
            if let memoryBytes = process.memoryBytes {
                let totalMemory = WidgetDataManager.shared.memoryData.totalBytes
                if totalMemory > 0 {
                    return min(Double(memoryBytes) / Double(totalMemory), 1.0)
                }
            }
            return 0

        case .network:
            if let networkBytes = process.networkBytes, networkBytes > 0 {
                let logValue = log(Double(networkBytes) + 1)
                let maxLog = log(100_000_000.0)
                return min(logValue / maxLog, 1.0)
            }
            return 0

        case .disk:
            if let readBytes = process.diskReadBytes, let writeBytes = process.diskWriteBytes {
                let total = readBytes + writeBytes
                if total > 0 {
                    let logValue = log(Double(total) + 1)
                    let maxLog = log(100_000_000.0)
                    return min(logValue / maxLog, 1.0)
                }
            }
            return 0

        default:
            return 0
        }
    }

    private var barColor: Color {
        let percentage = barPercentage
        switch percentage {
        case 0..<0.5: return DesignTokens.Colors.success
        case 0.5..<0.8: return DesignTokens.Colors.warning
        default: return DesignTokens.Colors.error
        }
    }
}

// MARK: - Any Process Type Erasure

/// Type-erased wrapper for different process types
struct AnyProcess: Identifiable {
    let id: String // Use String for Hashable conformance
    let name: String
    let icon: NSImage?
    let cpuUsage: Double?
    let memoryBytes: UInt64?
    let networkBytes: UInt64?
    let diskReadBytes: UInt64?
    let diskWriteBytes: UInt64?

    init(_ app: AppResourceUsage) {
        self.id = app.id.uuidString
        self.name = app.name
        self.icon = app.icon
        self.cpuUsage = app.cpuUsage
        self.memoryBytes = app.memoryBytes
        self.networkBytes = nil
        self.diskReadBytes = nil
        self.diskWriteBytes = nil
    }

    init(_ process: ProcessUsage) {
        self.id = String(process.id)
        self.name = process.name
        self.icon = process.icon()
        self.cpuUsage = process.cpuUsage
        self.memoryBytes = process.memoryUsage
        self.networkBytes = process.networkBytes
        self.diskReadBytes = process.diskReadBytes
        self.diskWriteBytes = process.diskWriteBytes
    }

    init(_ networkProcess: ProcessNetworkUsage) {
        self.id = networkProcess.id.uuidString
        self.name = networkProcess.name
        self.icon = nil
        self.cpuUsage = nil
        self.memoryBytes = nil
        self.networkBytes = networkProcess.totalBytes
        self.diskReadBytes = nil
        self.diskWriteBytes = nil
    }
}

// MARK: - Preview

#Preview("CPU Process List") {
    ProcessListWidgetView(widgetType: .cpu, maxCount: 5)
        .frame(width: 280)
        .padding()
}

#Preview("Memory Process List") {
    ProcessListWidgetView(widgetType: .memory, maxCount: 5)
        .frame(width: 280)
        .padding()
}
