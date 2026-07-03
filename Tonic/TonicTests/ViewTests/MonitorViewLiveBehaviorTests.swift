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

    /// GPU/Battery/Sensors readers are `popupOnly` in WidgetDataManager; without MonitorView
    /// opting itself into `popupVisibleModules`, those consoles freeze after the first sample.
    func testMonitorViewKeepsPopupOnlyReadersLiveWhileVisible() throws {
        let source = try monitorViewSource()

        XCTAssertTrue(source.contains(".onDisappear"))
        XCTAssertTrue(source.contains("setMonitorPopupVisibility"))
        XCTAssertTrue(source.contains("data.setPopupVisible(for: type, isVisible: visible)"))
        XCTAssertTrue(source.contains("[.gpu, .battery, .sensors]"))
    }

    func testMonitorLiveRenderingUsesExplicitLiveSampleHealth() throws {
        let source = try monitorViewSource()

        XCTAssertTrue(source.contains("return data.hasLiveMetricSample"))
        XCTAssertFalse(source.contains("return !data.cpuHistory.isEmpty"))
    }

    func testMonitorNetworkSurfaceUsesBidirectionalTrafficAndSessionTotals() throws {
        let source = try monitorViewSource()

        XCTAssertTrue(source.contains("NetworkTrafficCard("))
        XCTAssertTrue(source.contains("downloadHistory: networkDownloadSeries"))
        XCTAssertTrue(source.contains("uploadHistory: networkUploadSeries"))
        XCTAssertTrue(source.contains("context: networkTrafficCardContext"))
        XCTAssertTrue(source.contains("\"Today while open\""))
        XCTAssertFalse(source.contains("ChartCard(label: \"Network ↓\""))
    }

    func testNetworkTrafficCardLiveContextIncludesSessionTotals() {
        let context = NetworkTrafficCardContext.live(downTotal: "10 MB", upTotal: "2 MB")

        XCTAssertTrue(context.includesSessionTotals)
        XCTAssertNil(context.rangeLabel)
        XCTAssertEqual(
            context.footer,
            .sessionTotals(downTotal: "10 MB", upTotal: "2 MB", label: "Today while open")
        )
    }

    func testNetworkTrafficCardHistoryContextExcludesSessionTotals() {
        let context = NetworkTrafficCardContext.history(range: .twentyFourHours)

        XCTAssertFalse(context.includesSessionTotals)
        XCTAssertEqual(context.rangeLabel, "History range: 24h")
        XCTAssertEqual(context.footer, .range("History range: 24h"))
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
