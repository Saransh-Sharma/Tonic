# fn-6-i4g.9 Process Monitoring UI

## Description
Create SwiftUI UI component to display process resource usage in widget popovers.

**Size:** M

**Files:**
- `Tonic/Tonic/Views/ProcessListView.swift` (new)
- `Tonic/Tonic/MenuBarWidgets/Views/ProcessListWidgetView.swift` (new)
- `Tonic/Tonic/MenuBarWidgets/WidgetStatusItem.swift` (modify - integrate into popovers)

Create a reusable process monitoring list view:

1. **ProcessListView** component
```swift
struct ProcessListView: View {
    let processes: [ProcessUsage]
    let moduleType: WidgetType
    let maxCount: Int
}
```

Features:
- Display app icon, name, usage percentage
- Sortable by usage (descending by default)
- Color-coded usage bars (green → yellow → red)
- Show top N processes (default 5)
- Click on process to reveal in Finder or Activity Monitor

2. **Integration**: Add to each widget's popover:
- CPU widget → top CPU processes
- Memory widget → top memory processes
- Network widget → top network processes
- Disk widget → top disk I/O processes

## Approach

1. Create `ProcessListView.swift` in `Views/`
2. Use `DesignComponents.Card` for consistent styling
3. Use `DesignTokens.Colors` for usage-based coloring
4. Create row component: `ProcessRowView` with icon, name, value
5. Add click handler to reveal in Activity Monitor via `NSWorkspace.open(url:)`
6. Integrate into existing widget popovers
7. For widgets without popover views, create one

## Key Context

Stats Master shows this in every module's popup. Reference `stats-master/Kit/module/Popup.swift` for layout.

Tonic already collects `topCPUApps` and `topMemoryApps` in `WidgetDataManager.swift:1189-1219` — extend to all module types.

Activity Monitor deep link: `activitymanager://show/` or reveal in Finder then open.
## Acceptance
- [ ] ProcessListView component created
- [ ] ProcessRowView component created
- [ ] Shows app icon, name, usage percentage
- [ ] Sorted by usage descending
- [ ] Color-coded usage bars
- [ ] Click reveals in Activity Monitor
- [ ] Integrated into CPU widget popover
- [ ] Integrated into Memory widget popover
- [ ] Integrated into Network widget popover
- [ ] Integrated into Disk widget popover
- [ ] Follows DesignComponents patterns
- [ ] Uses DesignTokens for styling
## Done summary
Implemented process monitoring UI components for widget popovers. Created ProcessListWidgetView component that displays top processes for CPU, Memory, Network, and Disk usage with app icons, names, usage values, and color-coded usage bars. Integrated the component into all four widget detail views.
## Evidence
- Commits: d871cd510af1fc2aa1efa11cd6465b9dcd7ff955
- Tests: xcodebuild -project Tonic/Tonic.xcodeproj -scheme Tonic -configuration Debug build
- PRs: