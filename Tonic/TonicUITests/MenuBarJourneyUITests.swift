import XCTest

@MainActor
final class MenuBarJourneyUITests: XCTestCase {
    private func launch(completedSetup: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-open-menu-bar"]
        if completedSetup { app.launchArguments.append("--ui-test-completed-menu-bar-setup") }
        app.launch()
        return app
    }

    func testThreeStepSetupIsKeyboardReachable() {
        let app = launch()
        let step: (Int) -> XCUIElement = { number in
            app.descendants(matching: .any)["menu-bar-setup-step-\(number)"]
        }
        XCTAssertTrue(step(1).waitForExistence(timeout: 5))
        app.typeKey(.tab, modifierFlags: [])
        XCTAssertTrue(app.buttons["Continue"].exists)
        app.buttons["Continue"].click()
        XCTAssertTrue(step(2).waitForExistence(timeout: 2))
        app.buttons["Continue"].click()
        XCTAssertTrue(step(3).waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Apply Cleanup"].exists || app.buttons["Allow & Apply Cleanup"].exists)
    }

    func testLayoutPaletteAndApplyAreKeyboardReachable() {
        let app = launch(completedSetup: true)
        XCTAssertTrue(app.otherElements["menu-bar-layout-editor"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Spacer"].exists)
        app.buttons["Spacer"].click()
        XCTAssertTrue(app.buttons["Apply Layout"].waitForExistence(timeout: 2))
        app.typeKey(.tab, modifierFlags: [])
        XCTAssertTrue(app.buttons["Apply Layout"].isEnabled)
    }
}
