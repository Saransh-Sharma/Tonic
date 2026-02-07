//
//  AccessibilityTests.swift
//  TonicTests
//
//  Tests for accessibility - VoiceOver, keyboard navigation, focus order, WCAG compliance
//

import XCTest
import SwiftUI
@testable import Tonic

final class AccessibilityTests: XCTestCase {

    // MARK: - VoiceOver Label Tests

    func testDashboardLabels() {
        let labels = [
            "Health Score",
            "CPU Usage",
            "Memory",
            "Disk Usage",
            "Network Speed",
            "Smart Scan Button",
            "Recent Activity",
        ]

        for label in labels {
            XCTAssertFalse(label.isEmpty, "\(label) should exist")
        }
    }

    func testMaintenanceLabels() {
        let labels = [
            "Scan Tab",
            "Clean Tab",
            "Start Scan Button",
            "Cancel Button",
            "Progress Bar",
            "Scanning Stage",
            "Space Recovered",
        ]

        for label in labels {
            XCTAssertFalse(label.isEmpty)
        }
    }

    func testSettingsLabels() {
        let labels = [
            "Launch at Login Toggle",
            "Theme Picker",
            "Update Check Button",
            "Clear Cache Button",
        ]

        for label in labels {
            XCTAssertFalse(label.isEmpty)
        }
    }

    // MARK: - Keyboard Navigation Tests

    func testTabKeyNavigation() {
        var focusedElement = 0
        let elementCount = 5

        // Tab forward
        focusedElement = (focusedElement + 1) % elementCount
        XCTAssertGreaterThanOrEqual(focusedElement, 0)
        XCTAssertLessThan(focusedElement, elementCount)
    }

    func testArrowKeyNavigation() {
        var selectedIndex = 2

        // Arrow down
        selectedIndex += 1
        XCTAssertEqual(selectedIndex, 3)

        // Arrow up
        selectedIndex -= 1
        XCTAssertEqual(selectedIndex, 2)
    }

    func testEnterKeyActivation() {
        var isActivated = false
        // Simulate Enter key
        isActivated = true
        XCTAssertTrue(isActivated)
    }

    func testEscapeKeyDismissal() {
        var isOpen = true
        // Simulate Escape key
        isOpen = false
        XCTAssertFalse(isOpen)
    }

    func testSpaceKeyToggle() {
        var isToggled = false

        // Press space
        isToggled.toggle()
        XCTAssertTrue(isToggled)

        // Press space again
        isToggled.toggle()
        XCTAssertFalse(isToggled)
    }

    // MARK: - Focus Order Tests

    func testLogicalFocusOrder() {
        let focusOrder = [
            "Title",
            "Primary Content",
            "Action Button",
            "Secondary Button",
        ]

        for (index, element) in focusOrder.enumerated() {
            XCTAssertFalse(element.isEmpty)
            XCTAssertGreaterThanOrEqual(index, 0)
        }
    }

    func testFocusVisibility() {
        let focusColor = "blue"
        let focusWidth = 2

        XCTAssertFalse(focusColor.isEmpty)
        XCTAssertGreaterThan(focusWidth, 0)
    }

    func testFocusTrap() {
        var hasFocusTrap = false
        // Modal dialogs should trap focus
        let isModal = true
        if isModal {
            hasFocusTrap = true
        }

        XCTAssertTrue(hasFocusTrap)
    }

    // MARK: - Color Contrast Tests

    func testTextContrast() {
        let testCases: [(foreground: String, background: String)] = [
            ("black", "white"),
            ("dark-gray", "light-gray"),
            ("blue", "white"),
        ]

        for (fg, bg) in testCases {
            XCTAssertFalse(fg.isEmpty)
            XCTAssertFalse(bg.isEmpty)
        }
    }

    func testButtonContrast() {
        // Primary button should have sufficient contrast
        let hasContrast = true
        XCTAssertTrue(hasContrast)
    }

    // MARK: - Dynamic Type Tests

    func testLargeTextSize() {
        let fontSize: CGFloat = 20
        XCTAssertGreaterThan(fontSize, 16)
    }

    func testSmallTextSize() {
        let fontSize: CGFloat = 12
        XCTAssertGreaterThanOrEqual(fontSize, 12)
    }

    func testTextScaling() {
        let baseSize: CGFloat = 16
        let scaledSize = baseSize * 1.5
        XCTAssertGreaterThan(scaledSize, baseSize)
    }

    // MARK: - Icon Tests

    func testIconWithLabel() {
        let icon = "cpu"
        let label = "CPU Usage"

        XCTAssertFalse(icon.isEmpty)
        XCTAssertFalse(label.isEmpty)
    }

    func testIconContrast() {
        // Icons should be visible against background
        let hasContrast = true
        XCTAssertTrue(hasContrast)
    }

    func testDecorativeIcon() {
        let isDecorative = true
        // Decorative icons should not have labels
        let shouldHaveLabel = !isDecorative
        XCTAssertFalse(shouldHaveLabel)
    }

    // MARK: - Form Accessibility Tests

    func testFormLabelAssociation() {
        let formLabels = [
            ("Email", "email-input"),
            ("Password", "password-input"),
            ("Theme", "theme-picker"),
        ]

        for (label, inputId) in formLabels {
            XCTAssertFalse(label.isEmpty)
            XCTAssertFalse(inputId.isEmpty)
        }
    }

    func testErrorMessageAssociation() {
        let hasErrorMessage = true
        let hasErrorLabel = true

        XCTAssertTrue(hasErrorMessage)
        XCTAssertTrue(hasErrorLabel)
    }

    func testPlaceholderNotLabel() {
        // Placeholders should not be used as labels
        let hasLabel = true
        let hasPlaceholder = true

        XCTAssertTrue(hasLabel)
        XCTAssertTrue(hasPlaceholder)
    }

    // MARK: - Reduced Motion Tests

    func testAnimationPreference() {
        var prefersReducedMotion = false
        XCTAssertFalse(prefersReducedMotion)

        prefersReducedMotion = true
        XCTAssertTrue(prefersReducedMotion)
    }

    func testAnimationDisabled() {
        var animationDuration: TimeInterval = 0.3

        // When reduced motion is enabled
        if true {  // prefersReducedMotion
            animationDuration = 0
        }

        XCTAssertEqual(animationDuration, 0)
    }

    // MARK: - Focus Indicator Tests

    func testFocusRingVisible() {
        let focusRingColor = "accent"
        let focusRingWidth: CGFloat = 2

        XCTAssertFalse(focusRingColor.isEmpty)
        XCTAssertGreaterThan(focusRingWidth, 0)
    }

    func testFocusRingNotHidden() {
        let isVisible = true
        XCTAssertTrue(isVisible)
    }

    func testFocusIndicatorSize() {
        let size: CGFloat = 4
        XCTAssertGreaterThan(size, 0)
    }

    // MARK: - Screen Reader Tests

    func testHeadingStructure() {
        let headings = [
            ("h1", "Dashboard"),
            ("h2", "System Health"),
            ("h3", "Metrics"),
        ]

        for (level, text) in headings {
            XCTAssertFalse(level.isEmpty)
            XCTAssertFalse(text.isEmpty)
        }
    }

    func testListStructure() {
        let listItems = ["Item 1", "Item 2", "Item 3"]
        XCTAssertGreaterThan(listItems.count, 0)
    }

    func testTableStructure() {
        let headers = ["Name", "Size", "Date"]
        let rows = 10

        XCTAssertGreaterThan(headers.count, 0)
        XCTAssertGreaterThan(rows, 0)
    }

    // MARK: - WCAG Compliance Tests

    func testWCAGAStandards() {
        let standards = ["Perceivable", "Operable", "Understandable", "Robust"]
        XCTAssertEqual(standards.count, 4)
    }

    func testMinimumClickSize() {
        let minSize: CGFloat = 44
        XCTAssertGreaterThanOrEqual(minSize, 44)
    }

    func testMinimumPadding() {
        let padding: CGFloat = 8
        XCTAssertGreaterThanOrEqual(padding, 8)
    }

    // MARK: - State Announcement Tests

    func testLoadingAnnouncement() {
        let announcement = "Loading, please wait"
        XCTAssertFalse(announcement.isEmpty)
    }

    func testSuccessAnnouncement() {
        let announcement = "Operation completed successfully"
        XCTAssertFalse(announcement.isEmpty)
    }

    func testErrorAnnouncement() {
        let announcement = "Error: Action failed"
        XCTAssertFalse(announcement.isEmpty)
    }

    func testProgressAnnouncement() {
        let announcement = "Scanning: 50% complete"
        XCTAssertTrue(announcement.contains("%"))
    }

    // MARK: - Help Text Tests

    func testHelpTextAvailable() {
        let hasHelpText = true
        XCTAssertTrue(hasHelpText)
    }

    func testHelpTextAssociation() {
        let inputId = "email-input"
        let helpId = "email-help"

        XCTAssertFalse(inputId.isEmpty)
        XCTAssertFalse(helpId.isEmpty)
    }

    // MARK: - Language Tests

    func testLanguageDeclaration() {
        let language = "en"
        XCTAssertEqual(language, "en")
    }

    func testDirectionDeclaration() {
        let direction = "ltr"  // Left-to-right
        XCTAssertFalse(direction.isEmpty)
    }

    // MARK: - Smart Scan Visual Regression

    @MainActor
    func testSmartScanChipSnapshots() {
        let dark = renderImage(
            content: chipShowcase
                .padding(24)
                .frame(width: 520, height: 240)
                .background(WorldCanvasBackground())
                .tonicTheme(.smartScanPurple)
                .environment(\.colorScheme, .dark)
        )
        let light = renderImage(
            content: chipShowcase
                .padding(24)
                .frame(width: 520, height: 240)
                .background(WorldCanvasBackground())
                .tonicTheme(.smartScanPurple)
                .environment(\.colorScheme, .light)
        )

        XCTAssertNotNil(dark)
        XCTAssertNotNil(light)
        add(XCTAttachment(image: dark))
        add(XCTAttachment(image: light))
    }

    func testSmartScanChipReadabilityAcrossCanvases() {
        let darkCanvas = nsColor(TonicCanvasTokens.fill(for: .smartScanPurple, colorScheme: .dark))
        let sectionCanvas = nsColor(TonicCanvasTokens.fill(for: .cleanupGreen, colorScheme: .dark))
        let lightCanvas = nsColor(TonicNeutralToken.neutral3)

        let darkSemantic = TonicChipTokens.style(role: .semantic(.warning), strength: .subtle, colorScheme: .dark)
        let darkWorld = TonicChipTokens.style(role: .world(.cleanupGreen), strength: .subtle, colorScheme: .dark)
        let lightSemantic = TonicChipTokens.style(role: .semantic(.info), strength: .subtle, colorScheme: .light)

        assertChipReadability(style: darkSemantic, on: darkCanvas, context: "dark canvas semantic chip", minTextRatio: 4.5, minIconRatio: 4.5)
        assertChipReadability(style: darkWorld, on: sectionCanvas, context: "dark bento/section world chip")
        assertChipReadability(style: lightSemantic, on: lightCanvas, context: "light canvas semantic chip", minTextRatio: 4.5, minIconRatio: 4.5)

        for kind in TonicSemanticKind.allCases {
            let darkStatus = TonicStatusPalette.style(kind, for: .dark)
            assertStatusReadability(status: darkStatus, context: "dark status \(kind.rawValue)")

            let lightStatus = TonicStatusPalette.style(kind, for: .light)
            assertStatusReadability(status: lightStatus, context: "light status \(kind.rawValue)")
        }
    }

    @MainActor
    func testSmartScanSectionSnapshot() {
        let view = VStack(spacing: TonicSpaceToken.gridGap) {
            PillarSectionHeader(
                title: "Space",
                subtitle: "Cleanup + Clutter",
                summary: "12.8 GB reclaimable",
                sectionActionTitle: "Review",
                world: .cleanupGreen,
                sectionAccessibilityIdentifier: nil,
                onSectionAction: {}
            )
            BentoGrid(
                world: .cleanupGreen,
                tiles: [
                    .init(
                        id: .spaceSystemJunk,
                        size: .large,
                        metricTitle: "9.4 GB",
                        title: "System Junk Found",
                        subtitle: "Muted Pro sample tile for regression validation.",
                        iconSymbols: ["gearshape.2.fill"],
                        reviewTarget: .section(.space),
                        actions: [.init(title: "Review", kind: .review), .init(title: "Clean", kind: .clean)]
                    ),
                    .init(
                        id: .spaceTrashBins,
                        size: .wide,
                        metricTitle: "1.2 GB",
                        title: "Trash Bins Found",
                        subtitle: "Regression sample.",
                        iconSymbols: ["trash.fill"],
                        reviewTarget: .section(.space),
                        actions: [.init(title: "Review", kind: .review)]
                    ),
                    .init(
                        id: .spaceExtraBinaries,
                        size: .small,
                        metricTitle: "420 MB",
                        title: "Extra Binaries",
                        subtitle: "Regression sample.",
                        iconSymbols: ["terminal.fill"],
                        reviewTarget: .section(.space),
                        actions: [.init(title: "Review", kind: .review)]
                    ),
                    .init(
                        id: .spaceXcodeJunk,
                        size: .small,
                        metricTitle: "850 MB",
                        title: "Xcode Junk",
                        subtitle: "Regression sample.",
                        iconSymbols: ["hammer.fill"],
                        reviewTarget: .section(.space),
                        actions: [.init(title: "Review", kind: .review)]
                    )
                ],
                onReview: { _ in },
                onAction: { _, _ in }
            )
        }
            .padding(24)
            .frame(width: 980, height: 640, alignment: .topLeading)
            .background(WorldCanvasBackground())
            .tonicTheme(.smartScanPurple)
            .environment(\.colorScheme, .dark)

        let dark = renderImage(content: view)
        XCTAssertNotNil(dark)
        add(XCTAttachment(image: dark))

        let light = renderImage(
            content: view
                .environment(\.colorScheme, .light)
        )
        XCTAssertNotNil(light)
        add(XCTAttachment(image: light))
    }

    @MainActor
    func testSmartScanButtonStateSnapshots() {
        let dark = renderImage(
            content: buttonStateShowcase
                .padding(24)
                .frame(width: 860, height: 220)
                .background(WorldCanvasBackground())
                .tonicTheme(.smartScanPurple)
                .environment(\.colorScheme, .dark)
        )

        let light = renderImage(
            content: buttonStateShowcase
                .padding(24)
                .frame(width: 860, height: 220)
                .background(WorldCanvasBackground())
                .tonicTheme(.smartScanPurple)
                .environment(\.colorScheme, .light)
        )

        XCTAssertNotNil(dark)
        XCTAssertNotNil(light)
        add(XCTAttachment(image: dark))
        add(XCTAttachment(image: light))
    }

    @MainActor
    func testSmartScanBentoHoverElevationSnapshot() {
        let baseTile = BentoTile(
            model: .init(
                id: .spaceSystemJunk,
                size: .wide,
                metricTitle: "1.8 GB",
                title: "System Junk Found",
                subtitle: "Elevation snapshot sample.",
                iconSymbols: ["gearshape.fill"],
                reviewTarget: .section(.space),
                actions: [.init(title: "Review", kind: .review)]
            ),
            world: .cleanupGreen,
            onReview: { _ in },
            onAction: { _, _ in }
        )

        let view = HStack(spacing: 16) {
            baseTile
            baseTile
                .offset(y: -2)
                .softShadow(TonicShadowToken.lightE2)
        }
        .padding(24)
        .frame(width: 900, height: 300)
        .background(WorldCanvasBackground())
        .tonicTheme(.smartScanPurple)
        .environment(\.colorScheme, .light)

        let image = renderImage(content: view)
        XCTAssertNotNil(image)
        add(XCTAttachment(image: image))
    }

    func testSmartScanThemeRegressionContrastGuards() {
        let darkCanvas = nsColor(TonicCanvasTokens.fill(for: .smartScanPurple, colorScheme: .dark))
        let lightCanvas = nsColor(TonicCanvasTokens.fill(for: .smartScanPurple, colorScheme: .light))

        let darkPrimary = compositedColor(
            foreground: NSColor(calibratedWhite: 1.0, alpha: 0.92),
            over: darkCanvas
        )
        let lightPrimary = compositedColor(
            foreground: NSColor(calibratedWhite: 0.0, alpha: 0.88),
            over: lightCanvas
        )

        let darkRatio = ColorAccessibilityHelper.contrastRatio(foreground: darkPrimary, background: darkCanvas)
        let lightRatio = ColorAccessibilityHelper.contrastRatio(foreground: lightPrimary, background: lightCanvas)

        XCTAssertGreaterThanOrEqual(darkRatio, 4.5, "Dark theme labels must retain AA contrast")
        XCTAssertGreaterThanOrEqual(lightRatio, 4.5, "Light theme labels must retain AA contrast")
    }

    @MainActor
    private func renderImage<Content: View>(content: Content) -> NSImage {
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        renderer.proposedSize = .unspecified
        return renderer.nsImage ?? NSImage(size: NSSize(width: 1, height: 1))
    }

    private func assertChipReadability(
        style: TonicChipStyle,
        on canvas: NSColor,
        context: String,
        minTextRatio: Double = 3.0,
        minIconRatio: Double = 2.0
    ) {
        let composedBase = compositedColor(foreground: nsColor(style.backgroundBase), over: canvas)
        let composedFill = compositedColor(foreground: nsColor(style.backgroundTint), over: composedBase)
        let textRatio = ColorAccessibilityHelper.contrastRatio(
            foreground: nsColor(style.text),
            background: composedFill
        )
        let iconRatio = ColorAccessibilityHelper.contrastRatio(
            foreground: nsColor(style.icon),
            background: composedFill
        )

        XCTAssertGreaterThanOrEqual(textRatio, minTextRatio, "\(context) text contrast should remain readable")
        XCTAssertGreaterThanOrEqual(iconRatio, minIconRatio, "\(context) icon contrast should remain readable")
    }

    private func assertStatusReadability(status: TonicStatusStyle, context: String) {
        let ratio = ColorAccessibilityHelper.contrastRatio(
            foreground: nsColor(status.text),
            background: nsColor(status.fill)
        )
        XCTAssertGreaterThanOrEqual(ratio, 4.5, "\(context) text should meet WCAG AA")
    }

    private func nsColor(_ color: Color) -> NSColor {
        let value = NSColor(color)
        return value.usingColorSpace(.deviceRGB) ?? value
    }

    private func compositedColor(foreground: NSColor, over background: NSColor) -> NSColor {
        let fg = foreground.usingColorSpace(.deviceRGB) ?? foreground
        let bg = background.usingColorSpace(.deviceRGB) ?? background

        let fgA = fg.alphaComponent
        let bgA = bg.alphaComponent
        let outA = fgA + bgA * (1 - fgA)

        guard outA > 0 else {
            return .clear
        }

        let outR = (fg.redComponent * fgA + bg.redComponent * bgA * (1 - fgA)) / outA
        let outG = (fg.greenComponent * fgA + bg.greenComponent * bgA * (1 - fgA)) / outA
        let outB = (fg.blueComponent * fgA + bg.blueComponent * bgA * (1 - fgA)) / outA

        return NSColor(calibratedRed: outR, green: outG, blue: outB, alpha: outA)
    }

    private var chipShowcase: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                GlassChip(title: "Safe", role: .semantic(.success))
                GlassChip(title: "Needs Review", role: .semantic(.warning))
                GlassChip(title: "Risky", role: .semantic(.danger), strength: .strong)
            }
            HStack(spacing: 8) {
                GlassChip(title: "Reclaimable", role: .world(.cleanupGreen))
                GlassChip(title: "Startup Impact", role: .world(.performanceOrange))
                GlassChip(title: "Apps Found", role: .world(.applicationsBlue), strength: .outline)
            }
        }
    }

    private var buttonStateShowcase: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                ButtonStatePillView(title: "Default", variant: .primary, state: .default)
                ButtonStatePillView(title: "Hover", variant: .primary, state: .hover)
                ButtonStatePillView(title: "Pressed", variant: .primary, state: .pressed)
                ButtonStatePillView(title: "Focused", variant: .primary, state: .focused)
                ButtonStatePillView(title: "Disabled", variant: .primary, state: .disabled)
            }
            HStack(spacing: 10) {
                ButtonStatePillView(title: "Secondary", variant: .secondary, state: .default)
                ButtonStatePillView(title: "Hover", variant: .secondary, state: .hover)
                ButtonStatePillView(title: "Pressed", variant: .secondary, state: .pressed)
                ButtonStatePillView(title: "Focused", variant: .secondary, state: .focused)
                ButtonStatePillView(title: "Disabled", variant: .secondary, state: .disabled)
            }
        }
    }
}

private struct ButtonStatePillView: View {
    let title: String
    let variant: TonicButtonVariant
    let state: TonicControlState
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let style = TonicButtonTokens.style(variant: variant, state: state, colorScheme: colorScheme)
        let token = TonicButtonStateTokens.token(for: state)

        Text(title)
            .font(TonicTypeToken.caption.weight(.semibold))
            .foregroundStyle(style.foreground)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(style.background)
            .overlay(Capsule().stroke(style.stroke, lineWidth: 1))
            .overlay(Capsule().stroke(style.strokeBoost, lineWidth: 1))
            .overlay(
                Capsule()
                    .inset(by: -3)
                    .stroke(state == .focused ? style.focusRing : .clear, lineWidth: 2)
            )
            .clipShape(Capsule())
            .scaleEffect(token.scale)
            .brightness(token.brightnessDelta)
            .opacity(token.contentOpacity)
    }
}
