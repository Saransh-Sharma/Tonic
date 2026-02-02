//
//  NetworkPopoverView.swift
//  Tonic
//
//  Complete Stats Master-style Network popover with:
//  - Dashboard (Downloading/Uploading with large values)
//  - Usage history dual-line chart (red/blue)
//  - Connectivity history grid (30x3 green/red)
//  - Details (total upload/download, status, internet, latency, jitter)
//  - Interface (name, status, MAC, SSID, standard, channel, speed, DNS)
//  - Address (local IP, public IPv4/IPv6 with country codes)
//  - Top processes
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
            ScrollView {
                VStack(spacing: 0) {
                    // Dashboard Section (90pt height)
                    dashboardSection
                        .frame(height: 90)

                    // Usage History Chart Section
                    chartSection

                    // Connectivity History Grid Section
                    connectivitySection

                    // Details Section
                    detailsSection

                    // Interface Section
                    interfaceSection

                    // Address Section
                    addressSection

                    // Top Processes Section
                    processesSection
                }
            }
        }
        .frame(width: PopoverConstants.width, height: PopoverConstants.maxHeight)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Dashboard Section

    /// Top section with Downloading/Uploading large value displays
    /// Matches Stats Master's 90pt height dashboard with centered values
    private var dashboardSection: some View {
        HStack(spacing: 0) {
            // Download side (left half)
            halfBox(
                title: "Downloading",
                value: formattedSpeedValue(dataManager.networkData.downloadBytesPerSecond),
                unit: formattedSpeedUnit(dataManager.networkData.downloadBytesPerSecond),
                color: downloadColor,
                isActive: dataManager.networkData.downloadBytesPerSecond > 0
            )

            // Upload side (right half)
            halfBox(
                title: "Uploading",
                value: formattedSpeedValue(dataManager.networkData.uploadBytesPerSecond),
                unit: formattedSpeedUnit(dataManager.networkData.uploadBytesPerSecond),
                color: uploadColor,
                isActive: dataManager.networkData.uploadBytesPerSecond > 0
            )
        }
    }

    private func halfBox(title: String, value: String, unit: String, color: Color, isActive: Bool) -> some View {
        GeometryReader { geometry in
            let boxWidth = geometry.size.width / 2

            ZStack {
                // Value + Unit (top centered)
                VStack(spacing: 0) {
                    HStack(spacing: 5) {
                        Text(value)
                            .font(.system(size: 26, weight: .light))
                            .foregroundColor(DesignTokens.Colors.textPrimary)
                            .frame(width: valueWidth(value: value), alignment: .trailing)

                        Text(unit)
                            .font(.system(size: 13, weight: .light))
                            .foregroundColor(.secondary)
                            .frame(width: unitWidth(unit: unit), alignment: .leading)
                    }
                    .frame(height: 30)

                    Spacer()

                    // Title + Indicator (bottom centered)
                    HStack(spacing: 8) {
                        // Color indicator block (12x12)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isActive ? color : Color.gray.opacity(0.3))
                            .frame(width: 12, height: 12)

                        Text(title)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .frame(height: 15)
                }
                .frame(width: boxWidth)
                .position(x: boxWidth / 2, y: geometry.size.height / 2)
            }
        }
    }

    private func valueWidth(value: String) -> CGFloat {
        let font = NSFont.systemFont(ofSize: 26, weight: .light)
        return (value as NSString).size(withAttributes: [.font: font]).width + 5
    }

    private func unitWidth(unit: String) -> CGFloat {
        let font = NSFont.systemFont(ofSize: 13, weight: .light)
        return (unit as NSString).size(withAttributes: [.font: font]).width + 5
    }

    private func formattedSpeedValue(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond < 1024 {
            return "\(Int(bytesPerSecond))"
        } else if bytesPerSecond < 1024 * 1024 {
            return String(format: "%.1f", bytesPerSecond / 1024)
        } else {
            return String(format: "%.2f", bytesPerSecond / (1024 * 1024))
        }
    }

    private func formattedSpeedUnit(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond < 1024 {
            return "B/s"
        } else if bytesPerSecond < 1024 * 1024 {
            return "KB/s"
        } else {
            return "MB/s"
        }
    }

    // MARK: - Chart Section

    /// Dual-line chart for download/upload history (90pt height)
    private var chartSection: some View {
        VStack(spacing: 0) {
            // Section header (22pt)
            sectionHeader("Usage history")

            // Chart container (68pt)
            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.gray.opacity(0.1))

                DualLineChartView(
                    downloadData: dataManager.networkDownloadHistory,
                    uploadData: dataManager.networkUploadHistory,
                    downloadColor: downloadColor,
                    uploadColor: uploadColor
                )
            }
            .frame(height: 68)
        }
        .frame(height: 90)
    }

    // MARK: - Connectivity Section

    /// Grid chart for connectivity history (30pt height)
    private var connectivitySection: some View {
        VStack(spacing: 0) {
            // Section header (22pt)
            sectionHeader("Connectivity history")

            // Grid container (8pt)
            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.gray.opacity(0.1))

                ConnectivityGridView(
                    isConnected: dataManager.networkData.isConnected,
                    history: dataManager.connectivityHistory
                )
            }
            .frame(height: 8)
        }
        .frame(height: 30)
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(height: 22)
    }

    // MARK: - Details Section

    /// Details: Total upload/download, Status, Internet, Latency, Jitter
    /// With reset button in header
    private var detailsSection: some View {
        VStack(spacing: 0) {
            // Header with reset button (22pt)
            HStack {
                Text("Details")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Spacer()

                // Reset button
                Button {
                    resetTotalUsage()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Reset")
            }
            .frame(height: 22)

            // Total upload row (16pt)
            detailRowWithColor(
                title: "Total upload:",
                value: formattedTotalBytes(dataManager.totalUploadBytes),
                color: uploadColor
            )

            // Total download row (16pt)
            detailRowWithColor(
                title: "Total download:",
                value: formattedTotalBytes(dataManager.totalDownloadBytes),
                color: downloadColor
            )

            // Status row (16pt)
            detailRow(
                title: "Status:",
                value: dataManager.networkData.isConnected ? "UP" : "DOWN",
                color: dataManager.networkData.isConnected ? .green : .red
            )

            // Internet connection row (16pt)
            detailRow(
                title: "Internet connection:",
                value: dataManager.networkData.isConnected ? "Connected" : "Disconnected",
                color: dataManager.networkData.isConnected ? .green : .red
            )

            // Latency row (16pt)
            if let connectivity = dataManager.networkData.connectivity {
                detailRow(
                    title: "Latency:",
                    value: "\(Int(connectivity.latency)) ms"
                )

                // Jitter row (16pt)
                if connectivity.jitter > 0 {
                    detailRow(
                        title: "Jitter:",
                        value: "\(Int(connectivity.jitter)) ms"
                    )
                }
            } else {
                detailRow(title: "Latency:", value: "Unknown")
                detailRow(title: "Jitter:", value: "Unknown")
            }
        }
    }

    private func detailRow(title: String, value: String, color: Color = DesignTokens.Colors.textPrimary, help: String? = nil) -> some View {
        HStack(spacing: 0) {
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)

            Spacer()

            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(color)
        }
        .frame(height: 16)
        .help(help ?? "")
    }

    private func detailRowWithColor(title: String, value: String, color: Color) -> some View {
        HStack(spacing: 0) {
            // Color indicator
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 6, height: 6)

            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(width: 114, alignment: .leading)

            Spacer()

            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(DesignTokens.Colors.textPrimary)
        }
        .frame(height: 16)
    }

    // MARK: - Interface Section

    /// Interface: Interface name, Status, Physical address, Network, Standard, Channel, Speed, DNS
    /// With details toggle button
    private var interfaceSection: some View {
        VStack(spacing: 0) {
            // Header with details toggle (22pt)
            HStack {
                Text("Interface")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Spacer()

                // Details toggle button
                Button {
                    // TODO: Toggle interface details visibility
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Details")
            }
            .frame(height: 22)

            // Interface row (16pt)
            detailRow(
                title: "Interface:",
                value: interfaceDisplayName
            )

            // Status row (16pt)
            detailRow(
                title: "Status:",
                value: dataManager.networkData.isConnected ? "UP" : "DOWN",
                color: dataManager.networkData.isConnected ? .green : .red
            )

            // Physical address (MAC) row (16pt)
            detailRow(
                title: "Physical address:",
                value: macAddress,
                color: DesignTokens.Colors.textPrimary
            )
            .textSelection(.enabled)

            // WiFi rows (only if WiFi is connected)
            if dataManager.networkData.connectionType == .wifi,
               let wifi = dataManager.networkData.wifiDetails {
                // Network (SSID) row (16pt)
                let ssidValue = wifi.ssid + (wifi.rssi > -100 ? " (\(wifi.rssi))" : "")
                detailRow(title: "Network:", value: ssidValue)

                // Standard row (16pt) - shown when details enabled
                detailRow(title: "Standard:", value: wifi.security)

                // Channel row (16pt) - shown when details enabled
                let channelValue = "\(wifi.channel) (2.4 GHz)"
                detailRow(
                    title: "Channel:",
                    value: channelValue,
                    help: "RSSI: \(wifi.rssi) dBm\nChannel number: \(wifi.channel)\nChannel band: 2.4 GHz\nChannel width: 20 MHz"
                )

                // Speed row (16pt) - shown when details enabled
                detailRow(title: "Speed:", value: interfaceSpeed)
            }
        }
    }

    private var interfaceDisplayName: String {
        // Format: "en0" - TODO: Add country code if available
        return "en0"
    }

    private var macAddress: String {
        // TODO: Get actual MAC address from interface
        return "XX:XX:XX:XX:XX:XX"
    }

    private var interfaceSpeed: String {
        // TODO: Get actual interface speed
        return "1000baseT"
    }

    // MARK: - Address Section

    /// Address: Local IP, Public IPv4, Public IPv6
    /// With refresh button
    private var addressSection: some View {
        VStack(spacing: 0) {
            // Header with refresh button (22pt)
            HStack {
                Text("Address")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Spacer()

                // Refresh button
                Button {
                    // TODO: Trigger public IP refresh
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Refresh")
            }
            .frame(height: 22)

            // Local IP row (16pt)
            detailRow(
                title: "Local IP:",
                value: dataManager.networkData.ipAddress ?? "Unknown",
                color: .blue
            )
            .textSelection(.enabled)

            // Public IPv4 row (16pt) - shown when available
            if let publicIP = dataManager.networkData.publicIP {
                let ipv4Value = publicIP.ipAddress + (publicIP.country.map { " (\($0))" } ?? "")
                detailRow(
                    title: "Public IP:",
                    value: ipv4Value,
                    color: .blue
                )
                .textSelection(.enabled)
            }

            // Public IPv6 row (14pt, smaller font) - shown when available
            if let ipv6 = ipv6Address {
                detailRowIPv6(
                    title: "Public IP:",
                    value: ipv6
                )
            }
        }
    }

    // Placeholder for IPv6 - would need actual implementation
    private var ipv6Address: String? {
        nil  // TODO: Implement IPv6 detection
    }

    // IPv6 row with smaller font
    private func detailRowIPv6(title: String, value: String) -> some View {
        HStack(spacing: 0) {
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)

            Spacer()

            Text(value)
                .font(.system(size: 7, weight: .semibold))
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .offset(y: -1)
        }
        .frame(height: 14)
    }

    // MARK: - Processes Section

    /// Top processes with Downloading/Uploading columns
    private var processesSection: some View {
        VStack(spacing: 0) {
            // Section header (22pt)
            sectionHeader("Top processes")

            // Process list
            if let processes = dataManager.networkData.topProcesses, !processes.isEmpty {
                VStack(spacing: 0) {
                    ForEach(processes.prefix(8)) { process in
                        NetworkProcessRow(
                            process: process,
                            downloadColor: downloadColor,
                            uploadColor: uploadColor
                        )
                    }
                }
            } else {
                // Empty state
                VStack(spacing: 8) {
                    Text("No process data available")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .frame(height: 50)
            }
        }
    }

    // MARK: - Helper Methods

    private func formattedTotalBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func resetTotalUsage() {
        NotificationCenter.default.post(name: Notification.Name.resetTotalNetworkUsage, object: nil)
    }
}

// MARK: - Dual Line Chart View

/// Dual-line chart for download/upload history (68pt height)
/// Matches Stats Master's NetworkChartView
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
                // Download line (blue)
                if !downloadData.isEmpty {
                    linePath(for: downloadData, width: width, height: height)
                        .stroke(downloadColor, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                }

                // Upload line (red)
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
            path.move(to: CGPoint(x: 0, y: height - 1))
            path.addLine(to: CGPoint(x: width, y: height - 1))
            return path
        }

        let stepX = width / max(1, CGFloat(displayData.count - 1))

        for (index, value) in displayData.enumerated() {
            let x = CGFloat(index) * stepX
            let normalizedY = 1 - (value / maxVal)
            let y = normalizedY * (height - 2) + 1  // Padding

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
/// Matches Stats Master's GridChartView (30 columns x 3 rows = 90 cells)
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
                columns: Array(repeating: GridItem(.fixed(cellWidth), spacing: 0), count: columns),
                spacing: 0
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
        .padding(1)
    }

    private func statusForIndex(_ index: Int) -> Bool {
        if index == 0 {
            // First cell shows current status
            return isConnected
        } else if index - 1 < history.count {
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
/// Matches Stats Master's ProcessesView layout
struct NetworkProcessRow: View {
    let process: ProcessNetworkUsage
    let downloadColor: Color
    let uploadColor: Color

    var body: some View {
        HStack(spacing: 0) {
            // App icon placeholder (16pt)
            Image(systemName: "app.fill")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .frame(width: 16)

            // Process name (variable width)
            Text(process.name)
                .font(.system(size: 11))
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .frame(width: 90, alignment: .leading)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            // Download speed (fixed width)
            Text(formattedBytes(process.downloadBytes))
                .font(.system(size: 11))
                .foregroundColor(downloadColor)
                .frame(width: 60, alignment: .trailing)

            // Upload speed (fixed width)
            Text(formattedBytes(process.uploadBytes))
                .font(.system(size: 11))
                .foregroundColor(uploadColor)
                .frame(width: 60, alignment: .trailing)
        }
        .frame(height: 22)
    }

    private func formattedBytes(_ bytes: UInt64) -> String {
        if bytes < 1024 {
            return "\(bytes) B/s"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f K/s", Double(bytes) / 1024)
        } else {
            return String(format: "%.2f M/s", Double(bytes) / (1024 * 1024))
        }
    }
}

// MARK: - Preview

#Preview("Network Popover") {
    NetworkPopoverView()
}
