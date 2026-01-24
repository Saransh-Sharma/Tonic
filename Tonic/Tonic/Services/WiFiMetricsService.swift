//
//  WiFiMetricsService.swift
//  Tonic
//
//  Service for fetching detailed Wi-Fi metrics using CoreWLAN
//  Task ID: fn-2.8.2
//

import Foundation
import CoreWLAN
import os
import SwiftUI

// MARK: - WiFi Metrics Service

/// Service for collecting detailed Wi-Fi network metrics using CoreWLAN
@MainActor
@Observable
public final class WiFiMetricsService {
    public static let shared = WiFiMetricsService()

    private let logger = Logger(subsystem: "com.tonic.app", category: "WiFiMetricsService")

    private var wifiClient: CWWiFiClient?
    private var wifiInterface: CWInterface?

    // Current metrics
    public private(set) var currentMetrics: WiFiMetricsData?
    public private(set) var isMonitoring = false
    public private(set) var lastError: Error?

    private init() {
        initializeWiFiClient()
    }

    // MARK: - Initialization

    private func initializeWiFiClient() {
        do {
            wifiClient = CWWiFiClient.shared()
            logger.info("CoreWLAN client initialized successfully")
        } catch {
            logger.error("Failed to initialize CoreWLAN client: \(error.localizedDescription)")
            lastError = error
        }
    }

    // MARK: - Public Methods

