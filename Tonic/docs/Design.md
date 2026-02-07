# Tonic Design System Documentation

Comprehensive design system documentation for the Tonic macOS application, including component specifications, design tokens, and usage examples.

<p align="center">
  <img src="assets/app-icon.png" alt="Tonic App Icon" width="128" height="128" />
</p>

## Overview

Tonic uses a **dual-tier design system**:

| Tier | When to Use | Files |
|------|-------------|-------|
| **Modern System** (Part 1) | All new screens and revamped features (Smart Scan, managers) | `TonicThemeTokens.swift`, `TonicVisualPrimitives.swift`, `TonicSmartScanComponents.swift`, `TonicThemeProvider.swift` |
| **Legacy System** (Part 3) | Existing screens not yet migrated (Dashboard, Preferences, etc.) | `DesignTokens.swift`, `DesignComponents.swift`, `DesignAnimations.swift` |

**Rule of thumb:** If you are building a new screen or revamping an existing one, use the Modern System exclusively. If you are making a small fix to an existing legacy screen, continue using the Legacy System for consistency within that screen.

**Key Principles:**
- **Native macOS**: Use system semantics and native components
- **World-Colored Experiences**: Each feature area has its own color world
- **Glass Surfaces**: Translucent layered surfaces with depth
- **Spring-Based Motion**: Physically-modeled animations with `accessibilityReduceMotion` respect
- **8 Swappable Palettes**: Users choose a palette; all worlds adapt automatically
- **Accessibility**: WCAG AA contrast minimum, reduce motion support, keyboard navigation

---

# Part 1: Modern Design System (Preferred for New Code)

## 1.1 Theme & Color Palettes

### TonicWorld (6 Worlds)

Each feature area maps to a "world" — a semantic color family used for backgrounds, accents, and glows.

```swift
enum TonicWorld: String, CaseIterable {
    case smartScanPurple       // Smart Scan hub
    case cleanupGreen          // Disk cleanup, space recovery
    case clutterTeal           // Clutter detection
    case applicationsBlue      // App management
    case performanceOrange     // Performance tuning
    case protectionMagenta     // Security & protection
}
```

Each world resolves to a `TonicWorldColorToken` containing dark/mid/light colors for both dark mode and light mode:

```swift
struct TonicWorldColorToken {
    let darkMode: TonicWorldModeColorToken   // darkHex, midHex, lightHex
    let lightMode: TonicWorldModeColorToken

    var dark: Color   // Dynamic (auto light/dark)
    var mid: Color    // Dynamic
    var light: Color  // Dynamic
}
```

### TonicColorPalette (8 Palettes)

Users select a palette via `AppearancePreferences.shared.colorPalette`. All worlds re-derive their colors from the active palette.

| Palette | Display Name | Mood |
|---------|-------------|------|
| `.defaultPurple` | Default Purple | Creative, focused, modern |
| `.ocean` | Ocean | Cool, professional, trustworthy |
| `.sunset` | Sunset | Warm, energetic, optimistic |
| `.forest` | Forest | Natural, grounding, serene |
| `.lavender` | Lavender | Elegant, calm, contemplative |
| `.midnight` | Midnight | Dramatic, modern, powerful |
| `.roseGold` | Rose Gold | Luxurious, warm, sophisticated |
| `.arctic` | Arctic | Clean, minimal, precise |

#### How Palette Selection Works

```
User picks palette in Preferences
  → AppearancePreferences.shared.colorPalette = .ocean
  → TonicWorld.token reads palette.worldToken(for: self)
  → TonicThemeProvider body reads preferences.colorPalette (Observation tracking)
  → SwiftUI re-renders with new colors
```

### TonicTheme

The `TonicTheme` struct is the primary way views access themed colors:

```swift
struct TonicTheme {
    let world: TonicWorld

    var accent: Color       // worldToken.mid
    var glowSoft: Color     // worldToken.light @ 0.14 opacity
    var glowStrong: Color   // worldToken.light @ 0.22 opacity
    var glow: Color         // alias for glowStrong

    var canvasDark: Color   // worldToken.dark
    var canvasMid: Color    // worldToken.mid
    var canvasLight: Color  // worldToken.light
}

// Usage in views:
@Environment(\.tonicTheme) private var theme
```

---

## 1.2 Neutral, Text & Stroke Tokens

### TonicNeutralToken

```swift
enum TonicNeutralToken {
    static let white = Color(hex: "FFFFFF")
    static let black = Color(hex: "0A0A0F")

    // Light neutral stack
    static let neutral0 = Color(hex: "F5F6FA")  // Light mode canvas base
    static let neutral1 = Color(hex: "EEF0F6")
    static let neutral2 = Color(hex: "F8F9FC")  // Chip/card light mode base
    static let neutral3 = Color(hex: "FFFFFF")

    static let dynamicBackground  // Light: F5F6FA, Dark: 0A0A0F
}
```

### TonicTextToken

```swift
enum TonicTextToken {
    static let primary    // Light: #000000 @ 0.88, Dark: #FFFFFF @ 0.92
    static let secondary  // Light: #000000 @ 0.64, Dark: #FFFFFF @ 0.70
    static let tertiary   // Light: #000000 @ 0.50, Dark: #FFFFFF @ 0.52
}
```

### TonicStrokeToken

```swift
enum TonicStrokeToken {
    static let subtle     // Light: #000000 @ 0.10, Dark: #FFFFFF @ 0.12
    static let stronger   // Light: #000000 @ 0.17, Dark: #FFFFFF @ 0.20
}
```

---

## 1.3 Spacing & Radius

### TonicSpaceToken (8-Point Grid)

```swift
enum TonicSpaceToken {
    static let one: CGFloat   = 8    // Tight gaps, icon-text
    static let two: CGFloat   = 12   // Minor padding, row spacing
    static let three: CGFloat = 16   // Standard content padding
    static let four: CGFloat  = 24   // Section padding, panel insets
    static let five: CGFloat  = 32   // Large section gaps
    static let six: CGFloat   = 48   // Extra large spacing
    static let seven: CGFloat = 64   // Hero spacing

    static let gridGap: CGFloat = 16 // BentoGrid inter-tile gap
}
```

### TonicRadiusToken

```swift
enum TonicRadiusToken {
    static let s: CGFloat         = 10   // Small elements
    static let m: CGFloat         = 14   // Rows, inputs, icons
    static let l: CGFloat         = 22   // Cards (GlassCard default)
    static let xl: CGFloat        = 26   // Panels (GlassPanel default)
    static let container: CGFloat = 30   // Full-width containers, hero modules
    static let chip: CGFloat      = 12   // Chip corners
}
```

---

## 1.4 Typography

### TonicTypeToken

```swift
enum TonicTypeToken {
    static let hero        = Font.system(size: 44, weight: .semibold)  // Hero headlines
    static let pillarTitle = Font.system(size: 34, weight: .semibold)  // Section titles
    static let tileMetric  = Font.system(size: 28, weight: .semibold)  // Big numbers in tiles

    // Aliases
    static let display = hero         // Back-compat alias
    static let title   = pillarTitle  // Back-compat alias

    static let body    = Font.system(size: 15, weight: .regular)  // Body text
    static let caption = Font.system(size: 12, weight: .medium)   // Labels, badges
    static let micro   = Font.system(size: 11, weight: .regular)  // Metadata, tertiary
}
```

---

## 1.5 Motion & Animation

### TonicMotionToken

#### Durations

```swift
static let fast: Double = 0.12   // UI interactions (hover, press)
static let med: Double  = 0.20   // Standard transitions
static let slow: Double = 0.35   // Emphasis, fade-in

static let fade: Double  = slow  // Alias
static let hover: Double = fast  // Alias
static let press: Double = fast  // Alias
```

#### Spring Presets

```swift
// Tap feedback
static var springTap: Animation
    // response: 0.25, dampingFraction: 0.82

// Stage transitions
static var stageEnterSpring: Animation
    // response: 0.40, dampingFraction: 0.85
static var stageCheckmarkSpring: Animation
    // response: 0.30, dampingFraction: 0.60

// Result reveal
static var resultCardSpring: Animation
    // response: 0.45, dampingFraction: 0.82
static var resultMetricSpring: Animation
    // response: 0.50, dampingFraction: 0.75

// Modal
static var modalPresentSpring: Animation
    // response: 0.50, dampingFraction: 0.86
static var modalDismissSpring: Animation
    // response: 0.30, dampingFraction: 0.90

// Easing
static var ease: Animation
    // .easeInOut(duration: med)
```

#### Special Effects

```swift
// Hero breathing
static let breathingScale: ClosedRange<CGFloat> = 1.0 ... 1.015
static let breathingDuration: Double = 4.5

// Scan pulse
static let scanPulseAmplitude: Double = 0.04
static let scanPulseDuration: Double = 2.0

// Stage exit
static let stageExitDuration: Double = 0.20

// Staggered reveal
static let resultStaggerDelay: Double = 0.08
static let resultCountUpDuration: Double = 0.80
```

### Control States

```swift
enum TonicControlState: String, CaseIterable {
    case `default`, hover, pressed, focused, disabled
}
```

Each state maps to a `TonicControlStateToken`:

| State | Brightness | Scale | Content Opacity | Stroke Boost | Shadow |
|-------|-----------|-------|-----------------|-------------|--------|
| **default** | 0 | 1.0 | 1.0 | 0 | 1.0x |
| **hover** | +0.06 | 1.0 | 1.0 | 0.16 | 1.1x |
| **pressed** | -0.02 | 0.98 | 1.0 | 0.06 | 0.7x |
| **focused** | +0.01 | 1.0 | 1.0 | 0.10 | 1.0x |
| **disabled** | 0 | 1.0 | 0.5 | 0 | 1.0x |

Chips use slightly different values (see `TonicChipStateTokens`), e.g. hover brightness is +0.03 instead of +0.06.

### Focus Ring

```swift
enum TonicFocusToken {
    static let ringOpacity: Double = 0.40
    static func ring(for accent: Color) -> Color  // accent @ 0.40
}
```

---

## 1.6 Glass Surfaces

### Variants

```swift
enum TonicGlassVariant {
    case base      // Standard glass
    case raised    // Higher elevation — more fill, stroke, shadow
    case sunken    // Inset feel — more vignette, less fill
}
```

### Alpha Profiles (Dark Mode / Light Mode)

| Property | Base Dark | Base Light | Raised adds | Sunken adds |
|----------|----------|------------|-------------|-------------|
| fill | 0.07 | 0.025 | +0.025 | -0.015 |
| vignette | 0.24 | 0.035 | — | +0.05 |
| stroke | 0.11 | 0.10 | +0.02 | — |
| innerHighlight | 0.07 | 0.18 | — | — |
| shadow | 0.38 | 0.07 | +0.06 | — |

Blur: 24pt constant.

### Rendering Modes

```swift
enum TonicGlassRenderingMode {
    case legacy  // Custom translucent layers (all macOS versions)
    case liquid  // Native .glassEffect (macOS 26.0+ / Tahoe)
}
```

The **adaptive glass** system auto-selects:
- macOS 26.0+: `.liquid` by default (uses SwiftUI `.glassEffect`)
- Older macOS: `.legacy` (custom layers with vignette, inner highlight, stroke)
- Override with `.tonicForceLegacyGlass(true)` or `.tonicGlassRenderingMode(.legacy)`

### Glass Components

```swift
// View modifier — add glass to any view
.glassSurface(radius: TonicRadiusToken.l, variant: .base)

// Card with padding (16pt) + glass
GlassCard(radius: TonicRadiusToken.l, variant: .base) {
    content
}

// Panel with padding (24pt) + glass
GlassPanel(radius: TonicRadiusToken.xl, variant: .base) {
    content
}
```

### Helper Overlays

```swift
GlassStrokeOverlay(radius: 22)   // Subtle stroke overlay
GlassInnerHighlight(radius: 22)  // Top-to-center gradient highlight
```

---

## 1.7 Semantic Status Colors

### TonicSemanticKind

```swift
enum TonicSemanticKind: String, CaseIterable {
    case success, info, warning, danger, neutral
}
```

### TonicStatusPalette

Each kind provides `fill`, `stroke`, and `text` colors per mode:

| Kind | Light Fill | Light Stroke | Light Text | Dark Fill | Dark Stroke | Dark Text |
|------|-----------|-------------|-----------|----------|------------|----------|
| success | `#E6F6ED` | `#BFE7CF` | `#116A3C` | `#123022` | `#1E5A3C` | `#8BE0B4` |
| warning | `#FFF3E2` | `#FFD7A6` | `#8A4B00` | `#2A1E10` | `#6C3F12` | `#FFC57A` |
| danger | `#FFE9EA` | `#FFC0C4` | `#8B1D2C` | `#2C1215` | `#6B1E2A` | `#FF9AA3` |
| info | `#E9F1FF` | `#C7DAFF` | `#1C4FA8` | `#0F1D33` | `#1D3F7A` | `#9EC2FF` |
| neutral | `#EEF0F4` | `#D8DCE6` | `#3B4254` | `#161A22` | `#2A3242` | `#B9C0D0` |

Usage:

```swift
// Struct with fill/stroke/text
let style = TonicStatusPalette.style(.warning, for: colorScheme)

// Individual color accessors
TonicStatusPalette.fill(.success)   // Dynamic Color
TonicStatusPalette.stroke(.success)
TonicStatusPalette.text(.success)
```

---

## 1.8 Shadow Tokens

### Dark Stack

```swift
TonicShadowToken.elev1  // black @ 0.30, y: 8, blur: 22
TonicShadowToken.elev2  // black @ 0.35, y: 16, blur: 52
TonicShadowToken.elev3  // black @ 0.40, y: 26, blur: 86
```

### Light Stack

```swift
TonicShadowToken.lightE1  // black @ 0.08, y: 6, blur: 18
TonicShadowToken.lightE2  // black @ 0.10, y: 14, blur: 34
```

### Adaptive Helpers

```swift
TonicShadowToken.level1(for: colorScheme)  // elev1 or lightE1
TonicShadowToken.level2(for: colorScheme)  // elev2 or lightE2
```

---

## 1.9 Button & Chip Tokens

### Button Variants

```swift
enum TonicButtonVariant { case primary, secondary }
```

| Variant | Dark BG | Dark FG | Light BG | Light FG |
|---------|---------|---------|----------|----------|
| primary | `#FFFFFF` | `#0B0C10` | `#111318` | `#FFFFFF` |
| secondary | `#FFFFFF1F` | text.primary | `#FFFFFFA8` | text.primary |

Usage:

```swift
let style = TonicButtonTokens.style(
    variant: .primary,
    state: .default,
    colorScheme: colorScheme,
    accent: theme.accent
)
// style.background, .foreground, .stroke, .focusRing, .strokeBoost
```

### Chip System

Chips have two dimensions:

**Strength:**
```swift
enum TonicChipStrength { case subtle, strong, outline }
```

**Role:**
```swift
enum TonicChipRole {
    case semantic(TonicSemanticKind)  // Status-colored chips
    case world(TonicWorld)            // World-colored chips
}
```

**Chip Dimensions:**
- Height: 27pt
- Radius: 999 (full pill)
- Padding: 11pt horizontal, 5pt vertical
- Icon size: 12pt
- Font: `.system(size: 11.5, weight: .semibold)`

Usage:

```swift
let style = TonicChipTokens.style(
    role: .semantic(.success),
    strength: .subtle,
    colorScheme: colorScheme
)
```

---

## 1.10 Canvas Tokens

Canvas tokens define the full-bleed background for a world:

```swift
enum TonicCanvasTokens {
    // Solid base (dark: world-tinted near-black, light: neutral0)
    static func fill(for world: TonicWorld, colorScheme: ColorScheme) -> Color

    // Color wash (dark: mid @ 0.18, light: light @ 0.06)
    static func tint(for world: TonicWorld, colorScheme: ColorScheme) -> Color

    // Edge glow (dark: light @ 0.22, light: light @ 0.10)
    static func edgeGlow(for world: TonicWorld, colorScheme: ColorScheme) -> Color
}
```

Dark mode fill formula: `neutralDarkBase.blended(with: worldDark, weight: 0.55)` — this gives each world a distinct hue without being overwhelming.

---

## 1.11 Visual Primitives (View Modifiers)

All primitives are defined in `TonicVisualPrimitives.swift`.

### Backgrounds

```swift
// Full-bleed world-colored background with radial glows
WorldCanvasBackground(recipe: .default)

// Section-level tint overlay
.sectionTint(0.06)
```

### Glass

```swift
.glassSurface(radius:variant:)  // Add glass treatment to any view
GlassCard { content }           // Padded (16pt) glass container
GlassPanel { content }          // Padded (24pt) glass container
```

### Depth

```swift
.heroBloom()           // Soft world-colored glow (radius: 34)
.progressGlow(0.5)     // Intensity scales with progress 0→1
.depthLift()           // Hover-activated lift with shadow transition
.softShadow(style)     // Apply a TonicShadowStyle directly
```

### Hover & Press

```swift
.calmHover()                              // Subtle 1.01× scale on hover
PressEffect(focusShape: .capsule)         // ButtonStyle with state-driven brightness/scale/stroke
PressEffect(focusShape: .rounded(14))     // Rounded rect focus shape
PressEffect(focusShape: .circle)          // Circle focus shape
```

### Animation

```swift
.breathingHero()                          // Continuous gentle scale + glow pulse (4.5s cycle)
.heroSweep(active: isScanning)            // Diagonal highlight sweep across surface
.staggeredReveal(index: 2)               // Per-index fade+slide+scale entrance
.completionBurst(active: didComplete)     // Expanding ring burst on completion
.pulseGlow(active: isScanning, progress: 0.5)  // Scan-phase glow with oscillation
```

All animation modifiers respect `@Environment(\.accessibilityReduceMotion)`.

### Typography Views

```swift
DisplayText("Smart Scan")   // 44pt semibold, primary color
TitleText("Section Title")  // 34pt semibold, primary color
BodyText("Description")     // 15pt regular, secondary color
CaptionText("Label")        // 12pt medium, secondary color
MicroText("Metadata")       // 11pt regular, tertiary color
```

---

## 1.12 Reusable Components

All components are defined in `TonicSmartScanComponents.swift`.

### Buttons

| Component | Purpose | Style |
|-----------|---------|-------|
| `PrimaryScanButton` | Large circular scan trigger | Circle + world glow + PressEffect(circle) |
| `PrimaryActionButton` | Pill CTA ("Run Smart Clean") | Capsule + primary button tokens |
| `SecondaryPillButton` | Secondary action ("Customize") | Capsule + secondary button tokens |
| `TertiaryGhostButton` | Text-only action ("Review") | Plain, caption weight, secondary color |
| `IconOnlyButton` | Icon-only square button | 30×30, rounded rect, secondary tokens |

#### Usage

```swift
PrimaryScanButton(title: "Smart Scan", icon: "magnifyingglass") {
    startScan()
}

PrimaryActionButton(title: "Clean Up", icon: "sparkles", action: cleanUp)

SecondaryPillButton(title: "Customize") { showCustomize() }

TertiaryGhostButton(title: "Review") { showReview() }

IconOnlyButton(systemName: "chevron.left") { goBack() }
```

### Chips

| Component | Purpose |
|-----------|---------|
| `GlassChip` | Base chip with role, strength, and state support |
| `MetaBadge` | Predefined badges (Safe, Risky, Needs Review, etc.) |
| `SafetyBadge` | Alias for MetaBadge |
| `RecommendationBadge` | Pre-configured "Recommended" badge |
| `TrailingMetric` | Right-aligned value chip with numeric transition |
| `CounterChip` | Title + value chip with active/complete states |
| `LiveCounterChip` | CounterChip with auto world-mapping from label |

#### Usage

```swift
GlassChip(title: "Warning", icon: "exclamationmark.triangle", role: .semantic(.warning), strength: .strong)

MetaBadge(style: .safe)     // Green "Safe" badge
MetaBadge(style: .risky)    // Red "Risky" badge (strong strength)

TrailingMetric(value: "2.4 GB", world: .cleanupGreen)

CounterChip(title: "Space", value: "1.2 GB", world: .cleanupGreen, isActive: true)

LiveCounterChip(label: "Performance", value: "3 issues", isActive: false, isComplete: true)
```

### Rows

| Component | Purpose |
|-----------|---------|
| `SelectableRow` | Checkbox + icon + title/subtitle + metric |
| `DrilldownRow` | Icon + title/subtitle + metric + chevron |
| `HybridRow` | Checkbox + icon + title/subtitle + badges + metric + chevron |

#### Usage

```swift
SelectableRow(
    icon: "doc.fill",
    title: "System Cache",
    subtitle: "~/Library/Caches",
    metric: "1.2 GB",
    isSelected: isSelected,
    onSelect: { selectItem() },
    onToggle: { toggleItem() }
)

DrilldownRow(
    icon: "app.fill",
    title: "Xcode",
    subtitle: "Developer tools",
    metric: "8.4 GB",
    action: { showDetail() }
)

HybridRow(
    icon: "app.fill",
    title: "Sketch",
    subtitle: "Design tool",
    metric: "1.1 GB",
    isSelected: true,
    badges: [.unused, .large],
    onSelect: { select() },
    onToggle: { toggle() }
)
```

### Headers

| Component | Purpose |
|-----------|---------|
| `PageHeader` | Top bar with title, optional subtitle, search, back button, trailing content |
| `PillarSectionHeader` | Large world-tinted section header with title, subtitle, summary, action |
| `StickyActionBar` | Bottom bar with summary text + secondary/primary actions |

#### Usage

```swift
PageHeader(
    title: "App Manager",
    subtitle: "12 apps found",
    searchText: $searchText,
    trailing: AnyView(SortMenuButton(selected: $sortOption))
)

PillarSectionHeader(
    title: "Space",
    subtitle: "Disk cleanup opportunities",
    summary: "2.4 GB recoverable",
    sectionActionTitle: "Review All",
    world: .cleanupGreen,
    onSectionAction: { showSpaceReview() }
)

StickyActionBar(
    summary: "3 items selected • 1.2 GB",
    variant: .cleanUp,
    enabled: true,
    secondaryTitle: "Select All",
    onSecondaryAction: { selectAll() },
    action: { cleanUp() }
)
```

### Grid: BentoTile & BentoGrid

BentoTile renders a card in one of three sizes:

| Size | Height | Radius |
|------|--------|--------|
| `.large` | 368pt | xl (26pt) |
| `.wide` | 178pt | xl (26pt) |
| `.small` | 178pt | l (22pt) |

```swift
BentoGrid(
    world: .cleanupGreen,
    tiles: tileModels,
    onReview: { target in showReview(target) },
    onAction: { tileID, kind in executeAction(tileID, kind) }
)
```

BentoGrid automatically arranges tiles: 1 large + 1 wide + 2 small in an asymmetric layout, falling back to a 2-column LazyVGrid.

### Input

```swift
SearchField(text: $searchText, placeholder: "Search apps...")

SortMenuButton(selected: $sortOption)  // Dropdown menu for enum options

SegmentedFilter(
    options: filterOptions,
    selected: $selectedFilter,
    title: { $0.displayName }
)
```

### State Panels

```swift
EmptyStatePanel(icon: "sparkles", title: "No Results", message: "Run a scan first.")
ErrorStatePanel(message: "Failed to load data.")
ScanLoadingState(message: "Analyzing disk space...")
PlaceholderStatePanel(title: "Coming Soon", message: "This feature is in development.")
NoSelectionState(message: "Select an item to view details.")
```

### Sidebar

```swift
SidebarSectionHeader(title: "Categories")

SidebarWorldItem(
    icon: "folder",
    title: "System Cache",
    isSelected: true,
    badgeCount: 42,
    action: { selectCategory() }
)

SidebarBadge(count: 12)
```

### Shell Layouts

```swift
// Three-pane manager layout
ManagerShell(
    header: AnyView(PageHeader(title: "App Manager")),
    left: { LeftNavPane { categoryList } },
    middle: { MiddleSummaryPane { summaryContent } },
    right: { RightItemsPane { itemList } },
    footer: AnyView(StickyActionBar(...))
)
```

### Hub Components

```swift
// Scan hero with ready/scanning/results states
ScanHeroModule(state: .scanning(progress: 0.45), currentScanItem: "Analyzing ~/Library/Caches")

// Timeline stepper
ScanTimelineStepper(stages: ["Space", "Performance", "Apps"], activeIndex: 1, completed: [0])

// Command dock
SmartScanCommandDock(
    mode: .results,
    summary: "Scan complete • 3.2 GB recoverable",
    primaryEnabled: true,
    secondaryTitle: "Customize",
    onSecondaryAction: { customize() },
    action: { runClean() }
)
```

### Detail & Safety

```swift
RiskExplanationBlock(text: "Removing this may affect app functionality.")

DeleteModeToggle(permanent: $permanentDelete)

DetailPane(
    title: "System Cache",
    subtitle: "Safe to remove. Rebuilds automatically.",
    riskText: nil,
    includeExcludeTitle: "Include in cleanup",
    include: $includeItem
)

ActionConfirmationModal(
    title: "Confirm Cleanup",
    message: "This will remove 1.2 GB of files.",
    confirmTitle: "Clean Up",
    onConfirm: { execute() },
    onCancel: { dismiss() }
)
```

---

## 1.13 Environment Setup

### TonicThemeProvider

Wrap your view tree in `TonicThemeProvider` to inject the theme:

```swift
TonicThemeProvider(world: .smartScanPurple) {
    YourView()
}
```

Or use the view modifier:

```swift
YourView()
    .tonicTheme(.cleanupGreen)
```

### Environment Values

```swift
// Access current theme
@Environment(\.tonicTheme) private var theme

// Access glass rendering mode
@Environment(\.tonicGlassRenderingMode) private var renderingMode

// Force legacy glass (useful for testing)
@Environment(\.tonicForceLegacyGlass) private var forceLegacy
```

### View Modifiers for Glass Control

```swift
.tonicGlassRenderingMode(.legacy)  // Force legacy glass rendering
.tonicForceLegacyGlass(true)       // Override liquid glass to legacy
```

### How Palette Reactivity Works

`TonicThemeProvider` reads `AppearancePreferences.shared.colorPalette` in its `body`. Since `AppearancePreferences` is `@Observable`, SwiftUI creates an Observation tracking dependency. When the user changes palettes, the body re-evaluates, `TonicWorld.token` returns new palette colors, and the entire view tree updates.

---

# Part 2: Patterns & Recipes

## Building a New Screen (Step-by-Step)

1. **Wrap in TonicThemeProvider** with the appropriate world:
   ```swift
   TonicThemeProvider(world: .cleanupGreen) {
       MyNewScreenContent()
   }
   ```

2. **Add WorldCanvasBackground** as the lowest layer:
   ```swift
   ZStack {
       WorldCanvasBackground()
       ScrollView {
           // content
       }
   }
   ```

3. **Use glass surfaces** for content containers:
   ```swift
   GlassCard {
       // Card-level content (16pt padding)
   }

   GlassPanel(variant: .raised) {
       // Section-level content (24pt padding)
   }

   VStack { ... }
       .glassSurface(radius: TonicRadiusToken.l)
   ```

4. **Apply motion tokens** for animations:
   ```swift
   withAnimation(TonicMotionToken.springTap) { ... }

   .animation(TonicMotionToken.resultCardSpring, value: someValue)
   ```

5. **Respect accessibilityReduceMotion**:
   ```swift
   @Environment(\.accessibilityReduceMotion) private var reduceMotion

   if !reduceMotion {
       withAnimation(.easeInOut(duration: TonicMotionToken.breathingDuration)
           .repeatForever(autoreverses: true)) {
           expanded = true
       }
   }
   ```

6. **Test in both light/dark + all 8 palettes** — use `AppearancePreferences.shared.colorPalette` to cycle through palettes during development.

---

## Dimming Overlay Pattern

Use for modal-like overlays on top of existing content:

```swift
ZStack {
    // 1. Main content
    mainContent
        .blur(radius: showOverlay ? 3 : 0)

    // 2. Dimming backdrop
    if showOverlay {
        Color.black.opacity(0.4)
            .ignoresSafeArea()
            .onTapGesture { dismiss() }
            .transition(.opacity)
    }

    // 3. Overlay card
    if showOverlay {
        SmartScanQuickActionCard(...)
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
.animation(TonicMotionToken.modalPresentSpring, value: showOverlay)
```

---

## Collapsible Hero Pattern

Track scroll position with `GeometryReader` + `PreferenceKey`:

```swift
// In ScrollView:
GeometryReader { geo in
    Color.clear.preference(
        key: ScrollOffsetKey.self,
        value: geo.frame(in: .named("scroll")).minY
    )
}
.frame(height: 0)

// Conditional rendering:
if scrollOffset > -80 {
    ScanHeroModule(state: heroState)  // Full hero
} else {
    CompactScanBar(...)               // Collapsed bar
}
```

Animate with: `animation(.easeInOut(duration: reduceMotion ? 0 : TonicMotionToken.med), value: isCollapsed)`

---

## Staggered Entrance Pattern

```swift
ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
    ItemRow(item: item)
        .staggeredReveal(index: index)
}
```

This applies per-index opacity (0→1), offset (16→0), and scale (0.96→1.0) with `resultStaggerDelay * index` delay using `resultCardSpring`.

---

## Counter Animation Pattern

```swift
Text(formattedValue)
    .contentTransition(.numericText())
    .animation(TonicMotionToken.springTap, value: formattedValue)
```

The `.contentTransition(.numericText())` modifier provides smooth digit-by-digit transitions on `Text` views.

---

## Quick Reference: Token Cheat Sheet

### Spacing

| Token | Value | Use |
|-------|-------|-----|
| `one` | 8pt | Icon-text gaps, tight padding |
| `two` | 12pt | Row spacing, minor padding |
| `three` | 16pt | Content padding, standard spacing |
| `four` | 24pt | Section padding, panel insets |
| `five` | 32pt | Large section gaps |
| `six` | 48pt | Extra large |
| `seven` | 64pt | Hero spacing |
| `gridGap` | 16pt | BentoGrid inter-tile gap |

### Radius

| Token | Value | Use |
|-------|-------|-----|
| `s` | 10pt | Small elements |
| `m` | 14pt | Rows, inputs, icon buttons |
| `l` | 22pt | GlassCard default |
| `xl` | 26pt | GlassPanel default |
| `container` | 30pt | Full-width containers |
| `chip` | 12pt | Chip corners |

### Typography

| Token | Size | Weight | Use |
|-------|------|--------|-----|
| `hero` | 44pt | Semibold | Hero headlines |
| `pillarTitle` | 34pt | Semibold | Section headers |
| `tileMetric` | 28pt | Semibold | Big metric numbers |
| `body` | 15pt | Regular | Body text |
| `caption` | 12pt | Medium | Labels, buttons |
| `micro` | 11pt | Regular | Metadata, tertiary |

### Motion

| Token | Value | Use |
|-------|-------|-----|
| `fast` | 0.12s | Hover, press |
| `med` | 0.20s | Transitions |
| `slow` | 0.35s | Emphasis |
| `springTap` | 0.25/0.82 | Button feedback |
| `resultCardSpring` | 0.45/0.82 | Card entrance |
| `resultStaggerDelay` | 0.08s | Per-index delay |

---

# Part 3: Legacy Design System (Existing Screens)

> **Note:** This section documents the original design system used by screens not yet migrated to the modern system (Dashboard, Preferences, etc.). For new code, use the Modern System from Part 1.

All design tokens are centralized in `DesignTokens.swift` and accessed as static properties.

## Colors

Colors use semantic naming and system colors for automatic light/dark mode support.

### System Semantic Colors (Automatic Light/Dark Mode)

```swift
// Backgrounds
DesignTokens.Colors.background              // Primary window background
DesignTokens.Colors.backgroundSecondary     // Grouped/secondary content
DesignTokens.Colors.backgroundTertiary      // Text field background
DesignTokens.Colors.backgroundUnderPage     // Layered content background

// Text
DesignTokens.Colors.textPrimary             // Primary text (labels)
DesignTokens.Colors.textSecondary           // Secondary text (subtitles)
DesignTokens.Colors.textTertiary            // Tertiary text (metadata)
DesignTokens.Colors.textQuaternary          // Quaternary text (disabled)

// UI Elements
DesignTokens.Colors.accent                  // Primary CTAs, selection, progress
DesignTokens.Colors.separator               // Divider lines
DesignTokens.Colors.grid                    // Grid lines
DesignTokens.Colors.controlBackground       // Button/toggle backgrounds
DesignTokens.Colors.selectedContentBackground     // Selected content
DesignTokens.Colors.unemphasizedSelectedContentBackground // Unemphasized selection

// Status
DesignTokens.Colors.error                   // Errors/destructive actions (red)
DesignTokens.Colors.destructive             // Destructive actions (red)
DesignTokens.Colors.success                 // Green
DesignTokens.Colors.warning                 // Orange
DesignTokens.Colors.info                    // Blue
```

### High Contrast Theme (WCAG AAA Compliant)

```swift
DesignTokens.Colors.highContrastBackground
DesignTokens.Colors.highContrastTextPrimary
DesignTokens.Colors.highContrastAccent
// etc.

// Usage:
@Environment(\.isHighContrast) var isHighContrast
let textColor = DesignTokens.Colors.getTextPrimary(highContrast: isHighContrast)
```

### Color Usage Rules

- **Never use hardcoded colors** — always use tokens
- **Accent**: Primary CTAs, selection, progress
- **Red (destructive)**: Irreversible actions, critical errors
- **Green (success)**: Successful operations, grants
- **Orange (warning)**: Caution states, medium priority
- **Blue (info)**: Informational messages, neutral indicators

## Typography

```swift
// Headlines
DesignTokens.Typography.h1          // 32pt bold
DesignTokens.Typography.h2          // 24pt semibold
DesignTokens.Typography.h3          // 20pt semibold

// Body
DesignTokens.Typography.body        // 16pt regular
DesignTokens.Typography.bodyEmphasized // 16pt semibold

// Secondary
DesignTokens.Typography.subhead     // 14pt regular
DesignTokens.Typography.subheadEmphasized // 14pt medium

// Metadata
DesignTokens.Typography.caption     // 12pt regular
DesignTokens.Typography.captionEmphasized // 12pt medium

// Monospace
DesignTokens.Typography.monoBody    // 16pt monospaced
DesignTokens.Typography.monoSubhead // 14pt monospaced
DesignTokens.Typography.monoCaption // 12pt monospaced
```

## Spacing (8-Point Grid)

```swift
DesignTokens.Spacing.xxxs          // 4pt
DesignTokens.Spacing.xxs           // 8pt
DesignTokens.Spacing.xs            // 12pt
DesignTokens.Spacing.sm            // 16pt
DesignTokens.Spacing.md            // 24pt
DesignTokens.Spacing.lg            // 32pt
DesignTokens.Spacing.xl            // 40pt
DesignTokens.Spacing.xxl           // 48pt

// Component-specific
DesignTokens.Spacing.cardPadding   // 16pt
DesignTokens.Spacing.listPadding   // 12pt
DesignTokens.Spacing.buttonPadding // 12pt
DesignTokens.Spacing.inputPadding  // 8pt
DesignTokens.Spacing.sectionGap    // 24pt
```

## Corner Radius

```swift
DesignTokens.CornerRadius.small    // 4pt
DesignTokens.CornerRadius.medium   // 8pt
DesignTokens.CornerRadius.large    // 12pt
DesignTokens.CornerRadius.xlarge   // 16pt
DesignTokens.CornerRadius.round    // 9999
```

## Animation

```swift
// Timing
DesignTokens.AnimationDuration.instant     // 0s
DesignTokens.AnimationDuration.fast        // 0.15s
DesignTokens.AnimationDuration.normal      // 0.25s
DesignTokens.AnimationDuration.slow        // 0.35s
DesignTokens.AnimationDuration.slower      // 0.5s

// Curves
DesignTokens.AnimationCurve.spring         // Spring with 0.3s response
DesignTokens.AnimationCurve.springBouncy   // Bouncy spring
DesignTokens.AnimationCurve.smooth         // Smooth cubic bezier

// Predefined
DesignTokens.Animation.fast        // easeOut, 0.15s
DesignTokens.Animation.normal      // easeInOut, 0.25s
DesignTokens.Animation.slow        // easeInOut, 0.35s
DesignTokens.Animation.spring      // Spring curve
```

## Layout Constants

```swift
DesignTokens.Layout.minButtonHeight     // 36pt
DesignTokens.Layout.minRowHeight        // 44pt
DesignTokens.Layout.maxContentWidth     // 1200pt
DesignTokens.Layout.sidebarWidth        // 220pt
DesignTokens.Layout.cardMinWidth        // 280pt
```

## Legacy Components

### Card

Three variants: `elevated` (shadow), `flat` (border only), `inset` (inset border).

```swift
Card(variant: .elevated) {
    content
}
```

### MetricRow

Fixed-height (44pt) row with icon, title, value, optional sparkline.

```swift
MetricRow(
    icon: "cpu",
    title: "CPU Usage",
    value: "45%",
    sparklineData: [0.3, 0.4, 0.5]
)
```

### PreferenceList

Grouped settings list with sections, headers, toggles, pickers, buttons.

```swift
PreferenceList {
    PreferenceSection(header: "General") {
        PreferenceToggleRow(title: "Launch at Login", isOn: $launchAtLogin)
    }
}
```

### Other Legacy Components

- `PrimaryButton` / `SecondaryButton` — CTA and secondary buttons
- `StatusIndicator` — RAG (Red-Amber-Green) dot
- `StatusCard` — Card with icon, title, status
- `ProgressBar` — Linear progress
- `EmptyState` — Illustrated empty state
- `SearchBar` — Search input
- `Badge` — Status label
- `LoadingIndicator` — Spinner

## Animation Utilities (DesignAnimations.swift)

```swift
.shimmer()              // Loading shimmer
.fadeIn(delay: 0.2)     // Fade in with delay
.fadeInSlideUp()        // Fade + slide up
.scaleIn()              // Scale from 0 to 1
.slideIn(from: .trailing)
.bounce()               // Bounce effect
.pulse(intensity: 0.5)  // Pulsing
.rotate(duration: 2)    // Continuous rotation
.pressEffect(scale: 0.95)
.skeleton()             // Skeleton loading placeholder
```

## Popover Components (Stats Master Parity)

### PopoverConstants

```swift
PopoverConstants.width               // 280pt
PopoverConstants.maxHeight           // 600pt
PopoverConstants.fontSmall           // 9pt
PopoverConstants.fontDefault         // 11pt
PopoverConstants.fontHeader          // 13pt
PopoverConstants.compactSpacing      // 4pt
PopoverConstants.itemSpacing         // 12pt
PopoverConstants.horizontalPadding   // 16pt
PopoverConstants.sectionSpacing      // 24pt
PopoverConstants.innerCornerRadius   // 6pt
PopoverConstants.cornerRadius        // 10pt
```

### Reusable Popover Components (PopoverTemplate.swift)

```swift
ProcessRow(pid:name:cpuUsage:memoryUsage:iconName:onKill:)
IconLabelRow(icon:label:value:color:)
SectionHeader(title:icon:)
EmptyStateView(icon:title:)
PopoverDetailRow(label:value:)
PopoverDetailGrid(pairs:)
```

### Gauge Components

- `PressureGaugeView` — 3-color arc gauge for memory pressure
- `TachometerView` — Half-circle gauge for CPU/GPU utilization

---

# Part 4: Migration Guide

## Legacy → Modern Token Mapping

### Spacing

| Legacy | Modern | Value |
|--------|--------|-------|
| `DesignTokens.Spacing.xxs` | `TonicSpaceToken.one` | 8pt |
| `DesignTokens.Spacing.xs` | `TonicSpaceToken.two` | 12pt |
| `DesignTokens.Spacing.sm` | `TonicSpaceToken.three` | 16pt |
| `DesignTokens.Spacing.md` | `TonicSpaceToken.four` | 24pt |
| `DesignTokens.Spacing.lg` | `TonicSpaceToken.five` | 32pt |
| `DesignTokens.Spacing.xxl` | `TonicSpaceToken.six` | 48pt |

### Typography

| Legacy | Modern | Size |
|--------|--------|------|
| `DesignTokens.Typography.h1` (32pt) | `TonicTypeToken.pillarTitle` (34pt) | ~same |
| `DesignTokens.Typography.body` (16pt) | `TonicTypeToken.body` (15pt) | ~same |
| `DesignTokens.Typography.caption` (12pt) | `TonicTypeToken.caption` (12pt) | same |
| — | `TonicTypeToken.hero` (44pt) | new |
| — | `TonicTypeToken.tileMetric` (28pt) | new |
| — | `TonicTypeToken.micro` (11pt) | new |

### Corner Radius

| Legacy | Modern | Value |
|--------|--------|-------|
| `DesignTokens.CornerRadius.small` (4pt) | — | no direct equivalent |
| `DesignTokens.CornerRadius.medium` (8pt) | `TonicRadiusToken.s` (10pt) | slightly larger |
| `DesignTokens.CornerRadius.large` (12pt) | `TonicRadiusToken.m` (14pt) | slightly larger |
| `DesignTokens.CornerRadius.xlarge` (16pt) | `TonicRadiusToken.l` (22pt) | significantly larger |

### Components

| Legacy | Modern |
|--------|--------|
| `Card(variant: .elevated)` | `GlassCard(variant: .raised)` |
| `Card(variant: .flat)` | `GlassCard(variant: .base)` |
| `Card(variant: .inset)` | `GlassCard(variant: .sunken)` |
| `PrimaryButton` | `PrimaryActionButton` |
| `SecondaryButton` | `SecondaryPillButton` |
| `EmptyState` | `EmptyStatePanel` |
| `SearchBar` | `SearchField` |
| `Badge` | `GlassChip` / `MetaBadge` |
| `StatusIndicator` | `GlassChip(role: .semantic(...))` |

### Colors

| Legacy | Modern |
|--------|--------|
| `DesignTokens.Colors.textPrimary` | `TonicTextToken.primary` |
| `DesignTokens.Colors.textSecondary` | `TonicTextToken.secondary` |
| `DesignTokens.Colors.textTertiary` | `TonicTextToken.tertiary` |
| `DesignTokens.Colors.accent` | `theme.accent` (world-specific) |
| `DesignTokens.Colors.success` | `TonicStatusPalette.text(.success)` |
| `DesignTokens.Colors.warning` | `TonicStatusPalette.text(.warning)` |
| `DesignTokens.Colors.error` | `TonicStatusPalette.text(.danger)` |
| `DesignTokens.Colors.info` | `TonicStatusPalette.text(.info)` |
| `DesignTokens.Colors.background` | `WorldCanvasBackground` + `TonicNeutralToken.dynamicBackground` |
| `DesignTokens.Colors.backgroundSecondary` | `TonicGlassToken.fill` |
| `DesignTokens.Colors.separator` | `TonicStrokeToken.subtle` |

### Animations

| Legacy | Modern |
|--------|--------|
| `DesignTokens.Animation.fast` (0.15s) | `TonicMotionToken.fast` (0.12s) |
| `DesignTokens.Animation.normal` (0.25s) | `TonicMotionToken.med` (0.20s) |
| `DesignTokens.Animation.slow` (0.35s) | `TonicMotionToken.slow` (0.35s) |
| `DesignTokens.Animation.spring` | `TonicMotionToken.springTap` |
| `.fadeIn()` | `.staggeredReveal(index:)` |
| `.pressEffect()` | `PressEffect(focusShape:)` ButtonStyle |

---

## Files Reference

### Modern System

| File | Purpose |
|------|---------|
| `TonicThemeTokens.swift` | World colors, palettes, neutral/text/stroke tokens, spacing, radius, typography, motion, glass, shadow, button, chip, canvas, semantic, theme struct |
| `TonicVisualPrimitives.swift` | View modifiers — glass surface, canvas background, depth effects, hover/press, breathing, sweep, stagger, burst, pulse, typography views |
| `TonicSmartScanComponents.swift` | 30+ reusable UI components — buttons, chips, rows, headers, grids, state panels, detail views, hub components |
| `TonicThemeProvider.swift` | Environment plumbing — `TonicThemeProvider`, `@Environment(\.tonicTheme)`, glass rendering mode, force legacy glass |

### Legacy System

| File | Purpose |
|------|---------|
| `DesignTokens.swift` | Colors, typography, spacing, animations, layout constants |
| `DesignComponents.swift` | Card, MetricRow, PreferenceList, buttons, badges, status indicators |
| `DesignAnimations.swift` | Animation modifiers (shimmer, fadeIn, scaleIn, slideIn, bounce, pulse, etc.) |
| `PopoverConstants.swift` | Popover-specific spacing, typography, sizes (Stats Master parity) |
| `PopoverTemplate.swift` | Reusable popover components (ProcessRow, IconLabelRow, SectionHeader, etc.) |

---

## Resources

- **Apple HIG**: macOS Design Themes and Semantics
- **WCAG**: Web Content Accessibility Guidelines
- **Modern tokens**: `Tonic/Tonic/Design/TonicThemeTokens.swift`
- **Modern primitives**: `Tonic/Tonic/Design/TonicVisualPrimitives.swift`
- **Modern components**: `Tonic/Tonic/Design/TonicSmartScanComponents.swift`
- **Modern plumbing**: `Tonic/Tonic/Design/TonicThemeProvider.swift`
- **Legacy tokens**: `Tonic/Tonic/Design/DesignTokens.swift`
- **Legacy components**: `Tonic/Tonic/Design/DesignComponents.swift`
- **Legacy animations**: `Tonic/Tonic/Design/DesignAnimations.swift`
