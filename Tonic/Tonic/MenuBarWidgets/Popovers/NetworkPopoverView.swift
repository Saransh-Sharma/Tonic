//
//  NetworkPopoverView.swift
//  Tonic
//
//  Stats Master-style Network popup using SwiftUI
//  Refactored for visual parity with Stats Master's AppKit implementation
//

import SwiftUI
import AppKit
import OSLog

// MARK: - Network Popover State

@MainActor
@Observable
private class NetworkPopoverState {
    var showDNSDetails: Bool = false
    var showWiFiTooltip: Bool = false
}

// MARK: - Network Popover View

/// Stats Master-style network popover with exact visual parity
public struct NetworkPopoverView: View {

    // MARK: - Properties

    @State private var state = NetworkPopoverState()
    @State private var dataManager = WidgetDataManager.shared

    // Colors using NSColor for exact matching
    private let downloadColor = Color(nsColor: NSColor(red: 0.2, green: 0.5, blue: 1.0, alpha: 1.0))
    private let uploadColor = Color(nsColor: NSColor(red: 1.0, green: 0.3, blue: 0.2, alpha: 1.0))
    private let textColor = Color(nsColor: .textColor)
    private let secondaryTextColor = Color(nsColor: .secondaryLabelColor)
    private let greenStatus = Color(nsColor: .systemGreen)
    private let redStatus = Color(nsColor: .systemRed)

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            headerView
            ScrollView {
                VStack(spacing: PopoverConstants.sectionSpacing) {
                    dashboardSection
                    chartSection
                    connectivitySection
                    detailsSection
                    interfaceSection
                    addressSection
                    processesSection
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
            Image(systemName: PopoverConstants.Icons.network)
                .font(.title2)
                .foregroundColor(DesignTokens.Colors.accent)

            Text("Network")
                .font(PopoverConstants.headerTitleFont)
                .foregroundColor(DesignTokens.Colors.textPrimary)

            Spacer()

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

            Button {
                // TODO: Open settings to Network widget configuration
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

    // MARK: - Dashboard Section (90pt)

    private var dashboardSection: some View {
        HStack(spacing: 0) {
            // Download side
            halfDashboard(
                title: "Downloading",
                value: downloadSpeed.value,
                unit: downloadSpeed.unit,
                color: downloadColor,
                isActive: downloadSpeed.isActive
            )
            .frame(width: 140, height: 90)

            // Upload side
            halfDashboard(
                title: "Uploading",
                value: uploadSpeed.value,
                unit: uploadSpeed.unit,
                color: uploadColor,
                isActive: uploadSpeed.isActive
            )
            .frame(width: 140, height: 90)
        }
        .frame(height: 90)
    }

    private func halfDashboard(title: String, value: String, unit: String, color: Color, isActive: Bool) -> some View {
        ZStack {
            VStack(spacing: 0) {
                // Value + unit (top)
                HStack(spacing: 5) {
                    Text(value)
                        .font(Font.system(size: 26, weight: .light))
                        .foregroundColor(textColor)
                        .frame(width: valueWidth(value: value), alignment: .trailing)
                        .fixedSize()

                    Text(unit)
                        .font(Font.system(size: 13, weight: .light))
                        .foregroundColor(secondaryTextColor)
                        .frame(width: unitWidth(unit: unit), alignment: .leading)
                        .fixedSize()
                }
                .frame(height: 30)

                Spacer()

                // Title + indicator (bottom)
                HStack(spacing: 8) {
                    // Color indicator (12x12 rounded square)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isActive ? color : Color(nsColor: .systemGray).opacity(0.3))
                        .frame(width: 12, height: 12)

                    Text(title)
                        .font(Font.system(size: 12))
                        .foregroundColor(secondaryTextColor)
                }
                .frame(height: 15)
            }
        }
    }

    // MARK: - Chart Section (90pt = 22pt header + 68pt chart)

    private var chartSection: some View {
        VStack(spacing: 0) {
            // Header (22pt)
            sectionHeader("Usage history")

            // Chart (68pt)
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(formatRateFromKBps(maxHistoryRate))
                        .font(.system(size: 8))
                        .foregroundColor(secondaryTextColor)
                    Spacer()
                    Text("0")
                        .font(.system(size: 8))
                        .foregroundColor(secondaryTextColor)
                }
                .frame(width: 40)

                ZStack {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(nsColor: .lightGray).opacity(0.1))

                    DualLineChartView(
                        downloadData: dataManager.networkDownloadHistory,
                        uploadData: dataManager.networkUploadHistory,
                        downloadColor: downloadColor,
                        uploadColor: uploadColor
                    )
                }
            }
            .frame(height: 68)
        }
        .frame(height: 90)
    }

    // MARK: - Connectivity Section (30pt = 22pt header + 8pt chart)

    private var connectivitySection: some View {
        VStack(spacing: 0) {
            // Header (22pt)
            sectionHeader("Connectivity history")

            // Grid (8pt)
            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(nsColor: .lightGray).opacity(0.1))

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
        Text(title)
            .font(Font.system(size: 11))
            .foregroundColor(secondaryTextColor)
            .frame(height: 22, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 0)
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        VStack(spacing: 0) {
            // Header with reset button (22pt)
            headerWithButton("Details") {
                resetTotalUsage()
            }

            // Rows (16pt each)
            detailColorRow(title: "Total upload:", value: totalUploadValue, color: uploadColor)
            detailColorRow(title: "Total download:", value: totalDownloadValue, color: downloadColor)
            detailRow(title: "Status:", value: dataManager.networkData.isConnected ? "UP" : "DOWN", color: dataManager.networkData.isConnected ? greenStatus : redStatus)
            detailRow(title: "Internet connection:", value: dataManager.networkData.isConnected ? "UP" : "DOWN", color: dataManager.networkData.isConnected ? greenStatus : redStatus)

            if let connectivity = dataManager.networkData.connectivity {
                detailRow(title: "Latency:", value: "\(Int(connectivity.latency)) ms", color: textColor)
                if connectivity.jitter > 0 {
                    detailRow(title: "Jitter:", value: "\(Int(connectivity.jitter)) ms", color: textColor)
                }
            } else {
                detailRow(title: "Latency:", value: "Unknown", color: textColor)
                detailRow(title: "Jitter:", value: "Unknown", color: textColor)
            }
        }
    }

    private func detailRow(title: String, value: String, color: Color) -> some View {
        HStack(spacing: 0) {
            Text(title)
                .font(Font.system(size: 11))
                .foregroundColor(secondaryTextColor)
                .frame(width: 120, alignment: .leading)

            Spacer()

            Text(value)
                .font(Font.system(size: 11, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 160, alignment: .trailing)
        }
        .frame(height: 16)
    }

    private func detailColorRow(title: String, value: String, color: Color) -> some View {
        HStack(spacing: 0) {
            // Color indicator (6x6)
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 6, height: 6)

            Text(title)
                .font(Font.system(size: 11))
                .foregroundColor(secondaryTextColor)
                .frame(width: 114, alignment: .leading)

            Spacer()

            Text(value)
                .font(Font.system(size: 11, weight: .semibold))
                .foregroundColor(textColor)
                .frame(width: 160, alignment: .trailing)
        }
        .frame(height: 16)
    }

    // MARK: - Interface Section

    private var interfaceSection: some View {
        VStack(spacing: 0) {
            // Header with details button (22pt)
            headerWithButton("Interface") {
                // Toggle details
            }

            detailRow(title: "Interface:", value: interfaceValue, color: textColor)
            detailRow(title: "Status:", value: dataManager.networkData.isConnected ? "UP" : "DOWN", color: dataManager.networkData.isConnected ? greenStatus : redStatus)
            detailRow(title: "Physical address:", value: macAddressValue, color: textColor)

            // DNS servers with expand/collapse
            HStack(spacing: 0) {
                Text("DNS servers:")
                    .font(Font.system(size: 11))
                    .foregroundColor(secondaryTextColor)
                    .frame(width: 120, alignment: .leading)

                Spacer()

                Button(action: { state.showDNSDetails.toggle() }) {
                    HStack(spacing: 4) {
                        Text(dnsServersValue)
                            .font(Font.system(size: 11, weight: .semibold))
                            .foregroundColor(textColor)
                            .lineLimit(1)
                        Image(systemName: "chevron.right")
                            .font(Font.system(size: 8))
                            .foregroundColor(secondaryTextColor)
                            .rotationEffect(.degrees(state.showDNSDetails ? 90 : 0))
                    }
                }
                .buttonStyle(.plain)
                .frame(width: 160, alignment: .trailing)
            }
            .frame(height: 16)

            if state.showDNSDetails {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(dnsServersList.enumerated()), id: \.offset) { _, dns in
                        HStack(spacing: 8) {
                            Spacer()
                                .frame(width: 120)
                            Text(dns)
                                .font(Font.system(size: 10))
                                .foregroundColor(textColor)
                            Spacer()
                        }
                    }
                }
                .padding(.vertical, 4)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            }

            if showWiFiDetails,
               dataManager.networkData.connectionType == .wifi,
               let wifi = dataManager.networkData.wifiDetails {
                detailRow(title: "Network:", value: wifi.ssid, color: textColor)
                detailRow(title: "Standard:", value: wifi.standard, color: textColor)

                // WiFi details row with extended tooltip
                HStack(spacing: 0) {
                    Text("Channel:")
                        .font(Font.system(size: 11))
                        .foregroundColor(secondaryTextColor)
                        .frame(width: 120, alignment: .leading)

                    Spacer()

                    Button(action: { state.showWiFiTooltip.toggle() }) {
                        HStack(spacing: 4) {
                            Text("\(wifi.channel) (\(wifi.band.displayName), \(wifi.channelWidth) MHz)")
                                .font(Font.system(size: 11, weight: .semibold))
                                .foregroundColor(textColor)
                            Image(systemName: "info.circle")
                                .font(Font.system(size: 9))
                                .foregroundColor(secondaryTextColor)
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(width: 160, alignment: .trailing)
                    .popover(isPresented: $state.showWiFiTooltip, arrowEdge: .trailing) {
                        wifiTooltipView(wifi)
                    }
                }
                .frame(height: 16)

                detailRow(title: "Speed:", value: linkSpeedValue, color: textColor)
            }
        }
    }

    // MARK: - WiFi Tooltip View

    private func wifiTooltipView(_ wifi: WiFiDetails) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WiFi Details")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(textColor)
                .padding(.bottom, 4)

            wifiDetailRow(label: "Signal Strength", value: "\(wifi.rssi) dBm")
            wifiDetailRow(label: "Noise Level", value: "\(wifi.noise) dBm")
            wifiDetailRow(label: "SNR", value: "\(wifi.snr) dB")
            wifiDetailRow(label: "Channel", value: "\(wifi.channel)")
            wifiDetailRow(label: "Band", value: wifi.band.displayName)
            wifiDetailRow(label: "Channel Width", value: "\(wifi.channelWidth) MHz")
            wifiDetailRow(label: "BSSID", value: wifi.bssid)
        }
        .padding(12)
        .frame(width: 200)
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(8)
        .shadow(radius: 4)
    }

    private func wifiDetailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(secondaryTextColor)
            Spacer()
            Text(value)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(textColor)
        }
    }

    private var dnsServersValue: String {
        let servers = dnsServersList
        if servers.isEmpty {
            return "Unknown"
        } else if servers.count == 1 {
            return servers[0]
        } else {
            return "\(servers.count) servers"
        }
    }

    private var dnsServersList: [String] {
        dataManager.networkData.dnsServers
    }

    private var interfaceValue: String {
        let interfaceName = dataManager.networkData.interfaceName ?? "—"
        let typeLabel: String
        switch dataManager.networkData.connectionType {
        case .wifi:
            typeLabel = "Wi-Fi"
        case .ethernet:
            typeLabel = "Ethernet"
        case .cellular:
            typeLabel = "Cellular"
        default:
            typeLabel = "Network"
        }
        let statusLabel = dataManager.networkData.isConnected ? "IN" : "OUT"
        return "\(typeLabel) (\(interfaceName), \(statusLabel))"
    }

    private var macAddressValue: String {
        dataManager.networkData.macAddress ?? "Unknown"
    }

    private var showPublicIP: Bool {
        WidgetPreferences.shared.widgetConfigs
            .first(where: { $0.type == .network })?
            .moduleSettings.network.showPublicIP ?? true
    }

    private var showWiFiDetails: Bool {
        WidgetPreferences.shared.widgetConfigs
            .first(where: { $0.type == .network })?
            .moduleSettings.network.showWiFiDetails ?? true
    }

    // MARK: - Address Section

    private var addressSection: some View {
        VStack(spacing: 0) {
            // Header with refresh button (22pt)
            headerWithButton("Address") {
                // Refresh public IP
            }

            detailRow(title: "Local IP:", value: dataManager.networkData.ipAddress ?? "Unknown", color: Color(nsColor: .systemBlue))

            if showPublicIP {
                if let publicIP = dataManager.networkData.publicIP {
                    let ipValue = publicIP.ipAddress + (publicIP.country.map { " (\($0))" } ?? "")
                    detailRow(title: "Public IP:", value: ipValue, color: Color(nsColor: .systemBlue))
                } else {
                    detailRow(title: "Public IP:", value: "Unknown", color: Color(nsColor: .systemBlue))
                }
            }
        }
    }

    // MARK: - Processes Section

    private var processesSection: some View {
        VStack(spacing: 0) {
            // Header (22pt)
            sectionHeader("Top processes")

            // Process list
            if let processes = dataManager.networkData.topProcesses, !processes.isEmpty {
                let processCount = topProcessCount
                VStack(spacing: 0) {
                    processHeaderRow
                    ForEach(processes.prefix(processCount)) { process in
                        processRow(process)
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Text("No process data available")
                        .font(Font.system(size: 11))
                        .foregroundColor(secondaryTextColor)
                }
                .frame(height: 50)
            }
        }
    }

    private var processHeaderRow: some View {
        HStack(spacing: 0) {
            Text("Process")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(secondaryTextColor)
                .frame(width: 110, alignment: .leading)

            Spacer()

            HStack(spacing: 4) {
                Circle()
                    .fill(downloadColor)
                    .frame(width: 6, height: 6)
                Text("Down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(secondaryTextColor)
            }
            .frame(width: 60, alignment: .trailing)

            HStack(spacing: 4) {
                Circle()
                    .fill(uploadColor)
                    .frame(width: 6, height: 6)
                Text("Up")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(secondaryTextColor)
            }
            .frame(width: 60, alignment: .trailing)
        }
        .frame(height: 18)
    }

    /// Get the configured top process count from NetworkModuleSettings
    private var topProcessCount: Int {
        WidgetPreferences.shared.widgetConfigs
            .first(where: { $0.type == .network })?
            .moduleSettings.network.topProcessCount ?? 8
    }

    private func processRow(_ process: ProcessNetworkUsage) -> some View {
        HStack(spacing: 0) {
            // Icon placeholder (16pt)
            Image(systemName: "app.fill")
                .font(.system(size: 10))
                .foregroundColor(secondaryTextColor)
                .frame(width: 16)

            // Name (90pt)
            Text(process.name)
                .font(Font.system(size: 11))
                .foregroundColor(textColor)
                .frame(width: 94, alignment: .leading)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            // Download (60pt)
            Text(formattedBytes(process.downloadBytes))
                .font(Font.system(size: 11))
                .foregroundColor(downloadColor)
                .frame(width: 60, alignment: .trailing)

            // Upload (60pt)
            Text(formattedBytes(process.uploadBytes))
                .font(Font.system(size: 11))
                .foregroundColor(uploadColor)
                .frame(width: 60, alignment: .trailing)
        }
        .frame(height: 22)
    }

    // MARK: - Header with Button

    private func headerWithButton(_ title: String, action: @escaping () -> Void) -> some View {
        ZStack {
            Text(title)
                .font(Font.system(size: 11))
                .foregroundColor(secondaryTextColor)
                .frame(height: 22, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 0)

            HStack {
                Spacer()
                Button(action: action) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                        .foregroundColor(Color(nsColor: .lightGray))
                }
                .buttonStyle(.plain)
                .frame(width: 18, height: 18)
            }
        }
        .frame(height: 22)
    }

    // MARK: - Data Updates

    private var downloadSpeed: (value: String, unit: String, isActive: Bool) {
        let rate = dataManager.networkData.downloadBytesPerSecond
        let tuple = speedTuple(rate)
        return (tuple.value, tuple.unit, rate > 0)
    }

    private var uploadSpeed: (value: String, unit: String, isActive: Bool) {
        let rate = dataManager.networkData.uploadBytesPerSecond
        let tuple = speedTuple(rate)
        return (tuple.value, tuple.unit, rate > 0)
    }

    private var totalUploadValue: String {
        formatTotalBytes(dataManager.totalUploadBytes)
    }

    private var totalDownloadValue: String {
        formatTotalBytes(dataManager.totalDownloadBytes)
    }

    private var maxHistoryRate: Double {
        let maxDownload = dataManager.networkDownloadHistory.max() ?? 0
        let maxUpload = dataManager.networkUploadHistory.max() ?? 0
        return max(maxDownload, maxUpload)
    }

    private var linkSpeedValue: String {
        if let linkSpeed = dataManager.networkData.linkSpeedMbps, linkSpeed > 0 {
            return "\(Int(linkSpeed)) Mbps"
        }
        return "Unknown"
    }

    private func speedTuple(_ bytesPerSecond: Double) -> (value: String, unit: String) {
        if bytesPerSecond < 1024 {
            return ("\(Int(bytesPerSecond))", "B/s")
        } else if bytesPerSecond < 1024 * 1024 {
            return (String(format: "%.1f", bytesPerSecond / 1024), "KB/s")
        } else {
            return (String(format: "%.2f", bytesPerSecond / (1024 * 1024)), "MB/s")
        }
    }

    private func formatRateFromKBps(_ kbps: Double) -> String {
        if kbps < 1024 {
            return String(format: "%.0f KB/s", kbps)
        }
        return String(format: "%.1f MB/s", kbps / 1024)
    }

    private func formatTotalBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func valueWidth(value: String) -> CGFloat {
        let font = NSFont.systemFont(ofSize: 26, weight: .light)
        return (value as NSString).size(withAttributes: [.font: font]).width + 5
    }

    private func unitWidth(unit: String) -> CGFloat {
        let font = NSFont.systemFont(ofSize: 13, weight: .light)
        return (unit as NSString).size(withAttributes: [.font: font]).width + 5
    }

    private func formattedBytes(_ bytes: UInt64) -> String {
        if bytes < 1024 {
            return "\(bytes) B/s"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB/s", Double(bytes) / 1024)
        } else {
            return String(format: "%.2f MB/s", Double(bytes) / (1024 * 1024))
        }
    }

    private func resetTotalUsage() {
        NotificationCenter.default.post(name: .resetTotalNetworkUsage, object: nil)
    }
}

