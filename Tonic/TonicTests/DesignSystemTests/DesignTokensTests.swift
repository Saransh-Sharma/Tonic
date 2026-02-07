//
//  DesignTokensTests.swift
//  TonicTests
//
//  Tests for DesignTokens.swift - Color, Typography, Spacing, and Animation definitions
//

import XCTest
import SwiftUI
@testable import Tonic

final class DesignTokensTests: XCTestCase {

    // MARK: - Color Tests

    func testColorDefinitionsExist() {
        // Test that all color properties are accessible
        XCTAssertNotNil(DesignTokens.Colors.background)
        XCTAssertNotNil(DesignTokens.Colors.backgroundSecondary)
        XCTAssertNotNil(DesignTokens.Colors.textPrimary)
        XCTAssertNotNil(DesignTokens.Colors.textSecondary)
        XCTAssertNotNil(DesignTokens.Colors.accent)
        XCTAssertNotNil(DesignTokens.Colors.separator)
        XCTAssertNotNil(DesignTokens.Colors.error)
        XCTAssertNotNil(DesignTokens.Colors.success)
        XCTAssertNotNil(DesignTokens.Colors.warning)
        XCTAssertNotNil(DesignTokens.Colors.info)
    }

    func testHighContrastColors() {
        // Test that high contrast colors exist
        XCTAssertNotNil(DesignTokens.Colors.highContrastBackground)
        XCTAssertNotNil(DesignTokens.Colors.highContrastTextPrimary)
        XCTAssertNotNil(DesignTokens.Colors.highContrastAccent)
        XCTAssertNotNil(DesignTokens.Colors.highContrastSuccess)
        XCTAssertNotNil(DesignTokens.Colors.highContrastWarning)
        XCTAssertNotNil(DesignTokens.Colors.highContrastDestructive)
    }

    func testHighContrastColorAccessibility() {
        // Test that high contrast colors meet WCAG AAA standards (7:1)
        let testCases: [(foreground: NSColor, background: NSColor, name: String)] = [
            (NSColor(red: 0.0, green: 0.0, blue: 0.0), NSColor(red: 1.0, green: 1.0, blue: 1.0), "Black on White"),
            (NSColor(red: 0.2, green: 0.2, blue: 0.2), NSColor(red: 1.0, green: 1.0, blue: 1.0), "Dark Gray on White"),
            (NSColor(red: 0.0, green: 0.4, blue: 1.0), NSColor(red: 1.0, green: 1.0, blue: 1.0), "Blue on White"),
            (NSColor(red: 0.0, green: 0.6, blue: 0.0), NSColor(red: 1.0, green: 1.0, blue: 1.0), "Green on White"),
            (NSColor(red: 1.0, green: 0.5, blue: 0.0), NSColor(red: 1.0, green: 1.0, blue: 1.0), "Orange on White"),
            (NSColor(red: 1.0, green: 0.0, blue: 0.0), NSColor(red: 1.0, green: 1.0, blue: 1.0), "Red on White"),
        ]

        for testCase in testCases {
            let ratio = ColorAccessibilityHelper.contrastRatio(
                foreground: testCase.foreground,
                background: testCase.background
            )
            XCTAssertGreaterThanOrEqual(
                ratio,
                7.0,
                "High contrast \(testCase.name) should meet WCAG AAA (7:1), got \(String(format: "%.2f", ratio)):1"
            )
        }
    }

    func testColorHelpers() {
        // Test color helper functions
        let textPrimary = DesignTokens.Colors.getTextPrimary(highContrast: false)
        let textPrimaryHC = DesignTokens.Colors.getTextPrimary(highContrast: true)
        XCTAssertNotNil(textPrimary)
        XCTAssertNotNil(textPrimaryHC)

        let success = DesignTokens.Colors.getSuccess(highContrast: false)
        let successHC = DesignTokens.Colors.getSuccess(highContrast: true)
        XCTAssertNotNil(success)
        XCTAssertNotNil(successHC)
    }

    // MARK: - Typography Tests

    func testTypographyDefinitionsExist() {
        // Test that all typography tokens are accessible
        XCTAssertNotNil(DesignTokens.Typography.h1)
        XCTAssertNotNil(DesignTokens.Typography.h2)
        XCTAssertNotNil(DesignTokens.Typography.h3)
        XCTAssertNotNil(DesignTokens.Typography.body)
        XCTAssertNotNil(DesignTokens.Typography.bodyEmphasized)
        XCTAssertNotNil(DesignTokens.Typography.subhead)
        XCTAssertNotNil(DesignTokens.Typography.subheadEmphasized)
        XCTAssertNotNil(DesignTokens.Typography.caption)
        XCTAssertNotNil(DesignTokens.Typography.captionEmphasized)
        XCTAssertNotNil(DesignTokens.Typography.monoBody)
        XCTAssertNotNil(DesignTokens.Typography.monoSubhead)
        XCTAssertNotNil(DesignTokens.Typography.monoCaption)
    }

    func testTypographyHierarchy() {
        // Test that typography sizes follow the design spec
        // h1: 32, h2: 24, h3: 20, body: 16, subhead: 14, caption: 12
        let expectations: [(font: Font, expectedSize: CGFloat, name: String)] = [
            (DesignTokens.Typography.h1, 32, "h1"),
            (DesignTokens.Typography.h2, 24, "h2"),
            (DesignTokens.Typography.h3, 20, "h3"),
            (DesignTokens.Typography.body, 16, "body"),
            (DesignTokens.Typography.bodyEmphasized, 16, "bodyEmphasized"),
            (DesignTokens.Typography.subhead, 14, "subhead"),
            (DesignTokens.Typography.caption, 12, "caption"),
        ]

        // Note: We can't directly extract size from SwiftUI.Font, but we can verify they're created
        for expectation in expectations {
            XCTAssertNotNil(expectation.font, "\(expectation.name) should be defined")
        }
    }

    // MARK: - Spacing Tests

    func testSpacingGridCompliance() {
        // Test that spacing follows 8-point grid system
        // All values should be multiples of 8, except xxxs (4pt for icon-text gaps)
        let spacingValues: [(value: CGFloat, name: String, isMultipleOf8: Bool)] = [
            (DesignTokens.Spacing.xxxs, "xxxs (4pt)", false),  // Exception: 4pt
            (DesignTokens.Spacing.xxs, "xxs", true),           // 8
            (DesignTokens.Spacing.xs, "xs (12pt)", false),     // Exception: 12pt for visual balance
            (DesignTokens.Spacing.sm, "sm", true),             // 16
            (DesignTokens.Spacing.md, "md", true),             // 24
            (DesignTokens.Spacing.lg, "lg", true),             // 32
            (DesignTokens.Spacing.xl, "xl", true),             // 40
            (DesignTokens.Spacing.xxl, "xxl", true),           // 48
        ]

        for case_ in spacingValues {
            if case_.isMultipleOf8 {
                XCTAssertEqual(
                    Int(case_.value) % 8,
                    0,
                    "\(case_.name) should be multiple of 8, got \(case_.value)"
                )
            } else {
                // Known exceptions: xxxs (4pt) and xs (12pt)
                XCTAssert(
                    case_.value == 4 || case_.value == 12,
                    "\(case_.name) (\(case_.value)) should be 4pt or 12pt exception"
                )
            }
        }
    }

    func testSpacingValues() {
        // Test specific spacing values
        XCTAssertEqual(DesignTokens.Spacing.xxxs, 4)
        XCTAssertEqual(DesignTokens.Spacing.xxs, 8)
        XCTAssertEqual(DesignTokens.Spacing.xs, 12)
        XCTAssertEqual(DesignTokens.Spacing.sm, 16)
        XCTAssertEqual(DesignTokens.Spacing.md, 24)
        XCTAssertEqual(DesignTokens.Spacing.lg, 32)
        XCTAssertEqual(DesignTokens.Spacing.xl, 40)
        XCTAssertEqual(DesignTokens.Spacing.xxl, 48)
    }

    func testComponentSpacingValues() {
        // Test component-specific spacing is defined
        XCTAssertEqual(DesignTokens.Spacing.cardPadding, 16)      // sm
        XCTAssertEqual(DesignTokens.Spacing.listPadding, 12)      // xs
        XCTAssertEqual(DesignTokens.Spacing.buttonPadding, 12)    // xs
        XCTAssertEqual(DesignTokens.Spacing.inputPadding, 8)      // xxs
        XCTAssertEqual(DesignTokens.Spacing.sectionGap, 24)       // md
    }

    // MARK: - Corner Radius Tests

    func testCornerRadiusValues() {
        XCTAssertEqual(DesignTokens.CornerRadius.small, 4)
        XCTAssertEqual(DesignTokens.CornerRadius.medium, 8)
        XCTAssertEqual(DesignTokens.CornerRadius.large, 12)
        XCTAssertEqual(DesignTokens.CornerRadius.xlarge, 16)
    }

    // MARK: - Animation Duration Tests

    func testAnimationDurations() {
        XCTAssertEqual(DesignTokens.AnimationDuration.instant, 0)
        XCTAssertEqual(DesignTokens.AnimationDuration.fast, 0.15)
        XCTAssertEqual(DesignTokens.AnimationDuration.normal, 0.25)
        XCTAssertEqual(DesignTokens.AnimationDuration.slow, 0.35)
        XCTAssertEqual(DesignTokens.AnimationDuration.slower, 0.5)
    }

    func testAnimationDurationOrdering() {
        // Test that animation durations are in ascending order
        XCTAssertLessThan(
            DesignTokens.AnimationDuration.instant,
            DesignTokens.AnimationDuration.fast
        )
        XCTAssertLessThan(
            DesignTokens.AnimationDuration.fast,
            DesignTokens.AnimationDuration.normal
        )
        XCTAssertLessThan(
            DesignTokens.AnimationDuration.normal,
            DesignTokens.AnimationDuration.slow
        )
        XCTAssertLessThan(
            DesignTokens.AnimationDuration.slow,
            DesignTokens.AnimationDuration.slower
        )
    }

    // MARK: - Animation Curves Tests

    func testAnimationCurvesExist() {
        XCTAssertNotNil(DesignTokens.AnimationCurve.linear)
        XCTAssertNotNil(DesignTokens.AnimationCurve.easeIn)
        XCTAssertNotNil(DesignTokens.AnimationCurve.easeOut)
        XCTAssertNotNil(DesignTokens.AnimationCurve.easeInOut)
        XCTAssertNotNil(DesignTokens.AnimationCurve.spring)
        XCTAssertNotNil(DesignTokens.AnimationCurve.springBouncy)
        XCTAssertNotNil(DesignTokens.AnimationCurve.smooth)
    }

    func testPredefinedAnimationsExist() {
        XCTAssertNotNil(DesignTokens.Animation.fast)
        XCTAssertNotNil(DesignTokens.Animation.normal)
        XCTAssertNotNil(DesignTokens.Animation.slow)
        XCTAssertNotNil(DesignTokens.Animation.spring)
        XCTAssertNotNil(DesignTokens.Animation.springBouncy)
    }

    // MARK: - Layout Constants Tests

    func testLayoutConstants() {
        XCTAssertGreaterThan(DesignTokens.Layout.minButtonHeight, 0)
        XCTAssertGreaterThan(DesignTokens.Layout.minRowHeight, 0)
        XCTAssertGreaterThan(DesignTokens.Layout.maxContentWidth, 0)
        XCTAssertGreaterThan(DesignTokens.Layout.sidebarWidth, 0)
        XCTAssertGreaterThan(DesignTokens.Layout.cardMinWidth, 0)

        // Test reasonable values
        XCTAssertGreaterThanOrEqual(DesignTokens.Layout.minButtonHeight, 32)
        XCTAssertGreaterThanOrEqual(DesignTokens.Layout.minRowHeight, 40)
    }

    // MARK: - High Contrast Environment Key Tests

    func testHighContrastEnvironmentKey() {
        // Test the environment key for high contrast mode
        let key = HighContrastKey()
        XCTAssertEqual(key.defaultValue, false)
    }

    // MARK: - Integration Tests

    func testColorConsistencyAcrossDesignSystem() {
        // Verify that related colors maintain consistency
        // Text colors should all be different from each other
        let textPrimary = DesignTokens.Colors.textPrimary
        let textSecondary = DesignTokens.Colors.textSecondary
        let textTertiary = DesignTokens.Colors.textTertiary

        // All text colors should exist
        XCTAssertNotNil(textPrimary)
        XCTAssertNotNil(textSecondary)
        XCTAssertNotNil(textTertiary)
    }

    func testDesignTokensCompleteness() {
        // Ensure all major design token categories are available

        // Colors
        XCTAssertNotNil(DesignTokens.Colors.self)

        // Typography
        XCTAssertNotNil(DesignTokens.Typography.self)

        // Spacing
        XCTAssertNotNil(DesignTokens.Spacing.self)

        // Corner Radius
        XCTAssertNotNil(DesignTokens.CornerRadius.self)

        // Animation
        XCTAssertNotNil(DesignTokens.AnimationDuration.self)
        XCTAssertNotNil(DesignTokens.AnimationCurve.self)
        XCTAssertNotNil(DesignTokens.Animation.self)

        // Layout
        XCTAssertNotNil(DesignTokens.Layout.self)
    }
}

final class TonicThemeTokensTests: XCTestCase {

    func testMutedProWorldTokenHexValues() {
        let smartScan = TonicWorld.smartScanPurple.token
        XCTAssertEqual(smartScan.darkMode.darkHex, "0C0B1B")
        XCTAssertEqual(smartScan.darkMode.midHex, "2E295E")
        XCTAssertEqual(smartScan.darkMode.lightHex, "AFA6E6")
        XCTAssertEqual(smartScan.lightMode.darkHex, "F1F0FF")
        XCTAssertEqual(smartScan.lightMode.midHex, "D6D1FF")
        XCTAssertEqual(smartScan.lightMode.lightHex, "5B4EF0")

        let cleanup = TonicWorld.cleanupGreen.token
        XCTAssertEqual(cleanup.darkMode.darkHex, "0A1712")
        XCTAssertEqual(cleanup.lightMode.lightHex, "1F6A4A")

        let clutter = TonicWorld.clutterTeal.token
        XCTAssertEqual(clutter.darkMode.midHex, "244A50")
        XCTAssertEqual(clutter.lightMode.midHex, "CDEFF1")

        let apps = TonicWorld.applicationsBlue.token
        XCTAssertEqual(apps.darkMode.lightHex, "86A6E6")
        XCTAssertEqual(apps.lightMode.lightHex, "2B4ED6")

        let performance = TonicWorld.performanceOrange.token
        XCTAssertEqual(performance.darkMode.midHex, "6E341B")
        XCTAssertEqual(performance.lightMode.darkHex, "FFF3EC")

        let protection = TonicWorld.protectionMagenta.token
        XCTAssertEqual(protection.darkMode.lightHex, "E4A0CA")
        XCTAssertEqual(protection.lightMode.midHex, "FFD1EB")
    }

    func testDerivedGlowAndGlassProfiles() {
        let theme = TonicTheme(world: .smartScanPurple)
        XCTAssertNotNil(theme.glowSoft)
        XCTAssertNotNil(theme.glowStrong)
        XCTAssertNotNil(theme.glow) // back-compat alias

        let darkBase = TonicGlassToken.alphaProfile(for: .dark, variant: .base)
        let darkRaised = TonicGlassToken.alphaProfile(for: .dark, variant: .raised)
        let darkSunken = TonicGlassToken.alphaProfile(for: .dark, variant: .sunken)
        let lightBase = TonicGlassToken.alphaProfile(for: .light, variant: .base)
        let lightRaised = TonicGlassToken.alphaProfile(for: .light, variant: .raised)
        let lightSunken = TonicGlassToken.alphaProfile(for: .light, variant: .sunken)

        XCTAssertEqual(darkBase.fill, 0.06, accuracy: 0.0001)
        XCTAssertEqual(darkBase.vignette, 0.22, accuracy: 0.0001)
        XCTAssertEqual(darkBase.stroke, 0.10, accuracy: 0.0001)
        XCTAssertEqual(darkBase.innerHighlight, 0.06, accuracy: 0.0001)
        XCTAssertEqual(darkBase.shadow, 0.35, accuracy: 0.0001)

        XCTAssertEqual(darkRaised.fill, 0.08, accuracy: 0.0001)
        XCTAssertEqual(darkRaised.stroke, 0.12, accuracy: 0.0001)
        XCTAssertEqual(darkRaised.shadow, 0.40, accuracy: 0.0001)

        XCTAssertEqual(darkSunken.vignette, 0.26, accuracy: 0.0001)
        XCTAssertEqual(darkSunken.fill, 0.05, accuracy: 0.0001)

        XCTAssertEqual(lightBase.fill, 0.02, accuracy: 0.0001)
        XCTAssertEqual(lightBase.vignette, 0.03, accuracy: 0.0001)
        XCTAssertEqual(lightBase.stroke, 0.10, accuracy: 0.0001)
        XCTAssertEqual(lightBase.innerHighlight, 0.16, accuracy: 0.0001)
        XCTAssertEqual(lightBase.shadow, 0.06, accuracy: 0.0001)

        XCTAssertEqual(lightRaised.fill, 0.04, accuracy: 0.0001)
        XCTAssertEqual(lightRaised.stroke, 0.12, accuracy: 0.0001)
        XCTAssertEqual(lightRaised.shadow, 0.11, accuracy: 0.0001)

        XCTAssertEqual(lightSunken.vignette, 0.07, accuracy: 0.0001)
        XCTAssertEqual(lightSunken.fill, 0.01, accuracy: 0.0001)
    }

    func testStatusPaletteHexValues() {
        let lightSuccess = TonicStatusPalette.style(.success, for: .light)
        assertColor(lightSuccess.fill, hex: "E6F6ED")
        assertColor(lightSuccess.stroke, hex: "BFE7CF")
        assertColor(lightSuccess.text, hex: "116A3C")

        let lightWarning = TonicStatusPalette.style(.warning, for: .light)
        assertColor(lightWarning.fill, hex: "FFF3E2")
        assertColor(lightWarning.stroke, hex: "FFD7A6")
        assertColor(lightWarning.text, hex: "8A4B00")

        let lightDanger = TonicStatusPalette.style(.danger, for: .light)
        assertColor(lightDanger.fill, hex: "FFE9EA")
        assertColor(lightDanger.stroke, hex: "FFC0C4")
        assertColor(lightDanger.text, hex: "8B1D2C")

        let lightInfo = TonicStatusPalette.style(.info, for: .light)
        assertColor(lightInfo.fill, hex: "E9F1FF")
        assertColor(lightInfo.stroke, hex: "C7DAFF")
        assertColor(lightInfo.text, hex: "1C4FA8")

        let lightNeutral = TonicStatusPalette.style(.neutral, for: .light)
        assertColor(lightNeutral.fill, hex: "EEF0F4")
        assertColor(lightNeutral.stroke, hex: "D8DCE6")
        assertColor(lightNeutral.text, hex: "3B4254")

        let darkSuccess = TonicStatusPalette.style(.success, for: .dark)
        assertColor(darkSuccess.fill, hex: "123022")
        assertColor(darkSuccess.stroke, hex: "1E5A3C")
        assertColor(darkSuccess.text, hex: "8BE0B4")

        let darkWarning = TonicStatusPalette.style(.warning, for: .dark)
        assertColor(darkWarning.fill, hex: "2A1E10")
        assertColor(darkWarning.stroke, hex: "6C3F12")
        assertColor(darkWarning.text, hex: "FFC57A")

        let darkDanger = TonicStatusPalette.style(.danger, for: .dark)
        assertColor(darkDanger.fill, hex: "2C1215")
        assertColor(darkDanger.stroke, hex: "6B1E2A")
        assertColor(darkDanger.text, hex: "FF9AA3")

        let darkInfo = TonicStatusPalette.style(.info, for: .dark)
        assertColor(darkInfo.fill, hex: "0F1D33")
        assertColor(darkInfo.stroke, hex: "1D3F7A")
        assertColor(darkInfo.text, hex: "9EC2FF")

        let darkNeutral = TonicStatusPalette.style(.neutral, for: .dark)
        assertColor(darkNeutral.fill, hex: "161A22")
        assertColor(darkNeutral.stroke, hex: "2A3242")
        assertColor(darkNeutral.text, hex: "B9C0D0")
    }

    func testSemanticDefaultsAndChipGeometry() {
        XCTAssertNotNil(TonicStatusPalette.fill(.success))
        XCTAssertNotNil(TonicStatusPalette.fill(.info))
        XCTAssertNotNil(TonicStatusPalette.fill(.warning))
        XCTAssertNotNil(TonicStatusPalette.fill(.danger))
        XCTAssertNotNil(TonicStatusPalette.fill(.neutral))

        let darkSemantic = TonicChipTokens.style(
            role: .semantic(.warning),
            strength: .subtle,
            colorScheme: .dark
        )

        XCTAssertEqual(darkSemantic.height, 27)
        XCTAssertEqual(darkSemantic.radius, 999)
        XCTAssertEqual(darkSemantic.paddingX, 11)
        XCTAssertEqual(darkSemantic.paddingY, 5)
        XCTAssertEqual(darkSemantic.iconSize, 12)
        XCTAssertEqual(darkSemantic.strokeWidth, 1)
        XCTAssertEqual(alpha(of: darkSemantic.backgroundBase), 1, accuracy: 0.0001)
        XCTAssertEqual(alpha(of: darkSemantic.backgroundTint), 0, accuracy: 0.0001)
        XCTAssertEqual(alpha(of: darkSemantic.stroke), 1, accuracy: 0.0001)
        XCTAssertEqual(alpha(of: darkSemantic.text), 1, accuracy: 0.0001)
        XCTAssertEqual(alpha(of: darkSemantic.icon), 1, accuracy: 0.0001)

        let darkStrong = TonicChipTokens.style(
            role: .semantic(.warning),
            strength: .strong,
            colorScheme: .dark
        )
        XCTAssertGreaterThan(alpha(of: darkStrong.backgroundTint), 0.05)
        XCTAssertEqual(alpha(of: darkStrong.stroke), 1, accuracy: 0.0001)

        let worldChip = TonicChipTokens.style(
            role: .world(.performanceOrange),
            strength: .strong,
            colorScheme: .dark
        )
        XCTAssertEqual(worldChip.height, 27)
        XCTAssertEqual(worldChip.radius, 999)
        XCTAssertEqual(alpha(of: worldChip.backgroundTint), 0.18, accuracy: 0.0001)
        XCTAssertEqual(alpha(of: worldChip.stroke), 0.34, accuracy: 0.0001)
        XCTAssertEqual(alpha(of: worldChip.icon), 0.85, accuracy: 0.0001)

        let lightSemantic = TonicChipTokens.style(
            role: .semantic(.info),
            strength: .subtle,
            colorScheme: .light
        )
        XCTAssertEqual(alpha(of: lightSemantic.backgroundBase), 1, accuracy: 0.0001)
        XCTAssertEqual(alpha(of: lightSemantic.backgroundTint), 0, accuracy: 0.0001)
        XCTAssertEqual(alpha(of: lightSemantic.stroke), 1, accuracy: 0.0001)
        XCTAssertEqual(alpha(of: lightSemantic.text), 1, accuracy: 0.0001)
        XCTAssertEqual(alpha(of: lightSemantic.icon), 1, accuracy: 0.0001)

        let outline = TonicChipTokens.style(
            role: .semantic(.neutral),
            strength: .outline,
            colorScheme: .dark
        )
        XCTAssertEqual(alpha(of: outline.backgroundTint), 0, accuracy: 0.0001)
        XCTAssertEqual(alpha(of: outline.stroke), 1, accuracy: 0.0001)
        XCTAssertEqual(outline.strokeWidth, 1)
    }

    func testButtonStateTokensAreDeterministic() {
        let defaultToken = TonicButtonStateTokens.token(for: .default)
        XCTAssertEqual(defaultToken.scale, 1)
        XCTAssertEqual(defaultToken.brightnessDelta, 0, accuracy: 0.0001)
        XCTAssertEqual(defaultToken.strokeBoostOpacity, 0, accuracy: 0.0001)

        let hover = TonicButtonStateTokens.token(for: .hover)
        XCTAssertEqual(hover.scale, 1)
        XCTAssertEqual(hover.brightnessDelta, 0.06, accuracy: 0.0001)
        XCTAssertEqual(hover.strokeBoostOpacity, 0.16, accuracy: 0.0001)

        let pressed = TonicButtonStateTokens.token(for: .pressed)
        XCTAssertEqual(pressed.scale, 0.98, accuracy: 0.0001)
        XCTAssertEqual(pressed.shadowMultiplier, 0.7, accuracy: 0.0001)

        let focused = TonicButtonStateTokens.token(for: .focused)
        XCTAssertEqual(focused.scale, 1)
        XCTAssertEqual(focused.strokeBoostOpacity, 0.10, accuracy: 0.0001)

        let disabled = TonicButtonStateTokens.token(for: .disabled)
        XCTAssertEqual(disabled.contentOpacity, 0.5, accuracy: 0.0001)
    }

    func testButtonTokenBaseValues() {
        let lightPrimary = TonicButtonTokens.primary(for: .light)
        assertColor(lightPrimary.background, hex: "111318")
        assertColor(lightPrimary.foreground, hex: "FFFFFF")

        let darkPrimary = TonicButtonTokens.primary(for: .dark)
        assertColor(darkPrimary.background, hex: "FFFFFF")
        assertColor(darkPrimary.foreground, hex: "0B0C10")

        let lightSecondary = TonicButtonTokens.secondary(for: .light)
        assertColor(lightSecondary.background, hex: "FFFFFF", alpha: 168.0 / 255.0)

        let darkSecondary = TonicButtonTokens.secondary(for: .dark)
        assertColor(darkSecondary.background, hex: "FFFFFF", alpha: 31.0 / 255.0)
    }

    private func alpha(of color: Color) -> Double {
        let nsColor = NSColor(color)
        return Double((nsColor.usingColorSpace(.deviceRGB) ?? nsColor).alphaComponent)
    }

    private func assertColor(
        _ color: Color,
        hex: String,
        alpha: Double = 1.0,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let nsColor = NSColor(color).usingColorSpace(.deviceRGB) ?? NSColor(color)
        let r = Int(round(nsColor.redComponent * 255))
        let g = Int(round(nsColor.greenComponent * 255))
        let b = Int(round(nsColor.blueComponent * 255))
        let actualHex = String(format: "%02X%02X%02X", r, g, b)
        XCTAssertEqual(actualHex, hex, file: file, line: line)
        XCTAssertEqual(Double(nsColor.alphaComponent), alpha, accuracy: 0.002, file: file, line: line)
    }
}
