//
//  NetworkWidgetDataManager.swift
//  Tonic
//
//  Extension to WidgetDataManager for enhanced network widget data
//  Task ID: fn-2.8.6
//

import Foundation
import SwiftUI
import os

// MARK: - Network Quality History Store

/// Singleton to hold network quality history data (workaround for extensions not allowing stored properties)
public final class NetworkQualityHistoryStore: @unchecked Sendable {
    public static let shared = NetworkQualityHistoryStore()
    public var history = NetworkMetricHistory()
    private init() {}
}

// MARK: - Widget DataManager Extension

/// Extension to WidgetDataManager that provides enhanced network metrics
extension WidgetDataManager {

    // MARK: - Enhanced Network Properties

    /// Wi-Fi specific metrics (signal, noise, link rate, etc.)
    public var wiFiMetrics: WiFiMetricsData? {
        WiFiMetricsService.shared.currentMetrics
    }

    /// Router network quality (ping, jitter, packet loss to gateway)
    public var routerQuality: NetworkQualityData? {
        NetworkQualityService.shared.routerQuality
    }

    /// Internet network quality (ping, jitter, packet loss to external server)
    public var internetQuality: NetworkQualityData? {
        NetworkQualityService.shared.internetQuality
    }

    /// DNS configuration and performance
    public var dnsData: DNSData? {
        DNSService.shared.currentDNS
    }

    /// Speed test results
    public var speedTestData: SpeedTestData {
        SpeedTestService.shared.testData
    }

    /// History data for network quality metrics
    public var networkQualityHistory: NetworkMetricHistory {
        NetworkQualityHistoryStore.shared.history
    }

    // MARK: - Service Starters

    /// Start enhanced network monitoring
    public func startNetworkQualityMonitoring() {
        WiFiMetricsService.shared.startMonitoring()
        NetworkQualityService.shared.startMonitoring()

        // Update DNS info periodically
        updateDNSInfo()

        // Set up recurring DNS updates
        Task {
            while true {
                try? await Task.sleep(nanoseconds: 60_000_000_000)  // 1 minute
                self.updateDNSInfo()
            }
        }
    }

    /// Stop enhanced network monitoring
    public func stopNetworkQualityMonitoring() {
        WiFiMetricsService.shared.stopMonitoring()
        NetworkQualityService.shared.stopMonitoring()
    }

    /// Update DNS information
    public func updateDNSInfo() {
        DNSService.shared.refresh()
    }

    /// Force refresh all network quality data
    public func refreshNetworkQuality() {
        Task {
            // Update Wi-Fi metrics
            WiFiMetricsService.shared.fetchMetrics()

            // Test router quality
            let routerResult = await NetworkQualityService.shared.testRouterQuality()

            // Test internet quality
            let internetResult = await NetworkQualityService.shared.testInternetQuality()

            await MainActor.run {
                self.addToHistory(routerQuality: routerResult)
                self.addToHistory(internetQuality: internetResult)
            }
        }
    }

    // MARK: - History Management

    /// Add router quality data point to history
    private func addToHistory(routerQuality: NetworkQualityData) {
        if let ping = routerQuality.ping {
            NetworkQualityHistoryStore.shared.history.add(to: \.routerPing, value: ping * 1000)
        }
        if let jitter = routerQuality.jitter {
            NetworkQualityHistoryStore.shared.history.add(to: \.routerJitter, value: jitter * 1000)
        }
    }

    /// Add internet quality data point to history
    private func addToHistory(internetQuality: NetworkQualityData) {
        if let ping = internetQuality.ping {
            NetworkQualityHistoryStore.shared.history.add(to: \.internetPing, value: ping * 1000)
        }
        if let jitter = internetQuality.jitter {
            NetworkQualityHistoryStore.shared.history.add(to: \.internetJitter, value: jitter * 1000)
        }
    }

    /// Add Wi-Fi metrics data point to history
    public func addToHistory(wiFiMetrics: WiFiMetricsData) {
        if let linkRate = wiFiMetrics.linkRate {
            NetworkQualityHistoryStore.shared.history.add(to: \.linkRate, value: linkRate)
        }
        if let signal = wiFiMetrics.signalStrength {
            NetworkQualityHistoryStore.shared.history.add(to: \.signalStrength, value: signal)
        }
        if let noise = wiFiMetrics.noise {
            NetworkQualityHistoryStore.shared.history.add(to: \.noise, value: noise)
        }
    }

    /// Add DNS lookup time to history
    public func addToHistory(dnsLookup: TimeInterval) {
        NetworkQualityHistoryStore.shared.history.add(to: \.dnsLookup, value: dnsLookup * 1000)
    }

    // MARK: - Computed Properties

    /// Overall network health assessment
    public var networkHealthLevel: QualityLevel {
        // Check internet quality first
        if let internet = internetQuality {
            return internet.qualityLevel
        }
        // Fall back to router quality
        if let router = routerQuality {
            return router.qualityLevel
        }
        // Check basic connectivity
        return networkData.isConnected ? .good : .poor
    }

    /// Whether network issues are detected
    public var hasNetworkIssues: Bool {
        switch networkHealthLevel {
        case .poor, .unknown:
            return !networkData.isConnected
        default:
            return false
        }
    }

    /// Color representing current network health
    public var networkHealthColor: Color {
        networkHealthLevel.color.swiftUIColor
    }

    // MARK: - Helper Methods

    /// Get signal strength as a percentage (0-100)
    public func signalPercentage() -> Double? {
        guard let signal = wiFiMetrics?.signalStrength else { return nil }

        // Convert dBm to percentage
        // -30 dBm = 100%, -90 dBm = 0%
        let clamped = max(-90, min(-30, signal))
        return ((clamped + 90) / 60) * 100
    }

    /// Get formatted Wi-Fi channel info
    public func channelInfo() -> String? {
        WiFiMetricsService.shared.getChannelInfo()
    }

    /// Get Wi-Fi security type display name
    public func securityDisplay() -> String? {
        wiFiMetrics?.security?.rawValue
    }

    /// Check if current connection is Wi-Fi
    public var isWiFiConnection: Bool {
        networkData.connectionType == .wifi
    }

    /// Get connection icon for current network type
    public func connectionTypeIcon() -> String {
        switch networkData.connectionType {
        case .wifi:
            return "wifi.fill"
        case .ethernet:
            return "cable.connector"
        case .cellular:
            return "antenna.radiowaves.left.and.right.fill"
        case .unknown:
            return "network"
        }
    }
}

// MARK: - Color Extension

extension Color {
    /// Initialize from QualityColor
    init(_ qualityColor: QualityColor) {
        self = qualityColor.swiftUIColor
    }
}
