# fn-6-i4g.29 CPU Data Layer Enhancement

## Description

Add missing CPU data fields to achieve Stats Master parity:
- **System/User/Idle split** - Currently only provides total usage
- **Uptime** - System boot time display
- **Load Average** - 1/5/15 minute load averages
- **Populate existing fields** - eCoreUsage, pCoreUsage, frequency, temperature

## Files to Modify

1. **Tonic/Tonic/Models/WidgetDataModels.swift** (CPUData struct)
   - Add: `systemUsage`, `userUsage`, `idleUsage`
   - Add: `uptime`, `loadAverage`

2. **Tonic/Tonic/Services/WidgetDataManager.swift**
   - Refactor `updateCPUData()` to calculate System/User/Idle split
   - Populate `eCoreUsage` and `pCoreUsage` with grouped arrays
   - Wire existing `frequency` and `temperature` data
   - Add uptime and load average collection

3. **Tonic/Tonic/Services/WidgetReader/CPUReader.swift** (if used)
   - Sync with data model changes

## Implementation Steps

### Step 1: Update CPUData Model
```swift
// File: Tonic/Tonic/Models/WidgetDataModels.swift

public struct CPUData: Sendable {
    // Existing
    public let totalUsage: Double
    public let perCoreUsage: [Double]

    // NEW: System/User/Idle split
    public let systemUsage: Double
    public let userUsage: Double
    public let idleUsage: Double

    // Existing - properly populate these
    public let eCoreUsage: [Double]?      // Grouped E-core values
    public let pCoreUsage: [Double]?      // Grouped P-core values
    public let frequency: Double?         // CPU frequency in GHz
    public let temperature: Double?       // CPU temperature in Celsius

    // NEW: Telemetry
    public let uptime: TimeInterval       // Seconds since boot
    public let loadAverage: [Double]      // [1min, 5min, 15min]

    public let timestamp: Date
}
```

### Step 2: Calculate System/User/Idle Split
```swift
// File: Tonic/Tonic/Services/WidgetDataManager.swift (in updateCPUData)

private func getCPUUsageSplit() -> (system: Double, user: Double, idle: Double) {
    var size = HOST_CPU_LOAD_INFO_COUNT
    var cpuLoadInfo = host_cpu_load_info()

    let result = withUnsafeMutablePointer(to: &cpuLoadInfo) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
            host_statistics(machHostSelf, HOST_CPU_LOAD_INFO, $0, &size)
        }
    }

    guard result == KERN_SUCCESS else {
        return (0, 0, 100)
    }

    let userTicks = Double(cpuLoadInfo.cpu_ticks.0)
    let systemTicks = Double(cpuLoadInfo.cpu_ticks.1)
    let idleTicks = Double(cpuLoadInfo.cpu_ticks.2)
    let niceTicks = Double(cpuLoadInfo.cpu_ticks.3)
    let total = userTicks + systemTicks + idleTicks + niceTicks

    guard total > 0 else { return (0, 0, 100) }

    let system = (systemTicks / total) * 100
    let user = (userTicks / niceTicks) / total * 100
    let idle = (idleTicks / total) * 100

    return (system, user, idle)
}
```

### Step 3: Add Load Average
```swift
// File: Tonic/Tonic/Services/WidgetDataManager.swift

private func getLoadAverage() -> [Double] {
    var loadAverages: [Double] = [0, 0, 0]
    let result = getloadavg(&loadAverages, 3)
    if result == 3 {
        return loadAverages
    }
    return [0, 0, 0]
}
```

### Step 4: Add Uptime
```swift
// File: Tonic/Tonic/Services/WidgetDataManager.swift

private func getUptime() -> TimeInterval {
    var bootTime = timeval()
    var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]

    var len = MemoryLayout<timeval>.stride
    sysctl(&mib, u_int(mib.count), &bootTime, &len, nil, 0)

    return Date().timeIntervalSince1970 - TimeInterval(bootTime.tv_sec)
}
```

### Step 5: Update updateCPUData()
```swift
// File: Tonic/Tonic/Services/WidgetDataManager.swift (around line 796)

private func updateCPUData() {
    // Get existing total usage
    let totalUsage = getCPUUsage()

    // NEW: Get split
    let (systemUsage, userUsage, idleUsage) = getCPUUsageSplit()

    // Get per-core (existing logic)
    let perCoreUsage = getPerCoreUsage()

    // NEW: Group by E/P cores
    let (eCores, pCores) = groupCoresByType(perCoreUsage)

    // Get temperature (existing method at line 1029)
    let temperature = getCPUTemperature()

    // Get frequency (existing method at line 993)
    let frequency = getCPUFrequency()

    // NEW: Get telemetry
    let uptime = getUptime()
    let loadAverage = getLoadAverage()

    let newData = CPUData(
        totalUsage: totalUsage,
        perCoreUsage: perCoreUsage,
        systemUsage: systemUsage,
        userUsage: userUsage,
        idleUsage: idleUsage,
        eCoreUsage: eCores.isEmpty ? nil : eCores,
        pCoreUsage: pCores.isEmpty ? nil : pCores,
        frequency: frequency,
        temperature: temperature,
        uptime: uptime,
        loadAverage: loadAverage,
        timestamp: Date()
    )

    self.cpuData = newData
    self.addToHistory(&self.cpuHistory, value: totalUsage, maxPoints: Self.maxHistoryPoints)
}
```

## Acceptance

- [ ] CPUData contains systemUsage, userUsage, idleUsage
- [ ] CPUData contains uptime (seconds since boot)
- [ ] CPUData contains loadAverage [1m, 5m, 15m]
- [ ] eCoreUsage contains grouped E-core values
- [ ] pCoreUsage contains grouped P-core values
- [ ] frequency is populated with current CPU GHz
- [ ] temperature is populated and accessible
- [ ] Data matches Activity Monitor values (±2%)

## Done Summary

Enhanced CPU data layer with System/User/Idle split, uptime tracking, load average, and properly populated E/P core grouping. All telemetry fields now accessible for UI display.

## Evidence

- Commits:
- Tests:
- PRs:
