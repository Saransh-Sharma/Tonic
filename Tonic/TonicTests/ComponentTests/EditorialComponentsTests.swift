//
//  EditorialComponentsTests.swift
//  TonicTests
//
//  Tests for the current TonicDS editorial component contracts.
//

import XCTest
@testable import Tonic

final class EditorialComponentsTests: XCTestCase {

    func testTonicDSLayoutConstantsMatchEditorialShell() {
        XCTAssertEqual(TonicDS.Layout.maxContentWidth, 1200)
        XCTAssertEqual(TonicDS.Layout.sidebarWidth, 220)
        XCTAssertGreaterThanOrEqual(TonicDS.Layout.minControlTarget, 36)
        XCTAssertGreaterThanOrEqual(TonicDS.Layout.minRowHeight, 44)
    }

    func testTonicDSRadiusScalePreservesDataCardSignature() {
        XCTAssertEqual(TonicDS.Radius.sm, 8)
        XCTAssertEqual(TonicDS.Radius.md, 12)
        XCTAssertEqual(TonicDS.Radius.lg, 16)
        XCTAssertEqual(TonicDS.Radius.card, 22)
        XCTAssertGreaterThan(TonicDS.Radius.pill, TonicDS.Radius.card)
    }

    func testTonicDSMotionTimingMatchesDesignSpec() {
        XCTAssertEqual(TonicDS.Motion.instant, 0.10)
        XCTAssertEqual(TonicDS.Motion.feedback, 0.14)
        XCTAssertEqual(TonicDS.Motion.transition, 0.21)
        XCTAssertEqual(TonicDS.Motion.layout, 0.27)
        XCTAssertEqual(TonicDS.Motion.proof, 0.39)
        XCTAssertEqual(TonicDS.Motion.stagger, 0.05)
    }

    func testTonicDSTypographyMatchesDesignSpecTracking() {
        XCTAssertEqual(TonicDS.TypeRole.heroDisplay.size, 40)
        XCTAssertEqual(TonicDS.TypeRole.sectionDisplay.size, 28)
        XCTAssertEqual(TonicDS.TypeRole.cardHeading.size, 17)
        XCTAssertEqual(TonicDS.TypeRole.heroDisplay.tracking, -0.70, accuracy: 0.001)
        XCTAssertEqual(TonicDS.TypeRole.sectionDisplay.tracking, -0.35, accuracy: 0.001)
        XCTAssertEqual(TonicDS.TypeRole.cardHeading.tracking, -0.10, accuracy: 0.001)
        XCTAssertEqual(TonicDS.TypeRole.monoLabel.tracking, 0.50, accuracy: 0.001)
    }

    func testMenuBarConsoleDimensionsMatchDesignSpec() {
        XCTAssertEqual(TonicDS.Layout.MenuBar.width, 280)
        XCTAssertEqual(TonicDS.Layout.MenuBar.maxHeight, 420)
        XCTAssertEqual(TonicDS.Layout.MenuBar.compactHeight, 22)
        XCTAssertEqual(TonicDS.Layout.MenuBar.rowHeight, 28)
        XCTAssertEqual(TonicDS.Layout.MenuBar.chartHeight, 58)
    }
}
