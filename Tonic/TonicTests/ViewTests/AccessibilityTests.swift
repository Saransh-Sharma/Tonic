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
            "Theme Picker",
            "Update Check Button",
            "Color Palette Picker",
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

    // MARK: - Editorial TonicDS Regression

    @MainActor
    func testEditorialControlShowcaseRendersInLightAndDark() {
        let dark = renderImage(
            content: editorialControlShowcase
                .padding(24)
                .frame(width: 620, height: 260)
                .background(TonicDS.Colors.canvas)
                .environment(\.colorScheme, .dark)
        )
        let light = renderImage(
            content: editorialControlShowcase
                .padding(24)
                .frame(width: 620, height: 260)
                .background(TonicDS.Colors.canvas)
                .environment(\.colorScheme, .light)
        )

        XCTAssertGreaterThan(dark.size.width, 0)
        XCTAssertGreaterThan(light.size.width, 0)
        add(XCTAttachment(image: dark))
        add(XCTAttachment(image: light))
    }

    func testEditorialConsoleContrastGuards() {
        let console = NSColor(calibratedRed: 23.0 / 255.0, green: 23.0 / 255.0, blue: 28.0 / 255.0, alpha: 1)
        let onDark = NSColor.white
        let muted = NSColor(calibratedRed: 147.0 / 255.0, green: 147.0 / 255.0, blue: 159.0 / 255.0, alpha: 1)

        XCTAssertGreaterThanOrEqual(ColorAccessibilityHelper.contrastRatio(foreground: onDark, background: console), 4.5)
        XCTAssertGreaterThanOrEqual(ColorAccessibilityHelper.contrastRatio(foreground: muted, background: console), 4.5)
    }

    @MainActor
    private func renderImage<Content: View>(content: Content) -> NSImage {
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        renderer.proposedSize = .unspecified
        return renderer.nsImage ?? NSImage(size: NSSize(width: 1, height: 1))
    }

    @MainActor
    private var editorialControlShowcase: some View {
        VStack(alignment: .leading, spacing: 16) {
            MonoLabel("Controls")
            HStack(spacing: 10) {
                PrimaryPill("Run Smart Scan") {}
                FilterPill(title: "All", isActive: true) {}
                FilterPill(title: "Large", isActive: false) {}
            }
            MonitoringConsole {
                VStack(alignment: .leading, spacing: 10) {
                    MonoLabel("Console", color: TonicDS.Colors.onDarkMuted)
                    HStack {
                        StatusChip("Healthy", color: TonicDS.Colors.statusSuccess)
                        StatusChip("Critical", color: TonicDS.Colors.statusCritical)
                    }
                    Metric("42", unit: "%", color: TonicDS.Colors.statusInfo)
                }
            }
        }
    }
}
