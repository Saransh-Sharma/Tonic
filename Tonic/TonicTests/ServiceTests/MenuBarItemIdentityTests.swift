import XCTest
@testable import Tonic

final class MenuBarItemIdentityTests: XCTestCase {

    func testBundleIDWins() {
        XCTAssertEqual(MenuBarItemIdentity.stableKey(bundleID: "com.acme.App", ownerName: "Acme"), "com.acme.App")
    }

    func testFallsBackToOwnerName() {
        XCTAssertEqual(MenuBarItemIdentity.stableKey(bundleID: nil, ownerName: "Acme"), "Acme")
        XCTAssertEqual(MenuBarItemIdentity.stableKey(bundleID: "", ownerName: "Acme"), "Acme")
    }
}
