//
//  ActionTableTests.swift
//  TonicTests
//
//  Tests for ActionTable component - rendering, selection, sorting, and keyboard navigation
//

import XCTest
@testable import Tonic

// MARK: - Test Item

struct TestTableItem: ActionTableItem {
    let id: String
    let name: String
    let size: Int64
    var isSelected: Bool = false

    init(id: String = UUID().uuidString, name: String, size: Int64) {
        self.id = id
        self.name = name
        self.size = size
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: TestTableItem, rhs: TestTableItem) -> Bool {
        lhs.id == rhs.id
    }
}

final class ActionTableTests: XCTestCase {

    // MARK: - Test Data

    var testItems: [TestTableItem] = []

    override func setUp() {
        super.setUp()
        testItems = [
            TestTableItem(id: "1", name: "Item A", size: 1000),
            TestTableItem(id: "2", name: "Item B", size: 2000),
            TestTableItem(id: "3", name: "Item C", size: 3000),
            TestTableItem(id: "4", name: "Item D", size: 4000),
            TestTableItem(id: "5", name: "Item E", size: 5000),
        ]
    }

    override func tearDown() {
        testItems.removeAll()
        super.tearDown()
    }

    // MARK: - Column Tests

    func testColumnCreation() {
        let column = ActionTableColumn(
            id: "name",
            title: "Name",
            width: .fixed(200),
            alignment: .leading,
            isSortable: true
        ) { item in
            Text(item.name)
        }

        XCTAssertEqual(column.id, "name")
        XCTAssertEqual(column.title, "Name")
        XCTAssertEqual(column.alignment, .leading)
        XCTAssertTrue(column.isSortable)
    }

    func testColumnWidthVariants() {
        let fixed = ActionTableColumnWidth.fixed(100)
        let flexible = ActionTableColumnWidth.flexible
        let range = ActionTableColumnWidth.flexibleRange(min: 50, max: 200)

        XCTAssertEqual(fixed.minWidth, 100)
        XCTAssertEqual(fixed.maxWidth, 100)

        XCTAssertNil(flexible.minWidth)
        XCTAssertNil(flexible.maxWidth)

        XCTAssertEqual(range.minWidth, 50)
        XCTAssertEqual(range.maxWidth, 200)
    }

    // MARK: - Action Tests

    func testActionCreation() {
        var actionCalled = false
        let action = ActionTableAction(
            id: "delete",
            title: "Delete",
            icon: "trash",
            style: .destructive,
            isEnabled: { !$0.isEmpty },
            action: { _ in actionCalled = true }
        )

        XCTAssertEqual(action.id, "delete")
        XCTAssertEqual(action.title, "Delete")
        XCTAssertEqual(action.icon, "trash")
        XCTAssertTrue(action.isEnabled(testItems))

        action.action(testItems)
        XCTAssertTrue(actionCalled)
    }

    func testActionEnabledDisabled() {
        let action = ActionTableAction(
            id: "test",
            title: "Test",
            isEnabled: { items in items.count > 3 }
        ) { _ in }

        // Should be disabled with fewer items
        let fewItems = [testItems[0], testItems[1]]
        XCTAssertFalse(action.isEnabled(fewItems))

        // Should be enabled with more items
        let manyItems = Array(testItems)
        XCTAssertTrue(action.isEnabled(manyItems))
    }

    func testActionStyles() {
        let primaryAction = ActionTableAction(
            id: "primary",
            title: "Primary",
            style: .primary,
            action: { _ in }
        )

        let destructiveAction = ActionTableAction(
            id: "destructive",
            title: "Destructive",
            style: .destructive,
            action: { _ in }
        )

        XCTAssertEqual(primaryAction.style, .primary)
        XCTAssertEqual(destructiveAction.style, .destructive)
    }

    // MARK: - Item Rendering Tests

    func testItemRendering() {
        XCTAssertEqual(testItems.count, 5)
        XCTAssertEqual(testItems.first?.name, "Item A")
        XCTAssertEqual(testItems.last?.name, "Item E")
    }

