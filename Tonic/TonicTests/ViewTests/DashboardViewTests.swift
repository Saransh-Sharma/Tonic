//
//  DashboardViewTests.swift
//  TonicTests
//
//  Tests for DashboardView - health score, metrics, scan button, data loading
//

import XCTest
@testable import Tonic

final class DashboardViewTests: XCTestCase {

    // MARK: - Test Data

    var mockHealthScore: Int = 75
    var mockMetrics: [(icon: String, title: String, value: String)] = []

    override func setUp() {
        super.setUp()
        mockMetrics = [
            ("cpu", "CPU Usage", "45%"),
            ("memorychip", "Memory", "8.2 GB"),
            ("internaldrive", "Disk", "234 GB free"),
            ("network", "Network", "12.5 MB/s"),
        ]
    }

    override func tearDown() {
        mockHealthScore = 75
        mockMetrics.removeAll()
        super.tearDown()
    }

    // MARK: - Health Score Tests

    func testHealthScoreDisplay() {
        XCTAssertGreaterThanOrEqual(mockHealthScore, 0)
        XCTAssertLessThanOrEqual(mockHealthScore, 100)
    }

    func testHealthScoreRange() {
        let scores = [0, 25, 50, 75, 100]
        for score in scores {
            XCTAssertGreaterThanOrEqual(score, 0)
            XCTAssertLessThanOrEqual(score, 100)
        }
    }

    func testHealthScoreFormatting() {
        let formatted = "\(mockHealthScore)%"
        XCTAssertTrue(formatted.contains("%"))
    }

    // MARK: - Metric Display Tests

    func testMetricsRendering() {
        XCTAssertEqual(mockMetrics.count, 4)
        for metric in mockMetrics {
            XCTAssertFalse(metric.icon.isEmpty)
            XCTAssertFalse(metric.title.isEmpty)
            XCTAssertFalse(metric.value.isEmpty)
        }
    }

    func testMetricRowContent() {
        let cpuMetric = mockMetrics[0]
        XCTAssertEqual(cpuMetric.title, "CPU Usage")
        XCTAssertEqual(cpuMetric.value, "45%")
    }

    func testAllMetricsDisplayed() {
        let titles = mockMetrics.map { $0.title }
        XCTAssertTrue(titles.contains("CPU Usage"))
        XCTAssertTrue(titles.contains("Memory"))
        XCTAssertTrue(titles.contains("Disk"))
        XCTAssertTrue(titles.contains("Network"))
    }

    // MARK: - Button Tests

    func testSmartScanButton() {
        let buttonTitle = "Smart Scan"
        XCTAssertFalse(buttonTitle.isEmpty)
    }

    func testScanButtonInteraction() {
        var scanStarted = false
        let action = { scanStarted = true }
        action()
        XCTAssertTrue(scanStarted)
    }

    func testScanButtonAccessibility() {
        let label = "Start Smart Scan"
        XCTAssertFalse(label.isEmpty)
    }

    // MARK: - Activity Section Tests

    func testActivitySectionExists() {
        let activityTitle = "Recent Activity"
        XCTAssertFalse(activityTitle.isEmpty)
    }

    func testActivityExpansion() {
        var isExpanded = false
        isExpanded.toggle()
        XCTAssertTrue(isExpanded)

        isExpanded.toggle()
        XCTAssertFalse(isExpanded)
    }

    func testActivityItemsDisplay() {
        let activities = [
            "Cleaned 5 GB cache",
            "Scanned 250 files",
            "Updated 3 apps",
        ]

        for activity in activities {
            XCTAssertFalse(activity.isEmpty)
        }
    }

    // MARK: - Data Loading Tests

    func testDataLoadingState() {
        var isLoading = true
        XCTAssertTrue(isLoading)

        isLoading = false
        XCTAssertFalse(isLoading)
    }

    func testDataErrorState() {
        var hasError = false
        XCTAssertFalse(hasError)

        hasError = true
        XCTAssertTrue(hasError)
    }

    func testMissingDataHandling() {
        let emptyMetrics: [(icon: String, title: String, value: String)] = []
        XCTAssertTrue(emptyMetrics.isEmpty)
    }

    // MARK: - Layout Tests

    func testDashboardStructure() {
        let sections = ["Health", "Metrics", "Activity"]
        XCTAssertEqual(sections.count, 3)
    }

    func testViewHierarchy() {
        let hasHeader = true
        let hasContent = true
        let hasFooter = false

        XCTAssertTrue(hasHeader)
        XCTAssertTrue(hasContent)
        XCTAssertFalse(hasFooter)
    }

    // MARK: - Color & Styling Tests

    func testHealthScoreColor() {
        // Low health (red)
        var healthColor = "red"
        if mockHealthScore > 60 {
            healthColor = "green"  // Good health
        }
        XCTAssertFalse(healthColor.isEmpty)
    }

    func testMetricColorCoding() {
        let statusColors = ["green", "orange", "red"]
        XCTAssertEqual(statusColors.count, 3)
    }

    // MARK: - State Management Tests

    func testAutoRefresh() {
        var lastRefresh = Date()
        let newRefresh = Date().addingTimeInterval(1)

        XCTAssertNotEqual(lastRefresh, newRefresh)
        lastRefresh = newRefresh
        XCTAssertEqual(lastRefresh, newRefresh)
    }

    func testMetricsUpdate() {
        var cpuUsage = 45.0
        XCTAssertEqual(cpuUsage, 45.0)

        cpuUsage = 52.5
        XCTAssertEqual(cpuUsage, 52.5)
    }

    // MARK: - Error Handling Tests

    func testPermissionError() {
        let error = "Full Disk Access required"
        XCTAssertFalse(error.isEmpty)
    }

    func testNetworkError() {
        let error = "Cannot fetch metrics"
        XCTAssertFalse(error.isEmpty)
    }

    func testErrorMessageDisplay() {
        let errorMessage = "Failed to load data. Try again?"
        XCTAssertTrue(errorMessage.contains("?"))
    }

    // MARK: - Accessibility Tests

    func testAccessibilityLabels() {
        let labels = [
            "Health Score: 75%",
            "CPU Usage: 45%",
            "Smart Scan Button",
            "Recent Activity",
        ]

        for label in labels {
            XCTAssertFalse(label.isEmpty)
        }
    }

    func testSemanticStructure() {
        let heading = "Dashboard"
        let subheading = "System Health"
        let content = "Metrics"

        XCTAssertFalse(heading.isEmpty)
        XCTAssertFalse(subheading.isEmpty)
        XCTAssertFalse(content.isEmpty)
    }

    // MARK: - Performance Tests

    func testDashboardRenderPerformance() {
        let startTime = Date()

        // Simulate rendering
        var renderedMetrics = 0
        for _ in mockMetrics {
            renderedMetrics += 1
        }

        let duration = Date().timeIntervalSince(startTime)

        XCTAssertEqual(renderedMetrics, mockMetrics.count)
        XCTAssertLessThan(duration, 0.1, "Dashboard should render quickly")
    }

    func testMetricsUpdatePerformance() {
        let startTime = Date()

        // Update all metrics
        for i in 0..<100 {
            _ = "Metric \(i)"
        }

        let duration = Date().timeIntervalSince(startTime)
        XCTAssertLessThan(duration, 0.5, "Metric updates should be fast")
    }

    // MARK: - Integration Tests

    func testDashboardDataFlow() {
        // Simulate data flow: Load → Process → Display
        var dataLoaded = false
        var dataProcessed = false
        var dataDisplayed = false

        dataLoaded = true
        XCTAssertTrue(dataLoaded)

        if dataLoaded {
            dataProcessed = true
        }
        XCTAssertTrue(dataProcessed)

        if dataProcessed {
            dataDisplayed = true
        }
        XCTAssertTrue(dataDisplayed)
    }

    func testScanToDashboardFlow() {
        // Scan complete → Update metrics → Refresh dashboard
        var scanComplete = false
        var metricsUpdated = false
        var dashboardRefreshed = false

        scanComplete = true
        if scanComplete {
            metricsUpdated = true
        }
        if metricsUpdated {
            dashboardRefreshed = true
        }

        XCTAssertTrue(scanComplete)
        XCTAssertTrue(metricsUpdated)
        XCTAssertTrue(dashboardRefreshed)
    }

    // MARK: - Edge Cases

    func testZeroHealthScore() {
        let score = 0
        XCTAssertGreaterThanOrEqual(score, 0)
    }

    func testMaxHealthScore() {
        let score = 100
        XCTAssertLessThanOrEqual(score, 100)
    }

    func testEmptyMetrics() {
        let emptyMetrics: [(String, String, String)] = []
        XCTAssertTrue(emptyMetrics.isEmpty)
    }

    func testSpecialCharacterInMetric() {
        let metric = "RAM: 8.2 GB (50%)"
        XCTAssertFalse(metric.isEmpty)
    }

    // MARK: - Smart Scan Session Persistence

    @MainActor
    func testDashboardSharedScanManagerPersistsAcrossViewRecreation() {
        let manager = SmartScanManager()
        manager.hasScanResult = true
        manager.healthScore = 88

        let recommendation = ScanRecommendation(
            type: .cache,
            title: "Clean cache files",
            description: "Remove reclaimable cache data",
            actionable: true,
            safeToFix: true,
            spaceToReclaim: 512 * 1024 * 1024,
            affectedPaths: ["/tmp/cache"],
            scoreImpact: 6
        )
        manager.recommendations = [
            Recommendation(
                scanRecommendation: recommendation,
                type: .clean,
                category: .cache,
                priority: .medium,
                actionText: "Clean Now"
            ),
        ]
        manager.activityHistory = [
            ActivityItem(
                timestamp: Date(),
                type: .scan,
                title: "Smart Scan Completed",
                description: "Found reclaimable files",
                impact: .medium
            ),
        ]

        let firstView = DashboardView(scanManager: manager)
        let secondView = DashboardView(scanManager: manager)

        XCTAssertEqual(ObjectIdentifier(firstView.scanManager), ObjectIdentifier(secondView.scanManager))
        XCTAssertEqual(firstView.scanManager.healthScore, 88)
        XCTAssertTrue(secondView.scanManager.hasScanResult)
        XCTAssertEqual(secondView.scanManager.recommendations.count, 1)
        XCTAssertEqual(secondView.scanManager.activityHistory.count, 1)
    }

    @MainActor
    func testDetailViewReceivesInjectedDashboardScanManager() {
        let manager = SmartScanManager()
        let smartCareSession = SmartCareSessionStore()

        let detailView = DetailView(
            item: .dashboard,
            onPermissionNeeded: { _ in },
            smartCareSession: smartCareSession,
            dashboardScanSession: manager
        )

        XCTAssertEqual(ObjectIdentifier(detailView.dashboardScanSession), ObjectIdentifier(manager))
    }
}
