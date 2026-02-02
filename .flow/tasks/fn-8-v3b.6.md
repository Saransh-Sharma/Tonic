# fn-8-v3b.6 Create PerGpuContainer with gauges and charts

## Description
Create `PerGpuContainer.swift` component for per-GPU visualization with 4 gauges and 4 charts, matching Stats Master's multi-GPU architecture.

**Size:** M

**Files:**
- `Tonic/Tonic/MenuBarWidgets/Components/PerGpuContainer.swift` (NEW, ~300 lines)
- `Tonic/Tonic/MenuBarWidgets/Components/HalfCircleGaugeView.swift` (may need update)

## Approach

Create a container view that represents a single GPU with:

1. **Title bar (24px):** GPU model name, Status indicator (6x6 dot), "DETAILS" button
2. **Circles Row (50px):** 4 half-circle gauges horizontal
   - Temperature gauge
   - Utilization gauge
   - Render utilization gauge (NEW)
   - Tiler utilization gauge (NEW)
3. **Charts Row (60px):** 4 mini line charts horizontal
   - Temperature history
   - Utilization history
   - Render history
   - Tiler history
4. **Details Panel:** Expandable grid showing:
   - Vendor, Model, Cores, Status, Fan speed
   - Core clock, Memory clock
   - Current values for all 4 metrics

Each gauge: 50×50px with 10px margins.

Use existing `HalfCircleGaugeView` if available, or create as helper.

## Key Context

Stats Master's GPU popup at `stats-master/Modules/GPU/popup.swift` (18,377 lines) is the reference.

Multi-GPU systems are rare on Apple Silicon (typically only Mac Pro with multiple MPX modules, or Intel Macs with discrete + integrated). Implementation should gracefully degrade to single GPU.

GPU data from `WidgetDataManager.gpuData` needs enhancement for:
- `renderUtilization: Double?`
- `tilerUtilization: Double?`
- `coreClock: Double?`
- `memoryClock: Double?`
- `fanSpeed: Int?`
- `vendor: String?`
- `cores: Int?`
## Acceptance
- [ ] PerGpuContainer.swift created with title bar, gauges row, charts row
- [ ] 4 gauges display: Temperature, Utilization, Render, Tiler
- [ ] 4 line charts display 120-point history per metric
- [ ] Details panel expands/collapses on DETAILS button
- [ ] Status indicator dot shows GPU state
- [ ] Component uses standardized heights (title: 24px, gauges: 50px, charts: 60px)
- [ ] Handles missing GPU data gracefully (optional fields)
## Done summary
- Task completed
## Evidence
- Commits:
- Tests:
- PRs: