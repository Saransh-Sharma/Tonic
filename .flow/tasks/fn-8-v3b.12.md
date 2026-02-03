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
- [x] FanControlView integrated into SensorsPopoverView
- [x] Fan control section appears after temperature readings
- [x] Fan controls hidden when SMC unavailable
- [x] Fan controls respect showFanSpeeds setting
- [x] Fan mode changes persist in settings
- [x] UI updates reactively when fan speed changes
- [x] Proper spacing and section header for fan control
- [ ] Actual SMC fan speed writes (deferred to fn-8-v3b.13 - privileged helper required)
- [ ] Helper availability XPC check (deferred to fn-8-v3b.13)
## Done summary
- Task completed
## Evidence
- Commits:
- Tests:
- PRs: