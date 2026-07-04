# Tonic UI Audit Rerun

Date: 2026-06-29  
Scope: Full product UI audit against `TonicDesign.md`  
Mode: Read-only audit. No UI fixes were made.

## Executive Summary

The redesigned primary app surfaces are substantially aligned with `TonicDesign.md`: Home, Clean, Apps, Monitor, Settings, and Sidebar now mostly share the calm editorial shell, centered content columns, flat card language, mono metrics, and trust-oriented copy. The largest fidelity gap is no longer the five-screen app shell. It is the menu-bar/widget family and residual legacy settings surfaces, where `DesignTokens` colors, user-selectable accent palettes, gradients, and `NSColor.controlBackgroundColor` still leak into visible chrome.

Issue counts:

| Severity | Count |
| --- | ---: |
| Critical | 0 |
| High | 2 |
| Medium | 6 |
| Low | 4 |

Top fix order:

1. P0: Normalize menu-bar popovers and widget/module settings to TonicDS console colors and data-only status colors.
2. P0: Fix keyboard activation for custom interactive rows/cards that currently expose focus without button semantics.
3. P1: Address compact-window layout constraints and fixed-size modal/palette surfaces.
4. P1: Complete reduced-motion and icon-only accessibility coverage.
5. P2: Document or remove remaining gradient exceptions and legacy token drift.

Anti-pattern verdict: the primary screens mostly avoid the banned "glass/glow/gradient" visual language, but the product still has a visible legacy seam in menu-bar/widget configuration. That area should be treated as the next fidelity blocker before further polish.

## Audit Method

- Compared current SwiftUI components and screens to `TonicDesign.md`.
- Static inspected `Tonic/Tonic/Design`, `Tonic/Tonic/Views`, and `Tonic/Tonic/MenuBarWidgets`.
- Built a component and screen matrix across color discipline, typography, layout/radius, motion/reduced motion, accessibility, trust/safety copy, responsive behavior, and design-doc fidelity.
- Ran the requested project generation, build, and test commands.
- Did not perform live visual QA of every Light/Dark window, compact/wide window, VoiceOver path, Reduce Motion path, or every menu-bar popover. Those are recorded as follow-up validation requirements.

## Component Matrix

| Component / Family | Color | Type | Layout / Radius | Motion | Accessibility | Trust / Copy | Responsive | Fidelity |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `TonicDS` tokens | Mostly pass | Pass | Pass | Pass | Partial | N/A | N/A | Good, with token/doc drift |
| Editorial controls (`PrimaryPill`, `FilterPill`, `TextAction`) | Pass | Pass | Pass | Partial | Mostly pass | Pass | Pass | Good |
| `TonicPressStyle` | Pass | Pass | Pass | Medium gap | N/A | N/A | N/A | Press animation ignores Reduce Motion |
| `SystemListRow` | Pass | Pass | Pass | Pass | Medium gap | N/A | Pass | Focusable but not keyboard-activatable |
| `GaugeCard` / data cards | Pass | Pass | Pass | Pass | Medium gap | Pass | Pass | Good visual fidelity, interactivity gap |
| Search / empty states / notices | Pass | Pass | Pass | Pass | Mostly pass | Pass | Medium gap | Good, fixed-width search in Apps |
| Settings panels / rows | Mixed | Pass | Medium gap | Pass | Partial | Pass | Medium gap | New shell good, widget internals lag |
| Sidebar / rail rows | Pass | Pass | Medium gap | Pass | Mostly pass | N/A | Medium gap | 34 pt rows below documented control target |
| Popover template | Mostly pass | Pass | Pass | Partial | Low gap | N/A | Pass | Shared shell improved |
| Specific menu-bar popovers | High gap | Pass | Mixed | Partial | Partial | N/A | Pass | Legacy accents/control backgrounds remain |
| Widget gallery/settings | High gap | Mixed | Mixed | Partial | Partial | N/A | Mixed | Still legacy-accent driven |
| Command palette / developer tools | Pass | Pass | Medium gap | Partial | Medium gap | N/A | Medium gap | Debug-visible but not fully polished |

## Screen Matrix

| Screen / Surface | Result | Notes |
| --- | --- | --- |
| Home | Pass with minor risk | Centered 1200 pt column and data-first cards are aligned. Preserve the hero hierarchy and disk used/free semantics. |
| Clean | Pass with minor risk | Smart Scan remains the oversized voice and cleanup copy preserves Trash/review language. Fixed review sheet size needs compact validation. |
| Apps | Mostly pass | `FilterPill` replacement and inline error surfacing are aligned. Fixed search/progress widths and tappable list-row semantics need work. |
| Monitor | Mostly pass | Skeletons, mono metrics, and console-like readings align well. Metric cards that open details need keyboard activation. |
| Settings | Mixed | Shell, rail, about/version copy, and permission language are aligned. Widget/module settings still expose old accent and custom color controls. |
| Sidebar | Mostly pass | Quiet monochrome language is aligned. Row height is below the documented minimum control target. |
| Permission prompts | Mostly pass | Uses "Grant" and local permission language. Fixed prompt frame needs compact-window validation. |
| Onboarding | Mostly pass by static inspection | Shape is preserved; no broad Direct/Store terminology issue was found in the inspected pass. Needs visual/VoiceOver spot check. |
| Command palette / debug tools | Mixed | Debug-visible surfaces use the new shell but still rely on fixed frame sizing and custom row tap handling. |
| Menu-bar popovers | Failing fidelity area | Shared template is closer to TonicDS, but CPU/Memory/Disk/GPU/Network/Bluetooth/Sensors/Clock/Battery still contain legacy colors/backgrounds and chart gradients. |

## Detailed Findings

### HIGH-1: Menu-bar popovers still leak legacy accents and AppKit backgrounds

- Location:
  - `Tonic/Tonic/MenuBarWidgets/Popovers/CPUPopoverView.swift:108`, `:128`, `:174`, `:302`
  - `Tonic/Tonic/MenuBarWidgets/Popovers/MemoryPopoverView.swift:75`, `:95`, `:117`, `:143`, `:245`, `:261`
  - `Tonic/Tonic/MenuBarWidgets/Popovers/DiskPopoverView.swift:107`, `:127`, `:174`
  - `Tonic/Tonic/MenuBarWidgets/Popovers/BluetoothPopoverView.swift:83`, `:107`, `:125`, `:163`, `:268`, `:276`
  - Same pattern appears in GPU, Network, Sensors, Clock, and Battery popovers.
- Severity: High
- Design-doc rule violated: Menu-bar popovers are 280 pt dark consoles; status colors are data-only; coral/accent is brand-only; no OS accent/control background leakage.
- User impact: The menu-bar family does not feel like the same product as the main app. Legacy accent colors and `NSColor.controlBackgroundColor` make popovers look like generic utility panels instead of Tonic consoles.
- Recommendation: Retarget all popover nested containers to `TonicDS.Colors.console`, `consoleElevated`, `onDark`, `onDarkMuted`, `hairlineOnDark`, and TonicDS status colors. Keep status colors only on live values, arcs, bars, and charts. Centralize these in `PopoverTemplate`/shared popover components rather than fixing each popover ad hoc.
- Suggested validation: Open CPU, Memory, Disk, GPU, Network, Bluetooth, Sensors, Clock, and Battery popovers in Light and Dark system modes. Confirm fixed 280 pt console chrome, no `DesignTokens.Colors.accent`, no `controlBackgroundColor`, and no broad link-blue/coral chrome.

### HIGH-2: Widget/module settings still expose legacy accent customization as product chrome

- Location:
  - `Tonic/Tonic/Views/WidgetsPanelView.swift:535`, `:542`, `:546`, `:562`, `:566`, `:590`
  - `Tonic/Tonic/Views/Settings/ModulesSettingsContent.swift:128`, `:540`, `:546`, `:573`, `:584`, `:589`, `:687`, `:706`, `:1001`, `:1105`, `:1178`, `:1209`
  - `Tonic/Tonic/MenuBarWidgets/Settings/ModuleSettingsView.swift:94`, `:129`
  - `Tonic/Tonic/MenuBarWidgets/Settings/PopupSettingsView.swift:114`, `:122`, `:134`, `:141`, `:294`, `:361`
- Severity: High
- Design-doc rule violated: Data colors only on data; coral/brand accent only for rare brand/taxonomy moments; avoid old theme/accent systems in visible UI.
- User impact: Users can configure or see accent-heavy UI that conflicts with the new product position. It also keeps the app visually split between new TonicDS and the older widget customization system.
- Recommendation: Recast widget color controls as data visualization preferences only, or remove broad accent swatches from visible chrome. Module status indicators should use TonicDS status colors only when representing actual live state; enabled/selected chrome should use ink/surface/hairline.
- Suggested validation: Open Settings > Widgets and module settings. Confirm selected/enabled states are monochrome, status colors are tied to live status or data semantics, and custom swatches do not theme shell chrome.

### MEDIUM-1: Focusable custom rows/cards do not consistently activate from keyboard

- Location:
  - `Tonic/Tonic/Design/TonicEditorialComponents.swift:478` through `:504` (`SystemListRow`)
  - `Tonic/Tonic/Design/TonicEditorialChrome.swift:151` through `:156` (`GaugeCard`)
  - `Tonic/Tonic/Views/ContentView.swift:648` through `:679` (`CommandPaletteView.paletteRow`)
- Severity: Medium
- Design-doc rule violated: Native Mac utility controls should be keyboard navigable and accessible; focus affordances must map to real activation behavior.
- User impact: A row/card can appear focusable but may not activate with Space/Return like a button. This is especially visible in Apps selection rows, Monitor cards, and command palette rows.
- Recommendation: Convert interactive `SystemListRow`, `GaugeCard`, and command-palette rows to `Button` with `.buttonStyle(.plain)` and `tonicFocusableControl`, or add explicit Return/Space handling plus `.accessibilityAddTraits(.isButton)`.
- Suggested validation: Navigate Apps rows, Monitor metric cards, and command palette rows using keyboard only. Confirm focus ring, Space/Return activation, and VoiceOver announcement as actionable controls.

### MEDIUM-2: Compact-window behavior still has hard-width surfaces

- Location:
  - `Tonic/Tonic/Views/Apps/AppsView.swift:22` through `:24` fixed 240 pt search field
  - `Tonic/Tonic/Views/Apps/AppsView.swift:148` through `:153` fixed 240 pt loading progress
  - `Tonic/Tonic/Views/Apps/AppsView.swift:184` through `:185` fixed 64 pt size column
  - `Tonic/Tonic/Views/Settings/SettingsView.swift:26` through `:30` max 640 pt content column
  - `Tonic/Tonic/Views/Settings/SettingsView.swift:62` through `:64` fixed 220 pt rail
  - `Tonic/Tonic/Views/ContentView.swift:290`, `:392`, `:625` fixed prompt/sheet/palette frames
- Severity: Medium
- Design-doc rule violated: Content should center at the 1200 pt max but adapt in compact windows; controls should not crowd or clip.
- User impact: Narrow windows can make the Apps header, Settings, permission prompt, cleanup review sheet, or command palette feel cramped or clipped.
- Recommendation: Use responsive min/max frames, `ViewThatFits`, or geometry breakpoints. Allow header controls to wrap/stack. Keep modal/palette max sizes but permit smaller widths and heights with internal scrolling.
- Suggested validation: Resize main window to compact widths and inspect Home, Clean review, Apps search/list, Settings, permission prompt, and command palette. Confirm no clipped text or unusable controls.

### MEDIUM-3: Sidebar and Settings rail rows are below the documented control target

- Location:
  - `Tonic/Tonic/Views/SidebarView.swift:135` through `:137`
  - `Tonic/Tonic/Views/Settings/SettingsView.swift:78` through `:79`
- Severity: Medium
- Design-doc rule violated: Controls should be 36 pt minimum and rows should be 44 pt where they behave as primary row targets.
- User impact: Sidebar and settings navigation rows feel slightly tight compared with the rest of the redesigned shell and reduce hit comfort for keyboard/mouse users.
- Recommendation: Raise rail/sidebar row heights to at least 36 pt, or 40-44 pt if treating them as navigation rows. Validate that the sidebar still keeps the desired density.
- Suggested validation: Compare sidebar/rail rows against `PrimaryPill`, `FilterPill`, and `SystemListRow`; verify target size and text centering at normal and large text settings.

### MEDIUM-4: Reduced Motion is not fully respected for press and palette interactions

- Location:
  - `Tonic/Tonic/Design/TonicEditorialComponents.swift:16` through `:23` (`TonicPressStyle`)
  - `Tonic/Tonic/Views/ContentView.swift:559`, `:567` command-palette selection animation
- Severity: Medium
- Design-doc rule violated: All motion must respect Reduce Motion.
- User impact: Users who request reduced motion still get scale/animated selection feedback on common controls.
- Recommendation: Pass `accessibilityReduceMotion` into a motion-aware button style or create a `tonicPressStyle(reduceMotion:)` wrapper. Replace palette selection animations with nil/opacity-only behavior when Reduce Motion is enabled.
- Suggested validation: Enable Reduce Motion in macOS Accessibility. Use Sidebar, Apps chips, primary buttons, and command palette keyboard navigation. Confirm no scale or directional movement.

### MEDIUM-5: Data-visualization gradients need explicit containment

- Location:
  - `Tonic/Tonic/Views/Apps/AppsView.swift:80` through `:85`
  - `Tonic/Tonic/MenuBarWidgets/Views/LineChartWidgetView.swift:33`, `:265` through `:267`
  - `Tonic/Tonic/MenuBarWidgets/Views/BarChartWidgetView.swift:311`
  - `Tonic/Tonic/MenuBarWidgets/Components/SparklineChart.swift:96`
  - `Tonic/Tonic/MenuBarWidgets/Modules/MemoryWidgetView.swift:240`, `:249`
- Severity: Medium
- Design-doc rule violated: No decorative gradients; data is the media.
- User impact: Most listed gradients are probably functional chart fills or overflow fades, but without shared constraints they can drift back into decorative styling.
- Recommendation: Keep chart gradients only as low-opacity data-area fills and wrap overflow fades in a named utility, for example `TonicOverflowFade`. Avoid gradient fills on buttons, cards, panels, or non-data chrome.
- Suggested validation: Static scan for `LinearGradient`, `.gradient`, and `AngularGradient`; visually confirm every remaining gradient is either a data area fill or a utilitarian fade.

### MEDIUM-6: Debug-visible command palette/developer actions lack full accessibility polish

- Location:
  - `Tonic/Tonic/Views/ContentView.swift:481` through `:487` developer tool action buttons
  - `Tonic/Tonic/Views/ContentView.swift:648` through `:679` command palette rows
- Severity: Medium
- Design-doc rule violated: Debug/WIP routes can remain, but visible surfaces should not look or behave outside the product family.
- User impact: Debug routes are visible in Debug builds and can be used during QA. Icon-only actions may announce poorly, and palette rows rely on custom tap behavior.
- Recommendation: Add explicit accessibility labels/hints for icon-only debug actions and convert palette rows to button semantics.
- Suggested validation: VoiceOver pass on debug tools and command palette; keyboard-only open, move selection, activate, and dismiss.

### LOW-1: Some icon-only buttons are missing explicit VoiceOver labels

- Location:
  - `Tonic/Tonic/Design/TonicEditorialChrome.swift:266` through `:272` sheet close button
  - `Tonic/Tonic/MenuBarWidgets/Popovers/PopoverTemplate.swift:123` through `:132` header gear button
  - `Tonic/Tonic/MenuBarWidgets/Popovers/PopoverTemplate.swift:190` through `:203` `HoverableButton`
- Severity: Low
- Design-doc rule violated: Native Mac controls should have clear accessibility labels and hints, especially icon-only buttons.
- User impact: VoiceOver may announce only the SF Symbol or a generic "button", which slows users down in sheets/popovers.
- Recommendation: Add `.accessibilityLabel` and, where helpful, `.accessibilityHint` to close, settings, refresh, and other icon-only actions. Prefer label text that names the command, not the icon.
- Suggested validation: VoiceOver spot check on Clean review sheet, popover settings gear, and popover toolbar buttons.

### LOW-2: TonicDS status token values intentionally drift from the design document

- Location:
  - `Tonic/Tonic/Design/TonicDS.swift:131` through `:135`
  - `Tonic/TonicTests/DesignSystemTests/TonicDSPolishTests.swift` covers console status contrast
- Severity: Low
- Design-doc rule violated: Source token values differ from the doc palette for critical/info status colors.
- User impact: Low visual risk because the test suite confirms AA contrast for console status text. The risk is handoff confusion: designers and engineers may compare against different hex values.
- Recommendation: Either update `TonicDesign.md` with the contrast-adjusted status values or add a source comment explaining the variance as an accessibility adjustment.
- Suggested validation: Keep `TonicDSPolishTests.testConsoleStatusColorsMeetWCAGAAForText` and add a token-doc snapshot check if the doc becomes a generated artifact.

### LOW-3: Legacy glass/glow/world tokens remain reachable in old token files

- Location:
  - `Tonic/Tonic/Design/TonicThemeTokens.swift:442`, `:450`, `:462`, `:464`, `:496`, `:528`, `:555`, `:563`, `:571`, `:579`, `:844` through `:848`
  - `Tonic/TonicTests/DesignSystemTests/TonicThemeTokensTests.swift` still contains tests for derived glow/glass profiles.
- Severity: Low
- Design-doc rule violated: Avoid old glass/world palettes and glow language in the visible redesign.
- User impact: These tokens are not necessarily visible on the primary redesigned routes, but they make future regressions easy and keep tests validating old visual vocabulary.
- Recommendation: Bridge visible consumers to TonicDS first, then quarantine legacy tokens behind explicit legacy names or remove tests that encode glass/glow as desired output.
- Suggested validation: Static scan for `glow`, `glass`, `vignette`, `.accentColor`, and old theme token usage after each polish pass.

### LOW-4: The Apps overflow fade is a permissible exception but should be named

- Location:
  - `Tonic/Tonic/Views/Apps/AppsView.swift:65` through `:87`
- Severity: Low
- Design-doc rule violated: The doc bans decorative gradients; this one is a utilitarian overflow affordance.
- User impact: Minimal. The risk is future contributors treating it as permission for decorative gradient surfaces.
- Recommendation: Move the fade into a named helper such as `TonicOverflowFade` and document that it is an edge affordance, not surface styling.
- Suggested validation: Apps horizontal filter strip in compact and wide windows; confirm the fade does not obscure chip text or suggest a decorative brand treatment.

## Positive Findings To Preserve

- Home keeps Smart Scan as the primary story, centers content at `TonicDS.Layout.maxContentWidth`, and uses live metrics as the visual media.
- Clean preserves preview, Trash/restore-oriented copy, run summaries, and inline notices. The "Clean" label is visually demoted under the Smart Scan voice.
- Apps now uses `FilterPill`, surfaces scan/uninstall errors inline, and keeps destructive uninstall copy scoped to "Move to Trash".
- Monitor avoids zero-flash with skeleton placeholders and uses mono/numeric metric treatment.
- `PopoverTemplate` now defaults `headerColor` to `TonicDS.Colors.onDark` and uses `TonicDS.Colors.console` / `consoleElevated`, which is the right shared direction.
- Settings/About now includes version/build and local-first product language.
- `TonicDSPolishTests` covers status contrast and `GaugeCard` formatting, which should stay as guardrails.

## Systemic Patterns And Risk Areas

- The main app shell has moved to TonicDS; the menu-bar/widget family still straddles TonicDS, `DesignTokens`, AppKit system colors, and user accent palettes.
- Accessibility work is strongest where native `Button` is used. Custom tap surfaces need a policy: if it activates, it should be a button or implement equivalent keyboard and VoiceOver behavior.
- Reduced Motion is handled in major reveal/status components but not in all micro-interactions.
- Static visual policy should be enforced by scans for `DesignTokens.Colors.accent`, `.accentColor`, `controlBackgroundColor`, `LinearGradient`, `.gradient`, `glow`, `glass`, and `vignette`.
- Compact-window QA remains under-verified. The code has several fixed-width surfaces that deserve actual resize testing.

## Priority Fix Sequence

### P0 Fidelity Blockers

1. Normalize CPU/Memory/Disk/GPU/Network/Bluetooth/Sensors/Clock/Battery popovers to TonicDS console tokens and data-only status colors.
2. Remove or reframe widget accent customization so it does not theme product chrome.
3. Convert interactive `SystemListRow`, `GaugeCard`, and command-palette rows to real button semantics or equivalent keyboard activation.

### P1 Product Craft

1. Make Apps search/progress, Settings rail/content, permission prompt, Clean review sheet, and command palette responsive to compact windows.
2. Raise sidebar/settings rail row targets to at least the documented minimum.
3. Complete Reduce Motion handling for press feedback and command palette movement.
4. Add VoiceOver labels/hints to icon-only sheet and popover controls.

### P2 Polish

1. Wrap allowed overflow/chart gradients in named utilities and remove decorative gradient affordances.
2. Update `TonicDesign.md` or code comments for contrast-adjusted status token values.
3. Quarantine legacy glass/glow/world tokens and tests after visible consumers are bridged.
4. Add a lightweight static visual-policy test for banned tokens on primary app and popover surfaces.

## Validation Results

Commands run:

```sh
cd /Users/saransh1337/Developer/Projects/TONIC/Tonic && xcodegen generate
xcodebuild -project Tonic.xcodeproj -scheme Tonic -configuration Debug -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO
xcodebuild -project Tonic.xcodeproj -scheme Tonic -configuration Debug -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO
```

Results:

- `xcodegen generate`: passed, project regenerated.
- Debug macOS build: passed, `** BUILD SUCCEEDED **`.
- Debug macOS tests: passed, `462 tests, 0 failures`.
- Xcode emitted the existing warning that multiple macOS destinations matched and selected one automatically.

Manual QA not completed in this audit:

- Full Light/Dark visual pass.
- Compact/wide live resize pass.
- Keyboard-only end-to-end pass.
- VoiceOver spot check.
- Reduce Motion live behavior check.
- Live capture/inspection of every menu-bar popover.

These manual items should be done after P0 fixes, because the current static findings already identify the highest-value fidelity blockers.
