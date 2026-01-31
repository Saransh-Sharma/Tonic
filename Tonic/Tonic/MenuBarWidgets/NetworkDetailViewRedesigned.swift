//
//  NetworkDetailViewRedesigned.swift
//  Tonic
//
//  High-performance network widget with WhyFi-inspired design
//  Optimized for instant popover display with background data fetching
//  Performance: Removed blocking calls, added debouncing, optimized rendering
//

import SwiftUI

// MARK: - Cached Network State

/// Lightweight cached state for instant UI rendering
@MainActor
@Observable
final class NetworkViewState {
    static let shared = NetworkViewState()

    // Cached display values - updated in background, read instantly
    var ssid: String = "Not Connected"
    var band: String = "—"
    var linkRate: String = "—"
    var linkRateColor: Color = .secondary
    var signalStrength: String = "—"
    var signalColor: Color = .secondary
    var noise: String = "—"
    var noiseColor: Color = .secondary

    var routerPing: String = "—"
    var routerPingColor: Color = .secondary
    var routerJitter: String = "—"
    var routerJitterColor: Color = .secondary
    var routerLoss: String = "—"
    var routerLossColor: Color = .secondary
    var routerLoaded: Bool = false

    var internetPing: String = "—"
    var internetPingColor: Color = .secondary
    var internetJitter: String = "—"
    var internetJitterColor: Color = .secondary
    var internetLoss: String = "—"
    var internetLossColor: Color = .secondary
    var internetLoaded: Bool = false

    var dnsServer: String = "—"
    var dnsLookup: String = "—"
    var dnsLookupColor: Color = .secondary
    var dnsLoaded: Bool = false

    // Speed test results - persist across view recreations
    var speedTestDownloadSpeed: String?
    var speedTestUploadSpeed: String?
    var speedTestTimestamp: Date?

    var isConnected: Bool = false
    var lastUpdate: Date = .distantPast

    // Sparkline history (lightweight arrays)
    var linkRateHistory: [Double] = []
    var signalHistory: [Double] = []
    var noiseHistory: [Double] = []
    var routerPingHistory: [Double] = []
    var internetPingHistory: [Double] = []
    var dnsHistory: [Double] = []

    private init() {}

    /// Check if data is stale (older than 30 seconds)
    var isStale: Bool {
        Date().timeIntervalSince(lastUpdate) > 30
    }

    /// Check if speed test results are available and recent (within 1 hour)
    var hasRecentSpeedTestResults: Bool {
        guard let timestamp = speedTestTimestamp,
              speedTestDownloadSpeed != nil,
              speedTestUploadSpeed != nil else {
            return false
        }
        return Date().timeIntervalSince(timestamp) < 3600  // 1 hour
    }

    /// Invalidate all cached data
    func invalidate() {
        routerLoaded = false
        internetLoaded = false
        dnsLoaded = false
        lastUpdate = .distantPast
    }
}

// MARK: - Background Data Fetcher

/// Handles all network data fetching off the main thread
/// Optimized to never block the UI
actor NetworkDataFetcher {
    static let shared = NetworkDataFetcher()

    private var isFetching = false
    private var lastFetchTime: Date = .distantPast
    private var currentTask: Task<Void, Never>?
    private let minFetchInterval: TimeInterval = 2.0  // Reduced from 5 for responsiveness

    private init() {}

    /// Pre-fetch all network data in background
    func prefetchData() async {
        // Cancel any ongoing fetch
        currentTask?.cancel()

        // Debounce rapid calls
        guard !isFetching else { return }
        guard Date().timeIntervalSince(lastFetchTime) >= minFetchInterval else {
            // If data is recent, just mark as loaded
            await markAllAsLoaded()
            return
        }

        isFetching = true
        lastFetchTime = Date()

        // Create new task
        currentTask = Task {
            await performFetch()
            isFetching = false
        }

        await currentTask?.value
    }

    /// Cancel ongoing fetch
    func cancel() {
        currentTask?.cancel()
        isFetching = false
    }

    private func performFetch() async {
        // Fetch WiFi metrics first (fastest) - update UI immediately
        await fetchWiFiMetrics()

        // Don't await quality metrics - let them fill in progressively
        Task.detached(priority: .userInitiated) {
            await self.fetchRouterQuality()
        }

        Task.detached(priority: .userInitiated) {
            await self.fetchInternetQuality()
        }

        Task.detached(priority: .userInitiated) {
            await self.fetchDNS()
        }
    }

    private func fetchWiFiMetrics() async {
        // No MainActor.run wrapper - service has caching now
        let metrics = await MainActor.run {
            WiFiMetricsService.shared.fetchMetrics()
        }

        await MainActor.run {
            let state = NetworkViewState.shared

            if let metrics = metrics {
                state.isConnected = true
                state.ssid = WiFiMetricsService.shared.getSSID() ?? "Connected"

                // Band
                if let band = metrics.band {
                    state.band = band.rawValue
                } else {
                    state.band = "—"
                }

                // Link Rate
                if let rate = metrics.linkRate {
                    state.linkRate = String(format: "%.0f", rate)
                    state.linkRateColor = rate >= 400 ? TonicColors.success : (rate >= 150 ? TonicColors.warning : TonicColors.error)
                    state.linkRateHistory = addToHistory(state.linkRateHistory, value: rate)
                }

                // Signal
                if let signal = metrics.signalStrength {
                    state.signalStrength = String(format: "%.0f", signal)
                    state.signalColor = signal >= -50 ? TonicColors.success : (signal >= -70 ? TonicColors.warning : TonicColors.error)
                    state.signalHistory = addToHistory(state.signalHistory, value: signal)
                }

                // Noise
                if let noise = metrics.noise {
                    state.noise = String(format: "%.0f", noise)
                    state.noiseColor = noise <= -85 ? TonicColors.success : (noise <= -75 ? TonicColors.warning : TonicColors.error)
                    state.noiseHistory = addToHistory(state.noiseHistory, value: noise)
                }
            } else {
                state.isConnected = WidgetDataManager.shared.networkData.isConnected
                state.ssid = state.isConnected ? "Connected" : "Not Connected"
            }

            state.lastUpdate = Date()
        }
    }

    private func fetchRouterQuality() async {
        let quality = await NetworkQualityService.shared.testRouterQuality()

        await MainActor.run {
            let state = NetworkViewState.shared

            // Only update values if we got successful ping results
            if let ping = quality.ping {
                let pingMs = ping * 1000
                state.routerPing = String(format: "%.0f", pingMs)
                state.routerPingColor = pingMs < 10 ? TonicColors.success : (pingMs < 50 ? TonicColors.warning : TonicColors.error)
                state.routerPingHistory = addToHistory(state.routerPingHistory, value: pingMs)
            } else {
                // Ping failed - keep placeholder
                state.routerPing = "—"
                state.routerPingColor = .secondary
            }

            if let jitter = quality.jitter {
                let jitterMs = jitter * 1000
                state.routerJitter = String(format: "%.1f", jitterMs)
                state.routerJitterColor = jitterMs < 10 ? TonicColors.success : (jitterMs < 30 ? TonicColors.warning : TonicColors.error)
            } else {
                state.routerJitter = "—"
                state.routerJitterColor = .secondary
            }

            // Only show packet loss if we have successful pings
            if let loss = quality.packetLoss, quality.ping != nil {
                state.routerLoss = String(format: "%.0f", loss)
                state.routerLossColor = loss < 1 ? TonicColors.success : (loss < 5 ? TonicColors.warning : TonicColors.error)
            } else {
                state.routerLoss = "—"
                state.routerLossColor = .secondary
            }

            state.routerLoaded = true
        }
    }

    private func fetchInternetQuality() async {
        let quality = await NetworkQualityService.shared.testInternetQuality()

        await MainActor.run {
            let state = NetworkViewState.shared

            if let ping = quality.ping {
                let pingMs = ping * 1000
                state.internetPing = String(format: "%.0f", pingMs)
                state.internetPingColor = pingMs < 30 ? TonicColors.success : (pingMs < 100 ? TonicColors.warning : TonicColors.error)
                state.internetPingHistory = addToHistory(state.internetPingHistory, value: pingMs)
            } else {
                state.internetPing = "—"
                state.internetPingColor = .secondary
            }

            if let jitter = quality.jitter {
                let jitterMs = jitter * 1000
                state.internetJitter = String(format: "%.1f", jitterMs)
                state.internetJitterColor = jitterMs < 20 ? TonicColors.success : (jitterMs < 50 ? TonicColors.warning : TonicColors.error)
            } else {
                state.internetJitter = "—"
                state.internetJitterColor = .secondary
            }

            if let loss = quality.packetLoss, quality.ping != nil {
                state.internetLoss = String(format: "%.0f", loss)
                state.internetLossColor = loss < 1 ? TonicColors.success : (loss < 3 ? TonicColors.warning : TonicColors.error)
            } else {
                state.internetLoss = "—"
                state.internetLossColor = .secondary
            }

            state.internetLoaded = true
        }
    }

    private func fetchDNS() async {
        await MainActor.run {
            DNSService.shared.refresh()
        }

        // Small delay for DNS refresh to complete
        try? await Task.sleep(nanoseconds: 100_000_000)

        await MainActor.run {
            let state = NetworkViewState.shared

            if let dns = DNSService.shared.currentDNS {
                if let server = dns.servers.first {
                    let displayName = DNSService.shared.getDNSDisplayName(server)
                    state.dnsServer = displayName != server ? displayName : server
                }

                if let lookup = dns.lookupTime {
                    let lookupMs = lookup * 1000
                    state.dnsLookup = String(format: "%.0f", lookupMs)
                    state.dnsLookupColor = lookupMs < 30 ? TonicColors.success : (lookupMs < 100 ? TonicColors.warning : TonicColors.error)
                    state.dnsHistory = addToHistory(state.dnsHistory, value: lookupMs)
                }
            }

            state.dnsLoaded = true
        }
    }

    private func markAllAsLoaded() async {
        await MainActor.run {
            let state = NetworkViewState.shared
            state.routerLoaded = true
            state.internetLoaded = true
            state.dnsLoaded = true
        }
    }

    private nonisolated func addToHistory(_ history: [Double], value: Double, maxCount: Int = 20) -> [Double] {
        var newHistory = history
        newHistory.append(value)
        if newHistory.count > maxCount {
            newHistory.removeFirst(newHistory.count - maxCount)
        }
        return newHistory
    }
}

// MARK: - Network Detail View (Redesigned)

/// High-performance network diagnostics view inspired by WhyFi
public struct NetworkDetailViewRedesigned: View {

    @State private var state = NetworkViewState.shared
    @State private var isRefreshing = false
    @State private var refreshTask: Task<Void, Never>?
    @State private var speedTestRunning = false
    @State private var speedTestProgress: Double = 0

    public init() {}

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            // Content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    // Connection header (WhyFi style)
                    connectionHeader

                    // Wi-Fi metrics card
                    wifiMetricsCard

                    // Router quality card
                    qualityCard(
                        title: "Router",
                        ping: state.routerPing,
                        pingColor: state.routerPingColor,
                        pingHistory: state.routerPingHistory,
                        jitter: state.routerJitter,
                        jitterColor: state.routerJitterColor,
                        loss: state.routerLoss,
                        lossColor: state.routerLossColor,
                        isLoaded: state.routerLoaded
                    )

                    // Internet quality card
                    qualityCard(
                        title: "Internet",
                        subtitle: "1.1.1.1",
                        ping: state.internetPing,
                        pingColor: state.internetPingColor,
                        pingHistory: state.internetPingHistory,
                        jitter: state.internetJitter,
                        jitterColor: state.internetJitterColor,
                        loss: state.internetLoss,
                        lossColor: state.internetLossColor,
                        isLoaded: state.internetLoaded
                    )

                    // DNS card
                    dnsCard

                    // Speed test card
                    speedTestCard

                    // Top network processes
                    ProcessListWidgetView(widgetType: .network, maxCount: 5)
                }
                .padding(16)
            }
        }
        .frame(width: 340, height: 520)
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            // Immediate display with cached data, then refresh in background
            refreshData()
        }
        .onDisappear {
            // Cancel any ongoing refresh
            refreshTask?.cancel()
            refreshTask = nil
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 12) {
            Text("Network")
                .font(.system(size: 16, weight: .semibold))

            Spacer()

            Button {
                Task {
                    await refreshDataAsync()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .rotationEffect(isRefreshing ? .degrees(360) : .zero)
                    .animation(isRefreshing ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .default, value: isRefreshing)
            }
            .buttonStyle(.plain)
            .disabled(isRefreshing)

            Button {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.network") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Image(systemName: "gear")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Refresh Action

    private func refreshData() {
        // Cancel previous refresh
        refreshTask?.cancel()

        // Invalidate caches to force fresh data
        NetworkQualityService.shared.invalidateCache()
        WiFiMetricsService.shared.invalidateCache()

        isRefreshing = true

        refreshTask = Task {
            await NetworkDataFetcher.shared.prefetchData()

            await MainActor.run {
                isRefreshing = false
            }
        }
    }

    // MARK: - Refresh Action (Async version for buttons)

    private func refreshDataAsync() async {
        // Cancel previous refresh
        refreshTask?.cancel()

        // Invalidate caches to force fresh data
        NetworkQualityService.shared.invalidateCache()
        WiFiMetricsService.shared.invalidateCache()

        isRefreshing = true

        await NetworkDataFetcher.shared.prefetchData()

        isRefreshing = false
    }

    // MARK: - Connection Header (WhyFi Style)

    private var connectionHeader: some View {
        HStack(spacing: 8) {
            // Status dot
            Circle()
                .fill(state.isConnected ? TonicColors.success : TonicColors.error)
                .frame(width: 8, height: 8)

            // Network name
            Text(state.ssid)
                .font(.system(size: 14, weight: .medium))
                .lineLimit(1)

            // Band badge
            if state.isConnected && state.band != "—" {
                Text(state.band)
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.blue.opacity(0.15))
                    )
                    .foregroundColor(.blue)
            }

            Spacer()
        }
        .padding(12)
        .background(cardBackground)
    }

    // MARK: - WiFi Metrics Card

    private var wifiMetricsCard: some View {
        VStack(spacing: 0) {
            metricRow(
                label: "Link Rate",
                value: state.linkRate,
                unit: "Mbps",
                color: state.linkRateColor,
                history: state.linkRateHistory
            )

            Divider().padding(.horizontal, 12)

            metricRow(
                label: "Signal",
                value: state.signalStrength,
                unit: "dBm",
                color: state.signalColor,
                history: state.signalHistory
            )

            Divider().padding(.horizontal, 12)

            metricRow(
                label: "Noise",
                value: state.noise,
                unit: "dBm",
                color: state.noiseColor,
                history: state.noiseHistory
            )

            // Scan for Interference button
            Button {
                // Interference scan action
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 11))
                    Text("Scan for Interference")
                        .font(.system(size: 12))
                }
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .padding(12)
        }
        .background(cardBackground)
    }

    // MARK: - Quality Card

    private func qualityCard(
        title: String,
        subtitle: String? = nil,
        ping: String,
        pingColor: Color,
        pingHistory: [Double],
        jitter: String,
        jitterColor: Color,
        loss: String,
        lossColor: Color,
        isLoaded: Bool
    ) -> some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)

                if let subtitle = subtitle {
                    Text("·")
                        .foregroundColor(.secondary)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.7))
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)

            if isLoaded {
                metricRow(label: "Ping", value: ping, unit: "ms", color: pingColor, history: pingHistory)
                Divider().padding(.horizontal, 12)
                metricRow(label: "Jitter", value: jitter, unit: "ms", color: jitterColor, history: [])
                Divider().padding(.horizontal, 12)
                metricRow(label: "Loss", value: loss, unit: "%", color: lossColor, history: [])
            } else {
                // Skeleton loading state
                skeletonRow()
                Divider().padding(.horizontal, 12)
                skeletonRow()
                Divider().padding(.horizontal, 12)
                skeletonRow()
            }
        }
        .background(cardBackground)
    }

    // MARK: - DNS Card

    private var dnsCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("DNS")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)

                Circle()
                    .fill(state.dnsLoaded ? TonicColors.success : Color.secondary)
                    .frame(width: 6, height: 6)

                Spacer()

                if state.dnsLoaded {
                    Text(state.dnsServer)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.7))
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)

            if state.dnsLoaded {
                metricRow(label: "Lookup", value: state.dnsLookup, unit: "ms", color: state.dnsLookupColor, history: state.dnsHistory)
            } else {
                skeletonRow()
            }
        }
        .background(cardBackground)
    }

    // MARK: - Speed Test Card

    private var speedTestCard: some View {
        VStack(spacing: 12) {
            if state.hasRecentSpeedTestResults {
                // Show results
                VStack(spacing: 16) {
                    HStack(spacing: 32) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(state.speedTestDownloadSpeed ?? "—")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(TonicColors.success)
                                .contentTransition(.numericText())
                            Text("Download")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(alignment: .trailing, spacing: 6) {
                            Text(state.speedTestUploadSpeed ?? "—")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.blue)
                                .contentTransition(.numericText())
                            Text("Upload")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }

                    // Show timestamp if recent
                    if let timestamp = state.speedTestTimestamp {
                        Text("Tested \(timestamp, style: .relative) ago")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 8) {
                        Button {
                            runSpeedTest()
                        } label: {
                            Text("Retest")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Button {
                            // Clear results
                            state.speedTestDownloadSpeed = nil
                            state.speedTestUploadSpeed = nil
                            state.speedTestTimestamp = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 8)
            } else {
                // Speed test button
                Button {
                    runSpeedTest()
                } label: {
                    HStack(spacing: 10) {
                        if speedTestRunning {
                            ProgressView()
                                .scaleEffect(0.8)
                                .frame(width: 20, height: 20)
                            Text("Testing... \(Int(speedTestProgress * 100))%")
                                .font(.system(size: 13, weight: .medium))
                        } else {
                            Image(systemName: "speedometer")
                                .font(.system(size: 16))
                            Text("Run Speed Test")
                                .font(.system(size: 14, weight: .medium))
                        }
                    }
                    .foregroundColor(speedTestRunning ? .secondary : .blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.blue.opacity(speedTestRunning ? 0.05 : 0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.blue.opacity(0.2), lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
                .disabled(speedTestRunning)
            }
        }
        .padding(14)
        .background(cardBackground)
    }

    // MARK: - Reusable Components

    private func metricRow(
        label: String,
        value: String,
        unit: String,
        color: Color,
        history: [Double]
    ) -> some View {
        HStack(spacing: 8) {
            // Label
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)

            // Value with color dot
            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)

                Text(value)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(color)

                Text(unit)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .frame(width: 90, alignment: .leading)

            // Sparkline
            if !history.isEmpty {
                MiniSparkline(data: history, color: color)
                    .frame(height: 24)
            } else {
                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func skeletonRow() -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.secondary.opacity(0.15))
                .frame(width: 50, height: 12)

            RoundedRectangle(cornerRadius: 3)
                .fill(Color.secondary.opacity(0.15))
                .frame(width: 60, height: 16)

            Spacer()

            RoundedRectangle(cornerRadius: 3)
                .fill(Color.secondary.opacity(0.1))
                .frame(height: 20)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .shimmer()
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color(nsColor: .controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 1)
            )
    }

    // MARK: - Actions

    private func runSpeedTest() {
        speedTestRunning = true
        speedTestProgress = 0

        Task {
            // Get actual speed test results
            let speedService = SpeedTestService.shared
            speedService.startTest()

            // Wait for test to complete
            while speedService.isRunning {
                try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms
                await MainActor.run {
                    speedTestProgress = speedService.progress
                }
            }

            await MainActor.run {
                // Save results to persisted state
                if let download = speedService.testData.downloadSpeed {
                    state.speedTestDownloadSpeed = String(format: "%.1f Mbps", download)
                } else {
                    state.speedTestDownloadSpeed = nil
                }
                if let upload = speedService.testData.uploadSpeed {
                    state.speedTestUploadSpeed = String(format: "%.1f Mbps", upload)
                } else {
                    state.speedTestUploadSpeed = nil
                }
                state.speedTestTimestamp = Date()

                speedTestRunning = false
            }
        }
    }
}

// MARK: - Mini Sparkline (Lightweight)

struct MiniSparkline: View {
    let data: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            if data.count >= 2 {
                let minVal = data.min() ?? 0
                let maxVal = data.max() ?? 1
                let range = max(maxVal - minVal, 0.001)

                Path { path in
                    let stepX = geometry.size.width / CGFloat(data.count - 1)

                    for (index, value) in data.enumerated() {
                        let x = CGFloat(index) * stepX
                        let y = geometry.size.height * (1 - CGFloat((value - minVal) / range))

                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(color.opacity(0.7), lineWidth: 1.5)
            }
        }
    }
}

// MARK: - Preview

#Preview("Network Detail View") {
    NetworkDetailViewRedesigned()
        .preferredColorScheme(.dark)
}
