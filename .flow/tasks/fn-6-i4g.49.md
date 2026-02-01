# fn-6-i4g.49 CPU Popover Processes Integration

## Description

Complete CPU popover by adding the top processes section using ProcessesView component, and integrate all sections into the final CPUPopoverView.

**REFERENCE**: Read `stats-master/Modules/CPU/popup.swift` first - processes section and overall structure

## Dependencies

- Task 29 (CPU Data Layer) - needs process list
- Task 30c (ProcessesView) - reusable component
- Task 47 (Dashboard Section) - gauges
- Task 48 (Charts/Details) - other sections

## Files to Modify

1. **Tonic/Tonic/MenuBarWidgets/Popovers/CPUPopoverView.swift** - complete integration

## Implementation

```swift
// File: Tonic/Tonic/MenuBarWidgets/Popovers/CPUPopoverView.swift

import SwiftUI

struct CPUPopoverView: View {
    @ObservedObject private var dataManager = WidgetDataManager.shared
    @State private var isActivityMonitorMode = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HeaderView(
                title: "CPU",
                icon: "cpu.fill",
                isActivityMonitorMode: $isActivityMonitorMode,
                onSettingsTap: {
                    // Navigate to CPU settings
                    NotificationCenter.default.post(name: .showWidgetSettings, object: WidgetType.cpu)
                }
            )

            ScrollView {
                VStack(spacing: 16) {
                    // 1. Dashboard Section (Task 47)
                    dashboardSection

                    Divider()

                    // 2. History Chart (Task 48)
                    historyChartSection

                    Divider()

                    // 3. Per-Core Section (Task 48)
                    coreUsageSection

                    Divider()

                    // 4. Details Section (Task 48)
                    detailsSection

                    Divider()

                    // 5. Load Average (Task 48)
                    loadAverageSection

                    Divider()

                    // 6. Frequency Section (Task 48)
                    if dataManager.cpuData.frequency != nil {
                        frequencySection

                        Divider()
                    }

                    // 7. Top Processes (Task 30c + this task)
                    ProcessesView(
                        processes: dataManager.cpuProcesses,
                        title: "Top Processes",
                        maxCount: 5,
                        barColor: DesignTokens.Colors.accent
                    )
```
<!-- Updated by plan-sync: fn-6-i4g.32 used topCPUApps (AppResourceUsage) with custom processRow implementation, not ProcessesView component -->
                }
                .padding()
            }
        }
        .frame(width: 320, height: 500)
        .onAppear {
            // Refresh data when popover appears
            dataManager.updateAllData()
        }
    }

    // MARK: - All sections from Tasks 47-48

    // ... (dashboardSection, historyChartSection, coreUsageSection,
    //      detailsSection, loadAverageSection, frequencySection)
}
```

## Integration with Status Items

Update CPU status items to use the new popover:

```swift
// File: Tonic/Tonic/MenuBarWidgets/ChartStatusItems/PieChartStatusItem.swift

override func showPopover() {
    let popover = NSPopover()
    popover.behavior = .transient
    popover.contentViewController = NSHostingController(
        rootView: CPUPopoverView()
    )
    popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
}
```

## Complete Popover Structure

```
┌─────────────────────────────────────────────────────────────────────┐
│ HeaderView: [Icon] CPU [Activity Monitor → Close] [Settings]        │
├─────────────────────────────────────────────────────────────────────┤
│ 1. DASHBOARD (90px) - Pie + Temp + Freq gauges                      │
├─────────────────────────────────────────────────────────────────────┤
│ 2. USAGE HISTORY (70px) - Line chart                                │
├─────────────────────────────────────────────────────────────────────┤
│ 3. PER-CORE USAGE - E/P grouped bars                                │
├─────────────────────────────────────────────────────────────────────┤
│ 4. DETAILS - System/User/Idle color dots                           │
├─────────────────────────────────────────────────────────────────────┤
│ 5. LOAD AVERAGE - 1/5/15 min                                       │
├─────────────────────────────────────────────────────────────────────┤
│ 6. FREQUENCY - All/E/P cores in GHz                                │
├─────────────────────────────────────────────────────────────────────┤
│ 7. TOP PROCESSES - Configurable 0-15 items                         │
└─────────────────────────────────────────────────────────────────────┘
```

## Acceptance

- [ ] All 7 sections render in correct order
- [ ] Section dividers appear between sections
- [ ] Popover size: 320x500px
- [ ] Data refreshes when popover appears
- [ ] Activity Monitor mode keeps window open
- [ ] Settings button navigates to CPU settings
- [ ] Processes section shows top 5 CPU users
- [ ] Empty data handled gracefully (sections hide if no data)
- [ ] Scroll works if content exceeds height
- [ ] Popover closes when clicking outside (transient behavior)

## Done summary
Added frequency section to CPU popover showing all/E/P cores in GHz with color-coded display matching the core usage section. The section appears between load average and top processes, only when frequency data is available.
## Evidence
- Commits: 0141adfc6f9cc27d998733422edc4c6477d19ed5
- Tests: xcodebuild -scheme Tonic -configuration Debug build
- PRs:
## Reference Implementation

**Stats Master**: `stats-master/Modules/CPU/popup.swift`
- Complete popup structure (full file)
- Section ordering and spacing
- Data binding patterns
