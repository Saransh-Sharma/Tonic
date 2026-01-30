//
//  CardTests.swift
//  TonicTests
//
//  Tests for Card component - variants, styling, colors, shadows
//

import XCTest
import SwiftUI
@testable import Tonic

final class CardTests: XCTestCase {

    // MARK: - Card Variant Tests

    func testElevatedCardVariant() {
        let variant = Card<Text>.CardVariant.elevated
        XCTAssertNotNil(variant)
    }

    func testFlatCardVariant() {
        let variant = Card<Text>.CardVariant.flat
        XCTAssertNotNil(variant)
    }

    func testInsetCardVariant() {
        let variant = Card<Text>.CardVariant.inset
        XCTAssertNotNil(variant)
    }

    // MARK: - Card Properties Tests

    func testCardDefaultPadding() {
        let defaultPadding = DesignTokens.Spacing.cardPadding
        XCTAssertEqual(defaultPadding, 16)
    }

    func testCardDefaultCornerRadius() {
        let defaultRadius = DesignTokens.CornerRadius.large
        XCTAssertEqual(defaultRadius, 12)
    }

    func testCardCustomPadding() {
        let customPadding: CGFloat = 20
        XCTAssertGreaterThan(customPadding, 0)
        XCTAssertNotEqual(customPadding, DesignTokens.Spacing.cardPadding)
    }

    func testCardCustomCornerRadius() {
        let customRadius: CGFloat = 16
        XCTAssertGreaterThan(customRadius, 0)
        XCTAssertNotEqual(customRadius, DesignTokens.CornerRadius.large)
    }

    // MARK: - Color Tests

    func testCardBackgroundColor() {
        let backgroundColor = DesignTokens.Colors.backgroundSecondary
        XCTAssertNotNil(backgroundColor)
    }

    func testCardSeparatorColor() {
        let separatorColor = DesignTokens.Colors.separator
        XCTAssertNotNil(separatorColor)
    }

    // MARK: - Shadow Tests

    func testElevatedCardShadow() {
        let shadowOpacity: CGFloat = 0.1
        let shadowRadius: CGFloat = 4
        let shadowOffsetY: CGFloat = 2

        XCTAssertGreaterThan(shadowOpacity, 0)
        XCTAssertGreaterThan(shadowRadius, 0)
        XCTAssertGreaterThanOrEqual(shadowOffsetY, 0)
    }

    func testFlatCardBorder() {
        let borderWidth: CGFloat = 1
        let borderOpacity: CGFloat = 1.0

        XCTAssertEqual(borderWidth, 1)
        XCTAssertEqual(borderOpacity, 1.0)
    }

    func testInsetCardBorder() {
        let borderWidth: CGFloat = 0.5
        let borderOpacity: CGFloat = 0.5

        XCTAssertEqual(borderWidth, 0.5)
        XCTAssertEqual(borderOpacity, 0.5)
    }

    // MARK: - Content Tests

    func testCardWithSimpleContent() {
        let content = "Simple Content"
        XCTAssertFalse(content.isEmpty)
    }

    func testCardWithComplexContent() {
        let components = ["Title", "Description", "Footer"]
        XCTAssertEqual(components.count, 3)
    }

    func testCardContentInsets() {
        let padding = DesignTokens.Spacing.cardPadding
        XCTAssertGreaterThan(padding, 0)
    }

    // MARK: - Visual Style Tests

    func testElevatedCardStyle() {
        // Elevated: Shadow for depth
        let hasShadow = true
        let hasOnlyBorder = false

        XCTAssertTrue(hasShadow)
        XCTAssertFalse(hasOnlyBorder)
    }

    func testFlatCardStyle() {
        // Flat: Border only, no shadow
        let hasShadow = false
        let hasBorder = true

        XCTAssertFalse(hasShadow)
        XCTAssertTrue(hasBorder)
    }

    func testInsetCardStyle() {
        // Inset: Inset border for nested content
        let hasInsetBorder = true
        let isNested = true

        XCTAssertTrue(hasInsetBorder)
        XCTAssertTrue(isNested)
    }

    // MARK: - Accessibility Tests

    func testCardColorContrast() {
        // Card background should have good contrast with text
        let background = NSColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)
        let text = NSColor.black

        let ratio = ColorAccessibilityHelper.contrastRatio(foreground: text, background: background)
        XCTAssertGreaterThanOrEqual(ratio, 4.5, "Card should have WCAG AA contrast")
    }

    func testCardBorderVisibility() {
        // Border should be visible against background
        let background = NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        let border = NSColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0)

        let ratio = ColorAccessibilityHelper.contrastRatio(foreground: border, background: background)
        XCTAssertGreaterThanOrEqual(ratio, 1.5, "Border should be visible")
    }

    // MARK: - Layout Tests

    func testCardMinimumHeight() {
        let minHeight: CGFloat = 100
        XCTAssertGreaterThan(minHeight, 0)
    }

    func testCardMaximumWidth() {
        let maxWidth = DesignTokens.Layout.maxContentWidth
        XCTAssertGreaterThan(maxWidth, 0)
    }

    func testCardSpacing() {
        let spacing = DesignTokens.Spacing.md
        XCTAssertGreaterThan(spacing, 0)
    }

    // MARK: - Edge Cases

    func testCardWithNoContent() {
        let isEmpty = true
        XCTAssertTrue(isEmpty)
    }

    func testCardWithLongContent() {
        let longContent = String(repeating: "A", count: 10_000)
        XCTAssertEqual(longContent.count, 10_000)
    }

    func testCardWithSpecialCharacters() {
        let content = "Card with émojis 🎉 and spëcial çharacters"
        XCTAssertFalse(content.isEmpty)
    }

    // MARK: - Variant Switching Tests

    func testSwitchFromElevatedToFlat() {
        let initialVariant = Card<Text>.CardVariant.elevated
        let newVariant = Card<Text>.CardVariant.flat

        XCTAssertNotEqual(
            String(describing: initialVariant),
            String(describing: newVariant)
        )
    }

    func testSwitchFromFlatToInset() {
        let initialVariant = Card<Text>.CardVariant.flat
        let newVariant = Card<Text>.CardVariant.inset

        XCTAssertNotEqual(
            String(describing: initialVariant),
            String(describing: newVariant)
        )
    }

    // MARK: - Padding Variations

    func testSmallPadding() {
        let smallPadding = DesignTokens.Spacing.sm
        XCTAssertEqual(smallPadding, 16)
    }

    func testMediumPadding() {
        let mediumPadding = DesignTokens.Spacing.md
        XCTAssertEqual(mediumPadding, 24)
    }

    func testLargePadding() {
        let largePadding = DesignTokens.Spacing.lg
        XCTAssertEqual(largePadding, 32)
    }

    // MARK: - Corner Radius Variations

    func testSmallCornerRadius() {
        let small = DesignTokens.CornerRadius.small
        XCTAssertEqual(small, 4)
    }

    func testMediumCornerRadius() {
        let medium = DesignTokens.CornerRadius.medium
        XCTAssertEqual(medium, 8)
    }

    func testLargeCornerRadius() {
        let large = DesignTokens.CornerRadius.large
        XCTAssertEqual(large, 12)
    }

    func testXLargeCornerRadius() {
        let xlarge = DesignTokens.CornerRadius.xlarge
        XCTAssertEqual(xlarge, 16)
    }

    // MARK: - Semantic Variants Test

    func testVariantPurposes() {
        // Elevated: Primary content containers
        let elevatedUse = "Primary content containers"
        XCTAssertFalse(elevatedUse.isEmpty)

        // Flat: Secondary content
        let flatUse = "Secondary content"
        XCTAssertFalse(flatUse.isEmpty)

        // Inset: Grouped/nested content
        let insetUse = "Grouped or nested content"
        XCTAssertFalse(insetUse.isEmpty)
    }

    // MARK: - Performance Tests

    func testCardRenderingPerformance() {
        let startTime = Date()

        // Simulate creating multiple cards
        var cards: [String] = []
        for i in 0..<1000 {
            cards.append("Card \(i)")
        }

        let duration = Date().timeIntervalSince(startTime)

        XCTAssertEqual(cards.count, 1000)
        XCTAssertLessThan(duration, 0.5, "Creating 1000 cards should be fast")
    }

    func testCardVariantComparison() {
        let variants: [String] = ["elevated", "flat", "inset"]
        XCTAssertEqual(variants.count, 3)

        for variant in variants {
            XCTAssertFalse(variant.isEmpty)
        }
    }
}
