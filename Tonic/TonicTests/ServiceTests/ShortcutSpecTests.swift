import Carbon.HIToolbox
import XCTest
@testable import Tonic

final class ShortcutSpecTests: XCTestCase {

    func testStringRoundTrip() {
        let spec = ShortcutSpec(keyCode: 46, carbonModifiers: UInt32(cmdKey | shiftKey))
        let restored = ShortcutSpec(string: spec.stringValue)
        XCTAssertEqual(restored, spec)
    }

    func testRejectsMalformedStrings() {
        XCTAssertNil(ShortcutSpec(string: ""))
        XCTAssertNil(ShortcutSpec(string: "46"))
        XCTAssertNil(ShortcutSpec(string: "a:b"))
        XCTAssertNil(ShortcutSpec(string: "46:256:9"))
    }

    func testDisplayStringOrdersModifiers() {
        let spec = ShortcutSpec(
            keyCode: UInt32(kVK_Space),
            carbonModifiers: UInt32(cmdKey | shiftKey | optionKey | controlKey)
        )
        XCTAssertEqual(spec.displayString, "⌃⌥⇧⌘Space")
    }

    func testSpecialKeyNames() {
        XCTAssertEqual(ShortcutSpec.keyName(for: UInt32(kVK_Escape)), "⎋")
        XCTAssertEqual(ShortcutSpec.keyName(for: UInt32(kVK_UpArrow)), "↑")
        XCTAssertEqual(ShortcutSpec.keyName(for: UInt32(kVK_F5)), "F5")
    }
}
