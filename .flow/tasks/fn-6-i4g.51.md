# fn-6-i4g.51 Clock Popover Implementation

## Description

Create Clock widget popover with multi-timezone display, date/time formatting options, and calendar button integration.

**REFERENCE**: Read `stats-master/Modules/Clock/popup.swift` first

Stats Master's Clock popup features:
- Multiple timezone clocks (up to 4)
- Local time prominently displayed
- Date display with day of week
- Calendar button (opens Calendar app)
- World clock grid layout
- Analog clock option (optional)

## New Files to Create

1. **Tonic/Tonic/MenuBarWidgets/Popovers/ClockPopoverView.swift**
2. **Tonic/Tonic/Components/AnalogClockView.swift** (optional)

## Data Model

```swift
// File: Tonic/Tonic/Models/ClockData.swift (ensure exists)

public struct ClockData: Sendable {
    public let localTime: Date
    public let timezones: [TimezoneEntry]
    public let showAnalog: Bool

    public struct TimezoneEntry: Identifiable, Sendable {
        public let id: UUID
        public let name: String
        public let location: String  // e.g., "New York", "London"
        public let timeZone: TimeZone
        public let offset: TimeInterval  // seconds from UTC
    }
}
```

## Implementation

```swift
// File: Tonic/Tonic/MenuBarWidgets/Popovers/ClockPopoverView.swift

import SwiftUI

struct ClockPopoverView: View {
    @ObservedObject private var dataManager = WidgetDataManager.shared
    @State private var showAnalog = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HeaderView(
                title: "Clock",
                icon: "clock.fill",
                isActivityMonitorMode: .constant(false),
                onSettingsTap: {
                    // Open clock settings
                }
            )

            ScrollView {
                VStack(spacing: 16) {
                    // Local time - prominent display
                    localTimeSection

                    Divider()

                    // Date display
                    dateSection

                    Divider()

                    // World clocks
                    worldClocksSection

                    Divider()

                    // Calendar button
                    calendarButton
                }
                .padding()
            }
        }
        .frame(width: 280, height: 400)
    }

    // MARK: - Local Time Section

    private var localTimeSection: some View {
        VStack(spacing: 8) {
            if showAnalog {
                AnalogClockView(date: dataManager.clockData.localTime, size: 120)
            } else {
                Text(currentTimeString)
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(DesignTokens.Colors.text)
            }

            Text(timeZoneName())
                .font(.system(size: 12))
                .foregroundColor(DesignTokens.Colors.textSecondary)
        }
    }

    private var currentTimeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: dataManager.clockData.localTime)
    }

    private func timeZoneName() -> String {
        TimeZone.current.abbreviation() ?? "Local"
    }

    // MARK: - Date Section

    private var dateSection: some View {
        VStack(spacing: 4) {
            Text(fullDateString)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(DesignTokens.Colors.text)

            Text(relativeDateString)
                .font(.system(size: 11))
                .foregroundColor(DesignTokens.Colors.textSecondary)
        }
    }

    private var fullDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeZone = TimeZone.current
        return formatter.string(from: dataManager.clockData.localTime)
    }

    private var relativeDateString: String {
        let calendar = Calendar.current
        let now = dataManager.clockData.localTime

        if calendar.isDateInToday(now) {
            return "Today"
        } else if calendar.isDateInTomorrow(now) {
            return "Tomorrow"
        } else {
            let daysUntil = calendar.dateComponents([.day], from: Date(), to: now).day ?? 0
            return "\(abs(daysUntil)) days from now"
        }
    }

    // MARK: - World Clocks Section

    private var worldClocksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("World Clocks")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(DesignTokens.Colors.textSecondary)

            ForEach(dataManager.clockData.timezones) { timezone in
                worldClockRow(timezone)
            }
        }
    }

    private func worldClockRow(_ timezone: ClockData.TimezoneEntry) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(timezone.location)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(DesignTokens.Colors.text)

                Text(offsetString(timezone.offset))
                    .font(.system(size: 9))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }

            Spacer()

            Text(timezoneTimeString(timezone))
                .font(.system(size: 14, weight: .light))
                .foregroundColor(DesignTokens.Colors.text)
        }
    }

    private func offsetString(_ offset: TimeInterval) -> String {
        let hours = Int(offset / 3600)
        let sign = hours >= 0 ? "+" : ""
        return "UTC\(sign)\(hours)"
    }

    private func timezoneTimeString(_ timezone: ClockData.TimezoneEntry) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.timeZone = timezone.timeZone
        return formatter.string(from: dataManager.clockData.localTime)
    }

    // MARK: - Calendar Button

    private var calendarButton: some View {
        Button(action: openCalendar) {
            HStack {
                Image(systemName: "calendar")
                    .font(.system(size: 14))

                Text("Open Calendar")
                    .font(.system(size: 12))

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10))
            }
            .foregroundColor(DesignTokens.Colors.accent)
        }
        .buttonStyle(.plain)
    }

    private func openCalendar() {
        // Open Calendar app
        NSWorkspace.shared.open(URL(string: "x-apple.calendar://")!)
    }
}
```

