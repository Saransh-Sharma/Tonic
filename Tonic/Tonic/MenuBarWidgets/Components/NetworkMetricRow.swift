//
//  NetworkMetricRow.swift
//  Tonic
//
//  Row component for displaying a single network metric with label, value, and sparkline
//  Task ID: fn-2.8.8
//

import SwiftUI

// MARK: - Network Metric Row

/// Row component displaying a network metric with label, value, status color, and sparkline
public struct NetworkMetricRow: View {

    // MARK: - Properties

    let label: String
    let value: String
    let color: QualityColor
    let history: [Double]
    let tooltip: String?
    @State private var isExpanded = false

    // MARK: - Initialization

    public init(
        label: String,
        value: String,
        color: QualityColor = .unknown,
        history: [Double] = [],
        tooltip: String? = nil
    ) {
        self.label = label
        self.value = value
        self.color = color
        self.history = history
        self.tooltip = tooltip
    }

    // MARK: - Body

    public var body: some View {
        HStack(spacing: 12) {
            // Label
            Text(label)
                .font(DesignTokens.Typography.captionMedium)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .frame(width: 60, alignment: .leading)

            // Value with color indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(color.swiftUIColor)
                    .frame(width: 6, height: 6)

                Text(value)
                    .font(DesignTokens.Typography.monoMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(color.swiftUIColor)
            }
            .frame(width: 70, alignment: .leading)

            // Sparkline chart
            if !history.isEmpty {
                SparklineChart(
                    data: history,
                    color: color.swiftUIColor,
                    height: 28
                )
            } else {
                Spacer()
                    .frame(height: 28)
            }

            // Info button if tooltip available
            if let tooltip = tooltip {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(DesignTokens.Colors.backgroundSecondary.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.swiftUIColor.opacity(0.2), lineWidth: 1)
        )
        .overlay(alignment: .top) {
            if isExpanded, let tooltip = tooltip {
                TooltipPopover(text: tooltip, color: color)
                    .offset(y: 4)
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .opacity
                    ))
                    .zIndex(1)
            }
        }
        .onTapGesture {
            if tooltip != nil {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            }
        }
    }
}

// MARK: - Convenience Initializers

extension NetworkMetricRow {
    /// Create a row for ping metric
    public static func ping(
        _ value: TimeInterval?,
        history: [Double] = [],
        tooltip: Bool = true
    ) -> NetworkMetricRow {
        let displayValue: String
        let color: QualityColor

        if let ms = value {
            displayValue = String(format: "%.0f ms", ms * 1000)
            switch ms * 1000 {
            case 0..<30: color = .green
            case 30..<60: color = .green
            case 60..<100: color = .yellow
            default: color = .red
            }
        } else {
            displayValue = "--"
            color = .gray
        }

        return NetworkMetricRow(
            label: "Ping",
            value: displayValue,
            color: color,
            history: history,
            tooltip: tooltip ? pingTooltip(value) : nil
        )
    }

    /// Create a row for jitter metric
    public static func jitter(
        _ value: TimeInterval?,
        history: [Double] = [],
        tooltip: Bool = true
    ) -> NetworkMetricRow {
        let displayValue: String
        let color: QualityColor

        if let ms = value {
            displayValue = String(format: "%.1f ms", ms * 1000)
            switch ms * 1000 {
            case 0..<20: color = .green
            case 20..<50: color = .yellow
            default: color = .red
            }
        } else {
            displayValue = "--"
            color = .gray
        }

        return NetworkMetricRow(
            label: "Jitter",
            value: displayValue,
            color: color,
            history: history,
            tooltip: tooltip ? jitterTooltip(value) : nil
        )
    }

    /// Create a row for packet loss metric
    public static func packetLoss(
        _ value: Double?,
        history: [Double] = [],
        tooltip: Bool = true
    ) -> NetworkMetricRow {
        let displayValue: String
        let color: QualityColor

        if let loss = value {
            displayValue = String(format: "%.0f%%", loss)
            switch loss {
            case 0..<2: color = .green
            case 2..<5: color = .yellow
            default: color = .red
            }
        } else {
            displayValue = "--"
            color = .gray
        }

        return NetworkMetricRow(
            label: "Loss",
            value: displayValue,
            color: color,
            history: history,
            tooltip: tooltip ? lossTooltip(value) : nil
        )
    }

    /// Create a row for link rate metric
    public static func linkRate(
        _ value: Double?,
        history: [Double] = [],
        tooltip: Bool = true
    ) -> NetworkMetricRow {
        let displayValue: String
        let color: QualityColor

        if let rate = value {
            displayValue = String(format: "%.0f Mbps", rate)
            switch rate {
            case 400...: color = .green
            case 150..<400: color = .yellow
            default: color = .red
            }
        } else {
            displayValue = "--"
            color = .gray
        }

        return NetworkMetricRow(
            label: "Link Rate",
            value: displayValue,
            color: color,
            history: history,
            tooltip: tooltip ? linkRateTooltip(value) : nil
        )
    }

    /// Create a row for signal strength metric
    public static func signalStrength(
        _ value: Double?,
        history: [Double] = [],
        tooltip: Bool = true
    ) -> NetworkMetricRow {
        let displayValue: String
        let color: QualityColor

        if let signal = value {
            displayValue = String(format: "%.0f dBm", signal)
            switch signal {
            case -50...0: color = .green
            case -60..<(-50): color = .green
            case -70..<(-60): color = .yellow
            case -80..<(-70): color = .red
            default: color = .red
            }
        } else {
            displayValue = "--"
            color = .gray
        }

        return NetworkMetricRow(
            label: "Signal",
            value: displayValue,
            color: color,
            history: history,
            tooltip: tooltip ? signalTooltip(value) : nil
        )
    }

    /// Create a row for noise metric
    public static func noise(
        _ value: Double?,
        history: [Double] = [],
        tooltip: Bool = true
    ) -> NetworkMetricRow {
        let displayValue: String
        let color: QualityColor

        if let noise = value {
            displayValue = String(format: "%.0f dBm", noise)
            // Lower noise is better
            switch noise {
            case ...(-90): color = .green
            case (-90)...(-85): color = .yellow
            default: color = .red
            }
        } else {
            displayValue = "--"
            color = .gray
        }

        return NetworkMetricRow(
            label: "Noise",
            value: displayValue,
            color: color,
            history: history,
            tooltip: tooltip ? noiseTooltip(value) : nil
        )
    }

    /// Create a row for DNS lookup metric
    public static func dnsLookup(
        _ value: TimeInterval?,
        history: [Double] = [],
        tooltip: Bool = true
    ) -> NetworkMetricRow {
        let displayValue: String
        let color: QualityColor

        if let ms = value {
            displayValue = String(format: "%.0f ms", ms * 1000)
            switch ms * 1000 {
            case 0..<30: color = .green
            case 30..<60: color = .yellow
            default: color = .red
            }
        } else {
            displayValue = "--"
            color = .gray
        }

        return NetworkMetricRow(
            label: "Lookup",
            value: displayValue,
            color: color,
            history: history,
            tooltip: tooltip ? dnsLookupTooltip(value) : nil
        )
    }

    // MARK: - Tooltip Generators

    private static func pingTooltip(_ value: TimeInterval?) -> String? {
        guard let ms = value else { return "Ping not available" }
        let pingMs = ms * 1000
        switch pingMs {
        case 0..<20:
            return "Excellent: \(Int(pingMs))ms — Perfect for gaming and video calls."
        case 20..<50:
            return "Good: \(Int(pingMs))ms — Great for most activities."
        case 50..<100:
            return "Fair: \(Int(pingMs))ms — May notice lag in gaming."
        default:
            return "Poor: \(Int(pingMs))ms — High latency affecting performance."
        }
    }

    private static func jitterTooltip(_ value: TimeInterval?) -> String? {
        guard let ms = value else { return "Jitter not available" }
        let jitterMs = ms * 1000
        switch jitterMs {
        case 0..<10:
            return "Excellent: \(String(format: "%.1f", jitterMs))ms — Very stable connection."
        case 10..<30:
            return "Good: \(String(format: "%.1f", jitterMs))ms — Minor variations."
        case 30..<50:
            return "Fair: \(String(format: "%.1f", jitterMs))ms — Noticeable inconsistencies."
        default:
            return "Poor: \(String(format: "%.1f", jitterMs))ms — Unstable connection affecting calls."
        }
    }

