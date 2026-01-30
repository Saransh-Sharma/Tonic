# Tonic UI/UX Redesign - Native macOS Overhaul

**Epic ID:** fn-4-as7
**Status:** Open
**Review Backend:** rp
**Interviewed:** 2024-01-29 (47 questions asked)

## Problem Statement

The current Tonic UI uses heavy card-based layouts that don't feel native to macOS. Color usage is inconsistent (mix of DesignTokens, TonicColors, and raw values), making light/dark mode parity difficult. Navigation is flat without grouping of related features. Components are custom-built where native macOS equivalents exist.

**Specific Issues Identified:**
- WidgetCustomizationView has custom dark colors that don't adapt
- Card component has hardcoded dark colors instead of system colors
- Text contrast issues in both light and dark modes
- Accent color visibility issues in dark mode
- Some components stay dark even in light mode
- Card styling appears too bright/flat in light mode
- Shadows are too harsh in light mode

## Objective

Redesign Tonic's UI to feel native to macOS, visually calm, and equally polished in Light/Dark Mode. Improve and standardize the Card component, unify on semantic colors, and reorganize navigation for better hierarchy.

## Success Criteria

1. Users identify what to do next within 3 seconds of opening the app
2. No screen mixes more than one primary interaction pattern
3. Light and Dark Mode have parity in contrast (WCAG AA), density, and readability
4. App launch < 2s, Smart Scan < 30s (maintain current performance)
5. All hardcoded colors replaced with semantic tokens
6. Navigation uses grouped sections with visual separators
7. Improved Card component with variants works in both modes

## Non-Goals

- New features (functionality unchanged)
- Backend logic changes (except required for UX)
- Monetization changes
- iOS adaptation
- Pro feature gating (all features available to all users)

---

## Key Decisions from Interview

### Card Component
- **NOT removing** the Card component - keeping and improving it
- Create 3 variants: Elevated (shadow), Flat (no shadow), Inset (border inset)
- Fix existing Card color styling and DesignToken integration
- Use for: Main content containers and Stats/metrics displays

### Navigation
- Visual-only section headers (non-selectable) with separators between groups
- Fixed width sidebar (not resizable), wide enough for all text
- Cmd+K command palette for quick navigation
- No collapsible sections - flat list with separators

### Dashboard
- **Single primary CTA only** (Smart Scan button)
- Health ring redesigned and improved with tooltip explanation
- Recommendations: RAG priority (High=red, Medium=orange, Low=blue/gray) with icon badge, background tint, grouped by category
- Activity: Summary only (last 3 items with "View All" link)

### Apps
- **Keep the 4-column grid** (not changing to table)
- Add search bar, multi-select (Cmd+click), improve metadata design

### Disk
- **Hybrid view**: Segmented control for [List | Treemap | Hybrid]
- List = bar chart rows (Name | size bar | %)
- Show top 3-4 levels, user can drill down further
- Snappy animations for delightful UX
- No Pro gating - treemap available to all

### Maintenance (Smart Scan + Clean)
- Scan → Summary sheet with buttons: "Clean Now" or "Review"
- User can choose immediate action or review first
- Progress: Both circular + linear indicators
- Stage indicators: Numbered steps (1 2 3 4), active highlight, stage label
- **Subtext showing rapid updates** of what's happening in each stage
- Cancel button always visible, clean cancel (no partial results)

### Activity (Live Monitoring)
- Vertical list of MetricRows
- User-configurable update frequency: 5min/15min/60min (default 5min)
- No circular gauges

### Colors
- Add semantic colors: Success (green), Warning (yellow/orange), Info (blue)
- Use system semantic colors as base
- Target WCAG AA (4.5:1 minimum contrast)
- Custom high contrast theme (not just relying on system setting)

### Animations
- Quick timing: 0.15s for expand/collapse, progress, selection
- No decorative animations or parallax

### Onboarding
- First-launch feature walkthrough tour
- Explain redesigned UI elements

### Feedback
- "Give Feedback" button in Settings/Help menu
- Per-screen "Report Issue" option
- Crash reporting

### Accessibility
- Dynamic labels for changing content (e.g., "Scanning, 45% complete")
- Tab order through all screens
- Smart default focus on primary action
- Esc key closes modals/sheets
- Focus ring on all focused elements
- Custom high contrast theme
- Reduced motion: Not a priority for this redesign

### Performance
- Maintain current < 2s app launch
- Lazy stacks + virtual scroll for 1000+ item lists
- Profile-only approach for memory (no specific budget)

### Developer Workflow
- Add unit tests for new components
- Add SwiftUI Previews for all new components
- Create "Design Sandbox" screen to view all components
- Document design decisions in docs/Design.md
- Inline code documentation for component specs

### Testing
- No analytics in redesign
- No screen reader testing planned
- Manual testing only

---

## Design System Requirements

### Spacing (8-Point Grid)

```swift
enum Spacing {
    static let xxxs: CGFloat = 4   // Very tight (icon-text gap)
    static let xxs:  CGFloat = 8   // Small padding
    static let xs:   CGFloat = 12  // Minor separation
    static let sm:   CGFloat = 16  // Default small
    static let md:   CGFloat = 24  // Default medium
    static let lg:   CGFloat = 32  // Section gaps
    static let xl:   CGFloat = 40  // Extra large
    static let xxl:  CGFloat = 48  // Very large
}
```

**Rules:**
- No arbitrary spacing values
- Vertical rhythm uses `sm` or `md`
- Section separation uses `md` or `lg`

### Typography

```swift
enum Typography {
    static let h1 = Font.system(size: 32, weight: .bold)      // One per screen
    static let h2 = Font.system(size: 24, weight: .semibold)  // Sections
    static let body = Font.system(size: 16, weight: .regular)  // Content
    static let subhead = Font.system(size: 14, weight: .regular) // Secondary
    static let caption = Font.system(size: 12, weight: .regular) // Metadata
}
```

**Rules:**
- Only one H1 per screen
- Tables/lists use `body` or `subhead`
- Metadata uses `caption`
- No inline font size overrides

### Colors (Semantic + Custom)

```swift
enum Colors {
    // Backgrounds
    static let background = Color(NSColor.windowBackgroundColor)
    static let groupedBackground = Color(NSColor.controlBackgroundColor)

    // Text
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary

    // Semantic (system)
    static let accent = Color.accentColor
    static let destructive = Color.red
    static let separator = Color(NSColor.separatorColor)

    // Semantic (custom - WCAG AA compliant)
    static let success = Color("SuccessGreen")    // For safe/delete confirmations
    static let warning = Color("WarningOrange")    // For caution states
    static let info = Color("InfoBlue")            // For informational states
}
```

**Rules:**
- No hardcoded colors in views
- Accent only for: Primary CTAs, Selection, Progress
- Red only for destructive actions
- Custom colors must meet WCAG AA contrast

### Card Component

Three variants:
1. **Elevated**: Shadow for depth (primary content)
2. **Flat**: No shadow, border only (secondary content)
3. **Inset**: Inset border for grouped content

Uses semantic DesignTokens for colors, fixed dark/light mode.

---

## Navigation Structure

### New Sidebar IA

```
─────────────────────
Dashboard
─────────────────────
Maintenance
  Smart Scan
  Clean Up
─────────────────────
Explore
  Disk
  Apps
  Activity
─────────────────────
Menu Bar
  Widgets
─────────────────────
Advanced
  Developer Tools
  Permissions
─────────────────────
Settings
─────────────────────
```

**Implementation Notes:**
- Use `NavigationSplitView` with `SidebarListStyle`
- Group headers are visual separators only (non-selectable)
- Fixed width (not resizable but wide enough)
- Cmd+K opens command palette for quick navigation

---

## Shared Components

### 1. MetricRow
- **Used:** Dashboard, Live Monitoring
- **Contents:** Icon, Title, Value, Optional sparkline
- **Rules:** Fixed height (44pt), monospaced numbers, HStack layout
- **Sparkline:** User-configurable history (5/15/60 min options)

### 2. PreferenceList
- **Used:** All Settings screens
- **Structure:** Grouped List, Section headers, Label + Control rows
- **Controls:** Toggle, Picker, Button, Status indicator

### 3. Card (Improved)
- **Variants:** Elevated, Flat, Inset
- **Semantic colors** from DesignTokens
- **Fixed dark/light mode** (no custom dark colors)
- **Uses:** Main content, Stats/metrics

### 4. Command Palette
- **Trigger:** Cmd+K
- **Features:** Quick navigation to any screen
- **UI:** Centered search/results overlay

### 5. Onboarding Tour
- **Trigger:** First launch only
- **Style:** Feature walkthrough
- **Content:** Explain redesigned UI elements

---

## Screen-by-Screen Requirements

### Dashboard
- **Left column:**
  - Redesigned health ring (with tooltip explaining score calculation)
  - Single primary CTA: Smart Scan button
  - Real-time stats using MetricRow components
- **Right column:**
  - Recommendations grouped by category (Cache, Logs, etc.)
  - RAG priority coding (High/Medium/Low) with color tint, icon badge
  - Size impact shown within each priority group
  - Recent Activity: Last 3 items only with "View All" link
- **Rules:** Single CTA, health score explained, improved Cards

### Maintenance (Smart Scan + Clean Up)
- **Structure:** Single screen with tabs (Scan | Clean)
- **Scan Tab:**
  - Stage progress: Numbered circles (1 2 3 4), highlighted active stage
  - Both circular + linear progress indicators
  - Stage label + rapidly changing subtext of current action
  - Cancel button always visible (no partial results on cancel)
  - Summary on completion: "Clean Now" or "Review" buttons
- **Clean Tab:**
  - Grouped list of categories
  - Expandable previews
  - Total reclaim always visible
  - Always confirm before cleaning
- **Safety:** Mandatory preview, Collector Bin preserved, redesigned UI + improved access

### Disk
- **View Switcher:** Segmented control [List | Treemap | Hybrid]
- **List View:** Horizontal bar chart rows (Name | size bar | %)
- **Treemap:** Rectangle sizing by file/folder size
- **Hybrid:** Bar chart + treemap combination
- **Depth:** Show 3-4 levels, drill down for more
- **Interactions:** Snappy animations, Reveal-in-Finder always available
- **Rules:** No Pro gating, all views available to all users

### Apps
- **Layout:** Keep 4-column grid (NOT changing to table)
- **Sidebar:** Category filter (All, User, System, Extensions, etc.)
- **Search:** Add search bar at top
- **Multi-select:** Cmd+click for batch actions
- **Metadata:** Improve design (name, size, last used)
- **Rules:** Keep current sorting, improve visual design

### Activity (Live Monitoring)
- **Layout:** Vertical list of MetricRows
- **Metrics:** CPU, Memory, Disk, Network, GPU, Battery
- **Update Frequency:** User-configurable (5/15/60 min, default 5min)
- **Rules:** No circular gauges, no cards

### Menu Bar Widgets
- **Layout:** List of widgets with toggle
- **Reorder:** Cmd+drag (already built, preserve)
- **Preview:** Inline widget preview
- **Rules:** No decorative imagery, native list

### Settings
- **Sections:** General, Appearance, Permissions, Helper, Updates, About
- **About:** Full page within Settings + standalone window (app menu → About Tonic)
- **High Contrast:** Custom theme option
- **Rules:** Use PreferenceList, improved Cards, semantic colors

### Permission States
- **Denied state:** Explanation text + minimal state + action button + lock overlay
- **Refine:** Redesign existing similar screens
- **Action:** Button opens System Settings

### Empty States
- **Style:** Illustrated (SF Symbol icon + centered message)
- **Action:** Button to trigger scan/refresh
- **Reuse:** Keep existing EmptyState component, restyle

### Error States
- **Inline errors:** For field-level issues
- **Error banners:** Top of screen for blocking errors
- **Error sheets:** Modal for critical errors requiring action
- **Toast notifications:** Transient errors

---

## Interaction Requirements

### Mandatory
- `withAnimation(0.15s)` on: Expand/collapse, Progress updates, Selection changes
- Progress indicators for long tasks (>3s)
- Cancel available wherever task > 3s
- Cmd+K command palette

### Forbidden
- Decorative animations
- Parallax effects
- Auto-playing motion

### Keyboard
- Tab order through all screens
- Smart default focus
- Esc closes modals/sheets
- Cmd+K for command palette
- Focus ring on all focusable elements

---

## Accessibility Requirements

### Labels
- Dynamic labels for changing content (e.g., "Scanning, 45% complete")
- All interactive elements have `accessibilityLabel`

### Focus
- Logical tab order
- Default focus on primary action
- Visual focus ring

### Vision
- WCAG AA contrast (4.5:1 minimum)
- Custom high contrast theme
- Locale-aware date/number formatting
- Localizable strings (English only for v1, architected for i18n)

### Not in Scope
- Screen reader testing
- Reduced motion support
- RTL language support

---

## Performance Requirements

- App launch < 2s (maintain current)
- Smart Scan < 30s (maintain current)
- Lists > 1k rows: Lazy stacks + virtual scroll, 60fps
- Disk tree lazy-loaded, non-blocking
- Memory: Profile-only, no specific budget

---

## Implementation Phases

### Phase 1: Foundation
1. Design token updates (spacing, semantic colors, custom colors)
2. Card component improvements (3 variants, fix colors)
3. Shared components (MetricRow, PreferenceList)
4. Command palette (Cmd+K)
5. Sidebar refactor with grouped navigation

### Phase 2: Core Screens
1. Dashboard redesign (health ring, single CTA, RAG recommendations)
2. Maintenance view redesign (tabs, progress, summary flow)
3. Disk Analysis redesign (hybrid view, segmented control)
4. App Manager improvements (grid search, multi-select, metadata)

### Phase 3: Supporting Screens
1. Activity redesign (MetricRow list, configurable frequency)
2. Menu Bar Widgets redesign (native list)
3. Settings redesign (PreferenceList, high contrast theme)
4. Onboarding tour (first-launch walkthrough)

### Phase 4: Quality & Polish
1. Accessibility implementation (labels, focus, contrast)
2. Error/empty/permission states
3. Feedback mechanisms (crash reporting, per-screen reports)
4. Developer workflow (tests, previews, sandbox, docs)
5. Performance profiling
6. Visual QA (Light/Dark)

---

## Key Files to Modify

**Design System:**
- `Tonic/Tonic/Design/DesignTokens.swift` - Add spacing, semantic colors, custom colors
- `Tonic/Tonic/Design/DesignComponents.swift` - Card variants, new components

**New Components:**
- `Tonic/Tonic/Design/MetricRow.swift` - New shared component
- `Tonic/Tonic/Design/PreferenceList.swift` - New shared component
- `Tonic/Tonic/Design/CommandPalette.swift` - New component
- `Tonic/Tonic/Views/OnboardingTourView.swift` - New view
- `Tonic/Tonic/Views/DesignSandboxView.swift` - New view

**Navigation:**
- `Tonic/Tonic/Views/ContentView.swift` - NavigationSplitView structure
- `Tonic/Tonic/Views/SidebarView.swift` - Grouped navigation with separators

**Views (to redesign):**
- `Tonic/Tonic/Views/DashboardView.swift` - Health ring, single CTA, RAG recs
- `Tonic/Tonic/Views/SmartScanView.swift` - Tabs, progress, summary
- `Tonic/Tonic/Views/DiskAnalysisView.swift` - Hybrid view, segmented control
- `Tonic/Tonic/Views/AppInventoryView.swift` - Grid search, multi-select
- `Tonic/Tonic/Views/SystemStatusDashboard.swift` - MetricRow list
- `Tonic/Tonic/Views/WidgetCustomizationView.swift` - Native list, fix colors
- `Tonic/Tonic/Views/PreferencesView.swift` - PreferenceList, high contrast

**Documentation:**
- `docs/Design.md` - Component specifications (new)

## Quick commands

```bash
# Build the app
xcodebuild -scheme Tonic -configuration Debug build

# Run tests
xcodebuild test -scheme Tonic

# Check for hardcoded colors (auditing)
grep -r "Color(red:" Tonic/Tonic/Views/
grep -r "Color.blue\|Color.red\|Color.green" Tonic/Tonic/Views/
```

## Acceptance

### Design System
- [ ] DesignTokens has 8-point spacing values
- [ ] DesignTokens has semantic + custom colors (success, warning, info)
- [ ] Card component has 3 variants (Elevated, Flat, Inset)
- [ ] Card uses semantic colors, works in light/dark
- [ ] Typography scale matches spec
- [ ] All hardcoded RGB colors replaced

### Navigation
- [ ] Sidebar uses grouped sections with visual separators
- [ ] Section headers are non-selectable
- [ ] Cmd+K opens command palette
- [ ] Navigation works for all items
- [ ] Active item highlighted

### Components
- [ ] MetricRow component exists with sparkline support
- [ ] PreferenceList component exists
- [ ] Command palette exists and works
- [ ] SwiftUI Previews for all new components
- [ ] Unit tests for new components
- [ ] Design Sandbox screen exists

### Screens
- [ ] Dashboard: Single primary CTA, health ring with explanation
- [ ] Dashboard: RAG priority recommendations with grouped categories
- [ ] Dashboard: Activity shows last 3 items only
- [ ] Maintenance: Tabs for Scan/Clean
- [ ] Maintenance: Both circular + linear progress
- [ ] Maintenance: Stage subtext shows rapid updates
- [ ] Maintenance: Summary with Clean/Review buttons
- [ ] Disk: Segmented control for view switching
- [ ] Disk: Hybrid view (bar + treemap) works
- [ ] Disk: 3-4 levels depth, drill down works
- [ ] Apps: 4-column grid preserved
- [ ] Apps: Search bar added, multi-select works
- [ ] Activity: MetricRow list, no circular gauges
- [ ] Activity: Configurable update frequency (5/15/60min)
- [ ] Menu Bar: Native list, no decorative imagery
- [ ] Settings: PreferenceList used throughout
- [ ] Settings: High contrast theme option

### States
- [ ] Empty states: Illustrated with SF Symbols
- [ ] Permission denied: Lock overlay, explanation, action button
- [ ] Errors: Inline, banner, sheet, toast all implemented
- [ ] Onboarding: First-launch tour works

### Accessibility
- [ ] Dynamic labels on changing content
- [ ] Tab order logical on all screens
- [ ] Focus ring on all focusable elements
- [ ] Smart default focus
- [ ] Esc closes modals/sheets
- [ ] WCAG AA contrast verified
- [ ] High contrast theme works

### Performance
- [ ] App launch < 2s
- [ ] Smart Scan < 30s
- [ ] 1000+ item lists scroll at 60fps
- [ ] Disk tree loads asynchronously

### Polish
- [ ] Animations use 0.15s timing
- [ ] All strings localizable (architected)
- [ ] Crash reporting integrated
- [ ] Per-screen "Report Issue" buttons
- [ ] Light/Dark mode verified for all screens
- [ ] Design.md documentation created

## References

- Apple HIG: macOS Design Themes
- Apple HIG: Color and Semantics
- Apple HIG: Typography
- Apple HIG: Lists and Tables
- Apple HIG: Accessibility
- WCAG AA Contrast Requirements
- Existing: `Tonic/Tonic/Design/DesignTokens.swift`
- Existing: `Tonic/Tonic/Design/DesignComponents.swift`
- Existing: `Tonic/Tonic/Views/ContentView.swift`
- Existing: `Tonic/Tonic/Views/SidebarView.swift`
