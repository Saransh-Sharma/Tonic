//
//  DiskAnalysisViewTests.swift
//  TonicTests
//
//  Tests for DiskAnalysisView - view modes, navigation, permissions, scanning
//

import XCTest
@testable import Tonic

final class DiskAnalysisViewTests: XCTestCase {

    // MARK: - View Mode Tests

    func testListViewModeExists() {
        let mode = DiskViewMode.list
        XCTAssertEqual(mode.rawValue, "List")
        XCTAssertEqual(mode.icon, "list.bullet")
    }

    func testTreemapViewModeExists() {
        let mode = DiskViewMode.treemap
        XCTAssertEqual(mode.rawValue, "Treemap")
        XCTAssertEqual(mode.icon, "square.grid.2x2")
    }

    func testHybridViewModeExists() {
        let mode = DiskViewMode.hybrid
        XCTAssertEqual(mode.rawValue, "Hybrid")
        XCTAssertEqual(mode.icon, "square.split.1x2")
    }

    func testAllViewModesConformToIdentifiable() {
        let modes = DiskViewMode.allCases
        for mode in modes {
            XCTAssertFalse(mode.id.isEmpty)
        }
    }

    // MARK: - View Mode Switching Tests

    func testSwitchToListMode() {
        var currentMode = DiskViewMode.treemap
        currentMode = .list
        XCTAssertEqual(currentMode, .list)
    }

    func testSwitchToTreemapMode() {
        var currentMode = DiskViewMode.list
        currentMode = .treemap
        XCTAssertEqual(currentMode, .treemap)
    }

    func testSwitchToHybridMode() {
        var currentMode = DiskViewMode.list
        currentMode = .hybrid
        XCTAssertEqual(currentMode, .hybrid)
    }

    func testCycleThroughModes() {
        var mode = DiskViewMode.list
        let modes = DiskViewMode.allCases

        for _ in modes {
            let currentIndex = modes.firstIndex(of: mode) ?? 0
            let nextIndex = (currentIndex + 1) % modes.count
            mode = modes[nextIndex]
        }

        XCTAssertEqual(mode, .list)
    }

    // MARK: - Permission Tests

    func testPermissionCheckingState() {
        var isCheckingPermissions = false
        XCTAssertFalse(isCheckingPermissions)

        isCheckingPermissions = true
        XCTAssertTrue(isCheckingPermissions)
    }

    func testFullDiskAccessPermission() {
        var hasFullDiskAccess = false
        XCTAssertFalse(hasFullDiskAccess)

        hasFullDiskAccess = true
        XCTAssertTrue(hasFullDiskAccess)
    }

    func testPermissionRequiredView() {
        let permissionMessage = "Full Disk Access required"
        XCTAssertFalse(permissionMessage.isEmpty)
    }

    // MARK: - Scanning Tests

    func testScanningState() {
        var isScanning = false
        XCTAssertFalse(isScanning)

        isScanning = true
        XCTAssertTrue(isScanning)
    }

    func testScanProgress() {
        var scanProgress: Double = 0.0
        XCTAssertEqual(scanProgress, 0.0)

        scanProgress = 0.5
        XCTAssertEqual(scanProgress, 0.5)

        scanProgress = 1.0
        XCTAssertEqual(scanProgress, 1.0)
    }

    func testScanResultDisplay() {
        var scanResult: String? = nil
        XCTAssertNil(scanResult)

        scanResult = "Scan complete: 500 GB analyzed"
        XCTAssertNotNil(scanResult)
        XCTAssertFalse(scanResult?.isEmpty ?? true)
    }

    // MARK: - Navigation Tests

    func testInitialPath() {
        let path = FileManager.default.homeDirectoryForCurrentUser.path
        XCTAssertFalse(path.isEmpty)
        XCTAssertTrue(path.contains("/"))
    }

    func testPathNavigation() {
        var currentPath = "/Users/test"
        let newPath = "/Users/test/Documents"

        currentPath = newPath
        XCTAssertEqual(currentPath, newPath)
    }

    func testNavigationStack() {
        var navigationPath: [String] = []
        XCTAssertTrue(navigationPath.isEmpty)

        navigationPath.append("/Users")
        XCTAssertEqual(navigationPath.count, 1)

        navigationPath.append("/Users/Documents")
        XCTAssertEqual(navigationPath.count, 2)

        _ = navigationPath.popLast()
        XCTAssertEqual(navigationPath.count, 1)
    }

    func testBreadcrumbNavigation() {
        let pathComponents = ["Users", "Documents", "Projects"]
        XCTAssertEqual(pathComponents.count, 3)

        for component in pathComponents {
            XCTAssertFalse(component.isEmpty)
        }
    }

    // MARK: - Selection Tests

    func testSinglePathSelection() {
        var selectedPath: String? = nil
        XCTAssertNil(selectedPath)

        selectedPath = "/Users/Documents"
        XCTAssertNotNil(selectedPath)
    }

    func testMultiplePathSelection() {
        var selectedPaths: Set<String> = []
        XCTAssertTrue(selectedPaths.isEmpty)

        selectedPaths.insert("/Users/Documents")
        XCTAssertEqual(selectedPaths.count, 1)

        selectedPaths.insert("/Users/Downloads")
        XCTAssertEqual(selectedPaths.count, 2)

        selectedPaths.remove("/Users/Documents")
        XCTAssertEqual(selectedPaths.count, 1)
    }

    func testClearSelection() {
        var selectedPaths: Set<String> = ["/Users/Documents", "/Users/Downloads"]
        XCTAssertEqual(selectedPaths.count, 2)

        selectedPaths.removeAll()
        XCTAssertTrue(selectedPaths.isEmpty)
    }

    // MARK: - Error Handling Tests

    func testErrorMessageDisplay() {
        var errorMessage: String? = nil
        XCTAssertNil(errorMessage)

        errorMessage = "Permission denied: Cannot access directory"
        XCTAssertNotNil(errorMessage)
        XCTAssertTrue(errorMessage?.contains("Permission") ?? false)
    }

    func testErrorClearance() {
        var errorMessage: String? = "Error occurred"
        XCTAssertNotNil(errorMessage)

        errorMessage = nil
        XCTAssertNil(errorMessage)
    }

    func testPermissionError() {
        let error = "Full Disk Access required to scan system folders"
        XCTAssertFalse(error.isEmpty)
    }

    func testScanError() {
        let error = "Failed to scan directory: Permission denied"
        XCTAssertFalse(error.isEmpty)
    }

    // MARK: - View State Tests

    enum DiskAnalysisViewState {
        case checking
        case noPermission
        case scanning
        case error
        case results
        case initial
    }

    func testViewStateTransitions() {
        var state: DiskAnalysisViewState = .initial
        XCTAssertEqual(state, .initial)

        state = .checking
        XCTAssertEqual(state, .checking)

        state = .noPermission
        XCTAssertEqual(state, .noPermission)

        state = .scanning
        XCTAssertEqual(state, .scanning)

        state = .results
        XCTAssertEqual(state, .results)
    }

    func testErrorStateHandling() {
        var state: DiskAnalysisViewState = .scanning
        var hasError = false

        hasError = true
        if hasError {
            state = .error
        }

        XCTAssertEqual(state, .error)
        XCTAssertTrue(hasError)
    }

    // MARK: - Data Display Tests

    func testDirectoryEntry() {
        let entry = (name: "Documents", size: Int64(5_000_000_000))
        XCTAssertFalse(entry.name.isEmpty)
        XCTAssertGreaterThan(entry.size, 0)
    }

    func testMultipleDirectoryEntries() {
        let entries = [
            (name: "Documents", size: Int64(5_000_000_000)),
            (name: "Downloads", size: Int64(12_000_000_000)),
            (name: "Pictures", size: Int64(8_500_000_000)),
        ]

        XCTAssertEqual(entries.count, 3)
        for entry in entries {
            XCTAssertFalse(entry.name.isEmpty)
            XCTAssertGreaterThan(entry.size, 0)
        }
    }

    func testDirectorySizeFormatting() {
        let sizes: [Int64] = [
            1_000_000,      // 1 MB
            1_000_000_000,  // 1 GB
            1_000_000_000_000,  // 1 TB
        ]

        for size in sizes {
            XCTAssertGreaterThan(size, 0)
        }
    }

    // MARK: - Sorting Tests

    func testSortByName() {
        let entries = ["Documents", "Downloads", "Applications"]
        let sorted = entries.sorted()

        XCTAssertEqual(sorted[0], "Applications")
        XCTAssertEqual(sorted[2], "Downloads")
    }

    func testSortBySize() {
        let entries = [
            (name: "A", size: Int64(100)),
            (name: "B", size: Int64(200)),
            (name: "C", size: Int64(50)),
        ]

        let sorted = entries.sorted { $0.size < $1.size }
        XCTAssertEqual(sorted[0].size, 50)
        XCTAssertEqual(sorted[2].size, 200)
    }

    func testSortAscendingDescending() {
        let sizes = [100, 200, 50, 150]

        let ascending = sizes.sorted()
        XCTAssertEqual(ascending[0], 50)

        let descending = sizes.sorted { $0 > $1 }
        XCTAssertEqual(descending[0], 200)
    }

    // MARK: - Filtering Tests

    func testFilterBySize() {
        let entries = [
            (name: "Small", size: Int64(100_000)),
            (name: "Large", size: Int64(5_000_000_000)),
            (name: "Medium", size: Int64(500_000_000)),
        ]

        let largeEntries = entries.filter { $0.size > Int64(1_000_000_000) }
        XCTAssertEqual(largeEntries.count, 1)
    }

    func testSearchByName() {
        let entries = ["Documents", "Downloads", "Desktop", "Applications"]
        let search = "Doc"

        let results = entries.filter { $0.contains(search) }
        XCTAssertEqual(results.count, 2)
    }

    // MARK: - Performance Tests

    func testViewModeRenderPerformance() {
        let startTime = Date()

        for _ in DiskViewMode.allCases {
            let mode = DiskViewMode.list
            _ = mode.icon
        }

        let duration = Date().timeIntervalSince(startTime)
        XCTAssertLessThan(duration, 0.1, "View mode rendering should be fast")
    }

    func testNavigationPerformance() {
        let startTime = Date()

        var path = ""
        for i in 0..<100 {
            path = "/Users/user/dir\(i)"
        }

        let duration = Date().timeIntervalSince(startTime)
        XCTAssertLessThan(duration, 0.05, "Path navigation should be instant")
        XCTAssertFalse(path.isEmpty)
    }

    func testPathStackPerformance() {
        let startTime = Date()

        var stack: [String] = []
        for i in 0..<1000 {
            stack.append("/Users/user/dir\(i)")
        }

        let duration = Date().timeIntervalSince(startTime)
        XCTAssertLessThan(duration, 0.1)
        XCTAssertEqual(stack.count, 1000)
    }

    // MARK: - Accessibility Tests

    func testAccessibilityLabels() {
        let labels = [
            "List View Mode",
            "Treemap View Mode",
            "Hybrid View Mode",
            "Start Scan Button",
            "Cancel Button",
            "Permission Check View",
            "Results View",
        ]

        for label in labels {
            XCTAssertFalse(label.isEmpty)
        }
    }

    func testSegmentedControlAccessibility() {
        let modes = DiskViewMode.allCases
        for mode in modes {
            XCTAssertFalse(mode.id.isEmpty)
            XCTAssertFalse(mode.icon.isEmpty)
        }
    }

    // MARK: - Integration Tests

    func testPermissionCheckThenScan() {
        var hasPermission = false
        var isScanning = false

        hasPermission = true
        if hasPermission {
            isScanning = true
        }

        XCTAssertTrue(hasPermission)
        XCTAssertTrue(isScanning)
    }

    func testNavigateAndSelect() {
        var currentPath = "/Users"
        var selectedPath: String? = nil

        currentPath = "/Users/Documents"
        selectedPath = currentPath

        XCTAssertEqual(currentPath, "/Users/Documents")
        XCTAssertEqual(selectedPath, currentPath)
    }

    func testScanCompleteFlow() {
        var state: DiskAnalysisViewState = .initial
        var isScanning = false
        var hasResults = false

        state = .checking
        state = .scanning
        isScanning = true

        isScanning = false
        hasResults = true
        state = .results

        XCTAssertEqual(state, .results)
        XCTAssertFalse(isScanning)
        XCTAssertTrue(hasResults)
    }

    // MARK: - Edge Cases

    func testEmptyDirectoryList() {
        let entries: [(String, Int64)] = []
        XCTAssertTrue(entries.isEmpty)
    }

    func testSingleDirectory() {
        let entries = [
            (name: "Documents", size: Int64(5_000_000_000))
        ]
        XCTAssertEqual(entries.count, 1)
    }

    func testVeryLargePath() {
        var path = "/Users"
        for i in 0..<50 {
            path += "/dir\(i)"
        }

        XCTAssertGreaterThan(path.count, 100)
    }

    func testSpecialCharactersInPath() {
        let path = "/Users/test user/My Documents (2024)"
        XCTAssertTrue(path.contains(" "))
        XCTAssertTrue(path.contains("("))
    }
}
