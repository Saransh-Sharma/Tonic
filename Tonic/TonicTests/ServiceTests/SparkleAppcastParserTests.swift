import XCTest
@testable import Tonic

final class SparkleAppcastParserTests: XCTestCase {

    // MARK: - Fixtures

    /// Modern enclosure-attribute style (the common shape the old regex missed).
    private let attributeStyleFeed = """
    <?xml version="1.0" encoding="utf-8"?>
    <rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
      <channel>
        <title>App Changelog</title>
        <item>
          <title>Version 3.5.2</title>
          <pubDate>Wed, 01 Jan 2025 10:00:00 +0000</pubDate>
          <enclosure url="https://example.com/App-3.5.2.zip"
                     sparkle:version="3520"
                     sparkle:shortVersionString="3.5.2"
                     length="12345678"
                     sparkle:edSignature="abc123"
                     type="application/octet-stream"/>
        </item>
        <item>
          <title>Version 3.5.1</title>
          <enclosure url="https://example.com/App-3.5.1.zip"
                     sparkle:version="3510"
                     sparkle:shortVersionString="3.5.1"
                     length="12345600"/>
        </item>
      </channel>
    </rss>
    """

    /// Element style with release notes link.
    private let elementStyleFeed = """
    <?xml version="1.0" encoding="utf-8"?>
    <rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
      <channel>
        <item>
          <title>Version 1.4</title>
          <sparkle:version>140</sparkle:version>
          <sparkle:shortVersionString>1.4</sparkle:shortVersionString>
          <sparkle:releaseNotesLink>https://example.com/notes/1.4.html</sparkle:releaseNotesLink>
          <sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>
          <enclosure url="https://example.com/App-1.4.dmg" length="9999"/>
        </item>
      </channel>
    </rss>
    """

    private let channelAndMinOSFeed = """
    <?xml version="1.0" encoding="utf-8"?>
    <rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
      <channel>
        <item>
          <title>Beta 9.0</title>
          <sparkle:channel>beta</sparkle:channel>
          <enclosure url="https://example.com/App-9.0b.zip" sparkle:shortVersionString="9.0-beta.1"/>
        </item>
        <item>
          <title>Future 8.0</title>
          <sparkle:minimumSystemVersion>99.0</sparkle:minimumSystemVersion>
          <enclosure url="https://example.com/App-8.0.zip" sparkle:shortVersionString="8.0"/>
        </item>
        <item>
          <title>Stable 7.2</title>
          <enclosure url="https://example.com/App-7.2.zip" sparkle:shortVersionString="7.2"/>
        </item>
      </channel>
    </rss>
    """

    private func data(_ xml: String) -> Data { Data(xml.utf8) }

    // MARK: - Parsing

    func testParsesAttributeStyleVersions() throws {
        let items = try SparkleAppcastParser.parseItems(from: data(attributeStyleFeed))
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].shortVersionString, "3.5.2")
        XCTAssertEqual(items[0].version, "3520")
        XCTAssertEqual(items[0].enclosureURL?.absoluteString, "https://example.com/App-3.5.2.zip")
        XCTAssertEqual(items[0].enclosureLength, 12_345_678)
        XCTAssertEqual(items[0].edSignature, "abc123")
    }

    func testParsesElementStyleVersions() throws {
        let items = try SparkleAppcastParser.parseItems(from: data(elementStyleFeed))
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].version, "140")
        XCTAssertEqual(items[0].shortVersionString, "1.4")
        XCTAssertEqual(items[0].releaseNotesLink, "https://example.com/notes/1.4.html")
        XCTAssertEqual(items[0].minimumSystemVersion, "13.0")
    }

    /// The heart of the old bug: `version="…"` appears in the XML declaration
    /// and the rss element. The parser must report real versions, never "1.0"
    /// or "2.0" scraped from those attributes.
    func testXMLDeclarationVersionIsNeverMistakenForAppVersion() throws {
        let best = try SparkleAppcastParser.bestItem(from: data(attributeStyleFeed))
        XCTAssertEqual(best.displayVersion, "3.5.2")
        XCTAssertNotEqual(best.displayVersion, "1.0")
        XCTAssertNotEqual(best.displayVersion, "2.0")
    }

    // MARK: - Best-item selection

    func testPicksHighestVersionNotFirstItem() throws {
        // Reverse the item order so the highest version comes last.
        let reversed = attributeStyleFeed
            .replacingOccurrences(of: "3.5.2", with: "TEMP")
            .replacingOccurrences(of: "3.5.1", with: "3.5.2")
            .replacingOccurrences(of: "TEMP", with: "3.5.1")
        let best = try SparkleAppcastParser.bestItem(from: data(reversed))
        XCTAssertEqual(best.displayVersion, "3.5.2")
    }

    func testSkipsNonDefaultChannelsAndIncompatibleOS() throws {
        let best = try SparkleAppcastParser.bestItem(
            from: data(channelAndMinOSFeed),
            currentOS: OperatingSystemVersion(majorVersion: 14, minorVersion: 0, patchVersion: 0)
        )
        XCTAssertEqual(best.displayVersion, "7.2", "beta channel and macOS 99 items must be excluded")
    }

    func testMinimumSystemVersionBoundary() {
        let os14 = OperatingSystemVersion(majorVersion: 14, minorVersion: 2, patchVersion: 0)
        XCTAssertTrue(SparkleAppcastParser.isCompatible("14.0", with: os14))
        XCTAssertTrue(SparkleAppcastParser.isCompatible(nil, with: os14))
        XCTAssertFalse(SparkleAppcastParser.isCompatible("15.0", with: os14))
    }

    func testDefaultChannelRules() {
        XCTAssertTrue(SparkleAppcastParser.isDefaultChannel(nil))
        XCTAssertTrue(SparkleAppcastParser.isDefaultChannel(""))
        XCTAssertTrue(SparkleAppcastParser.isDefaultChannel("release"))
        XCTAssertFalse(SparkleAppcastParser.isDefaultChannel("beta"))
        XCTAssertFalse(SparkleAppcastParser.isDefaultChannel("nightly"))
    }

    // MARK: - Error paths

    func testMalformedXMLThrowsTypedError() {
        XCTAssertThrowsError(try SparkleAppcastParser.parseItems(from: data("<rss><item>"))) { error in
            guard case AppcastError.malformedXML = error else {
                return XCTFail("Expected malformedXML, got \(error)")
            }
        }
    }

    func testFeedWithoutItemsThrows() {
        let empty = """
        <?xml version="1.0"?><rss version="2.0"><channel><title>Empty</title></channel></rss>
        """
        XCTAssertThrowsError(try SparkleAppcastParser.parseItems(from: data(empty))) { error in
            guard case AppcastError.noItems = error else {
                return XCTFail("Expected noItems, got \(error)")
            }
        }
    }

    func testAllItemsIncompatibleThrows() {
        let feed = """
        <?xml version="1.0"?>
        <rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
          <channel><item>
            <sparkle:minimumSystemVersion>99.0</sparkle:minimumSystemVersion>
            <enclosure url="https://example.com/x.zip" sparkle:shortVersionString="1.0"/>
          </item></channel>
        </rss>
        """
        XCTAssertThrowsError(try SparkleAppcastParser.bestItem(from: data(feed))) { error in
            guard case AppcastError.noCompatibleItems = error else {
                return XCTFail("Expected noCompatibleItems, got \(error)")
            }
        }
    }
}
