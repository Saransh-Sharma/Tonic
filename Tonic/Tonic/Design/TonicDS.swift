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

        // -- Brand accents (RESERVED — editorial/brand only, NEVER on data) ----
        /// The one branded interactive accent — category-filter chips, brand marks.
        static let accentCoral = Color.tonicConstant("ff7759")
        static let accentCoralSoft = Color.tonicConstant("ffad9b")
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
    }

    // MARK: Status resolution (single threshold authority)
    //
    // Mirrors ColorZoneConfiguration.standardUtilization thresholds (0.50 / 0.75 / 0.90)
    // so gauges, charts, and chips all resolve color the same way.

    /// Status color for a 0...1 utilization fraction.
    static func status(forFraction value: Double) -> Color {
        switch value {
        case ..<0.50: return Colors.statusSuccess
        case ..<0.75: return Colors.statusWarning
        case ..<0.90: return Colors.statusCaution
        default:       return Colors.statusCritical
        }
    }

    /// Status color for a temperature in °C (typical SoC/ambient envelope).
    static func status(forTempC celsius: Double) -> Color {
        switch celsius {
        case ..<60:  return Colors.statusSuccess
        case ..<75:  return Colors.statusWarning
        case ..<90:  return Colors.statusCaution
        default:      return Colors.statusCritical
        }
    }

    /// Status color for a battery level 0...1 (charging is neutral/info).
    static func status(forBattery level: Double, isCharging: Bool) -> Color {
        if isCharging { return Colors.statusInfo }
        switch level {
        case ..<0.10: return Colors.statusCritical
        case ..<0.20: return Colors.statusCaution
        case ..<0.40: return Colors.statusWarning
        default:       return Colors.statusSuccess
        }
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
        static let fast: Double = 0.15
        static let normal: Double = 0.25
        static let slow: Double = 0.35

        static var appear: Animation { .easeOut(duration: normal) }
        static var press: Animation { .easeOut(duration: fast) }
        static var numeric: Animation { .easeInOut(duration: fast) }
        static var present: Animation { .easeInOut(duration: normal) }
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
}

// MARK: - Typography

extension TonicDS {
    /// Editorial type roles. Display = SF Pro Display fallback (TonicDisplay not yet
    /// bundled, per spec); body = SF Pro Text; technical = SF Mono. Tracking + line
    /// height are applied via `.tonicType(_:)` because SwiftUI `Font` can't carry them.
    enum TypeRole {
        case heroDisplay, sectionDisplay, cardHeading, featureHeading
        case bodyLarge, body, button, caption
        case monoLabel, metric, micro

        var size: CGFloat {
            switch self {
            case .heroDisplay: return 64
            case .sectionDisplay: return 44
            case .cardHeading: return 28
            case .featureHeading: return 20
            case .bodyLarge: return 16
            case .body: return 14
            case .button: return 13
            case .caption: return 12
            case .monoLabel: return 11
            case .metric: return 28
            case .micro: return 11
            }
        }

        var weight: Font.Weight {
            switch self {
            case .heroDisplay, .sectionDisplay, .cardHeading: return .medium   // 500
            case .featureHeading, .button: return .semibold                    // 600
            case .monoLabel, .metric: return .medium                           // 500
            default: return .regular                                           // 400
            }
        }

        var design: Font.Design {
            switch self {
            case .monoLabel, .metric: return .monospaced
            default: return .default
            }
        }

        /// Tracking in points.
        var tracking: CGFloat {
            switch self {
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
            case .metric: return 1.00
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
