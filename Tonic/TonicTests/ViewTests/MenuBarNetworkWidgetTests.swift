import XCTest
@testable import Tonic

final class MenuBarNetworkWidgetTests: XCTestCase {
    func testNetworkWidgetUsesBidirectionalChartAndSessionTotals() throws {
        let source = try widgetStatusItemSource()

        XCTAssertTrue(source.contains("NetworkTrafficChart("))
        XCTAssertTrue(source.contains("snapshot.networkDownloadHistory"))
        XCTAssertTrue(source.contains("snapshot.networkUploadHistory"))
        XCTAssertTrue(source.contains("\"Today while open\""))
        XCTAssertTrue(source.contains("\"Down total\""))
        XCTAssertTrue(source.contains("\"Up total\""))
        XCTAssertTrue(source.contains("dataManager.totalDownloadBytes"))
        XCTAssertTrue(source.contains("dataManager.totalUploadBytes"))
        XCTAssertFalse(source.contains("built.append(.chart(uploadHistory"))
    }

    private func widgetStatusItemSource() throws -> String {
        let testFile = URL(fileURLWithPath: #filePath)
        let projectRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = projectRoot.appendingPathComponent("Tonic/Tonic/MenuBarWidgets/WidgetStatusItem.swift")
        return try String(contentsOf: url, encoding: .utf8)
    }
}
