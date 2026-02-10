//
//  ActivityLogStoreTests.swift
//  TonicTests
//
//  Tests for persistent activity log store
//

import XCTest
@testable import Tonic

@MainActor
final class ActivityLogStoreTests: XCTestCase {
    private let suiteName = "ActivityLogStoreTests"
    private var userDefaults: UserDefaults!
    private var store: ActivityLogStore!

    override func setUp() {
        super.setUp()
        userDefaults = UserDefaults(suiteName: suiteName)
        userDefaults.removePersistentDomain(forName: suiteName)
        store = ActivityLogStore(userDefaults: userDefaults)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        store = nil
        userDefaults = nil
        super.tearDown()
    }

    func testRecordPrependsAndPrunesTo200() {
        for index in 0..<210 {
            store.record(makeEvent(index))
        }

        XCTAssertEqual(store.entries.count, 200)
        XCTAssertEqual(store.entries.first?.title, "Event 209")
        XCTAssertEqual(store.entries.last?.title, "Event 10")
    }

    func testPersistenceRoundTrip() {
        store.record(makeEvent(1))

        let reloaded = ActivityLogStore(userDefaults: userDefaults)
        XCTAssertEqual(reloaded.entries.count, 1)
        XCTAssertEqual(reloaded.entries.first?.title, "Event 1")
    }

    func testInstallLoggedOnce() {
        store.recordInstallIfNeeded(version: "1.0", build: "1")
        store.recordInstallIfNeeded(version: "1.0", build: "1")

        let installEvents = store.entries.filter { $0.title == "Tonic installed" }
        XCTAssertEqual(installEvents.count, 1)
    }

    func testUpdateLoggedOnVersionChange() {
        store.recordInstallIfNeeded(version: "1.0", build: "1")
        store.recordUpdateIfNeeded(version: "1.0", build: "1")
        XCTAssertEqual(store.entries.count, 1)

        store.recordUpdateIfNeeded(version: "1.1", build: "2")
        XCTAssertEqual(store.entries.count, 2)
        XCTAssertEqual(store.entries.first?.title, "Tonic updated")
        XCTAssertTrue(store.entries.first?.detail.contains("From 1.0 (Build 1) -> 1.1 (Build 2)") ?? false)
    }

    func testDecodeFailureClearsSafely() {
        userDefaults.set(Data("bad".utf8), forKey: "tonic.activity.log")

        let reloaded = ActivityLogStore(userDefaults: userDefaults)
        XCTAssertTrue(reloaded.entries.isEmpty)
        XCTAssertNil(userDefaults.data(forKey: "tonic.activity.log"))
    }

    private func makeEvent(_ index: Int) -> ActivityEvent {
        ActivityEvent(
            category: .scan,
            title: "Event \(index)",
            detail: "Detail \(index)",
            impact: .low
        )
    }
}
