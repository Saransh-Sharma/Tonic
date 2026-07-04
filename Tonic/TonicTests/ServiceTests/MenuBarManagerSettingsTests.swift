import XCTest
@testable import Tonic

final class MenuBarManagerSettingsTests: XCTestCase {

    func testDefaults() {
        let settings = MenuBarManagerSettings.default
        XCTAssertFalse(settings.isEnabled)
        XCTAssertFalse(settings.alwaysHiddenSectionEnabled)
        XCTAssertTrue(settings.autoRehide)
        XCTAssertEqual(settings.rehideDelaySeconds, 15)
        XCTAssertFalse(settings.showOnHover)
        XCTAssertFalse(settings.showOnClickEmptyMenuBar)
    }

    func testRoundTrip() throws {
        var settings = MenuBarManagerSettings.default
        settings.isEnabled = true
        settings.showOnHover = true
        settings.hoverDelaySeconds = 0.5
        settings.rehideDelaySeconds = 30
        settings.alwaysHiddenSectionEnabled = true

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(MenuBarManagerSettings.self, from: data)
        XCTAssertEqual(decoded, settings)
    }

    func testInitClampsRanges() {
        let settings = MenuBarManagerSettings(hoverDelaySeconds: 99, rehideDelaySeconds: 0.5)
        XCTAssertEqual(settings.hoverDelaySeconds, 2)
        XCTAssertEqual(settings.rehideDelaySeconds, 2)
    }

    func testDecodingUnknownPayloadFallsBackToDefaults() throws {
        let decoded = try JSONDecoder().decode(MenuBarManagerSettings.self, from: Data("{}".utf8))
        XCTAssertEqual(decoded, .default)
    }

    func testNewFieldsDefaultWhenAbsentFromOldJSON() throws {
        // A settings blob written before revealMode/styling existed.
        let legacy = """
        {"isEnabled":true,"autoRehide":false,"rehideDelaySeconds":40}
        """
        let decoded = try JSONDecoder().decode(MenuBarManagerSettings.self, from: Data(legacy.utf8))
        XCTAssertTrue(decoded.isEnabled)
        XCTAssertFalse(decoded.autoRehide)
        XCTAssertEqual(decoded.rehideDelaySeconds, 40)
        XCTAssertEqual(decoded.revealMode, .expand)
        XCTAssertFalse(decoded.styling.isEnabled)
    }

    func testRevealModeAndStylingRoundTrip() throws {
        var settings = MenuBarManagerSettings.default
        settings.revealMode = .tonicBar
        settings.styling = MenuBarStyling(isEnabled: true, tintHex: "#112233", usesGradient: true, cornerRadius: 8, opacity: 0.7)
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(MenuBarManagerSettings.self, from: data)
        XCTAssertEqual(decoded, settings)
    }
}