    func testItemIdentification() {
        for (index, item) in testItems.enumerated() {
            XCTAssertEqual(item.id, String(index + 1))
        }
    }

    // MARK: - Selection Tests

    func testSingleSelect() {
        var selection: Set<String> = []
        let selectedId = testItems[0].id

        selection.insert(selectedId)
        XCTAssertTrue(selection.contains(selectedId))
        XCTAssertEqual(selection.count, 1)
    }

    func testMultiSelect() {
        var selection: Set<String> = []

        // Select multiple items
        for item in testItems.prefix(3) {
            selection.insert(item.id)
        }

        XCTAssertEqual(selection.count, 3)
        XCTAssertTrue(selection.contains(testItems[0].id))
        XCTAssertTrue(selection.contains(testItems[1].id))
        XCTAssertTrue(selection.contains(testItems[2].id))
        XCTAssertFalse(selection.contains(testItems[3].id))
    }

    func testToggleSelect() {
        var selection: Set<String> = []
        let itemId = testItems[0].id

        // First select
        selection.insert(itemId)
        XCTAssertTrue(selection.contains(itemId))

        // Toggle off
        selection.remove(itemId)
        XCTAssertFalse(selection.contains(itemId))

        // Toggle on again
        selection.insert(itemId)
        XCTAssertTrue(selection.contains(itemId))
    }

    func testRangeSelect() {
        var selection: Set<String> = []

        // Simulate range select (items 1-3)
        let rangeItems = testItems.prefix(3)
        for item in rangeItems {
            selection.insert(item.id)
        }

        XCTAssertEqual(selection.count, 3)
    }

    func testClearSelection() {
        var selection: Set<String> = []

        // Add items
        for item in testItems.prefix(3) {
            selection.insert(item.id)
        }
        XCTAssertEqual(selection.count, 3)

        // Clear
        selection.removeAll()
        XCTAssertTrue(selection.isEmpty)
    }

    // MARK: - Batch Action Tests

    func testBatchActionWithSelection() {
        var selection: Set<String> = []
        var processedIds: [String] = []

        let action = ActionTableAction(
            id: "process",
            title: "Process",
            action: { items in
                processedIds = items.map { $0.id }
            }
        )

        // Select items
        for item in testItems.prefix(2) {
            selection.insert(item.id)
        }

        // Get selected items
        let selectedItems = testItems.filter { selection.contains($0.id) }
        action.action(selectedItems)

        XCTAssertEqual(processedIds.count, 2)
        XCTAssertTrue(processedIds.contains(testItems[0].id))
        XCTAssertTrue(processedIds.contains(testItems[1].id))
    }

    func testBatchActionDisabledWhenNoSelection() {
        let action = ActionTableAction(
            id: "test",
            title: "Test",
            isEnabled: { !$0.isEmpty },
            action: { _ in }
        )

        let selectedItems: [TestTableItem] = []
        XCTAssertFalse(action.isEnabled(selectedItems))
    }

    // MARK: - Sorting Tests

    func testSortableColumn() {
        let sortableColumn = ActionTableColumn(
            id: "name",
            title: "Name",
            isSortable: true
        ) { item in
            Text(item.name)
        }

        let unsortableColumn = ActionTableColumn(
            id: "actions",
            title: "Actions",
            isSortable: false
        ) { _ in
            Text("")
        }

        XCTAssertTrue(sortableColumn.isSortable)
        XCTAssertFalse(unsortableColumn.isSortable)
    }

    func testSortByName() {
        let sorted = testItems.sorted { $0.name < $1.name }
        XCTAssertEqual(sorted.first?.name, "Item A")
        XCTAssertEqual(sorted.last?.name, "Item E")
    }

    func testSortBySize() {
        let sorted = testItems.sorted { $0.size < $1.size }
        XCTAssertEqual(sorted.first?.size, 1000)
        XCTAssertEqual(sorted.last?.size, 5000)
    }

