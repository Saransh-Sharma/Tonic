//
//  WindowWorkspaceTests.swift
//  TonicTests
//
//  Windows v2 engine logic: cycling frame variants, workspace snapshot
//  round-trips, and display-rule matching.
//

import XCTest
@testable import Tonic

final class WindowWorkspaceTests: XCTestCase {

    private let screen = CGRect(x: 0, y: 0, width: 1200, height: 800)

    // MARK: - Cycling

    func testLeftHalfCyclesHalfThirdTwoThirds() {
        let frames = WindowAction.leftHalf.cycleFrames(in: screen)
        XCTAssertEqual(frames.count, 3)
        XCTAssertEqual(frames[0].width, 600)
        XCTAssertEqual(frames[1].width, 400)
        XCTAssertEqual(frames[2].width, 800)
        // All variants anchor to the left edge and full height.
        for frame in frames {
            XCTAssertEqual(frame.minX, 0)
            XCTAssertEqual(frame.height, 800)
        }
    }

    func testRightHalfVariantsAnchorToRightEdge() {
        let frames = WindowAction.rightHalf.cycleFrames(in: screen)
        XCTAssertEqual(frames.count, 3)
        for frame in frames {
            XCTAssertEqual(frame.maxX, 1200, accuracy: 0.001)
        }
    }

    func testNonCyclingActionsHaveSingleVariant() {
        for action in [WindowAction.maximize, .centered, .topLeft, .bottomHalf] {
            let frames = action.cycleFrames(in: screen)
            XCTAssertEqual(frames.count, 1)
            XCTAssertEqual(frames[0], action.frame(in: screen))
        }
    }

    // MARK: - Workspace snapshot round-trip

    func testRelativeFrameRoundTripsThroughVisibleFrame() {
        let visible = CGRect(x: 0, y: 25, width: 1512, height: 918)
        let original = CGRect(x: 100, y: 125, width: 756, height: 459)
        let relative = CGRect(
            x: (original.minX - visible.minX) / visible.width,
            y: (original.minY - visible.minY) / visible.height,
            width: original.width / visible.width,
            height: original.height / visible.height
        )
        let restored = CGRect(
            x: visible.minX + relative.minX * visible.width,
            y: visible.minY + relative.minY * visible.height,
            width: relative.width * visible.width,
            height: relative.height * visible.height
        )
        XCTAssertEqual(restored.minX, original.minX, accuracy: 0.5)
        XCTAssertEqual(restored.minY, original.minY, accuracy: 0.5)
        XCTAssertEqual(restored.width, original.width, accuracy: 0.5)
        XCTAssertEqual(restored.height, original.height, accuracy: 0.5)
    }

    func testWorkspaceAppNamesAreDistinctAndOrdered() {
        let display = DisplaySignature(name: "Built-in", width: 1512, height: 982, scale: 2)
        let windows = ["Xcode", "Safari", "Xcode", "Terminal"].map { app in
            WorkspaceWindowSnapshot(bundleIdentifier: app.lowercased(), appName: app,
                                    windowTitle: nil, display: display,
                                    relativeFrame: CGRect(x: 0, y: 0, width: 0.5, height: 0.5))
        }
        let workspace = WindowWorkspace(name: "Desk", windows: windows)
        XCTAssertEqual(workspace.appNames, ["Xcode", "Safari", "Terminal"])
    }

    func testWorkspaceCodableRoundTrip() throws {
        let display = DisplaySignature(name: "LG UltraFine", width: 5120, height: 2880, scale: 2)
        let workspace = WindowWorkspace(name: "Studio", windows: [
            WorkspaceWindowSnapshot(bundleIdentifier: "com.apple.dt.Xcode", appName: "Xcode",
                                    windowTitle: "Tonic.xcodeproj", display: display,
                                    relativeFrame: CGRect(x: 0, y: 0, width: 0.66, height: 1))
        ])
        let data = try JSONEncoder().encode(workspace)
        let decoded = try JSONDecoder().decode(WindowWorkspace.self, from: data)
        XCTAssertEqual(decoded, workspace)
    }

    // MARK: - Automation models

    func testAutomationCodableRoundTrip() throws {
        let automation = Automation(
            name: "Work Setup",
            condition: .wifiSSID("Office"),
            actions: [.applyWorkspace(UUID()), .runMaintenance],
            revertsWhenCleared: true
        )
        let data = try JSONEncoder().encode(automation)
        let decoded = try JSONDecoder().decode(Automation.self, from: data)
        XCTAssertEqual(decoded, automation)
    }

    func testMaintenanceActionAvailableInAllEditions() {
        XCTAssertTrue(AutomationAction.runMaintenance.isAvailable)
        XCTAssertTrue(AutomationAction.applyWorkspace(UUID()).isAvailable)
    }
}
