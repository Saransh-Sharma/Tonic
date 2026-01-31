# fn-6-i4g.8 Sensors & Battery Enhanced Readers

## Description
Implement Stats Master's comprehensive SMC sensors reader and enhanced battery reader.

**Size:** M

**Files:**
- `Tonic/Tonic/Services/WidgetDataManager.swift` (modify)
- `Tonic/Tonic/Models/SensorsData.swift` (modify - extend)
- `Tonic/Tonic/Models/SystemEnums.swift` (modify - extend BatteryData)
- `Tonic/Tonic/Services/SMCReader.swift` (new)

Implement two enhanced readers:

**1. SMC Sensors Reader**:
- Temperature sensors (CPU, GPU, SOC, ambient)
- Voltage sensors (CPU, GPU, SOC)
- Power sensors (CPU, GPU, battery)
- Fan sensors with min/max RPM and mode (auto/forced)

Use existing `SensorsData` struct from Task 2, populate with real SMC data.

**2. Enhanced Battery Reader**:
- Battery health with cycle count
- Optimized charging status (battery health management)
- Charger wattage detection
- Temperature reading

Extend `BatteryData` struct:
```swift
public struct BatteryData: Sendable {
    let isPresent: Bool
    let isCharging: Bool
    let chargePercentage: Double
    let estimatedMinutesRemaining: Int?
    let health: BatteryHealth
    let cycleCount: Int?
    let optimizedCharging: Bool?    // NEW
    let chargerWattage: Double?     // NEW
    let temperature: Double?        // NEW
}
```

## Approach

**SMC Reader**:
1. Study Stats Master's SMC reader at `stats-master/Modules/Sensors/readers.swift`
2. Use IOServiceGetMatchingService for SMC access
3. Use SMC key format: "SP" prefix for sensors
4. Temperature keys: TCXC, TC0C, TC0P, etc.
5. Fan keys: FNum, FAcn, FTg (target), F0Ac (actual)
6. Consider using TonicHelperTool if available for SMC access

**Battery Reader**:
1. Study Stats Master's battery readers at `stats-master/Modules/Battery/readers.swift`
2. Use existing `IOPSCopyPowerSourcesInfo()` from `WidgetDataManager.swift:1007-1067`
3. Add IORegistry query for battery temperature
4. Add IORegistry query for charger wattage
5. Check `pmset -g batt` for optimized charging status

## Key Context

SMC access may require privileged helper tool. Tonic has `TonicHelperTool` — extend it if needed for SMC key reading.

Fan mode detection: Read from IORegistry "AppleSMC" service.

Battery temperature: Available from IORegistry "AppleARMIODevice" or "battery" node.

Reference: Existing battery code at `WidgetDataManager.swift:1007-1067`, existing sensors TODO at `WidgetDataManager.swift`.
## Acceptance
- [ ] SMC reader implemented in new file
- [ ] Temperature sensors populated (CPU, GPU, SOC)
- [ ] Voltage sensors populated
- [ ] Power sensors populated
- [ ] Fan sensors populated with RPM, min, max, mode
- [ ] BatteryData extended with optimizedCharging
- [ ] BatteryData extended with chargerWattage
- [ ] BatteryData extended with temperature
- [ ] Battery temperature read via IORegistry
- [ ] Charger wattage detected
- [ ] Optimized charging status detected
- [ ] Graceful fallback when SMC unavailable
- [ ] All new readers follow Reader protocol
## Done summary
TBD

## Evidence
- Commits:
- Tests:
- PRs:
