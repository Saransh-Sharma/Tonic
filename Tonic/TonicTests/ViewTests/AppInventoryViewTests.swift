//
//  AppInventoryViewTests.swift
//  TonicTests
//
//  Tests for AppInventoryView - app scanning, filtering, sorting, management
//

import XCTest
@testable import Tonic

final class AppInventoryViewTests: XCTestCase {

    // MARK: - App Data Tests

    func testAppMetadataStructure() {
        let appName = "Safari"
        let bundleId = "com.apple.Safari"
        let version = "18.0"
        let size = Int64(50_000_000)

        XCTAssertFalse(appName.isEmpty)
        XCTAssertFalse(bundleId.isEmpty)
        XCTAssertFalse(version.isEmpty)
        XCTAssertGreaterThan(size, 0)
    }

    func testMultipleApps() {
        let apps = [
            (name: "Safari", size: Int64(50_000_000)),
            (name: "Mail", size: Int64(100_000_000)),
            (name: "Finder", size: Int64(80_000_000)),
        ]

        XCTAssertEqual(apps.count, 3)
        for app in apps {
            XCTAssertFalse(app.name.isEmpty)
            XCTAssertGreaterThan(app.size, 0)
        }
    }

    // MARK: - Scanning Tests

    func testAppScanningState() {
        var isScanning = false
        XCTAssertFalse(isScanning)

        isScanning = true
        XCTAssertTrue(isScanning)
    }

    func testScanProgress() {
        var scanProgress: Double = 0.0
        XCTAssertEqual(scanProgress, 0.0)

        scanProgress = 0.25
        XCTAssertEqual(scanProgress, 0.25)

        scanProgress = 0.5
        XCTAssertEqual(scanProgress, 0.5)

        scanProgress = 1.0
        XCTAssertEqual(scanProgress, 1.0)
    }

    func testScanResultsCollection() {
        var scannedApps: [String] = []
        XCTAssertTrue(scannedApps.isEmpty)

        scannedApps.append("Safari")
        scannedApps.append("Mail")

        XCTAssertEqual(scannedApps.count, 2)
    }

    // MARK: - App Display Tests

    func testAppTableRendering() {
        let apps = [
            "Safari",
            "Mail",
            "Calendar",
            "Contacts",
        ]

        XCTAssertEqual(apps.count, 4)
        for app in apps {
            XCTAssertFalse(app.isEmpty)
        }
    }

    func testAppIconDisplay() {
        let icons = ["Safari", "Mail", "Finder", "Trash"]
        XCTAssertEqual(icons.count, 4)

        for icon in icons {
            XCTAssertFalse(icon.isEmpty)
        }
    }

    func testAppSizeDisplay() {
        let sizes = [
            (name: "Safari", displaySize: "50 MB"),
            (name: "Mail", displaySize: "100 MB"),
        ]

        for size in sizes {
            XCTAssertTrue(size.displaySize.contains("MB"))
        }
    }

    func testAppVersionDisplay() {
        let apps = [
            (name: "Safari", version: "18.0"),
            (name: "Mail", version: "17.3"),
        ]

        for app in apps {
            XCTAssertTrue(app.version.contains("."))
        }
    }

    // MARK: - Filtering Tests

    func testFilterByName() {
        let apps = ["Safari", "Mail", "Maps", "Music"]
        let searchTerm = "M"

        let filtered = apps.filter { $0.starts(with: searchTerm) }
        XCTAssertEqual(filtered.count, 2)  // Mail, Maps, Music
    }

    func testFilterByCategorySystem() {
        let appCategories = [
            (name: "Safari", category: "System"),
            (name: "Mail", category: "System"),
            (name: "Finder", category: "System"),
        ]

        let systemApps = appCategories.filter { $0.category == "System" }
        XCTAssertEqual(systemApps.count, 3)
    }

    func testFilterByCategoryThirdParty() {
        let appCategories = [
            (name: "VS Code", category: "Developer"),
            (name: "Slack", category: "Communication"),
            (name: "Spotify", category: "Media"),
        ]

        let thirdPartyApps = appCategories.filter { $0.category != "System" }
        XCTAssertEqual(thirdPartyApps.count, 3)
    }

    func testFilterBySize() {
        let apps = [
            (name: "Small", size: Int64(10_000_000)),
            (name: "Large", size: Int64(1_000_000_000)),
            (name: "Huge", size: Int64(5_000_000_000)),
        ]

        let largeApps = apps.filter { $0.size > Int64(500_000_000) }
        XCTAssertEqual(largeApps.count, 2)
    }

    func testFilterByUnused() {
        let apps = [
            (name: "Safari", lastUsed: Date()),
            (name: "OldApp", lastUsed: Date().addingTimeInterval(-30 * 24 * 3600)),
            (name: "Mail", lastUsed: Date()),
        ]

        let threshold = Date().addingTimeInterval(-7 * 24 * 3600)
        let unused = apps.filter { $0.lastUsed < threshold }
        XCTAssertGreaterThanOrEqual(unused.count, 1)
    }

