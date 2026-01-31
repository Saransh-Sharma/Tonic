# fn-6-i4g.3 Notification System Foundation

## Description
Create the foundation for Stats Master's threshold-based notification system adapted for Tonic.

**Size:** M

**Files:**
- `Tonic/Tonic/Services/NotificationManager.swift` (new)
- `Tonic/Tonic/Models/NotificationThreshold.swift` (new)
- `Tonic/Tonic/Models/NotificationConfig.swift` (new)

Create the notification system architecture:

1. **NotificationThreshold** - Per-widget threshold configuration
```swift
struct NotificationThreshold: Codable, Sendable {
    let id: UUID
    let widgetType: WidgetType
    let condition: NotificationCondition
    let value: Double
    let isEnabled: Bool
}

enum NotificationCondition: String, Codable {
    case equals, notEquals, greaterThan, lessThan
    case greaterThanOrEqual, lessThanOrEqual
}
```

2. **NotificationConfig** - Aggregate notification settings
```swift
struct NotificationConfig: Codable, Sendable {
    var thresholds: [NotificationThreshold]
    var respectDoNotDisturb: Bool
    var minimumInterval: TimeInterval  // Debounce
}
```

3. **NotificationManager** - Singleton service following `WidgetPreferences` pattern
```swift
@MainActor
@Observable
public final class NotificationManager: Sendable {
    static let shared = NotificationManager()
    
    var config: NotificationConfig
    
    func checkThreshold(widgetType: WidgetType, value: Double)
    func requestPermission()
    func sendNotification(title: String, body: String)
}
```

## Approach

1. Create model structs in `Models/`
2. Create `NotificationManager` as `@Observable` singleton
3. Implement macOS notification permission request
4. Implement threshold checking logic
5. Add debouncing to prevent notification spam
6. Respect "Do Not Disturb" via `NSWorkspace.shared.notificationCenter`

## Key Context

Reference Stats Master's notification system in `stats-master/Kit/module/ModuleType.notifications.swift`. Stats Master supports 3% to 100% threshold increments — we'll use configurable Double values instead.

Pattern reference: `WidgetPreferences.swift:291-294` for the `@Observable` singleton pattern.
## Acceptance
- [ ] NotificationThreshold struct defined
- [ ] NotificationCondition enum with all comparison types
- [ ] NotificationConfig struct defined
- [ ] NotificationManager singleton created
- [ ] Permission request implemented
- [ ] Threshold checking logic implemented
- [ ] Debouncing prevents notification spam
- [ ] Do Not Disturb is respected
## Done summary
Created threshold-based notification system foundation for Tonic menu bar widgets. Implemented NotificationThreshold model with comparison conditions (equals, notEquals, greaterThan, lessThan, greaterThanOrEqual, lessThanOrEqual), NotificationConfig for persistence and global settings, and NotificationManager singleton service with UserNotifications framework integration, permission handling, debouncing, and Do Not Disturb detection.
## Evidence
- Commits: 93249f60e2bf224e411b1bd25f6675f51629bbeb
- Tests: xcodebuild -project Tonic/Tonic.xcodeproj -scheme Tonic -configuration Debug build
- PRs: