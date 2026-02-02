# fn-6-i4g.47 CPU Popover Dashboard Section

## Description

Create the dashboard section for CPU popover with 3 gauges: pie chart (System/User/Idle), temperature gauge, frequency gauge.

**REFERENCE**: Read `stats-master/Modules/CPU/popup.swift` first - dashboard section

Stats Master's CPU dashboard has:
- Left: Full pie chart showing System/User/Idle split
- Center: Half-circle gauge for temperature
- Right: Half-circle gauge for frequency
- All gauges ~70px wide
- Total section height: ~90px

## Dependencies

- Task 29 (CPU Data Layer) - must have System/User/Idle data
- Task 30 (Dashboard Gauge Components) - needs CircularGaugeView, HalfCircleGaugeView

## Files to Create

1. **Tonic/Tonic/MenuBarWidgets/Popovers/CPUPopoverView.swift** (dashboard section)

## Implementation

```swift
// File: Tonic/Tonic/MenuBarWidgets/Popovers/CPUPopoverView.swift

import SwiftUI

struct CPUPopoverView: View {
    @ObservedObject private var dataManager = WidgetDataManager.shared

    var body: some View {
        // ... header and rest of popover

        // DASHBOARD SECTION (90px)
        dashboardSection
            .padding(.vertical, 12)
    }

    // MARK: - Dashboard Section

    private var dashboardSection: some View {
        HStack(spacing: 20) {
            // 1. System/User/Idle pie chart
            CircularGaugeView(
                segments: [
                    (dataManager.cpuData.systemUsage, Color(red: 1, green: 0.3, blue: 0.2)),    // System - red
                    (dataManager.cpuData.userUsage, Color(red: 0.2, green: 0.5, blue: 1)),       // User - blue
                    (dataManager.cpuData.idleUsage, Color.gray.opacity(0.3))                     // Idle - gray
                ],
                centerText: "\(Int(dataManager.cpuData.totalUsage))%",
                centerSubtitle: "Usage"
            )

            // 2. Temperature gauge
            HalfCircleGaugeView(
                value: dataManager.cpuData.temperature ?? 0,
                maxValue: 100,
                label: "Temp",
                unit: "°C",
                color: temperatureColor(dataManager.cpuData.temperature ?? 0)
            )

            // 3. Frequency gauge
            HalfCircleGaugeView(
                value: dataManager.cpuData.frequency ?? 0,
                maxValue: 5.0,
                label: "Freq",
                unit: "GHz",
                color: .purple
            )
        }
        .frame(height: 90)
    }

    private func temperatureColor(_ temp: Double) -> Color {
        switch temp {
        case 0..<50: return .green
        case 50..<70: return .yellow
        case 70..<85: return .orange
        default: return .red
        }
    }
}
```

## Layout

```
┌─────────────────────────────────────────────────────────────────────┐
│ DASHBOARD SECTION (90px)                                            │
│ ┌─────────────────────────────────────────────────────────────────┐ │
│ │  ┌────────┐  ┌────────┐  ┌────────┐                           │ │
│ │  │ Pie    │  │ Temp   │  │ Freq   │                           │ │
│ │  │ Chart  │  │ Gauge  │  │ Gauge  │                           │ │
│ │  │ 68%    │  │ 45°C   │  │ 3.2GHz │                           │ │
│ │  │        │  │        │  │        │                           │ │
│ │  └────────┘  └────────┘  └────────┘                           │ │
│ └─────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

## Acceptance

- [ ] Dashboard section displays 3 gauges horizontally
- [ ] Left gauge: Pie chart with System (red), User (blue), Idle (gray)
- [ ] Center text shows total usage percentage
- [ ] Center gauge: Half-circle temperature with color coding
- [ ] Right gauge: Half-circle frequency in GHz
- [ ] Section height: 90px with 12px vertical padding
- [ ] Gauges animate smoothly when values change
- [ ] Colors match Stats Master (red/blue/gray for pie, temp gradient, purple for freq)
- [ ] Works with temperature unit toggle (°C/°F from Task 35a)

## Done summary

Created CPU popover dashboard section with 3 gauges: System/User/Idle pie chart, temperature half-gauge, frequency half-gauge. Matches Stats Master's 90px height layout.

## Evidence

- Commits: 0648814bbc539e6b412fbaa9f638cd5ada62d4da
- Tests: xcodebuild -scheme Tonic -configuration Debug build -destination 'platform=macOS'
- PRs:

## Reference Implementation

**Stats Master**: `stats-master/Modules/CPU/popup.swift`
- Dashboard section (lines 50-120)
- Gauge component usage
- Color scheme matching
