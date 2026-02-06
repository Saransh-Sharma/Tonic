//
//  TooltipPopover.swift
//  Tonic
//
//  Tooltip popover component for metric explanations
//  Task ID: fn-2.8.10
//

import SwiftUI

// MARK: - Tooltip Popover

/// Expandable tooltip showing metric explanation
public struct TooltipPopover: View {

    // MARK: - Properties

    let text: String
    let color: QualityColor

    @State private var isVisible = false

    // MARK: - Initialization

    public init(text: String, color: QualityColor = .gray) {
        self.text = text
        self.color = color
    }

    // MARK: - Body

    public var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Color indicator bar
            RoundedRectangle(cornerRadius: 2)
                .fill(color.swiftUIColor)
                .frame(width: 3)

            // Text content
            VStack(alignment: .leading, spacing: 4) {
                Text(text)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
            }

            Spacer()

            // Close button (handled by parent tap)
            Image(systemName: "xmark")
                .font(.caption2)
                .foregroundColor(DesignTokens.Colors.textTertiary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(DesignTokens.Colors.backgroundSecondary)
                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.swiftUIColor.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Compact Tooltip

/// Smaller inline tooltip variant
public struct CompactTooltip: View {
    let text: String
    let color: QualityColor
    @Binding var isExpanded: Bool

    public init(text: String, color: QualityColor = .gray, isExpanded: Binding<Bool>) {
        self.text = text
        self.color = color
        self._isExpanded = isExpanded
    }

    public var body: some View {
        if isExpanded {
            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill")
                    .font(.caption2)
                    .foregroundColor(color.swiftUIColor)

                Text(text)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textSecondary)

                Spacer()

                Button {
                    withAnimation {
                        isExpanded = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(color.swiftUIColor.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(color.swiftUIColor.opacity(0.2), lineWidth: 1)
            )
            .transition(.asymmetric(
                insertion: .scale(scale: 0.9).combined(with: .opacity),
                removal: .opacity
            ))
        }
    }
}

// MARK: - Info Button

/// Button that reveals a tooltip when tapped
public struct InfoButton: View {
    let tooltip: String
    let color: QualityColor
    @State private var showTooltip = false

    public init(tooltip: String, color: QualityColor = .gray) {
        self.tooltip = tooltip
        self.color = color
    }

    public var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showTooltip.toggle()
            }
        } label: {
            Image(systemName: "info.circle")
                .font(.caption)
                .foregroundColor(DesignTokens.Colors.textTertiary)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) {
            if showTooltip {
                TooltipPopover(text: tooltip, color: color)
                    .offset(y: -4)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.9).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
    }
}

// MARK: - Metric Label with Tooltip

/// Label with built-in tooltip button
public struct MetricLabelWithTooltip: View {
    let label: String
    let tooltip: String
    let color: QualityColor

    public init(label: String, tooltip: String, color: QualityColor = .gray) {
        self.label = label
        self.tooltip = tooltip
        self.color = color
    }

    public var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(DesignTokens.Typography.caption)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            Image(systemName: "info.circle")
                .font(.caption2)
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .help(tooltip) // macOS native tooltip
        }
    }
}

// MARK: - Preview

#Preview("Tooltip Components") {
    VStack(spacing: 24) {
        // Full tooltip popover
        VStack(alignment: .leading, spacing: 8) {
            Text("Full Tooltip Popover")
                .font(.caption)
                .foregroundColor(.secondary)
            TooltipPopover(
                text: "Between -60 and -75 dBm — functional but not ideal for high-bandwidth activities.",
                color: .yellow
            )
        }

        // Compact tooltip
        VStack(alignment: .leading, spacing: 8) {
            Text("Compact Tooltip")
                .font(.caption)
                .foregroundColor(.secondary)
            CompactTooltip(
                text: "Excellent signal strength for all activities.",
                color: .green,
                isExpanded: .constant(true)
            )
        }

        // Info button
        HStack {
            Text("Info Button Example")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            InfoButton(
                tooltip: "This explains what the metric means and what values are considered good.",
                color: .green
            )
        }

        // Metric label with tooltip
        MetricLabelWithTooltip(
            label: "Signal Strength",
            tooltip: "Lower is better. -50 dBm is excellent, -80 dBm is poor.",
            color: .yellow
        )
    }
    .padding()
    .frame(width: 320)
    .background(Color.black)
}
