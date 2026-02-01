# fn-6-i4g.28 Fix Configuration Refresh Bug

## Description

**CRITICAL BUG**: Changes to widget configuration (color, visualization type, etc.) do not immediately reflect in active menu bar widgets. User must manually click "Apply" or restart the app.

**Root Cause**: `WidgetConfiguration.updateConfig()` saves to UserDefaults but does NOT notify `WidgetCoordinator` that changes occurred.

## Files to Modify

1. **Tonic/Tonic/Models/WidgetConfiguration.swift** (lines 781-786)
   - Add notification broadcast after `saveConfigs()`
   - Create new notification name: `.widgetConfigurationDidUpdate`

2. **Tonic/Tonic/MenuBarWidgets/WidgetCoordinator.swift**
   - Add observer for configuration changes
   - Implement `handleConfigurationChange()` to update widgets

3. **Tonic/Tonic/Views/Refactored/WidgetCustomizationView.swift** (lines 107-123)
   - Make "Apply" button optional or change to "Reset to Defaults"
   - Changes should be immediate via reactive pattern

## Implementation Steps

### Step 1: Add Notification Extension
```swift
// File: Tonic/Tonic/Models/WidgetConfiguration.swift

extension Notification.Name {
    static let widgetConfigurationDidUpdate = Notification.Name("tonic.widgetConfigurationDidUpdate")
}
```

### Step 2: Make updateConfig() Reactive
```swift
// File: Tonic/Tonic/Models/WidgetConfiguration.swift (line 781)

public func updateConfig(for type: WidgetType, _ update: (inout WidgetConfiguration) -> Void) {
    if let index = widgetConfigs.firstIndex(where: { $0.type == type }) {
        update(&widgetConfigs[index])
        saveConfigs()

        // NEW: Broadcast change immediately
        Task { @MainActor in
            NotificationCenter.default.post(
                name: .widgetConfigurationDidUpdate,
                object: nil,
                userInfo: ["widgetType": type]
            )
        }
    }
}
```

### Step 3: Add Observer in WidgetCoordinator
```swift
// File: Tonic/Tonic/MenuBarWidgets/WidgetCoordinator.swift

private var configObserver: NSObjectProtocol?

private func setupConfigurationObserver() {
    configObserver = NotificationCenter.default.addObserver(
        forName: .widgetConfigurationDidUpdate,
        object: nil,
        queue: .main
    ) { [weak self] notification in
        self?.handleConfigurationChange(notification)
    }
}

private func handleConfigurationChange(_ notification: Notification) {
    guard let widgetType = notification.userInfo?["widgetType"] as? WidgetType else { return }

    if WidgetPreferences.shared.unifiedMenuBarMode {
        oneViewStatusItem?.refreshWidgetList()
    } else if let widget = activeWidgets[widgetType] {
        widget.refreshView()
    }
}

// Call in init()
init() {
    setupConfigurationObserver()
}

// Cleanup in deinit
deinit {
    if let observer = configObserver {
        NotificationCenter.default.removeObserver(observer)
    }
}
```

### Step 4: Remove Apply Button Dependency
```swift
// File: Tonic/Tonic/Views/Refactored/WidgetCustomizationView.swift
// The "Apply" button becomes optional since changes are now immediate
```

## Acceptance

- [ ] Changing widget color in settings immediately updates menu bar widget
- [ ] Changing visualization type immediately reflects in menu bar
- [ ] Toggling OneView mode immediately reorganizes menu bar items
- [ ] No app restart required for any configuration change
- [ ] "Apply" button is optional or removed entirely

## Done Summary

Fixed configuration refresh mechanism by adding reactive notification pattern between `WidgetConfiguration` and `WidgetCoordinator`. Configuration changes now propagate immediately without requiring manual apply or app restart.

## Evidence

- Commits:
- Tests:
- PRs:
