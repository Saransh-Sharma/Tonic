# fn-8-v3b.19 Fix menu bar refresh bug in WidgetStatusItem

## Description
Fix menu bar refresh bug in `WidgetStatusItem.swift` where `objectWillChange.send()` doesn't force NSView redraw.

**Size:** S

**Files:**
- `Tonic/Tonic/MenuBarWidgets/WidgetStatusItem.swift`

## Approach

Update `updateConfiguration` method to force immediate NSView refresh:

```swift
public func updateConfiguration(_ newConfig: WidgetConfiguration) {
    configuration = newConfig
    objectWillChange.send()

    // Force immediate NSView refresh
    DispatchQueue.main.async {
        if let statusItem = self.statusItem {
            let button = statusItem.button
            button?.window?.contentView?.setNeedsDisplay(button?.bounds ?? .zero)
            button?.window?.contentView?.displayIfNeeded()
            self.updateCompactView()  // Recreate view
        }
    }
}
```

Key fix: Call `setNeedsDisplay`, `displayIfNeeded`, and recreate the hosted SwiftUI view.

## Key Context

Bug: When widget configuration changes (color, mode, etc.), menu bar item doesn't update visually until next refresh cycle.

Root cause: SwiftUI `objectWillChange.send()` notifies observers but doesn't force NSView to redraw immediately.

Solution: Force NSView redraw and recreate the hosted SwiftUI view.

This is a known issue with NSStatusItem + SwiftUI hosting view integration.
## Acceptance
- [ ] updateConfiguration calls setNeedsDisplay on NSView
- [ ] updateConfiguration calls displayIfNeeded on NSView
- [ ] updateConfiguration recreates hosted SwiftUI view
- [ ] Menu bar item updates immediately on config change
- [ ] Color changes apply instantly
- [ ] Mode changes apply instantly
- [ ] No lag or delay in visual update
## Done summary
TBD

## Evidence
- Commits:
- Tests:
- PRs:
