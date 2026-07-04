import XCTest
@testable import Tonic

final class SemanticVersionTests: XCTestCase {

    func testNumericOrdering() {
        XCTAssertTrue(SemanticVersion("1.9") < SemanticVersion("1.10"))
        XCTAssertTrue(SemanticVersion("1.2.3") < SemanticVersion("1.2.4"))
        XCTAssertTrue(SemanticVersion("2.0") < SemanticVersion("10.0"))
        XCTAssertFalse(SemanticVersion("1.10") < SemanticVersion("1.9"))
    }

    func testShorterVersionsPadWithZeros() {
        XCTAssertEqual(SemanticVersion("1.2"), SemanticVersion("1.2.0"))
        XCTAssertTrue(SemanticVersion("1.2") < SemanticVersion("1.2.1"))
    }

    func testVPrefixIsIgnored() {
        XCTAssertEqual(SemanticVersion("v2.0"), SemanticVersion("2.0"))
        XCTAssertTrue(SemanticVersion("v1.9") < SemanticVersion("2.0"))
    }

    func testPrereleaseOrdersBelowRelease() {
        XCTAssertTrue(SemanticVersion("1.2.0b3") < SemanticVersion("1.2.0"))
        XCTAssertTrue(SemanticVersion("3.5-beta.2") < SemanticVersion("3.5"))
        XCTAssertTrue(SemanticVersion("1.0-beta.1") < SemanticVersion("1.0-beta.2"))
    }

    func testLongBuildStyleVersions() {
        XCTAssertTrue(SemanticVersion("141.0.7390.54") < SemanticVersion("141.0.7390.55"))
    }

    func testEmptyAndGarbageInput() {
        XCTAssertTrue(SemanticVersion("").isEmpty)
        XCTAssertTrue(SemanticVersion("not-a-version").isEmpty)
        XCTAssertFalse(SemanticVersion("1").isEmpty)
    }

    // MARK: - AppUpdate.compareVersions bridge

    func testCompareVersionsUpdateAvailable() {
        XCTAssertEqual(AppUpdate.compareVersions("1.0", "1.1"), .updateAvailable)
    }

    func testCompareVersionsUpToDate() {
        XCTAssertEqual(AppUpdate.compareVersions("2.3.1", "2.3.1"), .upToDate)
    }

    func testCompareVersionsBetaAheadOfFeed() {
        XCTAssertEqual(AppUpdate.compareVersions("2.0-beta.3", "1.9"), .beta)
    }

    func testCompareVersionsUnknownForNilOrGarbage() {
        XCTAssertEqual(AppUpdate.compareVersions(nil, "1.0"), .unknown)
        XCTAssertEqual(AppUpdate.compareVersions("garbage", "1.0"), .unknown)
    }

    /// Regression guard for the old regex bug: a "latest version" of "1.0"
    /// scraped from the XML declaration must never mark newer apps updatable.
    func testXMLDeclarationRegressionShape() {
        XCTAssertEqual(AppUpdate.compareVersions("3.2.1", "1.0"), .beta)
        XCTAssertNotEqual(AppUpdate.compareVersions("3.2.1", "1.0"), .updateAvailable)
    }
}
