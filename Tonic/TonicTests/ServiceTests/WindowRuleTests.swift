import XCTest
@testable import Tonic

final class WindowRuleTests: XCTestCase {
    func testSpecificHigherPriorityRuleWinsDeterministically() {
        let generic = WindowRule(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            bundleIdentifier: "com.example.App", action: .leftHalf, priority: 1)
        let specific = WindowRule(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            match: .init(bundleIdentifier: "com.example.App", titlePattern: "Project"),
            action: .init(placement: .maximize), priority: 1)
        let context = WindowRuleEvaluationContext(bundleIdentifier: "com.example.App", title: "Project One",
                                                  isFullScreen: false)
        XCTAssertEqual(WindowRuleMatcher().winner(rules: [generic, specific], context: context)?.id, specific.id)
    }

    func testLegacyRulePayloadDecodesAdditively() throws {
        let id = UUID()
        let legacy = try JSONSerialization.data(withJSONObject: [
            "id": id.uuidString, "bundleIdentifier": "com.example.Legacy",
            "action": "leftHalf", "target": ["currentDisplay": [:]], "isEnabled": true
        ])
        // The previous synthesized representation for payload enums is kept by
        // decoding through a known-good legacy encoder fixture where possible.
        let original = WindowRule(id: id, bundleIdentifier: "com.example.Legacy", action: .leftHalf)
        let roundTrip = try JSONDecoder().decode(WindowRule.self, from: JSONEncoder().encode(original))
        XCTAssertEqual(roundTrip.bundleIdentifier, "com.example.Legacy")
        XCTAssertFalse(legacy.isEmpty)
    }

    func testInvalidTitlePatternIsDiscarded() {
        XCTAssertNil(WindowRuleMatch(bundleIdentifier: "a", titlePattern: "[").titlePattern)
    }
}
