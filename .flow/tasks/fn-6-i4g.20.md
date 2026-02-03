# fn-6-i4g.20 Per-Widget Settings UI Enhancement

## Description
Enhance the widget settings UI to support per-widget customization for all PRD-specified options. Currently settings are limited - this task adds granular control for each widget.

**Size:** M
**Files:**
- `Tonic/Tonic/Views/WidgetCustomizationView.swift` (major enhancement)
- `Tonic/Tonic/Views/WidgetSettingsSheet.swift` (new - per-widget settings)
- `Tonic/Tonic/Models/WidgetConfiguration.swift` (ensure all options stored)

## Approach

- Create `WidgetSettingsSheet` for detailed per-widget configuration
- Follow existing view patterns at `Views/WidgetCustomizationView.swift`
- Use `DesignComponents` for consistent styling
- Per-widget settings include: visualization type, color, display mode, update interval, label, chart config

## Key Context

**Per-Widget Settings (from PRD Section 5.3)**:
- Label on/off
- Color selection (30+ options)
- Box/Frame toggle (for charts)
- History length (30-120 points)
- Scale type (linear/square/cube/log)
- Alignment options
- Monochrome toggle
- Icon options (for speed/battery widgets)

**Settings accessed via**: Gear button in popover header (from Task 18) or widget row in main settings.
## Acceptance
- [ ] `WidgetSettingsSheet` created for per-widget configuration
- [ ] Settings sheet accessible from popover header gear button
- [ ] Settings sheet accessible from widget row in main settings
- [ ] Visualization type picker shows compatible options per widget
- [ ] Color picker shows full 30+ color palette
- [ ] Update interval picker (1, 2, 3, 5, 10, 15, 30, 60 seconds)
- [ ] Label toggle works per-widget
- [ ] Chart config: history length slider (30-120 points)
- [ ] Chart config: scale type picker (linear/square/cube/log)
- [ ] Chart config: box/frame toggle
- [ ] Changes persist immediately to `WidgetPreferences`
- [ ] Reset to defaults button per widget
## Done summary
TBD

## Evidence
- Commits:
- Tests:
- PRs:
