//
//  DiskAnalysisViewTests.swift
//  TonicTests
//
//  Regression tests for disk-analysis models and scan-mode behavior.
//

import Foundation
import XCTest
@testable import Tonic

final class DiskAnalysisViewTests: XCTestCase {
    func testStorageScanModeRawValues() {
        XCTAssertEqual(StorageScanMode.quick.rawValue, "Quick")
        XCTAssertEqual(StorageScanMode.full.rawValue, "Full")
        XCTAssertEqual(StorageScanMode.targeted.rawValue, "Targeted")
    }

    func testStorageScanModeIDsAreStableAndUnique() {
        let ids = StorageScanMode.allCases.map(\.id)
        XCTAssertEqual(Set(ids).count, StorageScanMode.allCases.count)
        XCTAssertTrue(ids.contains("Quick"))
        XCTAssertTrue(ids.contains("Full"))
        XCTAssertTrue(ids.contains("Targeted"))
    }

    func testStorageDomainIconsAreNonEmpty() {
        for domain in StorageDomain.allCases {
            XCTAssertFalse(domain.icon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    func testCleanupCandidateCodableRoundTripWithTypedBlockedReason() throws {
        let candidate = CleanupCandidate(
            id: UUID(),
            nodeId: "node-1",
            path: "/Users/test/Downloads/file.log",
            actionType: .moveToTrash,
            estimatedReclaimBytes: 2_048,
            riskLevel: .low,
            safeReason: "Temp file",
            blockedReason: .missingScope,
            selected: true
        )

        let encoded = try JSONEncoder().encode(candidate)
        let decoded = try JSONDecoder().decode(CleanupCandidate.self, from: encoded)

        XCTAssertEqual(decoded.id, candidate.id)
        XCTAssertEqual(decoded.blockedReason, .missingScope)
        XCTAssertEqual(decoded.path, candidate.path)
    }

    func testCleanupCandidateDecodesLegacyBlockedReasonProtected() throws {
        let id = UUID().uuidString
        let json = """
        {
          "id": "\(id)",
          "nodeId": "legacy-node",
          "path": "/System/Library",
          "actionType": "moveToTrash",
          "estimatedReclaimBytes": 100,
          "riskLevel": "protected",
          "safeReason": "Legacy payload",
          "blockedReason": "Protected by macOS",
          "selected": false
        }
        """

        let decoded = try JSONDecoder().decode(CleanupCandidate.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.blockedReason, .macOSProtected)
    }

    func testCleanupCandidateDecodesLegacyBlockedReasonScope() throws {
        let id = UUID().uuidString
        let json = """
        {
          "id": "\(id)",
          "nodeId": "legacy-node",
          "path": "/Users/test/Library/Caches",
          "actionType": "moveToTrash",
          "estimatedReclaimBytes": 100,
          "riskLevel": "medium",
          "safeReason": "Legacy payload",
          "blockedReason": "Needs access scope",
          "selected": false
        }
        """

        let decoded = try JSONDecoder().decode(CleanupCandidate.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.blockedReason, .missingScope)
    }

    func testCleanupCandidateDecodesUnknownLegacyBlockedReasonAsNil() throws {
        let id = UUID().uuidString
        let json = """
        {
          "id": "\(id)",
          "nodeId": "legacy-node",
          "path": "/Users/test/Documents",
          "actionType": "moveToTrash",
          "estimatedReclaimBytes": 100,
          "riskLevel": "low",
          "safeReason": "Legacy payload",
          "blockedReason": "unexpected reason string",
          "selected": false
        }
        """

        let decoded = try JSONDecoder().decode(CleanupCandidate.self, from: Data(json.utf8))
        XCTAssertNil(decoded.blockedReason)
    }
}
