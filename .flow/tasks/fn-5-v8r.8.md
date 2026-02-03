# fn-5-v8r.8 Bar Chart and Pie Chart widgets implementation

## Description
Implement Bar Chart and Pie Chart widget types matching Stats Master. Bar charts show vertical bars for multi-value data (CPU cores, memory zones). Pie charts show circular progress for percentages.

## Implementation

Create `BarChartWidgetView.swift`:
- Vertical bars for multi-value data
- Configurable bar width, colors
- Ideal for: CPU cores, memory zones

Create `PieChartWidgetView.swift`:
- Circular progress using `trim()` modifier
- Battery level, disk usage
- Configurable fill percentage, colors

## Acceptance
- [ ] Bar chart renders multiple values as vertical bars
- [ ] Pie chart renders circular progress
- [ ] Colors follow Tonic design tokens
- [ ] 60 FPS performance

## Done summary
Implemented Bar Chart and Pie Chart widgets with Tonic styling.

## References
- Stats Master: `stats-master/Kit/Widgets/BarChart.swift`, `PieChart.swift`
