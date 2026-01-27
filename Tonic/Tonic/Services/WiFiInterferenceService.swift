//
//  WiFiInterferenceService.swift
//  Tonic
//
//  Service for scanning and analyzing Wi-Fi channel interference
//

import Foundation
import CoreWLAN
import SwiftUI
import os

// MARK: - Wi-Fi Interference Service

/// Service for scanning nearby Wi-Fi networks and analyzing channel interference
@MainActor
@Observable
public final class WiFiInterferenceService {
    public static let shared = WiFiInterferenceService()

    private let logger = Logger(subsystem: "com.tonic.app", category: "WiFiInterferenceService")
    private let wifiService = WiFiMetricsService.shared

    // Scan state
    public private(set) var isScanning = false
    public private(set) var lastScanResult: InterferenceScanResult?
    public private(set) var lastError: Error?
    public private(set) var lastScanTime: Date?

    private init() {}

    // MARK: - Public Methods

    /// Scan for Wi-Fi interference on nearby networks
    @discardableResult
    public func scanForInterference() async -> InterferenceScanResult? {
        guard !isScanning else {
            logger.debug("Scan already in progress")
            return lastScanResult
        }

        isScanning = true
        lastError = nil
        logger.info("Starting Wi-Fi interference scan")

        // Small delay to allow UI to update
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Get current network info
        guard let currentMetrics = wifiService.fetchMetrics(),
              let currentChannel = currentMetrics.channel else {
            isScanning = false
            logger.warning("Cannot scan: not connected to Wi-Fi")
            return nil
        }

        // Scan for nearby networks
        let networks = await wifiService.scanForNetworks()

        if networks.isEmpty {
            logger.warning("No nearby networks found during scan")
        }

        // Analyze interference
        let result = analyzeInterference(
            currentChannel: currentChannel,
            currentBand: currentMetrics.band ?? .unknown,
            nearbyNetworks: networks
        )

        lastScanResult = result
        lastScanTime = Date()
        isScanning = false

        logger.info("Scan complete: \(result.nearbyNetworks.count) networks, congestion: \(result.congestionLevel.rawValue)")

        return result
    }

    /// Get recommended channel based on last scan
    public func getRecommendedChannel() -> Int? {
        lastScanResult?.recommendedChannel
    }

    /// Check if a rescan is needed (older than 5 minutes)
    public var needsRescan: Bool {
        guard let lastTime = lastScanTime else { return true }
        return Date().timeIntervalSince(lastTime) > 300 // 5 minutes
    }

    // MARK: - Private Analysis Methods

    private func analyzeInterference(
        currentChannel: Int,
        currentBand: WiFiBand,
        nearbyNetworks: [WiFiNetworkInfo]
    ) -> InterferenceScanResult {

        // Determine which channels overlap with current channel
        let overlappingChannels = getOverlappingChannels(for: currentChannel, band: currentBand)

        // Categorize nearby networks
        var nearbyDetails: [NearbyNetworkDetail] = []
        var overlappingCount = 0
        var sameChannelCount = 0

        for network in nearbyNetworks {
            guard let networkChannel = network.channel else { continue }

            let isSameChannel = networkChannel == currentChannel
            let isOverlapping = overlappingChannels.contains(networkChannel)
            let interferenceLevel = calculateInterferenceLevel(
                networkSignal: network.signalStrength,
                isSameChannel: isSameChannel,
                isOverlapping: isOverlapping
            )

            if isSameChannel {
                sameChannelCount += 1
            } else if isOverlapping {
                overlappingCount += 1
            }

            nearbyDetails.append(NearbyNetworkDetail(
                ssid: network.ssid ?? "Hidden Network",
                bssid: network.bssid ?? "Unknown",
                channel: networkChannel,
                signalStrength: network.signalStrength ?? -100,
                band: network.band ?? .unknown,
                isSameChannel: isSameChannel,
                isOverlapping: isOverlapping,
                interferenceLevel: interferenceLevel
            ))
        }

        // Sort by signal strength (strongest first = most impact)
        nearbyDetails.sort { ($0.signalStrength) > ($1.signalStrength) }

        // Calculate overall congestion level
        let congestionLevel = calculateCongestionLevel(
            sameChannelCount: sameChannelCount,
            overlappingCount: overlappingCount,
            strongSignalCount: nearbyDetails.filter { $0.signalStrength > -70 }.count
        )

        // Find recommended channel
        let recommendedChannel = findBestChannel(
            currentChannel: currentChannel,
            currentBand: currentBand,
            nearbyNetworks: nearbyDetails
        )

        return InterferenceScanResult(
            currentChannel: currentChannel,
            currentBand: currentBand,
            nearbyNetworks: nearbyDetails,
            sameChannelCount: sameChannelCount,
            overlappingCount: overlappingCount,
            congestionLevel: congestionLevel,
            recommendedChannel: recommendedChannel,
            scanTime: Date()
        )
    }

    private func getOverlappingChannels(for channel: Int, band: WiFiBand) -> Set<Int> {
        switch band {
        case .ghz24:
            // 2.4GHz channels overlap significantly (only 1, 6, 11 don't overlap)
            // Each channel overlaps with +/- 4 channels
            let start = max(1, channel - 4)
            let end = min(14, channel + 4)
            return Set(start...end).subtracting([channel])

        case .ghz5, .ghz6:
            // 5GHz and 6GHz channels don't overlap (non-adjacent)
            // But adjacent channels might see some interference
            return Set([channel - 4, channel + 4].filter { $0 > 0 })

        default:
            return []
        }
    }

