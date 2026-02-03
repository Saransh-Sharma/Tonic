//
//  NetworkMetricsModels.swift
//  Tonic
//
//  Enhanced network monitoring data models
//  Task ID: fn-2.8.1
//

import Foundation
import CoreWLAN
import SwiftUI

// MARK: - WiFi Metrics Data

/// Detailed Wi-Fi metrics for network diagnostics
public struct WiFiMetricsData: Sendable {
    public let linkRate: Double?              // Mbps - Current connection speed
    public let signalStrength: Double?        // dBm - RSSI (Received Signal Strength Indicator)
    public let noise: Double?                 // dBm - Noise floor
    public let snr: Double?                   // Signal-to-noise ratio (computed)
    public let channel: Int?                  // WiFi channel number
    public let channelWidth: Int?             // Channel width in MHz (20, 40, 80, 160)
    public let band: WiFiBand?                // 2.4GHz, 5GHz, 6GHz
    public let security: WiFiSecurity?        // WPA2, WPA3, etc.
    public let bssid: String?                 // Router MAC address
    public let interfaceName: String?         // Network interface (en0, etc.)
    public let timestamp: Date

    public init(linkRate: Double? = nil,
                signalStrength: Double? = nil,
                noise: Double? = nil,
                channel: Int? = nil,
                channelWidth: Int? = nil,
                band: WiFiBand? = nil,
                security: WiFiSecurity? = nil,
                bssid: String? = nil,
                interfaceName: String? = nil,
                timestamp: Date = Date()) {

        self.linkRate = linkRate
        self.signalStrength = signalStrength
        self.noise = noise
        self.channel = channel
        self.channelWidth = channelWidth
        self.band = band
        self.security = security
        self.bssid = bssid
        self.interfaceName = interfaceName
        self.timestamp = timestamp

        // Compute SNR if we have both signal and noise
        if let signal = signalStrength, let noiseLevel = noise {
            self.snr = signal - noiseLevel
        } else {
            self.snr = nil
        }
    }

    // MARK: - Quality Assessments

    /// Signal quality level based on dBm
    public var signalQuality: SignalQuality {
        guard let signal = signalStrength else { return .unknown }
        switch signal {
        case -50...0: return .excellent
        case -60..<(-50): return .good
        case -70..<(-60): return .fair
        case -80..<(-70): return .poor
        default: return .terrible
        }
    }

    /// Link rate quality assessment
    public var linkRateQuality: QualityLevel {
        guard let rate = linkRate else { return .unknown }
        switch rate {
        case 800...: return .excellent  // 800+ Mbps
        case 400..<800: return .good    // 400-800 Mbps
        case 150..<400: return .fair    // 150-400 Mbps
        case 50..<150: return .poor     // 50-150 Mbps
        default: return .poor           // < 50 Mbps
        }
    }

    /// User-friendly description of signal strength
    public var signalDescription: String {
        switch signalQuality {
        case .excellent: return "Excellent signal"
        case .good: return "Good signal"
        case .fair: return "Functional but not ideal"
        case .poor: return "Weak signal - consider moving closer"
        case .terrible: return "Very weak signal - connection unstable"
        case .unknown: return "Unknown"
        }
    }

    /// Color for signal strength display
    public var signalColor: SignalColor {
        switch signalQuality {
        case .excellent, .good: return .green
        case .fair: return .yellow
        case .poor, .terrible: return .red
        case .unknown: return .gray
        }
    }
}

/// WiFi frequency band
public enum WiFiBand: String, Sendable, CaseIterable, Codable {
    case ghz24 = "2.4 GHz"
    case ghz5 = "5 GHz"
    case ghz6 = "6 GHz"
    case unknown = "Unknown"

    /// Icon representing the band
    public var icon: String {
        switch self {
        case .ghz24: return "antenna.radiowaves.left.and.right"
        case .ghz5: return "antenna.radiowaves.left.and.right.split"
        case .ghz6: return "wave.3.right"
        case .unknown: return "questionmark.circle"
        }
    }

    /// Wi-Fi generation indicator
    public var generation: String? {
        switch self {
        case .ghz6: return "Wi-Fi 6E/7"
        case .ghz5: return "Wi-Fi 5/6"
        case .ghz24: return "Wi-Fi 4/5"
        case .unknown: return nil
        }
    }
}

/// WiFi security type
public enum WiFiSecurity: String, Sendable, CaseIterable {
    case none = "Open"
    case wep = "WEP"
    case wpa = "WPA"
    case wpa2 = "WPA2"
    case wpa3 = "WPA3"
    case wpa2Enterprise = "WPA2 Enterprise"
    case wpa3Enterprise = "WPA3 Enterprise"
    case unknown = "Unknown"

    public var isSecure: Bool {
        switch self {
        case .none, .wep, .unknown: return false
        default: return true
        }
    }

    public var icon: String {
        isSecure ? "lock.fill" : "lock.open.fill"
    }
}

/// Signal quality level
public enum SignalQuality: Sendable {
    case excellent    // -50 dBm or better
    case good         // -50 to -60 dBm
    case fair         // -60 to -70 dBm
    case poor         // -70 to -80 dBm
    case terrible     // worse than -80 dBm
    case unknown
}

/// Signal color for UI display
public enum SignalColor: Sendable {
    case green, yellow, red, gray
}

// MARK: - Network Quality Data

/// Network quality metrics (ping, jitter, packet loss)
public struct NetworkQualityData: Sendable, Codable {
    public let ping: TimeInterval?           // milliseconds
    public let jitter: TimeInterval?         // milliseconds (variance)
    public let packetLoss: Double?           // percentage 0-100
    public let targetHost: String            // What was pinged
    public let targetName: String            // Display name (Router, Internet, etc.)
    public let timestamp: Date

    public init(ping: TimeInterval? = nil,
                jitter: TimeInterval? = nil,
                packetLoss: Double? = nil,
                targetHost: String = "",
                targetName: String = "",
                timestamp: Date = Date()) {

        self.ping = ping
        self.jitter = jitter
        self.packetLoss = packetLoss
        self.targetHost = targetHost
        self.targetName = targetName
        self.timestamp = timestamp
    }

    // MARK: - Computed Quality

    /// Overall quality level based on all metrics
    public var qualityLevel: QualityLevel {
        // Packet loss is most critical
        if let loss = packetLoss {
            if loss >= 10 { return .poor }
            if loss >= 5 { return .fair }
        }

        // Jitter second most critical
        if let j = jitter {
            if j >= 100 { return .poor }
            if j >= 50 { return .fair }
        }

        // Ping is least critical but most visible
        if let p = ping {
            if p >= 200 { return .poor }
            if p >= 100 { return .fair }
            if p >= 50 { return .good }
            if p < 20 { return .excellent }
        }

        return .good
    }

    /// Color for quality display
    public var qualityColor: QualityColor {
        switch qualityLevel {
        case .excellent, .good: return .green
        case .fair: return .yellow
        case .poor: return .red
        case .unknown: return .gray
        }
    }

    /// Formatted ping string
    public var pingString: String {
        guard let p = ping else { return "--" }
        return String(format: "%.0f ms", p * 1000)
    }

    /// Formatted jitter string
    public var jitterString: String {
        guard let j = jitter else { return "--" }
        return String(format: "%.1f ms", j * 1000)
    }

    /// Formatted packet loss string
    public var lossString: String {
        guard let l = packetLoss else { return "--" }
        return String(format: "%.0f%%", l)
    }
}

/// Overall network quality level
public enum QualityLevel: Sendable, Codable {
    case excellent    // Excellent: ping < 20ms, jitter < 10ms, loss < 1%
    case good         // Good: ping < 50ms, jitter < 30ms, loss < 2%
    case fair         // Fair: ping < 100ms, jitter < 50ms, loss < 5%
    case poor         // Poor: anything worse
    case unknown

    public var color: QualityColor {
        switch self {
        case .excellent, .good: return .green
        case .fair: return .yellow
        case .poor: return .red
        case .unknown: return .gray
        }
    }

    public var icon: String {
        switch self {
        case .excellent: return "checkmark.circle.fill"
        case .good: return "checkmark.circle"
        case .fair: return "exclamationmark.triangle.fill"
        case .poor: return "xmark.circle.fill"
        case .unknown: return "questionmark.circle"
        }
    }

    public var label: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .fair: return "Fair"
        case .poor: return "Poor"
        case .unknown: return "Unknown"
        }
    }
}

/// Quality color for UI theming
public enum QualityColor: Sendable {
    case green, yellow, red, gray

    public var swiftUIColor: SwiftUI.Color {
        switch self {
        case .green: return TonicColors.success
        case .yellow: return TonicColors.warning
        case .red: return TonicColors.error
        case .gray: return SwiftUI.Color.secondary
        }
    }
}

// MARK: - DNS Data

/// DNS configuration and performance data
public struct DNSData: Sendable {
    public let servers: [String]              // DNS server IPs
    public let source: DNSSource              // How DNS was configured
    public let lookupTime: TimeInterval?      // Average DNS lookup in ms
    public let testDomain: String             // Domain used for lookup test
    public let timestamp: Date

    public init(servers: [String] = [],
                source: DNSSource = .unknown,
                lookupTime: TimeInterval? = nil,
                testDomain: String = "example.com",
                timestamp: Date = Date()) {

        self.servers = servers
        self.source = source
        self.lookupTime = lookupTime
        self.testDomain = testDomain
        self.timestamp = timestamp
    }

    /// Primary DNS server (first in list)
    public var primaryServer: String? {
        servers.first
    }

    /// Formatted lookup time string
    public var lookupString: String {
        guard let time = lookupTime else { return "--" }
        return String(format: "%.0f ms", time * 1000)
    }

    /// Display description of DNS source
    public var sourceDescription: String {
        switch source {
        case .router: return "Router assigned"
        case .dhcp: return "DHCP assigned"
        case .manual: return "Manual"
        case .secure: return "Encrypted DNS"
        case .unknown: return "Unknown"
        }
    }

    /// Quality assessment of DNS lookup time
    public var lookupQuality: QualityLevel {
        guard let time = lookupTime else { return .unknown }
        let ms = time * 1000
        switch ms {
        case 0..<30: return .excellent
        case 30..<60: return .good
        case 60..<150: return .fair
        default: return .poor
        }
    }
}

/// DNS configuration source
public enum DNSSource: Sendable {
    case router       // Assigned via router DHCP
    case dhcp         // Direct from ISP DHCP
    case manual       // Manually configured
    case secure       // DoH, DoT, or other encrypted DNS
    case unknown

    public var icon: String {
        switch self {
        case .router: return "router"
        case .dhcp: return "network"
        case .manual: return "hand.tap"
        case .secure: return "lock.shield"
        case .unknown: return "questionmark.circle"
        }
    }
}

// MARK: - Speed Test Data

/// Speed test results
public struct SpeedTestData: Sendable {
    public let downloadSpeed: Double?        // Mbps
    public let uploadSpeed: Double?          // Mbps
    public let ping: TimeInterval?           // milliseconds
    public let jitter: TimeInterval?         // milliseconds
    public let server: String?               // Test server info
    public let isp: String?                  // ISP name
    public let isRunning: Bool               // Test in progress
    public let progress: Double              // 0-1 progress
    public let timestamp: Date

    public init(downloadSpeed: Double? = nil,
                uploadSpeed: Double? = nil,
                ping: TimeInterval? = nil,
                jitter: TimeInterval? = nil,
                server: String? = nil,
                isp: String? = nil,
                isRunning: Bool = false,
                progress: Double = 0,
                timestamp: Date = Date()) {

        self.downloadSpeed = downloadSpeed
        self.uploadSpeed = uploadSpeed
        self.ping = ping
        self.jitter = jitter
        self.server = server
        self.isp = isp
        self.isRunning = isRunning
        self.progress = progress
        self.timestamp = timestamp
    }

    /// Formatted download speed
    public var downloadString: String {
        guard let speed = downloadSpeed else { return "--" }
        return String(format: "%.1f Mbps", speed)
    }

    /// Formatted upload speed
    public var uploadString: String {
        guard let speed = uploadSpeed else { return "--" }
        return String(format: "%.1f Mbps", speed)
    }

    /// Overall test completion state
    public var isComplete: Bool {
        downloadSpeed != nil && uploadSpeed != nil && !isRunning
    }
}

// MARK: - Network Metric History

/// Time-series data point for network metrics
public struct NetworkMetricHistoryPoint: Identifiable, Sendable {
    public let id = UUID()
    public let value: Double
    public let timestamp: Date

    public init(value: Double, timestamp: Date = Date()) {
        self.value = value
        self.timestamp = timestamp
    }
}

/// History container for various network metrics
public struct NetworkMetricHistory: Sendable {
    public var linkRate: [NetworkMetricHistoryPoint]
    public var signalStrength: [NetworkMetricHistoryPoint]
    public var noise: [NetworkMetricHistoryPoint]
    public var routerPing: [NetworkMetricHistoryPoint]
    public var routerJitter: [NetworkMetricHistoryPoint]
    public var internetPing: [NetworkMetricHistoryPoint]
    public var internetJitter: [NetworkMetricHistoryPoint]
    public var dnsLookup: [NetworkMetricHistoryPoint]

    public init(linkRate: [NetworkMetricHistoryPoint] = [],
                signalStrength: [NetworkMetricHistoryPoint] = [],
                noise: [NetworkMetricHistoryPoint] = [],
                routerPing: [NetworkMetricHistoryPoint] = [],
                routerJitter: [NetworkMetricHistoryPoint] = [],
                internetPing: [NetworkMetricHistoryPoint] = [],
                internetJitter: [NetworkMetricHistoryPoint] = [],
                dnsLookup: [NetworkMetricHistoryPoint] = []) {

        self.linkRate = linkRate
        self.signalStrength = signalStrength
        self.noise = noise
        self.routerPing = routerPing
        self.routerJitter = routerJitter
        self.internetPing = internetPing
        self.internetJitter = internetJitter
        self.dnsLookup = dnsLookup
    }

    /// Maximum number of history points to keep
    public static let maxHistoryPoints = 60

    /// Add a new data point, trimming to max
    public mutating func add(to keyPath: WritableKeyPath<NetworkMetricHistory, [NetworkMetricHistoryPoint]>, value: Double) {
        var points = self[keyPath: keyPath]
        points.append(NetworkMetricHistoryPoint(value: value))
        if points.count > Self.maxHistoryPoints {
            points.removeFirst()
        }
        self[keyPath: keyPath] = points
    }

    /// Get history values as doubles for charting
    public func values(for keyPath: KeyPath<NetworkMetricHistory, [NetworkMetricHistoryPoint]>) -> [Double] {
        self[keyPath: keyPath].map { $0.value }
    }
}
