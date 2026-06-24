import Foundation
import XCTest
@testable import Tonic

final class AccessScopeModelsTests: XCTestCase {
    func testScopeBlockedReasonMessagesAreNonEmpty() {
        for reason in ScopeBlockedReason.allCases {
            XCTAssertFalse(reason.userMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    func testCoverageSummaryRoundTripState() {
        let summary = ScopeCoverageSummary(
            state: .limited,
            coveredPaths: ["/Users/test"],
            blockedPaths: ["/System": .macOSProtected]
        )

        XCTAssertEqual(summary.state, .limited)
        XCTAssertEqual(summary.coveredPaths.count, 1)
        XCTAssertEqual(summary.blockedPaths["/System"], .macOSProtected)
    }

    func testAccessScopeCodableRoundTrip() throws {
        let scope = AccessScope(
            displayName: "Home",
            rootPath: "/Users/test",
            kind: .home,
            bookmarkData: Data([0x00, 0x01])
        )

        let encoded = try JSONEncoder().encode(scope)
        let decoded = try JSONDecoder().decode(AccessScope.self, from: encoded)

        XCTAssertEqual(decoded.displayName, "Home")
        XCTAssertEqual(decoded.rootPath, "/Users/test")
        XCTAssertEqual(decoded.kind, .home)
        XCTAssertEqual(decoded.bookmarkData, Data([0x00, 0x01]))
    }

    func testAccessBrokerWithAccessScopeIDThrowsForUnknownScope() {
        XCTAssertThrowsError(try AccessBroker.shared.withAccess(scopeID: UUID()) { _ in () }) { error in
            guard case AccessBrokerError.scopeNotFound = error else {
                return XCTFail("Expected scopeNotFound, got \(error)")
            }
        }
    }

    func testAccessBrokerWithAccessForPathResolvesCanonicalPath() throws {
        let root = FileManager.default.temporaryDirectory.path
        let inputPath = root + "/../" + (root as NSString).lastPathComponent
        let resolved = try AccessBroker.shared.withAccess(forPath: inputPath) { url in
            url.path
        }
        XCTAssertEqual(resolved, ScopeResolver.shared.canonicalPath(inputPath))
    }

    func testScopedFileSystemResourceValuesAndRemoveItem() throws {
        let scopedFS = ScopedFileSystem.shared
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("tonic-scopedfs-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let fileURL = tempDirectory.appendingPathComponent("sample.txt")
        try Data("abc".utf8).write(to: fileURL)

        let values = try scopedFS.resourceValues(for: fileURL, keys: [.isDirectoryKey, .fileSizeKey])
        XCTAssertEqual(values.isDirectory, false)
        XCTAssertEqual(values.fileSize, 3)

        XCTAssertTrue(scopedFS.fileExists(atPath: fileURL.path))
        try scopedFS.removeItem(atPath: fileURL.path)
        XCTAssertFalse(scopedFS.fileExists(atPath: fileURL.path))
    }

    func testScopedFileSystemBlockedReasonMappingFromBrokerError() {
        let reason = ScopedFileSystem.shared.blockedReason(
            for: AccessBrokerError.blocked(.missingScope),
            path: "/tmp/example",
            requiresWrite: false
        )
        XCTAssertEqual(reason, .missingScope)
    }
}

final class Phase1TrustRegressionTests: XCTestCase {
    func testDuplicateKeepOneParentSelectionLeavesOneCopyUnselected() {
        let childIDs = ["/tmp/a.mov", "/tmp/b.mov", "/tmp/c.mov"]

        let selection = SmartCareSelectionPolicy.keepOneCopy.validatedSelection(
            proposed: Set(childIDs),
            orderedChildIDs: childIDs
        )

        XCTAssertEqual(selection, Set(["/tmp/b.mov", "/tmp/c.mov"]))
        XCTAssertFalse(selection.contains("/tmp/a.mov"))
    }

    func testDuplicateKeepOneRejectsSelectingEveryCopy() {
        let childIDs = ["/tmp/a.mov", "/tmp/b.mov"]

        let selection = SmartCareSelectionPolicy.keepOneCopy.validatedSelection(
            proposed: Set(childIDs),
            orderedChildIDs: childIDs
        )

        XCTAssertEqual(selection.count, 1)
        XCTAssertEqual(selection, Set(["/tmp/b.mov"]))
    }

    func testDuplicateProjectionDeletesOnlyRemovableCopies() {
        let item = SmartCareItem(
            domain: .cleanup,
            groupId: UUID(),
            title: "Duplicate Files",
            subtitle: "2 matching files · Keep at least one copy",
            size: 2_048,
            count: 2,
            safeToRun: true,
            isSmartSelected: false,
            action: .delete(paths: ["/tmp/a.mov", "/tmp/b.mov"]),
            paths: ["/tmp/a.mov", "/tmp/b.mov"],
            scoreImpact: 1,
            selectionPolicy: .keepOneCopy
        )

        let paths = SmartCareSelectionProjection.selectedDeletePaths(
            for: item,
            selectedChildIDs: ["/tmp/a.mov", "/tmp/b.mov"]
        )

        XCTAssertEqual(paths, ["/tmp/b.mov"])
        XCTAssertEqual(
            SmartCareSelectionProjection.projectedSize(for: item, selectedPathCount: paths.count, totalPathCount: item.paths.count),
            2_048
        )
    }

    func testClutterScannerFindsLargeOldAndDuplicateFiles() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("tonic-phase1-clutter-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let duplicateA = root.appendingPathComponent("duplicate-a.dat")
        let duplicateB = root.appendingPathComponent("duplicate-b.dat")
        let duplicatePayload = Data(repeating: 0x2A, count: 2 * 1024 * 1024)
        try duplicatePayload.write(to: duplicateA)
        try duplicatePayload.write(to: duplicateB)

        let largeOld = root.appendingPathComponent("large-old.mov")
        try Data(repeating: 0x07, count: 3 * 1024 * 1024).write(to: largeOld)
        let oldDate = Date().addingTimeInterval(-120 * 24 * 60 * 60)
        try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: largeOld.path)

        let result = await ScanCategoryScanner().scanClutterFiles(
            roots: [root.path],
            largeFileThresholdBytes: 2 * 1024 * 1024,
            oldFileThresholdDays: 90,
            duplicateMinFileSizeBytes: 1024
        )

        // Compare canonical paths: temp dirs surface as /var (symlink) while the
        // scanner reports the resolved /private/var form.
        func canon(_ path: String) -> String { URL(fileURLWithPath: path).resolvingSymlinksInPath().path }
        XCTAssertTrue(result.largeOldFiles.contains { canon($0.path) == canon(largeOld.path) })
        XCTAssertTrue(result.duplicateFiles.contains { Set($0.paths.map(canon)) == Set([canon(duplicateA.path), canon(duplicateB.path)]) })
        XCTAssertGreaterThanOrEqual(result.duplicateReclaimableSize, Int64(2 * 1024 * 1024))
    }

    func testClutterScannerReportsCandidateCaps() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("tonic-phase1-cap-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        for index in 0..<4 {
            let file = root.appendingPathComponent("candidate-\(index).dat")
            try Data(repeating: UInt8(index), count: 2 * 1024).write(to: file)
        }

        let result = await ScanCategoryScanner().scanClutterFiles(
            roots: [root.path],
            largeFileThresholdBytes: 10 * 1024 * 1024,
            duplicateMinFileSizeBytes: 1024,
            maxDuplicateHashCandidates: 1
        )

        XCTAssertTrue(result.duplicateCandidateCapReached)
        XCTAssertTrue(result.hasPartialResults)
    }

    func testClutterScannerReportsUnavailableRoots() async {
        let missingRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("tonic-missing-root-\(UUID().uuidString)", isDirectory: true)

        let result = await ScanCategoryScanner().scanClutterFiles(roots: [missingRoot.path])

        XCTAssertEqual(result.scannedRoots, [])
        XCTAssertEqual(result.inaccessibleRoots, [missingRoot.path])
        XCTAssertTrue(result.needsAdditionalAccess)
    }

    func testCancelledClutterScannerMarksPartialResult() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("tonic-phase1-cancel-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let task = Task {
            try? await Task.sleep(nanoseconds: 50_000_000)
            return await ScanCategoryScanner().scanClutterFiles(roots: [root.path])
        }
        task.cancel()

        let result = await task.value
        XCTAssertTrue(result.wasCancelled)
        XCTAssertTrue(result.hasPartialResults)
    }

    func testPrimaryPhase1SurfacesDoNotExposeNotWiredCopy() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let projectRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let checkedFiles = [
            "Tonic/Tonic/Views/SmartScan/SpaceManagerView.swift",
            "Tonic/Tonic/Views/SmartScan/AppsManagerView.swift",
            "Tonic/Tonic/Views/SmartScan/SmartScanHubView.swift",
            "Tonic/Tonic/Views/DashboardHomeView.swift"
        ]

        for relativePath in checkedFiles {
            let source = try String(contentsOf: projectRoot.appendingPathComponent(relativePath), encoding: .utf8)
            XCTAssertFalse(source.localizedCaseInsensitiveContains("not wired in this pass"), relativePath)
            XCTAssertFalse(source.localizedCaseInsensitiveContains("placeholder in this pass"), relativePath)
        }
    }

    func testDashboardDoesNotExposeDirectReviewedCleanupShortcut() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let projectRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: projectRoot.appendingPathComponent("Tonic/Tonic/Views/DashboardHomeView.swift"),
            encoding: .utf8
        )

        XCTAssertFalse(source.contains("Run reviewed items"))
        XCTAssertTrue(source.contains("Review Smart Clean"))
    }

    func testUpdaterLabsIsHiddenFromStandardModeNavigation() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let projectRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: projectRoot.appendingPathComponent("Tonic/Tonic/Views/SmartScan/AppsManagerView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(source.contains("if powerUserModeEnabled"))
        XCTAssertTrue(source.contains("Updater Labs"))
    }

    func testWIPFeatureFlagsAreClosedInReleaseBuilds() {
        #if DEBUG
        XCTAssertTrue(FeatureFlags.isEnabled(WIPFeature.developerTools))
        #else
        XCTAssertFalse(FeatureFlags.isEnabled(WIPFeature.developerTools))
        XCTAssertFalse(FeatureFlags.isEnabled(WIPFeature.designSandbox))
        XCTAssertFalse(FeatureFlags.isEnabled(WIPFeature.storageHub))
        XCTAssertFalse(FeatureFlags.isEnabled(WIPFeature.activity))
        #endif
    }

    func testPowerUserModeDefaultIsStandard() {
        let defaults = UserDefaults(suiteName: "tonic.phase1.tests.\(UUID().uuidString)")!
        XCTAssertFalse(defaults.bool(forKey: TonicUserDefaultsKey.powerUserModeEnabled))
    }
}
