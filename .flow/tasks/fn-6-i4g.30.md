# fn-6-i4g.30 Create Dashboard Gauge Components

## Description

Create reusable gauge components for Stats Master-style dashboard row. Need two component types:
1. **CircularGaugeView** - Full pie chart for System/User/Idle split (like Stats Master CPU dashboard)
2. **HalfCircleGaugeView** - Semi-circle gauge for temperature and frequency display

## New Files to Create

1. **Tonic/Tonic/Components/CircularGaugeView.swift**
2. **Tonic/Tonic/Components/HalfCircleGaugeView.swift**
3. **Tonic/Tonic/Components/GaugeSegment.swift** (helper model)

## Component Specifications

### CircularGaugeView

**Purpose**: Display usage breakdown with colored segments (System/User/Idle or other multi-part data)

**Props**:
- `segments: [(value: Double, color: Color)]` - Array of value-color pairs
- `centerText: String` - Text to display in center (e.g., "68%")
- `centerSubtitle: String?` - Optional smaller text below
- `size: CGFloat` - Width/height (default: 70)
- `lineWidth: CGFloat` - Stroke width (default: 12)

**Example**:
```swift
CircularGaugeView(
    segments: [
        (45, Color.red),      // System
        (32, Color.blue),     // User
        (23, Color.gray)      // Idle
    ],
    centerText: "68%",
    centerSubtitle: "Total",
    size: 70
)
```

### HalfCircleGaugeView

**Purpose**: Display single value with semi-circle progress (temperature, frequency, etc.)

**Props**:
- `value: Double` - Current value
- `maxValue: Double` - Maximum for gauge (e.g., 100°C)
- `minValue: Double` - Minimum (default: 0)
- `label: String?` - Text below gauge
- `unit: String?` - Unit symbol (°C, GHz)
- `color: Color` - Progress color
- `size: CGSize` - Width x height (default: 80x50)
- `lineWidth: CGFloat` - Stroke width (default: 10)

**Example**:
```swift
HalfCircleGaugeView(
    value: 45,
    maxValue: 100,
    label: "Temperature",
    unit: "°C",
    color: .orange,
    size: CGSize(width: 80, height: 50)
)
```

## Implementation: CircularGaugeView

```swift
// File: Tonic/Tonic/Components/CircularGaugeView.swift

import SwiftUI

struct CircularGaugeView: View {
    let segments: [(value: Double, color: Color)]
    let centerText: String
    var centerSubtitle: String? = nil
    var size: CGFloat = 70
    var lineWidth: CGFloat = 12

    private var totalValue: Double {
        segments.reduce(0) { $0 + $1.value }
    }

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: lineWidth)
                .frame(width: size, height: size)

            // Draw segments
            ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                let startAngle = startAngleForSegment(index)
                let endAngle = endAngleForSegment(index)

                Circle()
                    .trim(from: startAngle, to: endAngle)
                    .stroke(segment.color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: segment.value)
            }

            // Center text
            VStack(spacing: 2) {
                Text(centerText)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignTokens.Colors.text)

                if let subtitle = centerSubtitle {
                    Text(subtitle)
                        .font(.system(size: 9, weight: .regular))
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
            }
        }
        .frame(width: size, height: size)
    }

    private func startAngleForSegment(_ index: Int) -> Double {
        let previousValues = segments.prefix(index).reduce(0) { $0 + $1.value }
        return previousValues / totalValue
    }

    private func endAngleForSegment(_ index: Int) -> Double {
        let valuesIncludingSelf = segments.prefix(index + 1).reduce(0) { $0 + $1.value }
        return valuesIncludingSelf / totalValue
    }
}
```

## Implementation: HalfCircleGaugeView

```swift
// File: Tonic/Tonic/Components/HalfCircleGaugeView.swift

import SwiftUI

struct HalfCircleGaugeView: View {
    let value: Double
    let maxValue: Double
    var minValue: Double = 0
    var label: String? = nil
    var unit: String? = nil
    var color: Color = DesignTokens.Colors.accent
    var size: CGSize = CGSize(width: 80, height: 50)
    var lineWidth: CGFloat = 10

    private var fillFraction: Double {
        let clamped = max(minValue, min(maxValue, value))
        return (clamped - minValue) / (maxValue - minValue)
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Background semi-circle
                Path { path in
                    path.addArc(
                        center: CGPoint(x: size.width / 2, y: size.height),
                        radius: size.width / 2 - lineWidth / 2,
                        startAngle: .degrees(180),
                        endAngle: .degrees(0),
                        clockwise: false
                    )
                }
                .stroke(color.opacity(0.2), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

                // Fill semi-circle
                Path { path in
                    path.addArc(
                        center: CGPoint(x: size.width / 2, y: size.height),
                        radius: size.width / 2 - lineWidth / 2,
                        startAngle: .degrees(180),
                        endAngle: .degrees(180 + (360 * fillFraction / 2)),
                        clockwise: false
                    )
                }
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .animation(.easeInOut(duration: 0.3), value: fillFraction)

                // Value text
                Text("\(Int(value))\(unit ?? "")")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DesignTokens.Colors.text)
                    .offset(y: 10)
            }
            .frame(width: size.width, height: size.height)

            if let label = label {
                Text(label)
                    .font(.system(size: 8))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
        }
    }
}
```

## Usage Example (CPU Dashboard Row)

```swift
// In CPUPopoverView.swift

HStack(spacing: 20) {
    // System/User/Idle pie chart
    CircularGaugeView(
        segments: [
            (cpuData.systemUsage, Color(red: 1, green: 0.3, blue: 0.2)),
            (cpuData.userUsage, Color(red: 0.2, green: 0.5, blue: 1)),
            (cpuData.idleUsage, Color.gray.opacity(0.3))
        ],
        centerText: "\(Int(cpuData.totalUsage))%",
        centerSubtitle: "Usage"
    )

    // Temperature gauge
    HalfCircleGaugeView(
        value: cpuData.temperature ?? 0,
        maxValue: 100,
        label: "Temp",
        unit: "°C",
        color: temperatureColor(cpuData.temperature ?? 0)
    )

    // Frequency gauge
    HalfCircleGaugeView(
        value: cpuData.frequency ?? 0,
        maxValue: 5.0,
        label: "Freq",
        unit: "GHz",
        color: .purple
    )
}
.padding(.vertical, 12)
.frame(height: 90)
```

## Acceptance

- [ ] CircularGaugeView displays multiple colored segments
- [ ] CircularGaugeView animates value changes smoothly
- [ ] HalfCircleGaugeView fills from left to right
- [ ] HalfCircleGaugeView animates smoothly
- [ ] Both components work in dark mode
- [ ] Components scale correctly at different sizes
- [ ] Zero values handled gracefully (no divide-by-zero)
- [ ] CPU dashboard row displays all three gauges correctly

## Done summary
Created reusable gauge components for Stats Master-style dashboard display. CircularGaugeView for multi-segment data (System/User/Idle), HalfCircleGaugeView for single-value gauges (temperature, frequency).
## Evidence
- Commits: 0def1efe77ccb18a2acc04c2e06bd124782fd545
- Tests: xcodebuild -scheme Tonic -configuration Debug build
- PRs: