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

    func testDesignGalleryDocumentsTonicDSPrimitiveFamilies() throws {
        let source = try source(relativePath: "Tonic/Tonic/Views/Advanced/DesignGalleryView.swift")
        let requiredFragments = [
            "TonicScreenScaffold",
            "PrimaryPill(",
            "TextAction(",
            "FilterPill(",
            "CategoryFilterChip(",
            "GaugeCard(",
            "ChartCard(",
            "ModuleBand(",
            "MonitoringConsole",
            "ConsoleMetricRow",
            "ScanCategoryCard",
            "SettingsPanel",
            "SystemListRow",
            "SheetChrome",
            "TonicEmptyState",
            "TonicErrorNotice",
            "TonicOverflowFade"
        ]

        for fragment in requiredFragments {
            XCTAssertTrue(source.contains(fragment), "Design Gallery should include \(fragment)")
        }
    }

    func testPermissionRequiredUsesTonicPrimaryPill() throws {
        let source = try source(relativePath: "Tonic/Tonic/Views/ContentView.swift")
        XCTAssertFalse(source.contains(".buttonStyle(.borderedProminent)"))
        XCTAssertTrue(source.contains("PrimaryPill(\"Grant Permission\")"))
    }

    func testWidgetEnabledChromeIsNotStatusGreen() throws {
        let source = try source(relativePath: "Tonic/Tonic/Views/Settings/ModulesSettingsContent.swift")
        XCTAssertFalse(source.contains("config.isEnabled ? TonicDS.Colors.statusSuccess"))
        XCTAssertFalse(source.contains("preferences.config(for: module)?.isEnabled ?? false) ? TonicDS.Colors.statusSuccess"))
    }

    func testLinearGradientUsageIsNamedUtilityOrDataChartOnly() throws {
        let allowed = Set([
            "Tonic/Tonic/Design/TonicEditorialComponents.swift",
            "Tonic/Tonic/MenuBarWidgets/Components/SparklineChart.swift",
            // User-configured cosmetic menu bar tint — a utility gradient the
            // user opts into, not chrome.
            "Tonic/Tonic/Views/MenuBar/MenuBarStyleOverlayView.swift"
        ])
        let files = try swiftFiles(under: projectRoot.appendingPathComponent("Tonic/Tonic"))
        for file in files {
            let relative = file.path.replacingOccurrences(of: projectRoot.path + "/", with: "")
            let body = try String(contentsOf: file, encoding: .utf8)
            if body.contains("LinearGradient(") {
                XCTAssertTrue(allowed.contains(relative), "Unexpected LinearGradient in \(relative)")
            }
        }
    }

    func testProductionViewsDoNotUseLegacyVisualTokens() throws {
        let checkedRoots = [
            projectRoot.appendingPathComponent("Tonic/Tonic/Views"),
            projectRoot.appendingPathComponent("Tonic/Tonic/MenuBarWidgets")
        ]
        let banned = [
            "DesignTokens.",
            "TonicThemeTokens.",
            "NSColor.controlBackgroundColor",
            "controlBackgroundColor",
            ".buttonStyle(.borderedProminent)"
        ]

        for root in checkedRoots {
            for file in try swiftFiles(under: root) {
                let relative = file.path.replacingOccurrences(of: projectRoot.path + "/", with: "")
                let body = try String(contentsOf: file, encoding: .utf8)
                for token in banned {
                    XCTAssertFalse(body.contains(token), "\(relative) should not contain \(token)")
                }
            }
        }
    }

    // MARK: - Glass authority (materials resolve only through Design/)

    func testHandRolledMaterialsStayInsideDesignLayer() throws {
        let materialTokens = [".ultraThinMaterial", ".thinMaterial", ".thickMaterial", ".regularMaterial"]
        let files = try swiftFiles(under: projectRoot.appendingPathComponent("Tonic/Tonic"))
        for file in files {
            let relative = file.path.replacingOccurrences(of: projectRoot.path + "/", with: "")
            guard !relative.hasPrefix("Tonic/Tonic/Design/") else { continue }
            let body = try String(contentsOf: file, encoding: .utf8)
            for token in materialTokens {
                XCTAssertFalse(body.contains(token),
                               "\(relative) hand-rolls \(token); resolve via .tonicSurface instead")
            }
        }
    }

    // MARK: - Motion policy (system OR app toggle silences every recipe)

    func testMotionPolicyNilsAllAnimationsWhenReduced() {
        let reduced = TonicMotionPolicy(reduceMotion: true, appReducesMotion: false)
        XCTAssertNil(reduced.feedback)
        XCTAssertNil(reduced.transition)
        XCTAssertNil(reduced.layout)
        XCTAssertNil(reduced.proof)
        XCTAssertNil(reduced.flyout)
        XCTAssertNil(reduced.morph)
        XCTAssertNil(reduced.ripple)
        XCTAssertNil(reduced.particles)

        let appReduced = TonicMotionPolicy(reduceMotion: false, appReducesMotion: true)
        XCTAssertNil(appReduced.flyout, "app-level Reduce Motion must silence the flyout spring")

        let live = TonicMotionPolicy(reduceMotion: false, appReducesMotion: false)
        XCTAssertNotNil(live.feedback)
        XCTAssertNotNil(live.flyout)
        XCTAssertNotNil(live.morph)
        XCTAssertNotNil(live.ripple)
        XCTAssertNotNil(live.particles)
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

    private var projectRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func source(relativePath: String) throws -> String {
        try String(contentsOf: projectRoot.appendingPathComponent(relativePath), encoding: .utf8)
    }

    private func swiftFiles(under root: URL) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return try enumerator.compactMap { item in
            guard let url = item as? URL, url.pathExtension == "swift" else { return nil }
            let values = try url.resourceValues(forKeys: [.isRegularFileKey])
            return values.isRegularFile == true ? url : nil
        }
    }
}
