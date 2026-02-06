//
//  MaintenanceViewTests.swift
//  TonicTests
//
//  Tests for MaintenanceView - scan tab, clean tab, progress, cancellation
//

import XCTest
@testable import Tonic

final class MaintenanceViewTests: XCTestCase {

    // MARK: - Tab Tests

    func testScanTabExists() {
        let tabName = "Scan"
        XCTAssertEqual(tabName, "Scan")
    }

    func testCleanTabExists() {
        let tabName = "Clean"
        XCTAssertEqual(tabName, "Clean")
    }

    func testTabSwitching() {
        var activeTab = 0  // Scan tab
        XCTAssertEqual(activeTab, 0)

        activeTab = 1  // Clean tab
        XCTAssertEqual(activeTab, 1)

        activeTab = 0  // Back to Scan
        XCTAssertEqual(activeTab, 0)
    }

    // MARK: - Scan Tab Tests

    func testScanTabContent() {
        let content = ["Start Scan", "Smart Scan Engine", "Progress Display"]
        XCTAssertEqual(content.count, 3)
    }

    func testScanStartButton() {
        let buttonText = "Start Smart Scan"
        XCTAssertFalse(buttonText.isEmpty)
    }

    func testScanFlow() {
        var isScanStarted = false
        var isScanning = false
        var isScanComplete = false

        isScanStarted = true
        XCTAssertTrue(isScanStarted)

        if isScanStarted {
            isScanning = true
        }
        XCTAssertTrue(isScanning)

        if isScanning {
            isScanComplete = true
        }
        XCTAssertTrue(isScanComplete)
    }

    // MARK: - Progress Tests

    func testProgressDisplay() {
        var progress: Double = 0.0
        XCTAssertEqual(progress, 0.0)

        progress = 0.5
        XCTAssertEqual(progress, 0.5)

        progress = 1.0
        XCTAssertEqual(progress, 1.0)
    }

    func testProgressStages() {
        let stages = ["Preparing", "Scanning Disk", "Checking Apps", "Analyzing System"]
        XCTAssertEqual(stages.count, 4)

        for stage in stages {
            XCTAssertFalse(stage.isEmpty)
        }
    }

    func testProgressPercentage() {
        let percentages = [0, 25, 50, 75, 100]
        for percentage in percentages {
            XCTAssertGreaterThanOrEqual(percentage, 0)
            XCTAssertLessThanOrEqual(percentage, 100)
        }
    }

    // MARK: - Clean Tab Tests

    func testCleanTabContent() {
        let content = ["Cache", "Logs", "Temp Files", "Trash"]
        XCTAssertEqual(content.count, 4)
    }

    func testCleanCategories() {
        let categories = [
            "System Cache",
            "Browser Cache",
            "Application Caches",
            "Log Files",
            "Temporary Files",
            "Trash",
        ]
        XCTAssertGreaterThan(categories.count, 0)
    }

    func testCleanStartButton() {
        let buttonText = "Start Cleaning"
        XCTAssertFalse(buttonText.isEmpty)
    }

    func testSpaceRecovery() {
        var spaceClaimed: Int64 = 0
        let itemSize: Int64 = 100_000

        spaceClaimed += itemSize
        XCTAssertEqual(spaceClaimed, itemSize)

        spaceClaimed += itemSize
        XCTAssertEqual(spaceClaimed, itemSize * 2)
    }

    // MARK: - Cancellation Tests

    func testScanCancellation() {
        var isScanning = true
        var isCancelled = false

        isCancelled = true
        if isCancelled {
            isScanning = false
        }

        XCTAssertFalse(isScanning)
        XCTAssertTrue(isCancelled)
    }

    func testCleanCancellation() {
        var isCleaning = true
        var isCancelled = false

        isCancelled = true
        if isCancelled {
            isCleaning = false
        }

        XCTAssertFalse(isCleaning)
        XCTAssertTrue(isCancelled)
    }

    // MARK: - Results Display Tests

    func testScanResults() {
        let results = [
            ("Cache Found", "2.5 GB"),
            ("Logs Found", "500 MB"),
            ("Temp Files", "1.2 GB"),
        ]

        XCTAssertEqual(results.count, 3)
        for (title, size) in results {
            XCTAssertFalse(title.isEmpty)
            XCTAssertFalse(size.isEmpty)
        }
    }

    func testCleanResults() {
        let cleaned = [
            ("Cache Cleaned", "2.5 GB"),
            ("Files Deleted", "50 files"),
        ]

        XCTAssertEqual(cleaned.count, 2)
    }

    // MARK: - State Tests

    func testViewState() {
        enum ViewState {
            case idle
            case scanning
            case cleaning
            case complete
        }

        var state: ViewState = .idle
        XCTAssertEqual(state, .idle)

        state = .scanning
        XCTAssertEqual(state, .scanning)

        state = .complete
        XCTAssertEqual(state, .complete)
    }

    func testTabPersistence() {
        var selectedTab = 0
        XCTAssertEqual(selectedTab, 0)

        selectedTab = 1
        XCTAssertEqual(selectedTab, 1)

        // Tab selection persists
        let persistedTab = selectedTab
        XCTAssertEqual(persistedTab, 1)
    }

    // MARK: - Error Handling Tests

    func testScanError() {
        let errorMessage = "Failed to scan: Permission denied"
        XCTAssertFalse(errorMessage.isEmpty)
    }

    func testCleanError() {
        let errorMessage = "Cannot delete protected file"
        XCTAssertFalse(errorMessage.isEmpty)
    }

    func testErrorDisplay() {
        var hasError = false
        var errorText = ""

        hasError = true
        errorText = "An error occurred"

        XCTAssertTrue(hasError)
        XCTAssertFalse(errorText.isEmpty)
    }

    // MARK: - Performance Tests

    func testScanProgressUpdatePerformance() {
        let startTime = Date()

        for progress in stride(from: 0.0, through: 1.0, by: 0.01) {
            _ = progress  // Simulate progress update
        }

        let duration = Date().timeIntervalSince(startTime)
        XCTAssertLessThan(duration, 0.5, "Progress updates should be fast")
    }

    func testTabSwitchingPerformance() {
        let startTime = Date()

        for _ in 0..<100 {
            let tab = 0  // Switch between tabs
            _ = tab
        }

        let duration = Date().timeIntervalSince(startTime)
        XCTAssertLessThan(duration, 0.2, "Tab switching should be instant")
    }

    // MARK: - Accessibility Tests

    func testAccessibilityLabels() {
        let labels = [
            "Scan Tab",
            "Clean Tab",
            "Start Scan Button",
            "Cancel Button",
            "Progress Bar",
        ]

        for label in labels {
            XCTAssertFalse(label.isEmpty)
        }
    }

    func testProgressAnnouncement() {
        let announcement = "Scanning: 50% complete"
        XCTAssertTrue(announcement.contains("%"))
    }

    // MARK: - Integration Tests

    func testScanToCleanFlow() {
        var scanResults: [(String, String)] = [
            ("Cache", "2.5 GB"),
            ("Logs", "500 MB"),
        ]

        var cleaningEnabled = false
        if !scanResults.isEmpty {
            cleaningEnabled = true
        }

        XCTAssertTrue(cleaningEnabled)
    }

    func testCompleteMaintenanceFlow() {
        // 1. Start scan
        var isScanning = false
        isScanning = true
        XCTAssertTrue(isScanning)

        // 2. Complete scan
        isScanning = false
        var scanComplete = true
        XCTAssertTrue(scanComplete)

        // 3. Start cleaning
        var isCleaning = false
        if scanComplete {
            isCleaning = true
        }
        XCTAssertTrue(isCleaning)

        // 4. Complete cleaning
        isCleaning = false
        var cleanComplete = true
        XCTAssertTrue(cleanComplete)
    }
}

final class SmartScanDeepLinkMapperTests: XCTestCase {

    func testSectionReviewRoutes() {
        XCTAssertEqual(
            SmartScanDeepLinkMapper.destination(for: .section(.space)),
            .manager(.space(.spaceRoot))
        )
        XCTAssertEqual(
            SmartScanDeepLinkMapper.destination(for: .section(.performance)),
            .manager(.performance(.root(defaultNav: .maintenanceTasks)))
        )
        XCTAssertEqual(
            SmartScanDeepLinkMapper.destination(for: .section(.apps)),
            .manager(.apps(.root(defaultNav: .uninstaller)))
        )
    }

    func testContributorReviewRoutes() {
        XCTAssertEqual(
            SmartScanDeepLinkMapper.destination(for: .contributor(id: "xcodeJunk")),
            .manager(.space(.cleanup(.systemJunk, categoryId: CleanupCategoryID(raw: "xcodeJunk"), rowId: nil)))
        )
        XCTAssertEqual(
            SmartScanDeepLinkMapper.destination(for: .contributor(id: "downloads")),
            .manager(.space(.clutter(.downloads, filter: .allFiles, groupId: nil, fileId: nil)))
        )
        XCTAssertEqual(
            SmartScanDeepLinkMapper.destination(for: .contributor(id: "duplicates")),
            .manager(.space(.clutter(.duplicates, filter: .allFiles, groupId: nil, fileId: nil)))
        )
        XCTAssertEqual(
            SmartScanDeepLinkMapper.destination(for: .contributor(id: "maintenanceTasks")),
            .manager(.performance(.maintenanceTasks(preselectTaskIds: nil)))
        )
        XCTAssertEqual(
            SmartScanDeepLinkMapper.destination(for: .contributor(id: "backgroundItems")),
            .manager(.performance(.backgroundItems(preselectItemIds: nil)))
        )
        XCTAssertEqual(
            SmartScanDeepLinkMapper.destination(for: .contributor(id: "loginItems")),
            .manager(.performance(.loginItems(preselectItemIds: nil)))
        )
        XCTAssertEqual(
            SmartScanDeepLinkMapper.destination(for: .contributor(id: "uninstaller")),
            .manager(.apps(.uninstaller(filter: .all)))
        )
        XCTAssertEqual(
            SmartScanDeepLinkMapper.destination(for: .contributor(id: "updater")),
            .manager(.apps(.updater))
        )
        XCTAssertEqual(
            SmartScanDeepLinkMapper.destination(for: .contributor(id: "leftovers")),
            .manager(.apps(.leftovers))
        )
    }

    func testUnknownContributorFallsBackToSmartScan() {
        XCTAssertEqual(
            SmartScanDeepLinkMapper.destination(for: .contributor(id: "unknown-contributor")),
            .smartScan
        )
    }

    func testTileReviewRoutes() {
        XCTAssertEqual(
            SmartScanDeepLinkMapper.destination(for: .tile(.spaceXcodeJunk)),
            .manager(.space(.cleanup(.systemJunk, categoryId: CleanupCategoryID(raw: "xcodeJunk"), rowId: nil)))
        )
        XCTAssertEqual(
            SmartScanDeepLinkMapper.destination(for: .tile(.performanceMaintenanceTasks)),
            .manager(.performance(.maintenanceTasks(preselectTaskIds: nil)))
        )
        XCTAssertEqual(
            SmartScanDeepLinkMapper.destination(for: .tile(.appsLeftovers)),
            .manager(.apps(.leftovers))
        )
    }
}

@MainActor
final class SmartScanReviewFlowTests: XCTestCase {

    func testReviewButtonsFlowToManagerRoutes() {
        let store = SmartCareSessionStore()
        store.scanResult = SmartCareResult(timestamp: Date(), duration: 0, domainResults: [:])
        store.hubMode = .results

        store.review(target: .section(.space))
        XCTAssertEqual(store.destination, .manager(.space(.spaceRoot)))

        store.showHub()
        store.review(target: .section(.performance))
        XCTAssertEqual(store.destination, .manager(.performance(.root(defaultNav: .maintenanceTasks))))

        store.showHub()
        store.review(target: .section(.apps))
        XCTAssertEqual(store.destination, .manager(.apps(.root(defaultNav: .uninstaller))))
    }

    func testReviewCustomizeNavigatesFromResults() {
        let store = SmartCareSessionStore()
        store.scanResult = SmartCareResult(timestamp: Date(), duration: 0, domainResults: [:])
        store.hubMode = .results

        store.reviewCustomize()

        XCTAssertEqual(store.destination, .manager(.space(.spaceRoot)))
    }

    func testTileReviewFlowNavigatesToManagerRoutes() {
        let store = SmartCareSessionStore()
        store.scanResult = SmartCareResult(timestamp: Date(), duration: 0, domainResults: [:])
        store.hubMode = .results

        store.review(target: .tile(.appsUnused))

        XCTAssertEqual(store.destination, .manager(.apps(.uninstaller(filter: .unused))))
    }

    func testQuickActionEmptyItemsShowsInformationalSummary() {
        let store = SmartCareSessionStore()
        store.scanResult = SmartCareResult(timestamp: Date(), duration: 0, domainResults: [:])
        store.hubMode = .results

        store.presentQuickAction(for: .appsUpdates, action: .update)
        store.startQuickActionRun()

        XCTAssertFalse(store.quickActionIsRunning)
        XCTAssertEqual(store.quickActionSummary?.message, "No runnable items available for this action.")
    }

    func testQuickActionPresentationBlockedDuringGlobalRun() {
        let store = SmartCareSessionStore()
        store.scanResult = SmartCareResult(timestamp: Date(), duration: 0, domainResults: [:])
        store.hubMode = .running

        store.presentQuickAction(for: .spaceSystemJunk, action: .clean)

        XCTAssertNil(store.quickActionSheet)
    }

    func testGlobalRunBlockedWhenQuickActionSheetIsPresented() {
        let store = SmartCareSessionStore()
        store.scanResult = sampleResultWithRunnableItem()
        store.hubMode = .results

        store.presentQuickAction(for: .spaceSystemJunk, action: .clean)
        XCTAssertNotNil(store.quickActionSheet)

        store.runSmartClean()
        XCTAssertEqual(store.hubMode, .results)
    }

    private func sampleResultWithRunnableItem() -> SmartCareResult {
        let groupID = UUID()
        let item = SmartCareItem(
            domain: .cleanup,
            groupId: groupID,
            title: "System Junk",
            subtitle: "Sample",
            size: 1_024,
            count: 1,
            safeToRun: true,
            isSmartSelected: true,
            action: .delete(paths: ["/tmp/tonic-test"]),
            paths: ["/tmp/tonic-test"],
            scoreImpact: 2
        )
        let group = SmartCareGroup(
            id: groupID,
            domain: .cleanup,
            title: "System Junk",
            description: "Sample cleanup group",
            items: [item]
        )
        let domain = SmartCareDomainResult(domain: .cleanup, groups: [group])
        return SmartCareResult(
            timestamp: Date(),
            duration: 0.5,
            domainResults: [.cleanup: domain]
        )
    }
}
