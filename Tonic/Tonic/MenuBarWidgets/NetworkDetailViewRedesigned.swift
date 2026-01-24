//
//  NetworkDetailViewRedesigned.swift
//  Tonic
//
//  Redesigned network widget detail view with enhanced diagnostics
//  Task ID: fn-2.8.12
//

import SwiftUI
import Charts

// MARK: - Network Detail View (Redesigned)

/// Comprehensive network diagnostics detail view inspired by WhyFi
public struct NetworkDetailViewRedesigned: View {

    @State private var dataManager = WidgetDataManager.shared
    @State private var speedTestService = SpeedTestService.shared
    @State private var showingSpeedTestResults = false

    // Refresh state
    @State private var isRefreshing = false

    // Track expanded sections
    @State private var expandedSection: Section? = nil

    public enum Section: String, CaseIterable {
        case connection = "Connection"
        case wifi = "WiFi"
        case router = "Router"
        case internet = "Internet"
        case dns = "DNS"
        case speedTest = "Speed Test"
    }

    public init() {}

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Scrollable content
            ScrollView {
                VStack(spacing: 16) {
                    // Connection status card
                    connectionSection

                    // Show Wi-Fi metrics if connected to Wi-Fi
                    if dataManager.isWiFiConnection {
                        wifiMetricsSection
                    }

                    // Router quality section
                    routerQualitySection

                    // Internet quality section
                    internetQualitySection

                    // DNS section
                    dnsSection

                    // Speed test section
                    speedTestSection

                    // Footer action buttons
                    footerActions
                }
                .padding()
            }
        }
        .frame(width: 380, height: 580)
        .background(DesignTokens.Colors.background)
        .onAppear {
            refreshNetworkData()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            // Connection type icon
            Image(systemName: dataManager.connectionTypeIcon())
                .font(.title2)
                .foregroundColor(dataManager.networkHealthColor)

            // Title
            VStack(alignment: .leading, spacing: 2) {
                Text("Network")
                    .font(DesignTokens.Typography.headlineMedium)
                    .fontWeight(.semibold)

                if let ssid = dataManager.networkData.ssid {
                    Text(ssid)
                        .font(DesignTokens.Typography.captionMedium)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
            }

            Spacer()

            // Health indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(dataManager.networkHealthColor)
                    .frame(width: 8, height: 8)

                Text(dataManager.networkHealthLevel.label)
                    .font(DesignTokens.Typography.captionMedium)
                    .foregroundColor(dataManager.networkHealthColor)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(dataManager.networkHealthColor.opacity(0.15))
            )

            // Refresh button
            Button {
                refreshNetworkData()
            } label: {
                Image(systemName: isRefreshing ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                    .font(.body)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .rotationEffect(isRefreshing ? .degrees(360) : .zero)
                    .animation(isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(DesignTokens.Colors.backgroundSecondary)
    }

    // MARK: - Connection Section

    private var connectionSection: some View {
        ConnectionStatusCard(
            isConnected: dataManager.networkData.isConnected,
            networkName: dataManager.networkData.ssid,
            band: dataManager.wiFiMetrics?.band,
            ipAddress: dataManager.networkData.ipAddress
        )
    }

    // MARK: - Wi-Fi Metrics Section

    private var wifiMetricsSection: some View {
        NetworkSectionCard(
            title: "Wi-Fi Metrics",
            subtitle: dataManager.channelInfo(),
            status: dataManager.wiFiMetrics?.linkRateQuality
        ) {
            if let metrics = dataManager.wiFiMetrics {
                NetworkMetricRow.linkRate(
                    metrics.linkRate,
                    history: dataManager.networkQualityHistory.linkRate.map { $0 }
                )

                NetworkMetricRow.signalStrength(
                    metrics.signalStrength,
                    history: dataManager.networkQualityHistory.signalStrength.map { $0 }
                )

                NetworkMetricRow.noise(
                    metrics.noise,
                    history: dataManager.networkQualityHistory.noise.map { $0 }
                )
            } else {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading Wi-Fi metrics...")
                        .font(DesignTokens.Typography.captionMedium)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Router Quality Section

    private var routerQualitySection: some View {
        NetworkSectionCard(
            title: "Router",
            status: dataManager.routerQuality?.qualityLevel
        ) {
            if let quality = dataManager.routerQuality {
                NetworkMetricRow.ping(
                    quality.ping,
                    history: dataManager.networkQualityHistory.routerPing.map { $0 }
                )

                NetworkMetricRow.jitter(
                    quality.jitter,
                    history: dataManager.networkQualityHistory.routerJitter.map { $0 }
                )

                NetworkMetricRow.packetLoss(
                    quality.packetLoss,
                    tooltip: true
                )
            } else {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Testing router connection...")
                        .font(DesignTokens.Typography.captionMedium)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Internet Quality Section

    private var internetQualitySection: some View {
        NetworkSectionCard(
            title: "Internet",
            subtitle: dataManager.internetQuality?.targetHost,
            status: dataManager.internetQuality?.qualityLevel
        ) {
            if let quality = dataManager.internetQuality {
                NetworkMetricRow.ping(
                    quality.ping,
                    history: dataManager.networkQualityHistory.internetPing.map { $0 }
                )

                NetworkMetricRow.jitter(
                    quality.jitter,
                    history: dataManager.networkQualityHistory.internetJitter.map { $0 }
                )

                NetworkMetricRow.packetLoss(
                    quality.packetLoss,
                    tooltip: true
                )
            } else {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Testing internet connection...")
                        .font(DesignTokens.Typography.captionMedium)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - DNS Section

    private var dnsSection: some View {
        NetworkSectionCard(
            title: "DNS",
            subtitle: dnsSubtitle,
            status: dataManager.dnsData?.lookupQuality,
            action: {
                dataManager.updateDNSInfo()
            },
            actionIcon: "arrow.clockwise"
        ) {
            if let dns = dataManager.dnsData {
                NetworkMetricRow.dnsLookup(
                    dns.lookupTime,
                    history: dataManager.networkQualityHistory.dnsLookup.map { $0 }
                )

                // DNS servers list
                VStack(alignment: .leading, spacing: 6) {
                    Text("DNS Servers")
                        .font(DesignTokens.Typography.captionMedium)
                        .foregroundColor(DesignTokens.Colors.textTertiary)

                    ForEach(dns.servers.prefix(3), id: \.self) { server in
                        HStack {
                            Image(systemName: "server.rack")
                                .font(.caption2)
                                .foregroundColor(DesignTokens.Colors.textTertiary)

                            Text(server)
                                .font(DesignTokens.Typography.monoMedium)
                                .foregroundColor(DesignTokens.Colors.textSecondary)

                            Spacer()

                            if let displayName = DNSService.shared.getDNSDisplayName(server),
                               displayName != server {
                                Text(displayName)
                                    .font(DesignTokens.Typography.captionSmall)
                                    .foregroundColor(DesignTokens.Colors.textTertiary)
                            }
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(DesignTokens.Colors.backgroundSecondary.opacity(0.5))
                        )
                    }
                }
            } else {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading DNS information...")
                        .font(DesignTokens.Typography.captionMedium)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
            }
        }
    }

    private var dnsSubtitle: String? {
        guard let dns = dataManager.dnsData else { return nil }
        let servers = dns.servers.prefix(2).joined(separator: ", ")
        return "\(dns.sourceDescription) (\(servers))"
    }

    // MARK: - Speed Test Section

    private var speedTestSection: some View {
        VStack(spacing: 12) {
            // Speed test button
            SpeedTestButton(
                isRunning: speedTestService.isRunning,
                progress: speedTestService.progress,
                phase: speedTestService.currentPhase
            ) {
                if speedTestService.isRunning {
                    speedTestService.cancelTest()
                } else {
                    startSpeedTest()
                }
            }

            // Show results if available
            if speedTestService.testData.isComplete {
                SpeedTestResults(results: speedTestService.testData)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
    }

    // MARK: - Footer Actions

    private var footerActions: some View {
        HStack(spacing: 12) {
            // Network settings button
            Button {
                openNetworkSettings()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "gear")
                    Text("Network Settings")
                }
                .font(DesignTokens.Typography.captionMedium)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(DesignTokens.Colors.backgroundSecondary)
                )
                .overlay(
                    Capsule()
                        .stroke(DesignTokens.Colors.border, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            Spacer()

            // Quick diagnose button
            Button {
                runDiagnostics()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "stethoscope")
                    Text("Diagnose")
                }
                .font(DesignTokens.Typography.captionMedium)
                .foregroundColor(DesignTokens.Colors.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(DesignTokens.Colors.accent.opacity(0.1))
                )
                .overlay(
                    Capsule()
                        .stroke(DesignTokens.Colors.accent.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 4)
    }

    // MARK: - Actions

    private func refreshNetworkData() {
        isRefreshing = true

        Task {
            // Update Wi-Fi metrics
            WiFiMetricsService.shared.fetchMetrics()

            // Refresh network quality
            dataManager.refreshNetworkQuality()

            // Update DNS info
            dataManager.updateDNSInfo()

            try? await Task.sleep(nanoseconds: 1_000_000_000)

            await MainActor.run {
                isRefreshing = false
            }
        }
    }

    private func startSpeedTest() {
        Task {
            await speedTestService.startTest()
        }
    }

    private func openNetworkSettings() {
        // Open macOS Network preferences
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.network") {
            NSWorkspace.shared.open(url)
        }
    }

    private func runDiagnostics() {
        // Run full diagnostic sweep
        refreshNetworkData()

        // Show diagnostic result in a notification
        let quality = dataManager.networkHealthLevel

        let notification = NSUserNotification()
        notification.title = "Tonic Network Diagnostics"
        notification.informativeText = "Network health: \(quality.label)"

        if quality == .poor {
            notification.soundName = NSUserNotificationDefaultSoundName
        }

        NSUserNotificationCenter.default.deliver(notification)
    }
}

// MARK: - Preview

#Preview("Network Detail View") {
    NetworkDetailViewRedesigned()
        .frame(width: 380, height: 580)
        .preferredColorScheme(.dark)
}
