import XCTest
@testable import Tonic

final class NetworkTrafficChartTests: XCTestCase {
    func testMaxMagnitudeUsesBothDirectionsAndFallsBackForZeroTraffic() {
        XCTAssertEqual(
            NetworkTrafficChartScale.maxMagnitude(downloadData: [100, 250], uploadData: [40, 900]),
            900
        )
        XCTAssertEqual(
            NetworkTrafficChartScale.maxMagnitude(downloadData: [0], uploadData: [0]),
            1
        )
    }

    func testMaxMagnitudeIgnoresInvalidAndNonPositiveSamples() {
        XCTAssertEqual(
            NetworkTrafficChartScale.maxMagnitude(
                downloadData: [.nan, .infinity, -10, 0, 100],
                uploadData: [50]
            ),
            100
        )
        XCTAssertEqual(
            NetworkTrafficChartScale.maxMagnitude(
                downloadData: [.nan, -.infinity],
                uploadData: [-50, 0]
            ),
            1
        )
    }

    func testZeroAndInvalidValuesStayOnBaseline() {
        XCTAssertEqual(
            NetworkTrafficChartScale.normalizedMagnitude(
                0,
                maxMagnitude: 100,
                minimumVisibleFraction: 0.16
            ),
            0
        )
        XCTAssertEqual(
            NetworkTrafficChartScale.normalizedMagnitude(
                .nan,
                maxMagnitude: 100,
                minimumVisibleFraction: 0.16
            ),
            0
        )
        XCTAssertEqual(
            NetworkTrafficChartScale.normalizedMagnitude(
                .infinity,
                maxMagnitude: 100,
                minimumVisibleFraction: 0.16
            ),
            0
        )
        XCTAssertEqual(
            NetworkTrafficChartScale.normalizedMagnitude(
                -20,
                maxMagnitude: 100,
                minimumVisibleFraction: 0.16
            ),
            0
        )
    }

    func testCompactModeKeepsSmallNonzeroTrafficVisible() {
        let normalized = NetworkTrafficChartScale.normalizedMagnitude(
            1,
            maxMagnitude: 1_000,
            minimumVisibleFraction: NetworkTrafficChartMode.compactMenuBar.minimumVisibleFraction
        )

        XCTAssertEqual(normalized, 0.16, accuracy: 0.001)
    }

    func testMonitorModeUsesTruthfulSharedMagnitudeScaling() {
        let normalized = NetworkTrafficChartScale.normalizedMagnitude(
            100,
            maxMagnitude: 1_000,
            minimumVisibleFraction: NetworkTrafficChartMode.monitorCard.minimumVisibleFraction
        )

        XCTAssertEqual(normalized, 0.1, accuracy: 0.001)
    }
}
