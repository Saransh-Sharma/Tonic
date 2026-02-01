# fn-6-i4g.46 Create ProcessesView.swift

## Description

Create reusable top processes component for widget popovers. Stats Master uses this in CPU, Memory, Disk, and Network popovers.

**REFERENCE**: Read `stats-master/Kit/plugins/DB.swift` (process list) and individual popup files

Stats Master's ProcessesView features:
- Configurable number of processes (0-15)
- Sortable by usage percentage
- Reusable across all widget popovers
- Shows process name, usage bar, percentage

## New Files to Create

1. **Tonic/Tonic/Components/ProcessesView.swift**

## Implementation

```swift
// File: Tonic/Tonic/Components/ProcessesView.swift

import SwiftUI

struct ProcessesView: View {
    let processes: [ProcessUsage]
    var title: String = "Top Processes"
    var maxCount: Int = 5
    var barColor: Color = DesignTokens.Colors.accent

    private var displayedProcesses: [ProcessUsage] {
        Array(processes.prefix(maxCount))
    }

    var body: some View {
        if !displayedProcesses.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                // Section header
                HStack {
                    Text(title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(DesignTokens.Colors.textSecondary)

                    Spacer()

                    Text("\(displayedProcesses.count) processes")
                        .font(.system(size: 9))
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }

                // Process list
                VStack(spacing: 6) {
                    ForEach(displayedProcesses, id: \.pid) { process in
                        processRow(process)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func processRow(_ process: ProcessUsage) -> some View {
        HStack(spacing: 8) {
            // Process icon (use app icon if available, else generic)
            Image(systemName: "app.fill")
                .font(.system(size: 10))
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .frame(width: 16)

            // Process name
            Text(process.name)
                .font(.system(size: 10))
                .foregroundColor(DesignTokens.Colors.text)
                .frame(width: 80, alignment: .leading)
                .lineLimit(1)
                .truncationMode(.tail)

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.15))

                    // Fill
                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor)
                        .frame(width: geometry.size.width * ((process.cpuUsage ?? 0) / 100))
                        .animation(.easeInOut(duration: 0.2), value: process.cpuUsage)
                }
            }
            .frame(height: 6)

            // Percentage
            Text("\(Int(process.cpuUsage ?? 0))%")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(DesignTokens.Colors.text)
                .frame(width: 30, alignment: .trailing)
        }
    }
}

// ProcessUsage model - use existing model from Models/ProcessUsage.swift
// The existing model has:
// - id: Int32 (PID)
// - name: String
// - cpuUsage: Double? (CPU percentage)
// - memoryUsage: UInt64? (bytes)
// - diskReadBytes, diskWriteBytes, networkBytes: UInt64?
// Note: Use process.cpuUsage instead of usagePercent

// Preview
#if DEBUG
struct ProcessesView_Previews: PreviewProvider {
    static var previews: some View {
        ProcessesView(
            processes: [
                .init(id: 1234, name: "Safari", cpuUsage: 45),
                .init(id: 5678, name: "Xcode", cpuUsage: 28),
                .init(id: 9012, name: "Chrome", cpuUsage: 18),
                .init(id: 3456, name: "Spotify", cpuUsage: 8),
                .init(id: 7890, name: "Finder", cpuUsage: 3)
            ],
            maxCount: 5,
            barColor: .blue
        )
        .padding()
        .frame(width: 280)
        .background(DesignTokens.Colors.background)
    }
}
#endif
```

## Usage Examples

### CPU Popover
```swift
ProcessesView(
    processes: dataManager.cpuProcesses,
    title: "Top Processes",
    maxCount: 5,
    barColor: DesignTokens.Colors.accent
)
```

### Memory Popover
```swift
ProcessesView(
    processes: dataManager.memoryProcesses,
    title: "Top Memory Users",
    maxCount: 8,
    barColor: .purple
)
```

### Disk Popover
```swift
ProcessesView(
    processes: dataManager.diskProcesses,
    title: "Top Disk Usage",
    maxCount: 5,
    barColor: .orange
)
```

## Acceptance

- [ ] ProcessesView displays configurable number of processes
- [ ] Shows process name, progress bar, percentage
- [ ] Bar color is customizable
- [ ] Max count is 0-15 (0 = hidden)
- [ ] Empty state handled gracefully (no crash when empty)
- [ ] Works with CPU, Memory, Disk process lists
- [ ] Animates smoothly when values change
- [ ] Process names truncate properly

## Done Summary

Created reusable ProcessesView component for displaying top processes across CPU, Memory, Disk, and Network popovers. Configurable count and color, matches Stats Master design.
<!-- Updated by plan-sync: Use existing ProcessUsage model with cpuUsage property, not usagePercent -->

## Evidence

- Commits:
- Tests:
- PRs:

## Reference Implementation

**Stats Master**:
- `stats-master/Modules/CPU/popup.swift` - process section
- `stats-master/Modules/Memory/popup.swift` - process section
- `stats-master/Kit/plugins/DB.swift` - process data storage
