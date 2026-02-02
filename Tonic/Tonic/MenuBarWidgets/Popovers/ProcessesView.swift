//
//  ProcessesView.swift
//  Tonic
//
//  Reusable top processes component for widget popovers
//  Used in CPU, Memory, Disk, and Network popovers
//  Task ID: fn-6-i4g.46
//

import SwiftUI

// MARK: - Processes View

/// A reusable component for displaying top processes in widget popovers
///
/// Features:
/// - Configurable number of processes (0-15)
/// - Section header with title and process count
/// - Process list with name, progress bar, and percentage
/// - Customizable bar color
/// - Supports both ProcessUsage and AppResourceUsage data models
///
/// Usage Examples:
/// ```swift
/// // CPU Popover
/// ProcessesView(
///     processes: dataManager.topCPUApps,
///     title: "Top Processes",
///     maxCount: 5,
///     barColor: DesignTokens.Colors.accent
/// )
///
/// // Memory Popover
/// ProcessesView(
///     processes: dataManager.topMemoryApps,
///     title: "Top Memory Users",
///     maxCount: 8,
///     barColor: .purple
/// )
/// ```
public struct ProcessesView: View {

    // MARK: - Properties

    /// The processes to display (must conform to ProcessDisplayable)
    let processes: [any ProcessDisplayable]

    /// Section title (e.g., "Top Processes", "Top Memory Users")
    var title: String = "Top Processes"

    /// Maximum number of processes to display (0-15, 0 = hidden)
    var maxCount: Int = 5

    /// Color for the progress bars
    var barColor: Color = Color.accentColor

    /// Whether to show percentage values
    var showPercentage: Bool = true

    // MARK: - Computed Properties

    /// Returns the filtered and limited list of processes to display
    private var displayedProcesses: [any ProcessDisplayable] {
        guard maxCount > 0 else { return [] }
        return Array(processes.prefix(maxCount))
    }

    // MARK: - Body

    public var body: some View {
        if !displayedProcesses.isEmpty {
            VStack(alignment: .leading, spacing: PopoverConstants.itemSpacing) {
                // Section header
                sectionHeader

                // Process list
                VStack(spacing: PopoverConstants.compactSpacing) {
                    ForEach(displayedProcesses, id: \.processId) { process in
                        ProcessRow(
                            name: process.name,
                            icon: process.icon,
                            value: process.usageValue,
                            color: barColor,
                            showPercentage: showPercentage
                        )
                    }
                }
            }
        } else {
            // Empty state - show nothing (spec says handle gracefully)
            EmptyView()
        }
    }

    // MARK: - Section Header

    private var sectionHeader: some View {
        HStack {
            Text(title)
                .font(PopoverConstants.sectionTitleFont)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            Spacer()

            Text("\(displayedProcesses.count) processes")
                .font(.system(size: 9))
                .foregroundColor(DesignTokens.Colors.textTertiary)
        }
    }
}

// MARK: - Process Displayable Protocol

/// Protocol that allows both ProcessUsage and AppResourceUsage to work with ProcessesView
public protocol ProcessDisplayable {
    var processId: String { get }
    var name: String { get }
    var icon: NSImage? { get }
    var usageValue: Double { get }
}

// MARK: - ProcessUsage Conformance

extension ProcessUsage: ProcessDisplayable {
    public var processId: String {
        String(id)
    }

    public var usageValue: Double {
        cpuUsage ?? 0
    }
}

// MARK: - AppResourceUsage Conformance

extension AppResourceUsage: ProcessDisplayable {
    public var processId: String {
        id.uuidString
    }

    public var usageValue: Double {
        cpuUsage
    }
}

// MARK: - Convenience Initializers

extension ProcessesView {

    /// Creates a ProcessesView for AppResourceUsage (CPU apps)
    /// - Parameters:
    ///   - appProcesses: Array of AppResourceUsage from WidgetDataManager
    ///   - title: Section title
    ///   - maxCount: Maximum processes to show (0-15)
    ///   - barColor: Progress bar color
    ///   - showPercentage: Whether to show percentage text
    public init(
        appProcesses: [AppResourceUsage],
        title: String = "Top Processes",
        maxCount: Int = 5,
        barColor: Color = Color.accentColor,
        showPercentage: Bool = true
    ) {
        self.processes = appProcesses
        self.title = title
        self.maxCount = max(0, min(15, maxCount)) // Clamp to 0-15
        self.barColor = barColor
        self.showPercentage = showPercentage
    }

    /// Creates a ProcessesView for ProcessUsage (from readers)
    /// - Parameters:
    ///   - processes: Array of ProcessUsage from widget readers
    ///   - title: Section title
    ///   - maxCount: Maximum processes to show (0-15)
    ///   - barColor: Progress bar color
    ///   - showPercentage: Whether to show percentage text
    public init(
        processes: [ProcessUsage],
        title: String = "Top Processes",
        maxCount: Int = 5,
        barColor: Color = Color.accentColor,
        showPercentage: Bool = true
    ) {
        self.processes = processes
        self.title = title
        self.maxCount = max(0, min(15, maxCount)) // Clamp to 0-15
        self.barColor = barColor
        self.showPercentage = showPercentage
    }
}

// MARK: - Previews

#if DEBUG
#Preview("CPU Processes") {
    let sampleProcesses = [
        AppResourceUsage(
            name: "Safari",
            bundleIdentifier: "com.apple.Safari",
            icon: nil,
            cpuUsage: 45.2,
            memoryBytes: 1_500_000_000
        ),
        AppResourceUsage(
            name: "Xcode",
            bundleIdentifier: "com.apple.dt.Xcode",
            icon: nil,
            cpuUsage: 28.5,
            memoryBytes: 3_200_000_000
        ),
        AppResourceUsage(
            name: "Chrome",
            bundleIdentifier: "com.google.Chrome",
            icon: nil,
            cpuUsage: 18.3,
            memoryBytes: 2_100_000_000
        ),
        AppResourceUsage(
            name: "Spotify",
            bundleIdentifier: "com.spotify.client",
            icon: nil,
            cpuUsage: 8.1,
            memoryBytes: 800_000_000
        ),
        AppResourceUsage(
            name: "Finder",
            bundleIdentifier: "com.apple.finder",
            icon: nil,
            cpuUsage: 3.2,
            memoryBytes: 200_000_000
        )
    ]

    return ProcessesView(
        appProcesses: sampleProcesses,
        title: "Top Processes",
        maxCount: 5,
        barColor: .blue
    )
    .padding()
    .frame(width: 280)
    .background(DesignTokens.Colors.background)
}

#Preview("Memory Processes") {
    let sampleProcesses = [
        AppResourceUsage(
            name: "Xcode",
            bundleIdentifier: "com.apple.dt.Xcode",
            icon: nil,
            cpuUsage: 0,
            memoryBytes: 4_500_000_000
        ),
        AppResourceUsage(
            name: "Chrome",
            bundleIdentifier: "com.google.Chrome",
            icon: nil,
            cpuUsage: 0,
            memoryBytes: 2_800_000_000
        ),
        AppResourceUsage(
            name: "Safari",
            bundleIdentifier: "com.apple.Safari",
            icon: nil,
            cpuUsage: 0,
            memoryBytes: 1_200_000_000
        )
    ]

    return ProcessesView(
        appProcesses: sampleProcesses,
        title: "Top Memory Users",
        maxCount: 3,
        barColor: .purple
    )
    .padding()
    .frame(width: 280)
    .background(DesignTokens.Colors.background)
}

#Preview("ProcessUsage Model") {
    let sampleProcesses = [
        ProcessUsage(id: 1234, name: "Safari", cpuUsage: 45),
        ProcessUsage(id: 5678, name: "Xcode", cpuUsage: 28),
        ProcessUsage(id: 9012, name: "Chrome", cpuUsage: 18),
        ProcessUsage(id: 3456, name: "Spotify", cpuUsage: 8),
        ProcessUsage(id: 7890, name: "Finder", cpuUsage: 3)
    ]

    return ProcessesView(
        processes: sampleProcesses,
        title: "Top Processes",
        maxCount: 5,
        barColor: .orange
    )
    .padding()
    .frame(width: 280)
    .background(DesignTokens.Colors.background)
}

#Preview("Empty State") {
    ProcessesView(
        appProcesses: [],
        title: "Top Processes",
        maxCount: 5,
        barColor: .blue
    )
    .padding()
    .frame(width: 280)
    .background(DesignTokens.Colors.background)
}

#Preview("Max Count 0 (Hidden)") {
    ProcessesView(
        appProcesses: [
            AppResourceUsage(name: "Test", icon: nil, cpuUsage: 50)
        ],
        title: "Should Be Hidden",
        maxCount: 0,
        barColor: .blue
    )
    .padding()
    .frame(width: 280)
    .background(DesignTokens.Colors.background)
}
#endif