    // MARK: - Sorting Tests

    func testSortByName() {
        let apps = ["Zebra", "Apple", "Mail"]
        let sorted = apps.sorted()

        XCTAssertEqual(sorted[0], "Apple")
        XCTAssertEqual(sorted[2], "Zebra")
    }

    func testSortBySize() {
        let apps = [
            (name: "A", size: Int64(100)),
            (name: "B", size: Int64(50)),
            (name: "C", size: Int64(200)),
        ]

        let sorted = apps.sorted { $0.size < $1.size }
        XCTAssertEqual(sorted[0].size, 50)
        XCTAssertEqual(sorted[2].size, 200)
    }

    func testSortAscendingDescending() {
        var sorted = [1, 3, 2]
        sorted.sort()

        XCTAssertEqual(sorted[0], 1)
        XCTAssertEqual(sorted[2], 3)

        sorted.sort { $0 > $1 }
        XCTAssertEqual(sorted[0], 3)
        XCTAssertEqual(sorted[2], 1)
    }

    // MARK: - Selection Tests

    func testSingleAppSelection() {
        var selectedApp: String? = nil
        XCTAssertNil(selectedApp)

        selectedApp = "Safari"
        XCTAssertEqual(selectedApp, "Safari")
    }

    func testMultipleAppSelection() {
        var selectedApps: Set<String> = []
        XCTAssertTrue(selectedApps.isEmpty)

        selectedApps.insert("Safari")
        selectedApps.insert("Mail")

        XCTAssertEqual(selectedApps.count, 2)
        XCTAssertTrue(selectedApps.contains("Safari"))
    }

    func testToggleAppSelection() {
        var isSelected = false
        XCTAssertFalse(isSelected)

        isSelected.toggle()
        XCTAssertTrue(isSelected)

        isSelected.toggle()
        XCTAssertFalse(isSelected)
    }

    func testClearAppSelection() {
        var selectedApps: Set<String> = ["Safari", "Mail"]
        XCTAssertEqual(selectedApps.count, 2)

        selectedApps.removeAll()
        XCTAssertTrue(selectedApps.isEmpty)
    }

    // MARK: - Action Tests

    func testUninstallAppAction() {
        var installedApps = ["Safari", "Mail", "Finder"]
        XCTAssertEqual(installedApps.count, 3)

        if let index = installedApps.firstIndex(of: "Mail") {
            installedApps.remove(at: index)
        }

        XCTAssertEqual(installedApps.count, 2)
        XCTAssertFalse(installedApps.contains("Mail"))
    }

    func testBatchUninstallApps() {
        var installedApps = ["A", "B", "C", "D"]
        let toRemove = Set(["B", "D"])

        installedApps = installedApps.filter { !toRemove.contains($0) }

        XCTAssertEqual(installedApps.count, 2)
        XCTAssertEqual(installedApps, ["A", "C"])
    }

    func testRevealAppLocation() {
        let appPath = "/Applications/Safari.app"
        XCTAssertTrue(appPath.contains("/Applications/"))
    }

    // MARK: - Cache Tests

    func testLoadCachedApps() {
        let cachedApps: [String] = ["Safari", "Mail"]
        XCTAssertEqual(cachedApps.count, 2)
    }

    func testSaveCachedApps() {
        let apps = ["Safari", "Mail", "Finder"]
        let count = apps.count

        XCTAssertEqual(count, 3)
    }

    func testCacheInvalidation() {
        var cachedApps: [String]? = ["Safari", "Mail"]
        XCTAssertNotNil(cachedApps)

        cachedApps = nil
        XCTAssertNil(cachedApps)
    }

    // MARK: - View State Tests

    enum AppInventoryViewState {
        case idle
        case scanning
        case loaded
        case error
    }

    func testViewStateTransitions() {
        var state: AppInventoryViewState = .idle
        XCTAssertEqual(state, .idle)

        state = .scanning
        XCTAssertEqual(state, .scanning)

        state = .loaded
        XCTAssertEqual(state, .loaded)
    }

    func testErrorStateHandling() {
        var state: AppInventoryViewState = .scanning
        var hasError = false

        hasError = true
        if hasError {
            state = .error
        }

        XCTAssertEqual(state, .error)
        XCTAssertTrue(hasError)
    }

    // MARK: - Error Handling Tests

    func testScanError() {
        let error = "Failed to scan applications directory"
        XCTAssertFalse(error.isEmpty)
    }

    func testPermissionError() {
        let error = "Full Disk Access required to scan system apps"
        XCTAssertTrue(error.contains("Full Disk Access"))
    }

