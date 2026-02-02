//
//  NetworkPopoverView.swift
//  Tonic
//
//  Stats Master-style Network popover with:
//  - Real-time speed boxes (Download/Upload)
//  - Usage history dual-line chart
//  - Connectivity history grid
//  - Details section (total upload/download, status, latency)
//  - Interface section (WiFi info, MAC address)
//  - Address section (local IP, public IP)
//  - Top processes section
//

import SwiftUI

// MARK: - Network Popover View

/// Complete Stats Master-style network popover
public struct NetworkPopoverView: View {

    // MARK: - Properties

    @State private var dataManager = WidgetDataManager.shared

    // Colors matching Stats Master
    private let downloadColor = Color(red: 0.2, green: 0.5, blue: 1.0)  // Blue
    private let uploadColor = Color(red: 1.0, green: 0.3, blue: 0.2)     // Red

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            ScrollView {
                VStack(spacing: PopoverConstants.sectionSpacing) {
                    // Real-Time Speed Dashboard
                    speedDashboardSection

                    Divider()

                    // Usage History Chart
                    usageHistorySection

                    Divider()

                    // Connectivity History Grid
                    connectivityHistorySection

                    Divider()

                    // Details Section
                    detailsSection

                    Divider()

                    // Interface Section
                    interfaceSection

                    Divider()

                    // Address Section
                    addressSection

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
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: PopoverConstants.iconTextGap) {
            // Icon
            Image(systemName: PopoverConstants.Icons.network)
                .font(.title2)
                .foregroundColor(DesignTokens.Colors.accent)

            // Title
            Text("Network")
                .font(PopoverConstants.headerTitleFont)
                .foregroundColor(DesignTokens.Colors.textPrimary)

            Spacer()
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Real-Time Speed Dashboard

    /// Dashboard with large Download/Upload speed boxes
    /// Matches Stats Master's topValueView layout
    private var speedDashboardSection: some View {
        HStack(spacing: 0) {
            // Download side (left)
            speedBox(
                title: "Downloading",
                value: formattedSpeed(dataManager.networkData.downloadBytesPerSecond),
                color: downloadColor,
                isActive: dataManager.networkData.downloadBytesPerSecond > 0
            )

            Spacer()

            // Upload side (right)
            speedBox(
                title: "Uploading",
                value: formattedSpeed(dataManager.networkData.uploadBytesPerSecond),
                color: uploadColor,
                isActive: dataManager.networkData.uploadBytesPerSecond > 0
            )
        }
        .frame(height: 90)
    }

    private func speedBox(title: String, value: String, color: Color, isActive: Bool) -> some View {
        VStack(spacing: PopoverConstants.compactSpacing) {
            // Title with indicator dot
            HStack(spacing: 4) {
                IndicatorDot(color: isActive ? color : Color.gray.opacity(0.3))
                Text(title)
                    .font(.system(size: 11))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }

            // Large value
            Text(value)
                .font(.system(size: 26, weight: .light, design: .rounded))
                .foregroundColor(DesignTokens.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Usage History Chart

    /// Dual-line chart showing download (blue) and upload (red) history
    /// Matches Stats Master's NetworkChartView
    private var usageHistorySection: some View {
        VStack(alignment: .leading, spacing: PopoverConstants.itemSpacing) {
            PopoverSectionHeader(title: "Usage history")

            // Chart container with background
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: PopoverConstants.smallCornerRadius)
                    .fill(Color.gray.opacity(0.1))

                // Dual-line chart
                DualLineChartView(
                    downloadData: dataManager.networkDownloadHistory,
                    uploadData: dataManager.networkUploadHistory,
                    downloadColor: downloadColor,
                    uploadColor: uploadColor
                )
            }
            .frame(height: 90)
        }
    }

    // MARK: - Connectivity History Grid

    /// Grid of green/red squares showing connectivity status over time
    /// Matches Stats Master's GridChartView
    private var connectivityHistorySection: some View {
        VStack(alignment: .leading, spacing: PopoverConstants.itemSpacing) {
            PopoverSectionHeader(title: "Connectivity history")

            // Grid container with background
            ZStack {
                RoundedRectangle(cornerRadius: PopoverConstants.smallCornerRadius)
                    .fill(Color.gray.opacity(0.1))

                ConnectivityGridView(
                    isConnected: dataManager.networkData.isConnected,
                        history: dataManager.connectivityHistory
                )
            }
            .frame(height: 30)
        }
    }

    // MARK: - Details Section

    /// Shows total upload/download, status, latency, jitter
    /// Matches Stats Master's Details section
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: PopoverConstants.itemSpacing) {
            HStack {
                PopoverSectionHeader(title: "Details")

                Spacer()

                // Reset button
                Button {
                    resetTotalUsage()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: PopoverConstants.compactSpacing) {
                // Total upload (red indicator)
                detailRow(
                    label: "Total upload",
                    value: formattedTotalBytes(dataManager.totalUploadBytes),
                    color: uploadColor
                )

                // Total download (blue indicator)
                detailRow(
                    label: "Total download",
                    value: formattedTotalBytes(dataManager.totalDownloadBytes),
                    color: downloadColor
                )

                // Status
                IconLabelRow(
                    icon: "circle.fill",
                    label: "Status",
                    value: dataManager.networkData.isConnected ? "UP" : "DOWN",
                    valueColor: dataManager.networkData.isConnected ? .green : .red,
                    iconColor: dataManager.networkData.isConnected ? .green : .red
                )

                // Internet connection
                IconLabelRow(
                    icon: "globe",
                    label: "Internet",
                    value: dataManager.networkData.isConnected ? "Connected" : "Disconnected",
                    valueColor: dataManager.networkData.isConnected ? DesignTokens.Colors.textPrimary : .secondary
                )

                // Latency (if available)
                if let connectivity = dataManager.networkData.connectivity {
                    IconLabelRow(
                        icon: "speedometer",
                        label: "Latency",
                        value: "\(Int(connectivity.latency)) ms"
                    )

                    // Jitter (if available)
                    if connectivity.jitter > 0 {
                        IconLabelRow(
                            icon: "waveform",
                            label: "Jitter",
                            value: "\(Int(connectivity.jitter)) ms"
                        )
                    }
                }
            }
        }
    }

    private func detailRow(label: String, value: String, color: Color) -> some View {
        HStack(spacing: PopoverConstants.iconTextGap) {
            IndicatorDot(color: color)
            Text(label)
                .font(PopoverConstants.smallLabelFont)
                .foregroundColor(DesignTokens.Colors.textSecondary)
            Spacer()
            Text(value)
                .font(PopoverConstants.smallValueFont)
                .foregroundColor(DesignTokens.Colors.textPrimary)
        }
    }

    // MARK: - Interface Section

    /// Shows network interface info, MAC address, WiFi details
    /// Matches Stats Master's Interface section
    private var interfaceSection: some View {
        VStack(alignment: .leading, spacing: PopoverConstants.itemSpacing) {
            HStack {
                PopoverSectionHeader(title: "Interface")
                Spacer()
                // Details toggle indicator (future enhancement)
            }

            VStack(spacing: PopoverConstants.compactSpacing) {
                // Interface name
                IconLabelRow(
                    icon: "network",
                    label: "Interface",
                    value: interfaceName
                )

                // Status
                IconLabelRow(
                    icon: "circle.fill",
                    label: "Status",
                    value: dataManager.networkData.isConnected ? "UP" : "DOWN",
                    valueColor: dataManager.networkData.isConnected ? .green : .red,
                    iconColor: dataManager.networkData.isConnected ? .green : .red
                )

                // MAC address placeholder (would need enhanced data)
                IconLabelRow(
                    icon: "person.text.rectangle",
                    label: "Physical address",
                    value: "Not Available"
                )

                // WiFi details (if available)
                if let wifi = dataManager.networkData.wifiDetails {
                    wifiDetailsSection(wifi)
                }
            }
        }
    }

    private var interfaceName: String {
        if let ssid = dataManager.networkData.ssid {
            return "Wi-Fi (\(ssid))"
        }
        return dataManager.networkData.connectionType.displayName
    }

    private func wifiDetailsSection(_ wifi: WiFiDetails) -> some View {
        Group {
            // Network name/SSID
            IconLabelRow(
                icon: "wifi",
                label: "Network",
                value: wifi.ssid
            )

            // RSSI (signal strength)
            IconLabelRow(
                icon: "antenna.radiowaves.left.and.right",
                label: "Signal",
                value: "\(wifi.rssi) dBm",
                valueColor: rssiColor(wifi.rssi)
            )

            // Channel
            IconLabelRow(
                icon: "sapphic",
                label: "Channel",
                value: "\(wifi.channel)"
            )
        }
    }

    private func rssiColor(_ rssi: Int) -> Color {
        switch rssi {
        case -50...0: return .green       // Excellent
        case -60..<(-50): return .yellow   // Good
        case -70..<(-60): return .orange   // Fair
        default: return .red              // Poor
        }
    }

    // MARK: - Address Section

    /// Shows local IP and public IP addresses
    /// Matches Stats Master's Address section
    private var addressSection: some View {
        VStack(alignment: .leading, spacing: PopoverConstants.itemSpacing) {
            HStack {
                PopoverSectionHeader(title: "Address")
                Spacer()
                // Refresh button (future enhancement)
            }

            VStack(spacing: PopoverConstants.compactSpacing) {
                // Local IP
                IconLabelRow(
                    icon: "building.2",
                    label: "Local IP",
                    value: dataManager.networkData.ipAddress ?? "Unknown",
                    valueColor: .blue
                )

                // Public IP (if available)
                if let publicIP = dataManager.networkData.publicIP {
                    IconLabelRow(
                        icon: "globe",
                        label: "Public IP",
                        value: publicIP.ipAddress,
                        valueColor: .blue
                    )

                    // Country (if available)
                    if let country = publicIP.country {
                        IconLabelRow(
                            icon: "flag",
                            label: "Location",
                            value: country
                        )
                    }
                }
            }
        }
    }

    // MARK: - Top Processes Section

    /// Shows top network-using processes
    /// Matches Stats Master's Top processes section
    private var topProcessesSection: some View {
        VStack(alignment: .leading, spacing: PopoverConstants.itemSpacing) {
            PopoverSectionHeader(title: "Top processes")

            if let processes = dataManager.networkData.topProcesses, !processes.isEmpty {
                VStack(spacing: PopoverConstants.compactSpacing) {
                    ForEach(processes.prefix(8)) { process in
                        NetworkProcessRow(
                            process: process,
                            downloadColor: downloadColor,
                            uploadColor: uploadColor
                        )
                    }
                }
            } else {
                EmptyStateView(
                    icon: "arrow.up.arrow.down",
                    title: "No process data available"
                )
            }
        }
    }

    // MARK: - Helper Methods

    private func formattedSpeed(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond < 1024 {
            return "\(Int(bytesPerSecond)) B/s"
        } else if bytesPerSecond < 1024 * 1024 {
            return String(format: "%.1f KB/s", bytesPerSecond / 1024)
        } else {
            return String(format: "%.2f MB/s", bytesPerSecond / (1024 * 1024))
        }
    }

    private func formattedTotalBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func resetTotalUsage() {
        // Post notification to reset totals
        NotificationCenter.default.post(name: Notification.Name.resetTotalNetworkUsage, object: nil)
    }
}

// MARK: - Dual Line Chart View

/// Dual-line chart for download/upload history
/// Matches Stats Master's NetworkChartView with red (upload) and blue (download) lines
struct DualLineChartView: View {
    let downloadData: [Double]
    let uploadData: [Double]
    let downloadColor: Color
    let uploadColor: Color

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height

            ZStack {
                // Download line (blue) - drawn first so it's behind
                if !downloadData.isEmpty {
                    linePath(for: downloadData, width: width, height: height)
                        .stroke(downloadColor, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                }

                // Upload line (red) - drawn on top
                if !uploadData.isEmpty {
                    linePath(for: uploadData, width: width, height: height)
                        .stroke(uploadColor, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                }
            }
        }
    }

    private func linePath(for data: [Double], width: CGFloat, height: CGFloat) -> Path {
        var path = Path()

        guard !data.isEmpty else { return path }

        let maxPoints = 180
        let displayData = Array(data.suffix(maxPoints))

        guard let maxVal = displayData.max(), maxVal > 0 else {
            // Flat line at bottom
            path.move(to: CGPoint(x: 0, y: height))
            path.addLine(to: CGPoint(x: width, y: height))
            return path
        }

        let stepX = width / max(1, CGFloat(displayData.count - 1))

        for (index, value) in displayData.enumerated() {
            let x = CGFloat(index) * stepX
            let normalizedY = 1 - (value / maxVal)
            let y = normalizedY * (height - 4) + 2  // Padding

            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        return path
    }
}

// MARK: - Connectivity Grid View

/// Grid of colored squares showing connectivity status history
/// Matches Stats Master's GridChartView (30 columns x 3 rows)
struct ConnectivityGridView: View {
    let isConnected: Bool
    let history: [Bool]

    private let columns = 30
    private let rows = 3

    var body: some View {
        GeometryReader { geometry in
            let cellWidth = geometry.size.width / CGFloat(columns)
            let cellHeight = geometry.size.height / CGFloat(rows)

            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(cellWidth), spacing: 1), count: columns),
                spacing: 1
            ) {
                // Display current status + history (90 data points = 30x3 grid)
                ForEach(0..<(columns * rows), id: \.self) { index in
                    let status = statusForIndex(index)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(status ? Color.green : Color.red.opacity(0.5))
                        .frame(width: cellWidth - 1, height: cellHeight - 1)
                }
            }
        }
        .padding(2)
    }

