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

    // MARK: - Wave 4 window slots

    func testAllCasesCoverAppSlotsAndEveryWindowAction() {
        let cases = HotkeyAction.allCases
        XCTAssertEqual(cases.count, 4 + WindowAction.allCases.count)
        XCTAssertTrue(cases.contains(.topShelf), "missing Wave 5 Top Shelf hotkey slot")
        for action in WindowAction.allCases {
            XCTAssertTrue(cases.contains(.window(action)), "missing hotkey slot for \(action.rawValue)")
        }
    }

    func testStorageKeyRoundTripsForEveryAction() {
        for action in HotkeyAction.allCases {
            XCTAssertEqual(HotkeyAction(storageKey: action.storageKey), action)
        }
        XCTAssertNil(HotkeyAction(storageKey: "window.notARealAction"))
        XCTAssertNil(HotkeyAction(storageKey: "garbage"))
    }

    func testLegacyPersistedPayloadStillDecodesToOriginalSlots() {
        // A pre-Wave-4 `tonic.hotkeys` blob: rawValue keys, three slots.
        let legacy = [
            "toggleConsole": "46:256",
            "quickSearch": "49:4352",
            "toggleMenuBar": "11:2048"
        ]
        let decoded = HotkeySettingsStore.actionsByStorageKey(legacy)
        XCTAssertEqual(decoded[.toggleConsole], "46:256")
        XCTAssertEqual(decoded[.quickSearch], "49:4352")
        XCTAssertEqual(decoded[.toggleMenuBar], "11:2048")
        XCTAssertEqual(decoded.count, 3)
    }

    func testUnknownStorageKeysAreDroppedNotFatal() {
        let payload = ["someFutureAction": "1:256", "toggleConsole": "46:256"]
        let decoded = HotkeySettingsStore.actionsByStorageKey(payload)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[.toggleConsole], "46:256")
    }

    func testLegacyHotKeyIDsAreStableAndWindowIDsStartAt100() {
        XCTAssertEqual(HotkeyAction.toggleConsole.hotKeyID, 1)
        XCTAssertEqual(HotkeyAction.quickSearch.hotKeyID, 2)
        XCTAssertEqual(HotkeyAction.toggleMenuBar.hotKeyID, 3)
        for action in WindowAction.allCases {
            let id = HotkeyAction.window(action).hotKeyID
            XCTAssertGreaterThanOrEqual(id, 100, "\(action.rawValue) must use the explicit 100+ table")
        }
    }

    func testRecommendedDefaultsAreDistinctCombos() {
        let specs = HotkeyAction.allCases.compactMap(\.recommendedDefault).map(\.stringValue)
        XCTAssertEqual(Set(specs).count, specs.count, "recommended defaults must not collide")
        XCTAssertFalse(specs.isEmpty)
    }

    func testHotkeyActionCodableUsesStorageKey() throws {
        let action = HotkeyAction.window(.leftThird)
        let data = try JSONEncoder().encode(action)
        XCTAssertEqual(String(data: data, encoding: .utf8), "\"window.leftThird\"")
        XCTAssertEqual(try JSONDecoder().decode(HotkeyAction.self, from: data), action)
    }
}
