# fn-5-v8r.16 Drag-and-drop widget reordering

## Description
Implement drag-and-drop reordering for active widgets in horizontal layout. Match Stats Master's reordering behavior with visual feedback.

## Implementation

Add SwiftUI drag/drop to ActiveWidgetsSection:

```swift
.draggable(widget.id)
.dropDestination(for: UUID.self) { dropped, location in
    // Reorder logic
}
```

Key behaviors:
- Visual feedback during drag
- Insertion indicator
- Order saves immediately to WidgetStore
- Animated repositioning

## Acceptance
- [ ] Drag gesture initiates reorder
- [ ] Visual feedback shows drop position
- [ ] Order persists after restart
- [ ] Smooth animations
- [ ] Works with horizontal scroll

## Done summary
Implemented drag-and-drop reordering with Stats Master behavior.

## References
- SwiftUI `.draggable()`, `.dropDestination()` documentation
- Stats Master: Widget dock reordering
