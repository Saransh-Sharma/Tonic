//
//  NetworkSectionCard.swift
//  Tonic
//
//  Card container component for network widget sections
//  Task ID: fn-2.8.9
//

import SwiftUI

// MARK: - Network Section Card

/// Card container with section title, optional status badge, and content
public struct NetworkSectionCard<Content: View>: View {

    // MARK: - Properties

    let title: String
    let subtitle: String?
    let status: QualityLevel?
    let action: (() -> Void)?
    let actionIcon: String?
    @ViewBuilder let content: () -> Content

    @State private var isHovered = false

    // MARK: - Initialization

    public init(
        title: String,
        subtitle: String? = nil,
        status: QualityLevel? = nil,
        action: (() -> Void)? = nil,
        actionIcon: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.status = status
        self.action = action
        self.actionIcon = actionIcon
        self.content = content
    }

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            header

            // Content
            VStack(spacing: 8) {
                content()
            }
        }
        .padding(12)
        .background(cardBackground)
        .overlay(cardBorder)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            // Title and subtitle
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(DesignTokens.Typography.captionEmphasized)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignTokens.Colors.textSecondary)

                    // Status badge
                    if let status = status {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(status.color.swiftUIColor)
                                .frame(width: 5, height: 5)
                        }
                    }
                }

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                }
            }

            Spacer()

            // Action button
            if let action = action {
                Button(action: action) {
                    Image(systemName: actionIcon ?? "chevron.right")
                        .font(.caption)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                        .padding(4)
                        .background(
                            Circle()
                                .fill(DesignTokens.Colors.backgroundSecondary)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Card Styling

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(DesignTokens.Colors.backgroundSecondary.opacity(0.6))
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(
                DesignTokens.Colors.separator.opacity(0.5),
                lineWidth: 1
            )
    }
}

// MARK: - Compact Connection Status (WhyFi-style)

/// Compact inline connection status display: [dot] Network Name [frequency badge]
public struct CompactConnectionStatus: View {
    let isConnected: Bool
    let networkName: String?
    let band: WiFiBand?
    let ipAddress: String?

    public init(
        isConnected: Bool,
        networkName: String? = nil,
        band: WiFiBand? = nil,
        ipAddress: String? = nil
    ) {
        self.isConnected = isConnected
        self.networkName = networkName
        self.band = band
        self.ipAddress = ipAddress
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Main row: dot + network name + frequency badge
            HStack(spacing: 8) {
                // Status indicator dot
                Circle()
                    .fill(isConnected ? TonicColors.success : TonicColors.error)
                    .frame(width: 8, height: 8)

                if isConnected {
                    // Network name
                    Text(networkName ?? "Connected")
                        .font(DesignTokens.Typography.bodyEmphasized)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignTokens.Colors.textPrimary)

                    // Frequency badge
                    if let band = band {
                        Text(band.rawValue)
                            .font(DesignTokens.Typography.caption)
                            .fontWeight(.medium)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(DesignTokens.Colors.backgroundSecondary.opacity(0.8))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(DesignTokens.Colors.separator.opacity(0.5), lineWidth: 1)
                            )
                    }
                } else {
                    Text("Disconnected")
                        .font(DesignTokens.Typography.bodyEmphasized)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }

                Spacer()
            }

            // Secondary row: IP address (if connected)
            if isConnected, let ip = ipAddress {
                Text(ip)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                    .padding(.leading, 16) // Align with network name
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

// MARK: - Connection Status Card (Legacy - kept for compatibility)

/// Specialized card for displaying connection status
public struct ConnectionStatusCard: View {
    let isConnected: Bool
    let networkName: String?
    let band: WiFiBand?
    let ipAddress: String?

    public init(
        isConnected: Bool,
        networkName: String? = nil,
        band: WiFiBand? = nil,
        ipAddress: String? = nil
    ) {
        self.isConnected = isConnected
        self.networkName = networkName
        self.band = band
        self.ipAddress = ipAddress
    }

    public var body: some View {
        HStack(spacing: 16) {
            // Status indicator
            ZStack {
                Circle()
                    .fill(isConnected ? TonicColors.success.opacity(0.2) : TonicColors.error.opacity(0.2))
                    .frame(width: 48, height: 48)

                Image(systemName: isConnected ? "checkmark" : "xmark")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(isConnected ? TonicColors.success : TonicColors.error)
            }

            // Connection info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(isConnected ? "Connected" : "Disconnected")
                        .font(DesignTokens.Typography.bodyEmphasized)
                        .fontWeight(.semibold)
                        .foregroundColor(isConnected ? DesignTokens.Colors.textPrimary : DesignTokens.Colors.textSecondary)

                    // Status dot
                    Circle()
                        .fill(isConnected ? TonicColors.success : TonicColors.error)
                        .frame(width: 6, height: 6)
                }

                if let name = networkName, isConnected {
                    HStack(spacing: 6) {
                        Text(name)
                            .font(DesignTokens.Typography.subhead)
                            .foregroundColor(DesignTokens.Colors.textSecondary)

                        if let band = band {
                            Text("•")
                                .foregroundColor(DesignTokens.Colors.textTertiary)

                            Text(band.rawValue)
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(DesignTokens.Colors.textTertiary)
                        }
                    }
                } else if !isConnected {
                    Text("Not connected to a network")
                        .font(DesignTokens.Typography.subhead)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                }
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(DesignTokens.Colors.backgroundSecondary.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    (isConnected ? TonicColors.success : TonicColors.error).opacity(0.3),
                    lineWidth: 1
                )
        )
    }
}

// MARK: - Preview

#Preview("Network Section Cards") {
    VStack(spacing: 12) {
        // New compact connection status (WhyFi-style)
        CompactConnectionStatus(
            isConnected: true,
            networkName: "Babadan Starlink",
            band: .ghz5,
            ipAddress: "192.168.1.42"
        )

        Divider()
            .background(DesignTokens.Colors.separator.opacity(0.3))

        // Legacy connection status card (for comparison)
        ConnectionStatusCard(
            isConnected: true,
            networkName: "Babadan Starlink",
            band: .ghz5,
            ipAddress: "192.168.1.42"
        )

        NetworkSectionCard(
            title: "Router",
            status: .fair
        ) {
            NetworkMetricRow.ping(0.003, history: [3, 4, 3, 5, 3, 4, 3, 3])
            NetworkMetricRow.jitter(0.031, history: [25, 30, 35, 28, 32, 29, 31, 30])
            NetworkMetricRow.packetLoss(3.0, history: [0, 2, 3, 1, 0, 2, 3, 3])
        }

        NetworkSectionCard(
            title: "Internet",
            subtitle: "Connected to 1.1.1.1",
            status: .good
        ) {
            NetworkMetricRow.ping(0.042, history: [40, 45, 38, 42, 50, 44, 48, 42])
            NetworkMetricRow.jitter(0.049, history: [45, 50, 48, 52, 49, 47, 50, 49])
            NetworkMetricRow.packetLoss(0.0, history: [0, 0, 0, 0, 0, 0, 0, 0])
        }
    }
    .padding()
    .frame(width: 360)
    .background(Color.black)
}
