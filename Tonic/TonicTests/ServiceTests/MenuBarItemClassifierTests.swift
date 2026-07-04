import XCTest
@testable import Tonic

final class MenuBarItemClassifierTests: XCTestCase {

    // MARK: - Fixtures

    private func windowDict(
        layer: Int = 25,
        pid: Int32 = 500,
        windowID: UInt32 = 42,
        x: CGFloat = 1200,
        y: CGFloat = 0,
        width: CGFloat = 30,
        height: CGFloat = 24,
        owner: String = "SomeApp",
        onScreen: Bool = true
    ) -> [String: Any] {
        [
            kCGWindowLayer as String: layer,
            kCGWindowOwnerPID as String: pid,
            kCGWindowNumber as String: windowID,
            kCGWindowOwnerName as String: owner,
            kCGWindowIsOnscreen as String: onScreen,
            kCGWindowBounds as String: [
                "X": x, "Y": y, "Width": width, "Height": height
            ]
        ]
    }

    private func item(
        midX: CGFloat,
        windowID: UInt32 = 1,
        system: Bool = false
    ) -> MenuBarItemInfo {
        MenuBarItemInfo(
            windowID: windowID,
            ownerPID: 500,
            ownerName: system ? "Control Center" : "SomeApp",
            frame: CGRect(x: midX - 15, y: 0, width: 30, height: 24),
            isOnScreen: true,
            isSystemControlled: system,
            section: nil
        )
    }

    // MARK: - Parsing

    func testParsesStatusBarWindow() {
        let info = MenuBarItemClassifier.parseWindowInfo(windowDict(), ownPID: 100)
        XCTAssertNotNil(info)
        XCTAssertEqual(info?.ownerName, "SomeApp")
        XCTAssertEqual(info?.frame.width, 30)
        XCTAssertEqual(info?.windowID, 42)
        XCTAssertFalse(info?.isSystemControlled ?? true)
    }

    func testRejectsWrongLayer() {
        XCTAssertNil(MenuBarItemClassifier.parseWindowInfo(windowDict(layer: 0), ownPID: 100))
    }

    func testRejectsOwnWindows() {
        XCTAssertNil(MenuBarItemClassifier.parseWindowInfo(windowDict(pid: 100), ownPID: 100))
    }

    func testRejectsWindowsOutsideMenuBarBand() {
        // A status-level window lower on screen (e.g. an overlay) is not a menu bar item.
        XCTAssertNil(MenuBarItemClassifier.parseWindowInfo(windowDict(y: 400), ownPID: 100))
        // Oversized panels are not items either.
        XCTAssertNil(MenuBarItemClassifier.parseWindowInfo(windowDict(height: 200), ownPID: 100))
        XCTAssertNil(MenuBarItemClassifier.parseWindowInfo(windowDict(width: 900), ownPID: 100))
    }

    func testFlagsSystemOwners() {
        let info = MenuBarItemClassifier.parseWindowInfo(windowDict(owner: "Control Center"), ownPID: 100)
        XCTAssertEqual(info?.isSystemControlled, true)
    }

    // MARK: - Classification (expanded layout)

    func testClassifiesAroundSeparator() {
        // Layout: alwaysHidden(200) · AH-sep(400) · hidden(600) · sep(800) · visible(1200)
        let items = [
            item(midX: 200, windowID: 1),
            item(midX: 600, windowID: 2),
            item(midX: 1200, windowID: 3)
        ]
        let classified = MenuBarItemClassifier.classify(
            items: items,
            separatorMinX: 800,
            alwaysHiddenMinX: 400
        )
        XCTAssertEqual(classified[0].section, .alwaysHidden)
        XCTAssertEqual(classified[1].section, .hidden)
        XCTAssertEqual(classified[2].section, .visible)
    }

    func testClassifiesCollapsedOffscreenPositions() {
        // Collapsed: separator inflates to 10,000 pt, pushing hidden items far
        // past the left edge — x ordering is preserved, just shifted negative.
        let items = [
            item(midX: -19_000, windowID: 1),  // beyond the always-hidden separator
            item(midX: -9_000, windowID: 2),   // hidden section
            item(midX: 1200, windowID: 3)      // visible
        ]
        let classified = MenuBarItemClassifier.classify(
            items: items,
            separatorMinX: -8_500,
            alwaysHiddenMinX: -18_500
        )
        XCTAssertEqual(classified[0].section, .alwaysHidden)
        XCTAssertEqual(classified[1].section, .hidden)
        XCTAssertEqual(classified[2].section, .visible)
    }

    func testSystemItemsAlwaysClassifyVisible() {
        let classified = MenuBarItemClassifier.classify(
            items: [item(midX: 100, system: true)],
            separatorMinX: 800,
            alwaysHiddenMinX: nil
        )
        XCTAssertEqual(classified[0].section, .visible)
    }

    func testNoSeparatorsMeansEverythingVisible() {
        let classified = MenuBarItemClassifier.classify(
            items: [item(midX: 100), item(midX: 1400)],
            separatorMinX: nil,
            alwaysHiddenMinX: nil
        )
        XCTAssertTrue(classified.allSatisfy { $0.section == .visible })
    }

    func testAlwaysHiddenDisabledFallsBackToHidden() {
        let classified = MenuBarItemClassifier.classify(
            items: [item(midX: 100)],
            separatorMinX: 800,
            alwaysHiddenMinX: nil
        )
        XCTAssertEqual(classified[0].section, .hidden)
    }
}
