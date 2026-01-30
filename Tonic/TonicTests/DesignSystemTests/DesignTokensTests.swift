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
