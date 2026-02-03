//
//  InterferenceScanResultsView.swift
//  Tonic
//
//  View component for displaying Wi-Fi interference scan results
//

import SwiftUI

// MARK: - Interference Scan Results View

/// View displaying results of a Wi-Fi interference scan
public struct InterferenceScanResultsView: View {
    let result: InterferenceScanResult
    let onDismiss: () -> Void

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with dismiss
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: result.congestionLevel.icon)
                        .foregroundColor(result.congestionLevel.color)

                    Text("Channel \(result.currentChannel)")
                        .font(DesignTokens.Typography.bodyEmphasized)
                        .fontWeight(.semibold)
                }

                Spacer()

                // Congestion badge
                Text(result.congestionLevel.rawValue)
                    .font(DesignTokens.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundColor(result.congestionLevel.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(result.congestionLevel.color.opacity(0.15))
                    )

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                }
                .buttonStyle(.plain)
            }

            // Summary
            Text(result.summaryText)
                .font(DesignTokens.Typography.captionMedium)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            // Recommendation
            if let recommendation = result.recommendationText {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .font(.caption)
                        .foregroundColor(TonicColors.warning)

                    Text(recommendation)
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(TonicColors.warning.opacity(0.15))
                )
            }

            // Nearby networks list (top 5)
            if !result.nearbyNetworks.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Nearby Networks")
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(DesignTokens.Colors.textTertiary)

                    ForEach(result.nearbyNetworks.prefix(5)) { network in
                        NearbyNetworkRow(network: network, currentChannel: result.currentChannel)
                    }

                    if result.nearbyNetworks.count > 5 {
                        Text("+ \(result.nearbyNetworks.count - 5) more networks")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(DesignTokens.Colors.textTertiary)
                            .padding(.top, 4)
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(DesignTokens.Colors.backgroundSecondary.opacity(0.8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(result.congestionLevel.color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Nearby Network Row

struct NearbyNetworkRow: View {
    let network: NearbyNetworkDetail
    let currentChannel: Int

    var body: some View {
        HStack(spacing: 8) {
            // Interference indicator
            Circle()
                .fill(network.interferenceLevel.color)
                .frame(width: 6, height: 6)

            // Network name
            Text(network.ssid)
                .font(DesignTokens.Typography.captionMedium)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .lineLimit(1)

            Spacer()

            // Channel
            Text("Ch \(network.channel)")
                .font(DesignTokens.Typography.monoSmall)
                .foregroundColor(network.isSameChannel ? TonicColors.error : DesignTokens.Colors.textTertiary)

            // Signal strength
            Text("\(Int(network.signalStrength)) dBm")
                .font(DesignTokens.Typography.monoSmall)
                .foregroundColor(signalColor)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(network.isSameChannel ? TonicColors.error.opacity(0.1) : Color.clear)
        )
    }

    private var signalColor: Color {
        switch network.signalStrength {
        case -50...0: return TonicColors.success
        case -60..<(-50): return TonicColors.success.opacity(0.8)
        case -70..<(-60): return TonicColors.warning
        default: return DesignTokens.Colors.textTertiary
        }
    }
}

// MARK: - Compact Interference Indicator

/// Small inline indicator showing interference status
public struct InterferenceIndicator: View {
    let congestionLevel: CongestionLevel

    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: congestionLevel.icon)
                .font(.caption2)

            Text(congestionLevel.rawValue)
                .font(DesignTokens.Typography.captionSmall)
        }
        .foregroundColor(congestionLevel.color)
    }
}

// MARK: - Preview

#Preview("Interference Scan Results") {
    VStack(spacing: 16) {
        InterferenceScanResultsView(
            result: InterferenceScanResult(
                currentChannel: 6,
                currentBand: .ghz24,
                nearbyNetworks: [
                    NearbyNetworkDetail(
                        ssid: "Neighbor's WiFi",
                        bssid: "AA:BB:CC:DD:EE:FF",
                        channel: 6,
                        signalStrength: -55,
                        band: .ghz24,
                        isSameChannel: true,
                        isOverlapping: false,
                        interferenceLevel: .high
                    ),
                    NearbyNetworkDetail(
                        ssid: "NETGEAR-5G",
                        bssid: "11:22:33:44:55:66",
                        channel: 5,
                        signalStrength: -65,
                        band: .ghz24,
                        isSameChannel: false,
                        isOverlapping: true,
                        interferenceLevel: .medium
                    ),
                    NearbyNetworkDetail(
                        ssid: "xfinitywifi",
                        bssid: "77:88:99:AA:BB:CC",
                        channel: 11,
                        signalStrength: -78,
                        band: .ghz24,
                        isSameChannel: false,
                        isOverlapping: false,
                        interferenceLevel: .none
                    )
                ],
                sameChannelCount: 1,
                overlappingCount: 1,
                congestionLevel: .moderate,
                recommendedChannel: 11,
                scanTime: Date()
            ),
            onDismiss: { print("Dismiss") }
        )

        InterferenceIndicator(congestionLevel: .low)
        InterferenceIndicator(congestionLevel: .moderate)
        InterferenceIndicator(congestionLevel: .high)
    }
    .padding()
    .frame(width: 360)
    .background(Color.black)
}
