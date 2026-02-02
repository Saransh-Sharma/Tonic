# fn-8-v3b.9 Update DiskPopoverView with I/O stats and processes

## Description
Update `DiskPopoverView.swift` to use `PerDiskContainer` for each disk and add top processes section.

**Size:** M

**Files:**
- `Tonic/Tonic/MenuBarWidgets/Popovers/DiskPopoverView.swift`
- `Tonic/Tonic/Services/WidgetDataManager.swift` (add disk I/O data)

## Approach

1. Update `DiskVolumeData` to add:
   ```swift
   public let readHistory: [Double]
   public let writeHistory: [Double]
   public let operationReads: UInt64
   public let operationWrites: UInt64
   public let readTime: TimeInterval
   public let writeTime: TimeInterval
   public let topProcesses: [ProcessUsage]  // with disk I/O
   ```

2. Update `ProcessUsage` struct to include disk metrics:
   ```swift
   public let diskReadBytes: UInt64
   public let diskWriteBytes: UInt64
   ```

3. Refactor `DiskPopoverView` to:
   - Use `PerDiskContainer` for each volume
   - Add top processes section with disk I/O columns
   - Configurable process count (default 8, from `DiskModuleSettings.topProcessCount`)

4. Handle disk hot-plug: Use `@State` to track available volumes

## Key Context

Disk I/O data comes from `proc_pid_rusage` for per-process stats (already imported at line 22).

For system-wide disk stats, use IOKit `IOBlockStorageDriver` statistics keys:
- `kIOBlockStorageDriverStatisticsBytesReadKey`
- `kIOBlockStorageDriverStatisticsBytesWrittenKey`
- `kIOBlockStorageDriverStatisticsReadsKey`
- `kIOBlockStorageDriverStatisticsWritesKey`
- `kIOBlockStorageDriverStatisticsTotalReadTimeKey`
- `kIOBlockStorageDriverStatisticsTotalWriteTimeKey`

Process list should show: Process Name, Read Rate, Write Rate (formatted).
## Acceptance
- [ ] DiskVolumeData has read/write history arrays (180 points)
- [ ] DiskVolumeData has I/O operations count and timing stats
- [ ] DiskPopoverView uses PerDiskContainer for each volume
- [ ] Top processes section shows process name, read rate, write rate
- [ ] Process count configurable via DiskModuleSettings
- [ ] Disk hot-plug handled (no crash on volume ejection)
- [ ] Multiple volumes stack vertically
## Done summary
- Task completed
## Evidence
- Commits:
- Tests:
- PRs: