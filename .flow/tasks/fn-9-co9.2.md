## Description
# Phase 1: Design Token Migration (Typography & Colors)

Replace ~250 deprecated token usages across 115+ files.

**Typography Tokens (~180 replacements):**
```
.displayLarge (32pt) → .h1 (32pt)           [EXACT MATCH]
.displayMedium (28pt) → .h2 (24pt)         [4pt smaller - ACCEPTABLE]
.displaySmall (24pt) → .h2 (24pt)          [EXACT MATCH]
.headlineLarge (20pt) → .h3 (20pt)        [EXACT MATCH]
.headlineMedium (18pt) → .h3 (20pt)       [2pt larger - ACCEPTABLE]
.headlineSmall (16pt) → .bodyEmphasized (16pt)  [EXACT MATCH]
.bodyLarge (16pt) → .body (16pt)          [EXACT MATCH]
.bodyMedium (14pt) → .subhead (14pt)      [EXACT MATCH]
.bodySmall (12pt) → .caption (12pt)       [EXACT MATCH]
.captionLarge (12pt medium) → .captionEmphasized (12pt medium)  [EXACT MATCH]
.captionMedium (11pt) → .caption (12pt)    [1pt larger - ACCEPTABLE]
.captionSmall (10pt) → .caption (12pt)     [2pt larger - ACCEPTABLE]
.monoLarge (16pt) → .monoBody (16pt)       [EXACT MATCH]
.monoMedium (14pt) → .monoSubhead (14pt)   [EXACT MATCH]
.monoSmall (12pt) → .monoCaption (12pt)    [EXACT MATCH]
```

**Color Tokens (~70 replacements):**
```
.text → .textPrimary              .border → .separator
.surface → .backgroundSecondary   .surfaceElevated → .backgroundTertiary
.progressLow → .success           .progressMedium → .warning
.progressHigh → .error
```

**Special Case:** Replace `.surfaceHovered` with existing `DesignTokens.Colors.unemphasizedSelectedContentBackground`

**Size:** L (batch replace by token type)
**Files:** 115+ files

## Approach
Use batch find-replace for each token type. Build after each category.

## Typography Size Changes
| Old Token | Size | New Token | Size | Change |
|-----------|------|-----------|------|--------|
| .displayMedium | 28pt | .h2 | 24pt | -4pt |
| .headlineMedium | 18pt | .h3 | 20pt | +2pt |
| .captionMedium | 11pt | .caption | 12pt | +1pt |
| .captionSmall | 10pt | .caption | 12pt | +2pt |

These normalize typography to the 8-point grid. Small size changes are acceptable; layouts remain functional.

## Acceptance
- [ ] All deprecated typography token warnings removed (~180)
- [ ] All deprecated color token warnings removed (~70)
- [ ] `.surfaceHovered` replaced with `.unemphasizedSelectedContentBackground`

## Visual Spot-Check Checklist (screens must be functional, minor text size variation OK)
- [ ] **Preferences Window:** Opens, tabs switch, all sections visible
- [ ] **Dashboard:** Cards display correctly, text readable
- [ ] **Sidebar:** All navigation items visible and clickable
- [ ] **CPU Popover:** Chart displays, values readable
- [ ] **Memory Popover:** Gauge visible, text not truncated
- [ ] **Disk Popover:** Volume list readable, values visible
- [ ] **Network Popover:** Bandwidth chart displays
- [ ] **Battery Popover:** Battery visual and values readable
- [ ] **Menu Bar Widgets:** Icons and text fit in menu bar

- [ ] Build succeeds with reduced warning count
- [ ] Deprecated aliases still present in DesignTokens.swift (for Phase 7)

## Test Commands
```bash
# Count remaining deprecated token warnings
xcodebuild -project Tonic/Tonic.xcodeproj -scheme Tonic build 2>&1 | grep -E "deprecated.*renamed" | wc -l

# Verify no surfaceHovered usage
grep -r "surfaceHovered" Tonic/Tonic/ --include="*.swift" || echo "None found (expected)"
```
## Done summary
Migrated all deprecated design tokens (typography and colors) across 14 files. Typography tokens: .displaySmall→.h2, .headlineMedium→.h3, .bodyMedium→.subhead, .headlineSmall→.bodyEmphasized, .captionLarge→.captionEmphasized, .bodySmall/.captionSmall/.captionMedium→.caption. Color tokens: .text→.textPrimary, .border→.separator, .surface→.backgroundSecondary, .surfaceElevated→.backgroundTertiary, .surfaceHovered→.unemphasizedSelectedContentBackground, .progressLow→.success, .progressMedium→.warning, .progressHigh→.error. Build succeeds with 0 design token deprecation warnings.
## Evidence
- Commits: a72e72ce4aa855672479761a6c2b717fab1162d7
- Tests: xcodebuild -project Tonic/Tonic.xcodeproj -scheme Tonic -configuration Debug build
- PRs: