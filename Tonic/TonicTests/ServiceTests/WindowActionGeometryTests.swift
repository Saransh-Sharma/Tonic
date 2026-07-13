//
//  WindowActionGeometryTests.swift
//  TonicTests
//
//  Pure frame math for the Wave-4 tiling depth: thirds, sixths, gaps,
//  display projection, and cycling variants.
//

import XCTest
@testable import Tonic

final class WindowActionGeometryTests: XCTestCase {

    private let visible = CGRect(x: 0, y: 40, width: 1200, height: 760)

    // MARK: - Thirds

    func testThirdsSpanTheDisplayWithoutOverlap() {
        let left = WindowAction.leftThird.frame(in: visible)
        let center = WindowAction.centerThird.frame(in: visible)
        let right = WindowAction.rightThird.frame(in: visible)

        XCTAssertEqual(left.width, 400, accuracy: 0.5)
        XCTAssertEqual(center.width, 400, accuracy: 0.5)
        XCTAssertEqual(right.width, 400, accuracy: 0.5)
        XCTAssertEqual(left.maxX, center.minX, accuracy: 0.5)
        XCTAssertEqual(center.maxX, right.minX, accuracy: 0.5)
        XCTAssertEqual(left.minX, visible.minX, accuracy: 0.5)
        XCTAssertEqual(right.maxX, visible.maxX, accuracy: 0.5)
        for frame in [left, center, right] {
            XCTAssertEqual(frame.height, visible.height, accuracy: 0.5)
        }
    }

    func testThirdsCycleWalksColumnsFromOwnStart() {
        let fromLeft = WindowAction.leftThird.cycleFrames(in: visible)
        let fromCenter = WindowAction.centerThird.cycleFrames(in: visible)
        XCTAssertEqual(fromLeft.count, 3)
        XCTAssertEqual(fromLeft[0], WindowAction.leftThird.frame(in: visible))
        XCTAssertEqual(fromLeft[1], WindowAction.centerThird.frame(in: visible))
        XCTAssertEqual(fromLeft[2], WindowAction.rightThird.frame(in: visible))
        XCTAssertEqual(fromCenter[0], WindowAction.centerThird.frame(in: visible))
        XCTAssertEqual(fromCenter[2], WindowAction.leftThird.frame(in: visible), "wraps around")
    }

    // MARK: - Sixths

    func testSixthsTileTheDisplayInThreeByTwoGrid() {
        let sixths: [WindowAction] = [
            .topLeftSixth, .topCenterSixth, .topRightSixth,
            .bottomLeftSixth, .bottomCenterSixth, .bottomRightSixth
        ]
        var union = CGRect.null
        for action in sixths {
            let frame = action.frame(in: visible)
            XCTAssertEqual(frame.width, visible.width / 3, accuracy: 0.5, action.title)
            XCTAssertEqual(frame.height, visible.height / 2, accuracy: 0.5, action.title)
            XCTAssertTrue(visible.contains(frame.insetBy(dx: 0.1, dy: 0.1)), action.title)
            union = union.union(frame)
        }
        XCTAssertEqual(union, visible, "the six tiles must cover the visible frame exactly")

        let top = WindowAction.topLeftSixth.frame(in: visible)
        let bottom = WindowAction.bottomLeftSixth.frame(in: visible)
        XCTAssertEqual(bottom.maxY, top.minY, accuracy: 0.5)
    }

    // MARK: - Gaps

    func testGapInsetsScreenEdgesFullyAndSharedEdgesByHalf() {
        let gap: CGFloat = 16
        let left = WindowTilingGeometry.applyingGap(
            WindowAction.leftHalf.frame(in: visible), gap: gap, in: visible)
        let right = WindowTilingGeometry.applyingGap(
            WindowAction.rightHalf.frame(in: visible), gap: gap, in: visible)

        XCTAssertEqual(left.minX, visible.minX + gap, accuracy: 0.5)
        XCTAssertEqual(left.minY, visible.minY + gap, accuracy: 0.5)
        XCTAssertEqual(left.maxY, visible.maxY - gap, accuracy: 0.5)
        XCTAssertEqual(right.maxX, visible.maxX - gap, accuracy: 0.5)
        // Adjacent tiles end up exactly `gap` apart.
        XCTAssertEqual(right.minX - left.maxX, gap, accuracy: 0.5)
    }

    func testZeroGapIsIdentity() {
        let frame = WindowAction.topRight.frame(in: visible)
        XCTAssertEqual(WindowTilingGeometry.applyingGap(frame, gap: 0, in: visible), frame)
    }

    func testDegenerateGapFallsBackToOriginalFrame() {
        let tiny = CGRect(x: 0, y: 40, width: 60, height: 60)
        let result = WindowTilingGeometry.applyingGap(tiny, gap: 24, in: visible)
        XCTAssertEqual(result, tiny, "a gap that would collapse the frame is ignored")
    }

    func testMaximizeWithGapKeepsUniformMargin() {
        let gap: CGFloat = 8
        let framed = WindowTilingGeometry.applyingGap(visible, gap: gap, in: visible)
        XCTAssertEqual(framed, visible.insetBy(dx: gap, dy: gap))
    }

    // MARK: - Display projection

    func testProjectionPreservesRelativeFrameAcrossDisplays() {
        let source = CGRect(x: 0, y: 40, width: 1200, height: 760)
        let destination = CGRect(x: 1200, y: 0, width: 2560, height: 1415)
        // Left half of the source display.
        let window = CGRect(x: 0, y: 40, width: 600, height: 760)

        let projected = WindowTilingGeometry.projecting(window, from: source, onto: destination)
        XCTAssertEqual(projected.minX, destination.minX, accuracy: 0.5)
        XCTAssertEqual(projected.width, destination.width / 2, accuracy: 0.5)
        XCTAssertEqual(projected.height, destination.height, accuracy: 0.5)
    }

    func testProjectionFromDegenerateSourceFallsBackToDestination() {
        let destination = CGRect(x: 0, y: 0, width: 800, height: 600)
        let projected = WindowTilingGeometry.projecting(
            CGRect(x: 0, y: 0, width: 100, height: 100),
            from: .zero,
            onto: destination
        )
        XCTAssertEqual(projected, destination)
    }

    // MARK: - Display-move actions

    func testDisplayMovesAreFlaggedAndEverythingElseIsNot() {
        XCTAssertTrue(WindowAction.nextDisplay.isDisplayMove)
        XCTAssertTrue(WindowAction.previousDisplay.isDisplayMove)
        for action in WindowAction.allCases where !action.isDisplayMove {
            XCTAssertFalse(action.isDisplayMove)
        }
        XCTAssertEqual(WindowAction.allCases.filter(\.isDisplayMove).count, 2)
    }
}
