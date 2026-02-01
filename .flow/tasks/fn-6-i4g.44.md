# fn-6-i4g.44 Create PopupWindow.swift

## Description

Create NSWindow subclass for widget popovers matching Stats Master's behavior.

**REFERENCE**: Read `stats-master/Kit/module/popup.swift` first

Stats Master's PopupWindow features:
- Custom NSWindow (not NSPopover)
- Transparent background with custom shadow
- Drag behavior - window can be moved
- Close on drag end (Activity Monitor mode)
- Custom positioning (below menu bar item)

**NOTE**: This is optional. Tonic can continue using NSPopover if preferred. This task creates the option.

## New Files to Create

1. **Tonic/Tonic/MenuBarWidgets/Popovers/PopupWindow.swift**

## Implementation

```swift
// File: Tonic/Tonic/MenuBarWidgets/Popovers/PopupWindow.swift

import SwiftUI

class PopupWindow: NSWindow {
    var isDragging = false
    var closeOnDragEnd = false
    var initialLocation: NSPoint = .zero

    init(contentRect: NSRect, view: some View) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )

        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.level = .popUpMenu

        // Content
        let hostingView = NSHostingView(rootView: view)
        hostingView.autoresizingMask = [.width, .height]
        self.contentView = hostingView

        // Position below menu bar
        self.positionWindow()

        // Drag gesture
        let dragGesture = NSPanGestureRecognizer(target: self, action: #selector(handleDrag(_:)))
        self.contentView?.addGestureRecognizer(dragGesture)
    }

    private func positionWindow() {
        // Position below the menu bar item that triggered it
        // Implementation depends on which status item was clicked
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let windowWidth = contentRect.width
            self.setFrameOrigin(
                NSPoint(
                    x: screenFrame.midX - windowWidth / 2,
                    y: screenFrame.maxY - contentRect.height - 30  // Below menu bar
                )
            )
        }
    }

    @objc private func handleDrag(_ gesture: NSPanGestureRecognizer) {
        let location = gesture.location(in: nil)

        switch gesture.state {
        case .began:
            isDragging = true
            initialLocation = frame.origin

        case .changed:
            if isDragging {
                let delta = NSPoint(
                    x: location.x - initialLocation.x,
                    y: location.y - initialLocation.y
                )
                self.setFrameOrigin(delta)
            }

        case .ended:
            isDragging = false
            if closeOnDragEnd {
                self.close()
            }

        default:
            break
        }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMainWindow: Bool { false }
}
```

## Acceptance

- [ ] PopupWindow is NSWindow subclass with transparent background
- [ ] Window has shadow
- [ ] Drag behavior works (window follows mouse)
- [ ] closeOnDragEnd property controls behavior
- [ ] Window positions below menu bar item
- [ ] Level is .popUpMenu (stays on top)
- [ ] Content view renders SwiftUI correctly

## Optional: Continue using NSPopover

If PopupWindow is too complex, Tonic can continue using NSPopover (current approach). The key parity is in the **content**, not the window type.

## Done Summary

Created PopupWindow NSWindow subclass with drag behavior, matching Stats Master's popup window implementation. Optional - NSPopover can continue to be used if preferred.

## Evidence

- Commits:
- Tests:
- PRs:

## Reference Implementation

**Stats Master**: `stats-master/Kit/module/popup.swift`
- PopupWindow class (lines 40-120)
- Drag detection implementation
- Shadow and transparency setup
