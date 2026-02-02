# Tonic Design System Documentation

Comprehensive design system documentation for the Tonic macOS application, including component specifications, design tokens, and usage examples.

## Overview

The Tonic design system provides a cohesive, native macOS experience with consistent spacing, typography, colors, and reusable components. All design tokens and components support both light and dark modes using semantic system colors.

**Key Principles:**
- **Native macOS**: Use system semantics and native components
- **Semantic Colors**: All hardcoded colors replaced with system semantic colors
- **8-Point Grid**: All spacing values are multiples of 8pt (except xxxs at 4pt)
- **Accessibility**: WCAG AA contrast minimum (4.5:1), with WCAG AAA support via high contrast theme
- **Performance**: Animations optimized, no decorative motion
- **Consistency**: All components use design tokens, no magic values

---

## Design Tokens

All design tokens are centralized in `DesignTokens.swift` and accessed as static properties.

### Colors

Colors use semantic naming and system colors for automatic light/dark mode support.

#### System Semantic Colors (Automatic Light/Dark Mode)

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
```

#### Custom Semantic Colors (WCAG AA Compliant)

```swift
// Success - safe actions, confirmations (from Asset Catalog)
DesignTokens.Colors.success                 // Green - WCAG AA on all backgrounds

// Warning - caution, attention needed (from Asset Catalog)
DesignTokens.Colors.warning                 // Orange - WCAG AA on all backgrounds

// Info - informational, neutral guidance (from Asset Catalog)
DesignTokens.Colors.info                    // Blue - WCAG AA on all backgrounds
```

#### High Contrast Theme (WCAG AAA Compliant)

For accessibility, use these colors when high contrast is enabled:

```swift
// High contrast colors - all meet 7:1 minimum contrast on white
DesignTokens.Colors.highContrastBackground
DesignTokens.Colors.highContrastBackgroundSecondary
DesignTokens.Colors.highContrastTextPrimary
DesignTokens.Colors.highContrastTextSecondary
DesignTokens.Colors.highContrastTextTertiary
DesignTokens.Colors.highContrastAccent
DesignTokens.Colors.highContrastSuccess
DesignTokens.Colors.highContrastWarning
DesignTokens.Colors.highContrastDestructive

// Usage in views:
@Environment(\.isHighContrast) var isHighContrast
let textColor = DesignTokens.Colors.getTextPrimary(highContrast: isHighContrast)
```

#### Color Usage Rules

- **Never use hardcoded colors** - always use tokens
- **Accent color** is for:
  - Primary CTAs (buttons)
  - Selection indicators
  - Progress bars
  - Active navigation items
- **Red (destructive)** is for:
  - Destructive/irreversible actions
  - Critical errors
  - Permission denials
- **Green (success)** is for:
  - Successful operations
  - Permission grants
  - Positive confirmations
- **Orange (warning)** is for:
  - Caution states
  - Partial issues
  - Medium priority items
- **Blue (info)** is for:
  - Informational messages
  - Secondary metrics
  - Neutral indicators

### Typography

Typography scale provides consistent text sizing across the app.

#### Font Sizes

```swift
// Headlines (use only one h1 per screen)
DesignTokens.Typography.h1          // 32pt bold - page title
DesignTokens.Typography.h2          // 24pt semibold - section header
DesignTokens.Typography.h3          // 20pt semibold - subsection header

// Body Text
DesignTokens.Typography.body        // 16pt regular - primary content
DesignTokens.Typography.bodyEmphasized // 16pt semibold - emphasized body

// Secondary Text
DesignTokens.Typography.subhead     // 14pt regular - secondary content
DesignTokens.Typography.subheadEmphasized // 14pt medium - emphasized secondary

// Metadata
DesignTokens.Typography.caption     // 12pt regular - metadata, timestamps
DesignTokens.Typography.captionEmphasized // 12pt medium - emphasized metadata

// Monospace (for code/numbers)
DesignTokens.Typography.monoBody    // 16pt monospaced - large numbers
DesignTokens.Typography.monoSubhead // 14pt monospaced - medium numbers
DesignTokens.Typography.monoCaption // 12pt monospaced - small numbers
```

#### Typography Usage Rules

- **One h1 per screen maximum** - use for primary page title
- **h2** for major section headers
- **h3** for subsections or grouped content
- **body** for primary content text (16pt)
- **subhead** for secondary content (14pt)
- **caption** for metadata like timestamps or hints (12pt)
- **mono\*** fonts for numbers and code - ensures monospaced alignment
- **Never override font sizes inline** - always use tokens

#### Usage Example

```swift
Text("Dashboard")
    .font(DesignTokens.Typography.h1)
    .foregroundColor(DesignTokens.Colors.textPrimary)

Text("System Status")
    .font(DesignTokens.Typography.h2)

Text("CPU Usage: 45%")
    .font(DesignTokens.Typography.monoBody)
    .foregroundColor(DesignTokens.Colors.textSecondary)
```

### Spacing (8-Point Grid)

All spacing follows the 8-point grid system (except xxxs at 4pt for tight icon-text gaps).

```swift
DesignTokens.Spacing.xxxs          // 4pt - icon-text gaps only
DesignTokens.Spacing.xxs           // 8pt - small padding
DesignTokens.Spacing.xs            // 12pt - minor separation
DesignTokens.Spacing.sm            // 16pt - default small spacing
DesignTokens.Spacing.md            // 24pt - default medium spacing
DesignTokens.Spacing.lg            // 32pt - section gaps
DesignTokens.Spacing.xl            // 40pt - extra large spacing
DesignTokens.Spacing.xxl           // 48pt - very large spacing
```

#### Component-Specific Spacing

```swift
DesignTokens.Spacing.cardPadding   // 16pt (same as sm)
DesignTokens.Spacing.listPadding   // 12pt (same as xs)
DesignTokens.Spacing.buttonPadding // 12pt (same as xs)
DesignTokens.Spacing.inputPadding  // 8pt (same as xxs)
DesignTokens.Spacing.sectionGap    // 24pt (same as md)
```

#### Spacing Usage Rules

- **Always use spacing tokens** - never magic values
- **Vertical rhythm** uses sm (16pt) or md (24pt) between elements
- **Section separation** uses md (24pt) or lg (32pt)
- **Component padding** use predefined constants (cardPadding, listPadding)
- **Never use margins** - use padding and spacing

### Corner Radius

```swift
DesignTokens.CornerRadius.small    // 4pt - small UI elements
DesignTokens.CornerRadius.medium   // 8pt - default components
DesignTokens.CornerRadius.large    // 12pt - cards, major containers
DesignTokens.CornerRadius.xlarge   // 16pt - large modals/panels
DesignTokens.CornerRadius.round    // 9999 - fully rounded (circles)
```

#### Corner Radius Usage

- **Cards**: Use `large` (12pt)
- **Buttons**: Use `medium` (8pt)
- **Input fields**: Use `medium` (8pt)
- **Badges**: Use `round` for pill shapes
- **Modals/Sheets**: Use `large` or `xlarge`

### Animation Durations and Curves

#### Timing

```swift
DesignTokens.AnimationDuration.instant     // 0s - immediate
DesignTokens.AnimationDuration.fast        // 0.15s - UI interactions
DesignTokens.AnimationDuration.normal      // 0.25s - transitions
DesignTokens.AnimationDuration.slow        // 0.35s - emphasis
DesignTokens.AnimationDuration.slower      // 0.5s - delayed feedback
```

#### Curves

```swift
DesignTokens.AnimationCurve.linear         // Linear easing
DesignTokens.AnimationCurve.easeIn         // Ease in
DesignTokens.AnimationCurve.easeOut        // Ease out
DesignTokens.AnimationCurve.easeInOut      // Ease in/out
DesignTokens.AnimationCurve.spring         // Spring with 0.3s response
DesignTokens.AnimationCurve.springBouncy   // Bouncy spring
DesignTokens.AnimationCurve.smooth         // Smooth cubic bezier
```

#### Predefined Animations

```swift
DesignTokens.Animation.fast        // easeOut, 0.15s - fast UI changes
DesignTokens.Animation.normal      // easeInOut, 0.25s - standard transitions
DesignTokens.Animation.slow        // easeInOut, 0.35s - slow transitions
DesignTokens.Animation.spring      // Spring curve
DesignTokens.Animation.springBouncy // Bouncy spring
```

#### Animation Usage Rules

- **Use `.fast` (0.15s)** for: expand/collapse, selection changes, progress updates
- **Never use decorative animations** - animations must serve a purpose
- **Always animate with tokens** - never hardcode durations
- **Grouped animations**: use `withAnimation(DesignTokens.Animation.fast) { ... }`

#### Usage Example

```swift
withAnimation(DesignTokens.Animation.fast) {
    isExpanded.toggle()
}

Text("Scanning...")
    .transition(.scaleAndFade)
    .animation(DesignTokens.Animation.normal, value: isScanning)
```

### Layout Constants

```swift
DesignTokens.Layout.minButtonHeight     // 36pt
DesignTokens.Layout.minRowHeight        // 44pt (MetricRow fixed height)
DesignTokens.Layout.maxContentWidth     // 1200pt
DesignTokens.Layout.sidebarWidth        // 220pt
DesignTokens.Layout.cardMinWidth        // 280pt
```

---

## Components

### Card Component

Flexible card with 3 semantic variants using design tokens for proper light/dark mode support.

#### Variants

| Variant | Use Case | Style |
|---------|----------|-------|
| **elevated** | Primary content containers | Shadow for depth |
| **flat** | Secondary content | Border only, no shadow |
| **inset** | Grouped/nested content | Inset border |

#### Card Implementation

```swift
// Card has semantic variants that handle styling automatically
enum CardVariant {
    case elevated    // Shadow for depth (primary content containers)
    case flat       // No shadow, border only (secondary content)
    case inset      // Inset border (grouped/nested content)
}

struct Card<Content: View>: View {
    let content: Content
    let variant: CardVariant
    var padding: CGFloat = DesignTokens.Spacing.cardPadding
    var cornerRadius: CGFloat = DesignTokens.CornerRadius.large

    var body: some View { ... }
}
```

#### Card Usage

```swift
// Elevated card - for main content
Card(variant: .elevated) {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
        Text("Primary Content")
            .font(DesignTokens.Typography.body)
        Text("This is the main content area")
            .font(DesignTokens.Typography.caption)
            .foregroundColor(DesignTokens.Colors.textSecondary)
    }
}

// Flat card - for secondary content
Card(variant: .flat) {
    HStack {
        Image(systemName: "info.circle")
        Text("Additional information")
    }
}

// Inset card - for nested content
Card(variant: .inset) {
    VStack {
        ForEach(items) { item in
            Text(item.name)
        }
    }
}
```

#### Card Features

- Automatic light/dark mode using `DesignTokens.Colors.backgroundSecondary`
- Fixed corner radius (12pt) with customizable override
- Customizable padding (default 16pt)
- No custom dark colors - uses semantic system colors
- Works correctly in both light and dark modes

---

### MetricRow Component

Displays metrics with icon, title, value, and optional sparkline. Fixed height (44pt) for consistent list appearance.

#### Layout

```
[Icon] | Title        | [Sparkline]
       | Value        |
```

#### MetricRow Implementation

```swift
struct MetricRow: View {
    let icon: String              // SF Symbol name
    let title: String             // e.g., "CPU Usage"
    let value: String             // e.g., "45%"
    var iconColor: Color = DesignTokens.Colors.accent
    var sparklineData: [Double]? = nil  // Optional historical data (0-1)
    var sparklineColor: Color? = nil    // Defaults to accent

    var body: some View { ... }
}
```

#### MetricRow Features

- **Fixed height**: 44pt (DesignTokens.Layout.minRowHeight)
- **Icon column**: 24pt wide, centered, with custom color
- **Title**: Subhead (14pt) in secondary text color
- **Value**: Monospace body (16pt) in primary text color for alignment
- **Optional sparkline**: 60x24pt sparkline showing metric history
- **Accessibility**: Combined element with dynamic label

#### MetricRow Usage

```swift
// Simple metric
MetricRow(
    icon: "cpu",
    title: "CPU Usage",
    value: "45%",
    iconColor: DesignTokens.Colors.accent
)

// Metric with sparkline
MetricRow(
    icon: "memorychip",
    title: "Memory",
    value: "8.2 GB / 16 GB",
    iconColor: DesignTokens.Colors.info,
    sparklineData: [0.3, 0.4, 0.35, 0.5, 0.45, 0.52, 0.51],
    sparklineColor: DesignTokens.Colors.info
)

// In a list
VStack(spacing: 0) {
    MetricRow(icon: "cpu", title: "CPU", value: "45%")
    Divider()
    MetricRow(icon: "memorychip", title: "Memory", value: "8.2 GB")
    Divider()
    MetricRow(icon: "internaldrive", title: "Disk", value: "234 GB free")
}
```

#### Sparkline

The MetricSparkline component renders historical data as a line chart:
- Normalizes data to 0-1 range automatically
- Supports any number of data points
- Smooth rendering with rounded line caps
- Used for showing metric trends over time

---

### PreferenceList Component

Grouped settings list with sections, headers, and various control types.

#### PreferenceList Structure

```swift
struct PreferenceList<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) { ... }
    var body: some View { ... }
}

struct PreferenceSection<Content: View>: View {
    let header: String?
    let footer: String?
    let content: Content

    init(header: String? = nil, footer: String? = nil,
         @ViewBuilder content: () -> Content) { ... }
    var body: some View { ... }
}

struct PreferenceRow<Control: View>: View {
    let title: String
    let subtitle: String?
    let icon: String?
    var iconColor: Color = DesignTokens.Colors.accent
    let control: Control
    var showDivider: Bool = true

    var body: some View { ... }
}
```

#### PreferenceList Usage

```swift
PreferenceList {
    PreferenceSection(header: "General", footer: "These control startup behavior") {
        PreferenceToggleRow(
            title: "Launch at Login",
            subtitle: "Start Tonic when you log in",
            icon: "power",
            isOn: $launchAtLogin
        )

        PreferencePickerRow(
            title: "Theme",
            subtitle: "Choose your appearance",
            icon: "paintbrush",
            selection: $selectedTheme
        ) {
            Text("System").tag("System")
            Text("Light").tag("Light")
            Text("Dark").tag("Dark")
        }
    }

    PreferenceSection(header: "Permissions") {
        PermissionStatusRow(
            title: "Full Disk Access",
            subtitle: "Scan all files",
            icon: "externaldrive",
            status: permissionStatus,
            onGrantTapped: { requestPermission() }
        )
    }

    PreferenceSection(header: "Actions") {
        PreferenceButtonRow(
            title: "Clear Cache",
            subtitle: "Remove temporary files",
            icon: "trash",
            buttonTitle: "Clear",
            buttonStyle: .secondary,
            action: { clearCache() }
        )
    }
}
```

#### Convenience Components

##### PreferenceToggleRow

```swift
PreferenceToggleRow(
    title: "Automatic Updates",
    subtitle: "Check automatically",
    icon: "arrow.triangle.2.circlepath",
    showDivider: true,
    isOn: $automaticUpdates
)
```

##### PreferencePickerRow

```swift
PreferencePickerRow(
    title: "Update Frequency",
    icon: "clock",
    selection: $frequency
) {
    Text("5 minutes").tag("5m")
    Text("15 minutes").tag("15m")
    Text("60 minutes").tag("60m")
}
```

##### PreferenceButtonRow

```swift
PreferenceButtonRow(
    title: "Reset Settings",
    subtitle: "Restore defaults",
    icon: "arrow.counterclockwise",
    buttonTitle: "Reset",
    buttonStyle: .destructive,
    action: { resetSettings() }
)
```

##### PreferenceStatusRow

```swift
PreferenceStatusRow(
    title: "Helper Tool",
    icon: "gear",
    status: .healthy,
    statusText: "Installed"
)
```

##### PermissionStatusRow

```swift
PermissionStatusRow(
    title: "Full Disk Access",
    subtitle: "Required for complete scanning",
    icon: "externaldrive",
    status: permissionStatus,
    onGrantTapped: { grantPermission() }
)
```

#### PreferenceList Features

- **Grouped sections** with optional headers and footers
- **Automatic background** using `backgroundSecondary` color
- **Row dividers** - visible between rows, optional on last row
- **Hover effects** on rows with animation
- **Consistent padding** - sm vertical (16pt), md horizontal (24pt)
- **Icon support** with color customization
- **Accessibility** - combined elements with dynamic labels

---

### Other Components

#### PrimaryButton

Main call-to-action button with accent background.

```swift
PrimaryButton("Start Scan", icon: "play.fill") {
    startScan()
}
```

#### SecondaryButton

Secondary action button with border.

```swift
SecondaryButton("Cancel") {
    cancel()
}
```

#### StatusIndicator

Small colored indicator for RAG (Red-Amber-Green) status.

```swift
// Shows colored dot with label
StatusIndicator(level: .healthy)
StatusIndicator(level: .warning)
StatusIndicator(level: .critical)
```

#### StatusCard

Card with icon, title, description, and RAG status.

```swift
StatusCard(
    icon: "gear",
    title: "Helper Tool",
    description: "Privileged access for deep cleaning",
    status: .healthy,
    action: { installHelper() }
)
```

#### ProgressBar

Linear progress indicator with optional percentage.

```swift
ProgressBar(value: 45, total: 100)
ProgressBar(value: 1.2, total: 2.0, color: .orange, height: 6)
```

#### EmptyState

Illustrated empty state with optional action button.

```swift
EmptyState(
    icon: "magnifyingglass",
    title: "No Items",
    message: "Start a scan to find files to clean",
    actionTitle: "Start Scan",
    action: { startScan() }
)
```

#### SearchBar

Search input field with clear button.

```swift
@State private var searchText = ""

SearchBar(text: $searchText, placeholder: "Search apps...")
```

#### Badge

Small label for status/categorization.

```swift
Badge("Pro", color: DesignTokens.Colors.accent, size: .medium)
```

#### LoadingIndicator

Spinning progress indicator.

```swift
LoadingIndicator()
```

---

## Animation Utilities

Located in `DesignAnimations.swift`, provides reusable animation effects.

### View Modifiers

#### Shimmer Effect

```swift
Text("Loading...")
    .shimmer()
    .shimmer(colors: [.white.opacity(0), .white.opacity(0.5)])
```

#### Fade In

```swift
Text("Content")
    .fadeIn()
    .fadeIn(delay: 0.2)
    .fadeInSlideUp(offset: 20, delay: 0.1)
```

#### Scale In

```swift
Image(systemName: "checkmark.circle")
    .scaleIn()
    .scaleIn(delay: 0.3)
```

#### Slide In

```swift
Card {
    content
}
.slideIn(from: .trailing, offset: 30)
```

#### Bounce

```swift
Button("Tap Me") { }
    .bounce()
```

#### Pulse

```swift
LoadingIndicator()
    .pulse(intensity: 0.5)
```

#### Rotate

```swift
Image(systemName: "gear")
    .rotate(duration: 2, degrees: 360)
```

#### Press Effect

```swift
Button("Click") { }
    .pressEffect(scale: 0.95)
    .interactivePress()  // Gesture-based
```

#### Skeleton Loading

```swift
Text("...")
    .skeleton()
```

### Transitions

```swift
Text("Disappearing")
    .transition(.scaleAndFade)
    .transition(.slideAndFade)
```

### Conditional Animation

```swift
Text("Value: \(value)")
    .animateIf(isAnimating, animation: .easeInOut(duration: 0.3))
```

---

## High Contrast Mode

Support accessibility needs with high contrast theme.

### Environment Key

```swift
@Environment(\.isHighContrast) var isHighContrast
```

### Helper Functions

```swift
// Get color respecting high contrast setting
let textColor = DesignTokens.Colors.getTextPrimary(highContrast: isHighContrast)
let accentColor = DesignTokens.Colors.getAccent(highContrast: isHighContrast)

// Available helpers:
// - getTextPrimary(highContrast:)
// - getTextSecondary(highContrast:)
// - getTextTertiary(highContrast:)
// - getBackground(highContrast:)
// - getBackgroundSecondary(highContrast:)
// - getAccent(highContrast:)
// - getSuccess(highContrast:)
// - getWarning(highContrast:)
// - getDestructive(highContrast:)
```

### Usage Example

```swift
@Environment(\.isHighContrast) var isHighContrast

var body: some View {
    VStack {
        Text("Primary")
            .foregroundColor(DesignTokens.Colors.getTextPrimary(highContrast: isHighContrast))

        Text("Secondary")
            .foregroundColor(DesignTokens.Colors.getTextSecondary(highContrast: isHighContrast))
    }
    .background(DesignTokens.Colors.getBackground(highContrast: isHighContrast))
}
```

---

## Keyboard Navigation

### Focus Management

All interactive elements support keyboard navigation:

- **Tab**: Navigate between elements
- **Shift+Tab**: Navigate backward
- **Space/Return**: Activate buttons
- **Arrow keys**: Navigate in lists/pickers
- **Cmd+K**: Open command palette
- **Esc**: Close modals/sheets

### Accessibility Labels

All interactive elements have accessibility labels:

```swift
Button("Start Scan") {
    startScan()
}
.accessibilityLabel("Start Smart Scan")
.accessibilityHint("Scans your system for files to clean")

MetricRow(
    icon: "cpu",
    title: "CPU Usage",
    value: "45%"
)
// Automatically creates label: "CPU Usage: 45%"
```

---

## Quick Start Guide

### Adding a New Screen

1. **Create the view** in `Views/YourScreenName.swift`
2. **Use semantic colors**: Always use `DesignTokens.Colors.*`
3. **Use typography scale**: Always use `DesignTokens.Typography.*`
4. **Use spacing tokens**: Always use `DesignTokens.Spacing.*`
5. **Apply animations**: Use `DesignTokens.Animation.*`
6. **Add accessibility**: Include labels and hints
7. **Test light/dark modes**: Verify all colors in both modes

### Adding a New Component

1. **Create in `Design/YourComponent.swift`**
2. **Document with inline comments** explaining purpose and parameters
3. **Add SwiftUI Previews** for testing
4. **Use design tokens throughout** - no hardcoded values
5. **Support accessibility** with labels and hints
6. **Test in light/dark modes** using preview environment

### Using Components

```swift
// Import if in different file
import Design

// Use Card for containers
Card(variant: .elevated) {
    content
}

// Use MetricRow for metrics lists
MetricRow(
    icon: "cpu",
    title: "CPU",
    value: "45%",
    sparklineData: historicalData
)

// Use PreferenceList for settings
PreferenceList {
    PreferenceSection(header: "General") {
        PreferenceToggleRow(
            title: "Launch at Login",
            isOn: $launchAtLogin
        )
    }
}

// Use animation with tokens
withAnimation(DesignTokens.Animation.fast) {
    isVisible.toggle()
}
```

---

## Best Practices

### Colors

- Use `DesignTokens.Colors.*` for all colors
- Never hardcode RGB values
- Use high contrast helpers when needed
- Verify WCAG AA contrast (4.5:1 minimum)

### Typography

- One h1 per screen maximum
- Use appropriate sizes for hierarchy
- Never override inline - use tokens
- Prefer semantic names (body, subhead) over descriptive (h2, h3)

### Spacing

- Always use spacing tokens
- Maintain 8-point grid
- Use xxxs (4pt) only for icon-text gaps
- Section gaps use md (24pt) or lg (32pt)

### Components

- Reuse existing components
- Prefer PreferenceList for settings
- Use MetricRow for metrics lists
- Card variants for different contexts

### Animations

- Use predefined animations (fast, normal, slow)
- Avoid decorative motion
- Animations must have purpose
- Always use `withAnimation()` for grouped changes

### Accessibility

- Add labels to all interactive elements
- Dynamic labels for changing content
- Verify keyboard navigation
- Test in high contrast mode
- Aim for WCAG AA minimum (4.5:1)

---

## Migration Guide

### From Hardcoded Colors

**Before:**
```swift
.foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
```

**After:**
```swift
.foregroundColor(DesignTokens.Colors.textSecondary)
```

### From Custom Spacing

**Before:**
```swift
.padding(16)
.spacing: 32
```

**After:**
```swift
.padding(DesignTokens.Spacing.sm)
.spacing: DesignTokens.Spacing.lg
```

### From Inline Fonts

**Before:**
```swift
.font(.system(size: 16, weight: .semibold))
```

**After:**
```swift
.font(DesignTokens.Typography.bodyEmphasized)
```

---

## Files Reference

| File | Purpose |
|------|---------|
| `DesignTokens.swift` | Colors, typography, spacing, animations, layout constants |
| `DesignComponents.swift` | Card, MetricRow, PreferenceList, buttons, badges, status indicators |
| `DesignAnimations.swift` | Animation modifiers (shimmer, fadeIn, scaleIn, slideIn, bounce, pulse, etc.) |
| `PopoverConstants.swift` | Popover-specific spacing, typography, sizes (Stats Master parity) |
| `PopoverTemplate.swift` | Reusable popover components (ProcessRow, IconLabelRow, SectionHeader, etc.) |

---

## Popover Components (Stats Master Parity)

Located in `Tonic/MenuBarWidgets/Popovers/`:

### Gauge Components

#### PressureGaugeView
Three-color arc gauge with rotating needle for memory pressure display:
- **Green arc**: 0-50% (healthy)
- **Yellow arc**: 50-80% (warning)
- **Red arc**: 80-100% (critical)
- **Needle**: Rotates based on pressure percentage
- **Size**: ~80x80pt
- **Usage**: `MemoryPopoverView` for primary visual

#### TachometerView
Half-circle gauge for utilization display:
- **Arc**: 180° semicircle
- **Range**: 0-100%
- **Color**: Utilization-based (green→yellow→orange→red)
- **Needle**: Rotating indicator
- **Usage**: CPU/GPU utilization gauges

### Chart Components

#### DualLineChartView
Dual-line chart for read/write bandwidth:
- **Lines**: Upload (one color), Download (another color)
- **History**: 180 samples max
- **Labels**: Automatic min/max
- **Usage**: `NetworkPopoverView`, `DiskPopoverView`

#### CombinedCPUChartView
Combination line + bar chart for CPU data:
- **Line**: Total usage over time
- **Bars**: Per-core usage
- **Colors**: E-cores (one color), P-cores (another)
- **Usage**: `CPUPopoverView`

### Container Components

#### PerGpuContainer
Container for multi-GPU displays:
- **Layout**: Vertical stack of GPU cards
- **Each card**: Status dot, gauges, charts, expandable details
- **Toggle**: DETAILS button to expand/collapse info
- **Usage**: `GPUPopoverView`

#### PerDiskContainer
Container for multi-volume displays:
- **Layout**: Vertical stack of disk cards
- **Each card**: Usage bar, I/O stats, dual-line chart
- **Selection**: Tap to select volume
- **Usage**: `DiskPopoverView`

### Fan Control Components

#### FanControlView
Fan speed control interface:
- **Fan List**: Each fan with name, current RPM
- **Sliders**: Per-fan RPM control with min/max indicators
- **Mode Selection**: Manual/Auto/System segmented control
- **Visual**: Speed bars, mode indicators
- **Requirements**: Helper tool for write operations
- **Location**: `SensorsPopoverView`

### Popover Constants

```swift
// Dimensions (Stats Master parity)
PopoverConstants.width           // 280pt
PopoverConstants.maxHeight       // 600pt

// Typography
PopoverConstants.fontSmall       // 9pt
PopoverConstants.fontDefault     // 11pt
PopoverConstants.fontHeader      // 13pt

// Spacing (8-point grid)
PopoverConstants.compactSpacing  // 4pt
PopoverConstants.iconTextGap     // 8pt
PopoverConstants.itemSpacing     // 12pt
PopoverConstants.horizontalPadding // 16pt
PopoverConstants.sectionSpacing  // 24pt

// Corner radius
PopoverConstants.innerCornerRadius // 6pt
PopoverConstants.cornerRadius    // 10pt

// Animation
PopoverConstants.Animation.fast  // 0.15s
PopoverConstants.Animation.normal // 0.25s
PopoverConstants.Animation.slow  // 0.35s
```

### Reusable Popover Components

From `PopoverTemplate.swift`:

```swift
// Process row with PID, name, CPU%, memory, kill button
ProcessRow(
    pid: process.id,
    name: process.name,
    cpuUsage: process.cpuUsage,
    memoryUsage: process.memory,
    iconName: process.icon,
    onKill: { killProcess(process.id) }
)

// Icon + label + value display
IconLabelRow(
    icon: "cpu",
    label: "Usage",
    value: "45%",
    color: .blue
)

// Section header with optional icon
SectionHeader(title: "Connected Devices", icon: "bluetooth")

// Empty state placeholder
EmptyStateView(
    icon: "bluetooth.slash",
    title: "No devices connected"
)

// Key-value detail row
PopoverDetailRow(label: "SSID", value: "MyNetwork")
PopoverDetailGrid(pairs: ["RSSI": "-45 dBm", "Band": "5 GHz"])
```

---

## Troubleshooting

### Colors Look Wrong in Dark Mode

Check that you're using semantic system colors, not hardcoded values:
```swift
// Wrong - won't change in dark mode
.foregroundColor(Color.white)

// Right - automatically adapts
.foregroundColor(DesignTokens.Colors.textPrimary)
```

### Components Don't Align to Grid

Ensure you're using spacing tokens:
```swift
// Wrong - arbitrary value
.padding(15)

// Right - 8-point grid
.padding(DesignTokens.Spacing.sm)  // 16pt
.padding(DesignTokens.Spacing.md)  // 24pt
```

### Animations Feel Sluggish

Use the fast animation (0.15s) for UI interactions:
```swift
withAnimation(DesignTokens.Animation.fast) {
    property.toggle()
}
```

### Text Contrast Issues

Verify using high contrast helpers:
```swift
let textColor = DesignTokens.Colors.getTextPrimary(highContrast: isHighContrast)
```

And check WCAG AA compliance (minimum 4.5:1 ratio).

---

## Resources

- **Apple HIG**: macOS Design Themes and Semantics
- **WCAG**: Web Content Accessibility Guidelines
- **File**: `Tonic/Tonic/Design/DesignTokens.swift` - token definitions
- **File**: `Tonic/Tonic/Design/DesignComponents.swift` - component source
- **File**: `Tonic/Tonic/Design/DesignAnimations.swift` - animation source
