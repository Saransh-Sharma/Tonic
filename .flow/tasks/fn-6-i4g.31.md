# fn-6-i4g.31 Create Core Cluster Component

## Description

Create E/P core grouped bar component for CPU popover. Stats Master visually groups efficiency and performance cores with different colors and labels.

## New Files to Create

1. **Tonic/Tonic/Components/CoreClusterBarView.swift**

## Component Specifications

### CoreClusterBarView

**Purpose**: Display per-core usage with E/P core grouping and color-coding

**Props**:
- `eCores: [(index: Int, usage: Double)]` - Efficiency core values
- `pCores: [(index: Int, usage: Double)]` - Performance core values
- `barHeight: CGFloat` - Height of each bar (default: 8)
- `barSpacing: CGFloat` - Space between bars (default: 4)
- `showLabels: Bool` - Show E/P core labels (default: true)

## Implementation

```swift
// File: Tonic/Tonic/Components/CoreClusterBarView.swift

import SwiftUI

struct CoreClusterBarView: View {
    let eCores: [(index: Int, usage: Double)]
    let pCores: [(index: Int, usage: Double)]
    var barHeight: CGFloat = 8
    var barSpacing: CGFloat = 4
    var showLabels: Bool = true

    // E-cores: cool blue/green
    private var eCoreColor: Color {
        Color(red: 0.3, green: 0.7, blue: 0.9)
    }

    // P-cores: warm orange/red
    private var pCoreColor: Color {
        Color(red: 0.9, green: 0.5, blue: 0.2)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showLabels && !eCores.isEmpty {
                HStack {
                    Text("Efficiency")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(eCoreColor)
                    Spacer()
                    Text("\(eCores.count) cores")
                        .font(.system(size: 9))
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
            }

            if !eCores.isEmpty {
                coreBarGroup(eCores, color: eCoreColor)
            }

            if showLabels && !pCores.isEmpty {
                HStack {
                    Text("Performance")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(pCoreColor)
                    Spacer()
                    Text("\(pCores.count) cores")
                        .font(.system(size: 9))
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
            }

            if !pCores.isEmpty {
                coreBarGroup(pCores, color: pCoreColor)
            }
        }
    }

    @ViewBuilder
    private func coreBarGroup(_ cores: [(Int, Double)], color: Color) -> some View {
        VStack(alignment: .leading, spacing: barSpacing) {
            ForEach(cores, id: \.0) { core in
                coreBar(usage: core.1, color: color, label: "Core \(core.0)")
            }
        }
    }

    private func coreBar(usage: Double, color: Color, label: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .frame(width: 50, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.15))

                    // Fill
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: geometry.size.width * (usage / 100))
                        .animation(.easeInOut(duration: 0.2), value: usage)
                }
            }
            .frame(height: barHeight)

            Text("\(Int(usage))%")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(DesignTokens.Colors.text)
                .frame(width: 30, alignment: .trailing)
        }
    }
}
```

## Usage Example

```swift
// In CPUPopoverView.swift

CoreClusterBarView(
    eCores: cpuData.eCoreUsage?.enumerated().map { ($0, $1) } ?? [],
    pCores: cpuData.pCoreUsage?.enumerated().map { ($0, $1) } ?? [],
    barHeight: 8,
    barSpacing: 4,
    showLabels: true
)
```

## Acceptance

- [ ] E-cores display with cool blue color
- [ ] P-cores display with warm orange color
- [ ] Core type labels (Efficiency/Performance) shown
- [ ] Individual cores labeled "Core 0", "Core 1", etc.
- [ ] Percentage values displayed right-aligned
- [ ] Bars animate smoothly when values change
- [ ] Empty core arrays handled gracefully
- [ ] Component works with Intel Macs (no E/P split)

## Done summary
Created E/P core grouped bar component with color-coding for efficiency (cool blue) and performance (warm orange) CPU cores. Handles Apple Silicon E/P split and Intel Macs gracefully.
## Evidence
- Commits: 8cd9bc2ab659e0a5236769b62283a012cc1ba49f
- Tests: xcodebuild -scheme Tonic -configuration Debug build
- PRs: