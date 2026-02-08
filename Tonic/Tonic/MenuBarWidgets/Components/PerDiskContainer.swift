//
//  PerDiskContainer.swift
//  Tonic
//
//  Per-disk container with dual-line read/write charts for Stats Master parity
//  Task ID: fn-8-v3b.8
//

import SwiftUI

// MARK: - Per Disk Container

/// Container view for a single disk with dual-line read/write chart and expandable details
/// Matches Stats Master's per-disk popup pattern
///
/// Features:
/// - Title bar with disk name and used percentage badge
/// - Dual-line chart (120px height) showing read (blue) and write (red) rates
/// - Expandable details panel with capacity, rates, I/O counts, and timing stats
public struct PerDiskContainer: View {

    // MARK: - Properties

    let diskData: DiskVolumeData
    let readHistory: [Double]   // Read rate history (MB/s)
    let writeHistory: [Double]  // Write rate history (MB/s)

    @State private var isDetailsExpanded: Bool = false

    // MARK: - Constants

    private static let titleBarHeight: CGFloat = 24
    private static let chartHeight: CGFloat = 120

    // Colors matching Stats Master
    private let readColor = Color(nsColor: NSColor(red: 0.2, green: 0.5, blue: 1.0, alpha: 1.0))  // Blue
    private let writeColor = Color(nsColor: NSColor(red: 1.0, green: 0.3, blue: 0.2, alpha: 1.0)) // Red

    // MARK: - Initializer

    public init(
        diskData: DiskVolumeData,
        readHistory: [Double] = [],
        writeHistory: [Double] = []
    ) {
        self.diskData = diskData
        self.readHistory = readHistory
        self.writeHistory = writeHistory
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: PopoverConstants.itemSpacing) {
            // Title bar
            titleBar

            // Chart section
            chartSection

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
            // Disk icon
            Image(systemName: PopoverConstants.Icons.disk)
                .font(.system(size: 11))
                .foregroundColor(DesignTokens.Colors.textSecondary)

            // Disk name
            Text(diskData.name)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .lineLimit(1)

            Spacer()

            // Used percentage badge
            usedPercentageBadge

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

    private var usedPercentageBadge: some View {
        Text("\(Int(diskData.usagePercentage))%")
            .font(.system(size: 9, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(usageColor)
            .cornerRadius(4)
    }

    private var usageColor: Color {
        PopoverConstants.percentageColor(diskData.usagePercentage)
    }

    // MARK: - Chart Section

    private var chartSection: some View {
        VStack(spacing: PopoverConstants.compactSpacing) {
            // Chart legend
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(readColor)
                        .frame(width: 8, height: 8)
                    Text("Read")
                        .font(.system(size: 9))
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }

                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(writeColor)
                        .frame(width: 8, height: 8)
                    Text("Write")
                        .font(.system(size: 9))
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }

                Spacer()
            }

            // Dual-line chart
            dualLineChart
        }
    }

    private var dualLineChart: some View {
        Group {
            if readHistory.isEmpty && writeHistory.isEmpty {
                HStack {
                    Spacer()
                    Text("No I/O history")
                        .font(PopoverConstants.processValueFont)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                    Spacer()
                }
                .frame(height: 30)
                .background(Color(nsColor: .lightGray).opacity(0.05))
                .cornerRadius(3)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(nsColor: .lightGray).opacity(0.1))

                    DiskDualLineChartView(
                        readData: readHistory,
                        writeData: writeHistory,
                        readColor: readColor,
                        writeColor: writeColor
                    )
                    .padding(.vertical, 2)
                }
                .frame(height: Self.chartHeight)
            }
        }
    }

    // MARK: - Details Panel

    private var detailsPanel: some View {
        VStack(spacing: PopoverConstants.compactSpacing) {
            Divider()

            // Capacity section
            detailsSection("Capacity", items: [
                ("Total", formattedBytes(diskData.totalBytes)),
                ("Used", formattedBytes(diskData.usedBytes)),
                ("Free", formattedBytes(diskData.freeBytes))
            ])

            // Transfer rates section
            if let readRate = diskData.readBytesPerSecond, let writeRate = diskData.writeBytesPerSecond {
                detailsSection("Transfer Rate", items: [
                    ("Read", formattedBytesPerSecond(readRate)),
                    ("Write", formattedBytesPerSecond(writeRate))
                ])
            }

            // I/O operations section (if available)
            if let readIOPS = diskData.readIOPS, let writeIOPS = diskData.writeIOPS {
                detailsSection("I/O Operations", items: [
                    ("Read/s", "\(Int(readIOPS))"),
                    ("Write/s", "\(Int(writeIOPS))")
                ])
            }

            // I/O timing section (if available)
            if let readTime = diskData.readTime, let writeTime = diskData.writeTime {
                detailsSection("I/O Timing", items: [
                    ("Read Time", formattedTime(readTime)),
                    ("Write Time", formattedTime(writeTime))
                ])
            }

            // SMART data section (if available)
            if let smart = diskData.smartData {
                smartDataSection(smart)
            }
        }
        .padding(.top, PopoverConstants.compactSpacing)
    }

    private func detailsSection(_ title: String, items: [(String, String)]) -> some View {
        VStack(spacing: PopoverConstants.compactSpacing) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: PopoverConstants.compactSpacing) {
                ForEach(items, id: \.0) { item in
                    detailItem(item.0, value: item.1)
                }
            }
        }
    }

    private func smartDataSection(_ smart: NVMeSMARTData) -> some View {
        VStack(spacing: PopoverConstants.compactSpacing) {
            Text("SMART Health")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: PopoverConstants.compactSpacing) {
                // Temperature (optional)
                if let temp = smart.temperature {
                    detailItem("Temperature", value: "\(Int(temp))°C", color: PopoverConstants.temperatureColor(temp))
                } else {
                    detailItem("Temperature", value: "N/A")
                }

                // Percentage used (optional)
                if let pctUsed = smart.percentageUsed {
                    let usedColor = pctUsed > 90 ? Color.red : (pctUsed > 75 ? Color.orange : Color.green)
                    detailItem("Used", value: "\(Int(pctUsed))%", color: usedColor)
                } else {
                    detailItem("Used", value: "N/A")
                }

                // Critical warning
                detailItem("Critical", value: smart.criticalWarning ? "Yes" : "No", color: smart.criticalWarning ? Color.red : Color.green)

                // Power-on hours
                detailItem("Power On", value: smart.powerOnTimeString)

                // Power cycles
                detailItem("Cycles", value: smart.powerCycles > 0 ? "\(smart.powerCycles)" : "N/A")

                // Data read (optional)
                if let dataRead = smart.dataReadString {
                    detailItem("Data Read", value: dataRead)
                }

                // Data written (optional)
                if let dataWritten = smart.dataWrittenString {
                    detailItem("Data Written", value: dataWritten)
                }
            }
        }
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

    // MARK: - Formatting Helpers

    private func formattedBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }

    private func formattedBytesPerSecond(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond < 1024 {
            return "\(Int(bytesPerSecond)) B/s"
        } else if bytesPerSecond < 1024 * 1024 {
            return String(format: "%.1f KB/s", bytesPerSecond / 1024)
        } else if bytesPerSecond < 1024 * 1024 * 1024 {
            return String(format: "%.2f MB/s", bytesPerSecond / (1024 * 1024))
        } else {
            return String(format: "%.2f GB/s", bytesPerSecond / (1024 * 1024 * 1024))
        }
    }

    private func formattedTime(_ timeMs: TimeInterval) -> String {
        // timeMs is in milliseconds from IOKit timing stats
        if timeMs < 1 {
            return "< 1 ms"
        } else if timeMs < 1000 {
            return "\(Int(timeMs)) ms"
        } else {
            let seconds = timeMs / 1000
            return String(format: "%.2f s", seconds)
        }
    }
}

// MARK: - Disk Dual Line Chart View

/// Dual-line chart for disk read/write rates
/// Uses shared max value for proper visual comparison between read and write
struct DiskDualLineChartView: View {
    let readData: [Double]
    let writeData: [Double]
    let readColor: Color
    let writeColor: Color

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height

            // Compute shared max for both series to enable visual comparison
            let maxPoints = 180
            let displayRead = Array(readData.suffix(maxPoints))
            let displayWrite = Array(writeData.suffix(maxPoints))
            let sharedMax = max(displayRead.max() ?? 0, displayWrite.max() ?? 0, 0.1)

            ZStack {
                if !displayRead.isEmpty {
                    linePath(for: displayRead, width: width, height: height, maxValue: sharedMax)
                        .stroke(readColor, lineWidth: 1.5)
                }

                if !displayWrite.isEmpty {
                    linePath(for: displayWrite, width: width, height: height, maxValue: sharedMax)
                        .stroke(writeColor, lineWidth: 1.5)
                }
            }
        }
    }

    private func linePath(for data: [Double], width: CGFloat, height: CGFloat, maxValue: Double) -> Path {
        var path = Path()

        guard !data.isEmpty else { return path }

        guard maxValue > 0 else {
            path.move(to: CGPoint(x: 0, y: height - 1))
            path.addLine(to: CGPoint(x: width, y: height - 1))
            return path
        }

        let stepX = width / max(1, CGFloat(data.count - 1))

        for (index, value) in data.enumerated() {
            let x = CGFloat(index) * stepX
            let normalizedY = 1 - (value / maxValue)
            let y = normalizedY * (height - 4) + 2  // Small padding

            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        return path
    }
}

// MARK: - Preview

#Preview("Per Disk Container") {
    VStack(spacing: 16) {
        // Sample disk with all data
        PerDiskContainer(
            diskData: DiskVolumeData(
                name: "Macintosh HD",
                path: "/",
                usedBytes: 500_000_000_000,
                totalBytes: 1_000_000_000_000,
                isBootVolume: true,
                isInternal: true,
                isActive: true,
                smartData: NVMeSMARTData(
                    temperature: 45,
                    percentageUsed: 25,
                    criticalWarning: false,
                    powerCycles: 420,
                    powerOnHours: 8760,
                    dataReadBytes: 2_000_000_000_000,
                    dataWrittenBytes: 1_500_000_000_000
                ),
                readIOPS: 1250,
                writeIOPS: 840,
                readBytesPerSecond: 52_428_800,  // ~50 MB/s
                writeBytesPerSecond: 20_971_520  // ~20 MB/s
            ),
            readHistory: [0, 5, 12, 8, 15, 20, 18, 25, 30, 28, 35, 40, 38, 45, 42, 50, 48, 52, 50, 48],
            writeHistory: [0, 2, 8, 5, 10, 12, 8, 15, 18, 15, 20, 22, 18, 25, 20, 28, 25, 30, 28, 25]
        )

        // External disk without SMART data
        PerDiskContainer(
            diskData: DiskVolumeData(
                name: "External Drive",
                path: "/Volumes/External",
                usedBytes: 1_500_000_000_000,
                totalBytes: 2_000_000_000_000,
                isBootVolume: false,
                isInternal: false,
                isActive: false,
                readIOPS: 150,
                writeIOPS: 80,
                readBytesPerSecond: 10_485_760,  // ~10 MB/s
                writeBytesPerSecond: 5_242_880   // ~5 MB/s
            ),
            readHistory: [0, 2, 5, 3, 8, 10, 8, 12, 15, 12, 18, 20, 18, 22, 20, 25, 22, 28, 25, 22],
            writeHistory: [0, 1, 3, 2, 5, 6, 4, 8, 10, 8, 12, 14, 12, 15, 12, 18, 15, 20, 18, 15]
        )

        // Disk with minimal data
        PerDiskContainer(
            diskData: DiskVolumeData(
                name: "Time Machine",
                path: "/Volumes/TimeMachine",
                usedBytes: 800_000_000_000,
                totalBytes: 2_000_000_000_000,
                isBootVolume: false,
                isInternal: false,
                isActive: false
            ),
            readHistory: [],
            writeHistory: []
        )
    }
    .padding()
    .background(Color(nsColor: .windowBackgroundColor))
}