    private func calculateInterferenceLevel(
        networkSignal: Double?,
        isSameChannel: Bool,
        isOverlapping: Bool
    ) -> InterferenceLevel {
        guard let signal = networkSignal else { return .unknown }

        if isSameChannel {
            // Same channel interference is most severe
            if signal > -60 { return .high }
            if signal > -70 { return .medium }
            return .low
        } else if isOverlapping {
            // Overlapping channel interference is less severe
            if signal > -55 { return .medium }
            if signal > -65 { return .low }
            return .minimal
        } else {
            // Non-overlapping channels
            return .none
        }
    }

    private func calculateCongestionLevel(
        sameChannelCount: Int,
        overlappingCount: Int,
        strongSignalCount: Int
    ) -> CongestionLevel {
        // Weight factors
        let score = (sameChannelCount * 3) + (overlappingCount * 1) + (strongSignalCount * 2)

        switch score {
        case 0: return .clear
        case 1...3: return .low
        case 4...7: return .moderate
        case 8...12: return .high
        default: return .severe
        }
    }

    private func findBestChannel(
        currentChannel: Int,
        currentBand: WiFiBand,
        nearbyNetworks: [NearbyNetworkDetail]
    ) -> Int? {
        // Get available channels for this band
        let availableChannels: [Int]

        switch currentBand {
        case .ghz24:
            // Recommend only non-overlapping channels: 1, 6, 11
            availableChannels = [1, 6, 11]
        case .ghz5:
            // Common 5GHz channels
            availableChannels = [36, 40, 44, 48, 52, 56, 60, 64, 100, 104, 108, 112, 116, 149, 153, 157, 161, 165]
        case .ghz6:
            // 6GHz channels (Wi-Fi 6E)
            availableChannels = [1, 5, 9, 13, 17, 21, 25, 29, 33, 37, 41, 45, 49, 53, 57, 61, 65, 69, 73, 77]
        default:
            return nil
        }

        // Count interference on each channel
        var channelScores: [Int: Int] = [:]

        for channel in availableChannels {
            var score = 0
            let overlapping = getOverlappingChannels(for: channel, band: currentBand)

            for network in nearbyNetworks {
                if network.channel == channel {
                    // Same channel - high penalty
                    score += 10
                    if network.signalStrength > -60 { score += 5 }
                } else if overlapping.contains(network.channel) {
                    // Overlapping channel - medium penalty
                    score += 3
                    if network.signalStrength > -60 { score += 2 }
                }
            }

            channelScores[channel] = score
        }

        // Find channel with lowest score
        let bestChannel = channelScores.min { $0.value < $1.value }?.key

        // Only recommend if it's better than current
        if let best = bestChannel,
           let currentScore = channelScores[currentChannel],
           let bestScore = channelScores[best],
           bestScore < currentScore - 3 {
            return best
        }

        return nil
    }
}

// MARK: - Data Types

/// Result of an interference scan
public struct InterferenceScanResult: Sendable {
    public let currentChannel: Int
    public let currentBand: WiFiBand
    public let nearbyNetworks: [NearbyNetworkDetail]
    public let sameChannelCount: Int
    public let overlappingCount: Int
    public let congestionLevel: CongestionLevel
    public let recommendedChannel: Int?
    public let scanTime: Date

    public var hasRecommendation: Bool {
        recommendedChannel != nil
    }

    public var summaryText: String {
        var text = "\(nearbyNetworks.count) networks nearby"

        if sameChannelCount > 0 {
            text += ", \(sameChannelCount) on same channel"
        }

        if overlappingCount > 0 {
            text += ", \(overlappingCount) overlapping"
        }

        return text
    }

    public var recommendationText: String? {
        guard let channel = recommendedChannel else { return nil }
        return "Consider switching to channel \(channel) for less interference"
    }
}

/// Details about a nearby network
public struct NearbyNetworkDetail: Sendable, Identifiable {
    public let id = UUID()
    public let ssid: String
    public let bssid: String
    public let channel: Int
    public let signalStrength: Double
    public let band: WiFiBand
    public let isSameChannel: Bool
    public let isOverlapping: Bool
    public let interferenceLevel: InterferenceLevel
}

/// Level of interference from a network
public enum InterferenceLevel: String, Sendable {
    case none = "None"
    case minimal = "Minimal"
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case unknown = "Unknown"

    public var color: Color {
        switch self {
        case .none: return TonicColors.success
        case .minimal: return TonicColors.success.opacity(0.7)
        case .low: return .yellow
        case .medium: return TonicColors.warning
        case .high: return TonicColors.error
        case .unknown: return .gray
        }
    }
}

/// Overall channel congestion level
public enum CongestionLevel: String, Sendable {
    case clear = "Clear"
    case low = "Low"
    case moderate = "Moderate"
    case high = "High"
    case severe = "Severe"

    public var color: Color {
        switch self {
        case .clear: return TonicColors.success
        case .low: return TonicColors.success.opacity(0.8)
        case .moderate: return TonicColors.warning
        case .high: return TonicColors.error.opacity(0.8)
        case .severe: return TonicColors.error
        }
    }

    public var icon: String {
        switch self {
        case .clear: return "checkmark.circle.fill"
        case .low: return "wifi"
        case .moderate: return "wifi.exclamationmark"
        case .high: return "exclamationmark.triangle.fill"
        case .severe: return "xmark.circle.fill"
        }
    }
}