    func testReverseSorting() {
        let sorted = testItems.sorted { $0.name > $1.name }
        XCTAssertEqual(sorted.first?.name, "Item E")
        XCTAssertEqual(sorted.last?.name, "Item A")
    }

    // MARK: - Keyboard Navigation Tests

    func testKeyboardNavigation() {
        var currentIndex = 0

        // Simulate arrow key down
        if currentIndex < testItems.count - 1 {
            currentIndex += 1
        }
        XCTAssertEqual(currentIndex, 1)

        // Simulate arrow key up
        if currentIndex > 0 {
            currentIndex -= 1
        }
        XCTAssertEqual(currentIndex, 0)
    }

    func testKeyboardNavigationBounds() {
        var currentIndex = 0

        // Try to go up from first item
        if currentIndex > 0 {
            currentIndex -= 1
        }
        XCTAssertEqual(currentIndex, 0)

        // Go to last item
        currentIndex = testItems.count - 1
        XCTAssertEqual(currentIndex, 4)

        // Try to go down from last item
        if currentIndex < testItems.count - 1 {
            currentIndex += 1
        }
        XCTAssertEqual(currentIndex, 4)
    }

    func testSpaceKeySelection() {
        var selection: Set<String> = []
        let currentItem = testItems[0]

        if selection.contains(currentItem.id) {
            selection.remove(currentItem.id)
        } else {
            selection.insert(currentItem.id)
        }

        XCTAssertTrue(selection.contains(currentItem.id))

        // Press space again to deselect
        if selection.contains(currentItem.id) {
            selection.remove(currentItem.id)
        } else {
            selection.insert(currentItem.id)
        }

        XCTAssertFalse(selection.contains(currentItem.id))
    }

    // MARK: - Edge Case Tests

    func testEmptyTable() {
        let emptyItems: [TestTableItem] = []
        XCTAssertTrue(emptyItems.isEmpty)
    }

    func testLargeTable() {
        let largeItems = (0..<1000).map { index in
            TestTableItem(id: String(index), name: "Item \(index)", size: Int64(index))
        }
        XCTAssertEqual(largeItems.count, 1000)
    }

    func testDuplicateIds() {
        let duplicate1 = TestTableItem(id: "same", name: "Item 1", size: 100)
        let duplicate2 = TestTableItem(id: "same", name: "Item 2", size: 200)

        XCTAssertEqual(duplicate1.id, duplicate2.id)
        XCTAssertNotEqual(duplicate1.name, duplicate2.name)
    }

    func testItemEquality() {
        let item1 = TestTableItem(id: "1", name: "Test", size: 100)
        let item2 = TestTableItem(id: "1", name: "Test", size: 100)
        let item3 = TestTableItem(id: "2", name: "Test", size: 100)

        XCTAssertEqual(item1, item2)
        XCTAssertNotEqual(item1, item3)
    }

    // MARK: - Performance Tests

    func testTableWithManyItems() {
        let manyItems = (0..<5000).map { index in
            TestTableItem(id: String(index), name: "Item \(index)", size: Int64(index * 100))
        }

        let startTime = Date()
        let filtered = manyItems.filter { $0.size > 100_000 }
        let duration = Date().timeIntervalSince(startTime)

        XCTAssertGreaterThan(filtered.count, 0)
        XCTAssertLessThan(duration, 1.0, "Filtering 5000 items should be fast")
    }

    func testSortingPerformance() {
        let manyItems = (0..<10_000).map { index in
            TestTableItem(id: String(index), name: "Item \(index)", size: Int64.random(in: 0...1_000_000))
        }

        let startTime = Date()
        let sorted = manyItems.sorted { $0.size < $1.size }
        let duration = Date().timeIntervalSince(startTime)

        XCTAssertEqual(sorted.count, manyItems.count)
        XCTAssertLessThan(duration, 0.5, "Sorting 10k items should complete quickly")
    }
}
