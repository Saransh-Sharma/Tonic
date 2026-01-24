//
//  NetworkWidgetIndex.swift
//  Tonic
//
//  Index file for network widget components
//  Import this file to access all network widget components
//
//  Task ID: fn-2.8
//

import SwiftUI

// MARK: - Network Widget Redesign
//
// This file provides access to all components of the redesigned network widget.
// The redesign is inspired by the WhyFi app, featuring comprehensive
// network diagnostics with beautiful, animated visualizations.
//
// Usage:
//   In your view, simply create: NetworkDetailViewRedesigned()
//
// Architecture:
//
// DATA LAYER:
// - NetworkMetricsModels.swift    - All data models (WiFiMetricsData, NetworkQualityData, etc.)
// - WiFiMetricsService.swift      - CoreWLAN-based Wi-Fi metrics collection
// - NetworkQualityService.swift   - ICMP ping-based quality testing
// - DNSService.swift              - DNS configuration and lookup testing
// - SpeedTestService.swift        - Bandwidth speed testing
// - NetworkWidgetDataManager.swift - Extension to WidgetDataManager
//
// VIEW LAYER:
// - SparklineChart.swift          - Mini line chart for metric history
// - NetworkMetricRow.swift        - Single metric row with label, value, sparkline
// - NetworkSectionCard.swift      - Card container for metric sections
// - TooltipPopover.swift          - Expandable tooltip explanations
// - SpeedTestButton.swift         - Animated speed test button & results
// - NetworkAnimations.swift        - Animation modifiers and effects
// - NetworkDetailViewRedesigned.swift - Main detail view combining all components
//
// COMPATIBILITY:
// - Requires macOS 14.0+
// - Uses CoreWLAN for Wi-Fi metrics (no additional permissions needed)
// - Uses Network framework for ping testing

// MARK: - Re-exports

// Data models
@_exported import struct NetworkMetricsModels.WiFiMetricsData
@_exported import struct NetworkMetricsModels.WiFiBand
@_exported import struct NetworkMetricsModels.WiFiSecurity
@_exported import struct NetworkMetricsModels.NetworkQualityData
@_exported import struct NetworkMetricsModels.QualityLevel
@_exported import struct NetworkMetricsModels.QualityColor
@_exported import struct NetworkMetricsModels.DNSData
@_exported import struct NetworkMetricsModels.DNSSource
@_exported import struct NetworkMetricsModels.SpeedTestData
@_exported import struct NetworkMetricsModels.NetworkMetricHistory

// Services are accessed via their singletons:
// - WiFiMetricsService.shared
// - NetworkQualityService.shared
// - DNSService.shared
// - SpeedTestService.shared

// Main view
public typealias NetworkDetailView = NetworkDetailViewRedesigned

// MARK: - Quick Start Example

/*
 To use the redesigned network widget in your app:

 1. Start monitoring in your app initialization:
    ```swift
    WidgetDataManager.shared.startNetworkQualityMonitoring()
    ```

 2. Display the detail view:
    ```swift
    NetworkDetailViewRedesigned()
    ```

 3. For the menu bar widget, update NetworkStatusItem:
    ```swift
    public override func createDetailView() -> AnyView {
        AnyView(NetworkDetailViewRedesigned())
    }
    ```
 */

// MARK: - Theme Guide

/// Color scheme for network quality indicators
public enum NetworkQualityTheme {
    /// Green color for excellent/good metrics
    public static var excellent: Color { TonicColors.success }

    /// Yellow/Orange color for fair/warning metrics
    public static var fair: Color { TonicColors.warning }

    /// Red color for poor/critical metrics
    public static var poor: Color { TonicColors.error }

    /// Gray color for unknown/unavailable metrics
    public static var unknown: Color { Color.secondary }
}

// MARK: - Feature Checklist

/// Complete feature list for the redesigned network widget:
///
/// Wi-Fi Metrics:
/// ✓ Link rate (connection speed in Mbps)
/// ✓ Signal strength (RSSI in dBm)
/// ✓ Noise floor (dBm)
/// ✓ Signal-to-noise ratio (computed)
/// ✓ Channel number and width
/// ✓ Frequency band (2.4/5/6 GHz)
/// ✓ Security type (WPA2/WPA3)
/// ✓ BSSID (router MAC address)
///
/// Network Quality:
/// ✓ Ping to router
/// ✓ Ping to internet (Cloudflare, Google, OpenDNS)
/// ✓ Jitter measurement
/// ✓ Packet loss detection
/// ✓ Historical data tracking (60 points)
///
/// DNS Information:
/// ✓ Configured DNS servers
/// ✓ DNS source detection (router/DHCP/manual)
/// ✓ Encrypted DNS detection
/// ✓ Lookup time testing
/// ✓ Server identification (Cloudflare, Google, etc.)
///
/// Speed Testing:
/// ✓ Download speed test
/// ✓ Upload speed test
/// ✓ Latency measurement
/// ✓ Progress indication
/// ✓ Results display
///
/// UI/UX:
/// ✓ Color-coded health indicators
/// ✓ Mini sparkline charts for all metrics
/// ✓ Expandable tooltips with explanations
/// ✓ Animated status transitions
/// ✓ Card-based section layout
/// ✓ Dark theme optimized
/// ✓ Refresh controls
/// ✓ Quick diagnostics button

// MARK: - Preview Provider

#Preview("Network Widget - All States") {
    VStack(spacing: 20) {
        Text("Network Widget Redesign")
            .font(.title)
            .fontWeight(.bold)

        NetworkDetailViewRedesigned()
            .frame(height: 500)
            .cornerRadius(12)
    }
    .padding()
    .frame(width: 400, height: 600)
    .background(Color.black)
}
