# fn-6-i4g.17 Memory and Battery Visualization Types

## Description
Add two new visualization types to achieve full PRD parity: `memory` (two-row used/total display) and `battery` (battery icon with fill level). These are specialized visualizations distinct from existing types.

**Size:** S
**Files:**
- `Tonic/Tonic/Models/VisualizationType.swift` (add cases)
- `Tonic/Tonic/MenuBarWidgets/Views/MemoryWidgetView.swift` (new)
- `Tonic/Tonic/MenuBarWidgets/ChartStatusItems/MemoryStatusItem.swift` (new)
- `Tonic/Tonic/MenuBarWidgets/Views/BatteryWidgetView.swift` (enhance existing)
- `Tonic/Tonic/MenuBarWidgets/WidgetFactory.swift` (add cases)
- `Tonic/Tonic/Models/WidgetConfiguration.swift` (add to compatibleVisualizations)

## Approach

- Follow existing visualization pattern at `VisualizationType.swift:15-118`
- `memory` visualization: Two stacked rows showing "8.2 GB" over "16 GB" with order toggle option
- `battery` visualization: Battery icon with fill level (distinct from `batteryDetails` text display)
- Add to `WidgetFactory.createWidget()` switch at `WidgetFactory.swift:38-68`
- Update `compatibleVisualizations` for Memory and Battery widget types

## Key Context

**`memory` visualization** (from PRD):
- Width: ~50pt variable
- Shows used memory on top row, total on bottom
- Order toggle: user can swap which value is on top
- Supports symbols option (show memory icon)

**`battery` visualization** (from PRD):
- Width: ~40pt variable  
- Battery icon with fill level based on percentage
- Additional info options: none, percentage inside, percentage beside, time remaining
- Charger icon when charging
## Acceptance
- [ ] `memory` case added to `VisualizationType` enum
- [ ] `battery` case added to `VisualizationType` enum  
- [ ] `MemoryWidgetView` displays two-row used/total format
- [ ] Memory widget order toggle works (swap top/bottom values)
- [ ] Battery icon fills proportionally to battery percentage
- [ ] Battery icon shows charging indicator when plugged in
- [ ] Battery additional info options work (none/inside/%/time)
- [ ] Both visualizations integrate with `WidgetFactory`
- [ ] Memory visualization compatible with `.memory` widget type
- [ ] Battery visualization compatible with `.battery` widget type
## Done summary
Added two new visualization types for full PRD parity: `memory` (two-row used/total display) and `battery` (battery icon with fill level). Both integrate with WidgetFactory and are now available as visualization options for their respective widget types.
## Evidence
- Commits: 173b305c36fca5b9eb05a76b4a8449317148b011
- Tests: xcodebuild -scheme Tonic -configuration Debug build
- PRs: