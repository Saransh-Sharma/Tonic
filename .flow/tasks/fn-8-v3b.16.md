# fn-8-v3b.16 Create PopupSettingsView with global settings

## Description
Create `PopupSettingsView.swift` with global popover settings: keyboard shortcut, chart history duration, scaling mode, color pickers.

**Size:** M

**Files:**
- `Tonic/Tonic/MenuBarWidgets/Settings/PopupSettingsView.swift` (NEW)
- `Tonic/Tonic/Models/WidgetConfiguration.swift` (add popup settings)

## Approach

Create popup settings with:

1. **Global keyboard shortcut:** Recorder for opening widget popover
2. **Chart history duration:** Slider (60-300 seconds, default 180)
3. **Scaling mode:** Segmented control (None / Auto / Fixed)
4. **Fixed scale value:** Slider when scaling mode is Fixed
5. **Per-metric color pickers:** List of metrics with ColorPicker

Add to `WidgetConfiguration`:
```swift
public struct PopupSettings: Codable, Sendable, Equatable {
    public var keyboardShortcut: String?
    public var chartHistoryDuration: Int  // seconds
    public var scalingMode: ScalingMode
    public var fixedScaleValue: Double
    public var metricColors: [String: Color]  // metric name -> color
}

public enum ScalingMode: String, CaseIterable, Codable {
    case none = "none"
    case auto = "auto"
    case fixed = "fixed"
}
```

## Key Context

Stats Master allows per-metric color customization. Tonic has 32+ widget colors including auto-coloring based on utilization.

Color picker implementation:
- Use SwiftUI `ColorPicker` with `.supportsOpacity(false)`
- Bind to popup settings dictionary

Keyboard shortcut:
- Use `NSEventRecorder` or custom hotkey recorder
- Global shortcut monitoring via `NSEvent.addGlobalMonitorForEvents`

Chart history duration controls how many seconds of data are kept (180 seconds = 180 samples at 1 Hz).
## Acceptance
- [ ] PopupSettingsView created with all settings
- [ ] Keyboard shortcut recorder works
- [ ] Chart history duration slider (60-300 seconds)
- [ ] Scaling mode selector (None/Auto/Fixed)
- [ ] Fixed scale value appears when mode is Fixed
- [ ] Per-metric color pickers show and update
- [ ] Settings persist in WidgetPreferences
- [ ] Changes apply immediately to all popovers
## Done summary
TBD

## Evidence
- Commits:
- Tests:
- PRs:
