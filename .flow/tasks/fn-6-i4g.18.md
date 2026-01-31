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
- [ ] `PopoverConstants` struct created with PRD-specified values
- [ ] `PopoverTemplate` provides reusable header with icon, title, settings button
- [ ] All 8 widget popovers use consistent 280pt width
- [ ] All popovers have consistent section spacing (12pt)
- [ ] Details grids use two-column layout with 8pt item spacing
- [ ] Process list section configurable (0, 3, 5, 8, 10, 15 rows)
- [ ] Chart section appears where applicable (CPU, Memory, Network, GPU)
- [ ] Settings gear button opens widget-specific settings
- [ ] Dark/light mode styling consistent across all popovers
- [ ] Header icons use correct SF Symbols per widget type
## Done summary
TBD

## Evidence
- Commits:
- Tests:
- PRs:
