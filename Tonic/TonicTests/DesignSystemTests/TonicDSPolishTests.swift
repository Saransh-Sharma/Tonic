//
//  TonicDSPolishTests.swift
//  TonicTests
//
//  Focused regression tests for the TonicDS polish pass.
//

import XCTest
import AppKit
@testable import Tonic

final class TonicDSPolishTests: XCTestCase {

    func testConsoleStatusColorsMeetWCAGAAForText() {
        let console = nsColor(hex: "17171c")
        let colors: [(String, NSColor)] = [
            ("success", nsColor(hex: "1f9d57")),
            ("warning", nsColor(hex: "e0a32c")),
            ("caution", nsColor(hex: "e07b39")),
            ("critical", nsColor(hex: "e05252")),
            ("info", nsColor(hex: "4f8df0")),
            ("muted", nsColor(hex: "93939f"))
        ]

        for (name, color) in colors {
            let ratio = ColorAccessibilityHelper.contrastRatio(foreground: color, background: console)
            XCTAssertGreaterThanOrEqual(ratio, 4.5, "\(name) should meet AA on console")
        }
    }

    func testGaugeCardPercentFormatterClampsAndRoundsToInteger() {
        XCTAssertEqual(GaugeCardMetricFormatter.value(displayValue: "ignored", fraction: 0.294, mode: .percent), "29")
        XCTAssertEqual(GaugeCardMetricFormatter.value(displayValue: "ignored", fraction: 0.995, mode: .percent), "100")
        XCTAssertEqual(GaugeCardMetricFormatter.value(displayValue: "ignored", fraction: -0.4, mode: .percent), "0")
        XCTAssertEqual(GaugeCardMetricFormatter.value(displayValue: "ignored", fraction: 1.4, mode: .percent), "100")
        XCTAssertEqual(GaugeCardMetricFormatter.unit(providedUnit: nil, mode: .percent), "%")
    }

    func testGaugeCardPreformattedFormatterPreservesByteStrings() {
        XCTAssertEqual(GaugeCardMetricFormatter.value(displayValue: "37.09 GB", fraction: 0.92, mode: .preformatted), "37.09 GB")
        XCTAssertNil(GaugeCardMetricFormatter.unit(providedUnit: nil, mode: .preformatted))
        XCTAssertEqual(GaugeCardMetricFormatter.unit(providedUnit: "free", mode: .preformatted), "free")
    }

    private func nsColor(hex: String) -> NSColor {
        let value = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: value).scanHexInt64(&int)
        return NSColor(
            calibratedRed: CGFloat((int >> 16) & 0xff) / 255,
            green: CGFloat((int >> 8) & 0xff) / 255,
            blue: CGFloat(int & 0xff) / 255,
            alpha: 1
        )
    }
}
