import Foundation
import XCTest
@testable import Tonic

final class ResourceMetricCalculatorsTests: XCTestCase {
    func testCPUTotalUsesAllCores() {
        let previous = CPUCounterSnapshot(cores: [
            .init(user: 100, system: 0, idle: 900, nice: 0),
            .init(user: 100, system: 0, idle: 900, nice: 0)
        ])
        let current = CPUCounterSnapshot(cores: [
            .init(user: 200, system: 0, idle: 900, nice: 0),
            .init(user: 100, system: 0, idle: 1_000, nice: 0)
        ])

        let usage = ResourceMetricCalculators.cpuUsage(previous: previous, current: current)

        XCTAssertEqual(usage.totalUsage, 50, accuracy: 0.001)
        XCTAssertEqual(usage.perCoreUsage, [100, 0])
    }

    func testCPUUserSystemIdleAreDeltaBased() {
        let previous = CPUCounterSnapshot(cores: [
            .init(user: 100, system: 100, idle: 800, nice: 0)
        ])
        let current = CPUCounterSnapshot(cores: [
            .init(user: 130, system: 150, idle: 900, nice: 20)
        ])

        let usage = ResourceMetricCalculators.cpuUsage(previous: previous, current: current)

        XCTAssertEqual(usage.totalUsage, 50, accuracy: 0.001)
        XCTAssertEqual(usage.userUsage, 25, accuracy: 0.001)
        XCTAssertEqual(usage.systemUsage, 25, accuracy: 0.001)
        XCTAssertEqual(usage.idleUsage, 50, accuracy: 0.001)
    }

    func testFirstCPUSampleReturnsZeroBaseline() {
        let current = CPUCounterSnapshot(cores: [
            .init(user: 10, system: 10, idle: 80, nice: 0),
            .init(user: 20, system: 10, idle: 70, nice: 0)
        ])

        let usage = ResourceMetricCalculators.cpuUsage(previous: nil, current: current)

        XCTAssertEqual(usage.totalUsage, 0)
        XCTAssertEqual(usage.idleUsage, 100)
        XCTAssertEqual(usage.perCoreUsage, [0, 0])
    }

    func testCPUCounterResetNeverProducesNegativeUsage() {
        let previous = CPUCounterSnapshot(cores: [
            .init(user: 100, system: 100, idle: 100, nice: 0)
        ])
        let current = CPUCounterSnapshot(cores: [
            .init(user: 10, system: 20, idle: 30, nice: 0)
        ])

        let usage = ResourceMetricCalculators.cpuUsage(previous: previous, current: current)

        XCTAssertEqual(usage.totalUsage, 0)
        XCTAssertEqual(usage.perCoreUsage, [0])
    }

    func testNetworkRateUsesBytesPerSecond() {
        let rate = ResourceMetricCalculators.networkRate(previousBytes: 1_000, currentBytes: 6_000, elapsed: 2.5)
        XCTAssertEqual(rate, 2_000, accuracy: 0.001)
    }

    func testNetworkCounterResetReturnsZero() {
        let rate = ResourceMetricCalculators.networkRate(previousBytes: 6_000, currentBytes: 1_000, elapsed: 2.5)
        XCTAssertEqual(rate, 0)
    }

    func testMinuteBucketTimestampFloorsToMinute() {
        let date = Date(timeIntervalSince1970: 1_234.56)
        let bucket = ResourceMetricCalculators.minuteBucketTimestamp(for: date)
        XCTAssertEqual(bucket.timeIntervalSince1970, 1_200)
    }
}
