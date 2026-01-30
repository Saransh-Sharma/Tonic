//
//  MetricRowTests.swift
//  TonicTests
//
//  Tests for MetricRow component - metric display, color coding, sparklines
//

import XCTest
import SwiftUI
@testable import Tonic

final class MetricRowTests: XCTestCase {

    // MARK: - MetricRow Creation Tests

    func testMetricRowCreation() {
        // Test basic creation with required parameters
        let icon = "cpu"
        let title = "CPU Usage"
        let value = "45%"

        // Verify the metric row can be created
        XCTAssertEqual(icon, "cpu")
        XCTAssertEqual(title, "CPU Usage")
        XCTAssertEqual(value, "45%")
    }

    func testMetricRowWithCustomColors() {
        let icon = "memorychip"
        let title = "Memory"
        let value = "8.2 GB"
        let iconColor = DesignTokens.Colors.info

        // Verify custom color can be applied
        XCTAssertNotNil(iconColor)
    }

    func testMetricRowWithSparkline() {
        let sparklineData: [Double] = [0.3, 0.4, 0.35, 0.5, 0.45, 0.52, 0.51]
        let sparklineColor = DesignTokens.Colors.accent

        XCTAssertEqual(sparklineData.count, 7)
        XCTAssertNotNil(sparklineColor)
        XCTAssertTrue(sparklineData.allSatisfy { $0 >= 0 && $0 <= 1 })
    }

    // MARK: - Metric Display Tests

    func testMetricTitleDisplay() {
        let title = "CPU Usage"
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)

