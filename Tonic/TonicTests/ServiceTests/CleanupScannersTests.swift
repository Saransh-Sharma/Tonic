import XCTest
@testable import Tonic

/// Fixture-driven tests for the Phase-B cleanup scanners: device backups,
/// mail attachments, broken preferences, and dangling launch agents.
final class CleanupScannersTests: XCTestCase {

    private var fixtureRoot: URL!

    override func setUpWithError() throws {
        fixtureRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("CleanupScannersTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: fixtureRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: fixtureRoot)
    }

    private func makeDir(_ relative: String) throws -> URL {
        let url = fixtureRoot.appendingPathComponent(relative)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func writeFile(_ relative: String, bytes: Int) throws {
        let url = fixtureRoot.appendingPathComponent(relative)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try Data(repeating: 0x41, count: bytes).write(to: url)
    }

    private func writePlist(_ relative: String, _ plist: [String: Any]) throws {
        let url = fixtureRoot.appendingPathComponent(relative)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: url)
    }

    // MARK: - MobileBackupScanner

    func testFindsBackupsWithDeviceMetadata() throws {
        let backupDate = Date(timeIntervalSinceNow: -400 * 24 * 3600)
        _ = try makeDir("Backup/ABC123")
        try writePlist("Backup/ABC123/Info.plist", [
            "Device Name": "Saransh's iPhone",
            "Product Type": "iPhone16,1",
            "Last Backup Date": backupDate,
        ])
        try writeFile("Backup/ABC123/Manifest.db", bytes: 4096)

        let scanner = MobileBackupScanner(backupRoot: fixtureRoot.appendingPathComponent("Backup").path)
        let backups = scanner.scanBackups()

        XCTAssertEqual(backups.count, 1)
        XCTAssertEqual(backups[0].deviceName, "Saransh's iPhone")
        XCTAssertEqual(backups[0].productType, "iPhone16,1")
        XCTAssertTrue(backups[0].isStale, "400-day-old backup must be stale")
        XCTAssertGreaterThan(backups[0].size, 0)
    }

    func testBackupWithoutInfoPlistFallsBackToFolderName() throws {
        _ = try makeDir("Backup/DEADBEEF")
        try writeFile("Backup/DEADBEEF/data.bin", bytes: 128)

        let scanner = MobileBackupScanner(backupRoot: fixtureRoot.appendingPathComponent("Backup").path)
        let backups = scanner.scanBackups()
        XCTAssertEqual(backups.count, 1)
        XCTAssertEqual(backups[0].deviceName, "DEADBEEF")
        XCTAssertTrue(backups[0].isStale, "unknown backup date counts as stale")
    }

    func testMissingBackupRootYieldsEmpty() {
        let scanner = MobileBackupScanner(backupRoot: fixtureRoot.appendingPathComponent("nope").path)
        XCTAssertTrue(scanner.scanBackups().isEmpty)
    }

    // MARK: - MailAttachmentScanner

    func testFindsOnlyLargeAttachmentsInsideAttachmentsDirs() throws {
        // Sizes are compared on ALLOCATED bytes (4 KB blocks on APFS), so the
        // fixtures need to differ by more than one block.
        try writeFile("Mail/V10/AccountA/INBOX.mbox/Data/Attachments/1/2/big.pdf", bytes: 64 * 1024)
        try writeFile("Mail/V10/AccountA/INBOX.mbox/Data/Attachments/1/3/small.txt", bytes: 10)
        // Large but NOT under an Attachments dir — must be ignored.
        try writeFile("Mail/V10/AccountA/INBOX.mbox/Data/Messages/big.emlx", bytes: 64 * 1024)

        let scanner = MailAttachmentScanner(
            sizeThreshold: 32 * 1024,
            mailRoot: fixtureRoot.appendingPathComponent("Mail").path,
            mailDownloadsRoot: fixtureRoot.appendingPathComponent("MailDownloads").path
        )
        let report = scanner.scan()

        XCTAssertEqual(report.largeAttachments.count, 1)
        XCTAssertTrue(report.largeAttachments[0].path.hasSuffix("big.pdf"))
        XCTAssertGreaterThanOrEqual(report.largeAttachments[0].size, 64 * 1024)
    }

    func testMailDownloadsListsTopLevelItems() throws {
        try writeFile("MailDownloads/report.pdf", bytes: 2048)
        _ = try makeDir("MailDownloads/folder")
        try writeFile("MailDownloads/folder/nested.zip", bytes: 512)

        let scanner = MailAttachmentScanner(
            sizeThreshold: 1024,
            mailRoot: fixtureRoot.appendingPathComponent("Mail").path,
            mailDownloadsRoot: fixtureRoot.appendingPathComponent("MailDownloads").path
        )
        let report = scanner.scan()

        XCTAssertEqual(report.mailDownloads.count, 2, "top-level file and folder, not nested contents")
        XCTAssertGreaterThan(report.mailDownloadsBytes, 0)
    }

    func testMissingMailRootsYieldEmptyReport() {
        let scanner = MailAttachmentScanner(
            mailRoot: fixtureRoot.appendingPathComponent("noMail").path,
            mailDownloadsRoot: fixtureRoot.appendingPathComponent("noDownloads").path
        )
        let report = scanner.scan()
        XCTAssertTrue(report.largeAttachments.isEmpty)
        XCTAssertTrue(report.mailDownloads.isEmpty)
    }

    // MARK: - SystemIntegrityScanner: broken preferences

    func testFlagsCorruptAndEmptyPlistsButNeverAppleDomains() throws {
        let prefs = try makeDir("Preferences")
        // Corrupt third-party plist.
        try Data("not a plist at all".utf8)
            .write(to: prefs.appendingPathComponent("com.example.broken.plist"))
        // Empty third-party plist.
        try Data().write(to: prefs.appendingPathComponent("com.example.empty.plist"))
        // Valid plist — must not be flagged.
        try writePlist("Preferences/com.example.good.plist", ["ok": true])
        // Corrupt APPLE plist — must never be flagged.
        try Data("garbage".utf8)
            .write(to: prefs.appendingPathComponent("com.apple.broken.plist"))

        let scanner = SystemIntegrityScanner(preferencesRoot: prefs.path)
        let entries = scanner.scanBrokenPreferences(runningBundleIDs: [])

        XCTAssertEqual(entries.count, 2)
        XCTAssertTrue(entries.contains { $0.path.hasSuffix("com.example.broken.plist") })
        XCTAssertTrue(entries.contains { $0.path.hasSuffix("com.example.empty.plist") && $0.reason == "Empty file" })
        XCTAssertFalse(entries.contains { $0.path.contains("com.apple.") })
    }

    func testSkipsPlistsOfRunningApps() throws {
        let prefs = try makeDir("Preferences")
        try Data("garbage".utf8)
            .write(to: prefs.appendingPathComponent("com.example.running.plist"))

        let scanner = SystemIntegrityScanner(preferencesRoot: prefs.path)
        let entries = scanner.scanBrokenPreferences(runningBundleIDs: ["com.example.running"])
        XCTAssertTrue(entries.isEmpty)
    }

    // MARK: - SystemIntegrityScanner: dangling launch agents

    func testFlagsAgentsWithMissingBinaries() throws {
        let agents = try makeDir("LaunchAgents")
        // Dangling: absolute program path that doesn't exist.
        try writePlist("LaunchAgents/com.gone.helper.plist", [
            "Label": "com.gone.helper",
            "ProgramArguments": ["/Applications/GoneApp.app/Contents/MacOS/helper", "--daemon"],
        ])
        // Healthy: /bin/ls exists.
        try writePlist("LaunchAgents/com.fine.helper.plist", [
            "Label": "com.fine.helper",
            "Program": "/bin/ls",
        ])
        // Relative program name — can't judge, must be skipped.
        try writePlist("LaunchAgents/com.relative.helper.plist", [
            "Label": "com.relative.helper",
            "ProgramArguments": ["helper-tool"],
        ])
        // App-managed agent — skipped even though the binary is missing.
        try writePlist("LaunchAgents/com.appmanaged.plist", [
            "Label": "com.appmanaged",
            "Program": "/Applications/GoneApp.app/Contents/MacOS/agent",
            "AssociatedBundleIdentifiers": ["com.appmanaged.app"],
        ])

        let scanner = SystemIntegrityScanner(launchAgentsRoot: agents.path)
        let entries = scanner.scanDanglingLaunchAgents()

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].label, "com.gone.helper")
        XCTAssertEqual(entries[0].missingProgramPath, "/Applications/GoneApp.app/Contents/MacOS/helper")
    }
}
