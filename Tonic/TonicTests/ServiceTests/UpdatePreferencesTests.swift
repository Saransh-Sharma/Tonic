import XCTest
@testable import Tonic

final class UpdatePreferencesTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUpWithError() throws {
        suiteName = "UpdatePreferencesTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func makeUpdate(bundleID: String, latest: String) -> AppUpdate {
        AppUpdate(
            bundleIdentifier: bundleID,
            appName: bundleID,
            currentVersion: "1.0",
            latestVersion: latest,
            appPath: URL(fileURLWithPath: "/Applications/Test.app"),
            updateAvailable: true,
            source: .sparkle
        )
    }

    @MainActor func testDefaultsAreDailyAndNotifying() {
        let prefs = UpdatePreferences(defaults: defaults)
        XCTAssertEqual(prefs.cadence, .daily)
        XCTAssertTrue(prefs.notifyOnUpdates)
        XCTAssertTrue(prefs.ignoredBundleIDs.isEmpty)
    }

    @MainActor func testIgnoredAppIsNotSurfaced() {
        let prefs = UpdatePreferences(defaults: defaults)
        let update = makeUpdate(bundleID: "com.test.a", latest: "2.0")
        XCTAssertTrue(prefs.shouldSurface(update))
        prefs.ignore("com.test.a")
        XCTAssertFalse(prefs.shouldSurface(update))
        prefs.unignore("com.test.a")
        XCTAssertTrue(prefs.shouldSurface(update))
    }

    @MainActor func testSkippedVersionHidesOnlyThatVersion() {
        let prefs = UpdatePreferences(defaults: defaults)
        prefs.skipVersion("2.0", for: "com.test.b")
        XCTAssertFalse(prefs.shouldSurface(makeUpdate(bundleID: "com.test.b", latest: "2.0")))
        // The NEXT release must surface again.
        XCTAssertTrue(prefs.shouldSurface(makeUpdate(bundleID: "com.test.b", latest: "2.1")))
    }

    @MainActor func testPreferencesPersistAcrossInstances() {
        let prefs = UpdatePreferences(defaults: defaults)
        prefs.cadence = .weekly
        prefs.notifyOnUpdates = false
        prefs.ignore("com.test.c")
        prefs.skipVersion("3.0", for: "com.test.d")

        let reloaded = UpdatePreferences(defaults: defaults)
        XCTAssertEqual(reloaded.cadence, .weekly)
        XCTAssertFalse(reloaded.notifyOnUpdates)
        XCTAssertTrue(reloaded.isIgnored("com.test.c"))
        XCTAssertFalse(reloaded.shouldSurface(makeUpdate(bundleID: "com.test.d", latest: "3.0")))
    }

    @MainActor func testAutoCheckDueLogic() {
        let prefs = UpdatePreferences(defaults: defaults)

        prefs.cadence = .manual
        XCTAssertFalse(prefs.isAutoCheckDue(), "manual cadence never auto-checks")

        prefs.cadence = .daily
        prefs.lastCheckDate = nil
        XCTAssertTrue(prefs.isAutoCheckDue(), "never-checked is always due")

        prefs.lastCheckDate = Date().addingTimeInterval(-2 * 3600)
        XCTAssertFalse(prefs.isAutoCheckDue(), "checked 2h ago is not due daily")

        prefs.lastCheckDate = Date().addingTimeInterval(-25 * 3600)
        XCTAssertTrue(prefs.isAutoCheckDue(), "checked 25h ago is due daily")

        prefs.cadence = .weekly
        XCTAssertFalse(prefs.isAutoCheckDue(), "25h ago is not due weekly")
    }
}

/// Live end-to-end proof against a real appcast. Opt-in only:
/// run with TONIC_LIVE_TESTS=1 in the environment.
final class LiveUpdateCheckIntegrationTests: XCTestCase {

    @MainActor func testRealAppcastParsesToARealVersion() async throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["TONIC_LIVE_TESTS"] == "1",
            "live network test — set TONIC_LIVE_TESTS=1 to run"
        )

        // Rectangle publishes a stable element-style Sparkle feed.
        let url = URL(string: "https://rectangleapp.com/downloads/updates.xml")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let best = try SparkleAppcastParser.bestItem(from: data)

        let version = try XCTUnwrap(best.displayVersion)
        XCTAssertFalse(version.isEmpty)
        XCTAssertNotEqual(version, "1.0", "must never scrape the XML declaration")
        XCTAssertFalse(SemanticVersion(version).isEmpty, "version must parse numerically")
        XCTAssertNotNil(best.enclosureURL, "release item should carry a download enclosure")

        // A realistically old installed version must register as updatable.
        XCTAssertEqual(AppUpdate.compareVersions("0.1", version), .updateAvailable)
    }
}
