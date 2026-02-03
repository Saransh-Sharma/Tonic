# fn-5-v8r.12 Battery Details widget implementation

## Description
Implement Battery Details widget showing extended battery information beyond basic percentage. Includes health, cycle count, time remaining, charging state.

## Implementation

Create `BatteryDetailsWidgetView.swift`:
- Percentage with large display
- Time remaining estimate
- Charging state with animation
- Battery health percentage
- Cycle count (if available)
- Power source detail

## Acceptance
- [ ] All battery metrics display correctly
- [ ] Charging animation works
- [ ] Graceful fallback for unavailable data
- [ ] Tonic design tokens applied

## Done summary
Implemented Battery Details widget with comprehensive battery information.

## References
- Stats Master: `stats-master/Kit/Widgets/Battery.swift` (details mode)
- Tonic current: `Tonic/Tonic/MenuBarWidgets/BatteryWidgetView.swift`
