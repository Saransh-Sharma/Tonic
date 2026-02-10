//
//  DashboardViewTests.swift
//  TonicTests
//
//  Regression tests for dashboard manager state.
//

import XCTest
@testable import Tonic

@MainActor
final class DashboardViewTests: XCTestCase {
    func testSmartScanManagerInitialState() {
        let manager = SmartScanManager()

        XCTAssertFalse(manager.isScanning)
        XCTAssertEqual(manager.scanProgress, 0.0)
        XCTAssertEqual(manager.currentPhase, .idle)
        XCTAssertFalse(manager.hasScanResult)
        XCTAssertTrue(manager.recommendations.isEmpty)
        XCTAssertNil(manager.lastScanDate)
    }

    func testStopSmartScanResetsInFlightState() {
        let manager = SmartScanManager()
        manager.isScanning = true
        manager.scanProgress = 0.6
        manager.currentPhase = .analyzingSystem
        manager.scanStartDate = Date()

        manager.stopSmartScan()

        XCTAssertFalse(manager.isScanning)
        XCTAssertEqual(manager.scanProgress, 0.0)
        XCTAssertEqual(manager.currentPhase, .idle)
        XCTAssertNil(manager.scanStartDate)
    }

    func testScanPhaseIconsExist() {
        for phase in SmartScanManager.ScanPhase.allCases {
            XCTAssertFalse(phase.icon.isEmpty)
        }
    }

    func testQuickActionsDoNotCrashWithoutRecommendations() async {
        let manager = SmartScanManager()
        await manager.quickClean()
        await manager.quickOptimize()
        XCTAssertTrue(true)
    }
}
