import XCTest
@testable import Tonic

final class MenuBarPresetTests: XCTestCase {

    func testLayoutDiffExcludesUnchangedKeys() {
        let current: [String: MenuBarSection] = ["a": .visible, "b": .hidden, "c": .visible]
        let target: [String: MenuBarSection] = ["a": .visible, "b": .visible, "c": .alwaysHidden]
        let diff = MenuBarPresetPlanner.layoutDiff(current: current, target: target)
        XCTAssertEqual(diff, ["b": .visible, "c": .alwaysHidden])
    }

    func testLayoutDiffSkipsMissingCurrentKeys() {
        // A target key with no known current section is still a move.
        let diff = MenuBarPresetPlanner.layoutDiff(current: [:], target: ["x": .hidden])
        XCTAssertEqual(diff, ["x": .hidden])
    }

    func testLayoutDiffEmptyWhenIdentical() {
        let layout: [String: MenuBarSection] = ["a": .visible, "b": .hidden]
        XCTAssertTrue(MenuBarPresetPlanner.layoutDiff(current: layout, target: layout).isEmpty)
    }

    func testPresetRoundTrip() throws {
        let preset = MenuBarPreset(name: "Work", symbolName: "briefcase",
                                   layout: ["com.acme.App": .hidden, "com.other.App": .alwaysHidden])
        let data = try JSONEncoder().encode(preset)
        let decoded = try JSONDecoder().decode(MenuBarPreset.self, from: data)
        XCTAssertEqual(decoded, preset)
    }

    func testSectionCodableRawValues() throws {
        for section in MenuBarSection.allCases {
            let data = try JSONEncoder().encode(section)
            let decoded = try JSONDecoder().decode(MenuBarSection.self, from: data)
            XCTAssertEqual(decoded, section)
        }
    }
}
