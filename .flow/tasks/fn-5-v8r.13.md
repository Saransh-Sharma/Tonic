# fn-5-v8r.13 WidgetsPanelView main configuration UI

## Description
Create main Widgets Panel View following Stats Master's settings pattern. This is the primary UI for widget configuration - where users add, remove, and manage widgets.

Current Tonic has placeholder at `WidgetsPanelView` (file doesn't exist).

## Implementation

Create `Tonic/Tonic/Views/WidgetsPanelView.swift`:

```swift
struct WidgetsPanelView: View {
    @State private var viewModel = WidgetPanelViewModel()

    var body: some View {
        VStack(spacing: 0) {
            AvailableWidgetsSection()
            Divider()
            ActiveWidgetsSection()  // Horizontal layout
        }
    }
}
```

Components:
1. **AvailableWidgetsSection**: List of all widget types with drag-to-add
2. **ActiveWidgetsSection**: Horizontal scroll of active widgets (task 15)

Use `DesignComponents.Card` for widget cards.
Use `DesignTokens.Spacing` for consistent gaps.

## Acceptance
- [ ] All widget types displayed in available section
- [ ] Drag-and-drop to add widgets
- [ ] Active widgets shown in horizontal layout
- [ ] Tonic design tokens applied throughout
- [ ] Navigate from ContentView sidebar works

## Done summary
Created WidgetsPanelView with available/active widget sections following Stats Master's pattern with Tonic's design language.

## References
- Stats Master: `stats-master/Kit/module/settings.swift:196-242`
- Tonic navigation: `Tonic/Tonic/Views/ContentView.swift:167-168`
- Design: `Tonic/Tonic/Design/DesignComponents.swift`
