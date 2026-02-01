# Stats Master Menu Bar Parity (Extended PRD + Cleanup)

## Overview

Replace Tonic's current menu bar widget system with Stats Master's implementation to achieve full feature parity. This epic includes critical cleanup tasks to address ~3,300 lines of dead code from an aborted architecture migration.

**Critical Finding**: The codebase contains THREE separate reader architectures:
1. **Production Architecture** (WidgetDataManager with inline methods) - ✅ WORKING
2. **WidgetReader Protocol** (9 reader implementations) - ❌ DEAD (~2,605 lines)
3. **Reader Protocol** (BaseReader + Repeater) - ❌ UNUSED (594 lines)

**Only #1 is used in production.** Tasks 21-26 address the critical cleanup and completion issues.

**Original Scope (Tasks 1-14)**: 8 widget types, 14 visualizations, core Stats Master features
**Extended Scope (Tasks 15-20)**: Full PRD parity with Bluetooth, Clock, enhanced colors
**Cleanup Scope (Tasks 21-26)**: Fix build errors, add missing integrations, delete dead code
**Parity Scope (Tasks 28-50)**: Stats Master UI/UX parity

**Current Implementation State**:
- 8 widget types: CPU, GPU, Memory, Disk, Network, Weather, Battery, Sensors
- 14 visualization types: mini, lineChart, barChart, pieChart, tachometer, stack, speed, networkChart, batteryDetails, label, state, text, memory, battery
- OneView mode ✅ working
- Notification system foundation ✅ complete
- Color system ✅ 32 colors (exceeds 30+ requirement)

---

## IMPORTANT: Reference Stats Master Implementation

**ALL tasks in Phase 6 (Parity) must reference Stats Master's implementation** before writing code.

Stats Master reference location: `../stats-master/`

For each task:
1. Read Stats Master's implementation first
2. Understand patterns used (layout, spacing, colors, interactions)
3. Replicate in Tonic with SwiftUI
4. Keep Tonic's in-app navigation (NOT separate settings window)

---

## Scope

### Original Scope (Tasks 1-14) ✅ COMPLETE
Enhanced Data Readers, Process Monitoring UI, Notification System, OneView Mode, Widget Visualizations

### Extended Scope (Tasks 15-20) ⚠️ MOSTLY COMPLETE
- ✅ Bluetooth Module (Task 15)
- ⚠️ Clock Module (Task 16) → **Now Task 47**
- ✅ Memory/Battery Visualizations (Task 17)
- ✅ Enhanced Color System (Task 19) - 32 colors

### Cleanup Scope (Tasks 21-26) 🔧 TECHNICAL DEBT
| Task | Description | Priority |
|------|-------------|----------|
| 21 | Fix build errors (PlaceholderDetailView) | HIGH |
| 22 | Add Network/Bluetooth notifications | MEDIUM |
| 23 | Add history tracking (GPU/Battery/Sensors/Disk) | MEDIUM |
| 24 | Delete dead WidgetReader directory (~2,605 lines) | TECH DEBT |
| 25 | Delete dead Scheduler/Reader Protocol (~716 lines) | TECH DEBT |
| 26 | Complete data population (11 fields) | LOW |
| 27 | CPU E/P core detection complete | ✅ DONE |

### Parity Scope (Tasks 28-50) 🆕 STATS MASTER UI PARITY

#### CRITICAL FIXES (Tasks 28-29)
| Task | Title | Est. Days |
|------|-------|-----------|
| 28 | Fix Configuration Refresh Bug - Changes don't propagate | 1 |
| 29 | CPU Data Layer Enhancement - System/User/Idle, uptime, load avg, **frequency** | 2 |

#### INFRASTRUCTURE (Tasks 30-30c)
| Task | Title | Est. Days |
|------|-------|-----------|
| 30a | Create PopupWindow.swift (NSWindow subclass with drag) | 1 |
| 30b | Create HeaderView.swift (Activity Monitor + Settings button) | 0.5 |
| 30c | Create ProcessesView.swift (Reusable top processes) | 1 |

#### UI COMPONENTS (Tasks 31-31, 35a)
| Task | Title | Est. Days |
|------|-------|-----------|
| 31 | Core Cluster Component (E/P grouped bars) | 1 |
| 30 | Dashboard Gauge Components (CircularGaugeView, HalfCircleGaugeView) | 2 |
| 35a | Add °C/°F Toggle (General settings, applies everywhere) | 0.5 |

#### CPU POPOVER (Tasks 32a-32c) - 9 SECTIONS
Stats Master's CPU popup has 9 distinct sections:
1. Dashboard (pie + temp + freq gauges)
2. Usage history line chart
3. Per-core bar chart (E/P grouped)
4. Details (system/user/idle rows)
5. Average load (1/5/15 min)
6. Frequency section (all cores, E-cores, P-cores in MHz)
7. Scheduler/Speed limits (Intel-specific)
8. Top processes
9. Header + scroll container

| Task | Title | Est. Days |
|------|-------|-----------|
| 32a | CPU Popover - Dashboard Section (3 gauges) | 2 |
| 32b | CPU Popover - Charts, Details, Load Avg, Frequency | 2 |
| 32c | CPU Popover - Processes Section & Integration | 1 |

#### OTHER POPOVERS (Tasks 33-40, 47)
| Task | Widget | Sections | Est. Days |
|------|--------|----------|-----------|
| 33 | Memory | Add cache/wired, top processes | 1 |
| 34 | Network | WiFi details, public IP, connectivity | 1 |
| 35 | Disk | I/O history, SMART, top processes | 1 |
| 36 | GPU | History chart, E/core breakdown, top processes | 2 |
| 37 | Battery | Charge history, optimized charging display | 1 |
| 38 | Sensors | History charts, visual gauges, fan curves | 2 |
| 39 | Bluetooth | Connection history, signal strength | 1 |
| 47 | Clock | Multi-timezone, date formatting, calendar button | 2 |

#### SETTINGS OVERHAUL (Task 41)
**KEEP TONIC'S IN-APP NAVIGATION** - Add Stats Master's per-module options within existing view

| Task | Title | Est. Days |
|------|-------|-----------|
| 41 | Enhanced Per-Module Settings (in WidgetCustomizationView) | 2 |

- Replace generic config with Stats Master's per-module options
- For each widget: enabled toggle, visualization, interval, popup settings
- CPU-specific: show E/P cores, show frequency, show temperature, show load avg
- Disk-specific: select volume, show SMART
- Network-specific: select interface, show public IP, show WiFi details

#### POLISH (Tasks 42-44, 49-50)
| Task | Title | Est. Days |
|------|-------|-----------|
| 42 | Drag-Drop Widget Reordering | 1 |
| 43 | Visual Polish (match Stats Master spacing/fonts/colors) | 2 |
| 44 | Performance Optimization | 2 |
| 49 | Delete Dead Code (~3,300 lines) | 0.5 |
| 50 | Final Testing & Verification | 3 |

---

## Critical Issues Summary

| Issue | Severity | Lines | Status |
|-------|----------|-------|--------|
| Config refresh bug | CRITICAL | Reactive gap | Task 28 |
| Build errors | HIGH | PlaceholderDetailView | Task 21 |
| CPU data incomplete | HIGH | Missing frequency, load avg | Task 29 |
| Network notification missing | MEDIUM | Integration gap | Task 22 |
| Bluetooth notification missing | MEDIUM | Integration gap | Task 22 |
| GPU/Battery/Sensors/Disk history missing | LOW | Feature gap | Task 23 |
| Dead WidgetReader code | TECH DEBT | ~2,605 | Task 49 |
| Dead Scheduler/Protocol | TECH DEBT | ~716 | Task 49 |

---

## CPU Data Layer Complete Scope (Task 29)

Stats Master's CPU popup needs ALL of these:

| Data Point | Task Coverage | Notes |
|------------|---------------|-------|
| System/User/Idle | ✅ Task 29 | Color-coded rows |
| E-cores/P-cores breakdown | ✅ Task 27 (done) + Task 31 (display) | Detection done, display needed |
| Uptime | ✅ Task 29 | Seconds since boot |
| **Frequency** | ✅ Task 29 (EXPANDED) | All cores, E-cores, P-cores in MHz |
| Scheduler/Speed limits | ⚠️ Intel-specific | Optional, may skip |
| Average load (1/5/15 min) | ✅ Task 29 | getloadavg() |
| Temperature | ✅ Already exists | Wire to display |

---

## Settings Design Decision

**KEEP TONIC'S IN-APP NAVIGATION** - DO NOT create separate NSWindow for settings

Stats Master's approach: Separate 720x480 NSWindow from menu bar
Tonic's approach: In-app navigation via sidebar → KEEP THIS

**Hybrid Solution:**
- Keep Tonic's in-app `WidgetCustomizationView.swift`
- Add Stats Master's per-module options WITHIN that view
- When user clicks a widget, show Stats Master-style configuration:
  - Widget enabled toggle
  - Visualization picker (from Tonic)
  - Update interval (1s, 2s, 5s, Never) - from Stats Master
  - Popup-specific toggles (show temp, show freq, show pie, etc.)
  - Notification threshold settings

---

## Estimated Effort Summary

| Phase | Tasks | Est. Days | Status |
|-------|-------|-----------|--------|
| Phases 1-4 | 1-20 | - | ✅ Already done |
| Phase 5 (Cleanup) | 21-27 | ~3-4 days | 🔧 Pending |
| **Phase 6 (Parity)** | **28-50** | **~25-30 days** | 🆕 New |
| **TOTAL** | **50 tasks** | **~28-34 days** | |

---

## Recommended Execution Order

