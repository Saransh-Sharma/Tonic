//
//  NetworkDetails.swift
//  Tonic
//
//  Extended network information data models
//  Task ID: fn-6-i4g.2
//

import Foundation

// MARK: - WiFi Details

/// Extended WiFi network information
/// Captures detailed WiFi connection data beyond basic status
public struct WiFiDetails: Sendable, Codable, Equatable {
    /// Network SSID
    public let ssid: String

    /// Received Signal Strength Indicator (dBm)
    /// Typical range: -100 (weak) to -30 (strong)
    public let rssi: Int

    /// WiFi channel (1-165 for 2.4GHz/5GHz)
    public let channel: Int

    /// Security type (WPA2, WPA3, Open, etc.)
    public let security: String

    /// BSSID (MAC address of access point)
    public let bssid: String

    public init(
        ssid: String,
        rssi: Int,
        channel: Int,
        security: String,
        bssid: String
    ) {
        self.ssid = ssid
        self.rssi = rssi
        self.channel = channel
        self.security = security
        self.bssid = bssid
    }

    /// Signal quality percentage based on RSSI
    public var signalQuality: Double {
        // Map RSSI -100 to -30 onto 0-100 scale
        let clamped = Double(max(-100, min(-30, rssi)))
        return ((clamped + 100) / 70) * 100
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
