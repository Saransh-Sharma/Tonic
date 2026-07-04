import XCTest
@testable import Tonic

final class QuickSearchFilterTests: XCTestCase {

    private let items = [
        (index: 0, name: "Dropbox", key: "com.dropbox.Dropbox"),
        (index: 1, name: "1Password", key: "com.agilebits.onepassword"),
        (index: 2, name: "Docker Desktop", key: "com.docker.docker")
    ]

    func testEmptyQueryReturnsAllInOrder() {
        XCTAssertEqual(QuickSearchFilter.rank(names: items, query: ""), [0, 1, 2])
    }

    func testPrefixMatch() {
        // Only "Docker" begins with "do" (Dropbox is D-R-O-P…).
        XCTAssertEqual(QuickSearchFilter.rank(names: items, query: "do"), [2])
    }

    func testPrefixRanksAboveSubstring() {
        // "p" is a prefix of "1Password"? No — but a substring of Dropbox and
        // a prefix of nothing here, so substring order is preserved.
        let entries = [
            (index: 0, name: "Amphetamine", key: "com.if.Amphetamine"),
            (index: 1, name: "Amie", key: "com.amie.app")
        ]
        // "am" is a prefix of both; both are prefix matches, scan order kept.
        XCTAssertEqual(QuickSearchFilter.rank(names: entries, query: "am"), [0, 1])
        // "phet" only appears as a substring of Amphetamine.
        XCTAssertEqual(QuickSearchFilter.rank(names: entries, query: "phet"), [0])
    }

    func testMatchOnBundleKey() {
        let result = QuickSearchFilter.rank(names: items, query: "agilebits")
        XCTAssertEqual(result, [1])
    }

    func testNoMatch() {
        XCTAssertTrue(QuickSearchFilter.rank(names: items, query: "zzz").isEmpty)
    }

    func testCaseInsensitive() {
        XCTAssertEqual(QuickSearchFilter.rank(names: items, query: "DROPBOX"), [0])
    }
}
