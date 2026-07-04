import XCTest
@testable import Tonic

@MainActor
final class AppUpdaterTests: XCTestCase {

    // MARK: - Bundle fixtures

    /// Build a minimal .app bundle layout in a temp directory.
    private func makeAppBundle(
        name: String,
        infoPlist: [String: Any],
        masReceipt: Bool = false
    ) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppUpdaterTests-\(UUID().uuidString)")
        let appURL = root.appendingPathComponent("\(name).app")
        let contents = appURL.appendingPathComponent("Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)

        let plistData = try PropertyListSerialization.data(
            fromPropertyList: infoPlist, format: .xml, options: 0
        )
        try plistData.write(to: contents.appendingPathComponent("Info.plist"))

        if masReceipt {
            let receiptDir = contents.appendingPathComponent("_MASReceipt")
            try FileManager.default.createDirectory(at: receiptDir, withIntermediateDirectories: true)
            try Data("receipt".utf8).write(to: receiptDir.appendingPathComponent("receipt"))
        }
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        return appURL
    }

    // MARK: - Receipt detection

    func testDetectsMASReceipt() throws {
        let masApp = try makeAppBundle(
            name: "StoreApp",
            infoPlist: ["CFBundleIdentifier": "com.test.store", "CFBundleShortVersionString": "1.0"],
            masReceipt: true
        )
        let plainApp = try makeAppBundle(
            name: "PlainApp",
            infoPlist: ["CFBundleIdentifier": "com.test.plain", "CFBundleShortVersionString": "1.0"]
        )
        XCTAssertTrue(AppUpdater.shared.hasMASReceipt(appPath: masApp))
        XCTAssertFalse(AppUpdater.shared.hasMASReceipt(appPath: plainApp))
    }

    // MARK: - Sparkle feed URL extraction

    func testExtractsSparkleFeedURL() throws {
        let app = try makeAppBundle(
            name: "SparkleApp",
            infoPlist: [
                "CFBundleIdentifier": "com.test.sparkle",
                "CFBundleShortVersionString": "2.0",
                "SUFeedURL": "https://example.com/appcast.xml",
            ]
        )
        XCTAssertEqual(
            AppUpdater.shared.sparkleFeedURL(forAppAt: app)?.absoluteString,
            "https://example.com/appcast.xml"
        )
    }

    func testRejectsNonHTTPFeedURL() throws {
        let app = try makeAppBundle(
            name: "WeirdApp",
            infoPlist: [
                "CFBundleIdentifier": "com.test.weird",
                "SUFeedURL": "file:///etc/passwd",
            ]
        )
        XCTAssertNil(AppUpdater.shared.sparkleFeedURL(forAppAt: app))
    }

    func testNoFeedURLForAppWithoutSparkle() throws {
        let app = try makeAppBundle(
            name: "NoSparkle",
            infoPlist: ["CFBundleIdentifier": "com.test.nosparkle"]
        )
        XCTAssertNil(AppUpdater.shared.sparkleFeedURL(forAppAt: app))
    }

    // MARK: - Unknown-source apps

    /// Apps with no receipt and no appcast resolve to a quiet, non-updatable
    /// record — never an error, never a phantom update.
    func testUnknownSourceAppYieldsNoUpdateAndNoError() async throws {
        let app = try makeAppBundle(
            name: "Standalone",
            infoPlist: [
                "CFBundleIdentifier": "com.test.standalone",
                "CFBundleShortVersionString": "4.2",
                "CFBundleName": "Standalone",
            ]
        )
        let update = try await AppUpdater.shared.checkUpdate(
            for: "com.test.standalone",
            currentVersion: "4.2",
            appPath: app
        )
        XCTAssertEqual(update.source, .unknown)
        XCTAssertFalse(update.updateAvailable)
        XCTAssertEqual(update.currentVersion, "4.2")
    }

    /// Batch checking never loses apps: every app produces a result or an error.
    func testBatchCheckAccountsForEveryApp() async throws {
        var apps: [AppMetadata] = []
        for i in 0..<7 {
            let bundle = try makeAppBundle(
                name: "Batch\(i)",
                infoPlist: [
                    "CFBundleIdentifier": "com.test.batch\(i)",
                    "CFBundleShortVersionString": "1.\(i)",
                    "CFBundleName": "Batch\(i)",
                ]
            )
            apps.append(AppMetadata(
                bundleIdentifier: "com.test.batch\(i)",
                appName: "Batch\(i)",
                path: bundle,
                version: "1.\(i)"
            ))
        }

        let result = await AppUpdater.shared.checkUpdates(for: apps)
        XCTAssertEqual(result.appsChecked, 7)
        XCTAssertEqual(result.updates.count + result.errors.count, 7)
        XCTAssertEqual(result.updatesAvailable, 0)
    }
}