## Optional: Analog Clock Component

```swift
// File: Tonic/Tonic/Components/AnalogClockView.swift

import SwiftUI

struct AnalogClockView: View {
    let date: Date
    var size: CGFloat = 120

    var body: some View {
        ZStack {
            // Clock face
            Circle()
                .stroke(DesignTokens.Colors.textSecondary.opacity(0.3), lineWidth: 2)
                .frame(width: size, height: size)

            // Hour markers
            ForEach(0..<12) { i in
                Rectangle()
                    .fill(DesignTokens.Colors.textSecondary)
                    .frame(width: 2, height: 8)
                    .offset(y: -(size/2 - 12))
                    .rotationEffect(.degrees(Double(i) * 30))
            }

            // Hour hand
            Rectangle()
                .fill(DesignTokens.Colors.text)
                .frame(width: 4, height: size/3)
                .offset(y: -size/6)
                .rotationEffect(.degrees(hourAngle))

            // Minute hand
            Rectangle()
                .fill(DesignTokens.Colors.text)
                .frame(width: 2, height: size/2.5)
                .offset(y: -size/5)
                .rotationEffect(.degrees(minuteAngle))

            // Second hand (optional)
            Rectangle()
                .fill(Color.red)
                .frame(width: 1, height: size/2.2)
                .offset(y: -size/4.4)
                .rotationEffect(.degrees(secondAngle))

            // Center dot
            Circle()
                .fill(DesignTokens.Colors.accent)
                .frame(width: 6, height: 6)
        }
        .frame(width: size, height: size)
    }

    private var hourAngle: Double {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return Double(hour) * 30 + Double(minute) * 0.5 - 90
    }

    private var minuteAngle: Double {
        let calendar = Calendar.current
        let minute = calendar.component(.minute, from: date)
        let second = calendar.component(.second, from: date)
        return Double(minute) * 6 + Double(second) * 0.1 - 90
    }

    private var secondAngle: Double {
        let calendar = Calendar.current
        let second = calendar.component(.second, from: date)
        return Double(second) * 6 - 90
    }
}
```

## Acceptance

- [ ] Clock popover displays local time prominently
- [ ] Date shows full date with day of week
- [ ] World clocks section shows configured timezones
- [ ] Each world clock shows location, UTC offset, time
- [ ] Calendar button opens macOS Calendar app
- [ ] Analog clock displays correctly (if enabled)
- [ ] Clock updates every second
- [ ] Popover size: 280x400px
- [ ] Toggle for digital/analog display

## Done Summary

Created Clock popover with multi-timezone support. Features local time display, date with relative day, world clocks grid, and Calendar app integration. Optional analog clock face included.

## Evidence

- Commits:
- Tests:
- PRs:

## Reference Implementation

**Stats Master**: `stats-master/Modules/Clock/popup.swift`
- Full clock popup structure
- Timezone handling
- Analog clock drawing
