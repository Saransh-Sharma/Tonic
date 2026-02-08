//
//  ClockWidgetView.swift
//  Tonic
//
//  Clock widget views for multiple timezone display
//  Task ID: fn-6-i4g.16
//

import SwiftUI

// MARK: - Clock Formatter

/// Helper for formatting time in various timezones
public struct ClockFormatter {
    /// Format time for a specific timezone
    public static func formatTime(
        for entry: ClockEntry,
        format: ClockTimeFormat,
        showSeconds: Bool
    ) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = entry.timezone

        // Determine time format style
        switch format {
        case .auto:
            formatter.dateStyle = .none
            formatter.timeStyle = showSeconds ? .medium : .short
        case .twelveHour:
            let template = showSeconds ? "h:mm:ss a" : "h:mm a"
            formatter.setLocalizedDateFormatFromTemplate(template)
        case .twentyFourHour:
            let template = showSeconds ? "HH:mm:ss" : "HH:mm"
            formatter.setLocalizedDateFormatFromTemplate(template)
        }

        return formatter.string(from: Date())
    }

    /// Format date for a specific timezone
    public static func formatDate(for entry: ClockEntry) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = entry.timezone
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: Date())
    }

    /// Get UTC offset string for a timezone
    public static func utcOffsetString(for entry: ClockEntry) -> String {
        let seconds = entry.timezone.secondsFromGMT(for: Date())
        let hours = abs(seconds) / 3600
        let minutes = (abs(seconds) % 3600) / 60
        let sign = seconds >= 0 ? "+" : "-"
        return String(format: "%@%02d:%02d", sign, hours, minutes)
    }

    /// Check if DST is active for a timezone
    public static func isDST(for entry: ClockEntry) -> Bool {
        entry.timezone.isDaylightSavingTime(for: Date())
    }
}

// MARK: - Clock Stack View

/// Stack visualization showing multiple timezone clocks
struct ClockStackView: View {
    @State private var preferences = ClockPreferences.shared
    let configuration: WidgetConfiguration

    var body: some View {
        HStack(spacing: 6) {
            let enabledEntries = preferences.enabledEntries.prefix(3)

            if enabledEntries.isEmpty {
                // No enabled entries - show clock icon
                Image(systemName: "clock")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(enabledEntries.prefix(3)), id: \.id) { entry in
                    VStack(spacing: 2) {
                        // Location label (shortened)
                        Text(shortLabel(entry.name))
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)

                        // Time string
                        Text(ClockFormatter.formatTime(
                            for: entry,
                            format: preferences.timeFormat,
                            showSeconds: false
                        ))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.primary)
                    }
                }
            }
        }
        .padding(.horizontal, 4)
        .frame(height: 22)
    }

    private func shortLabel(_ name: String) -> String {
        // Shorten labels for compact display
        let lowercased = name.lowercased()
        if lowercased.contains("local") { return "Local" }
        if lowercased.contains("new york") || lowercased.contains("nyc") { return "NYC" }
        if lowercased.contains("los angeles") || lowercased.contains("la") { return "LA" }
        if lowercased.contains("london") { return "LDN" }
        if lowercased.contains("tokyo") { return "TYO" }
        if lowercased.contains("paris") { return "PAR" }
        if lowercased.contains("sydney") { return "SYD" }
        if lowercased.contains("utc") || lowercased.contains("gmt") { return "UTC" }
        return String(name.prefix(3)).uppercased()
    }
}

// MARK: - Clock Text View

/// Text visualization showing single timezone with custom format
struct ClockTextView: View {
    @State private var preferences = ClockPreferences.shared
    let configuration: WidgetConfiguration

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(configuration.accentColor.colorValue(for: .clock))

            if let firstEntry = preferences.enabledEntries.first {
                Text(ClockFormatter.formatTime(
                    for: firstEntry,
                    format: preferences.timeFormat,
                    showSeconds: preferences.showSeconds
                ))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.primary)

                if configuration.showLabel {
                    Text(firstEntry.name)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            } else {
                Text("--:--")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 4)
        .frame(height: 22)
    }
}

// MARK: - Clock Label View

/// Label visualization showing clock icon only
struct ClockLabelView: View {
    let configuration: WidgetConfiguration

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(configuration.accentColor.colorValue(for: .clock))

            if configuration.showLabel {
                Text("Clock")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 4)
        .frame(height: 22)
    }
}

// MARK: - Clock Detail View

/// Detailed popover view showing all configured timezones
public struct ClockDetailView: View {
    @State private var preferences = ClockPreferences.shared
    @State private var timer: Timer?
    @State private var refreshTrigger = 0

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            if preferences.entries.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(preferences.entries) { entry in
                            if entry.isEnabled {
                                clockRow(for: entry)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(width: 320, height: 280)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
        .id(refreshTrigger) // Force refresh
    }

    private var header: some View {
        HStack {
            Image(systemName: "clock")
                .font(.title2)
                .foregroundColor(TonicColors.accent)

            Text("World Clock")
                .font(.headline)

            Spacer()

            // Format indicator
            Text(formatIndicator)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var formatIndicator: String {
        switch preferences.timeFormat {
        case .auto: return "System"
        case .twelveHour: return "12h"
        case .twentyFourHour: return "24h"
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock")
                .font(.largeTitle)
                .foregroundColor(.secondary)

            Text("No timezones configured")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("Add timezones in settings")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func clockRow(for entry: ClockEntry) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.name)
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.semibold)

                HStack(spacing: 8) {
                    // UTC offset
                    Text(ClockFormatter.utcOffsetString(for: entry))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // DST indicator
                    if ClockFormatter.isDST(for: entry) {
                        Text("DST")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                // Time
                Text(ClockFormatter.formatTime(
                    for: entry,
                    format: preferences.timeFormat,
                    showSeconds: preferences.showSeconds
                ))
                .font(.system(size: 18, weight: .light, design: .rounded))
                .foregroundColor(.primary)

                // Date
                Text(ClockFormatter.formatDate(for: entry))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    private func startTimer() {
        // Refresh every second
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                refreshTrigger += 1
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Clock Status Item

/// Status item for the Clock widget
@MainActor
public final class ClockStatusItem: WidgetStatusItem {

    public override init(widgetType: WidgetType = .clock, configuration: WidgetConfiguration) {
        super.init(widgetType: widgetType, configuration: configuration)
    }

    public override func createCompactView() -> AnyView {
        _ = WidgetDataManager.shared

        // Use visualization-specific view
        switch configuration.visualizationType {
        case .stack:
            return AnyView(
                ClockStackView(configuration: configuration)
            )
        case .text:
            return AnyView(
                ClockTextView(configuration: configuration)
            )
        case .label:
            return AnyView(
                ClockLabelView(configuration: configuration)
            )
        default:
            return AnyView(
                ClockStackView(configuration: configuration)
            )
        }
    }

    public override func createDetailView() -> AnyView {
        return AnyView(ClockPopoverView())
    }
}

// MARK: - Preview

#Preview("Clock Detail") {
    ClockDetailView()
        .frame(width: 320, height: 280)
}
