# fn-6-i4g.32 CPU Popover Redesign

## Description

Replace current `CPUDetailView` with Stats Master-style dashboard layout. Current popover is generic and missing key sections (dashboard gauges, details, load average).

## Files to Modify/Create

1. **CREATE**: `Tonic/Tonic/MenuBarWidgets/Popovers/CPUPopoverView.swift`
2. **MODIFY**: `Tonic/Tonic/MenuBarWidgets/ChartStatusItems/PieChartStatusItem.swift` (to use new popover)
3. **MODIFY**: `Tonic/Tonic/MenuBarWidgets/ChartStatusItems/MiniChartStatusItem.swift` (to use new popover)

## New Popover Structure

```
┌─────────────────────────────────────────────────────────────────────┐
│ HeaderView: [Chart Icon] CPU    [Activity Monitor → Close] [Settings]│
├─────────────────────────────────────────────────────────────────────┤
│ DASHBOARD SECTION (90px)                                            │
│ ┌─────────────────────────────────────────────────────────────────┐ │
│ │  ┌────────┐  ┌────────┐  ┌────────┐                           │ │
│ │  │ Pie    │  │ Temp   │  │ Freq   │                           │ │
│ │  │ Chart  │  │ Gauge  │  │ Gauge  │                           │ │
│ │  │ 68%    │  │ 45°C   │  │ 3.2GHz │                           │ │
│ │  └────────┘  └────────┘  └────────┘                           │ │
│ └─────────────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────────────┤
│ HISTORY CHART (100px)                                               │
│ ┌─────────────────────────────────────────────────────────────────┐ │
│ │ Usage History (Line Chart - configurable scale/points)          │ │
│ └─────────────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────────────┤
│ PER-CORE SECTION (grouped by E/P)                                  │
│ ┌─────────────────────────────────────────────────────────────────┐ │
│ │ Efficiency (8 cores)                                            │ │
│ │ Core 0  ████████░  78%  Core 1  ██████░░░  62%                  │ │
│ │ Performance (4 cores)                                           │ │
│ │ Core 8  ████████░  89%  Core 9  ███████░░  75%                  │ │
│ └─────────────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────────────┤
│ DETAILS SECTION                                                     │
│ ┌─────────────────────────────────────────────────────────────────┐ │
│ │ ● System: 25%  ● User: 43%  ● Idle: 32%                        │ │
│ └─────────────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────────────┤
│ LOAD AVERAGE                                                        │
│ ┌─────────────────────────────────────────────────────────────────┐ │
│ │ 1 min: 2.45    5 min: 2.12    15 min: 1.87                      │ │
│ └─────────────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────────────┤
│ TOP PROCESSES                                                       │
│ ┌─────────────────────────────────────────────────────────────────┐ │
│ │ Safari        ████████░░  45%                                   │ │
│ │ Xcode         ████░░░░░░░  28%                                   │ │
│ │ Chrome        ██░░░░░░░░░  18%                                   │ │
│ └─────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

## Implementation

```swift
// File: Tonic/Tonic/MenuBarWidgets/Popovers/CPUPopoverView.swift

import SwiftUI

struct CPUPopoverView: View {
    @ObservedObject private var dataManager = WidgetDataManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HeaderView(
                title: "CPU",
                icon: "cpu.fill",
                showActivityMonitor: true
            )

            ScrollView {
                VStack(spacing: 16) {
                    // Dashboard Section
                    dashboardSection

                    Divider()

                    // History Chart
                    historyChartSection

                    Divider()

                    // Per-Core Section
                    coreUsageSection

                    Divider()

                    // Details Section
                    detailsSection

                    Divider()

                    // Load Average
                    loadAverageSection

                    Divider()

                    // Top Processes
                    topProcessesSection
                }
                .padding()
            }
        }
        .frame(width: 320, height: 500)
    }

    // MARK: - Dashboard Section

    private var dashboardSection: some View {
        HStack(spacing: 20) {
            // System/User/Idle pie chart
            CircularGaugeView(
                segments: [
                    (dataManager.cpuData.systemUsage, Color(red: 1, green: 0.3, blue: 0.2)),
                    (dataManager.cpuData.userUsage, Color(red: 0.2, green: 0.5, blue: 1)),
                    (dataManager.cpuData.idleUsage, Color.gray.opacity(0.3))
                ],
                centerText: "\(Int(dataManager.cpuData.totalUsage))%",
                centerSubtitle: "Usage"
            )

            // Temperature gauge
            HalfCircleGaugeView(
                value: dataManager.cpuData.temperature ?? 0,
                maxValue: 100,
                label: "Temp",
                unit: "°C",
                color: temperatureColor(dataManager.cpuData.temperature ?? 0)
            )

            // Frequency gauge
            HalfCircleGaugeView(
                value: dataManager.cpuData.frequency ?? 0,
                maxValue: 5.0,
                label: "Freq",
                unit: "GHz",
                color: .purple
            )
        }
        .padding(.vertical, 12)
        .frame(height: 90)
    }

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

    // MARK: - Core Usage Section

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

    // MARK: - Details Section

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
        HStack(spacing: 12) {
            loadItem("1 min", value: dataManager.cpuData.loadAverage[safe: 0])
            loadItem("5 min", value: dataManager.cpuData.loadAverage[safe: 1])
            loadItem("15 min", value: dataManager.cpuData.loadAverage[safe: 2])
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

    // MARK: - Top Processes Section

    private var topProcessesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Top Processes")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(DesignTokens.Colors.textSecondary)

            ForEach(dataManager.cpuProcesses.prefix(5), id: \.pid) { process in
                processBar(process)
            }
        }
    }

    private func processBar(_ process: ProcessUsage) -> some View {
        HStack(spacing: 8) {
            Text(process.name)
                .font(.system(size: 10))
                .foregroundColor(DesignTokens.Colors.text)
                .frame(width: 80, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.15))

                    RoundedRectangle(cornerRadius: 2)
                        .fill(DesignTokens.Colors.accent)
                        .frame(width: geometry.size.width * (process.cpuUsage / 100))
                }
            }
            .frame(height: 6)

            Text("\(Int(process.cpuUsage))%")
                .font(.system(size: 9))
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .frame(width: 30, alignment: .trailing)
        }
    }

    // MARK: - Helpers

    private func temperatureColor(_ temp: Double) -> Color {
        switch temp {
        case 0..<50: return .green
        case 50..<70: return .yellow
        case 70..<85: return .orange
        default: return .red
        }
    }
}

// Helper for safe array access
extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
```

## Acceptance

- [ ] Popover displays all 7 sections (dashboard, history, cores, details, load avg, processes, header)
- [ ] Dashboard shows 3 gauges (pie, temp, freq)
- [ ] E/P cores grouped with color-coding
- [ ] Load average shows 1/5/15 minute values
- [ ] Details section shows System/User/Idle with colored dots
- [ ] Top processes limited to 5 items with progress bars
- [ ] Header includes Activity Monitor toggle and Settings button
- [ ] Popover size: 320x500 (matching Stats Master)

## Done Summary

Created Stats Master-style CPU popover with dashboard gauges, grouped E/P cores, load average display, and details section. Replaced generic PopoverTemplate with widget-specific layout.

## Evidence

- Commits:
- Tests:
- PRs:
