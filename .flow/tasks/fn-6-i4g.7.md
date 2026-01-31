# fn-6-i4g.7 Disk Enhanced Reader

## Description
Implement Stats Master's enhanced disk readers including NVMe SMART data and IOPS tracking.

**Size:** M

**Files:**
- `Tonic/Tonic/Services/WidgetDataManager.swift` (modify)
- `Tonic/Tonic/Models/SystemEnums.swift` (modify - extend DiskVolumeData)

Extend disk data reading to include:
1. **NVMe SMART data** - temperature, life percentage, critical warnings
2. **IOPS** - read/write operations per second
3. **Activity tracking** - detailed read/write bytes with delta calculation
4. **Top processes by disk I/O**

Extend `DiskVolumeData` struct:
```swift
public struct DiskVolumeData: Sendable {
    let name: String
    let path: String
    let usedBytes: UInt64
    let totalBytes: UInt64
    let isBootVolume: Bool
    let smartData: NVMeSMARTData?   // NEW
    let readIOPS: Double?           // NEW
    let writeIOPS: Double?          // NEW
    let readBytesPerSecond: Double? // NEW
    let writeBytesPerSecond: Double?// NEW
    let topProcesses: [ProcessUsage]? // NEW
    var usagePercentage: Double { ... }
}
```

## Approach

1. Study Stats Master's disk readers at `stats-master/Modules/Disk/readers.swift`
2. **NVMe SMART**: Use IORegistry to access NVMe drive `IODeviceTree:/PCI0@0/RP0@1C/.../IONVMeController`
3. Query `SMART` attribute data via IOServiceGetMatchingService
4. **IOPS**: Use IORegistry block storage statistics
5. **Activity**: Calculate delta from previous IORegistry snapshot
6. **Process I/O**: Parse `proc_pid_rusage()` for per-process disk stats
7. For non-NVMe drives, gracefully omit SMART data

## Key Context

NVMe SMART access requires root privileges via helper tool. If TonicHelperTool exists, extend it. Otherwise, implement fallback to basic disk info.

SMART attributes:
- Attribute 1: Critical Warning
- Attribute 2: Composite Temperature
- Attribute 3: Available Spare
- Attribute 4: Percentage Used
- Attribute 5: Data Units Read
- Attribute 6: Data Units Written

Reference: Existing disk code at `WidgetDataManager.swift:677-713`.
## Acceptance
- [ ] DiskVolumeData extended with smartData
- [ ] DiskVolumeData extended with readIOPS, writeIOPS
- [ ] DiskVolumeData extended with readBytesPerSecond, writeBytesPerSecond
- [ ] DiskVolumeData extended with topProcesses
- [ ] NVMe SMART reader implemented
- [ ] Temperature, life percentage, critical warnings captured
- [ ] IOPS tracking implemented
- [ ] Activity bytes per second calculated
- [ ] Process disk I/O via proc_pid_rusage
- [ ] Graceful fallback for non-NVMe drives
- [ ] All new readers follow Reader protocol
## Done summary
Enhanced DiskReader with Stats Master parity: NVMe SMART data reading (temperature, life%, critical warnings), IOPS tracking, activity bytes/sec calculation with delta tracking, and process disk I/O tracking via proc_pid_rusage.
## Evidence
- Commits: 28371c616a5a3103c335dc03d821bce46c16a514
- Tests: xcodebuild -scheme Tonic -configuration Debug build
- PRs: