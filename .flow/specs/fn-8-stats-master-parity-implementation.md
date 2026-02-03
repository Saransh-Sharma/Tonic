# Stats Master Popover Parity Implementation Plan

**Flow ID:** fn-8
**Created:** 2026-02-02
**Status:** Planning
**Estimate:** 17-25 days

---

## Executive Summary

This plan implements exact visual and functional parity between Tonic's popover views and Stats Master's reference implementation. The specification document provides comprehensive measurements, missing features, and component requirements for each popover type.

**Key Deliverables:**
- 9 popover views enhanced to Stats Master parity
- Standardized layout constants (280px width, 9/11/13pt fonts)
- New components: PressureGaugeView, FanControlView, PerGpuContainer
- Menu bar refresh bug fix
- 31 tasks across 9 implementation phases

---

## Current State Analysis

### Existing Architecture

**PopoverConstants.swift** (Lines 1-200)
- Width: Already set to 280px ✓
- Font sizes: Using DesignTokens system (not exact Stats Master sizes)
- Section heights: Not standardized to Stats Master measurements

**Existing Popovers:**
- `CPUPopoverView.swift` (330 lines) - Missing: scheduler limit, speed limit, uptime, combined line+bar chart
- `GPUPopoverView.swift` (378 lines) - Missing: per-GPU containers, 4 gauges, 4 charts, expandable details
- `MemoryPopoverView.swift` - File not found (needs creation)
- `DiskPopoverView.swift` - Exists (needs verification for dual-line charts)
- `NetworkPopoverView.swift` (547 lines) - Mostly complete, missing: DNS toggle, WiFi tooltip
- `BatteryPopoverView.swift` - Exists (needs verification for electrical measurements)
- `SensorsPopoverView.swift` (437 lines) - Missing: fan control UI (~450 lines)
- `BluetoothPopoverView.swift` - Exists (needs multi-battery support)
- `ClockPopoverView.swift` - Original implementation (no changes needed)

**WidgetConfiguration.swift** (1298 lines)
- Already contains `ModuleSettings` structures for CPU, Disk, Network, Memory, Sensors, Battery
- Migration system in place (version 3)
- Comprehensive widget preferences with persistence

### Critical Gaps Identified

| Gap | Impact | Files Affected |
|-----|--------|----------------|
| Memory popover missing entirely | HIGH | Need to create MemoryPopoverView.swift |
| Fan control UI completely absent | HIGH | SensorsPopoverView.swift |
| Pressure gauge component missing | HIGH | Need to create PressureGaugeView.swift |
| GPU per-GPU architecture missing | MEDIUM | GPUPopoverView.swift |
| CPU scheduler/speed limits missing | MEDIUM | CPUPopoverView.swift |
| Menu bar refresh bug | LOW | WidgetStatusItem.swift |

---

## Implementation Plan by Phase

### Phase 1: Layout Standardization (Tasks 1-4)

**Duration:** 1-2 days
**Priority:** HIGH (Foundation for all popovers)

#### Task 1.1: Update PopoverConstants.swift Typography

**File:** `Tonic/Tonic/MenuBarWidgets/Popovers/PopoverConstants.swift`

**Changes Required:**
```swift
// Add exact Stats Master font sizes
public struct FontSizes {
    public static let small: CGFloat = 9     // Stats Master: fontSmall
    public static let medium: CGFloat = 11    // Stats Master: fontMedium
    public static let large: CGFloat = 13     // Stats Master: fontLarge
}

// Add exact Stats Master spacing
public struct StatsMasterSpacing {
    public static let margins: CGFloat = 10           // Currently 12
    public static let separatorHeight: CGFloat = 22   // Add this
}

// Update existing constants to match
public static let horizontalPadding: CGFloat = 10    // Currently 16
public static let verticalPadding: CGFloat = 10      // Currently 16
```

**Verification:**
- [ ] All popovers use 10pt horizontal/vertical padding
- [ ] Section headers are 22px height
- [ ] Detail rows are 16px height
- [ ] Process rows are 22px height

---

#### Task 1.2: Standardize Section Heights

**Files:** All `*PopoverView.swift` files

**Standard Heights:**
- Dashboard: 90px (fixed)
- Chart: 120px + 2px separator
- Details: 16px × number of fields + 2px separator
- Process header: 22px
- Process row: 22px × n

**Example Application (CPUPopoverView.swift):**
```swift
// Line 169: Already has correct height
.frame(height: 90) // Stats Master parity: 90px dashboard height

// Add to history chart section
.frame(height: 120) // Standard chart height
```

---

#### Task 1.3: Create MemoryPopoverView.swift

**File:** `Tonic/Tonic/MenuBarWidgets/Popovers/MemoryPopoverView.swift` (NEW)

**Template:** Use CPUPopoverView.swift as reference

**Required Sections:**
1. Dashboard (90px) - with pressure gauge
2. Chart (70px) - line chart
3. Details (22px × fields) - Used, Wired, Active, Compressed, Free, Total
4. Swap (dynamic) - Swap used, Swap size
5. Processes (22px × n) - Top processes

**Component Dependencies:**
- PressureGaugeView (create in Task 1.4)
- NetworkSparklineChart (existing)

---

#### Task 1.4: Create PressureGaugeView.swift

**File:** `Tonic/Tonic/MenuBarWidgets/Components/PressureGaugeView.swift` (NEW)

**Specifications:**
- Size: 80x80px
- Three-segment arc:
  - Green: 0-50% (normal pressure)
  - Yellow: 50-80% (warning pressure)
  - Red: 80-100% (critical pressure)
- Needle rotation based on pressure level
- Center text: Pressure level or percentage

**Implementation Outline:**
```swift
struct PressureGaugeView: View {
    let pressureLevel: MemoryPressureLevel
    let pressurePercentage: Double // 0-100
    let size: CGSize

    var body: some View {
        ZStack {
            // Background arcs (3 segments)
            // Green arc (0-180°)
            // Yellow arc (180-270°)
            // Red arc (270-360°)

            // Needle (rotated based on percentage)

            // Center text
        }
        .frame(width: size.width, height: size.height)
    }
}
```

---

### Phase 2: CPU Popover Enhancement (Tasks 5-8)

**Duration:** 2-3 days
**Priority:** HIGH

#### Task 2.1: Add Missing CPU Fields

**File:** `Tonic/Tonic/MenuBarWidgets/Popovers/CPUPopoverView.swift`

**Missing Fields:**
1. Scheduler limit (`cpuData.schedulerLimit`)
2. Speed limit (`cpuData.speedLimit`)
3. Uptime display (formatted uptime string)

**Implementation Location:** Add to `detailsSection` (after line 213)

```swift
// Add after existing detailDot calls
if let schedulerLimit = dataManager.cpuData.schedulerLimit {
    detailDot("Scheduler Limit", value: schedulerLimit, color: .orange)
}
if let speedLimit = dataManager.cpuData.speedLimit {
    detailDot("Speed Limit", value: speedLimit, color: .red)
}
uptimeRow  // New function
```

**Data Layer Update Required:**
Add `schedulerLimit`, `speedLimit`, `uptime` to `WidgetDataManager.cpuData`

---

#### Task 2.2: Create Combined Line + Bar Chart

**File:** Create `Tonic/Tonic/MenuBarWidgets/Components/CombinedCPUChartView.swift` (NEW)

**Specifications:**
- Top section: Line chart (180 points history)
- Bottom section: Per-core bar chart
- Total height: 120px
- Colors match per-core E/P colors

---

#### Task 2.3: Standardize Per-Core Colors

**File:** `Tonic/Tonic/MenuBarWidgets/Popovers/CPUPopoverView.swift`

**Current:** Uses `CoreClusterBarView` colors
**Required:** Ensure consistency across:
- Dashboard gauges
- Per-core section
- Combined chart (if implemented)

**Reference Colors (from CoreClusterBarView):**
```swift
var eCoreColor: Color { Color(red: 0.4, green: 0.6, blue: 0.8) }  // Light blue
var pCoreColor: Color { Color(red: 0.2, green: 0.4, blue: 0.8) }  // Dark blue
```

---

#### Task 2.4: Increase Chart History to 180 Points

**Files:** Multiple

**Current:** 60-120 points (varies by widget)
**Target:** 180 points (Stats Master standard)

**Files to Update:**
1. `WidgetDataManager.swift` - Increase history array sizes
2. All chart components - Update `maxPoints` constants

**Example (NetworkPopoverView.swift, line 475):**
```swift
// Current:
let maxPoints = 180

// Already correct - verify others match
```

---

### Phase 3: Memory Popover Enhancement (Tasks 9-11)

**Duration:** 1-2 days
**Priority:** HIGH

#### Task 3.1: Integrate Pressure Gauge

**File:** `Tonic/Tonic/MenuBarWidgets/Popovers/MemoryPopoverView.swift`

**Location:** Dashboard section (line ~139)

```swift
PressureGaugeView(
    pressureLevel: dataManager.memoryData.pressureLevel,
    pressurePercentage: dataManager.memoryData.pressurePercentage,
    size: CGSize(width: 80, height: 80)
)
```

---

#### Task 3.2: Add Swap Section

**File:** `Tonic/Tonic/MenuBarWidgets/Popovers/MemoryPopoverView.swift`

**Required Fields:**
- Swap used (formatted bytes)
- Swap size (formatted bytes)

**Data Layer Update Required:**
Add `swapUsed`, `swapSize` to `WidgetDataManager.memoryData`

---

#### Task 3.3: Add Missing Memory Fields

**File:** `Tonic/Tonic/MenuBarWidgets/Popovers/MemoryPopoverView.swift`

**Fields to Add:**
- Active memory
- Compressed memory
- Free memory

**Current:** Only shows Used, Wired
**Target:** Used, Wired, Active, Compressed, Free, Total (6 fields)

---

### Phase 4: GPU Popover Enhancement (Tasks 12-15)

**Duration:** 3-4 days
**Priority:** MEDIUM

#### Task 4.1: Create PerGpuContainer Component

**File:** `Tonic/Tonic/MenuBarWidgets/Components/PerGpuContainer.swift` (NEW)

**Specifications:**
- Title bar (24px): Model name, Status indicator (6x6), "DETAILS" button
- Circles Row (50px): 4 gauges horizontal
- Charts Row (60px): 4 line charts horizontal
- Details Panel: Expandable NSGridView

---

#### Task 4.2: Create 4-Gauge Dashboard

**File:** `PerGpuContainer.swift`

**Gauges Required:**
1. Temperature - `HalfCircleGaugeView` (existing)
2. Utilization - `HalfCircleGaugeView`
3. Render utilization - `HalfCircleGaugeView`
4. Tiler utilization - `HalfCircleGaugeView`

**Each:** 50x50px, `edgeInsets(10,10,0,10)`

---

#### Task 4.3: Create 4 Separate Line Charts

**File:** `PerGpuContainer.swift`

**Chart Specifications:**
- 120 points history per metric
- 100x60px each
- Margins: (10,10,10,10)

---

#### Task 4.4: Add Expandable Details Panel

**File:** `PerGpuContainer.swift`

**Fields:**
- Vendor, Model, Cores, Status, Fan speed
- Core clock, Memory clock
- Temperature, Utilization, Render, Tiler

**Interaction:**
- "DETAILS" button toggles visibility
- Animate height change

---

### Phase 5: Disk Popover Enhancement (Tasks 16-19)

**Duration:** 2-3 days
**Priority:** MEDIUM

#### Task 5.1: Create PerDiskContainer Component

**File:** `Tonic/Tonic/MenuBarWidgets/Components/PerDiskContainer.swift` (NEW)

**Structure:**
- Title bar: Disk name + used percentage
- Chart: Dual-line LineChartView
- Details: Expandable grid

---

#### Task 5.2: Add Dual-Line Charts

**File:** `PerDiskContainer.swift`

**Lines:**
- Read: Blue line
- Write: Red line
- 180 points history

---

#### Task 5.3: Add Top Processes Section

**File:** `Tonic/Tonic/MenuBarWidgets/Popovers/DiskPopoverView.swift`

**Required:**
- Process list with disk I/O
- Configurable count (default 8)
- Columns: Name, Read, Write

---

#### Task 5.4: Add I/O Statistics Fields

**File:** `Tonic/Tonic/MenuBarWidgets/Popovers/DiskPopoverView.swift`

**Fields:**
- Operation reads
- Operation writes
- Read bytes (total)
- Write bytes (total)
- Read time
- Write time

---

### Phase 6: Battery Popover Enhancement (Tasks 20-22)

**Duration:** 1-2 days
**Priority:** MEDIUM

#### Task 6.1: Add Electrical Measurement Fields

**File:** `Tonic/Tonic/MenuBarWidgets/Popovers/BatteryPopoverView.swift`

**Fields to Add:**
- Amperage (current draw in mA)
- Voltage (V)
- Battery power (calculated: voltage × amperage/1000 = W)

---

#### Task 6.2: Add Capacity Breakdown

**File:** `Tonic/Tonic/MenuBarWidgets/Popovers/BatteryPopoverView.swift`

**Format:** "current / maximum / designed mAh"

**Example:** "4500 / 5000 / 5400 mAh"

---

#### Task 6.3: Add Time Format Preference

**File:** `Tonic/Tonic/Models/WidgetConfiguration.swift`

**Add to `BatteryModuleSettings`:**
```swift
public struct BatteryModuleSettings: Codable, Sendable, Equatable {
    public var showOptimizedCharging: Bool
    public var showCycleCount: Bool
    public var timeFormat: TimeFormat  // NEW

    // ...
}

public enum TimeFormat: String, CaseIterable, Codable {
    case short = "short"    // "2h 30m"
    case long = "long"      // "2 hours 30 minutes"
}
```

---

### Phase 7: Sensors Popover Enhancement (Tasks 23-26)

**Duration:** 5-7 days
**Priority:** HIGH (Major feature gap)

#### Task 7.1: Create FanControlView Component

**File:** `Tonic/Tonic/MenuBarWidgets/Components/FanControlView.swift` (NEW)

**Estimated Lines:** ~450

**Features:**
- Per-fan speed sliders
- Manual/Auto/Sys control modes
- Min/Max speed indicators
- Current speed display
- Fan speed curve editor (optional)

---

#### Task 7.2: Add Fan Control Modes

**File:** `Tonic/Tonic/Models/WidgetConfiguration.swift`

**Add to `SensorsModuleSettings`:**
```swift
public struct SensorsModuleSettings: Codable, Sendable, Equatable {
    public var showFanSpeeds: Bool
    public var fanControlMode: FanControlMode  // NEW
    public var saveFanSpeed: Bool              // NEW
    public var syncFanControl: Bool            // NEW

    // ...
}

public enum FanControlMode: String, CaseIterable, Codable {
    case auto = "auto"
    case manual = "manual"
    case system = "system"
}
```

---

#### Task 7.3: Add Per-Fan Speed Sliders

**File:** `FanControlView.swift`

**UI Requirements:**
- Slider for each fan
- Min/Max labels
- Current value display
- Real-time SMC updates

**SMC Integration:**
Requires privileged helper for write operations

---

#### Task 7.4: Add Min/Max Indicators

**File:** `FanControlView.swift`

**Display:**
- Min speed label (left)
- Max speed label (right)
- Visual indicator of current position

---

