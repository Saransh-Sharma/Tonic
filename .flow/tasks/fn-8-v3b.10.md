# fn-8-v3b.10 Add electrical metrics to BatteryPopoverView

## Description
Add electrical measurement fields (amperage, voltage, power) and capacity breakdown to `BatteryPopoverView.swift`.

**Size:** M

**Files:**
- `Tonic/Tonic/MenuBarWidgets/Popovers/BatteryPopoverView.swift`
- `Tonic/Tonic/Services/WidgetDataManager.swift` (add battery data)
- `Tonic/Tonic/Models/WidgetConfiguration.swift` (add time format setting)

## Approach

1. Update `BatteryData` struct to add:
   ```swift
   public let amperage: Double?           // mA (negative = charging, positive = discharging)
   public let voltage: Double?             // V
   public let batteryPower: Double?       // W (calculated: voltage × amperage / 1000)
   public let designedCapacity: UInt64?   // mAh (design capacity)
   public let chargingCurrent: Double?    // Adapter current in mA
   public let chargingVoltage: Double?    // Adapter voltage in V
   ```

2. Add electrical metrics section to `BatteryPopoverView`:
   - Amperage (mA)
   - Voltage (V)
   - Power (W, calculated)

3. Add adapter section (if charging):
   - Adapter current
   - Adapter voltage

4. Add capacity breakdown:
   - Format: "current / maximum / designed mAh"

5. Add time format preference to `BatteryModuleSettings`:
   ```swift
   public enum TimeFormat: String, CaseIterable, Codable {
       case short = "short"    // "2h 30m"
       case long = "long"      // "2 hours 30 minutes"
   }
   public var timeFormat: TimeFormat = .short
   ```

## Key Context

Battery data comes from IOKit `IOPMPowerSource` API:
- `kIOPMPSCurrentCapacity` (current mAh)
- `kIOPMPSMaxCapacity` (max mAh)
- `kIOPMPSDesignCapacity` (design mAh)
- `kIOPMPSAmperage` (mA)
- `kIOPMPSCurrent` (mA, adapter)
- `kIOPMPSCapacity` (mWh, for voltage calculation)

Power calculation: `power = (voltage × amperage) / 1000` for watts.

Amperage is negative when charging, positive when discharging.
## Acceptance
- [ ] BatteryData has amperage, voltage, power, designedCapacity
- [ ] BatteryData has adapter current and voltage
- [ ] BatteryPopoverView shows electrical metrics section
- [ ] BatteryPopoverView shows adapter section (when charging)
- [ ] BatteryPopoverView shows capacity breakdown (current/max/designed)
- [ ] Power calculated correctly (W = V × A / 1000)
- [ ] Time format preference works (short/long)
- [ ] Desktop Macs (no battery) show empty state
## Done summary
TBD

## Evidence
- Commits:
- Tests:
- PRs:
