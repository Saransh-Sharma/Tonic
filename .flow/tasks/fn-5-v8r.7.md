# fn-5-v8r.7 Line Chart widget implementation

## Description
Implement Line Chart widget type matching Stats Master's functionality. Line charts display real-time data with configurable history buffer (30-120 points) and scaling modes.

This is a high-value widget type that doesn't exist in Tonic today.

## Implementation

Create `Tonic/Tonic/MenuBarWidgets/Views/LineChartWidgetView.swift`:

```swift
struct LineChartWidgetView: View {
    let data: [Double]
    let config: LineChartConfig

    var body: some View {
        // SwiftUI Path-based line chart
        // Configurable: history size, scaling mode, colors
    }
}

struct LineChartConfig {
    let historySize: Int  // 30-120
    let scaling: ScalingMode  // linear, square, cube, log
    let showBackground: Bool
    let lineColor: Color
    let fillColor: Color
}

enum ScalingMode {
    case linear, square, cube, logarithmic
}
```

Data buffer: Circular buffer for history (matching Stats Master's pattern).

## Acceptance
- [ ] Line chart renders data points as connected path
- [ ] History buffer configurable 30-120 points
- [ ] All scaling modes work correctly
- [ ] Colors follow Tonic design tokens
- [ ] Performance: 60 FPS with full history

## Done summary
Implemented Line Chart widget with configurable history buffer and scaling modes.

## References
- Stats Master: `stats-master/Kit/Widgets/LineChart.swift`
- Design tokens: `Tonic/Tonic/Design/DesignTokens.swift`
