# Stats Master Popover Parity — Layout, Components, and Settings

## Overview

Achieve full functional and layout parity between Stats Master and Tonic popover views for **public release**. This epic standardizes popover dimensions (280-300px width with flexibility), increases chart history to 180 points, adds missing data fields and visual components (pressure gauge, per-GPU architecture), and implements a comprehensive tabbed settings UI.

**Scope:** 8 popover types (CPU, GPU, Memory, Disk, Network, Battery, Sensors, Bluetooth) + global layout standards + tabbed settings architecture.

**Estimated Duration:** 17-25 days across 6 phases.

**Release Strategy:** Big bang release (all popovers ship together)

---

## Stakeholder Impact

### End Users
- **New Features:** Memory pressure gauge, per-GPU monitoring, battery electrical metrics, multi-battery Bluetooth support, per-widget keyboard shortcuts
- **Visual Consistency:** All popovers have uniform 280-300px width, standardized row heights, matching fonts
- **Improved Data:** 180-point chart history (3x current) for better trend visualization
- **Enhanced Configuration:** Tabbed settings UI with per-module controls, full color customization
- **Note:** Fan control deferred to follow-up epic

### Developers
- **New Components:** `PressureGaugeView`, `PerGpuContainer`, `PerDiskContainer`, `CombinedCPUChartView`, `FanControlView` (deferred)
- **Updated Data Layer:** Enhanced `WidgetDataManager` with new properties for all widget types
- **Settings Architecture:** `PopperPreferences` separate from `WidgetPreferences`, `ModuleSettings` protocol
- **Migration:** Settings reset on update (users reconfigure)

---

## Scope

### In Scope
- Layout standardization (280-300px width, 9/11/13pt fonts, standardized row heights)
- Chart history increase to 180 points (render all points, no optimization needed)
- Missing data fields (CPU: scheduler limit, speed limit, uptime; Memory: pressure, swap, fields; GPU: render/tiler, metadata; Disk: I/O stats, processes; Battery: electrical metrics)
- New visual components (pressure gauge, per-GPU/disk containers)
- Tabbed settings UI (Module, Widgets, Popup, Notifications tabs)
- Menu bar refresh bug fix
- Multi-battery Bluetooth support (essential for AirPods)
- Per-widget keyboard shortcuts
- Reactive data updates (when value changes, not time-based)

### Out of Scope (Deferred)
- **Fan Control:** Entire fan control system (~450 lines) deferred to follow-up epic
  - FanControlView component
  - SMC write commands
  - Fan modes (auto/manual/system)
  - Safety model (warnings, thermal limits)
- Weather popover (different data source, already complete)
- Clock popover (simple, no changes needed)
- Accessibility/VoiceOver support (separate pass)
- OneView mode settings (covered in existing epics)

---

## Key Decisions from Interview

### Layout & Design
- **Width:** 280-300px range acceptable (not strict 280px)
- **Expanded State:** Remember during session, reset to collapsed on app quit
- **Animation:** Charts animate on popover open only, not for data updates
- **Dark Mode:** Full dark mode support for all new gauges
- **Temperature:** Follow system locale with user override in settings

### Data & Updates
- **Chart History:** Memory only (not persisted to disk), render all 180 points
- **Update Strategy:** Reactive (when value changes), not time-based
- **Process Sampling:** Same interval for all metrics, per-process I/O for network
- **Process Count:** Standard configurable count (3-20) via module settings
- **Error Handling:** Specific error messages for each failure type

### Settings Architecture
- **Persistence:** Immediate + auto-save (no save button)
- **Shortcuts:** Per-widget keyboard shortcuts
- **Scaling:** All three modes (none/auto/fixed)
- **Colors:** Full customization per metric
- **Preferences:** Separate `PopoverPreferences` from `WidgetPreferences`
- **Migration:** Settings reset on update (users reconfigure)

### Hardware & Testing
- **GPU:** Single GPU testing (Apple Silicon), multi-GPU must be defensive with hide-if-unavailable
- **Battery:** Hide battery widget completely on desktop Macs
- **Testing:** MacBook Pro only, macOS 14 (Sonoma) + macOS 15 (Sequoia)
- **OneView:** Popovers work identically in both OneView and Individual modes

### Internationalization
- **i18n:** Use `Localizable.strings` structure (English hardcoded for v1)
- **Temperature Units:** Follow system locale with user-configurable override

### Deferred Features
- **Fan Control:** Entire feature deferred to follow-up epic
- **Accessibility:** VoiceOver support deferred to separate pass

---

## Approach

### Phase 1: Foundation (Layout + Constants)
1. Update `PopoverConstants.swift` with font sizes (9/11/13pt) and spacing (10px margins)
2. Allow 280-300px width flexibility
3. Increase `WidgetDataManager.maxHistoryPoints` from 60 to 180
4. Standardize section heights (dashboard: 90px, header: 22px, detail: 16px, process: 22px)

### Phase 2: Critical Components
1. Create `PressureGaugeView.swift` (3-color arc: green 0-50%, yellow 50-80%, red 80-100%)
2. Implement memory pressure via `dispatch_source` + fallback calculation
3. Create `MemoryPopoverView.swift` using pressure gauge as primary visual
4. Update `CPUPopoverView.swift` with missing fields (scheduler limit, speed limit, uptime)
5. Create `CombinedCPUChartView.swift` (line + bar in single component)

### Phase 3: Per-Device Architecture
1. Create `PerGpuContainer.swift` with 4 gauges + 4 charts + expandable details
2. Hide GPU metrics if unavailable (no placeholder state)
3. Create `PerDiskContainer.swift` with dual-line read/write charts
4. Add top processes sections to disk popover
5. Update `GPUPopoverView.swift` with per-GPU architecture
6. Update `DiskPopoverView.swift` with I/O stats and processes

### Phase 4: Battery & Network
1. Add electrical metrics to `BatteryPopoverView` (amperage, voltage, power)
2. Add capacity breakdown (current/max/designed)
3. Implement multi-battery support for Bluetooth (essential for AirPods)
4. Update `NetworkPopoverView.swift` with DNS servers, WiFi tooltip, per-process network I/O
5. Update `BluetoothPopoverView.swift` with multi-battery data model

### Phase 5: Settings Architecture
1. Create `TabbedSettingsView.swift` with segmented tab switcher (540×480 layout)
2. Implement `ModuleSettings` protocol
3. Create `PopperPreferences` (separate from `WidgetPreferences`)
4. Create per-module settings views with immediate + auto-save
5. Create `PopupSettingsView` with keyboard shortcuts, scaling modes, color customization
6. Extract notifications settings to dedicated tab

### Phase 6: Polish & Bug Fix
1. Fix menu bar refresh bug (`setNeedsDisplay`, `display()`, view recreation)
2. Add dark mode variants for all gauges
3. Implement reactive data updates (when value changes)
4. Add specific error messages for data failures
5. Prepare i18n structure (Localizable.strings)
6. Update documentation (minimal - code self-documenting)

---

## Risks and Mitigations

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Multi-GPU data unavailable | HIGH | LOW | Hide metrics if unavailable, single GPU testing only |
| GPU render/tiler unavailable | MEDIUM | LOW | Hide gauges/charts if data not available |
| Battery electrical data varies | MEDIUM | LOW | Graceful handling of optional fields |
| DNS enumeration fails | LOW | LOW | Display specific error message |
| Settings migration (reset) | MEDIUM | MEDIUM | Users will need to reconfigure, communicate in release notes |
| Chart performance at 180 points | LOW | LOW | Circular buffer O(1), SwiftUI efficient |
| SMC unavailable (fan control deferred) | N/A | N/A | Deferred to follow-up epic |

---

## Edge Cases

### Hardware Variations
- **Desktop Macs (no battery):** Hide battery widget completely
- **Single GPU systems:** Show single GPU container
- **Multi-GPU unavailable:** Hide per-GPU specific metrics (render/tiler)
- **No swap configured:** Hide swap section in Memory popover
- **No Bluetooth permissions:** Show permission request UI

### Data Availability
- **SMC unavailable:** Hide sensors/fan data gracefully
- **GPU metadata missing:** Hide vendor/cores/clock fields
- **Network DNS enumeration failed:** Show specific error message
- **WiFi details unavailable:** Hide extended tooltip
- **Process I/O unavailable:** Show CPU/memory fallback metrics

### User State
- **Expanded sections:** Remember during session, reset on app quit
- **Settings migration:** Reset all settings, users reconfigure
- **OneView vs Individual:** Popovers work identically in both modes
- **Desktop Mac:** Battery widget hidden from menu bar

### Performance
- **180-point charts:** Render all points, no downsampling
- **Chart updates:** Reactive (when value changes), not time-based
- **Process sampling:** Same interval for all metrics
- **Popover open:** Animate on open only, instant updates thereafter

---

## Acceptance Criteria