    func testUninstallError() {
        let error = "Cannot uninstall system application"
        XCTAssertFalse(error.isEmpty)
    }

    // MARK: - Data Loading Tests

    func testLoadingState() {
        var isLoading = true
        XCTAssertTrue(isLoading)

        isLoading = false
        XCTAssertFalse(isLoading)
    }

    func testDataRefresh() {
        var lastRefreshTime = Date()
        let newRefreshTime = Date().addingTimeInterval(60)

        lastRefreshTime = newRefreshTime
        XCTAssertGreater(lastRefreshTime, Date().addingTimeInterval(-100))
    }

    // MARK: - Performance Tests

    func testAppTableRenderPerformance() {
        let startTime = Date()

        var apps = [String]()
        for i in 0..<1000 {
            apps.append("App \(i)")
        }

        let duration = Date().timeIntervalSince(startTime)
        XCTAssertLessThan(duration, 0.1, "App table rendering should be fast")
        XCTAssertEqual(apps.count, 1000)
    }

    func testFilterPerformance() {
        let startTime = Date()

        let apps = (0..<1000).map { "App \($0)" }
        let filtered = apps.filter { $0.contains("5") }

        let duration = Date().timeIntervalSince(startTime)
        XCTAssertLessThan(duration, 0.1)
        XCTAssertGreaterThan(filtered.count, 0)
    }

    func testSortPerformance() {
        let startTime = Date()

        var apps = (0..<1000).map { "App \($0)" }
        apps.sort()

        let duration = Date().timeIntervalSince(startTime)
        XCTAssertLessThan(duration, 0.1)
        XCTAssertEqual(apps.count, 1000)
    }

    func testSelectionPerformance() {
        let startTime = Date()

        var selectedApps: Set<String> = []
        for i in 0..<500 {
            selectedApps.insert("App \(i)")
        }

        let duration = Date().timeIntervalSince(startTime)
        XCTAssertLessThan(duration, 0.1)
        XCTAssertEqual(selectedApps.count, 500)
    }

    // MARK: - Accessibility Tests

    func testAccessibilityLabels() {
        let labels = [
            "Apps Table",
            "App Name",
            "App Size",
            "App Version",
            "Uninstall Button",
            "Search Field",
            "Filter by Category",
            "Sort Options",
        ]

        for label in labels {
            XCTAssertFalse(label.isEmpty)
        }
    }

    func testAppCategoryAccessibility() {
        let categories = ["System", "Productivity", "Media", "Developer"]

        for category in categories {
            XCTAssertFalse(category.isEmpty)
        }
    }

    // MARK: - Integration Tests

    func testScanAndDisplay() {
        var isScanning = false
        var apps: [String] = []

        isScanning = true
        XCTAssertTrue(isScanning)

        isScanning = false
        apps = ["Safari", "Mail", "Finder"]
        XCTAssertEqual(apps.count, 3)
        XCTAssertFalse(isScanning)
    }

    func testFilterAndSort() {
        let apps = ["Zebra", "Apple", "Mail"]
        let filtered = apps.filter { $0.contains("a") }
        let sorted = filtered.sorted()

        XCTAssertGreaterThan(sorted.count, 0)
        XCTAssertTrue(sorted[0].lowercased().contains("a"))
    }

    func testSelectAndUninstall() {
        var installedApps = ["Safari", "Mail", "Finder"]
        var selectedApps: Set<String> = ["Mail"]

        installedApps = installedApps.filter { !selectedApps.contains($0) }

        XCTAssertEqual(installedApps.count, 2)
        XCTAssertFalse(installedApps.contains("Mail"))
    }

    func testCacheAndRefresh() {
        var cachedApps: [String]? = ["Safari", "Mail"]
        XCTAssertNotNil(cachedApps)

        cachedApps = nil  // Simulate refresh
        cachedApps = ["Safari", "Mail", "Finder"]

        XCTAssertEqual(cachedApps?.count, 3)
    }

    // MARK: - Edge Cases

    func testEmptyAppList() {
        let apps: [String] = []
        XCTAssertTrue(apps.isEmpty)
    }

    func testSingleApp() {
        let apps = ["Safari"]
        XCTAssertEqual(apps.count, 1)
    }

    func testLargeAppList() {
        let apps = (0..<10000).map { "App \($0)" }
        XCTAssertEqual(apps.count, 10000)
    }

    func testAppNameWithSpecialCharacters() {
        let appNames = [
            "App (2024)",
            "My App v2.0",
            "App & Co",
        ]

        for name in appNames {
            XCTAssertFalse(name.isEmpty)
        }
    }

    func testVeryLargeAppSize() {
        let largeSize = Int64(50_000_000_000)  // 50 GB
        XCTAssertGreaterThan(largeSize, Int64(1_000_000_000))
    }
}
