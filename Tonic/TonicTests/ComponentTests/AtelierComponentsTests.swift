import XCTest
@testable import Tonic

final class AtelierComponentsTests: XCTestCase {

    func testAtelierButtonStateTokens() {
        let normal = AtelierStateStyles.button(for: .normal)
        let hover = AtelierStateStyles.button(for: .hover)
        let pressed = AtelierStateStyles.button(for: .pressed)
        let disabled = AtelierStateStyles.button(for: .disabled)

        XCTAssertEqual(normal.scale, 1)
        XCTAssertGreaterThan(hover.scale, normal.scale)
        XCTAssertLessThan(pressed.scale, normal.scale)
        XCTAssertLessThan(disabled.opacity, normal.opacity)
    }

    func testAtelierWorldTokenCoverage() {
        for world in TonicWorld.allCases {
            let token = AtelierTokens.World.token(for: world)
            XCTAssertFalse(token.darkMode.darkHex.isEmpty)
            XCTAssertFalse(token.darkMode.midHex.isEmpty)
            XCTAssertFalse(token.darkMode.lightHex.isEmpty)
            XCTAssertFalse(token.lightMode.darkHex.isEmpty)
            XCTAssertFalse(token.lightMode.midHex.isEmpty)
            XCTAssertFalse(token.lightMode.lightHex.isEmpty)
        }
    }

    func testAtelierLayoutScales() {
        XCTAssertGreaterThan(AtelierLayout.radiusLg, AtelierLayout.radiusMd)
        XCTAssertGreaterThan(AtelierLayout.radiusMd, AtelierLayout.radiusSm)
        XCTAssertGreaterThan(AtelierLayout.lg, AtelierLayout.md)
    }
}