### Phase 8: Network/Bluetooth Polish (Tasks 27-29)

**Duration:** 1 day
**Priority:** LOW

#### Task 8.1: Add DNS Servers Field

**File:** `Tonic/Tonic/MenuBarWidgets/Popovers/NetworkPopoverView.swift`

**Location:** Interface section

**Implementation:**
```swift
@State private var showDNSServers: Bool = false

// In interfaceSection
if showDNSServers {
    detailRow(title: "DNS Servers:", value: dnsServers, color: textColor)
}

// Toggle button in header
headerWithToggle("Interface", isExpanded: $showDNSServers)
```

---

#### Task 8.2: Add Extended WiFi Tooltip

**File:** `Tonic/Tonic/MenuBarWidgets/Popovers/NetworkPopoverView.swift`

**Tooltip Content:**
- RSSI (signal strength)
- Noise level
- Channel number
- Band (2.4/5 GHz)
- Channel width (20/40/80 MHz)

---

#### Task 8.3: Support Multiple Battery Levels

**File:** `Tonic/Tonic/MenuBarWidgets/Popovers/BluetoothPopoverView.swift`

**Data Model Update:**
```swift
struct BluetoothDevice {
    var batteryLevels: [KeyValue_t]  // Array of (type, percentage)
    // Example: [("Case", 100), ("Left", 85), ("Right", 82)]
}
```

---

### Phase 9: Bug Fixes & Final Polish (Tasks 30-31)

**Duration:** 1 day
**Priority:** MEDIUM

#### Task 9.1: Apply Menu Bar Refresh Bug Fix

**File:** `Tonic/Tonic/MenuBarWidgets/WidgetStatusItem.swift`

**Location:** `updateConfiguration` method (~line 100+)

**Fix:**
```swift
public func updateConfiguration(_ newConfig: WidgetConfiguration) {
    configuration = newConfig
    objectWillChange.send()

    // Force immediate NSView refresh
    DispatchQueue.main.async {
        if let statusItem = self.statusItem {
            let button = statusItem.button
            button?.window?.contentView?.setNeedsDisplay(button?.bounds ?? .zero)
            self.updateCompactView()  // Recreate view
        }
    }
}
```

---

#### Task 9.2: Final Testing and Verification

**Verification Checklist:**

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

## Files to Create

| File | Purpose | Est. Lines |
|------|---------|------------|
| `Components/PressureGaugeView.swift` | 3-color arc pressure gauge | 150 |
| `Components/FanControlView.swift` | Fan control UI with sliders | 450 |
| `Components/PerGpuContainer.swift` | Per-GPU container with gauges/charts | 300 |
| `Components/PerDiskContainer.swift` | Per-disk container with dual-line chart | 200 |
| `Components/CombinedCPUChartView.swift` | Line + bar chart combination | 150 |
| `Popovers/MemoryPopoverView.swift` | Memory popover with pressure gauge | 300 |

**Total New Lines:** ~1,550

---

## Files to Modify

| File | Changes | Est. Lines Changed |
|------|---------|-------------------|
| `Popovers/PopoverConstants.swift` | Add Stats Master constants | +50 |
| `Popovers/CPUPopoverView.swift` | Add fields, combined chart | +80 |
| `Popovers/GPUPopoverView.swift` | Per-GPU architecture | +200 |
| `Popovers/DiskPopoverView.swift` | Dual-line charts, processes | +150 |
| `Popovers/NetworkPopoverView.swift` | DNS, WiFi tooltip | +40 |
| `Popovers/BatteryPopoverView.swift` | Electrical measurements | +60 |
| `Popovers/SensorsPopoverView.swift` | Fan control integration | +100 |
| `Popovers/BluetoothPopoverView.swift` | Multi-battery support | +50 |
| `WidgetStatusItem.swift` | Menu bar refresh fix | +10 |
| `WidgetConfiguration.swift` | Module settings updates | +100 |
| `WidgetDataManager.swift` | New data properties | +150 |