    /// Start monitoring Wi-Fi metrics
    public func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        logger.info("Wi-Fi metrics monitoring started")
    }

    /// Stop monitoring Wi-Fi metrics
    public func stopMonitoring() {
        isMonitoring = false
        logger.info("Wi-Fi metrics monitoring stopped")
    }

    /// Fetch current Wi-Fi metrics
    public func fetchMetrics() -> WiFiMetricsData? {
        guard let interface = getCurrentInterface() else {
            logger.debug("No Wi-Fi interface available")
            return nil
        }

        guard interface.powerOn() else {
            logger.debug("Wi-Fi interface is powered off")
            return nil
        }

        guard interface.ssid() != nil else {
            logger.debug("Not connected to a Wi-Fi network")
            return nil
        }

        let metrics = collectMetrics(from: interface)
        currentMetrics = metrics
        return metrics
    }

    /// Get the current SSID
    public func getSSID() -> String? {
        getCurrentInterface()?.ssid()
    }

    /// Get the current BSSID (router MAC address)
    public func getBSSID() -> String? {
        getCurrentInterface()?.bssid()
    }

    /// Check if Wi-Fi is connected
    public func isConnected() -> Bool {
        guard let interface = getCurrentInterface() else { return false }
        return interface.powerOn() && interface.ssid() != nil
    }

    /// Get Wi-Fi interface name
    public func getInterfaceName() -> String? {
        getCurrentInterface()?.interfaceName
    }

    // MARK: - Private Methods

    private func getCurrentInterface() -> CWInterface? {
        // Cache the interface for performance
        if let cached = wifiInterface, cached.interfaceName != nil {
            return cached
        }

        guard let client = wifiClient,
              let interfaces = client.interfaces(),
              let interface = interfaces.first else {
            return nil
        }

        wifiInterface = interface
        return interface
    }

    private func collectMetrics(from interface: CWInterface) -> WiFiMetricsData {
        // Link rate (transmit rate in Mbps)
        let linkRate = interface.transmitRate() as Double

        // Signal strength (RSSI in dBm) - using rawValue as NSNumber
        let signalStrength: Double?
        if let rssi = interface.rssi() {
            signalStrength = Double(truncating: rssi)
        } else {
            signalStrength = nil
        }

        // Noise floor in dBm
        let noise: Double?
        if let noiseValue = interface.noise() {
            noise = Double(truncating: noiseValue)
        } else {
            noise = nil
        }

        // Channel information
        let channel = interface.wlanChannel()
        let channelNumber = channel?.channelNumber
        let channelWidth = channel?.channelWidth

        // Determine band from channel number
        let band = determineBand(from: channelNumber)

        // Security type
        let security = determineSecurity(from: interface)

        // BSSID
        let bssid = interface.bssid()

        // Interface name
        let interfaceName = interface.interfaceName

        let metrics = WiFiMetricsData(
            linkRate: linkRate,
            signalStrength: signalStrength,
            noise: noise,
            channel: channelNumber,
            channelWidth: channelWidth as Int?,
            band: band,
            security: security,
            bssid: bssid,
            interfaceName: interfaceName
        )

        logger.debug("Wi-Fi metrics: SSID=\(interface.ssid() ?? "nil"), RSSI=\(signalStrength ?? 0), Link Rate=\(linkRate)")

        return metrics
    }

    private func determineBand(from channel: Int?) -> WiFiBand {
        guard let channel = channel else { return .unknown }

        // 6GHz: channels 1-233 (Wi-Fi 6E)
        if channel >= 1 && channel <= 233 {
            // Check if we can detect 6GHz specifically
            // For now, assume channels above 144 are 5GHz or 6GHz
            if channel > 144 {
                return .ghz5 // Could be 6GHz on newer systems
            }
        }

        // 5GHz: channels 36-144
        if channel >= 36 && channel <= 144 {
            return .ghz5
        }

        // 5GHz DFS channels: 50-144
        if channel >= 50 && channel <= 144 {
            return .ghz5
        }

        // 2.4GHz: channels 1-14
        if channel >= 1 && channel <= 14 {
            return .ghz24
        }

        return .unknown
    }

    private func determineSecurity(from interface: CWInterface) -> WiFiSecurity {
        let securityType = interface.security()

        // Map CWSecurity enum to our WiFiSecurity enum
        switch securityType {
        case .none:
            return .none
        case .wep:
            return .wep
        case .wpaPersonal:
            return .wpa
        case .wpaEnterprise:
            return .wpa
        case .wpa2Personal:
            return .wpa2
        case .wpa2Enterprise:
            return .wpa2Enterprise
        case .wpa3Personal:
            return .wpa3
        case .wpa3Enterprise:
            return .wpa3Enterprise
        case .wpa3Transition:
            return .wpa3
        default:
            return .unknown
        }
    }

    // MARK: - Channel Information

    /// Get human-readable channel info
    public func getChannelInfo() -> String? {
        guard let interface = getCurrentInterface(),
              let channel = interface.wlanChannel() else {
            return nil
        }

        let number = channel.channelNumber
        let width = channel.channelWidth
        let band = determineBand(from: number)

        let widthStr: String
        switch width {
        case CWChannelWidth.width20MHz: widthStr = "20MHz"
        case CWChannelWidth.width40MHz: widthStr = "40MHz"
        case CWChannelWidth.width80MHz: widthStr = "80MHz"
        case CWChannelWidth.width160MHz: widthStr = "160MHz"
        default: widthStr = "Unknown"
        }

        return "Ch \(number) • \(band.rawValue) • \(widthStr)"
    }

    /// Get supported channels for current interface
    public func getSupportedChannels() -> [Int] {
        guard let interface = getCurrentInterface(),
              let channels = interface.supportedWLANChannels() else {
            return []
        }

        return channels.compactMap { $0.channelNumber }
    }

    // MARK: - Network Scan

    /// Scan for available Wi-Fi networks
    public func scanForNetworks() -> [WiFiNetworkInfo] {
        guard let interface = getCurrentInterface() else {
            return []
        }

        do {
            let networks = try interface.scanForNetworks(withSSID: nil)
            return networks.compactMap { network in
                // CWNetwork has properties, not methods
                let ssid = network.ssid
                let bssid = network.bssid
                let rssi: Double? = network.rssi != nil ? Double(truncating: network.rssi!) : nil
                let channel = network.wlanChannel?.channelNumber

                return WiFiNetworkInfo(
                    ssid: ssid,
                    bssid: bssid,
                    signalStrength: rssi,
                    channel: channel,
                    band: determineBand(from: channel)
                )
            }
        } catch {
            logger.error("Failed to scan for networks: \(error.localizedDescription)")
            lastError = error
            return []
        }
    }
}

// MARK: - WiFi Network Info

/// Information about a discovered Wi-Fi network
public struct WiFiNetworkInfo: Sendable, Identifiable {
    public let id = UUID()
    public let ssid: String?
    public let bssid: String?
    public let signalStrength: Double?
    public let channel: Int?
    public let band: NetworkMetricsModels.WiFiBand?

    public var signalQuality: NetworkMetricsModels.SignalQuality {
        guard let signal = signalStrength else { return .unknown }
        switch signal {
        case -50...0: return .excellent
        case -60..<(-50): return .good
        case -70..<(-60): return .fair
        case -80..<(-70): return .poor
        default: return .terrible
        }
    }
}
