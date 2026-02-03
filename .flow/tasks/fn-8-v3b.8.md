# fn-8-v3b.8 Create PerDiskContainer with dual-line charts

## Description
Create `PerDiskContainer.swift` component for per-disk visualization with dual-line read/write charts.

**Size:** M

**Files:**
- `Tonic/Tonic/MenuBarWidgets/Components/PerDiskContainer.swift` (NEW, ~200 lines)

## Approach

Create a container view that represents a single disk with:

1. **Title bar:** Disk name + used percentage badge
2. **Chart section:** Dual-line chart (120px height)
   - Blue line: Read rate
   - Red line: Write rate
   - 180 points history each
3. **Details section:** Expandable grid with:
   - Total capacity, Used, Free
   - Read rate, Write rate
   - I/O operations count
   - I/O timing stats (read time, write time)

Use SwiftUI `Charts` framework or existing dual-line chart component.

Follow Stats Master's per-disk popup pattern from `stats-master/Modules/Disks/popup.swift`.

## Key Context

Need dual-line chart component. Options:
1. Use SwiftUI Charts `LineMark` with two series
2. Create custom `DualLineChartView` using `Path` and `Shape`

Reference existing `NetworkDualLineChartView` pattern in `NetworkPopoverView.swift` for dual-line implementation.

Disk data from `WidgetDataManager.diskData` needs:
- `readHistory: [Double]` (180 points)
- `writeHistory: [Double]` (180 points)
- `operationReads: UInt64`
- `operationWrites: UInt64`
- `readTime: TimeInterval`
- `writeTime: TimeInterval`
## Acceptance
- [ ] PerDiskContainer.swift created with title bar and dual-line chart
- [ ] Dual-line chart shows read (blue) and write (red)
- [ ] Chart displays 180 points of history
- [ ] Details section shows capacity, rates, I/O counts, timing
- [ ] Details panel expands/collapses
- [ ] Used percentage badge colors correctly (green/yellow/red)
- [ ] Handles missing I/O timing data gracefully
## Done summary
- Task completed
## Evidence
- Commits:
- Tests:
- PRs: