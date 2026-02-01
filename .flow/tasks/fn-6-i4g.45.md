# fn-6-i4g.45 Create HeaderView.swift

## Description

Create reusable header component for widget popovers matching Stats Master's header design.

**REFERENCE**: Read `stats-master/Kit/module/popup.swift` (HeaderView section)

Stats Master's HeaderView features:
- Widget icon on left
- Widget title (e.g., "CPU")
- Activity Monitor toggle button → becomes "Close" when active
- Settings button (gear icon)
- Separator line below

## New Files to Create

1. **Tonic/Tonic/MenuBarWidgets/Popovers/HeaderView.swift**

## Implementation

```swift
// File: Tonic/Tonic/MenuBarWidgets/Popovers/HeaderView.swift

import SwiftUI

struct HeaderView: View {
    let title: String
    let icon: String
    @Binding var isActivityMonitorMode: Bool
    var onSettingsTap: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DesignTokens.Colors.accent)
                    .frame(width: 24)

                // Title
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(DesignTokens.Colors.text)

                Spacer()

                // Activity Monitor / Close button
                Button(action: {
                    isActivityMonitorMode.toggle()
                }) {
                    Text(isActivityMonitorMode ? "Close" : "Activity Monitor")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(isActivityMonitorMode ? .red : DesignTokens.Colors.accent)
                }
                .buttonStyle(.plain)
                .help(isActivityMonitorMode ? "Close (drag to keep open)" : "Keep window open when dragging")

                // Settings button
                Button(action: {
                    onSettingsTap?()
                }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12))
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
                .buttonStyle(.plain)
                .help("Widget settings")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(DesignTokens.Colors.surface)

            // Separator
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1)
        }
    }
}

// Convenience initializer without Activity Monitor
extension HeaderView {
    init(title: String, icon: String, showActivityMonitor: Bool = false) {
        self.title = title
        self.icon = icon
        self._isActivityMonitorMode = .constant(false)
        self.onSettingsTap = nil
    }
}
```

## Usage Example

```swift
// In CPUPopoverView.swift

struct CPUPopoverView: View {
    @State private var isActivityMonitorMode = false

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(
                title: "CPU",
                icon: "cpu.fill",
                isActivityMonitorMode: $isActivityMonitorMode,
                onSettingsTap: {
                    // Open settings for CPU widget
                    WidgetPreferences.shared.openSettings(for: .cpu)
                }
            )

            // Rest of popover content...
        }
    }
}
```

## Activity Monitor Behavior

When enabled:
- Window stays open after mouse leaves
- User can drag window to reposition
- Button text changes to "Close"
- Closing returns to normal behavior

## Acceptance

- [ ] HeaderView displays icon, title, Activity Monitor, Settings
- [ ] Activity Monitor toggle works (state binding)
- [ ] Settings button calls callback
- [ ] Separator line renders below header
- [ ] Background color matches surface token
- [ ] Works in dark mode
- [ ] Proper padding and spacing match Stats Master

## Done Summary

Created reusable HeaderView component for widget popovers. Features icon, title, Activity Monitor toggle, and Settings button matching Stats Master's header design.

## Evidence

- Commits:
- Tests:
- PRs:

## Reference Implementation

**Stats Master**: `stats-master/Kit/module/popup.swift`
- HeaderView class (lines 150-220)
- Activity Monitor toggle logic
