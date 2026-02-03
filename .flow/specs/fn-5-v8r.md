# fn-5-v8r Stats Master–Parity Menu Bar Widgets Dashboard

## Overview

Replicate 100% of Stats Master's widget functionality within Tonic's Menu Bar Widgets Dashboard. The implementation must be functionally indistinguishable from Stats Master ("Stats Master's brain, Tonic's visual language").

**Key insight**: Stats Master has 14 widget types vs Tonic's current 7. Stats Master also provides sophisticated configuration options (color schemes, chart scaling, history buffers, display modes) that do not exist in Tonic today.

## Scope

### In Scope (Feature Parity)

**Widget Types from Stats Master to implement**:

| Stats Master Widget | Description | Tonic Equivalent | Gap |
|---------------------|-------------|------------------|-----|
| Mini | Simple value display with label | Basic widget modes | Color schemes, alignment |
| Line Chart | Real-time graph with history (30-120 points) | None | Full implementation needed |
| Bar Chart | Vertical bar visualization | None | Full implementation needed |
| Pie Chart | Circular progress indicator | None | Full implementation needed |
| Network Chart | Dual-direction I/O visualization | Network widget | Enhanced version needed |
| Speed | Network speed with I/O indicators | Network widget | Display modes needed |
| Battery | Battery level and status | Battery widget | Icon styles needed |
| Battery Details | Extended battery info | None | Full implementation needed |
| Stack (Sensors) | Multiple sensors in one widget | None | Full implementation needed |
| Memory | Memory with pressure zones | Memory widget | Zone indicators needed |
| Label | Custom text display | None | Full implementation needed |
| Tachometer | Circular gauge | None | Full implementation needed |
| State | Status indicator | None | Full implementation needed |
| Text | Dynamic text with templates | None | Full implementation needed |

**Business Logic Replacement**:
- Replace entire Menu Bar Widgets Dashboard implementation
- Widget lifecycle: creation, activation, ordering, refresh, destruction
- Configuration system: persistence, validation, defaults
- Refresh model: time-based intervals, event-driven triggers, throttling

**Active Widgets Section Refactor**:
- Convert from vertical list to horizontal layout
- Preserve ordering semantics
- Maintain widget preview/review visibility

### Out of Scope

- Menu bar status item implementation (Tonic's dashboard is in-app only)
- Remote/sharing features from Stats Master
- Stats Master's NSView-based drawing (use SwiftUI)
- Non-Apple Silicon GPU monitoring

## Approach

### Phase 1: Foundation & Architecture (Tasks 1-3)

**Goal**: Build Stats Master–equivalent architecture with proper separation of concerns.

**New Architecture Pattern** (based on Stats Master analysis):

```
WidgetEngine (singleton)
├── WidgetCoordinator (activation, ordering)
├── WidgetReaderManager (data collection with deduplication)
│   ├── CPUReader, MemoryReader, NetworkReader, etc.
├── WidgetRefreshScheduler (unified timer, not per-widget)
└── WidgetStore (config persistence, migration)
```

**Key Design Decisions**:

1. **Unified Refresh Scheduler** (NOT per-widget timers):
   - Single `Task`-based scheduler with configurable intervals (1, 2, 3, 5, 10, 15, 30, 60s)
   - Each reader declares its preferred interval
   - Scheduler coalesces updates to minimize CPU wakeups
   - Reference: Stats Master's `Repeater` class but consolidated

2. **Reader Pattern** (from Stats Master):
   ```swift
   protocol WidgetReader {
       associatedtype Output
       var preferredInterval: TimeInterval { get }
       func read() async throws -> Output
   }
   ```
   - Each reader is independent, testable, background-aware
   - Results cached with TTL per Stats Master's pattern (30s min write throttle)

3. **@Observable State Management**:
   - All widget view models use `@Observable` (macOS 14+)
   - `@MainActor` for UI properties
   - `[weak self]` in all async tasks to prevent retain cycles

4. **Configuration Schema**:
   ```swift
   struct WidgetConfig: Codable {
       id: UUID
       type: WidgetType
       isEnabled: Bool
       position: Int
       displayMode: DisplayMode
       colorScheme: ColorScheme        // NEW: 20+ colors from Stats Master
       historyBufferSize: Int          // NEW: 30-120 for charts
       valueFormat: ValueFormat
       showLabel: Bool
       alignment: Alignment             // NEW: left/center/right
   }
   ```

**Risks Addressed**:
- **CPU overuse**: Unified scheduler replaces per-widget timers
- **Memory leaks**: `[weak self]` and explicit cleanup methods
- **State sync**: `@Observable` with `@MainActor` ensures UI consistency

### Phase 2: Widget Readers & Data Layer (Tasks 4-6)

**Goal**: Implement Stats Master–equivalent data collection with proper throttling.

**Implementation Pattern** (follow existing `WidgetDataManager.swift` patterns):

```swift
@Observable
@MainActor
final class WidgetReaderManager {
    private var readers: [any WidgetReader] = []
    private var cache: [String: (value: Any, timestamp: Date)] = [:]

    func refreshReaders() async {
        // Group readers by interval, execute in parallel
        // Update cache, notify observers
    }
}
```

**Key Reference Files**:
- `Tonic/Tonic/Services/WidgetDataManager.swift:235-1151` — existing IOKit patterns
- `stats-master/Kit/module/reader.swift:123-149` — Stats Master's reader base class

**Data Source Mapping**:

| Widget Type | Data Source | Reference (Stats Master) |
|-------------|-------------|--------------------------|
| CPU | host_processor_info, host_statistics | Modules/CPU/readers.swift:15-150 |
| Memory | vm_statistics64, pressure monitor | Kit/Widgets/Memory.swift |
| Disk | IOKit block storage drivers | Modules/Disk/readers.swift |
| Network | NET_RT_IFLIST2, CoreWLAN | Modules/Net/readers.swift:106-200 |
| Battery | IOPowerSources API | Kit/Widgets/Battery.swift |
| GPU | IOAccelerator (Apple Silicon) | SMC/smc.swift |

### Phase 3: Widget Types Implementation (Tasks 7-12)

**Goal**: Implement missing widget types from Stats Master.

**Widget Implementation Priority**:

1. **Line Chart** (high value, not in Tonic)
   - History buffer: 30-120 points (configurable)
   - Scaling modes: linear, square, cube, log
   - Color options: line, fill, background
   - Reference: `stats-master/Kit/Widgets/LineChart.swift`

2. **Bar Chart** (high value, not in Tonic)
   - Vertical bars for multi-value data
   - Configurable bar width, colors
   - Ideal for: CPU cores, memory zones

3. **Pie Chart** (medium value, not in Tonic)
   - Circular progress for single-value percentages
   - Battery level, disk usage

4. **Stack/Sensors** (medium value, not in Tonic)
   - Multiple related values in one widget
   - Temperature sensors, fan speeds

5. **Tachometer** (nice-to-have)
   - Circular gauge for RPM/percentage

6. **Enhanced Network** (existing, needs upgrade)
   - Add dual-direction chart mode
   - Connection type, SSID display

**Design Integration**:
- Use `DesignTokens` for colors, spacing, typography
- Use `DesignComponents` for card layouts
- Reference: `Tonic/Tonic/Design/DesignTokens.swift`

### Phase 4: Widget Configuration UI (Tasks 13-14)

**Goal**: Build Stats Master–equivalent configuration surface.

**UI Structure** (follow Stats Master's `settings.swift` pattern):

```
WidgetsPanelView
├── AvailableWidgetsSection (list, drag to add)
├── ActiveWidgetsSection (horizontal, drag to reorder)
└── WidgetConfigurationSheet (per-widget settings)
    ├── Display Mode picker
    ├── Color Scheme picker (20+ colors)
    ├── Show Label toggle
    ├── Alignment (left/center/right)
    ├── History Buffer Size (for charts)
    └── Refresh Interval selector
```

**Key Reference**:
- Stats Master: `Kit/module/settings.swift:196-242`
- Tonic: `Tonic/Tonic/Models/WidgetConfiguration.swift:175-221`

### Phase 5: Horizontal Layout & Polish (Tasks 15-16)

**Goal**: Refactor Active Widgets to horizontal layout with drag-reorder.

**Layout Pattern** (Stats Master uses horizontal scroll):
```swift
ScrollView(.horizontal) {
    LazyHStack(spacing: DesignTokens.Spacing.sm) {
        ForEach(activeWidgets) { widget in
            WidgetPreviewCard(widget: widget)
                .frame(width: 120, height: 80)
                .draggable(widget.id)
        }
    }
}
```

**Drag/Reorder**: Use SwiftUI's `.draggable()` and `.dropDestination()` modifiers

### Phase 6: Performance Validation (Task 17)

**Goal**: Verify CPU/memory usage within ±5% of Stats Master.

**Instrumentation**:
- Use Instruments Time Profiler for CPU
- Use Allocations for memory leak detection
- Compare idle and active scenarios

**Success Criteria**:
- No per-widget timers (consolidated scheduler)
- No memory leaks across refresh cycles
- Idle CPU ≈ 0% when widgets inactive

## Quick commands

```bash
# Generate Xcode project after any file changes
xcodegen generate

# Build debug
xcodebuild -scheme Tonic -configuration Debug build

# Run tests (when implemented)
xcodebuild test -scheme Tonic -destination 'platform=macOS'

# Open in Xcode
open Tonic/Tonic.xcodeproj
```

## Acceptance

### Functional Parity (Hard Gate)
- [ ] Every widget from Stats Master exists in Tonic Menu Bar Widgets Dashboard
- [ ] Widget behavior, data semantics, and output values are equivalent for same inputs
- [ ] No widget is missing, partially implemented, or stubbed

### Widget Lifecycle & State
- [ ] Widget creation flow matches Stats Master (defaults, initial state, first refresh)
- [ ] Activation/deactivation semantics are identical
- [ ] Order persistence matches Stats Master across app/system restart
- [ ] Deletion fully cleans up: config, cache, background tasks

### Refresh & Update Model
- [ ] Time-based refresh cadence matches Stats Master (1-60s intervals)
- [ ] Event-driven refreshes trigger at same moments
- [ ] Background refresh respects throttling rules
- [ ] Failure handling matches Stats Master (backoff, suppression, fallback)

### Data Correctness & Consistency
- [ ] For identical system state: widget values match within refresh window
- [ ] Formatting (units, rounding, truncation) matches exactly
- [ ] Empty, loading, error, partial-data states match visually

### Widget Configuration Parity
- [ ] All configuration options present in Stats Master are available
- [ ] Configuration defaults are identical
- [ ] Validation rules match exactly
- [ ] Changes apply at same time (immediate vs lazy)
- [ ] Configuration persists across: restart, reorder, enable/disable

### UI & Interaction Model
- [ ] Widget layout, spacing, density match Stats Master behaviorally
- [ ] Tonic styling applied without altering semantics
- [ ] Hover, click, context menu behaviors match
- [ ] Animations respect Stats Master timing

### Menu Bar Widgets Dashboard Integration
- [ ] Dashboard fully replaces prior widget implementation
- [ ] No legacy widget code paths execute
- [ ] All Stats Master widget interactions supported

### Active Widgets Section (Layout Refactor)
- [ ] Active Widgets converted from vertical → horizontal layout
- [ ] Widget order unchanged logically
- [ ] Drag/reorder behavior matches Stats Master
- [ ] Widget preview remains visible and functional
- [ ] Horizontal layout supports overflow, scrolling, resizing

### Performance & Resource Usage
- [ ] CPU, memory, battery within ±5% of Stats Master under equivalent load
- [ ] No unnecessary background work when widgets inactive
- [ ] Cold start widget readiness time matches Stats Master

### Regression & Safety
- [ ] No regressions in unrelated Menu Bar functionality
- [ ] Rollback path defined and tested

## References

### Stats Master Reference Files
- `stats-master/Kit/module/widget.swift:31-127` — Widget base class
- `stats-master/Kit/module/reader.swift:123-149` — Reader lifecycle
- `stats-master/Kit/plugins/Repeater.swift:25-72` — Timer implementation
- `stats-master/Kit/plugins/Store.swift:14-137` — Configuration persistence
- `stats-master/Kit/module/settings.swift:196-242` — Settings UI pattern
- `stats-master/Modules/CPU/readers.swift:15-150` — CPU data collection
- `stats-master/Modules/Net/readers.swift:106-200` — Network data collection
- `stats-master/SMC/smc.swift` — GPU/temperature via SMC

### Tonic Reference Files
- `Tonic/Tonic/Services/WidgetDataManager.swift:235-1151` — Current data collection
- `Tonic/Tonic/Models/WidgetConfiguration.swift:175-221` — Current config model
- `Tonic/Tonic/MenuBarWidgets/WidgetStatusItem.swift:18-304` — Status item lifecycle
- `Tonic/Tonic/Design/DesignTokens.swift` — Design tokens
- `Tonic/Tonic/Design/DesignComponents.swift` — Reusable components
- `Tonic/Tonic/Views/ContentView.swift:167-168` — Navigation integration

### Design Patterns
- `@Observable` pattern for macOS 14+ state management
- `[weak self]` in async tasks for memory safety
- `@MainActor` for UI properties
- Single unified scheduler (not per-widget timers)

### Known Risks (from flow-gap-analyst)
- **Timer per-widget** → Fixed by unified scheduler
- **NSStatusItem leaks** → Fixed by explicit cleanup pattern
- **Main thread IOKit** → Move to background with `@MainActor` result dispatch
- **@MainActor deinit violation** → Use explicit `cleanup()` method
- **Memory leaks in NSHostingController** → Track and release explicitly
