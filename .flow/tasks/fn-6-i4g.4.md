# fn-6-i4g.4 CPU Enhanced Reader

## Description
Implement Stats Master's enhanced CPU readers in Tonic's architecture.

**Size:** M

**Files:**
- `Tonic/Tonic/Services/WidgetDataManager.swift` (modify - add CPU readers)
- `Tonic/Tonic/Models/SystemEnums.swift` (modify - extend CPUData)

Extend CPU data reading to include:
1. **Per-core usage** with E/P core cluster identification
2. **CPU frequency** reading (E cores vs P cores on Apple Silicon)
3. **CPU temperature** via IOKit thermal sensors
4. **Thermal limits** via `pmset -g therm`
5. **Average load** via `uptime` command

Extend `CPUData` struct:
```swift
public struct CPUData: Sendable {
    let totalUsage: Double
    let perCoreUsage: [Double]
    let eCoreUsage: [Double]?      // NEW
    let pCoreUsage: [Double]?      // NEW
    let frequency: Double?         // NEW - GHz
    let temperature: Double?       // NEW - Celsius
    let thermalLimit: Bool?        // NEW - throttling
    let averageLoad: [Double]?     // NEW - 1min, 5min, 15min
    let timestamp: Date
}
```

## Approach

1. Study Stats Master's CPU readers at `stats-master/Modules/CPU/readers.swift:42-151`
2. **FrequencyReader**: Use IOReport for CPU frequency on Apple Silicon
3. **TemperatureReader**: Use IOKit `IOServiceMatching("IOThermalSensor")`
4. **LimitReader**: Parse `pmset -g therm` output
5. **AverageLoadReader**: Parse `uptime` command output
6. Add methods to `WidgetDataManager` to populate new fields
7. Keep existing `host_processor_info()` pattern from `WidgetDataManager.swift:468-525`
8. Use existing `cpuLock` for thread safety

## Key Context

Stats Master uses platform-specific sensor lists for temperature. For Apple Silicon, focus on `CPU0` and `CPU1` sensors via IORegistry.

E/P core identification: On Apple Silicon, first N cores are E (efficiency), rest are P (performance). Use `hw.physicalcpu` and `hw.perflevel0.physicalcpu` sysctls.

Reference: Stats Master's CPU cluster coloring at `stats-master/Modules/CPU/widget.swift`.
## Acceptance
- [ ] CPUData extended with eCoreUsage, pCoreUsage
- [ ] CPUData extended with frequency field
- [ ] CPUData extended with temperature field
- [ ] CPUData extended with thermalLimit field
- [ ] CPUData extended with averageLoad field
- [ ] Frequency reader implemented via IOReport
- [ ] Temperature reader implemented via IOKit
- [ ] Thermal limit reader implemented via pmset
- [ ] Average load reader implemented via uptime
- [ ] E/P core identification works on Apple Silicon
- [ ] All new readers follow Reader protocol from Task 1
- [ ] Thread-safe with existing locking patterns
## Done summary
Extended CPUData struct with enhanced CPU monitoring capabilities including E/P core usage distribution, CPU frequency, temperature, thermal throttling detection, and load averages. Added six new reader methods to WidgetDataManager with Apple Silicon support and graceful fallbacks for Intel Macs.
## Evidence
- Commits: cdb203813435a1ea6daf46528b3dda2093b634b5
- Tests: xcodebuild -scheme Tonic -configuration Debug -destination 'platform=macOS' build
- PRs: