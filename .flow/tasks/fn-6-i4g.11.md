# fn-6-i4g.11 OneView Mode

## Description
Implement OneView mode that combines all enabled widgets into a single menu bar item.

**Size:** M

**Files:**
- `Tonic/Tonic/MenuBarWidgets/OneViewStatusItem.swift` (new)
- `Tonic/Tonic/Views/OneViewContentView.swift` (new)
- `Tonic/Tonic/Models/WidgetConfiguration.swift` (modify - add unified mode flag)
- `Tonic/Tonic/Services/WidgetCoordinator.swift` (modify - handle OneView)

**OneView Widget**:
1. Single NSStatusItem showing all enabled widgets in a compact grid
2. Click opens unified popup with all widget details
3. Widgets arranged horizontally with dividers
4. Overflow handled with scroll or max widget limit

**Configuration**:
1. Add `unifiedMenuBarMode: Bool` to `WidgetPreferences`
2. Toggle in `WidgetCustomizationView`
3. When enabled: hide individual widgets, show OneView widget
4. When disabled: restore individual widgets, hide OneView

## Approach

1. Create `OneViewStatusItem` extending `WidgetStatusItem`
2. Create `OneViewContentView` with grid layout
3. Grid shows widget icons + values in compact form
4. On click: show `NSPopover` with scrollable list of all widget detail views
5. Add mode toggle to `WidgetPreferences`
6. Update `WidgetCoordinator.start()` to check mode and create appropriate widgets
7. Handle mode switch at runtime (stop individual, start OneView, or vice versa)

## Key Context

Stats Master calls this "oneView" mode. Reference `stats-master/Kit/module/MenuBar.swift` for the combined widget layout.

Grid layout suggestion: Use `LazyHGrid` with 3 rows max for typical menu bar height.

Max widgets: If >6 widgets enabled, scroll horizontal or show "...".

Reference: `WidgetFactory.swift:14-110` for widget creation patterns.
## Acceptance
- [ ] OneViewStatusItem created
- [ ] OneViewContentView with grid layout
- [ ] Shows all enabled widgets in compact form
- [ ] Click opens unified popover
- [ ] Popover scrollable for many widgets
- [ ] unifiedMenuBarMode flag in WidgetPreferences
- [ ] Mode toggle in WidgetCustomizationView
- [ ] Individual widgets hidden when OneView active
- [ ] Individual widgets restored when OneView disabled
- [ ] Mode switch works at runtime
- [ ] Menu bar overflow handled gracefully
## Done summary
TBD

## Evidence
- Commits:
- Tests:
- PRs:
