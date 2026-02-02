# fn-8-v3b.11 Create FanControlView with sliders and modes

## Description
Create `FanControlView.swift` component with per-fan sliders, mode selection, and safety features (~450 lines).

**Size:** L (split into M)

**Files:**
- `Tonic/Tonic/MenuBarWidgets/Components/FanControlView.swift` (NEW, ~450 lines)
- `Tonic/Tonic/Models/WidgetConfiguration.swift` (add fan control settings)

## Approach

Create a comprehensive fan control UI with:

1. **Mode selector:** Segmented control (Auto / Manual / System)
2. **Per-fan controls:**
   - Fan name label
   - Min speed label (left)
   - Max speed label (right)
   - Slider for speed control
   - Current speed display
3. **Safety features:**
   - Warning dialog on first manual mode use
   - Thermal auto-switch (if temp exceeds threshold, revert to auto)
   - Auto-restore to auto on app quit

4. **Settings to add to `SensorsModuleSettings`:**
   ```swift
   public enum FanControlMode: String, CaseIterable, Codable {
       case auto = "auto"
       case manual = "manual"
       case system = "system"
   }
   public var fanControlMode: FanControlMode = .auto
   public var saveFanSpeed: Bool = false
   public var syncFanControl: Bool = true
   public var hasAcknowledgedFanWarning: Bool = false
   ```

Reference Stats Master's fan control implementation (~450 lines of UI).

## Key Context

SMC fan control requires privileged helper. Speed values typically 0-100 (percentage) or actual RPM (6000+ max).

Fan data comes from `SMCReader.shared.fans` array with:
- `fanId: Int`
- `name: String`
- `currentSpeed: Int`
- `minSpeed: Int`
- `maxSpeed: Int`

SMC writes require `TonicHelperTool` XPC connection (task 13).
## Acceptance
- [ ] FanControlView.swift created with mode selector
- [ ] Per-fan sliders show min/max labels and current speed
- [ ] Mode switcher: Auto / Manual / System
- [ ] Warning dialog appears on first manual mode use
- [ ] Fan speed changes update SMC in real-time
- [ ] Thermal limit triggers auto-switch to auto mode
- [ ] Fan settings persist in SensorsModuleSettings
- [ ] Fans sync when syncFanControl is enabled
- [ ] Component handles missing fan data gracefully
## Done summary
TBD

## Evidence
- Commits:
- Tests:
- PRs:
