---
version: 3.0
name: Tonic-design
description: Tonic's design language — "Liquid Tonic" — is a calm native macOS command center rendered as layered glass over the desktop. A floating icon rail and translucent surfaces let the wallpaper glow through as the light source, while the readout keeps every drop of color: near-black smoked-glass monitoring consoles, deep enterprise-green and dark-navy band glass, rounded data cards, and a research-lab type split between SF Pro display/body text and SF Mono technical labels. The shell is glass; the data is the media.

colors:
  # Anchors (dual light/dark)
  ink: "#17171c"
  ink-pure: "#0a0a0f"
  canvas: "#ffffff"
  canvas-dark: "#0a0a0f"
  canvas-soft: "#f6f4ef"
  canvas-soft-dark: "#121318"
  # Brand bands & console (constant across appearances)
  console: "#17171c"
  console-elevated: "#1d1d24"
  deep-green: "#003c33"
  deep-green-soft: "#0b1f1b"
  dark-navy: "#071829"
  dark-navy-soft: "#0c1a2b"
  # Warm neutral surface
  soft-stone: "#eeece7"
  soft-stone-dark: "#16161c"
  pale-green: "#edfce9"
  pale-blue: "#f1f5ff"
  # Rules & borders
  hairline: "#d9d9dd"
  hairline-dark: "#2a2a32"
  hairline-on-dark: "#ffffff @ 0.10"
  glass-stroke-light: "#17171c @ 0.10"
  glass-stroke-dark: "#ffffff @ 0.14"
  border-light: "#e5e7eb"
  card-border: "#f2f2f2"
  # Text
  text-primary-light: "#212121"
  text-primary-dark: "#f4f3ef"
  text-muted-light: "#75758a"
  text-muted-dark: "#93939f"
  # Brand accent (RESERVED — brand/identity only, never on data)
  brand-accent: "#176b58"          # mineral green; dark-mode lift #5cc7a7
  brand-accent-soft: "#dcefe8"     # dark-mode #14352c
  link-blue: "#1863dc"             # dark-mode #5b93ff
  # Status scale (DATA ONLY — never brand, surface tint, or chrome)
  status-success: "#1f9d57"
  status-warning: "#e0a32c"
  status-caution: "#e07b39"
  status-critical: "#d14b4b"       # dark-mode lift #e05252
  status-info: "#3a78d6"           # dark-mode lift #5b93ff
  # Semantic
  focus: "#4c6ee6"
  on-dark: "#ffffff"
  on-light: "#17171c"
  overlay-dim: "#000000 @ 0.30"

glass:
  # Z0 canvas wash over the behind-window blur, per user intensity
  canvas-wash-regular: "0.50 dark / 0.65 light"
  canvas-wash-subtle: "0.78"
  canvas-wash-off: "1.00 (flat editorial fallback)"
  # Z1 washes over SwiftUI Material
  surface-wash: 0.55        # thin material + surface (or component tint)
  smoked-wash: 0.65         # ultra-thin material + console; 0.60 is the FLOOR
  band-wash: 0.85           # thin material + deep-green/navy
  overlay-wash: 0.70        # thick material + canvas (sheets, palette)

typography:
  # Shipped native scale (TonicDS.TypeRole). Display face is SF Pro Display
  # fallback until TonicDisplay is bundled. Line heights via .tonicType(_:).
  hero-display:    { size: 40pt, weight: 500, tracking: -0.70pt, lineHeight: 1.02 }
  section-display: { size: 28pt, weight: 500, tracking: -0.35pt, lineHeight: 1.05 }
  card-heading:    { size: 17pt, weight: 500, tracking: -0.10pt, lineHeight: 1.15 }
  feature-heading: { size: 17pt, weight: 600, tracking: 0,      lineHeight: 1.25 }
  body-large:      { size: 16pt, weight: 400, tracking: 0,      lineHeight: 1.45 }
  body:            { size: 14pt, weight: 400, tracking: 0,      lineHeight: 1.50 }
  button:          { size: 13pt, weight: 600, tracking: 0,      lineHeight: 1.20 }
  caption:         { size: 12pt, weight: 400, tracking: 0,      lineHeight: 1.40 }
  mono-label:      { family: SF Mono, size: 11pt, weight: 500, tracking: 0.50pt, lineHeight: 1.30 }
  metric:          { family: SF Mono, size: 28pt, weight: 500, lineHeight: 1.00 }
  metric-small:    { family: SF Mono, size: 20pt, weight: 500, lineHeight: 1.00 }
  micro:           { size: 11pt, weight: 400, lineHeight: 1.35 }

rounded:
  xs: 4pt
  sm: 8pt
  md: 12pt          # console / list panels
  lg: 16pt          # module bands / settings panels
  card: 22pt        # signature data-card radius
  pill: 32pt
  full: 9999pt

spacing:
  xxs: 4pt
  xs: 8pt
  sm: 12pt
  md: 16pt
  lg: 24pt
  xl: 32pt
  xxl: 40pt
  xxxl: 48pt
  section: 64pt

motion:
  # Shipped TonicDS.Motion values plus contextual flagship recipes.
  instant: 0.10s
  feedback: 0.14s   # press, numeric transitions
  transition: 0.21s # appear, present
  layout: 0.27s     # settle
  proof: 0.39s
  stagger: 0.05s per index
  glass-morph: "layout curve; structural expansion only"
  mineral-ripple: "brief activation/apply/restore proof"
  orbital-particles: "rare discovery or completion moments only"
---

## Overview

Tonic is a native macOS command center for system health. **Liquid Tonic** renders that instrument as layered glass floating over the desktop: the window is a translucent sheet (behind-window blur pulls the wallpaper in as the light source), navigation lives in a floating icon capsule detached from the window edges, and content sits on washed glass panels separated by hairlines. The shell is luminous but quiet — all color and energy still come from the readout itself: gauges, charts, sparklines, status arcs, and the smoked-glass consoles that render live metrics in mono type.

Two rules govern everything:

1. **The data is the media.** Status color (green→yellow→orange→red) belongs to measured machine state only. The brand mineral-green accent belongs to brand and primary actions only. Neither ever crosses over. Chrome never competes with the numbers.
2. **Glass is chrome, never meaning.** Translucency is the shell's material, not a signal. No reading, state, or category is ever communicated by glass vs. flat, and every glass layer degrades to the flat editorial fill (the previous shipped design) when transparency is reduced.

This language supersedes the flat "editorial command center" system as the default presentation — but keeps it, byte-for-byte, as the reduced-transparency tier. The palette, typography, spacing grid, radius scale, and status discipline carry over unchanged.

Version 3.0 retains the Wave 4 hybrid workspace language and adds three flagship instruments: Recovery Center for evidence-led repair, Top Shelf for deliberate context, and the curated provider marketplace. The design remains calm under denial and failure: an unavailable private adapter never erases its public fallback, a report-only Store action never impersonates execution, and every disruptive recovery step stays visible and removable before confirmation.

## Wave 5 product posture

Tonic 5 is fully unlocked in both editions. Production UI contains no tier chip, paywall, trial, purchase limit, or license activation. Dormant commerce code compiles only under `TONIC_COMMERCE`; legacy license preferences remain untouched. Edition language describes macOS capability boundaries rather than commercial value.

Recovery Center is the canonical `Clean` recovery workspace. Diagnostics are read-only and evidence-led. A plan is ordered, editable, interruption-aware, and explicit about disruption, duration, privilege, and recovery behavior. Each disruptive step receives focused confirmation, execution stops at the first failure, and proof consists of a per-step receipt, measured post-check, and aggregate receipt.

Top Shelf is an active-display `NSPanel` with a calm capsule state and an expanded instrument state. Cached modules appear immediately while actors refresh. Status item, hotkey, Quick Search, and an optional gesture are equivalent entry points. Ambient Now Playing, next-event, and actionable health content requires one explicit set-level confirmation and independent module switches thereafter. Calendar access is contextual; Clipboard is read only after deliberate opening and is never persisted. Ambient presentation never steals keyboard focus.

The marketplace visually separates publisher identity, permissions, endpoint and refresh behavior, compatibility, health, and release provenance. Signature, revocation, permission expansion, unsupported schema, and host incompatibility are first-class states. Installation and update proof never relies on color alone.

Automatic Space contexts and foreign menu proxying are direct-only compatibility layers, not foundations. The settings surface always states the current signed compatibility decision and preserves manual contexts and ordinary Quick Shelf behavior. Foreign menu sessions are ephemeral, bounded, keyboard accessible, and fall back to the original item whenever mapping is ambiguous.

Per-app window rules use the existing placement vocabulary and receipt language. Matching evidence, deterministic priority, delay, cooldown, and restore are visible. Store users can build and preview the same rules without a false claim of automatic movement.

All Wave 5 user-facing copy is prepared for English, Spanish, German, French, Japanese, and Simplified Chinese String Catalogs. Layout tolerates pseudolocalization, German expansion, CJK line breaking, larger accessibility text, keyboard order, and VoiceOver without fixed-height clipping.

## Motion and accessibility

Motion communicates cause and effect. Glass morphs explain structural expansion; mineral ripples confirm deliberate Apply, restore, alignment, and success; orbital particles are reserved for first discovery and rare completion. Shared recipes are governed by `TonicMotionPolicy`, never authored ad hoc in feature rows.

- Reduce Motion removes displacement, particles, morphing, and motion-implying haptics. Pressed controls retain opacity feedback without scale.
- Reduce Transparency resolves every glass surface to a semantic flat fill and stroke.
- Increased Contrast strengthens boundaries without changing information hierarchy.
- Every drag action has keyboard and context-menu equivalents; every gesture has a button equivalent.
- Numeric updates use restrained ticker transitions and remain fully readable by VoiceOver.

## Menu Bar flagship workspace

Organize → Menu Bar is the canonical destination. Its top-level sections are Layout, Reveal, Automations, and Appearance. Setup is a compact trust-first journey: choose On-Demand (recommended) or Live enforcement, grant only contextual access, review a conservative draft, then Apply once. Accessibility is requested only by the direct build; Screen Recording remains optional and is used only for richer ephemeral item imagery and explicitly opted-in update watching.

The layout editor uses stable persisted sections while presenting them as **Visible**, **On Demand**, and **Quiet**. Dragging edits only a local draft. A sticky footer summarizes changes and offers Apply Layout or Discard. Apply produces a moved/failure receipt and one-step Undo. System essentials are never recommended for hiding, and Quiet is never recommended automatically.

Quick Shelf is the user-facing name for the legacy Tonic Bar implementation. Its global presentation is Compact Icons, Labeled Grid, or Searchable List; groups may override it. Groups live in Quick Shelf by default and may be pinned with an SF Symbol and accessible accent. Tonic-owned spacers, groups, and custom items are created from the Layout palette.

Reveal supports collapse-control click, menu-bar dwell, empty-space click, and scroll/two-finger swipe. It is throttled, active-display aware, auto-rehides, and suppresses surprise presentation in full-screen contexts. Offscreen or notch-obscured items surface in Quick Shelf Overflow without rewriting saved placement.

Update watching is explicitly enabled per item. Screen imagery is processed locally and remains ephemeral; persistence contains only a nonreversible digest, unseen state, and the minimum display asset. Activating the real item from the bar, Quick Shelf, group, or Quick Search acknowledges the update.

Custom provider items use one versioned async interface for built-in, reviewed HTTPS, and direct executable sources. Remote sources expose their URL, interval, private-network policy, and response bound at review; secret material lives only in the data-protection Keychain. Direct `.tonicprovider` bundles run as the user with bounded line-delimited Codable I/O, require Developer ID signing in production, and allow immutable-hash approval only in Advanced mode. Provider snapshots are display-only and can never invoke actions or the helper.

Presentation profiles resolve global → attached display → manual named context. Display overrides may change appearance, reveal behavior, Quick Shelf target/presentation, overflow, and inactive-display presentation. Manual Work/Home/Recording-style contexts are selectable directly or by reversible triggers. Foreign-item physical placement remains one global layout because macOS exposes no supported per-display ordering API; active-Space notifications refresh wallpaper and supported triggers but no undocumented Space identifier is stored.

Appearance begins with Clear, Mineral Glass, Obsidian, and Match Wallpaper presets. Real-bar preview is temporary and always has Apply and Cancel/rollback. Advanced controls cover two-stop gradients, border, shadow, opacity, corner radius, and capsule/full-width layout. The migrated global appearance remains the default; public-API display profiles and manual named contexts may override presentation without claiming per-display foreign-item placement.

## Custom items and execution safety

The safe custom-item builder supports SF Symbols or user-selected images; static and formatted date/time, battery, processor, memory, network, and weather data; and multiple actions that open an app, file, URL, Tonic destination, or Apple Shortcut. Store builds receive this safe model and editor.

Direct builds may additionally define scripts with an explicit shell/executable, argument array, security-scoped file or working-directory selections, environment allowlist, and timeout. Scripts never cross the privileged-helper boundary. Click, reviewed schedules, and automation-triggered runs share one policy: unattended runs require a full command-and-condition review, overlapping executions are rejected, three consecutive failures pause the action until an explicit review, output is independently truncated and sanitized, optional mapped labels are bounded to one line, and every run creates a structured receipt.

## History and privileged maintenance

Monitor cards share Live / 1h / 24h / 7d / 30d controls. `WidgetHistoryStore` owns live and short presentation history; `LongTermMetricsStore` owns local minute/hour/day weighted rollups, retention, atomic persistence, import, Disable, Clear, and storage-size reporting. Disabled history performs no long-term writes while live monitoring continues. Unsupported GPU or temperature series are omitted with capability copy rather than zero-filled charts.

The direct build installs `TonicHelper` only when a privileged operation is chosen. Every run begins with a review sheet. The XPC contract is a closed, versioned Codable allowlist with no caller-provided privileged paths or commands. Client and helper verify team and identifier requirements reciprocally; malformed, oversized, unauthorized, or version-incompatible requests are rejected before dispatch. Fixed-tool output is collected asynchronously with strict bounds and a timeout so cleanup cannot block watchdog heartbeats. Fan control uses a heartbeat watchdog that restores Automatic on quit, crash, disconnect, or renewal loss. Store builds omit every helper/client/write source and retain report-only explanations.

**Key characteristics:**
- The whole window is a glass slab; the desktop glows through at a user-set intensity (Regular / Subtle / Off).
- A floating 56pt icon capsule rail (Z3 Liquid Glass) replaces the docked sidebar; labels surface as hover flyouts.
- The near-black **monitoring console** becomes **smoked glass** — an ultra-thin material under a `#17171c` wash that never drops below 0.60 opacity, so status readouts always sit on a near-black field.
- Deep-green / navy module bands read as **colored glass** (0.85 wash) — brand identity, translucent but unmistakable.
- Rounded data cards (22pt), pill controls, SF Mono metrics, hairline structure — all unchanged from the editorial system.
- One oversized display voice per screen; restrained motion; Reduce Motion and Reduce Transparency are first-class tiers, not afterthoughts.

## Colors

The palette is unchanged from the editorial system. Brand identity (ink/canvas anchors, deep-green and navy bands, soft-stone warmth, the reserved mineral-green accent) is constant across light/dark; only the neutral stack inverts.

### Brand & Band
- **Ink** (`#17171c`): primary CTAs, high-contrast text on light. The brand anchor.
- **Ink Pure** (`#0a0a0f`): alert banner; deepest obsidian base.
- **Deep Enterprise Green** (`#003c33`) / **Dark Navy** (`#071829`): module band tints — healthy/cleanup vs. protection/security.
- **Brand Accent — Mineral Green** (`#176b58`, dark lift `#5cc7a7`): **reserved** for primary actions, selection, focusable identity (e.g. the rail's selected icon). Never a gauge color, never a glass tint. (The former coral accent is retired; `accentCoral` remains only as a code alias to this green.)
- **Link Blue** (`#1863dc` / `#5b93ff`): inline navigation links only.

### Status Scale — DATA ONLY
`status-success #1f9d57` (0–50%) → `status-warning #e0a32c` (50–75%) → `status-caution #e07b39` (75–90%) → `status-critical #d14b4b/#e05252` (90–100%), plus `status-info` for neutral/charging. Resolved exclusively through `TonicDS.statusLevel(forFraction:/forTempC:/forBattery:)`; every status color pairs with a status word ("Healthy/Elevated/High/Critical") for VoiceOver and chips. Categorical series colors (E/P-core, read/write, memory composition) derive from these hues.

### Tint & Wash table (glass mode)

| Layer | Material | Wash | Stroke |
|---|---|---|---|
| Z0 window | behind-window blur (AppKit) | `canvas` @ 0.50 dark / 0.65 light (Regular); 0.78 (Subtle) | — |
| Z1 `.surface` | `.thinMaterial` | `surface` (or component tint: soft-stone, canvas-soft) @ 0.55 | `glass-stroke` |
| Z1 `.smoked` | `.ultraThinMaterial` | `console #17171c` @ 0.65 — **0.60 floor, non-negotiable** | `hairline-on-dark` |
| Z1 `.band` | `.thinMaterial` | `deep-green` / `dark-navy` @ 0.85 | none |
| Z2 `.overlay` | `.thickMaterial` | `canvas` @ 0.70 | `glass-stroke` |
| Z3 `.chrome` | Liquid Glass (`glassEffect`) | none — system rim | system |

The smoke floor exists because status colors at 11pt mono only meet contrast on a near-black field; 0.60 keeps the worst-case composite dark even over a white wallpaper.

## Typography

Unchanged. Three voices: a tight display face (SF Pro Display fallback for the unbundled `TonicDisplay`), SF Pro Text for UI/body, and **SF Mono for every technical label, unit, and metric**. One oversized display voice per screen. Measured values additionally use `.monospacedDigit()`. Roles and exact values are in the frontmatter and `TonicDS.TypeRole`.

## Materials & Elevation — the Z-model

Depth is layered light, not shadow stacking. Four Z-tiers, each with a single resolution point in code (`.tonicSurface(_:in:)`, `.tonicCanvas()`, `.tonicSheetBackground()`, `.tonicPopoverConsole()` in `Design/TonicGlass.swift`, governed by `TonicGlassPolicy`):

| Tier | What | Treatment | Examples |
|---|---|---|---|
| **Z0 — Desktop light** | The window floor | `NSVisualEffectView` behind-window blur + canvas wash at the user's glass intensity | `TonicWindowChrome` at the shell root |
| **Z1 — Surfaces** | Content panels | SwiftUI `Material` + color wash + hairline | `DataCard`, `SettingsPanel`, `ScanCategoryCard`, search fields (`.surface`); `MonitoringConsole`, `MetricConsole`, toasts, widget popovers (`.smoked`); `ModuleBand` (`.band`) |
| **Z2 — Overlays** | Modal layer | `.thickMaterial` + canvas wash + `overlay-dim` scrim behind | Sheets (`presentationBackground`), command palette, permission prompt, rail flyout labels |
| **Z3 — Chrome** | Floating controls | True Liquid Glass (`glassEffect` in a `GlassEffectContainer`) | Floating rail, hub capsule bar, ActionDock, Tonic Bar, Quick Search panel |

Rules:
- **Z3 is the only `glassEffect` tier**, and at most ~3 chrome elements are visible per window. Z1 uses cheap `Material` — bento grids render many cards.
- Text never sits directly on Z0; it always has a Z1+ surface (or the hero declaration sits on the washed canvas itself, which counts).
- The shadow rule survives verbatim: **one** `cardLift` soft shadow to lift a card, dock, or rail — never stacked, never colored.
- Smoked surfaces force the dark color scheme for their children regardless of window appearance, exactly as the flat consoles did.
- Flat fallback: when `TonicGlassPolicy.isGlassEnabled == false` (app Reduce Transparency, system accessibility setting, or intensity Off), every layer resolves to the shipped editorial fill — `surface`+`card-border`, `console`, solid bands, flat canvas. That tier is the fully-QA'd previous design and must remain screenshot-perfect.

## Layout

### Shell (two distinct floating surfaces in one transparent window)
- **Glass slab** (`TonicGlassSlab`): the app content lives on a 26pt-radius glass sheet (behind-window blur + canvas wash + glass stroke) inset 56pt from the window's leading edge and 8pt from the other edges — the window itself is fully transparent, so the slab reads as its own floating pane over the desktop.
- **Floating rail** (`FloatingRailView`): a vertically-centered 56pt glass capsule floating in the transparent leading gutter, **outside the slab and overlapping its left edge by ~10pt** — visibly a separate element, per the reference mockup. Contents: app glyph, five hub icons (44×44), hairline, All Tools (⌘K), Settings, edition dot. Selection = brand-accent icon on a quiet circle; labels via `.help()` tooltips + hover flyout capsules (0.4s delay). Keyboard: ⌘1–5 hubs, ⌘K palette; full focus-ring and VoiceOver support.
- **Flat tier**: when glass is reduced, the shell reverts to the full-window canvas with the rail in a leading safe-area gutter (the shipped editorial layout).
- **Hub bar**: each hub's tool switcher is a floating glass capsule (Z3) at the top of the slab, hugging its content, clear of the traffic lights.
- **Window**: `hiddenTitleBar` + `fullSizeContentView`, transparent (`isOpaque = false`), movable by background. Content max width 1200pt, centered in wide windows.
- The **alert banner** stays an opaque `ink-pure` strip across the top of the slab — global alerts are not translucent.

### Spacing, grid, whitespace
Unchanged: 8-pt grid with a 64pt section interval; screens keep believing they own the full pane (the rail lives in the safe area, so `tonicScreenHPadding` breakpoints — compact <900, wide ≥1200 — reflow untouched). Whitespace separates status → proof → action; density appears only in consoles, lists, and forms.

## Shapes

Radius scale unchanged (see frontmatter); 22pt cards and 12pt consoles remain the dominant radii; the rail and pills are capsules. Visualizations fill their cards edge-to-edge, clipped by the card radius; never framed in heavy chrome.

## Components

Layer assignments for the shipped component library (call sites don't choose materials — components resolve their own layer internally):

| Component | Layer | Notes |
|---|---|---|
| `floating-rail` | Z3 chrome | New shell navigation; replaces the docked sidebar spec |
| `hub-bar` (tool switcher capsule) | Z3 chrome | Title + segmented tools in a floating capsule |
| `ActionDock`, toasts | Z3 chrome / Z1 smoked | Toast keeps its dark console-capsule identity |
| `DataCard`, `GaugeCard`, `ChartCard` | Z1 `.surface` | 22pt radius, glass stroke, one hover-deepened lift |
| `SettingsPanel`, `TonicSearchField`, machine strip | Z1 `.surface` | Flat fallback keeps their hairline border |
| `ScanCategoryCard` | Z1 `.surface` (soft-stone tint) | Warm glass; flat fallback is borderless soft-stone |
| `MonitoringConsole`, `MetricConsole`, widget popovers, OneView | Z1 `.smoked` | Forced-dark children; status colors on near-black |
| `ModuleBand` | Z1 `.band` | Deep-green/navy colored glass @ 0.85 |
| `SheetChrome`, onboarding, reset/folder-scan sheets | Z2 overlay | Via `presentationBackground` thick material |
| Command palette, permission prompt | Z2 overlay | Over the `overlay-dim` scrim |
| Tonic Bar, Quick Search (floating NSPanels) | Z3 chrome | Real Liquid Glass; flat fallback = solid console |
| `PrimaryPill`, `TextAction`, `FilterPill`, `StatusChip`, `MonoLabel`, `Metric`, hairlines, progress/arc, `SystemListRow`, empty states | unchanged | Ink pills on glass are the signature control look |

## Do's and Don'ts

### Do
- Let gauges, charts, and consoles carry all color; keep the glass shell quiet and luminous.
- Keep the status scale strictly on data, the mineral-green accent strictly on brand/selection.
- Keep smoke ≥ 0.60 under any status-colored readout.
- Use `Material` for content surfaces and reserve `glassEffect` for the ≤3 floating chrome elements.
- Give light mode its milkier washes (0.65 canvas) and ink-based glass strokes; QA both schemes over bright *and* dark wallpapers.
- Keep the flat fallback pixel-faithful to the editorial system — it is a design tier, not a degradation.

### Don't
- Don't put `glassEffect` on Z1 content surfaces (cards, consoles, panels).
- Don't tint glass with a status color, and don't let glass vs. flat carry meaning.
- Don't stack shadows, add glow/vignette, or animate blur radius (expensive and dizzy).
- Don't place text directly on the Z0 desktop light.
- Don't box every section; hairlines and space still do the structural work.
- Don't reintroduce per-feature color worlds or decorative continuous animation.

## Motion

Shipped scale (all easeOut): instant 0.10 / feedback 0.14 / transition 0.21 / layout 0.27 / proof 0.39, stagger 0.05s per index. Patterns: fade+rise on appear, staggered bento reveals, `.numericText()` metric transitions, subtle press scale (0.97), banner/overlay present.

Glass-specific rules: glass elements move with `settle` (0.27s); `glassEffectID` morphs only between elements inside one `GlassEffectContainer`; never animate material thickness or blur radius. All motion respects Reduce Motion (collapses to opacity/instant). The only always-on motion is live-data redraw.

## Adaptive Behavior

| Axis | Behavior |
|---|---|
| Window width | Compact <900: single-column bento, tighter gutters, stacked row metadata. Regular: 2-col. Wide ≥1200: 3-col, centered content. The rail gutter is constant. |
| Glass intensity | **Regular** (default): desktop clearly glows through. **Subtle**: 0.78 wash — safe for screenshots/docs. **Off**: flat editorial. Settings › General › Interface. |
| Reduce Transparency | App toggle **or** macOS accessibility setting → flat tier, everywhere including menu-bar surfaces (`TonicGlassPolicy` is the single authority). |
| Appearance | Light and dark are both first-class; smoked/band surfaces are constant-dark in both. The in-app System/Light/Dark selector is applied at the shell root. |
| Menu-bar popovers | Fixed-width smoked consoles (280pt default), max height 420pt, native popover chrome in `.darkAqua`. |

## Iteration Guide

1. Start from the Z0 washed canvas (or a `.band` hero) — never a mid-tone opaque page fill; use `.tonicCanvas()` for page roots.
2. Establish one oversized voice (`hero-display` declaration or `section-display` band heading).
3. Let a smoked console or data-card readout supply the energy; honest skeletons while loading.
4. Compose surfaces through `.tonicSurface(_:in:)` — never hand-roll a material; pass `tint`/`flatFill`/`flatStroke` only to preserve a legacy component's flat identity.
5. One `primary-pill` per surface; `text-action` as its companion; dense surfaces use filter pills + `system-list-row`.
6. Before shipping a screen: check it at Regular/Subtle/Off × light/dark × Reduce Transparency, over a bright wallpaper.

## Known Gaps

- `TonicDisplay` is still unbundled; SF Pro Display is the production fallback.
- Contrast of `status-warning` on light-mode `.surface` glass over white wallpapers is the tightest case — audit before release; raise the surface wash locally if a readout fails AA.
- The Monitor console wall renders many smoked materials at 1s cadence; if Instruments shows composite churn, fall back to one shared smoked backdrop behind the console grid.
- Stage Manager / Mission Control snapshots and ⇧⌘4 captures include window transparency; use Subtle or Off for marketing captures.
- The expandable labeled rail (pinned open) is a possible later enhancement; hover flyouts ship first.