    private static func lossTooltip(_ value: Double?) -> String? {
        guard let loss = value else { return "Packet loss not available" }
        switch loss {
        case 0..<1:
            return "Excellent: \(String(format: "%.1f", loss))% — Virtually no lost packets."
        case 1..<2:
            return "Good: \(String(format: "%.1f", loss))% — Minimal packet loss."
        case 2..<5:
            return "Fair: \(String(format: "%.1f", loss))% — Some data being retransmitted."
        default:
            return "Poor: \(String(format: "%.1f", loss))% — Significant data loss affecting connection."
        }
    }

    private static func linkRateTooltip(_ value: Double?) -> String? {
        guard let rate = value else { return "Link rate not available" }
        switch rate {
        case 800...:
            return "Excellent: \(Int(rate)) Mbps — Maximum Wi-Fi 6/6E speed."
        case 400..<800:
            return "Good: \(Int(rate)) Mbps — Good for 4K streaming and downloads."
        case 150..<400:
            return "Fair: \(Int(rate)) Mbps — Adequate for HD streaming."
        default:
            return "Poor: \(Int(rate)) Mbps — May limit streaming quality."
        }
    }

    private static func signalTooltip(_ value: Double?) -> String? {
        guard let signal = value else { return "Signal not available" }
        switch signal {
        case -50...0:
            return "Excellent: \(Int(signal)) dBm — Maximum signal strength."
        case -60..<(-50):
            return "Good: \(Int(signal)) dBm — Reliable for all activities."
        case -70..<(-60):
            return "Fair: \(Int(signal)) dBm — Functional but may slow down."
        case -80..<(-70):
            return "Poor: \(Int(signal)) dBm — Weak signal, move closer to router."
        default:
            return "Terrible: \(Int(signal)) dBm — Connection very unstable."
        }
    }

    private static func noiseTooltip(_ value: Double?) -> String? {
        guard let noise = value else { return "Noise not available" }
        switch noise {
        case ...(-90):
            return "Excellent: \(Int(noise)) dBm — Very low interference."
        case (-90)...(-85):
            return "Good: \(Int(noise)) dBm — Acceptable noise level."
        case (-85)...(-80):
            return "Fair: \(Int(noise)) dBm — Moderate interference."
        default:
            return "Poor: \(Int(noise)) dBm — High interference affecting connection."
        }
    }

    private static func dnsLookupTooltip(_ value: TimeInterval?) -> String? {
        guard let ms = value else { return "DNS lookup not available" }
        let lookupMs = ms * 1000
        switch lookupMs {
        case 0..<30:
            return "Excellent: \(Int(lookupMs))ms — Very fast DNS resolution."
        case 30..<60:
            return "Good: \(Int(lookupMs))ms — Normal DNS response time."
        case 60..<150:
            return "Fair: \(Int(lookupMs))ms — Slow DNS, consider changing servers."
        default:
            return "Poor: \(Int(lookupMs))ms — Very slow DNS, affecting page loads."
        }
    }
}

// MARK: - Preview

#Preview("Network Metric Rows") {
    VStack(spacing: 12) {
        NetworkMetricRow.ping(0.042, history: [40, 45, 38, 42, 50, 44, 48, 42])

        NetworkMetricRow.jitter(0.031, history: [25, 30, 28, 35, 32, 29, 31, 30])

        NetworkMetricRow.packetLoss(0.0, history: [0, 0, 0, 1, 0, 0, 0, 0])

        NetworkMetricRow.linkRate(866, history: [800, 850, 820, 866, 860, 855, 870, 866])

        NetworkMetricRow.signalStrength(-61, history: [-60, -59, -62, -60, -61, -63, -61, -60])

        NetworkMetricRow.noise(-90, history: [-90, -89, -91, -90, -90, -89, -90, -90])

        NetworkMetricRow.dnsLookup(0.012, history: [10, 15, 12, 10, 14, 11, 12, 12])
    }
    .padding()
    .frame(width: 320)
    .background(Color.black)
}
