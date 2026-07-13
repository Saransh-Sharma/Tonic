import XCTest
@testable import Tonic

final class TonicProductArchitectureTests: XCTestCase {
    func testEveryToolBelongsToAStableHub() {
        let hubs = Set(TonicToolID.allCases.map(\.hub))
        XCTAssertEqual(hubs, Set(TonicHub.allCases))
    }

    func testStoreEditionReportsDirectOnlyCapabilitiesHonestly() {
        let registry = CapabilityRegistry(edition: .store)
        XCTAssertEqual(
            registry.availability(of: .advancedMenuBarControl),
            .editionRestricted(required: .direct)
        )
        XCTAssertEqual(
            registry.availability(of: .privilegedMaintenance),
            .editionRestricted(required: .direct)
        )
    }

    func testWaveFiveCommercialAvailabilityIsAlwaysUnlocked() {
        let authority = FeatureAvailabilityAuthority.current
        for feature in TonicFeatureID.allCases {
            XCTAssertEqual(authority.availability(of: feature), .unlocked)
            XCTAssertTrue(authority.availability(of: feature).isUnlocked)
        }
    }

    func testWindowActionsStayInsideVisibleFrame() {
        let visibleFrame = CGRect(x: -1200, y: 40, width: 1200, height: 800)

        for action in WindowAction.allCases {
            let result = action.frame(in: visibleFrame)
            XCTAssertGreaterThan(result.width, 0, action.title)
            XCTAssertGreaterThan(result.height, 0, action.title)
            XCTAssertTrue(visibleFrame.contains(result), "\(action.title) escaped the display: \(result)")
        }
    }

    func testActionReceiptRoundTripsUndoProof() throws {
        let receipt = ActionReceipt(
            tool: .windows,
            title: "Placed Finder",
            detail: "Left Half on Studio Display",
            impact: "756×982",
            undo: .available(token: "restore-token", expiresAt: nil),
            metadata: ["before": "900×700", "after": "756×982"]
        )

        let data = try JSONEncoder().encode(receipt)
        let decoded = try JSONDecoder().decode(ActionReceipt.self, from: data)
        XCTAssertEqual(decoded, receipt)
    }

    func testCommandAliasesFindDailyControlVocabulary() {
        let windows = CommandDescriptor.toolCommands.first { $0.route == .tool(.windows) }
        let menuBar = CommandDescriptor.toolCommands.first { $0.route == .tool(.menuBar) }
        XCTAssertTrue(windows?.aliases.contains("snap") == true)
        XCTAssertTrue(menuBar?.aliases.contains("hide icons") == true)
    }
}
