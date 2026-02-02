# fn-8-v3b.5 Add missing CPU fields and enhance CPUPopoverView

## Description
Add missing CPU data fields (scheduler limit, speed limit, uptime) to `CPUPopoverView.swift` and `WidgetDataManager.swift` for Stats Master parity.

**Size:** M

**Files:**
- `Tonic/Tonic/MenuBarWidgets/Popovers/CPUPopoverView.swift` (~330 lines)
- `Tonic/Tonic/Services/WidgetDataManager.swift` (update CPUData struct)

## Approach

1. Update `CPUData` struct in WidgetDataManager (around line 91) to add:
   ```swift
   public let schedulerLimit: Double?
   public let speedLimit: Double?
   ```

2. Update CPU data collection (around line 900) to fetch:
   - Scheduler limit from sysctl `hw.cpufrequency_max` vs current
   - Speed limit from CPU power management
   - Uptime is already in `CPUData` at line 107

3. Add detail rows in `CPUPopoverView.swift` details section (after line 213):
   - Scheduler Limit (if available) - orange color
   - Speed Limit (if available) - red color
   - Uptime display (formatted as "X days, Y hours, Z minutes")

4. Standardize per-core colors across dashboard gauges and charts:
   - E-core: Light blue `Color(red: 0.4, green: 0.6, blue: 0.8)`
   - P-core: Dark blue `Color(red: 0.2, green: 0.4, blue: 0.8)`

## Key Context

The uptime field already exists in `CPUData` (line 107) but may not be displayed in the popover.

Uptime formatting helper:
```swift
func formatUptime(_ seconds: TimeInterval) -> String {
    let days = Int(seconds) / 86400
    let hours = Int(seconds) % 86400 / 3600
    let minutes = Int(seconds) % 3600 / 60
    if days > 0 { return "\(days)d \(hours)h \(minutes)m" }
    if hours > 0 { return "\(hours)h \(minutes)m" }
    return "\(minutes)m"
}
```

CPU frequency limit data comes from `sysctl hw.cpufrequency` for current and `hw.cpufrequency_max` for max.
## Acceptance
- [ ] CPUData struct has schedulerLimit and speedLimit properties
- [ ] CPU data collection fetches scheduler and speed limits
- [ ] CPUPopoverView displays Scheduler Limit (if available)
- [ ] CPUPopoverView displays Speed Limit (if available)
- [ ] CPUPopoverView displays formatted uptime
- [ ] Per-core colors match E-core/P-core consistently
- [ ] New fields use correct color coding (orange, red)
## Done summary
- Task completed
## Evidence
- Commits:
- Tests:
- PRs: