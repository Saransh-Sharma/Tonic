# fn-6-i4g.5 RAM Enhanced Reader

## Description
Implement Stats Master's enhanced RAM readers including swap, pressure details, and process list.

**Size:** M

**Files:**
- `Tonic/Tonic/Services/WidgetDataManager.swift` (modify)
- `Tonic/Tonic/Models/SystemEnums.swift` (modify - extend MemoryData)

Extend memory data reading to include:
1. **Detailed pressure levels** (normal, warning, critical with numerical value)
2. **Swap usage** with total/used/free
3. **Compressed memory** amount
4. **Top processes by memory usage** (already partially exists, enhance)

Extend `MemoryData` struct:
```swift
public struct MemoryData: Sendable {
    let usedBytes: UInt64
    let totalBytes: UInt64
    let freeBytes: UInt64?         // NEW
    let compressedBytes: UInt64
    let swapTotalBytes: UInt64?    // NEW
    let swapUsedBytes: UInt64?     // NEW
    let pressure: MemoryPressure
    let pressureValue: Double?     // NEW - 0-100 scale
    let topProcesses: [ProcessUsage]?  // NEW
    var usagePercentage: Double { ... }
}
```

## Approach

1. Study Stats Master's RAM readers at `stats-master/Modules/RAM/readers.swift`
2. Use existing `host_statistics64()` pattern from `WidgetDataManager.swift:565-624`
3. Add `vm_statistics64()` for swap information
4. Add `sysctlbyname("vm.swapusage")` for detailed swap data
5. Pressure value: Map `MemoryPressure` enum to 0-100 scale (normal=0-33, warning=34-66, critical=67-100)
6. Process reader: Use `top -l 1 -o mem -stats pid,command,mem` parsing
7. Reuse existing `topMemoryApps` array from `WidgetDataManager.swift:1195`

## Key Context

Stats Master shows top 5 processes by memory. We already collect `topMemoryApps` — just need to ensure it's populated correctly and exposed via `MemoryData`.

Pressure level detection via `sysctlbyname("vm.memory_pressure")` — returns 0-4 mapping to normal/warning/critical.
## Acceptance
- [ ] MemoryData extended with freeBytes
- [ ] MemoryData extended with swapTotalBytes, swapUsedBytes
- [ ] MemoryData extended with pressureValue (0-100 scale)
- [ ] MemoryData extended with topProcesses array
- [ ] Swap reader implemented via sysctl
- [ ] Pressure value mapping implemented
- [ ] Process memory list populated via top command
- [ ] topMemoryApps array correctly populated
- [ ] All new readers follow Reader protocol
- [ ] Thread-safe with existing patterns
## Done summary
Enhanced MemoryReader and WidgetDataManager with Stats Master parity for RAM monitoring. Implemented kernel memory pressure detection via kern.memorystatus_vm_pressure_level sysctl, process memory list via top command, and proper swap usage reading via vm.swapusage sysctl. All new enhanced properties (freeBytes, swapTotalBytes, swapUsedBytes, pressureValue, topProcesses) are now populated correctly.
## Evidence
- Commits: 14483c3ecbe71716ff5b1eadc4a30920099f0965
- Tests: xcodebuild -scheme Tonic -configuration Debug build
- PRs: