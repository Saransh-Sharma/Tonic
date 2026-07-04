import XCTest
@testable import Tonic

final class NetworkPerProcessSamplerTests: XCTestCase {

    func testParsesNettopCSV() {
        let fixture = """
        ,bytes_in,bytes_out,
        launchd.1,0,0,
        mDNSResponder.426,161357628,78966900,
        My App With Spaces.9999,123,456,
        """
        let rows = NetworkPerProcessSampler.parse(fixture)
        XCTAssertEqual(rows.count, 3, "header row must be skipped")
        XCTAssertEqual(rows[1].key, "mDNSResponder.426")
        XCTAssertEqual(rows[1].bytesIn, 161_357_628)
        XCTAssertEqual(rows[1].bytesOut, 78_966_900)
        XCTAssertEqual(rows[2].key, "My App With Spaces.9999")
    }

    func testMalformedLinesAreSkipped() {
        let fixture = """
        garbage line without commas
        name.1,notanumber,5,
        good.2,10,20,
        """
        let rows = NetworkPerProcessSampler.parse(fixture)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].key, "good.2")
    }
}