```
1. Task 28  (Fix Configuration Refresh Bug)    ⚡ DO FIRST - foundation for everything
2. Task 21  (Fix Build Errors)                  Unblock development
3. Task 29  (CPU Data Layer)                    Enables CPU popover
4. Task 30  (Dashboard Gauge Components)        Prerequisite for all dashboards
5. Task 30a  (PopupWindow)                       Window infrastructure
6. Task 30b  (HeaderView)                        Header infrastructure
7. Task 30c  (ProcessesView)                    Reusable component
8. Task 31  (Core Cluster)                       E/P display
9. Task 32a  (CPU Popover - Dashboard)          First full popover
10. Task 32b  (CPU Popover - Charts/Details)
11. Task 32c  (CPU Popover - Processes)
12. Task 35a  (°C/°F Toggle)                     Quick win
13. Task 41  (Per-Module Settings)              Replace generic config
14. Tasks 33-40, 47  (Other Popovers)           Parallel work possible
15. Task 42  (Drag-Drop)                         Nice-to-have
16. Task 49  (Delete Dead Code)                  Cleanup after testing
17. Tasks 43-44, 50  (Polish)                    Final polish
```

---

## Acceptance Criteria

### Critical Fixes (Tasks 21, 28-29)
- [ ] Configuration changes propagate immediately (no restart needed)
- [ ] CPU data includes System/User/Idle, uptime, load average, frequency
- [ ] Build errors resolved (PlaceholderDetailView)

### Infrastructure (Tasks 30-30c)
- [ ] PopupWindow with drag behavior (optional, can use NSPopover)
- [ ] HeaderView with Activity Monitor toggle + Settings button
- [ ] ProcessesView reusable across CPU/Memory/Disk

### CPU Popover (Tasks 32a-32c)
- [ ] 9 sections matching Stats Master
- [ ] Dashboard with 3 gauges (pie, temp, freq)
- [ ] E/P core grouped bars
- [ ] System/User/Idle color-coded rows
- [ ] 1/5/15 min load average
- [ ] Frequency section (all/E/P cores in MHz)
- [ ] Top processes (configurable 0-15)

### Other Popovers (Tasks 33-40, 47)
- [ ] Memory: cache, wired, top processes
- [ ] Network: WiFi details, public IP, connectivity
- [ ] Disk: I/O history, SMART, top processes
- [ ] GPU: history chart, E/core breakdown
- [ ] Battery: charge history, optimized charging
- [ ] Sensors: history charts, visual gauges
- [ ] Bluetooth: connection history, signal
- [ ] Clock: multi-timezone, calendar button

### Settings (Task 41, 35a)
- [ ] Per-module options in in-app WidgetCustomizationView
- [ ] CPU-specific toggles (E/P, frequency, temp, load avg)
- [ ] °C/°F toggle in General settings

### Polish (Tasks 42-44, 49-50)
- [ ] Drag-drop widget reordering
- [ ] Visual match to Stats Master (spacing, fonts, colors)
- [ ] Performance optimized (<1% CPU per widget)
- [ ] Dead code deleted (~3,300 lines)
- [ ] Side-by-side verification with Stats Master

---

## Quick Commands

```bash
# Build Tonic
xcodebuild -scheme Tonic -configuration Debug build

# Verify no WidgetReader references remain
grep -r "WidgetReader" Tonic/Tonic/ --exclude-dir=WidgetReader

# Verify no ReaderProtocol references remain
grep -r ": Reader<" Tonic/Tonic/

# Count lines removed (for verification)
wc -l Tonic/Tonic/Services/WidgetReader/*  # before deletion
wc -l Tonic/Tonic/Services/WidgetRefreshScheduler.swift  # before deletion
wc -l Tonic/Tonic/Services/ReaderProtocol.swift  # before deletion
```

---

## References

### Production System
- WidgetDataManager: `Tonic/Tonic/Services/WidgetDataManager.swift`
- updateCPUData(): line 796
- updateMemoryData(): line 1168
- updateDiskData(): line 1553
- updateNetworkData(): line 1960
- updateGPUData(): line 2474
- updateBatteryData(): line 2626
- updateSensorsData(): line 2807
- updateBluetoothData(): line 3214

### Dead Code (To Delete in Task 49)
- WidgetReader/: `Tonic/Tonic/Services/WidgetReader/`
- WidgetRefreshScheduler: `Tonic/Tonic/Services/WidgetRefreshScheduler.swift`
- ReaderProtocol: `Tonic/Tonic/Services/ReaderProtocol.swift`

### Stats Master Reference (ALL Phase 6 tasks must read)
- CPU popup: `../stats-master/Modules/CPU/popup.swift`
- Settings: `../stats-master/Stats/Views/Settings.swift`
- Popup window: `../stats-master/Kit/module/popup.swift`
- Widget: `../stats-master/Kit/widget.swift`
