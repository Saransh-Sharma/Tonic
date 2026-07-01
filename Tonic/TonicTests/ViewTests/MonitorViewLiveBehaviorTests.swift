import XCTest
@testable import Tonic

@MainActor
final class MonitorViewLiveBehaviorTests: XCTestCase {
    func testMonitorInitialRangeDefaultsToLive() {
        XCTAssertEqual(MonitorView.initialResourceHistoryRangeForTesting, .live)
    }

    func testMonitorViewRepairsLiveMonitoringOnActivationPaths() throws {
        let source = try monitorViewSource()

        XCTAssertTrue(source.contains("ensureLiveMonitoring(\"MonitorView.onAppear\")"))
        XCTAssertTrue(source.contains(".onChange(of: isActive)"))
        XCTAssertTrue(source.contains("ensureLiveMonitoring(\"MonitorView active\")"))
        XCTAssertTrue(source.contains(".onChange(of: selectedRange)"))
        XCTAssertTrue(source.contains("ensureLiveMonitoring(\"MonitorView live selected\")"))
        XCTAssertTrue(source.contains("ensureLiveMonitoring(\"MonitorView retry\")"))
    }

    func testMonitorLiveRenderingUsesExplicitLiveSampleHealth() throws {
        let source = try monitorViewSource()

        XCTAssertTrue(source.contains("return data.hasLiveMetricSample"))
        XCTAssertFalse(source.contains("return !data.cpuHistory.isEmpty"))
    }

    private func monitorViewSource() throws -> String {
        let testFile = URL(fileURLWithPath: #filePath)
        let projectRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = projectRoot.appendingPathComponent("Tonic/Tonic/Views/Monitor/MonitorView.swift")
        return try String(contentsOf: url, encoding: .utf8)
    }
}
