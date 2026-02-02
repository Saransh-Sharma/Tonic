# fn-8-v3b.12 Update SensorsPopoverView with fan control integration

## Description
Update `SensorsPopoverView.swift` to integrate `FanControlView` and show fan controls.

**Size:** M

**Files:**
- `Tonic/Tonic/MenuBarWidgets/Popovers/SensorsPopoverView.swift` (~437 lines)

## Approach

1. Integrate `FanControlView` into sensors popover:
   - Add after temperature readings section
   - Hide if `SMCReader.shared.isAvailable == false`
   - Hide if `SensorsModuleSettings.showFanSpeeds == false`

2. Update sensors list layout:
   - Temperature readings (existing)
   - Fan control section (NEW)
   - Other sensors (voltage, power) as applicable

3. Add "Fan Control" section header with icon

4. Ensure proper state management:
   - Fan mode changes update SMC
   - SMC updates reflected in UI via `@Observable`
   - Handle SMC write failures gracefully

## Key Context

Current `SensorsPopoverView` shows temperature readings using `TempGauge` components.

Fan control should be a distinct section below temperature readings.

If SMC is unavailable (Intel Mac without SMC sensors, or permission denied), hide fan control section entirely with no empty state.

Reference Stats Master's Sensors popup at `stats-master/Modules/Sensors/popup.swift`.
## Acceptance
- [ ] FanControlView integrated into SensorsPopoverView
- [ ] Fan control section appears after temperature readings
- [ ] Fan controls hidden when SMC unavailable
- [ ] Fan controls respect showFanSpeeds setting
- [ ] Fan mode changes persist in settings
- [ ] UI updates reactively when fan speed changes
- [ ] Proper spacing and section header for fan control
## Done summary
TBD

## Evidence
- Commits:
- Tests:
- PRs:
