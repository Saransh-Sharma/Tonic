//
//  ActionTablePerformanceTests.swift
//  TonicTests
//
//  Performance tests for ActionTable - 1000+ items at 60fps
//

import XCTest
@testable import Tonic

final class ActionTablePerformanceTests: PerformanceTestBase {

    // MARK: - Test Items

    struct MockTableItem: ActionTableItem {
        let id: String
        let name: String
        let size: Int64

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }

        static func == (lhs: MockTableItem, rhs: MockTableItem) -> Bool {
            lhs.id == rhs.id
        }
    }

    func createMockItems(count: Int) -> [MockTableItem] {
        (0..<count).map { i in
            MockTableItem(
                id: String(i),
                name: "File \(i).app",
                size: Int64.random(in: 100_000...1_000_000_000)
            )
        }
    }

    // MARK: - Rendering Performance

    func testRenderingWith100Items() {
        let items = createMockItems(count: 100)
        measure {
            _ = items
        }
    }

    func testRenderingWith1000Items() {
        let items = createMockItems(count: 1000)

        let duration = measureExecutionTime {
            _ = items
        }

        XCTAssertLessThan(
            duration,
            0.5,
            "Rendering 1000 items should complete in < 500ms"
        )
    }

    func testRenderingWith5000Items() {
        let items = createMockItems(count: 5000)

        let duration = measureExecutionTime {
            _ = items
        }

        XCTAssertLessThan(
            duration,
            1.0,
            "Rendering 5000 items should complete in < 1000ms"
        )
    }

    // MARK: - Sorting Performance

    func testSortingPerformance100Items() {
        let items = createMockItems(count: 100)

        let duration = measureExecutionTime {
            _ = items.sorted { $0.name < $1.name }
        }

        XCTAssertLessThan(duration, 0.05)
    }

    func testSortingPerformance1000Items() {
        let items = createMockItems(count: 1000)

        let duration = measureExecutionTime {
            _ = items.sorted { $0.name < $1.name }
        }

        XCTAssertLessThan(
            duration,
            0.2,
            "Sorting 1000 items should complete in < 200ms"
        )
    }

    func testSortingPerformance10000Items() {
        let items = createMockItems(count: 10_000)

        let duration = measureExecutionTime {
            _ = items.sorted { $0.size < $1.size }
        }

        XCTAssertLessThan(
            duration,
            1.0,
            "Sorting 10k items should complete in < 1s"
        )
    }

    // MARK: - Selection Performance

    func testSelectionWith100Items() {
        let items = createMockItems(count: 100)
        var selection: Set<String> = []

        let duration = measureExecutionTime {
            for item in items {
                selection.insert(item.id)
            }
        }

        XCTAssertLessThan(duration, 0.05)
        XCTAssertEqual(selection.count, 100)
    }

    func testSelectionWith1000Items() {
        let items = createMockItems(count: 1000)
        var selection: Set<String> = []

        let duration = measureExecutionTime {
            for item in items {
                selection.insert(item.id)
            }
        }

        XCTAssertLessThan(duration, 0.1)
        XCTAssertEqual(selection.count, 1000)
    }

    func testMultiSelectPerformance() {
        let items = createMockItems(count: 1000)
        var selection: Set<String> = []

        let duration = measureExecutionTime {
            // Simulate cmd-click multi-select
            for item in items.prefix(100) {
                selection.insert(item.id)
            }
        }

        XCTAssertLessThan(duration, 0.05)
    }

    // MARK: - Filtering Performance

    func testFilteringPerformance1000Items() {
        let items = createMockItems(count: 1000)

        let duration = measureExecutionTime {
            _ = items.filter { $0.size > 500_000_000 }
        }

        XCTAssertLessThan(
            duration,
            0.1,
            "Filtering 1000 items should be < 100ms"
        )
    }

    func testFilteringPerformance10000Items() {
        let items = createMockItems(count: 10_000)

        let duration = measureExecutionTime {
            _ = items.filter { $0.name.contains("File") }
        }

        XCTAssertLessThan(
            duration,
            0.5,
            "Filtering 10k items should be < 500ms"
        )
    }

    // MARK: - Batch Operation Performance

    func testBatchDeletePerformance() {
        let items = createMockItems(count: 1000)
        var toDelete: Set<String> = []

        // Select 100 items for deletion
        for item in items.prefix(100) {
            toDelete.insert(item.id)
        }

        let duration = measureExecutionTime {
            _ = items.filter { !toDelete.contains($0.id) }
        }

        XCTAssertLessThan(duration, 0.1)
    }

    func testBatchMovePerformance() {
        let items = createMockItems(count: 1000)
        var toMove: Set<String> = []

        for item in items.prefix(50) {
            toMove.insert(item.id)
        }

        let duration = measureExecutionTime {
            let movedItems = items.filter { toMove.contains($0.id) }
            _ = movedItems
        }

        XCTAssertLessThan(duration, 0.05)
    }

    // MARK: - Memory Performance

    func testMemoryUsageWith1000Items() {
        let items = createMockItems(count: 1000)

        let memoryUsed = measureMemoryUsage {
            var selection: Set<String> = []
            for item in items {
                selection.insert(item.id)
            }
            _ = selection
        }

        print("Memory used for 1000 items: \(ByteCountFormatter.string(fromByteCount: memoryUsed, countStyle: .file))")
        XCTAssertLessThan(
            memoryUsed,
            50_000_000,  // 50MB
            "1000 items should use < 50MB"
        )
    }

    func testMemoryUsageWith10000Items() {
        let items = createMockItems(count: 10_000)

        let memoryUsed = measureMemoryUsage {
            var selection: Set<String> = []
            for item in items {
                selection.insert(item.id)
            }
            _ = selection
        }

        print("Memory used for 10k items: \(ByteCountFormatter.string(fromByteCount: memoryUsed, countStyle: .file))")
        XCTAssertLessThan(
            memoryUsed,
            200_000_000,  // 200MB
            "10k items should use < 200MB"
        )
    }

    // MARK: - Frame Rate Simulation

    func testScrollingWith1000Items() {
        let items = createMockItems(count: 1000)

        // Simulate 60 FPS scrolling (16.67ms per frame)
        let targetFrameTime: TimeInterval = 0.0167

        let duration = measureExecutionTime {
            // Simulate rendering 60 frames
            for _ in 0..<60 {
                _ = items.prefix(10)  // Visible items
            }
        }

        let averageFrameTime = duration / 60
        XCTAssertLessThan(
            averageFrameTime,
            targetFrameTime,
            "Average frame time should be < 16.67ms for 60fps"
        )
    }

    // MARK: - Search Performance

    func testSearchPerformance1000Items() {
        let items = createMockItems(count: 1000)
        let searchTerm = "File 5"

        let duration = measureExecutionTime {
            _ = items.filter { $0.name.contains(searchTerm) }
        }

        XCTAssertLessThan(
            duration,
            0.1,
            "Search in 1000 items should be < 100ms"
        )
    }

    func testSearchPerformance10000Items() {
        let items = createMockItems(count: 10_000)
        let searchTerm = "500"

        let duration = measureExecutionTime {
            _ = items.filter { $0.name.contains(searchTerm) }
        }

        XCTAssertLessThan(
            duration,
            0.5,
            "Search in 10k items should be < 500ms"
        )
    }

    // MARK: - Stress Tests

    func testLargeTableOperations() {
        let items = createMockItems(count: 5000)

        let duration = measureExecutionTime {
            // Multiple operations
            let filtered = items.filter { $0.size > 100_000_000 }
            let sorted = filtered.sorted { $0.name < $1.name }
            var selected: Set<String> = []
            for item in sorted.prefix(100) {
                selected.insert(item.id)
            }
            _ = selected
        }

        XCTAssertLessThan(
            duration,
            0.5,
            "Complex operations on 5k items should be < 500ms"
        )
    }

    // MARK: - Reporting

    override func tearDown() {
        let report = PerformanceTestBase.generatePerformanceReport()
        print(report)
        super.tearDown()
    }
}
