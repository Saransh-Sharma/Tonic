# Stats Master Popover View Parity Epic

## Overview

Achieve exact visual and functional parity between Tonic's popover views and Stats Master's. This epic provides precise specifications for replicating each popover section-by-section with exact measurements, component types, and missing features.

## Priority Matrix

### Critical (Feature Parity)
1. **Sensors**: Add fan control UI (~450 lines)
2. **RAM**: Add pressure gauge (3-color arc with needle)
3. **GPU**: Add per-GPU containers with 4 gauges + 4 charts
4. **CPU**: Add scheduler limit, speed limit, uptime fields
5. **Disk**: Add per-disk dual-line charts + top processes
6. **Battery**: Add electrical measurements (amperage, voltage, power)

### Important (Layout Exactness)
7. Standardize width: 320px → 280px
8. Chart history: Standardize to 180 points
9. Section heights: Match Stats Master measurements
10. Font sizes: Use exact sizes (9/11/13pt)

### Nice-to-Have
11. Expandable details panels (GPU, Disk)
12. Interface details toggle (Network)
13. Multiple battery levels per device (Bluetooth)
14. WiFi extended tooltip (Network)

---

## Shared Constants

### Stats Master Reference
```swift
struct Popup {
    static let width: CGFloat = 280       // Tonic: 320px (DIFFERENT)
    static let margins: CGFloat = 10       // Tonic: 12px
    static let separatorHeight: CGFloat = 22
    static let fontSmall: CGFloat = 9      // Tonic: varies
    static let fontMedium: CGFloat = 11     // Tonic: varies
    static let fontLarge: CGFloat = 13      // Tonic: varies
}
```

**Action Required**: Update `PopoverConstants.swift` to match Stats Master values.

---

## Component Mapping

| Stats Master | Tonic Equivalent | Status |
|--------------|------------------|--------|
| LineChartView | NetworkSparklineChart | Partial - different history |
| HalfCircleGraphView | TemperatureGaugeView | Similar |
| PieChartView | CPUCircularGaugeView | Similar |
| NetworkChartView | DualLineChartView | Similar |
| GridChartView | ConnectivityGridView | ✓ |
| BatteryView | batteryVisualView | Similar |
| ProcessesView | ProcessRow | ✓ |
| NSGridView | VStack of IconLabelRow | Functional |
| ColorView | IndicatorDot | ✓ |

---

## 1. CPU Popover Parity (CPU/popup.swift → CPUPopoverView.swift)

### Stats Master Layout (677 lines)

| Section | Height | Components | Layout Details |
|---------|--------|------------|----------------|
| Dashboard | 90px | 3 gauges horizontal | PieChartView (80x80 center), HalfCircleGraphView temp (left), HalfCircleGraphView freq (right) |
| Chart | 120px + separator | LineChartView + BarChartView | Line chart 180pts history, per-core bar chart below |
| Details | Dynamic | Color-coded rows | System/User/Idle with color dots, E-cores/P-cores, Scheduler limit, Speed limit, Uptime |
| Average Load | 22px × 3 | 3 vertical columns | 1 min, 5 min, 15 min with values |
| Frequency | Dynamic | 3 horizontal items | All, E-Cores, P-Cores in MHz |
| Top Processes | 22px × n | Process list | Configurable (default 8) |

### Missing in Tonic
1. Scheduler limit field (value: `cpuData.schedulerLimit`)
2. Speed limit field (value: `cpuData.speedLimit`)
3. Uptime display (formatted uptime string)
4. Line chart + Bar chart combined layout (currently only sparkline)
5. Per-core color matching - E/P cores should use same colors as per-core section
6. Chart history: 180 points vs Tonic's 60-120

### Exact Height Calculations
```
Dashboard: 90px
Chart: 120px + 2px separator
Details: (16px × number of fields) + 2px separator
Average Load: (22px × 3) + 2px separator
Frequency: (if present) 22px × 3 + 2px separator
Processes: 22px header + (22px × numberOfProcesses)
```

### Tasks
- [ ] Add scheduler limit field to CPUPopoverView
- [ ] Add speed limit field to CPUPopoverView
- [ ] Add uptime display to CPUPopoverView
- [ ] Create combined line + bar chart layout
- [ ] Standardize per-core colors across sections
- [ ] Increase chart history to 180 points

---

## 2. GPU Popover Parity (GPU/popup.swift → GPUPopoverView.swift)

### Stats Master Layout (457 lines)

**Per-GPU Container (GPUView class):**

| Component | Height | Details |
|-----------|--------|---------|
| Title bar | 24px | Model name (left, 13pt), Status indicator (6x6 circle), "DETAILS" button (right, 9pt) |
| Circles Row | 50px | 4 gauges horizontal: Temperature, Utilization, Render, Tiler (each 50x50px) |
| Charts Row | 60px + margins | 4 line charts horizontal, 120 points history (each 100x60px) |
| Details Panel | Expandable | NSGridView with: Vendor, Model, Cores, Status, Fan speed, Core clock, Memory clock, Temperature, Utilization, Render, Tiler |

### Missing in Tonic
1. Per-GPU architecture - Tonic shows single combined view
2. Four separate metric gauges - Temperature, Utilization, Render utilization, Tiler utilization
3. Four separate line charts - One per metric with 120-point history
4. Expandable details panel - Toggle with "DETAILS" button
5. Status indicator in title bar (green/red circle)
6. GPU metadata fields: Vendor, Cores, Fan speed, Core clock, Memory clock
7. Render/Tiler utilization metrics

### Required Components to Create
```swift
// Need to create:
HalfCircleGraphView      // Semi-circle gauge with text overlay
GPUDetailsGridView       // NSGridView-based details panel
PerGpuContainer          // Container for multiple GPUs
```

### Tasks
- [ ] Create PerGpuContainer component
- [ ] Create 4-gauge dashboard (Temperature, Utilization, Render, Tiler)
- [ ] Create 4 separate line charts with 120-point history
- [ ] Add expandable details panel with "DETAILS" button
- [ ] Add status indicator (green/red circle) in title bar
- [ ] Add GPU metadata fields to data layer
- [ ] Add Render/Tiler utilization to data layer

---

## 3. Memory/RAM Popover Parity (RAM/popup.swift → MemoryPopoverView.swift)

### Stats Master Layout (~400 lines)

| Section | Height | Components |
|---------|--------|------------|
| Dashboard | 90px | Pressure gauge (3-color arc with needle) |
| Chart | 70px + separator | LineChartView |
| Details | 22px × fields | Used, Wired, Active, Compressed, Free, Total |
| Swap | Dynamic | Swap used, Swap size |
| Processes | 22px × n | Top processes (default 8) |

### Critical Missing Feature: Pressure Gauge

Stats Master uses a three-segment arc gauge:
- Green arc: 0-50% (normal pressure)
- Yellow arc: 50-80% (warning pressure)
- Red arc: 80-100% (critical pressure)
- Needle pointing to current pressure level

**Exact Pressure Gauge Specs:**
- Size: ~80x80px
- Arc segments: Green (0-180°), Yellow (180-270°), Red (270-360°)
- Needle: Rotates based on pressure level
- Center text: Pressure level or percentage

### Missing in Tonic
1. Pressure gauge - The signature 3-color arc with needle
2. Swap section - Swap used, Swap size fields
3. Field count: Only shows 4-5 fields vs Stats Master's 6-8

### Tasks
- [ ] Create PressureGaugeView component with 3-color arc
- [ ] Add needle animation based on pressure level
- [ ] Add Swap section to MemoryPopoverView
- [ ] Add missing memory fields (Active, Compressed)

---

## 4. Disk Popover Parity (Disk/popup.swift → DiskPopoverView.swift)

### Stats Master Layout

**Per-Disk Container (DiskView):**
- Title bar: Disk name + used percentage
- Chart: Dual-line LineChartView (read/write), 180 points history, two colors
- Details: Expandable grid (Total, Free, Used, Operation reads/writes, Read/Write bytes/time)
- Process Section: Top processes with disk I/O (configurable, default 8)

### Missing in Tonic
1. Per-disk charts - Each disk gets its own read/write line chart
2. Dual-line charts - Separate lines for read and write
3. Expandable details per disk - Toggle to show extended info
4. I/O statistics: Operation reads/writes, read/write time
5. Top processes section - Completely missing
6. Chart history: 180 points vs fewer in Tonic

### Tasks
- [ ] Create PerDiskContainer component
- [ ] Add dual-line charts for read/write
- [ ] Add expandable details panel
- [ ] Add I/O statistics fields
- [ ] Create top processes section for disk I/O
- [ ] Increase chart history to 180 points

---

## 5. Network Popover Parity (Net/popup.swift → NetworkPopoverView.swift)

### Stats Master Layout (936 lines)

| Section | Height | Layout |
|---------|--------|--------|
| Dashboard | 90px | Left/Right split (140px each): Downloading/Uploading |
| Chart | 90px | NetworkChartView (dual-line, 180 pts) |
| Connectivity | 30px | GridChartView (30×3 grid = 90 cells) |
| Details | Dynamic | Total upload/download (color-coded), Status, Internet, Latency, Jitter |
| Interface | Dynamic | Interface, Status, Physical address, Network (WiFi only), Standard, Channel, Speed, DNS (toggle) |
| Address | Dynamic | Local IP, Public IPv4, Public IPv6 |
| Processes | 22px × n | Top 8 processes, download/upload columns |

### Key Differences

| Feature | Stats Master | Tonic | Action |
|---------|--------------|-------|--------|
| Chart component | NetworkChartView (custom) | DualLineChartView | Status: Similar |
| Chart history | 180 points | 180 points | ✓ Complete |
| Connectivity view | GridChartView (30×3) | ConnectivityGridView | ✓ Complete |
| Public IP refresh | Button in header | Button in header | ✓ Complete |
| Reset totals | Button with icon | Button with icon | ✓ Complete |
| Interface details toggle | Yes | Partial | **Need fix** |
| DNS servers | Yes (toggleable) | No | **Add** |
| WiFi details tooltip | RSSI, Noise, Channel #/band/width | Simplified | **Enhance** |
| Top processes count | Configurable | Hardcoded to 8 | **Add config** |

### Missing in Tonic
1. DNS Servers field - Toggleable in interface details
2. Channel tooltip - Extended WiFi info (RSSI, noise, channel number/band/width)
3. Interface details toggle - Expand Standard/Channel/Speed rows
4. Top processes count configuration - Hardcoded to 8

### Tasks
- [ ] Add DNS Servers toggle field
- [ ] Add extended WiFi tooltip (RSSI, noise, channel info)
- [ ] Add interface details toggle
- [ ] Make top processes count configurable

---

## 6. Battery Popover Parity (Battery/popup.swift → BatteryPopoverView.swift)

### Stats Master Layout (439 lines)

| Section | Height | Fields |
|---------|--------|--------|
| Dashboard | 90px | BatteryView (custom drawn, 120×50) |
| Details | 22px × 4 | Level, Source, Time (calculating), Last charge |
| Battery | 22px × 7 | Health, Capacity (current/max/designed), Cycles, Temperature, Power, Amperage, Voltage |
| Adapter | 22px × 4 (conditional) | Is charging, Power, Current, Voltage |
| Processes | 22px × n | Top CPU consumers (battery impact) |

### Exact BatteryView Drawing Specs

```swift
// BatteryView.draw(_ dirtyRect:)
- Battery frame: w=120, h=50 (min values)
- Corner radius: 3px
- Battery tip: 8x8px, rounded corners (4px)
- Fill width: (w-10) × percentage
- Colors: percentageColor(color: colorState)
- Font: 13pt light for percentage
```

### Missing in Tonic
1. Capacity breakdown - "current / maximum / designed mAh" format
2. Amperage field - Current draw in mA
3. Voltage field - Voltage in V
4. Battery power field - Calculated: voltage × (amperage/1000) = W
5. Charging current field - In adapter section
6. Charging voltage field - In adapter section
7. Last charge tooltip - Shows exact date/time
8. Time format preference - Short vs full format

### Tasks
- [ ] Add capacity breakdown display (current/max/designed)
- [ ] Add amperage field (current draw in mA)
- [ ] Add voltage field (V)
- [ ] Add calculated battery power field (W)
- [ ] Add charging current field to adapter section
- [ ] Add charging voltage field to adapter section
- [ ] Add last charge tooltip with exact date/time
- [ ] Add time format preference setting

---

## 7. Sensors Popover Parity (Sensors/popup.swift → SensorsPopoverView.swift)

### Stats Master Layout (~700 lines)

| Section | Components | Notes |
|---------|------------|-------|
| Dashboard | Temperature/fan gauges | Optional |
| Fan Control | ~450 lines of fan slider controls | **MAJOR MISSING FEATURE** |
| Temperatures | List with color-coded values | Each sensor: name, value, min/max bar |
| Fans | List with RPM bars | Fan name, RPM, progress bar, mode |
| Voltage | List | Name, voltage value |
| Power | List | Name, power value (W) |

### Critical Missing Feature: Fan Control (~450 lines)

Stats Master has full fan control UI:
- Per-fan speed sliders
- Manual/Auto/Sys control modes
- Min/Max speed indicators
- Current speed display
- Fan speed curve editor
- This is a MAJOR feature completely missing from Tonic

### Missing in Tonic
1. Fan control UI - Entire section (~450 lines)
2. Fan modes - Manual/Auto/Sys
3. Fan speed sliders - Per-fan control
4. Min/Max indicators - Per-fan
5. Mode display - Shows current fan control mode

### Tasks
- [ ] Create FanControlView component (~450 lines)
- [ ] Add per-fan speed sliders
- [ ] Add Manual/Auto/Sys control modes
- [ ] Add Min/Max speed indicators
- [ ] Add mode display
- [ ] Add fan speed curve editor (optional advanced feature)

---

## 8. Bluetooth Popover Parity (Bluetooth/popup.swift → BluetoothPopoverView.swift)

### Stats Master Layout (132 lines)

**Simple Device List:**
- BLEView per device (30px height each)
- Device name (left, 13pt light)
- Battery levels (right, multiple per device)
  - Each battery: 12pt regular, percentage + unit
  - Tooltip shows battery type (e.g., "Case", "Left", "Right")
- Empty state: "No Bluetooth devices are available"

### Comparison

| Feature | Stats Master | Tonic |
|---------|--------------|-------|
| Device list | Simple name + batteries | Full card with icon, type, signal |
| Battery display | Text percentage | Icon + percentage |
| Signal strength | Not shown | 4-bar indicator |
| Status section | No | Yes (metrics) |
| History chart | No | Yes |
| Connection count | No | Yes |

**Analysis**: Tonic's Bluetooth popover is MORE feature-rich than Stats Master's. However:
- Stats Master shows multiple batteries per device (e.g., AirPods case + left + right)
- Tonic only shows primaryBatteryLevel (single value)

### Required Change

```swift
// Support multiple battery levels per device:
struct BluetoothDevice {
    var batteryLevels: [KeyValue_t]  // Array of (type, percentage)
    // Example: [("Case", 100), ("Left", 85), ("Right", 82)]
}
```

### Tasks
- [ ] Update BluetoothDevice model to support multiple battery levels
- [ ] Update BluetoothPopoverView to display multiple batteries per device
- [ ] Add tooltip to show battery type (Case, Left, Right, etc.)

---

## 9. Clock Popover

Stats Master does not have a Clock popover. Tonic's ClockPopoverView is original implementation.

**Status**: No changes needed.

---

## Menu Bar Refresh Bug Fix

### Root Cause Identified

```swift
// Tonic WidgetStatusItem.swift:
public func updateConfiguration(_ newConfig: WidgetConfiguration) {
    configuration = newConfig
    objectWillChange.send()  // <-- May not trigger NSView update
}
```

### Stats Master Approach

```swift
// Stats Master directly manipulates NSView:
self.setNeedsDisplay(self.frame)  // Force redraw
self.display()  // Triggers immediate redraw
```

### Proposed Fix

```swift
// In WidgetStatusItem.swift:
public func updateConfiguration(_ newConfig: WidgetConfiguration) {
    configuration = newConfig
    objectWillChange.send()

    // Force immediate NSView refresh
    DispatchQueue.main.async {
        if let statusItem = self.statusItem {
            let button = statusItem.button
            button?.window?.contentView?.setNeedsDisplay(button?.bounds ?? .zero)
            // Recreate the hosted view to force SwiftUI refresh
            self.updateView()
        }
    }
}
```

### Tasks
- [ ] Apply NSView refresh fix to WidgetStatusItem.swift
- [ ] Test configuration changes propagate immediately

---

## Implementation Priority

### Phase 1: Layout Standardization (1-2 days)
1. Fix popover width to 280px
2. Update PopoverConstants.swift to match Stats Master
3. Standardize font sizes (9/11/13pt)
4. Standardize section heights

### Phase 2: CPU Popover Enhancement (2-3 days)
5. Add missing CPU fields (scheduler/speed limits, uptime)
6. Create combined line + bar chart layout
7. Standardize per-core colors
8. Increase chart history to 180 points

### Phase 3: Memory Popover Enhancement (1-2 days)
9. Create PressureGaugeView component
10. Add Swap section
11. Add missing memory fields

### Phase 4: GPU Popover Enhancement (3-4 days)
12. Create PerGpuContainer
13. Create 4-gauge dashboard
14. Create 4 separate line charts
15. Add expandable details panel

### Phase 5: Disk Popover Enhancement (2-3 days)
16. Create PerDiskContainer
17. Add dual-line charts
18. Add top processes section
19. Add I/O statistics

### Phase 6: Battery Popover Enhancement (1-2 days)
20. Add electrical measurement fields
21. Add capacity breakdown
22. Add time format preference

### Phase 7: Sensors Popover Enhancement (5-7 days)
23. Create FanControlView (~450 lines)
24. Add fan control modes
25. Add per-fan speed sliders
26. Add min/max indicators

### Phase 8: Network/Bluetooth Polish (1 day)
27. Add DNS servers field
28. Add extended WiFi tooltip
29. Support multiple battery levels per device

### Phase 9: Bug Fixes & Final Polish (1 day)
30. Apply menu bar refresh bug fix
31. Final testing and verification

---

## Estimated Effort

| Phase | Tasks | Est. Days |
|-------|-------|-----------|
| Layout Standardization | 1-4 | 1-2 |
| CPU Popover | 5-8 | 2-3 |
| Memory Popover | 9-11 | 1-2 |
| GPU Popover | 12-15 | 3-4 |
| Disk Popover | 16-19 | 2-3 |
| Battery Popover | 20-22 | 1-2 |
| Sensors Popover | 23-26 | 5-7 |
| Network/Bluetooth | 27-29 | 1 |
| Bug Fixes | 30-31 | 1 |
| **TOTAL** | **31 tasks** | **17-25 days** |

---

## Verification Checklist

For each popover:
- [ ] Width is 280px
- [ ] Dashboard height is 90px
- [ ] Section headers are 22px
- [ ] Detail rows are 16px
- [ ] Process rows are 22px
- [ ] Chart history is 180 points
- [ ] Font sizes are 9/11/13pt
- [ ] All fields from Stats Master are present
- [ ] Layout matches Stats Master visually
- [ ] Interactions match Stats Master behavior

---

## References

### Stats Master Source Location
```
../stats-master/Modules/CPU/popup.swift
../stats-master/Modules/GPU/popup.swift
../stats-master/Modules/RAM/popup.swift
../stats-master/Modules/Disk/popup.swift
../stats-master/Modules/Net/popup.swift
../stats-master/Modules/Battery/popup.swift
../stats-master/Modules/Sensors/popup.swift
../stats-master/Modules/Bluetooth/popup.swift
../stats-master/Kit/module/Constants.swift
```

### Tonic Target Files
```
Tonic/Tonic/MenuBarWidgets/Popovers/CPUPopoverView.swift
Tonic/Tonic/MenuBarWidgets/Popovers/GPUPopoverView.swift
Tonic/Tonic/MenuBarWidgets/Popovers/MemoryPopoverView.swift
Tonic/Tonic/MenuBarWidgets/Popovers/DiskPopoverView.swift
Tonic/Tonic/MenuBarWidgets/Popovers/NetworkPopoverView.swift
Tonic/Tonic/MenuBarWidgets/Popovers/BatteryPopoverView.swift
Tonic/Tonic/MenuBarWidgets/Popovers/SensorsPopoverView.swift
Tonic/Tonic/MenuBarWidgets/Popovers/BluetoothPopoverView.swift
Tonic/Tonic/MenuBarWidgets/Popovers/PopoverConstants.swift
```
