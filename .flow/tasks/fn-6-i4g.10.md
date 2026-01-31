# fn-6-i4g.10 Notification System Implementation

## Description
Complete the notification system implementation with UI for configuring thresholds.

**Size:** M

**Files:**
- `Tonic/Tonic/Services/NotificationManager.swift` (modify - complete implementation)
- `Tonic/Tonic/Views/NotificationSettingsView.swift` (new)
- `Tonic/Tonic/Views/WidgetCustomizationView.swift` (modify - integrate)

**Notification Manager** enhancements:
1. Implement threshold checking for each data type
2. Add notification queue with debounce
3. Track last notification time per threshold
4. Implement "Do Not Disturb" checking

**Notification Settings UI**:
1. Add "Notifications" section to `WidgetCustomizationView`
2. Per-module notification configuration:
   - Enable/disable notifications for widget type
   - Threshold sliders (e.g., "Notify when CPU > 80%")
   - Condition selection (greater than, less than, equals)
3. Test notification button
4. Notification preview section

## Approach

1. Complete `NotificationManager.checkThreshold()` implementation
2. Add `checkThreshold()` calls in `WidgetDataManager` update methods
3. Create `NotificationSettingsView` with threshold configuration
4. Integrate into `WidgetCustomizationView.swift` as new tab/section
5. Add notification permission prompt on first enable
6. Use `UNUserNotificationCenter` for delivery
7. Respect `NSWorkspace.shared.notificationCenter.shouldShowNotification` for DND

## Key Context

Stats Master's notification thresholds are configurable per widget type. Reference `stats-master/Kit/module/ModuleType.notifications.swift` for supported ranges.

Default thresholds:
- CPU: >80% usage
- Memory: >90% usage
- Disk: >90% capacity
- Network: Public IP changed
- Battery: <20% level

Reference pattern: `WidgetCustomizationView.swift:14-898` for settings UI structure.
## Acceptance
- [ ] Threshold checking implemented for all widget types
- [ ] Notification queue with debounce
- [ ] Do Not Disturb respected
- [ ] Notification settings UI created
- [ ] Per-module threshold configuration
- [ ] Condition selection (greater than, etc.)
- [ ] Test notification button works
- [ ] Permission request on first enable
- [ ] Notifications delivered correctly
- [ ] Notifications respect user preferences
- [ ] Notification history/log available (optional)
## Done summary
TBD

## Evidence
- Commits:
- Tests:
- PRs:
