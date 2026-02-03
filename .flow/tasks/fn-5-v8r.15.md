# fn-5-v8r.15 Active Widgets horizontal layout refactor

## Description
Refactor Active Widgets section from vertical list to horizontal layout following Stats Master. Preserve widget ordering semantics and maintain preview visibility.

## Implementation

Modify ActiveWidgetsSection in WidgetsPanelView:

```swift
struct ActiveWidgetsSection: View {
    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: DesignTokens.Spacing.sm) {
                ForEach(activeWidgets) { widget in
                    WidgetPreviewCard(widget: widget)
                        .frame(width: 120, height: 80)
                }
            }
        }
    }
}
```

## Acceptance
- [ ] Active widgets in horizontal scroll
- [ ] Widget order preserved logically
- [ ] Widget preview remains visible
- [ ] Overflow handled correctly
- [ ] Order persists across restarts

## Done summary
Refactored Active Widgets section to horizontal layout with preserved ordering.

## References
- Current: Tonic TBD (vertical list exists)
- Stats Master: Horizontal widget dock
