import XCTest
@testable import Tonic

final class MenuBarTriggerEvaluatorTests: XCTestCase {

    func testBatteryBelow() {
        let env = TriggerEnvironment(batteryPercent: 15)
        XCTAssertTrue(TriggerEvaluator.isSatisfied(.batteryBelow(percent: 20), in: env))
        XCTAssertFalse(TriggerEvaluator.isSatisfied(.batteryBelow(percent: 10), in: env))
    }

    func testBatteryBelowWithNoBattery() {
        let env = TriggerEnvironment(batteryPercent: nil)
        XCTAssertFalse(TriggerEvaluator.isSatisfied(.batteryBelow(percent: 50), in: env))
    }

    func testChargingAndOnBattery() {
        XCTAssertTrue(TriggerEvaluator.isSatisfied(.charging, in: TriggerEnvironment(isCharging: true)))
        XCTAssertTrue(TriggerEvaluator.isSatisfied(.onBattery, in: TriggerEnvironment(onBattery: true)))
        XCTAssertFalse(TriggerEvaluator.isSatisfied(.charging, in: TriggerEnvironment(isCharging: false)))
    }

    func testWifiSSID() {
        let env = TriggerEnvironment(ssid: "HomeNet")
        XCTAssertTrue(TriggerEvaluator.isSatisfied(.wifiSSID("HomeNet"), in: env))
        XCTAssertFalse(TriggerEvaluator.isSatisfied(.wifiSSID("Office"), in: env))
    }

    func testAppRunning() {
        let env = TriggerEnvironment(runningBundleIDs: ["com.apple.FaceTime", "com.zoom.xos"])
        XCTAssertTrue(TriggerEvaluator.isSatisfied(.appRunning(bundleID: "com.zoom.xos"), in: env))
        XCTAssertFalse(TriggerEvaluator.isSatisfied(.appRunning(bundleID: "com.slack"), in: env))
    }

    func testTimeWindowSameDay() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let now = date(hour: 10, minute: 30, cal: cal)
        // 09:00–17:00
        XCTAssertTrue(TriggerEvaluator.timeWindowSatisfied(start: 540, end: 1020, weekdays: [], now: now, calendar: cal))
        // 12:00–17:00 — before start
        XCTAssertFalse(TriggerEvaluator.timeWindowSatisfied(start: 720, end: 1020, weekdays: [], now: now, calendar: cal))
    }

    func testTimeWindowCrossesMidnight() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        // 22:00–06:00 window; 23:30 is inside, 12:00 is outside.
        let late = date(hour: 23, minute: 30, cal: cal)
        let noon = date(hour: 12, minute: 0, cal: cal)
        XCTAssertTrue(TriggerEvaluator.timeWindowSatisfied(start: 1320, end: 360, weekdays: [], now: late, calendar: cal))
        XCTAssertFalse(TriggerEvaluator.timeWindowSatisfied(start: 1320, end: 360, weekdays: [], now: noon, calendar: cal))
    }

    func testTimeWindowWeekdayFilter() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        // 2026-07-06 is a Monday (weekday 2).
        var comps = DateComponents()
        comps.year = 2026; comps.month = 7; comps.day = 6; comps.hour = 10
        let monday = cal.date(from: comps)!
        XCTAssertTrue(TriggerEvaluator.timeWindowSatisfied(start: 540, end: 1020, weekdays: [2], now: monday, calendar: cal))
        XCTAssertFalse(TriggerEvaluator.timeWindowSatisfied(start: 540, end: 1020, weekdays: [7], now: monday, calendar: cal))
    }

    func testTransitions() {
        let a = UUID(); let b = UUID(); let c = UUID()
        let (fired, cleared) = TriggerEvaluator.transitions(previous: [a, b], current: [b, c])
        XCTAssertEqual(fired, [c])
        XCTAssertEqual(cleared, [a])
    }

    private func date(hour: Int, minute: Int, cal: Calendar) -> Date {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 7; comps.day = 8
        comps.hour = hour; comps.minute = minute
        return cal.date(from: comps)!
    }
}