// MARK: - Dual Line Chart View

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
                if !downloadData.isEmpty {
                    linePath(for: downloadData, width: width, height: height)
                        .stroke(downloadColor, lineWidth: 1.5)
                }

                if !uploadData.isEmpty {
                    linePath(for: uploadData, width: width, height: height)
                        .stroke(uploadColor, lineWidth: 1.5)
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
            path.move(to: CGPoint(x: 0, y: height - 1))
            path.addLine(to: CGPoint(x: width, y: height - 1))
            return path
        }

        let stepX = width / max(1, CGFloat(displayData.count - 1))

        for (index, value) in displayData.enumerated() {
            let x = CGFloat(index) * stepX
            let normalizedY = 1 - (value / maxVal)
            let y = normalizedY * (height - 2) + 1

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
                ForEach(0..<(columns * rows), id: \.self) { index in
                    let status = statusForIndex(index)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(status ? Color(nsColor: .systemGreen) : Color(nsColor: .systemRed).opacity(0.5))
                        .frame(width: cellWidth - 1, height: cellHeight - 1)
                }
            }
        }
        .padding(1)
    }

    private func statusForIndex(_ index: Int) -> Bool {
        if index == 0 {
            return isConnected
        } else if index - 1 < history.count {
            return history.reversed()[index - 1]
        } else {
            return isConnected
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

#Preview("Network Popover") {
    NetworkPopoverView()
}
