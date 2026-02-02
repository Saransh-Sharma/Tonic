# fn-8-v3b.3 Create PressureGaugeView component

## Description
Create `PressureGaugeView.swift` component for memory pressure visualization matching Stats Master's 3-color arc gauge.

**Size:** M

**Files:**
- `Tonic/Tonic/MenuBarWidgets/Components/PressureGaugeView.swift` (NEW, ~150 lines)

## Approach

Create a SwiftUI view with:

1. **Size:** 80×80px frame
2. **Three-segment arc:**
   - Green arc: 0-50% pressure (normal)
   - Yellow arc: 50-80% pressure (warning)
   - Red arc: 80-100% pressure (critical)
3. **Needle:** Rotates based on pressure percentage
4. **Center text:** Shows pressure level or percentage
5. **Input:** `pressureLevel: MemoryPressure` enum and `pressurePercentage: Double` (0-100)

Use `TrimmedPath` and `rotationEffect` for arc segments. Use `ZStack` to layer needle over arcs.

Reference: Similar to existing `CPUCircularGaugeView` at `Tonic/Tonic/MenuBarWidgets/Views/CPUCircularGaugeView.swift` but with 3 segments instead of 1.

## Key Context

Memory pressure comes from `WidgetDataManager.memoryData.pressure` enum.
Pressure percentage should be calculated from `pressureValue` (0-100 scale).

Color values should use DesignTokens:
- Green: `DesignTokens.Colors.success` or `.green`
- Yellow: `DesignTokens.Colors.warning` or `.yellow`
- Red: `DesignTokens.Colors.error` or `.red`
## Acceptance
- [ ] PressureGaugeView.swift created in Components directory
- [ ] View renders at 80×80px size
- [ ] Green arc shows for 0-50% pressure
- [ ] Yellow arc shows for 50-80% pressure
- [ ] Red arc shows for 80-100% pressure
- [ ] Needle rotates correctly based on percentage
- [ ] Center text displays pressure percentage
- [ ] Component uses @Observable pattern for reactive updates
## Done summary
- Task completed
## Evidence
- Commits:
- Tests:
- PRs: