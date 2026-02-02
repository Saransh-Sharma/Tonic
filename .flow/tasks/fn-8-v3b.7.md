# fn-8-v3b.7 Update GPUPopoverView with per-GPU architecture

## Description
Update `GPUPopoverView.swift` to use `PerGpuContainer` for each GPU, enabling multi-GPU support.

**Size:** M

**Files:**
- `Tonic/Tonic/MenuBarWidgets/Popovers/GPUPopoverView.swift` (~378 lines)
- `Tonic/Tonic/Services/WidgetDataManager.swift` (add GPU data properties)

## Approach

1. Update `GPUData` struct to add per-metric history:
   ```swift
   public let renderHistory: [Double]
   public let tilerHistory: [Double]
   public let temperatureHistory: [Double]
   public let utilizationHistory: [Double]
   ```

2. Add missing properties for display:
   ```swift
   public let renderUtilization: Double?
   public let tilerUtilization: Double?
   public let coreClock: Double?
   public let memoryClock: Double?
   public let fanSpeed: Int?
   public let vendor: String?
   public let cores: Int?
   ```

3. Refactor `GPUPopoverView` to:
   - Loop through GPUs array (if multiple) or show single GPU
   - Use `PerGpuContainer` for each GPU
   - Stack vertically with spacing

4. Handle single GPU case gracefully (most Macs)

## Key Context

Current `GPUPopoverView` shows combined view. Stats Master shows per-GPU containers.

Apple Silicon GPU metrics come from Metal framework `MTLCreateSystemDefaultDevice()` and `IORegistry` for power stats.

Intel Macs may have no GPU data or only integrated Intel GPU - show empty state or "unsupported" message.

Reference: Stats Master GPU module at `stats-master/Modules/GPU/popup.swift` for data collection patterns.
## Acceptance
- [ ] GPUData struct has render/tiler utilization and history
- [ ] GPUData has metadata: coreClock, memoryClock, fanSpeed, vendor, cores
- [ ] GPUPopoverView uses PerGpuContainer for each GPU
- [ ] Multiple GPUs stack vertically
- [ ] Single GPU displays correctly (most common case)
- [ ] Intel Macs without GPU show appropriate empty state
- [ ] All 4 metrics show in gauges and charts
## Done summary
- Task completed
## Evidence
- Commits:
- Tests:
- PRs: