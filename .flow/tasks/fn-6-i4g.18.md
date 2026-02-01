# fn-6-i4g.18 Popover Layout Standardization

## Description
Standardize all widget popover layouts to match PRD specifications. Currently popovers have inconsistent layouts - this task creates a unified template with consistent dimensions, sections, and styling.

**Size:** M
**Files:**
- `Tonic/Tonic/MenuBarWidgets/Popovers/PopoverConstants.swift` (new)
- `Tonic/Tonic/MenuBarWidgets/Popovers/PopoverTemplate.swift` (new)
- `Tonic/Tonic/MenuBarWidgets/CPUWidgetView.swift` (refactor popover)
- `Tonic/Tonic/MenuBarWidgets/MemoryWidgetView.swift` (refactor popover)
- `Tonic/Tonic/MenuBarWidgets/DiskWidgetView.swift` (refactor popover)
- `Tonic/Tonic/MenuBarWidgets/NetworkWidgetView.swift` (refactor popover)
- `Tonic/Tonic/MenuBarWidgets/GPUWidgetView.swift` (refactor popover)
- `Tonic/Tonic/MenuBarWidgets/BatteryWidgetView.swift` (refactor popover)
- `Tonic/Tonic/MenuBarWidgets/SensorsWidgetView.swift` (if exists, refactor)

## Approach

- Create `PopoverConstants` struct with PRD layout values at `Popovers/PopoverConstants.swift`
- Create reusable `PopoverTemplate` view that provides standard header, sections, and styling
- Refactor each widget's popover to use template pattern
- Follow existing design patterns from `Design/DesignComponents.swift`

## Key Context

**PRD Layout Constants**:
```swift
struct PopoverConstants {
    static let width: CGFloat = 280
    static let maxHeight: CGFloat = 500
    static let headerHeight: CGFloat = 44
    static let sectionSpacing: CGFloat = 12
    static let itemSpacing: CGFloat = 8
    static let horizontalPadding: CGFloat = 16
    static let cornerRadius: CGFloat = 12
}
```

**Standard sections**:
1. Header (44pt): Module icon + title + settings gear
2. Dashboard (variable): Large primary metric + main visualization
3. Details Grid (variable): Two-column key-value pairs
4. Chart Section (optional, ~120pt): Full-width chart
5. Process List (optional, variable): Top processes by usage
## Acceptance
- [x] `PopoverConstants` struct created with PRD-specified values
- [x] `PopoverTemplate` provides reusable header with icon, title, settings button
- [x] All 6 main widget popovers use consistent 280pt width (CPU, Memory, Disk, Network, GPU, Battery)
- [x] All popovers have consistent section spacing (12pt)
- [x] Details grids use two-column layout with 8pt item spacing
- [x] Process list section configurable via ProcessListWidgetView maxCount parameter
- [x] Chart section appears where applicable (CPU, Memory, Network, GPU)
- [x] Settings gear button available in PopoverTemplate header
- [x] Dark/light mode styling consistent via DesignTokens colors
- [x] Header icons use correct SF Symbols per widget type (PopoverConstants.Icons)

## Done summary
- Task completed
## Evidence
- Commits:
- Tests:
- PRs: