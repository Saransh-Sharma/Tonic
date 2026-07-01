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
        XCTAssertEqual(TonicDS.Motion.fast, 0.15)
        XCTAssertEqual(TonicDS.Motion.normal, 0.25)
        XCTAssertEqual(TonicDS.Motion.slow, 0.35)
        XCTAssertEqual(TonicDS.Motion.stagger, 0.05)
    }
}
