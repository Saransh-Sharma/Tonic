# fn-6-i4g.48 CPU Popover Charts Details Load Frequency

## Description

Create the remaining CPU popover sections: usage history chart, per-core bars (E/P grouped), details section (color-coded rows), load average (1/5/15 min), and frequency section (all/E/P cores in MHz).

**REFERENCE**: Read `stats-master/Modules/CPU/popup.swift` first - all sections below dashboard

Stats Master's CPU popup sections (below dashboard):
1. Usage history line chart (70px)
2. Per-core bar chart (E/P grouped, color-coded)
3. Details: System/User/Idle rows with colored dots
4. Load average: 1/5/15 minute values
5. Frequency section: all cores, E-cores, P-cores in MHz
6. Scheduler/Speed limits: Intel-specific (OPTIONAL - may skip)

## Dependencies

- Task 29 (CPU Data Layer) - needs load average, frequency arrays
- Task 31 (Core Cluster Component) - for E/P grouped bars
- Task 30 (Dashboard Gauge Components) - already done

## Files to Modify

1. **Tonic/Tonic/MenuBarWidgets/Popovers/CPUPopoverView.swift** - add remaining sections

## Implementation

```swift
// File: Tonic/Tonic/MenuBarWidgets/Popovers/CPUPopoverView.swift

// ... existing dashboard section

// MARK: - History Chart Section

private var historyChartSection: some View {
    VStack(alignment: .leading, spacing: 8) {
        Text("Usage History")
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(DesignTokens.Colors.textSecondary)

        LineChartView(
            data: dataManager.cpuHistory,
            color: DesignTokens.Colors.accent,
            showGrid: true
        )
        .frame(height: 70)
    }
}

// MARK: - Per-Core Section (E/P Grouped)

private var coreUsageSection: some View {
    VStack(alignment: .leading, spacing: 8) {
        Text("Per-Core Usage")
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(DesignTokens.Colors.textSecondary)

        CoreClusterBarView(
            eCores: (dataManager.cpuData.eCoreUsage ?? []).enumerated().map { ($0, $1) },
            pCores: (dataManager.cpuData.pCoreUsage ?? []).enumerated().map { ($0, $1) }
        )
    }
}

// MARK: - Details Section (System/User/Idle)

private var detailsSection: some View {
    HStack(spacing: 16) {
        detailDot("System", value: dataManager.cpuData.systemUsage, color: .red)
        detailDot("User", value: dataManager.cpuData.userUsage, color: .blue)
        detailDot("Idle", value: dataManager.cpuData.idleUsage, color: .gray)
    }
}

private func detailDot(_ label: String, value: Double, color: Color) -> some View {
    HStack(spacing: 6) {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)

        Text("\(label): \(Int(value))%")
            .font(.system(size: 10))
            .foregroundColor(DesignTokens.Colors.text)
    }
}

// MARK: - Load Average Section

private var loadAverageSection: some View {
    VStack(alignment: .leading, spacing: 8) {
        Text("Load Average")
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(DesignTokens.Colors.textSecondary)

        HStack(spacing: 12) {
            loadItem("1 min", value: dataManager.cpuData.loadAverage[safe: 0])
            loadItem("5 min", value: dataManager.cpuData.loadAverage[safe: 1])
            loadItem("15 min", value: dataManager.cpuData.loadAverage[safe: 2])
        }
    }
}

private func loadItem(_ label: String, value: Double?) -> some View {
    VStack(spacing: 2) {
        Text(label)
            .font(.system(size: 9))
            .foregroundColor(DesignTokens.Colors.textSecondary)

        Text(String(format: "%.2f", value ?? 0))
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(DesignTokens.Colors.text)
    }
    .frame(maxWidth: .infinity)
}

// MARK: - Frequency Section

private var frequencySection: some View {
    VStack(alignment: .leading, spacing: 8) {
        Text("Frequency")
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(DesignTokens.Colors.textSecondary)

        // All cores average
        frequencyRow("All Cores", value: dataManager.cpuData.frequency)

        // E-cores average (if available)
        if let eCoreFreq = dataManager.cpuData.eCoreFrequency {
            frequencyRow("E-Cores", value: eCoreFreq)
        }

        // P-cores average (if available)
        if let pCoreFreq = dataManager.cpuData.pCoreFrequency {
            frequencyRow("P-Cores", value: pCoreFreq)
        }
    }
}

private func frequencyRow(_ label: String, value: Double?) -> some View {
    HStack {
        Text(label)
            .font(.system(size: 10))
            .foregroundColor(DesignTokens.Colors.textSecondary)
            .frame(width: 80, alignment: .leading)

        Text("\(String(format: "%.1f", value ?? 0)) GHz")
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(DesignTokens.Colors.text)

        Spacer()
    }
}

// Helper for safe array access
extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
```

## Complete CPU Popover Structure

```
┌─────────────────────────────────────────────────────────────────────┐
│ HeaderView: [Icon] CPU [Activity Monitor → Close] [Settings]        │
├─────────────────────────────────────────────────────────────────────┤
│ DASHBOARD (90px)                                                     │
│ ┌──────────┐ ┌──────────┐ ┌──────────┐                             │
│ │ Pie Chart│ │ Temp     │ │ Freq     │                             │
│ │  68%     │ │ 45°C     │ │ 3.2GHz   │                             │
│ └──────────┘ └──────────┘ └──────────┘                             │
├─────────────────────────────────────────────────────────────────────┤
│ USAGE HISTORY (70px)                                                │
│ ╱╲╱╲╱╲╱╲╱╲╱╲╱╲╱╲                                                    │
├─────────────────────────────────────────────────────────────────────┤
│ PER-CORE USAGE                                                      │
│ Efficiency (8 cores)                                                │
│ Core 0 ████████░ 78%  Core 1 ██████░░░ 62%                          │
│ Performance (4 cores)                                               │
│ Core 8 ████████░ 89%  Core 9 ███████░░ 75%                          │
├─────────────────────────────────────────────────────────────────────┤
│ DETAILS                                                             │
│ ● System: 25%  ● User: 43%  ● Idle: 32%                           │
├─────────────────────────────────────────────────────────────────────┤
│ LOAD AVERAGE                                                        │
│ 1 min: 2.45    5 min: 2.12    15 min: 1.87                         │
├─────────────────────────────────────────────────────────────────────┤
│ FREQUENCY                                                           │
│ All Cores    3.2 GHz                                                │
│ E-Cores      2.1 GHz                                                │
│ P-Cores      3.8 GHz                                                │
└─────────────────────────────────────────────────────────────────────┘
```

## Acceptance

- [ ] Usage history chart displays line graph
- [ ] Per-core section shows E/P grouped bars with color-coding
- [ ] Details section shows System/User/Idle with colored dots
- [ ] Load average shows 1/5/15 min values
- [ ] Frequency section shows all cores, E-cores, P-cores in GHz
- [ ] All sections have proper headers and spacing
- [ ] Section dividers render correctly
- [ ] Missing data handled gracefully (optional sections hide if no data)

## Done Summary

Created CPU popover sections: history chart, E/P grouped core bars, color-coded details, load average, and frequency breakdown. Matches Stats Master's complete CPU popup structure.

## Evidence

- Commits:
- Tests:
- PRs:

## Reference Implementation

**Stats Master**: `stats-master/Modules/CPU/popup.swift`
- History chart section (lines 120-170)
- Core bars section (lines 170-250)
- Details section (lines 250-280)
- Load average section (lines 280-310)
- Frequency section (lines 310-380)
