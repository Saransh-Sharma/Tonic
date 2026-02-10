//
//  ActionTableTests.swift
//  TonicTests
//
//  Regression tests for ActionTable core types.
//

import SwiftUI
import XCTest
@testable import Tonic

private struct TestTableItem: ActionTableItem {
    let id: String
    let name: String
    let size: Int64
}

final class ActionTableTests: XCTestCase {
    private let testItems: [TestTableItem] = [
        .init(id: "1", name: "Item A", size: 1_000),
        .init(id: "2", name: "Item B", size: 2_000),
        .init(id: "3", name: "Item C", size: 3_000),
    ]

    func testColumnWidthVariants() {
        let fixed = ActionTableColumnWidth.fixed(120)
        let flexible = ActionTableColumnWidth.flexible
        let range = ActionTableColumnWidth.flexibleRange(min: 80, max: 240)

        XCTAssertEqual(fixed.minWidth, 120)
        XCTAssertEqual(fixed.maxWidth, 120)
        XCTAssertNil(flexible.minWidth)
        XCTAssertNil(flexible.maxWidth)
        XCTAssertEqual(range.minWidth, 80)
        XCTAssertEqual(range.maxWidth, 240)
    }

    func testColumnCreation() {
        let column = ActionTableColumn<TestTableItem>(
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
        XCTAssertTrue(column.isSortable)
        XCTAssertEqual(column.alignment, .leading)
    }

    func testActionCreationAndExecution() {
        var capturedIds: [String] = []
        let action = ActionTableAction<TestTableItem>(
            id: "delete",
            title: "Delete",
            icon: "trash",
            style: .destructive
        ) { items in
            capturedIds = items.map(\.id)
        }

        XCTAssertEqual(action.id, "delete")
        XCTAssertEqual(action.title, "Delete")
        XCTAssertEqual(action.icon, "trash")
        XCTAssertEqual(action.style, .destructive)

        action.action(testItems)
        XCTAssertEqual(capturedIds, ["1", "2", "3"])
    }

    func testActionEnablementPredicate() {
        let action = ActionTableAction<TestTableItem>(
            id: "run",
            title: "Run",
            isEnabled: { $0.count >= 2 }
        ) { _ in }

        XCTAssertFalse(action.isEnabled([testItems[0]]))
        XCTAssertTrue(action.isEnabled(testItems))
    }

    func testSimpleSelectionFlow() {
        var selection = Set<String>()

        selection.insert(testItems[0].id)
        selection.insert(testItems[1].id)
        XCTAssertEqual(selection.count, 2)
        XCTAssertTrue(selection.contains("1"))
        XCTAssertTrue(selection.contains("2"))

        selection.remove(testItems[0].id)
        XCTAssertEqual(selection.count, 1)
        XCTAssertFalse(selection.contains("1"))
        XCTAssertTrue(selection.contains("2"))
    }
}
