# fn-6-i4g.19 Enhanced Color System with Utilization-Based Coloring

## Description
Enhance the color system to match PRD specifications: 30+ fixed color options, automatic utilization-based coloring (green→yellow→orange→red), color zones, and monochrome mode support.

**Size:** S
**Files:**
- `Tonic/Tonic/Models/WidgetConfiguration.swift` (expand `WidgetAccentColor`)
- `Tonic/Tonic/Design/WidgetColors.swift` (new - color palette)
- `Tonic/Tonic/Design/ColorZones.swift` (new - threshold-based coloring)

## Approach

- Expand `WidgetAccentColor` enum at `WidgetConfiguration.swift:126-175` with full PRD palette
- Create `ColorZone` struct for threshold-based automatic coloring
- Add utilization color calculation: green (0-50%), yellow (50-75%), orange (75-90%), red (90-100%)
- Add cluster colors for CPU E/P cores: teal (E-cores), indigo (P-cores)
- Add monochrome mode that adapts to light/dark appearance

## Key Context

**PRD Fixed Colors (30 options)**:
```
Primary: red, green, blue, yellow, orange, purple, brown, cyan, magenta, pink, teal, indigo
Secondary: secondRed, secondGreen, secondBlue, secondYellow, secondOrange, secondPurple, secondBrown
Grays: gray, secondGray, darkGray, lightGray
Other: white, black, clear
```

**Utilization-based coloring**:
- Use `.utilizationBased` as color option that auto-calculates from value
- Configurable thresholds via `ColorZone` struct

**Monochrome mode**:
- Single color that adapts to appearance (white in dark mode, black in light mode)
- Used when user wants minimal visual distraction
## Acceptance
- [ ] `WidgetAccentColor` expanded to 30+ color options
- [ ] `.utilizationBased` color option auto-calculates from widget value
- [ ] Utilization colors: green (0-50%), yellow (50-75%), orange (75-90%), red (90-100%)
- [ ] `ColorZone` struct enables custom threshold definitions
- [ ] CPU cluster colors available: teal for E-cores, indigo for P-cores
- [ ] Monochrome mode adapts to system appearance
- [ ] All existing widgets support new color options
- [ ] Color picker in settings shows full palette
- [ ] Colors persist correctly in `WidgetConfiguration`
## Done summary
TBD

## Evidence
- Commits:
- Tests:
- PRs:
