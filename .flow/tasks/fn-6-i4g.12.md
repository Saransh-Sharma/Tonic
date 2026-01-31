# fn-6-i4g.12 Widget Visualization Enhancements

## Description
Enhance existing widget visualizations with Stats Master features.

**Size:** M

**Files:**
- `Tonic/Tonic/MenuBarWidgets/Views/LineChartWidgetView.swift` (modify)
- `Tonic/Tonic/MenuBarWidgets/Views/BarChartWidgetView.swift` (modify)
- `Tonic/Tonic/MenuBarWidgets/Views/NetworkChartWidgetView.swift` (new)
- `Tonic/Tonic/Models/VisualizationType.swift` (modify - add networkChart)

**Line Chart Enhancements**:
1. Value overlay - show current value on chart
2. E/P core cluster coloring for CPU
3. Configurable chart background (fill vs line only)

**Bar Chart Enhancements**:
1. Per-core E/P cluster coloring
2. Stacked bar option for multi-value display

**New: networkChart Visualization**:
1. Dual-line chart (upload/download)
2. Independent colors per direction
3. Independent scaling options
4. Follows `networkChart` pattern from Stats Master

## Approach

1. Extend `LineChartConfig` with `showValueOverlay` flag
2. Add E/P core color mapping to `BarChartWidgetView`
3. Create `NetworkChartWidgetView` for dual-line network chart
4. Add `networkChart` case to `VisualizationType` enum
5. Register `networkChart` in compatible visualizations for `WidgetType.network`
6. Update `WidgetFactory` to route `networkChart` to new view

## Key Context

Stats Master's `networkChart` uses separate colors and scales for upload vs download. Reference `stats-master/Kit/widgets/NetworkChart.swift`.

E/P core colors: Stats Master uses cluster-based coloring. Apple Silicon E cores = cooler color (blue/green), P cores = warmer color (orange/red).

Reference: `LineChartWidgetView.swift:15-97` for current line chart implementation.
## Acceptance
- [ ] LineChartConfig extended with showValueOverlay
- [ ] Line chart shows current value overlay when enabled
- [ ] Bar chart has E/P core cluster coloring
- [ ] Bar chart supports stacked mode
- [ ] networkChart visualization type added
- [ ] NetworkChartWidgetView created
- [ ] Dual-line display for upload/download
- [ ] Independent colors per direction
- [ ] Independent scaling per direction
- [ ] networkChart registered for WidgetType.network
- [ ] WidgetFactory routes networkChart correctly
## Done summary
Enhanced widget visualizations with Stats Master features: Line chart now supports value overlays and configurable fill modes. Bar chart has E/P core cluster coloring and stacked mode. Created NetworkChartWidgetView with dual-line upload/download display, independent colors and scaling per direction. All visualizations integrated with WidgetFactory and VisualizationType.
## Evidence
- Commits: 3175e498c6a39554ea76a69e2743433ff441cf17
- Tests: xcodebuild -scheme Tonic -configuration Debug build
- PRs: