# fn-8-v3b.14 Create TabbedSettingsView container

## Description
Create `TabbedSettingsView.swift` with segmented tab switcher for Stats Master-style settings UI (540×480 layout).

**Size:** M

**Files:**
- `Tonic/Tonic/MenuBarWidgets/Settings/TabbedSettingsView.swift` (NEW)
- `Tonic/Tonic/MenuBarWidgets/Settings/ModuleSettingsView.swift` (NEW)
- `Tonic/Tonic/MenuBarWidgets/Settings/PopupSettingsView.swift` (NEW)
- `Tonic/Tonic/MenuBarWidgets/Settings/NotificationsSettingsView.swift` (NEW)

## Approach

Create a tabbed settings container with:

1. **Segmented tab switcher:** 4 tabs (Module, Widgets, Popup, Notifications)
2. **Content area:** 540×480 fixed size
3. **Tab views:**
   - ModuleSettingsView: Per-module settings
   - WidgetsView: Existing (move from current location)
   - PopupSettingsView: Global popup settings
   - NotificationsSettingsView: Notification settings (extract from current)

4. **Presentation:** Sheet from popover settings button

5. **Layout pattern:**
   ```
   ┌─────────────────────────────────┐
   │  [Module|Widgets|Popup|Notify] │ ← Segmented control
   ├─────────────────────────────────┤
   │                                 │
   │      Tab Content View           │
   │      (540×480 content)         │
   │                                 │
   └─────────────────────────────────┘
   ```

## Key Context

Stats Master uses 540×480 for settings window. Popover settings button currently has `// TODO: Open settings` comment.

Tab views should use SwiftUI `TabView` with `.tabViewStyle(.segmented)` for native segmented control appearance.

Existing settings are in `WidgetsPanelView.swift`. This should be refactored into the new tabbed structure.
## Acceptance
- [ ] TabbedSettingsView.swift created with 4 tabs
- [ ] Segmented tab switcher displays correctly
- [ ] Content area is 540×480 fixed size
- [ ] ModuleSettingsView, PopupSettingsView, NotificationsSettingsView created
- [ ] Settings sheet opens from popover settings button
- [ ] Tab state persists across session
- [ ] All tabs use standardized spacing and typography
## Done summary
TBD

## Evidence
- Commits:
- Tests:
- PRs:
