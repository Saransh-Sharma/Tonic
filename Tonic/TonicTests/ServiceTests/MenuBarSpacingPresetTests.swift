#if !TONIC_STORE
import XCTest
@testable import Tonic

final class MenuBarSpacingPresetTests: XCTestCase {

    func testPresetValues() {
        XCTAssertEqual(MenuBarSpacingPreset.system.values.spacing, nil)
        XCTAssertEqual(MenuBarSpacingPreset.compact.values.spacing, 8)
        XCTAssertEqual(MenuBarSpacingPreset.compact.values.padding, 6)
        XCTAssertEqual(MenuBarSpacingPreset.tight.values.spacing, 4)
        XCTAssertEqual(MenuBarSpacingPreset.tight.values.padding, 3)
    }

    func testMatchingRoundTrip() {
        for preset in MenuBarSpacingPreset.allCases {
            let values = preset.values
            XCTAssertEqual(MenuBarSpacingPreset.matching(spacing: values.spacing, padding: values.padding), preset)
        }
    }

    func testUnknownValuesFallBackToSystem() {
        XCTAssertEqual(MenuBarSpacingPreset.matching(spacing: 99, padding: 99), .system)
    }
}
#endif
