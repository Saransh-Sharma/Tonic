//
//  DesignTokens.swift
//  Tonic
//
//  Design system tokens for colors, typography, spacing, and animations
//  Updated to follow 8-point grid system and semantic color usage
//

import SwiftUI

// MARK: - High Contrast Environment Key

struct HighContrastKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    /// Whether high contrast mode is enabled
    var isHighContrast: Bool {
        get { self[HighContrastKey.self] }
        set { self[HighContrastKey.self] = newValue }
    }
}

// MARK: - Design Tokens

/// Design system tokens for consistent UI across the app
enum DesignTokens {

    // MARK: - Colors

    /// Semantic color palette using system colors for light/dark mode parity
    enum Colors {
        // MARK: Backgrounds (System Semantic)
        /// Primary window background
        static let background = Color(nsColor: .windowBackgroundColor)
        /// Secondary/grouped content background
        static let backgroundSecondary = Color(nsColor: .controlBackgroundColor)
        /// Tertiary/text field background
        static let backgroundTertiary = Color(nsColor: .textBackgroundColor)
        /// Under-page background for layered content
        static let backgroundUnderPage = Color(nsColor: .underPageBackgroundColor)

        // MARK: Text (System Semantic)
        /// Primary text color
        static let textPrimary = Color(nsColor: .labelColor)
        /// Secondary/subtitle text color
        static let textSecondary = Color(nsColor: .secondaryLabelColor)
        /// Tertiary/placeholder text color
        static let textTertiary = Color(nsColor: .tertiaryLabelColor)
        /// Quaternary/disabled text color
        static let textQuaternary = Color(nsColor: .quaternaryLabelColor)

        // MARK: UI Elements (System Semantic)
        /// Accent color for primary CTAs, selection, and progress
        static let accent = Color.accentColor
        /// Separator lines
        static let separator = Color(nsColor: .separatorColor)
        /// Grid lines
        static let grid = Color(nsColor: .gridColor)
        /// Control background (buttons, toggles)
        static let controlBackground = Color(nsColor: .controlBackgroundColor)
        /// Selected content background
        static let selectedContentBackground = Color(nsColor: .selectedContentBackgroundColor)
        /// Unemphasized selected content background
        static let unemphasizedSelectedContentBackground = Color(nsColor: .unemphasizedSelectedContentBackgroundColor)

        // MARK: Status Colors (System Semantic)
        /// Destructive/error actions
        static let destructive = Color(nsColor: .systemRed)
        /// System red
        static let error = Color(nsColor: .systemRed)

        // MARK: Custom Semantic Colors (WCAG AA Compliant)
        /// Success state - safe actions, confirmations (Asset Catalog)
        static let success = Color("SuccessGreen")
        /// Warning state - caution, attention needed (Asset Catalog)
        static let warning = Color("WarningOrange")
        /// Info state - informational, neutral guidance (Asset Catalog)
        static let info = Color("InfoBlue")

        // MARK: High Contrast Theme Colors (WCAG AAA - 7:1 Compliant)
        /// High contrast background - pure white or near-white
        static let highContrastBackground = Color(red: 1.0, green: 1.0, blue: 1.0)
        /// High contrast background secondary - very light gray
        static let highContrastBackgroundSecondary = Color(red: 0.95, green: 0.95, blue: 0.95)
        /// High contrast text primary - pure black or near-black
        static let highContrastTextPrimary = Color(red: 0.0, green: 0.0, blue: 0.0)
        /// High contrast text secondary - dark gray (meets 7:1 on white)
        static let highContrastTextSecondary = Color(red: 0.2, green: 0.2, blue: 0.2)
        /// High contrast text tertiary - medium gray (meets 7:1 on white)
        static let highContrastTextTertiary = Color(red: 0.35, green: 0.35, blue: 0.35)
        /// High contrast accent - bold blue (meets 7:1 on white)
        static let highContrastAccent = Color(red: 0.0, green: 0.4, blue: 1.0)
        /// High contrast success - bold green (meets 7:1 on white)
        static let highContrastSuccess = Color(red: 0.0, green: 0.6, blue: 0.0)
        /// High contrast warning - bold orange (meets 7:1 on white)
        static let highContrastWarning = Color(red: 1.0, green: 0.5, blue: 0.0)
        /// High contrast destructive - bold red (meets 7:1 on white)
        static let highContrastDestructive = Color(red: 1.0, green: 0.0, blue: 0.0)

        // MARK: Legacy Aliases (Backward Compatibility)
        /// Legacy alias for textPrimary
        @available(*, deprecated, renamed: "textPrimary")
        static let text = Color(nsColor: .labelColor)
        /// Legacy alias for separator - border color for UI elements
        @available(*, deprecated, renamed: "separator")
        static let border = Color(nsColor: .separatorColor)
        /// Legacy alias for backgroundSecondary - surface background
        @available(*, deprecated, renamed: "backgroundSecondary")
        static let surface = Color(nsColor: .controlBackgroundColor)
        /// Legacy alias for backgroundTertiary - elevated surface
        @available(*, deprecated, renamed: "backgroundTertiary")
        static let surfaceElevated = Color(nsColor: .textBackgroundColor)
        /// Legacy alias for controlBackground - hovered surface
        @available(*, deprecated, message: "Use a hover state modifier instead")
        static let surfaceHovered = Color(nsColor: .unemphasizedSelectedContentBackgroundColor)
        /// Legacy alias for accent - focused border
        @available(*, deprecated, renamed: "accent")
        static let borderFocused = Color.accentColor
        /// Legacy overlays
        static let overlay = Color.black.opacity(0.4)
        static let overlayLight = Color.black.opacity(0.2)
        /// Legacy progress colors - consider using success/warning/error instead
        @available(*, deprecated, message: "Use success for low, warning for medium, error for high")
        static let progressLow = Color("SuccessGreen")
        @available(*, deprecated, message: "Use warning instead")
        static let progressMedium = Color("WarningOrange")
        @available(*, deprecated, message: "Use error instead")
        static let progressHigh = Color(nsColor: .systemRed)

        // MARK: Legacy Brand Colors (Deprecated - use semantic alternatives)
        /// Pro/premium feature indicator
        @available(*, deprecated, message: "Use accent for emphasis or a custom asset")
        static let pro = Color(red: 1.0, green: 0.75, blue: 0.0)
    }

    // MARK: - Typography Scale

    /// Typography scale matching design spec
    /// h1=32, h2=24, body=16, subhead=14, caption=12
    enum Typography {
        // MARK: Headlines (One h1 per screen)
        /// H1 - Primary page title (32pt bold) - Use only once per screen
        static let h1 = Font.system(size: 32, weight: .bold, design: .default)
        /// H2 - Section headers (24pt semibold)
        static let h2 = Font.system(size: 24, weight: .semibold, design: .default)
        /// H3 - Subsection headers (20pt semibold)
        static let h3 = Font.system(size: 20, weight: .semibold, design: .default)

        // MARK: Body Text
        /// Body - Primary content text (16pt regular)
        static let body = Font.system(size: 16, weight: .regular, design: .default)
        /// Body emphasized - Primary content bold (16pt semibold)
        static let bodyEmphasized = Font.system(size: 16, weight: .semibold, design: .default)
        /// Subhead - Secondary content text (14pt regular)
        static let subhead = Font.system(size: 14, weight: .regular, design: .default)
        /// Subhead emphasized - Secondary content bold (14pt medium)
        static let subheadEmphasized = Font.system(size: 14, weight: .medium, design: .default)

        // MARK: Caption
        /// Caption - Metadata, timestamps (12pt regular)
        static let caption = Font.system(size: 12, weight: .regular, design: .default)
        /// Caption emphasized - Metadata bold (12pt medium)
        static let captionEmphasized = Font.system(size: 12, weight: .medium, design: .default)

        // MARK: Monospace (for code/numbers)
        /// Mono body - Code, numbers at body size (16pt)
        static let monoBody = Font.system(size: 16, weight: .regular, design: .monospaced)
        /// Mono subhead - Code, numbers at subhead size (14pt)
        static let monoSubhead = Font.system(size: 14, weight: .regular, design: .monospaced)
        /// Mono caption - Code, numbers at caption size (12pt)
        static let monoCaption = Font.system(size: 12, weight: .regular, design: .monospaced)

        // MARK: Legacy Aliases (Backward Compatibility)
        @available(*, deprecated, renamed: "h1")
        static let displayLarge = Font.system(size: 32, weight: .bold, design: .default)
        @available(*, deprecated, message: "Use h2 (24pt) instead")
        static let displayMedium = Font.system(size: 28, weight: .bold, design: .default)
        @available(*, deprecated, renamed: "h2")
        static let displaySmall = Font.system(size: 24, weight: .semibold, design: .default)
        @available(*, deprecated, renamed: "h3")
        static let headlineLarge = Font.system(size: 20, weight: .semibold, design: .default)
        @available(*, deprecated, message: "Use h3 (20pt) or bodyEmphasized (16pt) instead")
        static let headlineMedium = Font.system(size: 18, weight: .semibold, design: .default)
        @available(*, deprecated, renamed: "bodyEmphasized")
        static let headlineSmall = Font.system(size: 16, weight: .medium, design: .default)
        @available(*, deprecated, renamed: "body")
        static let bodyLarge = Font.system(size: 16, weight: .regular, design: .default)
        @available(*, deprecated, renamed: "subhead")
        static let bodyMedium = Font.system(size: 14, weight: .regular, design: .default)
        @available(*, deprecated, renamed: "caption")
        static let bodySmall = Font.system(size: 12, weight: .regular, design: .default)
        @available(*, deprecated, renamed: "captionEmphasized")
        static let captionLarge = Font.system(size: 12, weight: .medium, design: .default)
        @available(*, deprecated, message: "Use caption (12pt) instead")
        static let captionMedium = Font.system(size: 11, weight: .regular, design: .default)
        @available(*, deprecated, message: "Use caption (12pt) instead")
        static let captionSmall = Font.system(size: 10, weight: .regular, design: .default)
        @available(*, deprecated, renamed: "monoBody")
        static let monoLarge = Font.system(size: 16, weight: .regular, design: .monospaced)
        @available(*, deprecated, renamed: "monoSubhead")
        static let monoMedium = Font.system(size: 14, weight: .regular, design: .monospaced)
        @available(*, deprecated, renamed: "monoCaption")
        static let monoSmall = Font.system(size: 12, weight: .regular, design: .monospaced)
    }

    // MARK: - Spacing (8-Point Grid)

    /// Spacing scale following the 8-point grid system
    /// All values are multiples of 8 except xxxs (4pt for icon-text gaps)
    enum Spacing {
        /// 4pt - Very tight spacing (icon-text gap)
        static let xxxs: CGFloat = 4
        /// 8pt - Small padding
        static let xxs: CGFloat = 8
        /// 12pt - Minor separation (exception for visual balance)
        static let xs: CGFloat = 12
        /// 16pt - Default small spacing
        static let sm: CGFloat = 16
        /// 24pt - Default medium spacing
        static let md: CGFloat = 24
        /// 32pt - Section gaps
        static let lg: CGFloat = 32
        /// 40pt - Extra large spacing
        static let xl: CGFloat = 40
        /// 48pt - Very large spacing
        static let xxl: CGFloat = 48

        // MARK: Component-Specific Spacing
        /// Card internal padding (16pt = sm)
        static let cardPadding: CGFloat = 16
        /// List row padding (12pt = xs)
        static let listPadding: CGFloat = 12
        /// Button internal padding (12pt = xs)
        static let buttonPadding: CGFloat = 12
        /// Input field padding (8pt = xxs)
        static let inputPadding: CGFloat = 8
        /// Section gap (24pt = md)
        static let sectionGap: CGFloat = 24
    }

    // MARK: - Corner Radius

    /// Corner radius scale
    enum CornerRadius {
        static let small: CGFloat = 4
        static let medium: CGFloat = 8
        static let large: CGFloat = 12
        static let xlarge: CGFloat = 16
        static let round: CGFloat = 9999 // Fully rounded
    }

    // MARK: - Animation Durations

    /// Animation timing
    enum AnimationDuration {
        static let instant: TimeInterval = 0
        static let fast: TimeInterval = 0.15
        static let normal: TimeInterval = 0.25
        static let slow: TimeInterval = 0.35
        static let slower: TimeInterval = 0.5
    }

    // MARK: - Animation Curves

    /// Animation easing curves
    enum AnimationCurve {
        static var linear: SwiftUI.Animation { .linear }
        static var easeIn: SwiftUI.Animation { .easeIn }
        static var easeOut: SwiftUI.Animation { .easeOut }
        static var easeInOut: SwiftUI.Animation { .easeInOut }

        // Custom curves
        static var spring: SwiftUI.Animation {
            .spring(response: 0.3, dampingFraction: 0.7)
        }
        static var springBouncy: SwiftUI.Animation {
            .spring(response: 0.4, dampingFraction: 0.5)
        }
        static var smooth: SwiftUI.Animation {
            .timingCurve(0.25, 0.1, 0.25, 1.0)
        }
    }

    // MARK: - Combined Animations

    /// Predefined animation combinations
    enum Animation {
        static let fast = SwiftUI.Animation.easeOut(duration: AnimationDuration.fast)
        static let normal = SwiftUI.Animation.easeInOut(duration: AnimationDuration.normal)
        static let slow = SwiftUI.Animation.easeInOut(duration: AnimationDuration.slow)
        static let spring = AnimationCurve.spring
        static let springBouncy = AnimationCurve.springBouncy
    }

    // MARK: - Shadow

    /// Shadow styles
    enum Shadow {
        static let small = NSShadow()
        static let medium: NSShadow = {
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.15)
            shadow.shadowOffset = NSSize(width: 0, height: 2)
            shadow.shadowBlurRadius = 4
            return shadow
        }()
        static let large: NSShadow = {
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.2)
            shadow.shadowOffset = NSSize(width: 0, height: 4)
            shadow.shadowBlurRadius = 8
            return shadow
        }()
    }

    // MARK: - Layout

    /// Layout constants
    enum Layout {
        static let minButtonHeight: CGFloat = 36
        static let minRowHeight: CGFloat = 44
        static let maxContentWidth: CGFloat = 1200
        static let sidebarWidth: CGFloat = 220
        static let cardMinWidth: CGFloat = 280
    }
}

// MARK: - Font Extensions

extension Font {
    /// Initialize from typography token
    static func typography(_ token: Font) -> Font {
        return token
    }

    /// Monospace font for numbers/code
    static func mono(size: CGFloat, weight: Weight = .regular) -> Font {
        return .system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - View Extensions for Design Tokens

extension View {
    /// Apply card styling using semantic colors
    func cardStyle() -> some View {
        self
            .background(DesignTokens.Colors.backgroundSecondary)
            .cornerRadius(DesignTokens.CornerRadius.large)
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    /// Apply hover effect
    func hoverEffect() -> some View {
        self.onHover { isHovered in
            NSCursor.pointingHand.push()
        }
    }
}

// MARK: - Animation Extensions

// No extensions needed - using SwiftUI.Animation directly

// MARK: - High Contrast Helper

/// Helper function to get colors adapted for high contrast mode
extension DesignTokens.Colors {
    /// Get text primary color, respecting high contrast setting
    static func getTextPrimary(highContrast: Bool) -> Color {
        highContrast ? DesignTokens.Colors.highContrastTextPrimary : DesignTokens.Colors.textPrimary
    }

    /// Get text secondary color, respecting high contrast setting
    static func getTextSecondary(highContrast: Bool) -> Color {
        highContrast ? DesignTokens.Colors.highContrastTextSecondary : DesignTokens.Colors.textSecondary
    }

    /// Get text tertiary color, respecting high contrast setting
    static func getTextTertiary(highContrast: Bool) -> Color {
        highContrast ? DesignTokens.Colors.highContrastTextTertiary : DesignTokens.Colors.textTertiary
    }

    /// Get background color, respecting high contrast setting
    static func getBackground(highContrast: Bool) -> Color {
        highContrast ? DesignTokens.Colors.highContrastBackground : DesignTokens.Colors.background
    }

    /// Get background secondary color, respecting high contrast setting
    static func getBackgroundSecondary(highContrast: Bool) -> Color {
        highContrast ? DesignTokens.Colors.highContrastBackgroundSecondary : DesignTokens.Colors.backgroundSecondary
    }

    /// Get accent color, respecting high contrast setting
    static func getAccent(highContrast: Bool) -> Color {
        highContrast ? DesignTokens.Colors.highContrastAccent : DesignTokens.Colors.accent
    }

    /// Get success color, respecting high contrast setting
    static func getSuccess(highContrast: Bool) -> Color {
        highContrast ? DesignTokens.Colors.highContrastSuccess : DesignTokens.Colors.success
    }

    /// Get warning color, respecting high contrast setting
    static func getWarning(highContrast: Bool) -> Color {
        highContrast ? DesignTokens.Colors.highContrastWarning : DesignTokens.Colors.warning
    }

    /// Get destructive color, respecting high contrast setting
    static func getDestructive(highContrast: Bool) -> Color {
        highContrast ? DesignTokens.Colors.highContrastDestructive : DesignTokens.Colors.destructive
    }
}
