# fn-6-i4g.16 Clock Module Implementation

## Description
Implement the Clock module to display multiple timezone clocks in the menu bar. This is a simple module that doesn't require system APIs - just TimeZone and Date formatting.

**Size:** S
**Files:**
- `Tonic/Tonic/Services/WidgetReader/ClockReader.swift` (new)
- `Tonic/Tonic/Models/WidgetConfiguration.swift` (add `.clock` case)
- `Tonic/Tonic/MenuBarWidgets/ClockWidgetView.swift` (new)
- `Tonic/Tonic/Models/ClockConfiguration.swift` (new - timezone list)

## Approach

- Create `ClockReader` conforming to `WidgetReader` protocol - simply returns formatted time strings
- Add `.clock` case to `WidgetType` enum at `Models/WidgetConfiguration.swift:14-63`
- Store user's timezone preferences in new `ClockConfiguration` struct
- Compatible visualizations: `stack` (multiple timezones), `text` (single timezone)
- Update interval: 1 second for clock display

## Key Context

**Data structure from PRD**:
```swift
struct ClockEntry {
    id: UUID
    name: String                   // Display name (e.g., "Tokyo", "London")
    timezone: TimeZone
    format: String                 // Time format string (e.g., "HH:mm", "h:mm a")
    isEnabled: Bool
}
```

**Popover content**: List of configured timezones with current time, date, UTC offset, DST indicator.
## Acceptance
- [ ] `ClockReader` returns formatted time for configured timezones
- [ ] User can add/remove/reorder timezone entries in settings
- [ ] `stack` visualization shows multiple timezone clocks (2-row layout)
- [ ] `text` visualization shows single timezone with custom format
- [ ] Time format customizable (12/24 hour, with/without seconds)
- [ ] Popover shows full timezone list with date, UTC offset, DST status
- [ ] Widget updates every second when visible
- [ ] Default timezone list includes local time + 2-3 common zones
## Done summary
Implemented Clock Module for multiple timezone display in the menu bar. Added ClockConfiguration model with timezone entries, time format options (12/24 hour), and ClockPreferences for user settings. Created ClockWidgetView with stack/text/label visualizations and detail popover showing all timezones with UTC offset and DST indicators. Updated WidgetConfiguration, WidgetFactory, and related status items to support the new clock widget type.
## Evidence
- Commits: 3461429d44ca21d2e12f9a4e368dacdf1e330215
- Tests: xcodebuild -scheme Tonic -configuration Debug build - Clock files compiled successfully with no clock-specific errors
- PRs: