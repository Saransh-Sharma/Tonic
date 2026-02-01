//
//  CoreClusterBarView.swift
//  Tonic
//
//  E/P core grouped bar component for CPU popover
//  Visually groups efficiency and performance cores with different colors and labels
//  Task ID: fn-6-i4g.31
//

import SwiftUI

// MARK: - Core Cluster Bar View

/// Display per-core usage with E/P core grouping and color-coding
///
/// Ideal for: CPU popover showing efficiency vs performance core usage
///
/// Example:
/// ```swift
/// CoreClusterBarView(
///     eCores: [(0, 25), (1, 30), (2, 28), (3, 35)],
///     pCores: [(0, 72), (1, 81), (2, 68), (3, 75)],
///     barHeight: 8,
///     barSpacing: 4,
///     showLabels: true
/// )
/// ```
public struct CoreClusterBarView: View {
    // MARK: - Properties

    /// Efficiency core values as (index, usage) tuples
    public let eCores: [(index: Int, usage: Double)]

    /// Performance core values as (index, usage) tuples
    public let pCores: [(index: Int, usage: Double)]

    /// Height of each bar (default: 8)
    public var barHeight: CGFloat = 8

    /// Space between bars (default: 4)
    public var barSpacing: CGFloat = 4

    /// Show E/P core type labels (default: true)
    public var showLabels: Bool = true

    // MARK: - Computed Properties

    /// E-cores color - cool blue for efficiency
    public var eCoreColor: Color {
        Color(red: 0.37, green: 0.62, blue: 1.0)
    }

    /// P-cores color - warm orange for performance
    public var pCoreColor: Color {
        Color(red: 1.0, green: 0.62, blue: 0.04)
    }

    // MARK: - Initializer

    /// Initialize a core cluster bar view
    /// - Parameters:
    ///   - eCores: Array of (index, usage) tuples for efficiency cores
    ///   - pCores: Array of (index, usage) tuples for performance cores
    ///   - barHeight: Height of each bar (default: 8)
    ///   - barSpacing: Vertical space between bars (default: 4)
    ///   - showLabels: Whether to show E/P core type labels (default: true)
    public init(
        eCores: [(index: Int, usage: Double)],
        pCores: [(index: Int, usage: Double)],
        barHeight: CGFloat = 8,
        barSpacing: CGFloat = 4,
        showLabels: Bool = true
    ) {
        self.eCores = eCores
        self.pCores = pCores
        self.barHeight = barHeight
        self.barSpacing = barSpacing
        self.showLabels = showLabels
    }

    /// Convenience initializer with plain arrays
    /// - Parameters:
    ///   - eCoreUsage: Array of usage values for efficiency cores (indexed from 0)
    ///   - pCoreUsage: Array of usage values for performance cores (indexed from 0)
    ///   - barHeight: Height of each bar (default: 8)
    ///   - barSpacing: Vertical space between bars (default: 4)
    ///   - showLabels: Whether to show E/P core type labels (default: true)
    public init(
        eCoreUsage: [Double],
        pCoreUsage: [Double],
        barHeight: CGFloat = 8,
        barSpacing: CGFloat = 4,
        showLabels: Bool = true
    ) {
        self.eCores = eCoreUsage.enumerated().map { ($0, $1) }
        self.pCores = pCoreUsage.enumerated().map { ($0, $1) }
        self.barHeight = barHeight
        self.barSpacing = barSpacing
        self.showLabels = showLabels
    }

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Efficiency cores section
            if !eCores.isEmpty {
                if showLabels {
                    coreTypeHeader("Efficiency", coreCount: eCores.count, color: eCoreColor)
                }
                coreBarGroup(eCores, color: eCoreColor)
            }

            // Performance cores section
            if !pCores.isEmpty {
                if showLabels {
                    coreTypeHeader("Performance", coreCount: pCores.count, color: pCoreColor)
                }
                coreBarGroup(pCores, color: pCoreColor)
            }

            // Empty state for Intel Macs without E/P split
            if eCores.isEmpty && pCores.isEmpty {
                Text("No core data available")
                    .font(.system(size: 10))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
        }
    }

    // MARK: - View Components

    /// Header for a core type group
    @ViewBuilder
    private func coreTypeHeader(_ typeName: String, coreCount: Int, color: Color) -> some View {
        HStack {
            Text(typeName)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(color)
            Spacer()
            Text("\(coreCount) \(coreCount == 1 ? "core" : "cores")")
                .font(.system(size: 9))
                .foregroundColor(DesignTokens.Colors.textSecondary)
        }
    }

    /// Group of core bars for a core type
    @ViewBuilder
    private func coreBarGroup(_ cores: [(Int, Double)], color: Color) -> some View {
        VStack(alignment: .leading, spacing: barSpacing) {
            ForEach(cores, id: \.0) { core in
                coreBar(usage: core.1, color: color, label: coreLabel(for: core.0))
            }
        }
    }

    /// Generate a core label string
    private func coreLabel(for index: Int) -> String {
        return "Core \(index)"
    }

    /// Individual core bar with label, progress bar, and percentage
    private func coreBar(usage: Double, color: Color, label: String) -> some View {
        HStack(spacing: 8) {
            // Core label
            Text(label)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .frame(width: 50, alignment: .leading)

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.15))

                    // Fill bar
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: geometry.size.width * min(usage / 100, 1.0))
                        .animation(.easeInOut(duration: 0.2), value: usage)
                }
            }
            .frame(height: barHeight)

            // Percentage text
            Text("\(Int(usage))%")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .frame(width: 30, alignment: .trailing)
        }
    }
}

// MARK: - Convenience Initializers

extension CoreClusterBarView {
    /// Initialize from CPU data with flat arrays
    /// - Parameters:
    ///   - eCoreUsage: Optional array of efficiency core usage values
    ///   - pCoreUsage: Optional array of performance core usage values
    ///   - barHeight: Height of each bar (default: 8)
    ///   - barSpacing: Vertical space between bars (default: 4)
    ///   - showLabels: Whether to show E/P core type labels (default: true)
    public static func fromCPUData(
        eCoreUsage: [Double]?,
        pCoreUsage: [Double]?,
        barHeight: CGFloat = 8,
        barSpacing: CGFloat = 4,
        showLabels: Bool = true
    ) -> CoreClusterBarView {
        CoreClusterBarView(
            eCoreUsage: eCoreUsage ?? [],
            pCoreUsage: pCoreUsage ?? [],
            barHeight: barHeight,
            barSpacing: barSpacing,
            showLabels: showLabels
        )
    }
}

// MARK: - Preview

#Preview("Core Cluster Bar - Apple Silicon") {
    VStack(alignment: .leading, spacing: 24) {
        // M1/M2 style: 4 E-cores, 4 P-cores
        CoreClusterBarView(
            eCores: [(0, 25), (1, 30), (2, 28), (3, 35)],
            pCores: [(0, 72), (1, 81), (2, 68), (3, 75)],
            showLabels: true
        )
        .padding()
        .background(DesignTokens.Colors.backgroundSecondary)
        .cornerRadius(12)

        // M1 Pro style: 2 E-cores, 8 P-cores
        CoreClusterBarView(
            eCoreUsage: [15, 20],
            pCoreUsage: [45, 52, 48, 55, 60, 42, 38, 50],
            showLabels: true
        )
        .padding()
        .background(DesignTokens.Colors.backgroundSecondary)
        .cornerRadius(12)

        // High load
        CoreClusterBarView(
            eCoreUsage: [65, 70, 68, 72],
            pCoreUsage: [95, 88, 92, 85, 90, 87, 91, 89],
            showLabels: true
        )
        .padding()
        .background(DesignTokens.Colors.backgroundSecondary)
        .cornerRadius(12)
    }
    .padding()
}

#Preview("Core Cluster Bar - Intel") {
    VStack(alignment: .leading, spacing: 24) {
        // Intel - no E/P split, all treated as P-cores
        CoreClusterBarView(
            eCores: [],
            pCores: [
                (0, 45), (1, 52), (2, 48), (3, 55),
                (4, 42), (5, 38), (6, 50), (7, 44)
            ],
            showLabels: true
        )
        .padding()
        .background(DesignTokens.Colors.backgroundSecondary)
        .cornerRadius(12)

        // Empty state
        CoreClusterBarView(
            eCores: [],
            pCores: [],
            showLabels: true
        )
        .padding()
        .background(DesignTokens.Colors.backgroundSecondary)
        .cornerRadius(12)
    }
    .padding()
}

#Preview("Core Cluster Bar - Compact") {
    VStack(alignment: .leading, spacing: 16) {
        // Without labels
        CoreClusterBarView(
            eCoreUsage: [25, 30, 28, 35],
            pCoreUsage: [72, 81, 68, 75],
            showLabels: false
        )
        .padding()
        .background(DesignTokens.Colors.backgroundSecondary)
        .cornerRadius(12)

        // Thinner bars
        CoreClusterBarView(
            eCoreUsage: [25, 30, 28, 35],
            pCoreUsage: [72, 81, 68, 75],
            barHeight: 6,
            barSpacing: 2,
            showLabels: true
        )
        .padding()
        .background(DesignTokens.Colors.backgroundSecondary)
        .cornerRadius(12)
    }
    .padding()
}

#Preview("Core Cluster Bar - Dark Mode") {
    VStack(alignment: .leading, spacing: 16) {
        CoreClusterBarView(
            eCoreUsage: [25, 30, 28, 35],
            pCoreUsage: [72, 81, 68, 75],
            showLabels: true
        )
        .padding()
        .background(Color.black.opacity(0.8))
        .cornerRadius(12)
    }
    .padding()
    .preferredColorScheme(.dark)
}