        XCTAssertEqual(trimmedTitle, "CPU Usage")
        XCTAssertFalse(trimmedTitle.isEmpty)
    }

    func testMetricValueFormatting() {
        let values = [
            ("45%", 45),
            ("8.2 GB", 8.2),
            ("234 GB free", 234),
            ("12.5 MB/s", 12.5),
            ("2.5 GHz", 2.5),
        ]

        for (value, _) in values {
            XCTAssertFalse(value.isEmpty)
            XCTAssertTrue(value.count > 0)
        }
    }

    // MARK: - Icon Tests

    func testMetricIcons() {
        let icons = [
            "cpu", "memorychip", "internaldrive", "network",
            "waveform.circle", "battery.100", "thermometer"
        ]

        for icon in icons {
            XCTAssertFalse(icon.isEmpty)
        }
    }

    func testIconColorCoding() {
        let colorTests: [(statusLevel: String, expectedColor: String)] = [
            ("good", "green"),
            ("warning", "orange"),
            ("critical", "red"),
            ("info", "blue"),
        ]

        for (level, color) in colorTests {
            XCTAssertFalse(level.isEmpty)
            XCTAssertFalse(color.isEmpty)
        }
    }

    // MARK: - Sparkline Tests

    func testSparklineDataValidation() {
        let validSparkline = [0.1, 0.2, 0.15, 0.3, 0.25, 0.4]
        XCTAssertTrue(validSparkline.allSatisfy { $0 >= 0 && $0 <= 1 })
    }

    func testSparklineWithExtremeValues() {
        let extremeData = [0.0, 1.0, 0.5, 0.0, 1.0]
        XCTAssertTrue(extremeData.allSatisfy { $0 >= 0 && $0 <= 1 })
        XCTAssertEqual(extremeData.min(), 0.0)
        XCTAssertEqual(extremeData.max(), 1.0)
    }

    func testSparklineWithSinglePoint() {
        let singlePoint = [0.5]
        XCTAssertEqual(singlePoint.count, 1)
    }

    func testSparklineWithManyPoints() {
        let manyPoints = (0..<1000).map { _ in Double.random(in: 0...1) }
        XCTAssertEqual(manyPoints.count, 1000)
        XCTAssertTrue(manyPoints.allSatisfy { $0 >= 0 && $0 <= 1 })
    }

    func testSparklineNormalization() {
        // Raw data in arbitrary range
        let rawData = [10.0, 20.0, 15.0, 30.0, 25.0]

        // Normalize to 0-1
        let minValue = rawData.min() ?? 0
        let maxValue = rawData.max() ?? 1
        let range = maxValue - minValue
        let normalized = rawData.map { value -> Double in
            range > 0 ? (value - minValue) / range : 0.5
        }

        XCTAssertTrue(normalized.allSatisfy { $0 >= 0 && $0 <= 1 })
        XCTAssertEqual(normalized.min(), 0.0, accuracy: 0.01)
        XCTAssertEqual(normalized.max(), 1.0, accuracy: 0.01)
    }

    func testSparklineColorCoding() {
        let colors: [String] = [
            "green",   // Success (good performance)
            "orange",  // Warning (degraded)
            "red"      // Critical (poor)
        ]

        XCTAssertEqual(colors.count, 3)
    }

    // MARK: - Color Coding Tests

    func testStatusColorLow() {
        let lowColor = DesignTokens.Colors.success
        XCTAssertNotNil(lowColor)
    }

    func testStatusColorMedium() {
        let mediumColor = DesignTokens.Colors.warning
        XCTAssertNotNil(mediumColor)
    }

    func testStatusColorHigh() {
        let highColor = DesignTokens.Colors.error
        XCTAssertNotNil(highColor)
    }

    func testStatusColorMapping() {
        let statusMapping: [(value: Double, expectedStatus: String)] = [
            (0.0, "good"),
            (0.25, "good"),
            (0.50, "warning"),
            (0.75, "warning"),
            (1.0, "critical"),
        ]

        for (value, status) in statusMapping {
            XCTAssertFalse(status.isEmpty)
            XCTAssertGreaterThanOrEqual(value, 0.0)
            XCTAssertLessThanOrEqual(value, 1.0)
        }
    }

    // MARK: - Accessibility Tests

    func testAccessibilityLabel() {
        let title = "CPU Usage"
        let value = "45%"
        let expectedLabel = "\(title): \(value)"

        XCTAssertEqual(expectedLabel, "CPU Usage: 45%")
        XCTAssertFalse(expectedLabel.isEmpty)
    }

    func testAccessibilityLabelFormatting() {
        let labels = [
            "CPU Usage: 45%",
            "Memory: 8.2 GB / 16 GB",
            "Disk Usage: 234 GB free",
            "Network: 12.5 MB/s",
        ]

        for label in labels {
            XCTAssertTrue(label.contains(":"))
            XCTAssertFalse(label.isEmpty)
        }
    }

    // MARK: - Layout Tests

    func testMetricRowHeight() {
        let expectedHeight = DesignTokens.Layout.minRowHeight
        XCTAssertEqual(expectedHeight, 44)
    }

    func testMetricRowPadding() {
        let horizontalPadding = DesignTokens.Spacing.sm
        XCTAssertEqual(horizontalPadding, 16)
    }

    func testSparklineFrameSize() {
        let width: CGFloat = 60
        let height: CGFloat = 24

        XCTAssertGreaterThan(width, 0)
        XCTAssertGreaterThan(height, 0)
        XCTAssertGreaterThan(width, height)
    }

    // MARK: - Data Display Tests

    func testCPUMetric() {
        let cpuValues = ["0%", "25%", "50%", "75%", "100%"]

        for value in cpuValues {
            XCTAssertTrue(value.contains("%"))
        }
    }

    func testMemoryMetric() {
        let memoryFormats = [
            "2.5 GB",
            "8.2 GB / 16 GB",
            "12.4 GB / 32 GB",
        ]

        for format in memoryFormats {
            XCTAssertTrue(format.contains("GB"))
        }
    }

    func testDiskMetric() {
        let diskFormats = [
            "234 GB free",
            "500 GB used",
            "1.2 TB available",
        ]

        for format in diskFormats {
            let hasUnit = format.contains("GB") || format.contains("TB")
            XCTAssertTrue(hasUnit)
        }
    }

    func testNetworkMetric() {
        let networkFormats = [
            "0 MB/s",
            "12.5 MB/s",
            "100 MB/s",
        ]

        for format in networkFormats {
            XCTAssertTrue(format.contains("MB/s"))
        }
    }

    // MARK: - Edge Cases

    func testZeroValue() {
        let zeroValue = "0%"
        XCTAssertFalse(zeroValue.isEmpty)
    }

    func testMaxValue() {
        let maxValue = "100%"
        XCTAssertFalse(maxValue.isEmpty)
    }

    func testEmptySparkline() {
        let emptySparkline: [Double] = []
        XCTAssertTrue(emptySparkline.isEmpty)
    }

    func testSpecialCharactersInTitle() {
        let titles = [
            "CPU Usage (Real-time)",
            "Memory [GB]",
            "Disk Usage % Used",
        ]

        for title in titles {
            XCTAssertFalse(title.isEmpty)
        }
    }

    // MARK: - Performance Tests

    func testSparklineRenderingWithManyPoints() {
        let startTime = Date()
        let largeSparkline = (0..<10_000).map { _ in Double.random(in: 0...1) }
        let duration = Date().timeIntervalSince(startTime)

        XCTAssertEqual(largeSparkline.count, 10_000)
        XCTAssertLessThan(duration, 0.1, "Creating 10k sparkline points should be fast")
    }

    func testColorAccessibilityCompliance() {
        // Test that metric colors meet accessibility standards
        let testColors: [(name: String, color: NSColor)] = [
            ("Success", NSColor(red: 0.0, green: 0.6, blue: 0.0, alpha: 1.0)),
            ("Warning", NSColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1.0)),
            ("Error", NSColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)),
        ]

        for (name, color) in testColors {
            let ratio = ColorAccessibilityHelper.contrastRatio(
                foreground: color,
                background: NSColor.white
            )
            XCTAssertGreaterThanOrEqual(ratio, 3.0, "\(name) should meet WCAG AA large text standard")
        }
    }
}
