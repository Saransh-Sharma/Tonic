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
- [x] DiskPopoverView uses PerDiskContainer for each volume
- [x] Multiple volumes stack vertically
- [x] Top processes section shows process name, read/write totals
- [x] Process count configurable via topProcessCount property
- [x] Disk hot-plug handled (ForEach handles gracefully)
- [x] I/O operations count and timing stats added to DiskVolumeData
- [x] Shared read/write history in WidgetDataManager (180 points)
- [ ] DiskModuleSettings integration (deferred to fn-8-v3b.15)
- [ ] Per-process I/O rates (deferred - cumulative totals shown)
- [ ] Per-volume history in DiskVolumeData (uses shared WidgetDataManager history)
## Done summary
Task completed with documented deviations:
- DiskPopoverView refactored to use PerDiskContainer for each volume (stacked vertically)
- Top processes section added with cumulative I/O data (labeled "Read (Total)" / "Write (Total)")
- Process count configurable via topProcessCount property (ready for DiskModuleSettings in fn-8-v3b.15)
- Shared history from WidgetDataManager used for boot volume charts
- Disk hot-plug handled via ForEach
- Future enhancements documented in code comments
## Evidence
- Commits:
- Tests:
- PRs: