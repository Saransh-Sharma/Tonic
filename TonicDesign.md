---
version: alpha
name: Tonic-design
description: Tonic's design language is a calm native macOS command center for system health — stark editorial canvases in white or obsidian, deep enterprise-green and dark-navy module bands, near-black monitoring consoles, soft mineral surfaces, rounded data cards, and a research-lab type split between a tight carved display face, precise SF Pro UI text, and SF Mono technical labels. The shell stays quiet; the live system data carries all the color.

colors:
  # Anchors (dual light/dark)
  ink: "#17171c"
  ink-pure: "#0a0a0f"
  canvas: "#ffffff"
  canvas-soft: "#f6f4ef"
  obsidian: "#0a0a0f"
  obsidian-soft: "#121318"
  # Brand bands & console
  console: "#17171c"
  deep-green: "#003c33"
  deep-green-soft: "#0b1f1b"
  dark-navy: "#071829"
  dark-navy-soft: "#0c1a2b"
  # Warm neutral surface
  soft-stone: "#eeece7"
  pale-green: "#edfce9"
  pale-blue: "#f1f5ff"
  # Rules & borders
  hairline: "#d9d9dd"
  hairline-dark: "#2a2a32"
  border-light: "#e5e7eb"
  card-border: "#f2f2f2"
  # Text
  text-primary-light: "#212121"
  text-primary-dark: "#f4f3ef"
  text-muted-light: "#75758a"
  text-muted-dark: "#93939f"
  # Brand accent (reserved — editorial/brand only, never on data)
  accent-coral: "#ff7759"
  accent-coral-soft: "#ffad9b"
  link-blue: "#1863dc"
  # Status scale (DATA ONLY — never used as brand or chrome)
  status-success: "#1f9d57"
  status-warning: "#e0a32c"
  status-caution: "#e07b39"
  status-critical: "#d14b4b"
  status-info: "#3a78d6"
  # Semantic
  focus: "#4c6ee6"
  on-dark: "#ffffff"
  on-light: "#17171c"

typography:
  hero-display:
    fontFamily: TonicDisplay
    fontSize: 64pt
    fontWeight: 500
    lineHeight: 1.02
    letterSpacing: -1.28pt
  section-display:
    fontFamily: TonicDisplay
    fontSize: 44pt
    fontWeight: 500
    lineHeight: 1.05
    letterSpacing: -0.88pt
  card-heading:
    fontFamily: TonicDisplay
    fontSize: 28pt
    fontWeight: 500
    lineHeight: 1.15
    letterSpacing: -0.4pt
  feature-heading:
    fontFamily: SF Pro Display
    fontSize: 20pt
    fontWeight: 600
    lineHeight: 1.25
    letterSpacing: 0pt
  body-large:
    fontFamily: SF Pro Text
    fontSize: 16pt
    fontWeight: 400
    lineHeight: 1.45
    letterSpacing: 0pt
  body:
    fontFamily: SF Pro Text
    fontSize: 14pt
    fontWeight: 400
    lineHeight: 1.5
    letterSpacing: 0pt
  button:
    fontFamily: SF Pro Text
    fontSize: 13pt
    fontWeight: 600
    lineHeight: 1.2
    letterSpacing: 0pt
  caption:
    fontFamily: SF Pro Text
    fontSize: 12pt
    fontWeight: 400
    lineHeight: 1.4
    letterSpacing: 0pt
  mono-label:
    fontFamily: SF Mono
    fontSize: 11pt
    fontWeight: 500
    lineHeight: 1.3
    letterSpacing: 0.5pt
  metric:
    fontFamily: SF Mono
    fontSize: 28pt
    fontWeight: 500
    lineHeight: 1.0
    letterSpacing: 0pt
  micro:
    fontFamily: SF Pro Text
    fontSize: 11pt
    fontWeight: 400
    lineHeight: 1.35
    letterSpacing: 0pt

rounded:
  xs: 4pt
  sm: 8pt
  md: 12pt
  lg: 16pt
  card: 22pt
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

components:
  primary-pill:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.on-dark}"
    typography: "{typography.button}"
    rounded: "{rounded.pill}"
    padding: 10pt 22pt
  text-action:
    backgroundColor: transparent
    textColor: "{colors.text-primary-light}"
    typography: "{typography.body}"
    rounded: "{rounded.xs}"
    padding: 6pt 0
  filter-pill:
    backgroundColor: transparent
    textColor: "{colors.text-primary-light}"
    typography: "{typography.button}"
    rounded: "{rounded.pill}"
    padding: 6pt 14pt
  category-filter-chip:
    backgroundColor: transparent
    textColor: "{colors.accent-coral}"
    typography: "{typography.card-heading}"
    rounded: "{rounded.sm}"
    padding: 8pt 14pt
  alert-banner:
    backgroundColor: "{colors.ink-pure}"
    textColor: "{colors.on-dark}"
    typography: "{typography.micro}"
    height: 32pt
  dashboard-hero:
    backgroundColor: "{colors.canvas}"
    textColor: "{colors.text-primary-light}"
    typography: "{typography.hero-display}"
  monitoring-console:
    backgroundColor: "{colors.console}"
    textColor: "{colors.on-dark}"
    rounded: "{rounded.md}"
    padding: 16pt
  data-card:
    backgroundColor: "{colors.canvas}"
    textColor: "{colors.text-primary-light}"
    rounded: "{rounded.card}"
    padding: 20pt
  module-band:
    backgroundColor: "{colors.deep-green}"
    textColor: "{colors.on-dark}"
    rounded: "{rounded.lg}"
    padding: 48pt
  scan-category-card:
    backgroundColor: "{colors.soft-stone}"
    textColor: "{colors.text-primary-light}"
    rounded: "{rounded.sm}"
    padding: 24pt
  system-identity-strip:
    backgroundColor: transparent
    textColor: "{colors.text-muted-light}"
    typography: "{typography.mono-label}"
  system-list-row:
    backgroundColor: "{colors.canvas}"
    textColor: "{colors.text-primary-light}"
    typography: "{typography.body}"
  settings-panel:
    backgroundColor: "{colors.canvas}"
    textColor: "{colors.text-primary-light}"
    rounded: "{rounded.lg}"
    padding: 24pt
  status-chip:
    backgroundColor: transparent
    textColor: "{colors.status-info}"
    typography: "{typography.mono-label}"
    rounded: "{rounded.full}"
    padding: 3pt 8pt
---

## Overview

Tonic is a native macOS command center for system health. Its design language treats the interface like a calm, precise instrument: a quiet editorial shell that gets out of the way so the live readout of the machine — disk space, CPU load, memory pressure, temperatures, fans, network — can speak with total clarity. The home surface opens on a single monumental status declaration over an open canvas, then alternates editorial white (or obsidian, in dark mode) with deep enterprise-green and dark-navy module bands and near-black monitoring consoles. Cards are rounded but never cute. Type is large, tight, and almost mechanical in spirit, with monospaced technical labels giving every panel a research-lab cadence.

What makes the system distinctive is one rule applied everywhere: **the data is the media.** The chrome is austere — flat surfaces, thin hairline rules, generous space, no decorative gradients or glass. All color and energy come from the readout itself: gauges, charts, sparklines, status arcs, and the dark console panels that render live metrics in mono type. The shell never competes with the numbers. A reserved coral accent and an editorial blue link appear only for brand and navigation moments — never on a gauge, never as a surface fill.

This language supersedes Tonic's earlier glass / world-colored "luxury" system (translucent surfaces, per-feature color worlds, breathing/bloom motion). Where the old system layered decorative depth and chroma onto the chrome, this one strips the chrome back to editorial neutrals and lets the instrument carry the expression.

**Key Characteristics:**
- One monumental display declaration per screen, with tight line height and negative tracking; everything else settles into restrained 12–20pt UI text.
- White (light) or obsidian (dark) editorial canvases interrupted by deep-green, dark-navy, and near-black console bands.
- The near-black **monitoring console** — mono labels, small status chips, device integration badges, live readouts — as the signature surface.
- Rounded **data cards** (22pt) whose content is a gauge, chart, or sparkline rather than imagery.
- Flat depth: surface alternation, hairline rules, and rounded cards do the work; no heavy shadows, no glass, no glow.
- SF Mono technical labels and metrics everywhere — the research-lab voice that fits a system monitor.
- Status color (green→yellow→orange→red) reserved strictly for data; brand coral reserved strictly for brand.

## Colors

Tonic carries one disciplined palette that resolves into both light and dark appearances. The brand identity — ink/canvas anchors, deep-green and navy bands, soft-stone warmth, a single reserved accent — is constant across both; only the neutral stack inverts.

### Brand & Band

- **Ink** (`#17171c`): Primary CTAs, console panels, high-contrast text on light. The brand anchor.
- **Ink Pure** (`#0a0a0f`): Alert banner and the deepest obsidian base in dark mode.
- **Deep Enterprise Green** (`#003c33`): Module bands for healthy / cleanup / optimized surfaces (Smart Scan, Storage). Tonic's primary brand band.
- **Dark Navy** (`#071829`): Module bands for protection / security / permissions surfaces.
- **Accent Coral** (`#ff7759`): **Reserved** for brand and editorial taxonomy only — category-filter chips, warm brand markers. Never a gauge color, never a broad surface fill.
- **Soft Coral** (`#ffad9b`): Pale chip borders and segmented label details.
- **Link Blue** (`#1863dc`): Inline navigation links, pagination, "learn more" affordances.

### Surface & Background

- **Canvas White** (`#ffffff`): Default light surface and the base for data cards, lists, and forms.
- **Canvas Soft** (`#f6f4ef`): Warm off-white page base, an alternate to pure white for large fields.
- **Obsidian** (`#0a0a0f`) / **Obsidian Soft** (`#121318`): Default dark-mode page and elevated surfaces.
- **Soft Stone** (`#eeece7`): Warm neutral cards — scan categories, cleanup-result summaries, quiet proof blocks.
- **Pale Green Wash** (`#edfce9`) / **Pale Blue Wash** (`#f1f5ff`): Occasional section backdrops behind stacked dark panels.
- **Card Border** (`#f2f2f2`): Softest containment line on light surfaces.

### Text & Rules

- **Text Primary** — Light `#212121` / Dark `#f4f3ef`: Default body and most link text.
- **Text Muted** — Light `#75758a` / Dark `#93939f`: Metadata, dates, de-emphasized labels, footer links.
- **Hairline** — Light `#d9d9dd` / Dark `#2a2a32`: Standard list rules and section dividers.
- **Border Light** (`#e5e7eb`): Secondary utility rule on light surfaces.

### Status Scale — Data Only

These colors describe machine state and appear **exclusively** on gauges, charts, arcs, status chips, and value text. They are never used as brand color, surface fill, or decorative chrome — and the brand accent never substitutes for them.

| Token | Value | Meaning |
|---|---|---|
| `status-success` | `#1f9d57` | Healthy / safe / low utilization (0–50%) |
| `status-warning` | `#e0a32c` | Elevated / attention (50–75%) |
| `status-caution` | `#e07b39` | High / approaching limit (75–90%) |
| `status-critical` | `#d14b4b` | Critical / over threshold (90–100%) |
| `status-info` | `#3a78d6` | Neutral informational state (e.g. charging) |

### Light ↔ Dark Mapping

| Role | Light | Dark |
|---|---|---|
| Page canvas | `canvas` / `canvas-soft` | `obsidian` |
| Elevated surface | `canvas` | `obsidian-soft` |
| Console panel | `console` (#17171c) | `console` (#17171c) — constant |
| Warm card | `soft-stone` | `obsidian-soft` + hairline |
| Primary text | `#212121` | `#f4f3ef` |
| Muted text | `#75758a` | `#93939f` |
| Hairline rule | `#d9d9dd` | `#2a2a32` |
| Brand band (green/navy) | as defined — constant | as defined — constant |

### Gradient & Chroma Policy

Tonic does not use gradients as generic UI fill. UI surfaces are flat. Chroma is reserved for the data layer only: gauge arcs, chart strokes and fills, sparklines, and the console readout. Module bands (deep-green, navy) are solid, not gradient. If a band needs depth, use a single very-subtle tonal step, never a saturated gradient.

## Typography

### Font Families

- **Display**: `TonicDisplay` (a tight, carved, geometric face with a near-monospaced spirit), falling back to `SF Pro Display`, `ui-sans-serif`, `system-ui`. Until `TonicDisplay` is bundled, `SF Pro Display` at the documented weights/tracking is the production face.
- **UI / Body**: `SF Pro Text` / `SF Pro Display` (system), the native macOS voice.
- **Technical labels & metrics**: `SF Mono`, falling back to `ui-monospaced`, `Menlo`. Used for every measured value, unit, and system marker.

### Hierarchy

| Role | Family | Size | Weight | Line Height | Tracking | Use |
|---|---|---:|---:|---:|---:|---|
| Hero Display | TonicDisplay | 64pt | 500 | 1.02 | -1.28pt | Dashboard status declaration — one per screen. |
| Section Display | TonicDisplay | 44pt | 500 | 1.05 | -0.88pt | Module-band and large section headings. |
| Card Heading | TonicDisplay | 28pt | 500 | 1.15 | -0.4pt | Data-card and list-section titles. |
| Feature Heading | SF Pro Display | 20pt | 600 | 1.25 | 0 | Card subtitles, settings groups, panel titles. |
| Body Large | SF Pro Text | 16pt | 400 | 1.45 | 0 | Lead copy and primary descriptions. |
| Body | SF Pro Text | 14pt | 400 | 1.50 | 0 | Default UI copy and list text. |
| Button | SF Pro Text | 13pt | 600 | 1.20 | 0 | CTA and control labels. |
| Caption | SF Pro Text | 12pt | 400 | 1.40 | 0 | Metadata and small explanatory text. |
| Mono Label | SF Mono | 11pt | 500 | 1.30 | 0.5pt | Uppercase technical labels (CPU, MEM, °C, RPM), units, system markers. |
| Metric | SF Mono | 28pt | 500 | 1.00 | 0 | Large live readout numbers in consoles and data cards. |
| Micro | SF Pro Text | 11pt | 400 | 1.35 | 0 | Banner, footnotes, tertiary links. |

### Principles

- **One oversized voice per screen.** A surface carries a single hero or section display; everything else stays in restrained 12–20pt UI type. Size and space, not weight, build the hierarchy.
- **Keep display type tight and carved.** Negative tracking and near-1.0 line height make headlines feel machined, not airy.
- **Mono is the technical voice.** Every measured value, unit, and system marker uses SF Mono — CPU/MEM/GPU labels, percentages, byte counts, temperatures, RPM, PIDs, timestamps. This is what gives Tonic its instrument cadence.
- **Avoid heavy bold.** Display sits at medium (500); body emphasis tops out at semibold. Let surface contrast and the data layer provide emphasis.
- **Numbers tabular and animated.** Live metrics use monospaced digits with numeric content transitions so readouts update without reflow.

## Layout

### Spacing System

An 8-pt base grid: `4`, `8`, `12`, `16`, `24`, `32`, `40`, `48`, with a `64pt` section interval for the dramatic vertical breathing room between status, proof, and action. Dense content (process lists, file lists, settings rows) packs tighter on the grid; marketing-weight surfaces (dashboard hero, module bands) hold wide intervals.

### Grid & Container

- **Shell**: `NavigationSplitView` — a ~220pt sidebar (grouped destinations) beside a detail pane. Content max width ~1200pt, centered in wide windows.
- **Dashboard**: a centered hero declaration above an editorial bento grid of data cards (mixed large/wide/small), with a quiet system-identity strip below the hero.
- **Module screens**: alternate centered hero blocks, full-bleed deep-green/navy bands, and 2–3 column card grids.
- **List screens** (processes, files, apps, recently cleaned): full-width rule-separated rows with mono technical columns instead of decorative cards.
- **Settings**: rounded panels with grouped preference rows, set on canvas or a quiet stone section.
- **Menu-bar popovers**: fixed 280pt-wide consoles, scrollable to a max height.

### Whitespace Philosophy

Whitespace is a calm signal. Large empty intervals separate the system status, the proof (what was found / what state things are in), and the action (clean, optimize, configure). Density appears only where it serves the readout: console panels, list rows, and settings forms.

## Elevation & Depth

Tonic is flat. Depth comes from surface alternation, the contrast of console panels against canvas, hairline borders, and rounded data cards — never from drop shadows, glass, or glow. This explicitly **supersedes** the legacy glass/vignette/bloom depth model.

| Level | Treatment | Use |
|---|---|---|
| Flat | No shadow; white/obsidian field | Hero copy, lists, editorial surfaces |
| Bordered | 1pt hairline | List rows, settings panels, warm cards, dividers |
| Surface alternation | Stone or wash block against canvas | Scan categories, proof blocks, section grouping |
| Module band | Solid deep-green or navy full-bleed | Smart Scan, Storage, Protection, Permissions |
| Console field | Near-black `#17171c` panel | Monitoring popovers, live readouts, agent-style panels |

A single soft shadow (very low opacity, small offset) is permitted only to lift a data card or popover off canvas — never stacked, never colored.

## Shapes

### Radius Scale

| Token | Value | Role |
|---|---:|---|
| `xs` | 4pt | Inline chips, tiny utility elements, inner controls |
| `sm` | 8pt | Scan-category cards, small media, filter chips, dialogs |
| `md` | 12pt | Console panels, list cards, grouped blocks |
| `lg` | 16pt | Module bands, settings panels |
| `card` | 22pt | Signature radius for data cards and gauge cards |
| `pill` | 32pt | Primary CTAs and filter pills |
| `full` | 9999pt | Status dots and fully pill-shaped chips |

### Visualization Treatment

In place of photography, Tonic's "media" is the live visualization. Gauges, charts, and sparklines sit inside rounded data cards with visible corners — the dominant radii are 12pt (console/list) and 22pt (data cards). A gauge is itself circular; a chart fills its card edge-to-edge with the card's radius clipping it. Never frame a visualization in heavy chrome; let the card and a hairline contain it.

## Components

Every component is a real Tonic native surface. No marketing-web idioms survive un-translated.

### **`primary-pill`**

Near-black (or white, on dark/band surfaces) pill CTA. 13pt SF Pro semibold, 10pt 22pt padding, 32pt radius. The single highest-priority action per surface — "Run Smart Clean", "Scan", "Apply".

### **`text-action`**

Text-only companion action, underlined or rule-aligned, no fill. Used for "Review", "Customize", "Learn more", and secondary hero actions.

### **`filter-pill`**

Lightweight outlined pill, transparent fill, 1pt border, 32pt radius. Used for list filters and monitoring scopes (All / System / Environment, sort modes, time ranges).

### **`category-filter-chip`**

Oversized taxonomy chip for scan/app/storage categories — a hero-level control. Active inverts to coral fill with dark text; inactive uses coral outline on pale fill. This is the one place the brand accent appears on an interactive control; it never migrates onto data.

### **`alert-banner`**

Thin (32pt) near-black strip at the top of the window for global system states — "Full Disk Access required", "Helper tool not installed", "Update available" — with an inline action link and a dismiss control.

### **`dashboard-hero`**

The opening surface: a single monumental status declaration ("All clear.", "12.4 GB to recover", "Running hot") at hero-display scale over the canvas, with a short supporting line and at most one primary action. The calm voice that sets the tone for the whole app.

### **`monitoring-console`** — signature surface

The near-black panel that renders live data, used for menu-bar popovers and Live Monitoring sections. Contents: mono section labels (CPU / MEM / GPU / NET), large mono metrics, small status chips, device integration badges (connected displays, AirPods, power adapter), and inline gauges/sparklines. White and muted text on `#17171c`; status color used only on the readout. This is where the "data is the media" thesis is most literal — the console has no decoration of its own; the numbers are the design.

### **`data-card`**

Rounded 22pt card whose body is a live visualization — a gauge, line chart, bar chart, or sparkline — with a mono label and metric. The card chrome is a hairline and the canvas; all expression is in the readout.

### **`module-band`**

Full-bleed deep-green (healthy/cleanup/optimized) or dark-navy (protection/security/permissions) section. White text, thin-line system glyphs, a section-display heading, and a primary-pill or text-action. Used as the hero surface for Smart Scan, Storage, Protection, and Permissions modules.

### **`scan-category-card`**

Warm soft-stone card summarizing a cleanup category or scan result. Typically 2–3 column, 8pt radius, generous padding, a divider, checkmark bullet rows, a size metric in mono, and a small pill action.

### **`system-identity-strip`**

A quiet, unboxed line of the user's actual hardware identity — "MacBook Pro · M3 Max · 36 GB · macOS Sonoma" — in mono labels with wide spacing, set below the dashboard hero. The honest, monochrome analog of a proof strip: no cards, no borders, just space.

### **`system-list-row`**

Rule-separated row for processes, files, apps, and the recently-cleaned log: title/icon left, status or taxonomy pills center, and a right-aligned mono technical column (size, %, PID, date). Tall, border-driven, white/obsidian. Filters above use `filter-pill`s.

### **`status-chip`**

Small pill carrying a single machine-state marker — a status-colored dot plus a mono label ("ACTIVE", "92°C", "THROTTLED"). Color drawn from the status scale, never brand.

### **`settings-panel`**

Rounded panel containing grouped preference rows (toggle / picker / button / threshold). Set on canvas or a quiet stone/dark section. Inputs are rectangular with thin borders and compact mono-or-body labels; the submit/primary control uses `primary-pill`.

### Supporting surfaces

- **`sidebar`** — grouped `NavigationSplitView` sidebar: section headers, icon+label rows, optional count badges. Quiet, monochrome, ~220pt.
- **`page-header`** — title + optional subtitle + trailing actions / search, atop each detail screen.
- **`gauge` family** — circular (full/segmented), half-circle, tachometer (needle), and pressure (3-zone arc) gauges; all status-colored, all the "media" of a data card.
- **`chart-card`** — line/spark/bar history rendered edge-to-edge inside a data card.
- **`search-field`** — text input with a leading glyph and clear control; thin border, body type.
- **`empty-state`** — centered thin-line glyph, card-heading title, caption message, optional text-action.

## Do's and Don'ts

### Do

- Let gauges, charts, and the console carry all the color and energy; keep the shell editorial.
- Keep the status scale (green→yellow→orange→red) strictly for data.
- Use deep-green and navy as intentional full-bleed module bands, not as accidental accents.
- Use SF Mono for every technical label, unit, and metric.
- Hold one oversized display voice per screen and settle everything else into restrained UI type.
- Use 22pt radius on data cards and 12pt on console/list panels.
- Use the system-identity strip and quiet stone proof blocks instead of decorative filler.

### Don't

- Do not put the brand accent (coral) or link-blue on a gauge, arc, or status readout.
- Do not reintroduce glass, vignette, inner-highlight, glow, or breathing/bloom chrome.
- Do not add heavy or stacked drop shadows to cards.
- Do not box every section; favor unframed rows, hairline rules, and open space.
- Do not use saturated gradients as UI surface fills; keep bands solid and chroma in the data.
- Do not introduce a second generic sans voice or drop the display/body/mono split.
- Do not let chrome compete with the readout — if a panel's decoration draws the eye before the numbers, simplify it.

## Motion

Motion is restrained and editorial — a deliberate departure from the legacy breathing/bloom/sweep system. It clarifies state changes and live data, never decorates.

| Pattern | Use | Timing |
|---|---|---|
| Fade + rise on appear | Cards, panels, sections entering | normal (0.25s), easeOut |
| Staggered reveal | List rows and bento tiles on load | per-index delay ~0.05s |
| Numeric content transition | Live metrics updating in console/cards | fast (0.15s) |
| Press feedback | Buttons, chips, rows | fast (0.15s), subtle scale |
| Banner / overlay present | Alert banner, modals, popovers | normal (0.25s), ease |

Timing tokens: **fast 0.15s**, **normal 0.25s**, **slow 0.35s**. All motion respects `accessibilityReduceMotion` — when reduced, transitions collapse to instant or simple opacity. Retire decorative continuous animation (breathing scale, glow pulse, diagonal sweep) entirely; the only "always-on" motion permitted is live-data redraw.

## Adaptive Behavior

Tonic adapts to macOS window size, not web breakpoints.

| Window | Behavior |
|---|---|
| Compact (narrow) | Sidebar collapses to a toggle; bento grid → single column; module-band padding reduces; list rows stack metadata below the title. |
| Regular | Sidebar visible; bento grid → 2 columns; standard padding. |
| Wide | Full sidebar + detail; bento grid → 3 columns; content centered at ~1200pt with generous side gutters. |

- **Menu-bar popovers** are a fixed 280pt console regardless of window state, scrollable to max height.
- **Lists** preserve their rule-separated structure at every width; only the metadata layout reflows.
- **Click/touch targets**: minimum 36pt for controls and pills, 44pt for list rows.

## Iteration Guide

1. Start from a white/obsidian canvas or a full-bleed deep-green/navy band — never a mid-tone page background.
2. Establish one oversized voice: a `dashboard-hero` declaration or a `section-display` band heading. Everything else stays restrained.
3. Let a `monitoring-console` or a `data-card` gauge/chart supply the visual energy. Never invent data to fill a panel — use honest placeholder/skeleton states when data is loading.
4. Use `primary-pill` for the single highest-priority action and `text-action` for its companion.
5. For dense surfaces (processes, files, apps), combine `category-filter-chip`, `filter-pill`, and `system-list-row` instead of marketing cards.
6. Keep status color on the data and brand coral on brand. If you reach for coral on a gauge, stop.

## Known Gaps

- The custom display face `TonicDisplay` is not yet bundled; `SF Pro Display` at the documented weights and tracking is the production fallback until it is.
- Dark-mode status and brand colors must be validated for WCAG AA contrast on `obsidian` surfaces before release; values here are starting points.
- This language **supersedes** the legacy glass / world-colored system (`TonicThemeTokens`, glass surfaces, `AtelierTokens`); migrating existing screens off that system is handled as separate redesign work, not by this document.
- Menu-bar console layouts are documented from the existing 280pt popover structure; final per-widget console compositions will be refined during implementation.
