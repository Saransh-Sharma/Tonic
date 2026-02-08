//
//  ClockPopoverView.swift
//  Tonic
//
//  Stats Master-style Clock popover with multi-timezone display, date/time formatting,
//  and calendar button integration.
//  Task ID: fn-6-i4g.51
//

import SwiftUI

// MARK: - Clock Popover View

/// Complete Stats Master-style Clock popover with:
/// - Local time prominently displayed (digital or analog)
/// - Date display with day of week
/// - World clocks section (multiple timezones)
/// - Calendar app integration button
public struct ClockPopoverView: View {

    // MARK: - Properties

    @State private var preferences = ClockPreferences.shared
    @State private var refreshTrigger = 0
    @State private var timer: Timer?

    private let currentTime = Date()

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            SoftDivider()

            ScrollView {
                VStack(spacing: PopoverConstants.sectionSpacing) {
                    // Local time section - prominent display
                    localTimeSection

                    SoftDivider()

                    // Date display section
                    dateSection

                    if !enabledWorldClocks.isEmpty {
                        SoftDivider()

                        // World clocks section
                        worldClocksSection
                    }

                    SoftDivider()

                    // Calendar button
                    calendarButton
                }
                .padding(PopoverConstants.horizontalPadding)
                .padding(.vertical, PopoverConstants.verticalPadding)
            }
        }
        .frame(width: PopoverConstants.width, height: PopoverConstants.maxHeight)
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(PopoverConstants.cornerRadius)
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
        .id(refreshTrigger)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: PopoverConstants.iconTextGap) {
            // Icon
            Image(systemName: PopoverConstants.Icons.clock)
                .font(.title2)
                .foregroundColor(DesignTokens.Colors.accent)

            // Title
            Text(PopoverConstants.Names.clock)
                .font(PopoverConstants.headerTitleFont)
                .foregroundColor(DesignTokens.Colors.textPrimary)

            Spacer()

            // Time format indicator
            Text(formatIndicator)
                .font(.system(size: 11))
                .foregroundColor(DesignTokens.Colors.textSecondary)

            // Settings button
            HoverableButton(systemImage: PopoverConstants.Icons.settings) {
                SettingsDeepLinkNavigator.openModuleSettings(.clock)
            }
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

    // MARK: - Local Time Section

    private var localTimeSection: some View {
        VStack(spacing: PopoverConstants.compactSpacing) {
            // Time display (large, prominent)
            Text(currentTimeString)
                .font(PopoverConstants.clockTimeFont)
                .foregroundColor(DesignTokens.Colors.textPrimary)

            // Timezone label
            Text(localTimezoneName)
                .font(.caption)
                .foregroundColor(DesignTokens.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, PopoverConstants.verticalPadding)
    }

    private var currentTimeString: String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone.current

        switch preferences.timeFormat {
        case .auto:
            formatter.dateStyle = .none
            formatter.timeStyle = preferences.showSeconds ? .medium : .short
        case .twelveHour:
            let template = preferences.showSeconds ? "h:mm:ss a" : "h:mm a"
            formatter.setLocalizedDateFormatFromTemplate(template)
        case .twentyFourHour:
            let template = preferences.showSeconds ? "HH:mm:ss" : "HH:mm"
            formatter.setLocalizedDateFormatFromTemplate(template)
        }

        return formatter.string(from: currentTime)
    }

    private var localTimezoneName: String {
        let localName = TimeZone.current.localizedName(for: .generic, locale: .current) ?? "Local"
        let offset = utcOffsetString(for: TimeZone.current)
        return "\(localName) (\(offset))"
    }

    private func utcOffsetString(for timeZone: TimeZone) -> String {
        let seconds = timeZone.secondsFromGMT(for: currentTime)
        let hours = abs(seconds) / 3600
        let minutes = (abs(seconds) % 3600) / 60
        let sign = seconds >= 0 ? "+" : "-"
        return String(format: "UTC%s%02d:%02d", sign, hours, minutes)
    }

    // MARK: - Date Section

    private var dateSection: some View {
        VStack(spacing: PopoverConstants.compactSpacing) {
            // Full date string
            Text(fullDateString)
                .font(PopoverConstants.clockDateFont)
                .foregroundColor(DesignTokens.Colors.textPrimary)

            // Relative day string
            Text(relativeDateString)
                .font(.caption)
                .foregroundColor(DesignTokens.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, PopoverConstants.itemSpacing)
    }

    private var fullDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeZone = TimeZone.current
        return formatter.string(from: currentTime)
    }

    private var relativeDateString: String {
        let calendar = Calendar.current

        if calendar.isDateInToday(currentTime) {
            return "Today"
        } else if calendar.isDateInYesterday(currentTime) {
            return "Yesterday"
        } else if calendar.isDateInTomorrow(currentTime) {
            return "Tomorrow"
        } else {
            let daysUntil = calendar.dateComponents([.day], from: Date(), to: currentTime).day ?? 0
            let absDays = abs(daysUntil)
            if absDays == 1 {
                return daysUntil > 0 ? "Tomorrow" : "Yesterday"
            }
            return "\(absDays) days from now"
        }
    }

    // MARK: - World Clocks Section

    private var worldClocksSection: some View {
        VStack(alignment: .leading, spacing: PopoverConstants.itemSpacing) {
            PopoverSectionHeader(
                title: "World Clocks",
                icon: "globe"
            )

            VStack(spacing: PopoverConstants.rowSpacing) {
                ForEach(enabledWorldClocks) { entry in
                    worldClockRow(for: entry)
                }
            }
        }
    }

    private var enabledWorldClocks: [ClockEntry] {
        // Filter out "Local" entry since it's shown separately
        preferences.enabledEntries.filter { entry in
            entry.timezoneIdentifier != TimeZone.current.identifier
        }
    }

    private func worldClockRow(for entry: ClockEntry) -> some View {
        HStack(spacing: PopoverConstants.itemSpacing) {
            // Location info (left side)
            VStack(alignment: .leading, spacing: PopoverConstants.compactSpacing) {
                Text(entry.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DesignTokens.Colors.textPrimary)

                HStack(spacing: PopoverConstants.iconTextGap) {
                    // UTC offset
                    Text(utcOffsetString(for: entry.timezone))
                        .font(.system(size: 9))
                        .foregroundColor(DesignTokens.Colors.textSecondary)

                    // DST indicator
                    if entry.timezone.isDaylightSavingTime(for: currentTime) {
                        Text("DST")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor(TonicColors.warning)
                    }
                }
            }

            Spacer()

            // Time display (right side)
            VStack(alignment: .trailing, spacing: PopoverConstants.compactSpacing) {
                Text(timezoneTimeString(for: entry))
                    .font(PopoverConstants.clockWorldTimeFont)
                    .foregroundColor(DesignTokens.Colors.textPrimary)

                // Day difference indicator
                Text(dayDifferenceString(for: entry))
                    .font(.system(size: 9))
                    .foregroundColor(dayDifferenceColor(for: entry))
            }
        }
        .padding(.horizontal, PopoverConstants.horizontalPadding)
        .padding(.vertical, PopoverConstants.itemSpacing)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(PopoverConstants.innerCornerRadius)
    }

    private func timezoneTimeString(for entry: ClockEntry) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = entry.timezone

        switch preferences.timeFormat {
        case .auto:
            formatter.dateStyle = .none
            formatter.timeStyle = preferences.showSeconds ? .medium : .short
        case .twelveHour:
            let template = preferences.showSeconds ? "h:mm:ss a" : "h:mm a"
            formatter.setLocalizedDateFormatFromTemplate(template)
        case .twentyFourHour:
            let template = preferences.showSeconds ? "HH:mm:ss" : "HH:mm"
            formatter.setLocalizedDateFormatFromTemplate(template)
        }

        return formatter.string(from: currentTime)
    }

    private func dayDifferenceString(for entry: ClockEntry) -> String {
        let calendar = Calendar.current
        let localDate = calendar.startOfDay(for: Date())
        let entryDate = calendar.startOfDay(for: currentTime)

        if calendar.isDate(localDate, inSameDayAs: entryDate) {
            return "Same day"
        } else {
            let daysDifference = calendar.dateComponents([.day], from: localDate, to: entryDate).day ?? 0
            if daysDifference > 0 {
                return "+\(daysDifference)d"
            } else {
                return "\(daysDifference)d"
            }
        }
    }

    private func dayDifferenceColor(for entry: ClockEntry) -> Color {
        let calendar = Calendar.current
        let localDate = calendar.startOfDay(for: Date())
        let entryDate = calendar.startOfDay(for: currentTime)

        if calendar.isDate(localDate, inSameDayAs: entryDate) {
            return DesignTokens.Colors.textSecondary
        } else {
            let daysDifference = calendar.dateComponents([.day], from: localDate, to: entryDate).day ?? 0
            if daysDifference > 0 {
                return TonicColors.success  // Ahead
            } else {
                return TonicColors.warning  // Behind
            }
        }
    }

    // MARK: - Calendar Button

    private var calendarButton: some View {
        Button(action: openCalendar) {
            HStack(spacing: PopoverConstants.itemSpacing) {
                Image(systemName: "calendar")
                    .font(.system(size: 14))

                Text("Open Calendar")
                    .font(.subheadline)

                Spacer()

                Image(systemName: "arrow.up.right.square")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(PopoverConstants.innerCornerRadius)
        }
        .buttonStyle(.plain)
    }

    private func openCalendar() {
        NSWorkspace.shared.open(URL(string: "x-apple.calendar://")!)
    }

    // MARK: - Timer Management

    private func startTimer() {
        // Refresh every second to update time display
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

// MARK: - Preview

#Preview("Clock Popover") {
    ClockPopoverView()
        .frame(width: 280, height: 500)
}
