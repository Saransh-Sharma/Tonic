# Technical Audit Report: Tonic Menu Bar Widgets vs. Stats Master Parity

**Audit Date**: 2026-02-02
**Auditor**: Claude + User Deep Technical Audit
**Epic**: fn-6-i4g - Stats Master Menu Bar Parity
**Current Parity**: ~60-65%
**Target Parity**: 100%

---

## Executive Summary

Tonic has a modern SwiftUI-based architecture with solid foundations, but significant gaps exist in:
1. **Configuration Refresh Bug** - Changes don't propagate to active widgets immediately
2. **Popover UI Depth** - Missing dashboard gauges, detail sections, custom window behavior
3. **Data Granularity** - No System/User/Idle split, no E/P core clustering
4. **Settings Experience** - Sheet modal vs tabbed interface, missing global settings
5. **Refresh Interval Logic** - Need to adopt Stats Master's per-module refresh pattern

**Critical Decision Points**:
- ✅ **Keep Tonic's**: Single timer optimization, SwiftUI architecture, advanced chart config
- ❌ **Replace with Stats Master's**: PopupWindow behavior, per-module settings UI, refresh interval logic
- ⚖️ **Hybrid**: Configuration storage (merge both approaches)

---

## Part 1: Critical Bug - Configuration Refresh Mechanism (DETAILED)

### Bug Location & Current Implementation

**Tonic/Views/WidgetCustomizationView.swift:107-123**:
```swift
Button(action: {
    withAnimation(DesignTokens.Animation.fast) {
        WidgetCoordinator.shared.refreshWidgets()  // Manual trigger only
    }
}) {
    Label("Apply", systemImage: "checkmark")
}
```

**Tonic/Models/WidgetConfiguration.swift:781-786**:
```swift
public func updateConfig(for type: WidgetType, _ update: (inout WidgetConfiguration) -> Void) {
    if let index = widgetConfigs.firstIndex(where: { $0.type == type }) {
        update(&widgetConfigs[index])
        saveConfigs()
        // ❌ Missing: No notification to WidgetCoordinator
    }
}
```

### Stats Master Reactive Pattern (Reference)

**stats-master/Kit/widget.swift:422-444**:
```swift
widget.toggleCallback = { [weak self] (type, state) in
    if let s = self, s.oneView {
        // Immediate recalculation and view update
        DispatchQueue.main.async(execute: {
            s.recalculateWidth()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                s.view.addWidget(w.item)
                s.view.recalculate(s.sortedWidgets)
            }
        })
    } else {
        widget.setMenuBarItem(state: state)  // ← Immediate!
    }
}
```

### Required Fix for Tonic

**Step 1: Make WidgetConfiguration.updateConfig() Reactive**
```swift
// File: Tonic/Tonic/Models/WidgetConfiguration.swift

public func updateConfig(for type: WidgetType, _ update: (inout WidgetConfiguration) -> Void) {
    if let index = widgetConfigs.firstIndex(where: { $0.type == type }) {
        update(&widgetConfigs[index])
        saveConfigs()

        // NEW: Notify WidgetCoordinator immediately
        Task { @MainActor in
            let newConfig = widgetConfigs[index]
            WidgetCoordinator.shared.updateWidget(type: type, configuration: newConfig)
        }
    }
}

// Ensure all setters call updateConfig:
public func setWidgetColor(for type: WidgetType, color: WidgetAccentColor) {
    updateConfig(for: type) { config in
        config.accentColor = color
    }
}
```

**Step 2: Remove/Make Optional "Apply" Button**
Changes should be immediate. Apply button becomes redundant or becomes a "Reset to Defaults" option.

---

## Part 2: Popover Window Behavior - CRITICAL GAP

### Stats Master PopupWindow Implementation

**stats-master/Kit/module/popup.swift**:
- **NSPopupWindow** (NSWindow subclass)
- Custom transparency, shadow, positioning
- Drag detection and window locking (lines 89-92)
- Close button state change (Activity Monitor → Close on drag)

### Tonic Current Implementation

**Tonic/MenuBarWidgets/Popovers/PopoverTemplate.swift**:
- Uses NSPopover (not custom window)
- Fixed dimensions: 280x500
- No drag behavior
- No window locking

### Required Fix: Custom PopupWindow

**New File**: `Tonic/MenuBarWidgets/PopupWindow.swift`
```swift
class PopupWindow: NSWindow {
    var isDragging = false
    var closeOnDragEnd = false

    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStore: NSWindow.BackingStoreType, defer defer: Bool) {
        super.init(contentRect: contentRect, styleMask: styleMask, backing: backingStore, defer: defer)
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
    }

    // Implement drag behavior
    override var canBecomeKeyWindow: Bool { true }
    override var canBecomeMainWindow: Bool { false }

    // Close button state change logic
}
```

---

## Part 3: Popover Content Structure - COMPLETE REDESIGN NEEDED

### Stats Master CPU Popup Structure (Reference)

```
┌─────────────────────────────────────────────────────────────────────┐
│ HeaderView: [Chart] [Activity Monitor → Close] CPU    [Settings]   │
├─────────────────────────────────────────────────────────────────────┤
│ DASHBOARD SECTION (90px)                                              │
│ ┌─────────────────────────────────────────────────────────────────┐ │
│ │  ┌────────┐  ┌────────┐  ┌────────┐                           │ │
│ │  │ Pie    │  │ Temp   │  │ Freq   │                           │ │
│ │  │ Chart  │  │ Gauge  │  │ Gauge  │                           │ │
│ │  │ 68%    │  │ 45°C   │  │ 3.2GHz │                           │ │
│ │  └────────┘  └────────┘  └────────┘                           │ │
│ └─────────────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────────────┤
│ USAGE HISTORY (Line Chart - 70px)                                   │
│ Configurable: scale (none/linear/square/cube/log/fixed), points (60-180)│
├─────────────────────────────────────────────────────────────────────┤
│ PER-CORE BARS (50px) - Color-coded by E/P cores                    │
├─────────────────────────────────────────────────────────────────────┤
│ DETAILS SECTION                                                       │
│ ● System: 45% (red dot)   ● User: 32% (blue dot)  ● Idle: 23%     │
│ Efficiency cores: 15%     Performance cores: 67%                      │
├─────────────────────────────────────────────────────────────────────┤
│ AVERAGE LOAD                                                          │
│ 1 minute: 2.45    5 minutes: 2.12    15 minutes: 1.87               │
├─────────────────────────────────────────────────────────────────────┤
│ TOP PROCESSES (Configurable 0-15)                                   │
│ Chrome 45%    Xcode 23%    Safari 12%                               │
└─────────────────────────────────────────────────────────────────────┘
```

### Tonic Current Popover - Missing All Above Sections

Tonic uses generic `PopoverTemplate` which provides:
- Header with icon + title + value + gear
- Single content section
- No dashboard, no details section, no load average

### Critical Parity Gaps Table

| Feature | Stats Master | Tonic | File to Create/Modify |
|---------|--------------|-------|----------------------|
| **Window** | NSPopupWindow | NSPopover | `PopupWindow.swift` (NEW) |
| **Drag Behavior** | ✅ Lock on drag | ❌ None | `PopupWindow.swift` |
| **Header** | Activity Monitor + Settings | Gear only | `HeaderView.swift` (NEW) |
| **Dashboard** | ✅ 3 gauges (90px) | ❌ Missing | `CPUPopoverView.swift` |
| **History Chart** | ✅ Configurable | ⚠️ Fixed | Modify existing chart |
| **E/P Core Bars** | ✅ Color-coded | ❌ Flat list | `CoreClusterBarView.swift` |
| **Details Section** | ✅ Color-coded rows | ❌ Missing | `CPUPopoverView.swift` |
| **Load Average** | ✅ 1/5/15 min | ❌ Missing | Add to data collection |
| **Top Processes** | ✅ 0-15 configurable | ⚠️ Fixed 5 | Make configurable |
| **Dynamic Height** | ✅ Auto-resize | ❌ Fixed 500px | `PopupWindow.swift` |

---

## Part 4: Configuration UI - COMPLETE REPLACEMENT NEEDED

### Stats Master Settings UI (Reference)

**stats-master/Stats/Views/Settings.swift**:
- Window size: 720x480px
- Layout: Split view with 180px sidebar + 540px main content
- Modules in sidebar: CPU, GPU, Memory, Disk, Network, Battery, Sensors, Bluetooth, Clock
- Per-module tabs: Module / Widgets / Popup / Notifications

### Stats Master Per-Module Settings Example (CPU)

```
┌─────────────────────────────────────────────────────────────────────┐
│ Settings                                   CPU │ GPU │ Memory... │
├──────────────┬────────────────────────────────────────────────────────┤
│ Module        │ Show CPU widget in menu bar                           │
│               │ Show load average                                     │
│               │ Show uptime                                            │
│               │ Show processes                                        │
├──────────────┼────────────────────────────────────────────────────────┤
│ Widgets       │ Visualization: Mini │ Pie │ Line │ Bar │ Tachometer     │
│               │ Update interval: 1s │ 2s │ 5s │ Never                │
│               │ Color: [Color picker]                                 │
├──────────────┼────────────────────────────────────────────────────────┤
│ Popup         │ Show temperature                                     │
│               │ Show frequency                                       │
│               │ Show pie chart                                        │
│               │ Show history chart                                     │
├──────────────┼────────────────────────────────────────────────────────┤
│ Notifications │ CPU usage alert:                                     │
│               │ When above: [80]%                                    │
│               │ Actions: [x] Notify [x] Play sound                    │
└──────────────┴────────────────────────────────────────────────────────┘
```

### Tonic Current Settings UI

**Tonic/Views/WidgetCustomizationView.swift**:
- Integrated in main app (not separate window)
- Single-page layout
- Sheet modal for per-widget settings
- No per-module organization

### Required Changes

1. **Replace with Stats Master's tabbed per-module settings**
2. **Adopt Stats Master's refresh interval options per module**
3. **Keep Tonic's chart config where superior** (history, scale options)
4. **Add temperature unit toggle (°C/°F)**

---

## Part 5: Refresh Interval Logic - ADOPT STATS MASTER PATTERN

### Stats Master Refresh Pattern

**stats-master/Kit/module/Module.swift**:
```swift
open class Module {
    public var updateInterval: Int = 1  // Per-module!
    private var readers: [Reader_p] = []

    func enable() {
        readers.forEach { $0.start() }  // Each reader has own timer
    }

    func setInterval(_ interval: Int) {
        self.updateInterval = interval
        readers.forEach { $0.setInterval(interval) }
    }
}
```

**stats-master/Kit/plugins/Repeater.swift**:
```swift
class Repeater {
    private var timer: DispatchSourceTimer
    private let interval: Int

    init(seconds: Int, callback: @escaping () -> Void) {
        self.interval = seconds
        self.setupTimer(callback)
    }

    private func setupTimer(_ callback: @escaping () -> Void) {
        self.timer = DispatchSource.makeTimerSource(...)
        self.timer.schedule(deadline: .now(), repeating: .seconds(interval))
        self.timer.resume()
    }
}
```

### Tonic Current Pattern (To Keep for Optimization)

**Tonic/Services/WidgetDataManager.swift**:
```swift
private var refreshTimer: DispatchSourceTimer?

func startMonitoring() {
    self.refreshTimer = DispatchSource.makeTimerSource(...)
    self.refreshTimer.schedule(deadline: .now(), repeating: .seconds(2.0))  // Single unified timer!
    self.refreshTimer.resume()
}
```

**Decision**: **KEEP TONIC'S SINGLE TIMER** - It's 6x more efficient!
- Stats Master: 7 modules × 1 timer each = 7 timers
- Tonic: 1 unified timer for all modules
- **However**: Add per-module configurable intervals via conditional updates

### Hybrid Solution

```swift
// Keep single timer, but update modules based on their interval
func updateAllData() {
    let now = Date()

    // CPU updates every 1s
    if shouldUpdate(.cpu, since: cpuLastUpdate, interval: cpuUpdateInterval) {
        updateCPUData()
        cpuLastUpdate = now
    }

    // Disk updates every 5s
    if shouldUpdate(.disk, since: diskLastUpdate, interval: diskUpdateInterval) {
        updateDiskData()
        diskLastUpdate = now
    }
    // ... etc
}
```

---

## Part 6: Per-Widget Configuration - ADOPT STATS MASTER OPTIONS

### Stats Master CPU Module Settings

| Setting | Stats Master | Tonic | Action |
|---------|--------------|-------|--------|
| **Widget** | Show in menu bar (toggle) | ✅ | Keep |
| **Update** | 1s, 2s, 5s, Never | 1s, 2s, 3s, 5s, Never | **Adopt Stats options** |
| **Visualization** | Mini, Pie, Line, Bar, Tachometer | Same | Keep both |
| **Color** | ~15 colors | 30+ colors | **Keep Tonic (superior)** |
| **Popup Settings** | Show temp, Show freq, Show pie, Show history | Missing | **Add all** |
| **Notification** | Threshold, Sound, Notify | Threshold | **Add sound option** |

### Required Configuration Changes

**Replace Tonic's WidgetUpdateInterval** with Stats Master's options:
```swift
// Remove Tonic's enum
enum WidgetUpdateInterval { case performance, balanced, power }

// Adopt Stats Master's direct seconds
// 1s, 2s, 5s options (matching Stats Master exactly)
```

---

## Part 7: All New Files Required

### New Popover Files
```
Tonic/Tonic/MenuBarWidgets/Popovers/
├── PopupWindow.swift              # NEW - NSWindow subclass with drag behavior
├── HeaderView.swift               # NEW - Activity Monitor + Settings button
├── CPUPopoverView.swift          # NEW - Full CPU popup matching Stats
├── MemoryPopoverView.swift       # NEW
├── NetworkPopoverView.swift      # NEW
├── DiskPopoverView.swift         # NEW
├── BatteryPopoverView.swift      # NEW
├── SensorsPopoverView.swift      # NEW
├── BluetoothPopoverView.swift    # NEW
└── ProcessesView.swift           # NEW - Configurable top processes
```

### New Settings Files
```
Tonic/Tonic/Views/Settings/
├── SettingsWindow.swift           # NEW - Main settings window (720x480)
├── SettingsSidebar.swift          # NEW - Module list sidebar
├── ModuleSettingsView.swift       # NEW - Per-module settings container
└── ModuleSettings/
    ├── CPUModuleSettings.swift    # NEW - CPU-specific settings
    ├── MemoryModuleSettings.swift # NEW
    ├── DiskModuleSettings.swift   # NEW
    └── ...
```

### New Component Files
```
Tonic/Tonic/Components/   # NEW DIRECTORY
├── CircularGaugeView.swift       # Full pie chart (System/User/Idle)
├── HalfCircleGaugeView.swift    # Semi-circle gauge (Temp/Freq)
├── CoreClusterBarView.swift      # E/P core grouped bars
├── ConfigurableLineChart.swift   # Line chart with scale options
└── DetailRowView.swift           # Color-coded detail row
```
    UserDefaults.standard.set(try? encoder.encode(configs), forKey: "widgetConfigs")
    // MISSING: No notification posted!
}

// Tonic/MenuBarWidgets/WidgetCoordinator.swift
// No observer for configuration changes
// Widgets never know they need to refresh
```

### The Fix

**Step 1: Add Notification to WidgetStore**
```swift
// File: Tonic/Tonic/Services/WidgetStore.swift

extension Notification.Name {
    static let widgetConfigurationDidUpdate = Notification.Name("tonic.widgetConfigurationDidUpdate")
}

func saveConfig(_ config: WidgetConfiguration) {
    // ... existing save logic ...

    // Broadcast change
    NotificationCenter.default.post(
        name: .widgetConfigurationDidUpdate,
        object: nil,
        userInfo: ["widgetType": config.type]
    )
}
```

**Step 2: Add Observer in WidgetCoordinator**
```swift
// File: Tonic/MenuBarWidgets/WidgetCoordinator.swift

private func setupConfigurationObserver() {
    NotificationCenter.default.addObserver(
        forName: .widgetConfigurationDidUpdate,
        object: nil,
        queue: .main
    ) { [weak self] notification in
        self?.handleConfigurationChange(notification)
    }
}

private func handleConfigurationChange(_ notification: Notification) {
    guard let widgetType = notification.userInfo?["widgetType"] as? WidgetType else { return }

    if WidgetPreferences.shared.unifiedMenuBarMode {
        oneViewStatusItem?.refreshWidgetList()
    } else if let widget = activeWidgets[widgetType] {
        widget.refreshView()
    }
}
```

---

## Part 2: Popover UI Parity Analysis

### 2.1 Stats Master Popover Structure (Reference)

```
┌─────────────────────────────────────────────────────────────────────┐
│ HeaderView: [Activity] Title [Settings]                             │
├─────────────────────────────────────────────────────────────────────┤
│ DASHBOARD ROW (90px)                                                │
│ ┌─────────────────────┬───────────────────┬─────────────────────┐  │
│ │   Temp Gauge        │   Usage Pie Chart │   Freq Gauge        │  │
│ │   (Half-circle)     │   (Full circle)   │   (Half-circle)     │  │
│ │   45°C              │   68%             │   3.2 GHz           │  │
│ └─────────────────────┴───────────────────┴─────────────────────┘  │
├─────────────────────────────────────────────────────────────────────┤
│ CHART SECTION (120px)                                               │
│ ┌─────────────────────────────────────────────────────────────────┐ │
│ │ Usage History (Line Chart - 70px)                               │ │
│ └─────────────────────────────────────────────────────────────────┘ │
│ ┌─────────────────────────────────────────────────────────────────┐ │
│ │ Per-Core Bars (50px) - Color-coded by E/P cores                │ │
│ └─────────────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────────────┤
│ DETAILS SECTION                                                     │
│ ┌─────────────┬─────────────┬─────────────┐                        │
│ │ System: 25% │ User: 43%   │ Idle: 32%   │                        │
│ │ E-Cores: 8  │ P-Cores: 4  │ Uptime: 3d  │                        │
│ └─────────────┴─────────────┴─────────────┘                        │
├─────────────────────────────────────────────────────────────────────┤
│ LOAD AVERAGE                                                        │
│ ┌─────────────┬─────────────┬─────────────┐                        │
│ │ 1 min: 2.1 │ 5 min: 1.8  │ 15 min: 1.5 │                        │
│ └─────────────┴─────────────┴─────────────┘                        │
├─────────────────────────────────────────────────────────────────────┤
│ TOP PROCESSES (8 items)                                             │
│ ┌─────────────────────────────────────────────────────────────────┐ │
│ │ Safari        ███████░░  45%                                    │ │
│ │ Xcode         ████░░░░░░  28%                                    │ │
│ └─────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

### 2.2 Tonic Current Popover Structure

```
┌─────────────────────────────────────────────────────────────────────┐
│ PopoverTemplate Header: [Icon] Title [Value] [Gear]                │
├─────────────────────────────────────────────────────────────────────┤
│ TOTAL USAGE DISPLAY                                                 │
│ ┌─────────────────────────────────────────────────────────────────┐ │
│ │                     48%                                         │ │
│ │                   12 Cores                                      │ │
│ └─────────────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────────────┤
│ PER-CORE USAGE                                                      │
│ ┌─────────────────────────────────────────────────────────────────┐ │
│ │ Core 1  ████████░░░  75%                                        │ │
│ │ Core 2  ██████░░░░░  60%                                        │ │
│ │ Core 3  ████░░░░░░░  45%                                        │ │
│ │ ... (flat list, no E/P grouping)                                │ │
│ └─────────────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────────────┤
│ USAGE HISTORY (Line Chart)                                          │
│ ┌─────────────────────────────────────────────────────────────────┐ │
│ │ ╱╲╱╲╱╲╱╲╱╲╱╲╱╲╱╲                                           │ │
│ └─────────────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────────────┤
│ TOP APPS (5 items)                                                  │
│ ┌─────────────────────────────────────────────────────────────────┐ │
│ │ Safari        45%                                               │ │
│ │ Xcode         28%                                               │ │
│ └─────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

### 2.3 UI Parity Gaps

| Feature | Stats Master | Tonic | Gap |
|---------|--------------|-------|-----|
| Dashboard Gauges | ✅ Pie + 2 Half-circles | ❌ No gauges | **CRITICAL** |
| System/User/Idle Split | ✅ Color-coded segments | ❌ Total only | **HIGH** |
| E/P Core Grouping | ✅ Visual grouping | ❌ Flat list | **HIGH** |
| Temperature Display | ✅ Gauge + value | ❌ Not in popover | **HIGH** |
| Frequency Display | ✅ Gauge + value | ❌ Not in popover | **HIGH** |
| Load Average | ✅ 1/5/15 min | ❌ Missing | **MEDIUM** |
| Uptime Display | ✅ Text | ❌ Missing | **MEDIUM** |
| Process Count | ✅ Configurable (8) | ⚠️ Fixed (5) | **LOW** |

---

## Part 3: Data Layer Parity Analysis

### 3.1 CPU Data Model Comparison

**Stats Master CPU Data**:
```swift
public struct CPUData {
    // Usage
    let totalUsage: Double
    let systemUsage: Double     // ← Missing in Tonic
    let userUsage: Double       // ← Missing in Tonic
    let idleUsage: Double       // ← Missing in Tonic

    // Topology
    let logicalCores: Int
    let physicalCores: Int
    let eCores: [Double]        // ← Missing in Tonic (grouped)
    let pCores: [Double]        // ← Missing in Tonic (grouped)

    // Telemetry
    let temperature: Double?    // ← Exists but not in popover
    let frequency: Double?      // ← Missing

    // Metadata
    let uptime: TimeInterval   // ← Missing
    let loadAverage: [Double]   // ← Missing [1m, 5m, 15m]
}
```

**Tonic CPU Data** (Current):
```swift
public struct CPUData: Sendable {
    public let totalUsage: Double
    public let perCoreUsage: [Double]  // Flat array
    public let eCoreUsage: [Double]?   // ✅ Exists but not used
    public let pCoreUsage: [Double]?   // ✅ Exists but not used
    public let frequency: Double?      // ⚠️ Exists but not populated
    public let temperature: Double?    // ⚠️ Exists but not in popover
    // ❌ No systemUsage, userUsage, idleUsage
    // ❌ No uptime
    // ❌ No loadAverage
}
```

### 3.2 Data Collection Gaps

| Data Point | Stats Master | Tonic Implementation | Action Required |
|------------|--------------|---------------------|-----------------|
| System/User/Idle | host_cpu_load_info | Same API, not split | Refactor `getCPUUsage()` |
| E/P Cores | sysctl hw.perflevel0/1 | ⚠️ Partial | Complete detection |
| Temperature | SMCReader | ⚠️ Exists | Wire to UI |
| Frequency | sysctl hw.cpufrequency | ⚠️ Partial | Implement fully |
| Uptime | ProcessInfo.systemUptime | ❌ Not exposed | Add to CPUData |
| Load Average | getloadavg() | ❌ Not exposed | Add to CPUData |

---

## Part 4: Settings/Configuration Parity

### 4.1 Stats Master Settings Experience

**Features**:
- ✅ **Tabbed Interface**: 4 tabs (General, Modules, Appearance, Notifications)
- ✅ **Drag-Drop Reordering**: Widgets can be reordered in list
- ✅ **Per-Module Settings**: Each module has custom settings class
  - CPU: "Show Hyperthreading", "Show Temperature", etc.
  - Disk: "Select Volume", "Show SMART Data"
  - Network: "Select Interface", "Show Public IP"
- ✅ **Keyboard Shortcuts**: Customizable per module
- ✅ **Color Import/Export**: Share color schemes

**Settings Storage**:
```swift
// stats-master/Kit/plugins/Store.swift
class Store {
    func set(_ value: Any, forKey key: String)
    func string(_ key: String) -> String?
    func int(_ key: String) -> Int
    // Automatic UserDefaults + notification broadcast
}
```

### 4.2 Tonic Settings Experience (Current)

**Features**:
- ⚠️ **Single List View**: All settings in one long scroll
- ❌ **No Drag-Drop**: Reordering not implemented
- ⚠️ **Generic Configuration**: All widgets use same `WidgetConfiguration`
- ❌ **No Per-Module Settings**: No module-specific options
- ✅ **Good Color System**: 32 colors with auto-modes
- ✅ **Visualization Picker**: With compatibility checking

**Settings Storage**:
```swift
// Tonic/Models/WidgetConfiguration.swift
struct WidgetConfiguration {
    let type: WidgetType
    let visualizationType: VisualizationType
    let displayMode: WidgetDisplayMode
    let accentColor: WidgetAccentColor
    // Generic - no module-specific options
}
```

### 4.3 Settings Parity Gaps

| Feature | Stats Master | Tonic | Priority |
|---------|--------------|-------|----------|
| Tabbed Interface | ✅ | ❌ | **HIGH** |
| Drag-Drop Reorder | ✅ | ❌ | **HIGH** |
| Per-Module Settings | ✅ | ❌ | **MEDIUM** |
| Keyboard Shortcuts | ✅ | ❌ | **LOW** |
| Color Import/Export | ✅ | ❌ | **LOW** |

---

## Part 5: Per-Widget Popover Parity Status

### CPU Widget
| Element | Stats Master | Tonic | Status |
|---------|--------------|-------|--------|
| Total Usage | ✅ | ✅ | Parity |
| System/User/Idle | ✅ Pie segments | ❌ | **Gap** |
| Temperature Gauge | ✅ Half-circle | ❌ | **Gap** |
| Frequency Gauge | ✅ Half-circle | ❌ | **Gap** |
| E/P Core Grouping | ✅ Color-coded bars | ❌ Flat list | **Gap** |
| Load Average | ✅ | ❌ | **Gap** |
| Uptime | ✅ | ❌ | **Gap** |
| History Chart | ✅ | ✅ | Parity |
| Top Processes | ✅ 8 items | ⚠️ 5 items | Partial |
| **Overall Parity** | - | - | **75%** |

### Memory Widget
| Element | Stats Master | Tonic | Status |
|---------|--------------|-------|--------|
| Used/Free Gauge | ✅ | ✅ | Parity |
| Pressure Level | ✅ | ✅ | Parity |
| Swap Display | ✅ | ✅ | Parity |
| Compressed | ✅ | ✅ | Parity |
| Cache | ✅ | ❌ | **Gap** |
| Wired | ✅ | ❌ | **Gap** |
| History Chart | ✅ | ✅ | Parity |
| Top Processes | ✅ | ✅ | Parity |
| **Overall Parity** | - | - | **85%** |

### Network Widget
| Element | Stats Master | Tonic | Status |
|---------|--------------|-------|--------|
| Download/Upload | ✅ | ✅ | Parity |
| Public IP | ✅ | ⚠️ Fetched | Parity |
| Interface Dropdown | ✅ | ❌ | **Gap** |
| WiFi Details | ✅ | ✅ | Parity |
| Connectivity Check | ✅ | ✅ | Parity |
| Top Processes | ✅ | ❌ | **Gap** |
| History Chart | ✅ | ✅ | Parity |
| **Overall Parity** | - | - | **85%** |

### Disk Widget
| Element | Stats Master | Tonic | Status |
|---------|--------------|-------|--------|
| Volume Usage | ✅ | ✅ | Parity |
| Read/Write Speed | ✅ | ✅ | Parity |
| I/O History | ✅ Chart | ⚠️ No chart | **Gap** |
| SMART Status | ✅ | ✅ | Parity |
| Top Processes | ✅ | ❌ | **Gap** |
| **Overall Parity** | - | - | **75%** |

### GPU Widget
| Element | Stats Master | Tonic | Status |
|---------|--------------|-------|--------|
| Usage % | ✅ | ✅ | Parity |
| History Chart | ✅ | ⚠️ No chart | **Gap** |
| Top Processes | ✅ | ❌ | **Gap** |
| E/Core Usage | ✅ | ❌ | **Gap** |
| **Overall Parity** | - | - | **60%** |

### Battery Widget
| Element | Stats Master | Tonic | Status |
|---------|--------------|-------|--------|
| Charge % | ✅ | ✅ | Parity |
| Time Remaining | ✅ | ✅ | Parity |
| Health | ✅ | ✅ | Parity |
| Cycle Count | ✅ | ✅ | Parity |
| Temperature | ✅ | ✅ | Parity |
| Charge History | ✅ Chart | ⚠️ No chart | **Gap** |
| Optimized Charging | ✅ | ⚠️ Not displayed | **Gap** |
| **Overall Parity** | - | - | **85%** |

### Sensors Widget
| Element | Stats Master | Tonic | Status |
|---------|--------------|-------|--------|
| Temperature List | ✅ | ✅ | Parity |
| Fan Speeds | ✅ | ✅ | Parity |
| Sensor History | ✅ Chart | ❌ | **Gap** |
| Fan History | ✅ Chart | ❌ | **Gap** |
| Visual Gauges | ✅ | ❌ | **Gap** |
| **Overall Parity** | - | - | **60%** |

### Bluetooth Widget
| Element | Stats Master | Tonic | Status |
|---------|--------------|-------|--------|
| Device List | ✅ | ✅ | Parity |
| Battery Levels | ✅ | ✅ | Parity |
| Connection Status | ✅ | ✅ | Parity |
| Connection History | ✅ | ❌ | **Gap** |
| Signal Strength | ✅ | ❌ | **Gap** |
| **Overall Parity** | - | - | **80%** |

---

## Part 6: Architecture Comparison

### 6.1 Data Flow

**Stats Master**:
```
[Reader] → [Module] → [Callback] → [Widget] → [NSStatusItem]
    ↓                                              ↓
[UserDefaults] ← [Settings UI]                   [Popover]
```

**Tonic**:
```
[WidgetDataManager @Observable] → [Published Properties] → [SwiftUI Views]
                                     ↓
                              [WidgetStatusItem] → [NSStatusItem]
                                     ↓
                                  [Popover]
```

**Analysis**: Tonic's reactive SwiftUI approach is **more modern** and cleaner. Stats Master's callback pattern is older but works.

### 6.2 Widget Lifecycle

| Phase | Stats Master | Tonic |
|-------|--------------|-------|
| Creation | Module.initWidgets() | WidgetFactory.createWidget() |
| Updates | Reader callback → Widget.update() | @Published → SwiftUI auto-update |
| Destruction | Module.terminate() | WidgetStatusItem.deinit |
| **Winner** | Manual control | **Automatic** ✅ |

---

## Part 7: Execution Plan

### Phase 1: Critical Fixes (Week 1)
**Task fn-6-i4g.28**: Fix Configuration Refresh Bug
- Add notification to `WidgetStore.saveConfig()`
- Add observer in `WidgetCoordinator`
- Test: Change widget color → verify immediate update

**Task fn-6-i4g.29**: CPU Data Layer Enhancement
- Split CPU usage into System/User/Idle
- Add uptime and load average to CPUData
- Implement E/P core detection and grouping
- Wire temperature/frequency to UI

### Phase 2: UI Components (Week 2)
**Task fn-6-i4g.30**: Dashboard Gauge Component
- Create `CircularGaugeView` (full pie)
- Create `HalfCircleGaugeView` (semi-circle)
- Support for multiple segments (System/User/Idle)
- Center text and labels

**Task fn-6-i4g.31**: Core Cluster Component
- Create `CoreClusterBarView`
- Group bars by E/P cores
- Color-coded by cluster type
- Animated value transitions

**Task fn-6-i4g.32**: CPU Popover Redesign
- Replace `CPUDetailView` with dashboard layout
- 3-gauge header row
- Grouped core bars
- Details section with System/User/Idle
- Load average display
- Uptime display

### Phase 3: Settings Overhaul (Week 3)
**Task fn-6-i4g.33**: Tabbed Settings Interface
- Create `WidgetSettingsContainerView`
- Implement 4 tabs: General, Widgets, Appearance, Notifications
- Navigation-based layout

**Task fn-6-i4g.34**: Drag-Drop Reordering
- Add `.onMove` support to widget list
- Implement position persistence
- Update WidgetCoordinator to respect order

**Task fn-6-i4g.35**: Per-Module Settings
- Extend `WidgetConfiguration` with `customSettings: [String: Any]`
- Create `CPUSettingsView`, `DiskSettingsView`, etc.
- Module-specific options

### Phase 4: Widget Parity (Week 4-5)
**Task fn-6-i4g.36**: GPU Widget Parity
- Add history chart
- Add top processes list
- Add E/core breakdown

**Task fn-6-i4g.37**: Disk Widget Parity
- Add I/O history chart
- Add top processes list

**Task fn-6-i4g.38**: Battery Widget Parity
- Add charge history chart
- Display optimized charging status

**Task fn-6-i4g.39**: Sensors Widget Parity
- Add sensor history charts
- Add visual gauges
- Add fan history

**Task fn-6-i4g.40**: Bluetooth Widget Parity
- Add connection history
- Add signal strength indicator

### Phase 5: Polish & Testing (Week 6)
**Task fn-6-i4g.41**: Visual Polish
- Match Stats Master spacing, fonts, colors
- Ensure consistent popover widths
- Verify animations

**Task fn-6-i4g.42**: Performance Optimization
- Profile widget refresh cycles
- Optimize history data storage
- Reduce CPU impact

**Task fn-6-i4g.43**: Final Testing & Verification
- Side-by-side comparison with Stats Master
- Test all configuration combinations
- Verify all notification integrations

---

## Summary of New Tasks

| Task ID | Title | Priority | Est. Days |
|---------|-------|----------|-----------|
| fn-6-i4g.28 | Fix Configuration Refresh Bug | CRITICAL | 1 |
| fn-6-i4g.29 | CPU Data Layer Enhancement | HIGH | 2 |
| fn-6-i4g.30 | Dashboard Gauge Component | HIGH | 2 |
| fn-6-i4g.31 | Core Cluster Component | HIGH | 1 |
| fn-6-i4g.32 | CPU Popover Redesign | HIGH | 2 |
| fn-6-i4g.33 | Tabbed Settings Interface | MEDIUM | 2 |
| fn-6-i4g.34 | Drag-Drop Reordering | MEDIUM | 1 |
| fn-6-i4g.35 | Per-Module Settings | MEDIUM | 2 |
| fn-6-i4g.36 | GPU Widget Parity | MEDIUM | 2 |
| fn-6-i4g.37 | Disk Widget Parity | MEDIUM | 1 |
| fn-6-i4g.38 | Battery Widget Parity | MEDIUM | 1 |
| fn-6-i4g.39 | Sensors Widget Parity | MEDIUM | 2 |
| fn-6-i4g.40 | Bluetooth Widget Parity | LOW | 1 |
| fn-6-i4g.41 | Visual Polish | LOW | 2 |
| fn-6-i4g.42 | Performance Optimization | LOW | 2 |
| fn-6-i4g.43 | Final Testing & Verification | LOW | 3 |

**Total Effort**: 27 days (~6 weeks)

---

## Non-Functional Requirements

| Metric | Target | How to Measure |
|--------|--------|----------------|
| Widget Refresh Latency | <500ms | Timestamp delta |
| Memory per Widget | <5MB | Memory profiler |
| CPU Impact (per widget) | <0.5% | Activity Monitor |
| Configuration Apply Time | <1s | Visual verification |
| Popover Open Time | <200ms | Stopwatch |

---

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| CPU data split may affect accuracy | HIGH | Validate against Activity Monitor |
| New components may have bugs | MEDIUM | Unit tests for each component |
| Performance degradation | MEDIUM | Profile before/after each change |
| Breaking existing configs | LOW | Migration layer in place |
