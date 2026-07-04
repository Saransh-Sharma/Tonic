import XCTest
@testable import Tonic

final class MenuBarNetworkWidgetTests: XCTestCase {
    func testNetworkWidgetUsesBidirectionalChartAndSessionTotals() throws {
        // The popover console renders the paired series through the traffic chart…
        let popoverSource = try source("Tonic/Tonic/MenuBarWidgets/WidgetStatusItem.swift")
        XCTAssertTrue(popoverSource.contains("NetworkTrafficChart("))
        XCTAssertTrue(popoverSource.contains("snapshot.traffic"))
        XCTAssertTrue(popoverSource.contains("traffic.primary"))
        XCTAssertTrue(popoverSource.contains("traffic.secondary"))

        // …and the snapshot builds the network series + session totals.
        let snapshotSource = try source("Tonic/Tonic/MenuBarWidgets/WidgetMetricSnapshot.swift")
        XCTAssertTrue(snapshotSource.contains("networkDownloadHistory"))
        XCTAssertTrue(snapshotSource.contains("networkUploadHistory"))
        XCTAssertTrue(snapshotSource.contains("\"Today while open\""))
        XCTAssertTrue(snapshotSource.contains("\"Down total\""))
        XCTAssertTrue(snapshotSource.contains("\"Up total\""))
        XCTAssertTrue(snapshotSource.contains("dataManager.totalDownloadBytes"))
        XCTAssertTrue(snapshotSource.contains("dataManager.totalUploadBytes"))
        XCTAssertFalse(snapshotSource.contains("built.append(.chart(uploadHistory"))
    }

    private func source(_ relativePath: String) throws -> String {
        let testFile = URL(fileURLWithPath: #filePath)
        let projectRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = projectRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }
}