**Total Modified Lines:** ~990

---

## Data Layer Updates Required

### WidgetDataManager Additions

```swift
// CPU Data
var schedulerLimit: Double?
var speedLimit: Double?
var uptime: TimeInterval?

// Memory Data
var pressureLevel: MemoryPressureLevel
var pressurePercentage: Double
var swapUsed: UInt64
var swapSize: UInt64
var activeMemory: UInt64
var compressedMemory: UInt64
var freeMemory: UInt64

// GPU Data
var renderUtilization: Double?
var tilerUtilization: Double?
var coreClock: Double?
var memoryClock: Double?
var fanSpeed: Int?
var vendor: String?
var cores: Int?

// Disk Data
var operationReads: UInt64
var operationWrites: UInt64
var readTime: TimeInterval
var writeTime: TimeInterval

// Battery Data
var amperage: Double?
var voltage: Double?
var batteryPower: Double?  // Calculated
var designedCapacity: UInt64
var chargingCurrent: Double?
var chargingVoltage: Double?

// Bluetooth Data
var batteryLevels: [KeyValue_t]  // Per device
```

---

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Fan control requires elevated privileges | HIGH | HIGH | Use existing TonicHelperTool, add SMC write commands |
| Memory popover file doesn't exist | HIGH | MEDIUM | Create from scratch using CPUPopoverView template |
| GPU per-GPU data not available on all Macs | MEDIUM | LOW | Graceful degradation to single GPU view |
| Chart history increase may affect performance | LOW | LOW | Profile and optimize if needed |
| DNS server enumeration may fail on some networks | LOW | LOW | Handle gracefully with "Unknown" fallback |

---

## Dependencies

**Internal:**
- `DesignTokens.swift` - For base spacing/colors
- `PopoverTemplate.swift` - For reusable components
- `WidgetDataManager.swift` - For data source
- `TonicHelperTool` - For fan control write operations

**External:**
- macOS 14.0+ (Sonoma)
- IOKit framework (for SMC access)
- AppKit framework (for NSStatusItem)

---

## Success Criteria

1. **Visual Parity:** All popovers match Stats Master layout within 5% tolerance
2. **Feature Parity:** All Stats Master fields present in Tonic popovers
3. **Data Accuracy:** All new data fields correctly sourced from system APIs
4. **Performance:** Chart history increase (180 points) doesn't impact frame rate
5. **Stability:** Fan control doesn't cause system instability

---

## Rollout Plan

### Phase 1: Foundation (Week 1)
- Update PopoverConstants
- Create PressureGaugeView
- Create MemoryPopoverView

### Phase 2: Core Popovers (Weeks 2-3)
- CPU popover enhancements
- Memory popover integration
- Network popover polish

### Phase 3: Advanced Features (Weeks 4-6)
- GPU per-GPU architecture
- Disk popover enhancements
- Battery electrical measurements

### Phase 4: Fan Control (Weeks 7-8)
- FanControlView component
- SMC integration
- Settings UI

### Phase 5: Final Polish (Week 9)
- Menu bar refresh fix
- Multi-battery Bluetooth support
- Testing and verification

---

## Open Questions

1. **Fan Control Permission Model:** Should fan control require explicit user acknowledgment of risks?
2. **Chart History Migration:** How to handle existing user data when increasing from 60-120 to 180 points?
3. **Memory Pressure Calculation:** Use `DISPATCH_MEMORYPRESSURE_*` or custom logic?
4. **GPU Multi-GPU Support:** How to test without multi-GPU hardware?

---

## References

- Stats Master source: `../stats-master/Modules/*/popup.swift`
- Spec document: `.flow/specs/fn-7-stats-master-popover-parity.md`
- Design tokens: `Tonic/Tonic/Design/DesignTokens.swift`
- Popover templates: `Tonic/Tonic/MenuBarWidgets/Popovers/PopoverTemplate.swift`
