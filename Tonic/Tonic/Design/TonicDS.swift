//
//  TonicDS.swift
//  Tonic
//
//  Editorial "Command Center" design system — the single source of truth for the
//  redesigned UI layer (see TonicDesign.md). This is the only token namespace for
//  editorial palette, carved type, spacing/radius grid, data color, and restrained motion.
//
//  One rule governs everything: THE DATA IS THE MEDIA. The shell stays austere; all
//  color and energy come from the readout. Status color is data-only; brand coral is
//  brand-only. Never put a status color on chrome, never put coral/link-blue on data.
//

import SwiftUI
import AppKit

// MARK: - Dynamic color helper

private struct TonicDSRGB {
    let r, g, b: Double

    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        switch s.count {
        case 3:
            r = Double((v >> 8) * 17) / 255
            g = Double((v >> 4 & 0xF) * 17) / 255
            b = Double((v & 0xF) * 17) / 255
        case 6:
            r = Double(v >> 16) / 255
            g = Double(v >> 8 & 0xFF) / 255
            b = Double(v & 0xFF) / 255
        default:
            r = 0; g = 0; b = 0
        }
    }

    func nsColor(alpha: Double) -> NSColor {
        NSColor(calibratedRed: r, green: g, blue: b, alpha: min(max(alpha, 0), 1))
    }
}

extension Color {
    /// Appearance-aware color built from light/dark hex strings. Resolves live as the
    /// system (or app-forced) appearance changes.
    static func tonic(_ lightHex: String, dark darkHex: String,
                      lightAlpha: Double = 1, darkAlpha: Double = 1) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let match = appearance.bestMatch(from: [.darkAqua, .aqua])
            let rgb = match == .darkAqua ? TonicDSRGB(hex: darkHex) : TonicDSRGB(hex: lightHex)
            return rgb.nsColor(alpha: match == .darkAqua ? darkAlpha : lightAlpha)
        })
    }

    /// Constant color (same in both appearances) — for bands and the console.
    static func tonicConstant(_ hex: String, alpha: Double = 1) -> Color {
        Color(nsColor: TonicDSRGB(hex: hex).nsColor(alpha: alpha))
    }
}

// MARK: - TonicDS

/// Editorial design-system namespace. See TonicDesign.md for the full language.
enum TonicDS {

    // MARK: Colors
    //
    // Brand identity (ink/canvas anchors, deep-green & navy bands, soft-stone warmth,
    // reserved accents) is constant across light/dark; only the neutral stack inverts.

    enum Colors {
        // -- Anchors & surfaces ------------------------------------------------
        /// Page background. White (light) / obsidian (dark).
        static let canvas = Color.tonic("ffffff", dark: "0a0a0f")
        /// Warm off-white page field / elevated obsidian.
        static let canvasSoft = Color.tonic("f6f4ef", dark: "121318")
        /// Elevated surface for data cards, lists, forms.
        static let surface = Color.tonic("ffffff", dark: "121318")
        /// Warm neutral card — scan categories, proof blocks, quiet summaries.
        static let softStone = Color.tonic("eeece7", dark: "16161c")
        /// Occasional section washes behind stacked dark panels.
        static let paleGreen = Color.tonic("edfce9", dark: "0e1a14")
        static let paleBlue = Color.tonic("f1f5ff", dark: "0d1422")

        /// Brand anchor — primary CTA fill, high-contrast text on light.
        static let ink = Color.tonicConstant("17171c")
        /// Deepest obsidian base — alert banner / dark-mode page floor.
        static let inkPure = Color.tonicConstant("0a0a0f")
        /// The signature monitoring-console surface. CONSTANT in both appearances.
        static let console = Color.tonicConstant("17171c")
        static let consoleElevated = Color.tonicConstant("1d1d24")

        // -- Brand bands (constant) -------------------------------------------
        /// Healthy / cleanup / optimized module band. Tonic's primary brand band.
        static let deepGreen = Color.tonicConstant("003c33")
        static let deepGreenSoft = Color.tonicConstant("0b1f1b")
        /// Protection / security / permissions module band.
        static let darkNavy = Color.tonicConstant("071829")
        static let darkNavySoft = Color.tonicConstant("0c1a2b")

        // -- Text --------------------------------------------------------------
        static let textPrimary = Color.tonic("212121", dark: "f4f3ef")
        static let textMuted = Color.tonic("75758a", dark: "93939f")
        /// Foreground on dark/band/console surfaces.
        static let onDark = Color.tonicConstant("ffffff")
        static let onDarkMuted = Color.tonicConstant("ffffff", alpha: 0.62)
        /// Foreground on light/coral surfaces.
        static let onLight = Color.tonicConstant("17171c")

        // -- Rules & borders ---------------------------------------------------
        static let hairline = Color.tonic("d9d9dd", dark: "2a2a32")
        static let borderLight = Color.tonic("e5e7eb", dark: "23232b")
        static let cardBorder = Color.tonic("f2f2f2", dark: "23232b")
        /// Hairline on a dark/console surface.
        static let hairlineOnDark = Color.tonicConstant("ffffff", alpha: 0.10)
        /// Hairline on a glass surface — ink-based in light, white in dark, so the
        /// rim reads against whatever the desktop shows through the material.
        static let glassStroke = Color.tonic("17171c", dark: "ffffff",
                                             lightAlpha: 0.10, darkAlpha: 0.14)

        // -- Brand accents (RESERVED — editorial/brand only, NEVER on data) ----
        /// Tonic's mineral-green brand accent. It is reserved for primary actions,
        /// focus, and identity; measured machine state continues to use status colors.
        static let brandAccent = Color.tonic("176b58", dark: "5cc7a7")
        static let brandAccentSoft = Color.tonic("dcefe8", dark: "14352c")
        // Compatibility aliases while legacy consumers migrate to the semantic names.
        static let accentCoral = brandAccent
        static let accentCoralSoft = brandAccentSoft
        /// Inline navigation links, pagination, "learn more". Never on data.
        static let linkBlue = Color.tonic("1863dc", dark: "5b93ff")
        /// Keyboard focus ring.
        static let focus = Color.tonicConstant("4c6ee6")

        // -- Status scale (DATA ONLY — gauges, charts, arcs, chips, value text) -
        // Never a brand color, surface fill, or chrome. Brand never substitutes.
        // Spec hex on light canvas; lifted on dark/console (which force the dark
        // scheme) so small mono readouts on the near-black console meet WCAG AA.
        static let statusSuccess = Color.tonicConstant("1f9d57")  // 0–50%   healthy
        static let statusWarning = Color.tonicConstant("e0a32c")  // 50–75%  elevated
        static let statusCaution = Color.tonicConstant("e07b39")  // 75–90%  high
        static let statusCritical = Color.tonic("d14b4b", dark: "e05252") // 90–100% critical
        static let statusInfo = Color.tonic("3a78d6", dark: "5b93ff")     // neutral (charging)

        // -- Categorical data series (DATA ONLY) -------------------------------
        // For multi-series readouts (CPU system/user/idle, memory breakdown, disk
        // read/write, E/P-core clusters) where the value is a *category*, not a single
        // utilization. Derived from the status hues so the data layer stays coherent.
        // Distinct from the green→red status scale and from reserved brand coral —
        // never used as chrome, never substituting for a status reading.
        /// Disk/network read & download.
        static let seriesRead = statusInfo
        /// Disk/network write & upload.
        static let seriesWrite = statusCaution
        /// Efficiency-core cluster.
        static let seriesEcore = Color.tonicConstant("5f9ea8")
        /// Performance-core cluster.
        static let seriesPcore = Color.tonicConstant("5b6cc4")
        /// Memory — active/app footprint.
        static let seriesAppMem = statusInfo
        /// Memory — wired (resident kernel/system).
        static let seriesWired = statusSuccess
        /// Memory — compressed.
        static let seriesCompressed = statusCaution
        /// CPU — system/kernel time.
        static let seriesSystem = statusCaution
        /// CPU — user time.
        static let seriesUser = statusInfo
        /// CPU — idle (quiet neutral).
        static let seriesIdle = Color.tonic("d9d9dd", dark: "2a2a32")

        // -- Quiet interaction fills (appearance-aware) ------------------------
        /// Row hover / unemphasized selection tint.
        static func rowHover(_ opacity: Double = 0.05) -> Color {
            Color.tonic("000000", dark: "ffffff", lightAlpha: opacity, darkAlpha: opacity)
        }

        /// Scrim behind palettes / modal overlays. The one sanctioned dimming fill.
        static let overlayDim = Color.tonicConstant("000000", alpha: 0.30)
    }

    // MARK: Emphasis (opacity scale for de-emphasized ink)

    enum Emphasis {
        /// Baseline-aligned unit next to a metric value.
        static let unit: Double = 0.70
        /// Disabled control fill / content.
        static let disabled: Double = 0.35
    }

    // MARK: Status resolution (single threshold authority)
    //
    // Mirrors ColorZoneConfiguration.standardUtilization thresholds (0.50 / 0.75 / 0.90)
    // so gauges, charts, and chips all resolve color the same way.

    /// A machine-state level: the status color plus the word that voices it.
    /// The word is what VoiceOver reads and what status chips can print — color
    /// alone is never the only carrier of meaning.
    enum StatusLevel {
        case success, warning, caution, critical, info

        var color: Color {
            switch self {
            case .success: return Colors.statusSuccess
            case .warning: return Colors.statusWarning
            case .caution: return Colors.statusCaution
            case .critical: return Colors.statusCritical
            case .info: return Colors.statusInfo
            }
        }

        /// Human word for the level ("Healthy", "Elevated", …).
        var word: String {
            switch self {
            case .success: return "Healthy"
            case .warning: return "Elevated"
            case .caution: return "High"
            case .critical: return "Critical"
            case .info: return "Info"
            }
        }
    }

    /// Status level for a 0...1 utilization fraction.
    static func statusLevel(forFraction value: Double) -> StatusLevel {
        switch value {
        case ..<0.50: return .success
        case ..<0.75: return .warning
        case ..<0.90: return .caution
        default:       return .critical
        }
    }

    /// Status level for a temperature in °C (typical SoC/ambient envelope).
    static func statusLevel(forTempC celsius: Double) -> StatusLevel {
        switch celsius {
        case ..<60:  return .success
        case ..<75:  return .warning
        case ..<90:  return .caution
        default:      return .critical
        }
    }

    /// Status level for a battery level 0...1 (charging is neutral/info).
    static func statusLevel(forBattery level: Double, isCharging: Bool) -> StatusLevel {
        if isCharging { return .info }
        switch level {
        case ..<0.10: return .critical
        case ..<0.20: return .caution
        case ..<0.40: return .warning
        default:       return .success
        }
    }

    /// Status color for a 0...1 utilization fraction.
    static func status(forFraction value: Double) -> Color {
        statusLevel(forFraction: value).color
    }

    /// Status color for a temperature in °C (typical SoC/ambient envelope).
    static func status(forTempC celsius: Double) -> Color {
        statusLevel(forTempC: celsius).color
    }

    /// Status color for a battery level 0...1 (charging is neutral/info).
    static func status(forBattery level: Double, isCharging: Bool) -> Color {
        statusLevel(forBattery: level, isCharging: isCharging).color
    }

    // MARK: Chart / data color

    enum Chart {
        static func utilization(_ percent: Double) -> Color {
            TonicDS.status(forFraction: percent / 100)
        }

        static func fraction(_ value: Double) -> Color {
            TonicDS.status(forFraction: value)
        }

        static func temperature(_ celsius: Double) -> Color {
            TonicDS.status(forTempC: celsius)
        }

        static func battery(level percent: Double, isCharging: Bool = false) -> Color {
            TonicDS.status(forBattery: percent / 100, isCharging: isCharging)
        }

        static let read = Colors.seriesRead
        static let write = Colors.seriesWrite
        static let download = Colors.seriesRead
        static let upload = Colors.seriesWrite
        static let memoryApp = Colors.seriesAppMem
        static let memoryWired = Colors.seriesWired
        static let memoryCompressed = Colors.seriesCompressed
        static let cpuUser = Colors.seriesUser
        static let cpuSystem = Colors.seriesSystem
        static let cpuIdle = Colors.seriesIdle
        static let efficiencyCore = Colors.seriesEcore
        static let performanceCore = Colors.seriesPcore
        static let neutral = Colors.textMuted

        // -- Chart area-fill opacity (data layer only) -------------------------
        /// Top stop of a sparkline/area gradient.
        static let areaOpacity: Double = 0.18
        /// Bottom stop of a sparkline/area gradient (near-transparent).
        static let areaSoftOpacity: Double = 0.04

        // -- Categorical map palette (DATA ONLY) --------------------------------
        // Muted editorial hues for many-category visualizations (disk map
        // segments). Deliberately distinct from the status scale — a segment's
        // color identifies *which* directory, never how healthy it is.
        static let categorical: [Color] = [
            Color.tonicConstant("4f7f8c"),  // slate teal
            Color.tonicConstant("5b6cc4"),  // indigo
            Color.tonicConstant("8c6d4f"),  // ochre
            Color.tonicConstant("7d5b8c"),  // plum
            Color.tonicConstant("4f8c5f"),  // moss
            Color.tonicConstant("8c4f5e"),  // rosewood
            Color.tonicConstant("5f8c86"),  // sea
            Color.tonicConstant("8c7a4f"),  // brass
            Color.tonicConstant("64648c"),  // dusk
            Color.tonicConstant("6d8c4f")   // olive
        ]
    }

    // MARK: Bands

    enum Band { case green, navy }

    static func bandFill(_ kind: Band) -> Color {
        kind == .green ? Colors.deepGreen : Colors.darkNavy
    }

    // MARK: Spacing (8-pt grid + 64pt section interval)

    enum Space {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 40
        static let xxxl: CGFloat = 48
        /// Dramatic breathing room between status, proof, and action.
        static let section: CGFloat = 64
    }

    // MARK: Radius

    enum Radius {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12       // console / list panels
        static let lg: CGFloat = 16       // module bands / settings panels
        static let card: CGFloat = 22     // signature data-card radius
        static let pill: CGFloat = 32
        static let full: CGFloat = 9999
    }

    // MARK: Layout

    enum Layout {
        static let maxContentWidth: CGFloat = 1200
        static let sidebarWidth: CGFloat = 220
        static let minControlTarget: CGFloat = 36
        static let minRowHeight: CGFloat = 44
        /// Text inputs (search fields, small form fields).
        static let inputHeight: CGFloat = 32
        /// The 6pt status dot used by chips and console rows.
        static let statusDotSize: CGFloat = 6

        enum MenuBar {
            static let width: CGFloat = 280
            static let maxHeight: CGFloat = 420
            static let compactHeight: CGFloat = 22
            static let rowHeight: CGFloat = 28
            static let sectionHeaderHeight: CGFloat = 24
            static let chartHeight: CGFloat = 58
            static let compactChartWidth: CGFloat = 36
            static let compactChartHeight: CGFloat = 14
        }

        // -- Responsive breakpoints (detail-pane width) ------------------------
        /// Below this the pane is compact: tighter gutters, single-column bento,
        /// list rows stack metadata below the title.
        static let compactMaxWidth: CGFloat = 900
        /// At/above this the pane is wide: full gutters, centered content.
        static let wideMinWidth: CGFloat = 1200

        enum Breakpoint { case compact, regular, wide }

        static func breakpoint(forWidth width: CGFloat) -> Breakpoint {
            if width < compactMaxWidth { return .compact }
            if width >= wideMinWidth { return .wide }
            return .regular
        }

        static func isCompact(_ width: CGFloat) -> Bool { width < compactMaxWidth }

        /// Adaptive screen gutter: tightens on compact windows so content isn't cramped.
        static func screenHPadding(forWidth width: CGFloat) -> CGFloat {
            isCompact(width) ? Space.lg : Space.xxxl   // 24 ↔ 48
        }
    }

    // MARK: Motion

    enum Motion {
        static let instant: Double = 0.10
        static let feedback: Double = 0.14
        static let transition: Double = 0.21
        static let layout: Double = 0.27
        static let proof: Double = 0.39

        static let fast = feedback
        static let normal = transition
        static let slow = proof

        static var appear: Animation { .easeOut(duration: transition) }
        static var press: Animation { .easeOut(duration: feedback) }
        static var numeric: Animation { .easeOut(duration: feedback) }
        static var present: Animation { .easeOut(duration: transition) }
        static var settle: Animation { .easeOut(duration: layout) }
        /// Per-index delay for staggered list/bento reveals.
        static let stagger: Double = 0.05

        static func respectingReduceMotion(_ animation: Animation, reduceMotion: Bool) -> Animation? {
            reduceMotion ? nil : animation
        }

        static func duration(_ duration: Double, reduceMotion: Bool) -> Double {
            reduceMotion ? 0 : duration
        }
    }

    // MARK: Elevation

    enum Elevation {
        /// The single permitted soft lift for a data card / popover. Never stacked,
        /// never colored, never on bands or the console.
        static func cardLift(_ scheme: ColorScheme) -> (color: Color, radius: CGFloat, y: CGFloat) {
            scheme == .dark
                ? (Color.black.opacity(0.30), 14, 6)
                : (Color.black.opacity(0.07), 12, 4)
        }
    }

    // MARK: Glass (Liquid Tonic material model — see TonicDesign.md §Materials)
    //
    // The Z-model: Z0 desktop light (behind-window blur + canvas wash) → Z1 surfaces
    // (Material + color wash) → Z2 overlays (thicker material + scrim) → Z3 chrome
    // (true Liquid Glass, ≤3 elements per window). Glass is chrome, never meaning:
    // status color is never a glass tint, and every layer degrades to the flat
    // editorial fill when transparency is reduced (`TonicGlassPolicy`).

    enum Glass {
        /// Geometry and interaction timing for the two-surface application shell.
        /// The collapsed rail ends 20pt before the slab; expansion grows rightward
        /// over the slab without moving the host window.
        enum Shell {
            static let outerInset: CGFloat = 8
            static let slabLeadingInset: CGFloat = 88
            static let slabCornerRadius: CGFloat = 28

            static let railLeadingInset: CGFloat = 12
            static let railCollapsedWidth: CGFloat = 56
            static let railExpandedWidth: CGFloat = 208
            static let railToSlabGap: CGFloat = 20
            static let railCornerRadius: CGFloat = 28
            static let railHoverCorridor: CGFloat = 10
            static let pinnedContentInset: CGFloat = 148

            static let hoverOpenDelay: Double = 0.12
            static let hoverCloseDelay: Double = 0.28
            static let trafficLightLeadingInset: CGFloat = 16
            static let trafficLightContentClearance: CGFloat = 78
        }

        /// Semantic surface layer. Components declare a layer; `.tonicSurface(_:in:)`
        /// resolves it to glass or the exact legacy flat fill.
        enum Layer {
            /// Z3 — floating rail, top bar, docks, toasts. The only true
            /// `glassEffect` tier; keep at most ~3 visible per window.
            case chrome
            /// Z2 — sheets, command palette, modal panels.
            case overlay
            /// Z1 — data cards, settings panels, list containers, fields.
            case surface
            /// Z1-dark — the monitoring console family. Smoke wash never drops
            /// below `smokedWash`: status readouts need a near-black field.
            case smoked
            /// Z1-brand — deep-green / navy module bands as colored glass.
            case band(TonicDS.Band)
        }

        // -- Wash opacities (color over material) -------------------------------
        /// Z1 surface wash over thin material.
        static let surfaceWash: Double = 0.55
        /// Z1 smoke wash over ultra-thin material. 0.60 is the non-negotiable
        /// floor — status colors at 11pt mono require a near-black backdrop.
        static let smokedWash: Double = 0.65
        /// Z1 band tint — bands are brand identity and must read as colored glass.
        static let bandWash: Double = 0.85
        /// Z2 overlay wash over thick material.
        static let overlayWash: Double = 0.70

        /// Z0 canvas wash over the behind-window blur, per intensity + scheme.
        /// Light mode runs milkier so content never sits on a glaring backdrop.
        static func canvasWash(_ intensity: GlassIntensity, scheme: ColorScheme) -> Double {
            switch intensity {
            case .regular: return scheme == .dark ? 0.22 : 0.42
            case .subtle: return scheme == .dark ? 0.55 : 0.68
            case .off: return 1.0
            }
        }
    }
}

// MARK: - Typography

extension TonicDS {
    /// Editorial type roles. Display = SF Pro Display fallback (TonicDisplay not yet
    /// bundled, per spec); body = SF Pro Text; technical = SF Mono. Tracking + line
    /// height are applied via `.tonicType(_:)` because SwiftUI `Font` can't carry them.
    enum TypeRole {
        case heroDisplay, sectionDisplay, cardHeading, featureHeading
        case bodyLarge, body, button, caption
        case monoLabel, metric, metricSmall, micro

        var size: CGFloat {
            switch self {
            case .heroDisplay: return 40
            case .sectionDisplay: return 28
            case .cardHeading: return 17
            case .featureHeading: return 17
            case .bodyLarge: return 16
            case .body: return 14
            case .button: return 13
            case .caption: return 12
            case .monoLabel: return 11
            case .metric: return 28
            case .metricSmall: return 20   // compact console/popover header readout
            case .micro: return 11
            }
        }

        var weight: Font.Weight {
            switch self {
            case .heroDisplay, .sectionDisplay, .cardHeading: return .medium   // 500
            case .featureHeading, .button: return .semibold                    // 600
            case .monoLabel, .metric, .metricSmall: return .medium             // 500
            default: return .regular                                           // 400
            }
        }

        var design: Font.Design {
            switch self {
            case .monoLabel, .metric, .metricSmall: return .monospaced
            default: return .default
            }
        }

        /// Tracking in points.
        var tracking: CGFloat {
            switch self {
            case .heroDisplay: return -0.70
            case .sectionDisplay: return -0.35
            case .cardHeading: return -0.10
            case .monoLabel: return 0.50
            default: return 0
            }
        }

        var lineHeightMultiple: CGFloat {
            switch self {
            case .heroDisplay: return 1.02
            case .sectionDisplay: return 1.05
            case .cardHeading: return 1.15
            case .featureHeading: return 1.25
            case .bodyLarge: return 1.45
            case .body: return 1.50
            case .button: return 1.20
            case .caption: return 1.40
            case .monoLabel: return 1.30
            case .metric, .metricSmall: return 1.00
            case .micro: return 1.35
            }
        }

        var font: Font {
            .system(size: size, weight: weight, design: design)
        }

        /// Extra inter-line spacing approximating the documented line height.
        var lineSpacing: CGFloat {
            max(0, size * (lineHeightMultiple - 1))
        }
    }
}

extension View {
    /// Apply an editorial type role: font + tracking + line spacing in one call.
    /// Measured values should additionally use `.monospacedDigit()`.
    func tonicType(_ role: TonicDS.TypeRole) -> some View {
        self.font(role.font)
            .tracking(role.tracking)
            .lineSpacing(role.lineSpacing)
    }

    /// Accessibility-scaled variant for compact custom controls that cannot use
    /// platform text styles directly.
    func tonicScaledType(_ role: TonicDS.TypeRole, size: CGFloat) -> some View {
        self.font(.system(size: size, weight: role.weight, design: role.design))
            .tracking(role.tracking)
            .lineSpacing(role.lineSpacing)
    }
}

// MARK: - Reduce-motion aware helpers

extension View {
    /// Fade + rise on appear, respecting Reduce Motion (collapses to opacity).
    @ViewBuilder
    func tonicAppear(_ isVisible: Bool, index: Int = 0, reduceMotion: Bool) -> some View {
        if reduceMotion {
            self.opacity(isVisible ? 1 : 0)
        } else {
            self
                .opacity(isVisible ? 1 : 0)
                .offset(y: isVisible ? 0 : 8)
                .animation(TonicDS.Motion.appear.delay(Double(index) * TonicDS.Motion.stagger),
                           value: isVisible)
        }
    }
}