    private func statusForIndex(_ index: Int) -> Bool {
        let totalSlots = columns * rows
        let historyCount = history.count

        if index == 0 {
            // First cell shows current status
            return isConnected
        } else if index - 1 < historyCount {
            // Remaining cells show history
            return history.reversed()[index - 1]
        } else {
            // Fill remaining with current status
            return isConnected
        }
    }
}

// MARK: - Network Process Row

/// Row showing network process with download/upload speeds
struct NetworkProcessRow: View {
    let process: ProcessNetworkUsage
    let downloadColor: Color
    let uploadColor: Color

    var body: some View {
        HStack(spacing: PopoverConstants.itemSpacing) {
            // App icon placeholder
            Image(systemName: "app.fill")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .frame(width: PopoverConstants.appIconSize, height: PopoverConstants.appIconSize)

            // Process name
            Text(process.name)
                .font(PopoverConstants.smallLabelFont)
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .frame(width: 70, alignment: .leading)
                .lineLimit(1)
                .truncationMode(.tail)

            // Download speed indicator
            HStack(spacing: 2) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 6))
                    .foregroundColor(downloadColor)
                Text(formattedBytes(process.downloadBytes))
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(downloadColor)
            }
            .frame(width: 50, alignment: .leading)

            // Upload speed indicator
            HStack(spacing: 2) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 6))
                    .foregroundColor(uploadColor)
                Text(formattedBytes(process.uploadBytes))
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(uploadColor)
            }
            .frame(width: 50, alignment: .leading)

            Spacer()
        }
    }

    private func formattedBytes(_ bytes: UInt64) -> String {
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f K", Double(bytes) / 1024)
        } else {
            return String(format: "%.2f M", Double(bytes) / (1024 * 1024))
        }
    }
}

// MARK: - Preview

#Preview("Network Popover") {
    NetworkPopoverView()
}
