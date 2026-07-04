import XCTest
@testable import Tonic

final class ChartScaleTests: XCTestCase {

    func testAutoModeAlwaysAutoScales() {
        XCTAssertNil(ChartScale.resolvedMax(mode: .auto, fixedValue: 100, isPercentSeries: true))
        XCTAssertNil(ChartScale.resolvedMax(mode: .auto, fixedValue: 100, isPercentSeries: false))
    }

    func testNoneModePinsPercentSeriesToHundred() {
        XCTAssertEqual(ChartScale.resolvedMax(mode: .none, fixedValue: 55, isPercentSeries: true), 100)
    }

    func testFixedModeUsesFixedValueForPercentSeries() {
        XCTAssertEqual(ChartScale.resolvedMax(mode: .fixed, fixedValue: 80, isPercentSeries: true), 80)
    }

    func testFixedModeClampsOutOfRangeValues() {
        XCTAssertEqual(ChartScale.resolvedMax(mode: .fixed, fixedValue: 5, isPercentSeries: true), 10)
        XCTAssertEqual(ChartScale.resolvedMax(mode: .fixed, fixedValue: 999, isPercentSeries: true), 200)
    }

    func testRateSeriesNeverPin() {
        XCTAssertNil(ChartScale.resolvedMax(mode: .none, fixedValue: 100, isPercentSeries: false))
        XCTAssertNil(ChartScale.resolvedMax(mode: .fixed, fixedValue: 100, isPercentSeries: false))
    }

    func testPercentSeriesWidgetMapping() {
        XCTAssertTrue(WidgetType.cpu.hasPercentHistory)
        XCTAssertTrue(WidgetType.memory.hasPercentHistory)
        XCTAssertTrue(WidgetType.gpu.hasPercentHistory)
        XCTAssertTrue(WidgetType.battery.hasPercentHistory)
        XCTAssertFalse(WidgetType.network.hasPercentHistory)
        XCTAssertFalse(WidgetType.disk.hasPercentHistory)
        XCTAssertFalse(WidgetType.sensors.hasPercentHistory)
    }

    func testSettingsConvenienceUsesWidgetMapping() {
        let settings = PopupSettings(scalingMode: .none)
        XCTAssertEqual(settings.chartFixedMax(for: .cpu), 100)
        XCTAssertNil(settings.chartFixedMax(for: .network))
    }
}
