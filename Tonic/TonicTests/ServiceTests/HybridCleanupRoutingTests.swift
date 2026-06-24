import Foundation
import XCTest
@testable import Tonic

/// Tests the classification + review-state logic that decides whether cleaned
/// items go to the Trash (recoverable) or are removed permanently, and which
/// runs require the review-before-removing sheet.
final class HybridCleanupRoutingTests: XCTestCase {

    private func item(
        title: String,
        size: Int64,
        count: Int = 1,
        dataClass: SmartCareDataClass
    ) -> SmartCareItem {
        SmartCareItem(
            domain: .cleanup,
            groupId: UUID(),
            title: title,
            subtitle: "",
            size: size,
            count: count,
            safeToRun: true,
            isSmartSelected: false,
            action: .delete(paths: ["/tmp/\(title)"]),
            paths: ["/tmp/\(title)"],
            scoreImpact: 1,
            dataClass: dataClass
        )
    }

    func testDataClassRecoverabilitySemantics() {
        XCTAssertTrue(SmartCareDataClass.personal.isRecoverable)
        XCTAssertTrue(SmartCareDataClass.personal.requiresReview)
        XCTAssertFalse(SmartCareDataClass.systemJunk.isRecoverable)
        XCTAssertFalse(SmartCareDataClass.systemJunk.requiresReview)
    }

    func testDataClassDefaultsToSystemJunk() {
        let i = item(title: "cache", size: 10, dataClass: .systemJunk)
        XCTAssertEqual(i.dataClass, .systemJunk)
    }

    func testReviewStatePartitionsPersonalAndJunk() {
        let personal = item(title: "movie.mov", size: 500, count: 1, dataClass: .personal)
        let dup = item(title: "dupes", size: 300, count: 3, dataClass: .personal)
        let junk = item(title: "cache", size: 200, dataClass: .systemJunk)

        let review = SmartCleanReviewState(items: [personal, dup, junk])

        XCTAssertEqual(review.personalItems.count, 2)
        XCTAssertEqual(review.junkItems.count, 1)
        XCTAssertEqual(review.personalSize, 800)
        XCTAssertEqual(review.totalSize, 1000)
        // personalCount sums effective counts (dup group counts 3).
        XCTAssertEqual(review.personalCount, 4)
    }

    func testReviewStateWithOnlyJunkHasNoPersonalItems() {
        let junkA = item(title: "logs", size: 50, dataClass: .systemJunk)
        let junkB = item(title: "temp", size: 75, dataClass: .systemJunk)

        let review = SmartCleanReviewState(items: [junkA, junkB])

        XCTAssertTrue(review.personalItems.isEmpty)
        XCTAssertEqual(review.personalSize, 0)
        XCTAssertEqual(review.junkItems.count, 2)
    }

    func testRunSummaryRecoveryFlag() {
        let withRecovery = SmartScanRunSummary(
            tasksRun: 3,
            spaceFreed: 100,
            errors: 0,
            scoreImprovement: 2,
            recoveryBatchID: UUID(),
            recoverableCount: 2
        )
        XCTAssertTrue(withRecovery.hasRecoverable)

        let junkOnly = SmartScanRunSummary(
            tasksRun: 3,
            spaceFreed: 100,
            errors: 0,
            scoreImprovement: 2
        )
        XCTAssertFalse(junkOnly.hasRecoverable)
    }
}
