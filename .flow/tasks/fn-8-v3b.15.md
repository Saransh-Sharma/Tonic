# fn-8-v3b.15 Implement ModuleSettings protocol and views

## Description
Implement `ModuleSettings` protocol and create per-module settings views for CPU, GPU, Memory, Disk, Network, Battery, Sensors, Bluetooth.

**Size:** M

**Files:**
- `Tonic/Tonic/Models/WidgetConfiguration.swift` (add protocol)
- `Tonic/Tonic/MenuBarWidgets/Settings/ModuleSettingsView.swift` (implement)
- Individual module settings views (create)

## Approach

1. Create `ModuleSettings` protocol:
   ```swift
   protocol ModuleSettings {
       var displayName: String { get }
       var icon: String { get }
       var settingsView: any View { get }
   }
   ```

2. Extend existing module settings structs to conform:
   - `CPUModuleSettings`
   - `GPUModuleSettings`
   - `MemoryModuleSettings`
   - `DiskModuleSettings`
   - `NetworkModuleSettings`
   - `BatteryModuleSettings`
   - `SensorsModuleSettings`
   - `BluetoothModuleSettings`

3. Create per-module settings views with:
   - Update interval slider
   - Top process count (3-20)
   - Visualization options
   - Module-specific toggles

4. `ModuleSettingsView` implementation:
   - List of all modules
   - Tap to expand module settings
   - Save on change

## Key Context

Existing `ModuleSettings` structs already exist in `WidgetConfiguration.swift` but lack UI.

Stats Master exposes these settings categories per module:
- Update intervals (main + processes)
- Top process count
- Visualization splits
- Base units
- Text widget variables
- Per-metric toggles
- Sensor selection lists
- Fan behavior controls
- ICMP host config (network)
- Data reset intervals

Start with essential settings: update interval, top process count, fan mode (sensors), time format (battery).
## Acceptance
- [ ] ModuleSettings protocol defined
- [ ] All 8 module settings structs conform to protocol
- [ ] ModuleSettingsView shows list of modules
- [ ] Tapping module shows its settings view
- [ ] Update interval setting works for all modules
- [ ] Top process count setting works (3-20 range)
- [ ] Fan mode setting works (sensors module)
- [ ] Time format setting works (battery module)
- [ ] Settings persist immediately on change
## Done summary
TBD

## Evidence
- Commits:
- Tests:
- PRs:
