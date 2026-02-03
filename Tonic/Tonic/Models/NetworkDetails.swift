//
//  NetworkDetails.swift
//  Tonic
//
//  Extended network information data models
//  Task ID: fn-6-i4g.2
//

import Foundation

// MARK: - WiFiBand Extension

extension WiFiBand {
    /// Display name for the band
    public var displayName: String {
        rawValue
    }
}

// MARK: - WiFi Details

/// Extended WiFi network information
/// Captures detailed WiFi connection data beyond basic status
public struct WiFiDetails: Sendable, Codable, Equatable {
    /// Network SSID
    public let ssid: String

    /// Received Signal Strength Indicator (dBm)
    /// Typical range: -100 (weak) to -30 (strong)
    public let rssi: Int

    /// Noise level (dBm)
    /// Typical range: -100 (high noise) to -30 (low noise)
    public let noise: Int

    /// WiFi channel (1-165 for 2.4GHz/5GHz)
    public let channel: Int

    /// Channel width in MHz (20, 40, 80, 160)
    public let channelWidth: Int

    /// Frequency band
    public let band: WiFiBand

    /// Security type (WPA2, WPA3, Open, etc.)
    public let security: String

    /// Wi-Fi standard (e.g., 802.11ac)
    public let standard: String

    /// BSSID (MAC address of access point)
    public let bssid: String

    public init(
        ssid: String,
        rssi: Int,
        noise: Int = -90,
        channel: Int,
        channelWidth: Int = 20,
        band: WiFiBand = .ghz24,
        security: String,
        standard: String = "Unknown",
        bssid: String
    ) {
        self.ssid = ssid
        self.rssi = rssi
        self.noise = noise
        self.channel = channel
        self.channelWidth = channelWidth
        self.band = band
        self.security = security
        self.standard = standard
        self.bssid = bssid
    }

    /// Signal quality percentage based on RSSI
    public var signalQuality: Double {
        // Map RSSI -100 to -30 onto 0-100 scale
        let clamped = Double(max(-100, min(-30, rssi)))
        return ((clamped + 100) / 70) * 100
    }

    /// Signal-to-noise ratio (SNR) in dB
    /// Higher is better (typical: 20-40 dB)
    public var snr: Int {
        rssi - noise
    }

    /// Signal strength description
    public var signalStrength: SignalStrength {
        switch signalQuality {
        case 0..<25: return .poor
        case 25..<50: return .fair
        case 50..<75: return .good
        default: return .excellent
        }
    }
}

/// Channel width in MHz
public enum ChannelWidth: Int, Sendable, Codable {
    case twenty = 20
    case forty = 40
    case eighty = 80
    case oneSixty = 160

    public var displayName: String {
        "\(rawValue) MHz"
    }
}

/// Signal strength classification
public enum SignalStrength: String, Sendable {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"

    public var colorHex: String {
        switch self {
        case .excellent: return "#34C759"  // Green
        case .good: return "#30D158"       // Light green
        case .fair: return "#FF9F0A"       // Orange
        case .poor: return "#FF3B30"       // Red
        }
    }
}

// MARK: - Public IP Info

/// Public IP address tracking information
/// Used for external IP monitoring and geolocation
public struct PublicIPInfo: Sendable, Codable, Equatable {
    /// Public IP address
    public let ipAddress: String

    /// Country code/name (optional)
    public let country: String?

    /// City name (optional)
    public let city: String?

    /// ISP name (optional)
    public let isp: String?

    /// When this information was fetched
    public let timestamp: Date

    public init(
        ipAddress: String,
        country: String? = nil,
        city: String? = nil,
        isp: String? = nil,
        timestamp: Date = Date()
    ) {
        self.ipAddress = ipAddress
        self.country = country
        self.city = city
        self.isp = isp
        self.timestamp = timestamp
    }

    /// Location description combining city and country
    public var locationDescription: String? {
        guard let city = city, let country = country else {
            return city ?? country
        }
        return "\(city), \(country)"
    }

    /// Whether the IP info is stale (older than 1 hour)
    public var isStale: Bool {
        Date().timeIntervalSince(timestamp) > 3600
    }
}

// MARK: - Connectivity Info

/// Network connectivity testing information
/// Measures latency, jitter, and reachability to external servers
public struct ConnectivityInfo: Sendable, Codable, Equatable {
    /// Average latency in milliseconds
    public let latency: Double

    /// Jitter (variance in latency) in milliseconds
    public let jitter: Double

    /// Whether the target server is reachable
    public let isReachable: Bool

    /// When this measurement was taken
    public let timestamp: Date

    public init(
        latency: Double,
        jitter: Double,
        isReachable: Bool,
        timestamp: Date = Date()
    ) {
        self.latency = latency
        self.jitter = jitter
        self.isReachable = isReachable
        self.timestamp = timestamp
    }

    /// Connection quality based on latency
    public var quality: ConnectionQuality {
        guard isReachable else { return .offline }
        switch latency {
        case 0..<50: return .excellent
        case 50..<100: return .good
        case 100..<200: return .fair
        default: return .poor
        }
    }
}

/// Connection quality classification
public enum ConnectionQuality: String, Sendable {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
    case offline = "Offline"

    public var colorHex: String {
        switch self {
        case .excellent: return "#34C759"  // Green
        case .good: return "#30D158"       // Light green
        case .fair: return "#FF9F0A"       // Orange
        case .poor: return "#FF3B30"       // Red
        case .offline: return "#8E8E93"    // Gray
        }
    }
}

// MARK: - Process Network Usage

/// Network usage information for a single process
public struct ProcessNetworkUsage: Sendable, Identifiable, Equatable {
    public let id: UUID
    public let pid: Int
    public let name: String
    public let uploadBytes: UInt64
    public let downloadBytes: UInt64
    public let totalBytes: UInt64

    public init(
        pid: Int,
        name: String,
        uploadBytes: UInt64,
        downloadBytes: UInt64
    ) {
        self.id = UUID()
        self.pid = pid
        self.name = name
        self.uploadBytes = uploadBytes
        self.downloadBytes = downloadBytes
        self.totalBytes = uploadBytes + downloadBytes
    }

    /// Formatted upload string
    public var uploadString: String {
        ByteCountFormatter.string(fromByteCount: Int64(uploadBytes), countStyle: .binary)
    }

    /// Formatted download string
    public var downloadString: String {
        ByteCountFormatter.string(fromByteCount: Int64(downloadBytes), countStyle: .binary)
    }

    /// Total usage percentage (relative to a provided max)
    public func usagePercentage(of maxBytes: UInt64) -> Double {
        guard maxBytes > 0 else { return 0 }
        return Double(totalBytes) / Double(maxBytes) * 100
    }
}

// MARK: - Connection Type Extension

/// Network connection type with enhanced details
public enum ConnectionType: String, Sendable, Codable {
    case ethernet = "ethernet"
    case wifi = "wifi"
    case cellular = "cellular"
    case tethered = "tethered"
    case disconnected = "disconnected"
    case unknown = "unknown"

    public var displayName: String {
        switch self {
        case .ethernet: return "Ethernet"
        case .wifi: return "Wi-Fi"
        case .cellular: return "Cellular"
        case .tethered: return "Tethered"
        case .disconnected: return "Disconnected"
        case .unknown: return "Unknown"
        }
    }

    public var iconName: String {
        switch self {
        case .ethernet: return "cable.connector"
        case .wifi: return "wifi"
        case .cellular: return "antenna.radiowaves.left.and.right"
        case .tethered: return "personalhotspot"
        case .disconnected: return "wifi.slash"
        case .unknown: return "questionmark.circle"
        }
    }
}
