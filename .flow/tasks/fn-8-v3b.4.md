# fn-8-v3b.4 Create MemoryPopoverView with pressure gauge

## Description
Create `MemoryPopoverView.swift` using pressure gauge as the primary visual element. This file does not currently exist.

**Size:** M

**Files:**
- `Tonic/Tonic/MenuBarWidgets/Popovers/MemoryPopoverView.swift` (NEW, ~300 lines)

## Approach

Follow the pattern from `CPUPopoverView.swift` (~330 lines) as a template.

Structure:
1. **Dashboard section (90px):** PressureGaugeView as primary visual + key metrics
2. **Chart section (120px):** Line chart showing 180-point memory history
3. **Details section:** 6 fields - Used, Wired, Active, Compressed, Free, Total
4. **Swap section:** Swap used / Swap size (hide if swapTotalBytes == 0)
5. **Processes section (22px × n):** Top memory-consuming processes

Use `PopoverTemplate.swift` components:
- `PopoverSection` for section containers
- `PopoverDetailRow` for key-value displays
- `ProcessRow` for process list

## Key Context

`WidgetDataManager.memoryData` already has:
- usedBytes, totalBytes
- pressure: MemoryPressure enum
- compressedBytes, swapBytes
- Enhanced properties (optional): freeBytes, swapTotalBytes, swapUsedBytes, pressureValue, topProcesses

Need to add missing properties to `MemoryData` struct if not present:
- `activeBytes: UInt64`
- `freeBytes: UInt64`
- `swapTotalBytes: UInt64`
- `swapUsedBytes: UInt64`
- `pressureValue: Double?` (0-100 scale)

Update data collection in `WidgetDataManager.swift` around line ~1400 (memory data section).
## Acceptance
- [ ] MemoryPopoverView.swift created following CPUPopoverView pattern
- [ ] PressureGaugeView integrated as dashboard primary visual
- [ ] Line chart shows 180-point memory history
- [ ] Details section shows: Used, Wired, Active, Compressed, Free, Total (6 fields)
- [ ] Swap section shows used/total (hidden if not configured)
- [ ] Processes section shows top memory consumers
- [ ] Popover width is 280px
- [ ] All sections use standardized row heights
## Done summary
- Task completed
## Evidence
- Commits:
- Tests:
- PRs: