import Carbon.HIToolbox
import XCTest
@testable import Tonic

final class HotkeySettingsStoreTests: XCTestCase {

    func testHotkeyActionIDsAreDistinct() {
        let ids = HotkeyAction.allCases.map(\.hotKeyID)
        XCTAssertEqual(Set(ids).count, ids.count, "each action needs a unique EventHotKeyID")
    }

    func testShortcutSpecRoundTripThroughStoreString() {
        let spec = ShortcutSpec(keyCode: 46, carbonModifiers: UInt32(cmdKey | shiftKey))
        let restored = ShortcutSpec(string: spec.stringValue)
        XCTAssertEqual(restored, spec)
    }

    func testActionTitlesAreNonEmpty() {
        for action in HotkeyAction.allCases {
            XCTAssertFalse(action.title.isEmpty)
            XCTAssertFalse(action.subtitle.isEmpty)
        }
    }
}
