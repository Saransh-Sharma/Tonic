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

    // MARK: - StatusLevel (color + word single authority)

    func testStatusLevelThresholdsMatchStatusColorAuthority() {
        XCTAssertEqual(TonicDS.statusLevel(forFraction: 0.20), .success)
        XCTAssertEqual(TonicDS.statusLevel(forFraction: 0.60), .warning)
        XCTAssertEqual(TonicDS.statusLevel(forFraction: 0.80), .caution)
        XCTAssertEqual(TonicDS.statusLevel(forFraction: 0.95), .critical)

        XCTAssertEqual(TonicDS.statusLevel(forTempC: 45), .success)
        XCTAssertEqual(TonicDS.statusLevel(forTempC: 95), .critical)

        XCTAssertEqual(TonicDS.statusLevel(forBattery: 0.05, isCharging: false), .critical)
        XCTAssertEqual(TonicDS.statusLevel(forBattery: 0.05, isCharging: true), .info)
    }

    func testStatusLevelWordsAreNonEmptyAndDistinct() {
        let levels: [TonicDS.StatusLevel] = [.success, .warning, .caution, .critical, .info]
        let words = levels.map(\.word)
        XCTAssertEqual(Set(words).count, levels.count, "status words must be distinct")
        XCTAssertFalse(words.contains(where: \.isEmpty))
    }

    func testEmphasisAndLayoutTokens() {
        XCTAssertEqual(TonicDS.Emphasis.unit, 0.70, accuracy: 0.001)
        XCTAssertEqual(TonicDS.Emphasis.disabled, 0.35, accuracy: 0.001)
        XCTAssertEqual(TonicDS.Layout.statusDotSize, 6)
        XCTAssertEqual(TonicDS.Layout.inputHeight, 32)
    }

    // MARK: - Home hero arbitration (live health outranks scan bookkeeping)

    func testHeroArbiterPriorityLadder() {
        let bytes: (Int64) -> String = { "\($0) B" }
        var inputs = SystemStatusArbiter.Inputs(
            isScanning: false, scanPhase: "", scanProgress: 0,
            hasScanResult: true, reclaimableBytes: 1_000, recommendationCount: 2,
            memoryPressureCritical: false, diskFreeFraction: 0.4, thermalThrottled: false
        )

        // Recoverable bytes win when live health is fine.
        XCTAssertEqual(SystemStatusArbiter.declare(inputs, formatBytes: bytes).title, "1000 B to recover")

        // Thermal throttling outranks recoverable bytes.
        inputs.thermalThrottled = true
        XCTAssertEqual(SystemStatusArbiter.declare(inputs, formatBytes: bytes).title, "Running hot")
        XCTAssertTrue(SystemStatusArbiter.declare(inputs, formatBytes: bytes).leadsToMonitor)

        // Scanning outranks everything.
        inputs.isScanning = true
        inputs.scanPhase = "Space"
        XCTAssertEqual(SystemStatusArbiter.declare(inputs, formatBytes: bytes).title, "Scanning…")

        // Memory pressure and disk-full rank between throttle and recoverable.
        inputs.isScanning = false
        inputs.thermalThrottled = false
        inputs.memoryPressureCritical = true
        XCTAssertEqual(SystemStatusArbiter.declare(inputs, formatBytes: bytes).title, "Memory under pressure")

        inputs.memoryPressureCritical = false
        inputs.diskFreeFraction = 0.02
        XCTAssertEqual(SystemStatusArbiter.declare(inputs, formatBytes: bytes).title, "Disk almost full")

        // All clear / ready states.
        inputs.diskFreeFraction = 0.4
        inputs.reclaimableBytes = 0
        XCTAssertEqual(SystemStatusArbiter.declare(inputs, formatBytes: bytes).title, "All clear.")
        inputs.hasScanResult = false
        XCTAssertEqual(SystemStatusArbiter.declare(inputs, formatBytes: bytes).title, "Ready when you are")
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