### Phase 1: Layout Parity
- [ ] All popovers are 280-300px wide
- [ ] Dashboard sections are exactly 90px tall
- [ ] Section headers are exactly 22px tall
- [ ] Detail rows are exactly 16px tall
- [ ] Process rows are exactly 22px tall
- [ ] Font sizes are 9pt (small), 11pt (medium), 13pt (large)
- [ ] Margins are 10px
- [ ] Chart history is 180 points for all widgets

### Phase 2: Critical Visual Components
- [ ] `PressureGaugeView` displays green (0-50%), yellow (50-80%), red (80-100%)
- [ ] Pressure gauge has dark mode variants
- [ ] Needle rotates correctly based on pressure percentage
- [ ] Center text shows pressure level or percentage
- [ ] Memory pressure uses dispatch_source + fallback
- [ ] `MemoryPopoverView.swift` exists and uses pressure gauge
- [ ] CPU popover shows scheduler limit, speed limit, uptime
- [ ] CPU popover has combined line + bar chart
- [ ] CPU popover colors match per-core E/P colors

### Phase 3: Per-Device Architecture
- [ ] `PerGpuContainer` shows 4 gauges (temp, util, render, tiler)
- [ ] `PerGpuContainer` shows 4 line charts (one per metric)
- [ ] GPU popover has expandable details panel (remember during session)
- [ ] Unavailable GPU metrics hidden (no placeholder)
- [ ] `PerDiskContainer` shows dual-line read/write chart
- [ ] Disk popover shows top processes with I/O
- [ ] Disk popover shows I/O statistics (ops, bytes, time)

### Phase 4: Battery & Network
- [ ] Battery popover shows amperage (mA)
- [ ] Battery popover shows voltage (V)
- [ ] Battery popover shows power (W = V × A)
- [ ] Battery popover shows capacity breakdown (current/max/designed)
- [ ] Bluetooth popover supports multiple battery levels per device
- [ ] Bluetooth popover works with AirPods case/left/right
- [ ] Network popover shows DNS servers (with error message if unavailable)
- [ ] Network popover WiFi tooltip shows RSSI, noise, band, width
- [ ] Network popover shows per-process network I/O
- [ ] Battery widget hidden on desktop Macs

### Phase 5: Settings Architecture
- [ ] `TabbedSettingsView` shows 4 tabs: Module, Widgets, Popup, Notifications
- [ ] Tabbed settings container is 540×480
- [ ] Settings apply immediately with auto-save
- [ ] Module tab shows per-module settings views
- [ ] Popup tab has per-widget keyboard shortcuts
- [ ] Popup tab has scaling mode (none/auto/fixed)
- [ ] Popup tab has per-metric color pickers
- [ ] `PopperPreferences` separate from `WidgetPreferences`
- [ ] Temperature unit override in settings

### Phase 6: Polish & Bug Fix
- [ ] Menu bar widget refresh works immediately after config change
- [ ] All new gauges have dark mode variants
- [ ] Data updates reactively (when value changes)
- [ ] Specific error messages for each failure type
- [ ] Localizable.strings structure in place (English text)
- [ ] Popovers work identically in OneView and Individual modes

### Documentation (Minimal)
- [ ] CLAUDE.md notes key new components
- [ ] Settings architecture documented at high level

---

## Open Questions

1. **Settings Reset Communication:** How will users be informed that settings will reset after this update? (Release notes, in-app notification, or both?)

2. **Color Picker Implementation:** Full customization per metric requires significant UI. Should this be a grid of color pickers or a drill-down per widget?

3. **Per-Widget Shortcuts Implementation:** How should users assign keyboard shortcuts? Global hotkey registration requires system permissions.

---

## References

- **Stats Master reference:** `stats-master/Modules/*/popup.swift`
- **Existing spec:** `.flow/specs/fn-7-stats-master-popover-parity.md`
- **Design tokens:** `Tonic/Tonic/Design/DesignTokens.swift`
- **Popover templates:** `Tonic/Tonic/MenuBarWidgets/Popovers/PopoverTemplate.swift`
- **Widget data manager:** `Tonic/Tonic/Services/WidgetDataManager.swift`
- **Widget configuration:** `Tonic/Tonic/Models/WidgetConfiguration.swift`

### Dependency Epics
- **fn-4-as7** (UI/UX Redesign): Follow design tokens and component patterns
- **fn-5-v8r** (Stats Master Parity): Builds on existing widget architecture
- **fn-6-i4g** (Extended Parity): Uses working data layer and configuration system

### Deferred to Follow-up Epic
- **Fan Control System:** Full fan control UI, SMC integration, safety model (~450 lines)
- **Accessibility/VoiceOver:** Comprehensive accessibility labels for all gauges and charts
