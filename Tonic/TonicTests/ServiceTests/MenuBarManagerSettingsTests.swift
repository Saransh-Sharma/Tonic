import XCTest
@testable import Tonic

final class MenuBarManagerSettingsTests: XCTestCase {

    func testDefaults() {
        let settings = MenuBarManagerSettings.default
        XCTAssertFalse(settings.isEnabled)
        XCTAssertFalse(settings.alwaysHiddenSectionEnabled)
        XCTAssertTrue(settings.autoRehide)
        XCTAssertEqual(settings.rehideDelaySeconds, 15)
        XCTAssertTrue(settings.showOnHover)
        XCTAssertTrue(settings.showOnClickEmptyMenuBar)
        XCTAssertTrue(settings.showOnScroll)
    }

    func testRoundTrip() throws {
        var settings = MenuBarManagerSettings.default
        settings.isEnabled = true
        settings.showOnHover = true
        settings.hoverDelaySeconds = 0.5
        settings.rehideDelaySeconds = 30
        settings.alwaysHiddenSectionEnabled = true

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(MenuBarManagerSettings.self, from: data)
        XCTAssertEqual(decoded, settings)
    }

    func testInitClampsRanges() {
        let settings = MenuBarManagerSettings(hoverDelaySeconds: 99, rehideDelaySeconds: 0.5)
        XCTAssertEqual(settings.hoverDelaySeconds, 2)
        XCTAssertEqual(settings.rehideDelaySeconds, 2)
    }

    func testDecodingUnknownPayloadFallsBackToDefaults() throws {
        let decoded = try JSONDecoder().decode(MenuBarManagerSettings.self, from: Data("{}".utf8))
        XCTAssertEqual(decoded, .default)
    }

    func testNewFieldsDefaultWhenAbsentFromOldJSON() throws {
        // A settings blob written before revealMode/styling existed.
        let legacy = """
        {"isEnabled":true,"autoRehide":false,"rehideDelaySeconds":40}
        """
        let decoded = try JSONDecoder().decode(MenuBarManagerSettings.self, from: Data(legacy.utf8))
        XCTAssertTrue(decoded.isEnabled)
        XCTAssertFalse(decoded.autoRehide)
        XCTAssertEqual(decoded.rehideDelaySeconds, 40)
        XCTAssertEqual(decoded.revealMode, .expand)
        XCTAssertEqual(decoded.quickShelfPresentation, .compactStrip)
        XCTAssertTrue(decoded.showOnScroll)
        XCTAssertFalse(decoded.styling.isEnabled)
    }

    func testRevealModeAndStylingRoundTrip() throws {
        var settings = MenuBarManagerSettings.default
        settings.revealMode = .tonicBar
        settings.styling = MenuBarStyling(isEnabled: true, tintHex: "#112233", usesGradient: true, cornerRadius: 8, opacity: 0.7)
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(MenuBarManagerSettings.self, from: data)
        XCTAssertEqual(decoded, settings)
    }
}

@MainActor
final class MenuBarWorkspaceStoreTests: XCTestCase {
    private func item(id: UInt32, section: MenuBarSection, system: Bool = false) -> MenuBarItemInfo {
        MenuBarItemInfo(windowID: id, ownerPID: pid_t(id + 100), ownerName: "App\(id)",
                        frame: CGRect(x: Int(id) * 30, y: 0, width: 24, height: 24),
                        isOnScreen: true, isSystemControlled: system, section: section)
    }

    func testDraftStagesDiscardsAndCommitsWithoutChangingLiveItem() {
        let suite = "MenuBarWorkspaceStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = MenuBarWorkspaceStore(defaults: defaults)
        let live = item(id: 1, section: .visible)

        store.synchronize(with: [live])
        store.stage(live, in: .hidden)
        XCTAssertTrue(store.isDirty)
        XCTAssertEqual(store.section(for: live), .hidden)
        XCTAssertEqual(live.section, .visible)
        store.discard()
        XCTAssertFalse(store.isDirty)

        store.stage(live, in: .alwaysHidden)
        store.markApplied()
        XCTAssertFalse(store.isDirty)
        XCTAssertEqual(store.baseline[live.stableKey], .alwaysHidden)
    }

    func testSystemItemsCannotBeStaged() {
        let defaults = UserDefaults(suiteName: "MenuBarWorkspaceStoreTests.\(UUID().uuidString)")!
        let store = MenuBarWorkspaceStore(defaults: defaults)
        let system = item(id: 2, section: .visible, system: true)
        store.synchronize(with: [system])
        store.stage(system, in: .hidden)
        XCTAssertFalse(store.isDirty)
    }

    func testSynchronizeDeduplicatesMultipleObservationsOfOneLogicalItem() {
        let suite = "MenuBarWorkspaceStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = MenuBarWorkspaceStore(defaults: defaults)
        // Both rows intentionally have the same owner and therefore the same
        // stable key, matching the scanner's multi-display observation shape.
        let firstDisplay = item(id: 20, section: .visible)
        let secondDisplay = MenuBarItemInfo(
            windowID: 21,
            ownerPID: firstDisplay.ownerPID,
            ownerName: firstDisplay.ownerName,
            frame: CGRect(x: 1_200, y: 0, width: 24, height: 24),
            isOnScreen: true,
            isSystemControlled: false,
            section: .hidden
        )

        store.synchronize(with: [firstDisplay, secondDisplay])

        XCTAssertEqual(store.baseline, [firstDisplay.stableKey: .visible])
        XCTAssertEqual(store.envelope.draft.orderedNodes, [.foreign(stableKey: firstDisplay.stableKey)])
    }

    func testPartialCommitLeavesOnlyFailuresDirty() {
        let defaults = UserDefaults(suiteName: "MenuBarWorkspaceStoreTests.\(UUID().uuidString)")!
        let store = MenuBarWorkspaceStore(defaults: defaults)
        let first = item(id: 10, section: .visible), second = item(id: 11, section: .visible)
        store.synchronize(with: [first, second]); store.stage(first, in: .hidden); store.stage(second, in: .hidden)
        store.commit(successfulForeignKeys: [first.stableKey], commitOwnedItems: true)
        XCTAssertEqual(store.baseline[first.stableKey], .hidden)
        XCTAssertEqual(store.baseline[second.stableKey], .visible)
        XCTAssertEqual(store.changes.map(\.stableKey), [second.stableKey])
    }

    func testUnifiedOrderAndOwnedZoneChangesRemainStaged() {
        let defaults = UserDefaults(suiteName: "MenuBarWorkspaceStoreTests.\(UUID().uuidString)")!
        let store = MenuBarWorkspaceStore(defaults: defaults)
        let foreign = item(id: 12, section: .visible)
        let spacer = MenuBarSpacer(label: "Breathing room")
        let custom = CustomMenuBarItem(name: "CPU", dataSource: .cpu)
        store.synchronize(with: [foreign])
        store.addSpacer(spacer)
        store.addCustomItem(custom)

        store.move(.customItem(custom.id), by: -1)
        XCTAssertTrue(store.stageOwned(.spacer(spacer.id), in: .hidden))
        XCTAssertEqual(store.spacers.first?.section, .hidden)
        XCTAssertTrue(store.isDirty)
        XCTAssertLessThan(store.envelope.draft.orderedNodes.firstIndex(of: .customItem(custom.id))!,
                          store.envelope.draft.orderedNodes.firstIndex(of: .spacer(spacer.id))!)

        store.discard()
        XCTAssertTrue(store.spacers.isEmpty)
        XCTAssertTrue(store.customItems.isEmpty)
    }

    func testPartialOwnedCommitKeepsOnlyFailedNodeDirty() {
        let defaults = UserDefaults(suiteName: "MenuBarWorkspaceStoreTests.\(UUID().uuidString)")!
        let store = MenuBarWorkspaceStore(defaults: defaults)
        let spacer = MenuBarSpacer(label: "Applied spacer")
        let custom = CustomMenuBarItem(name: "Invalid", symbolName: "not.a.real.symbol",
                                       dataSource: .staticLabel("Invalid"))
        store.addSpacer(spacer); store.addCustomItem(custom)
        let failedID = MenuBarLayoutNode.customItem(custom.id).stableID
        store.commit(successfulForeignKeys: [], commitOwnedItems: false, failedOwnedNodeIDs: [failedID])

        XCTAssertEqual(store.envelope.committed.spacers.map(\.id), [spacer.id])
        XCTAssertTrue(store.envelope.committed.customItems.isEmpty)
        XCTAssertEqual(store.customItems.map(\.id), [custom.id])
        XCTAssertTrue(store.isDirty)
    }
}

@MainActor
final class MenuBarUpdateWatchStoreTests: XCTestCase {
    func testDigestPrivacyAndAcknowledgement() {
        let suite = "MenuBarUpdateWatchStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!; defer { defaults.removePersistentDomain(forName: suite) }
        let store = MenuBarUpdateWatchStore(defaults: defaults)
        store.setWatching(true, key: "item")
        XCTAssertFalse(store.recordDigest("baseline", for: "item"))
        XCTAssertTrue(store.recordDigest("changed", thumbnail: Data(repeating: 1, count: 1_024), for: "item"))
        XCTAssertEqual(store.unseenCount, 1)
        XCTAssertEqual(store.thumbnails["item"]?.count, 1_024)
        XCTAssertTrue(store.recordDigest("changed-again", thumbnail: Data(repeating: 2, count: 40_000), for: "item"))
        XCTAssertEqual(store.thumbnails["item"]?.count, 1_024, "oversized thumbnails must never replace the bounded asset")
        store.acknowledge("item")
        XCTAssertEqual(store.unseenCount, 0)
    }
}

final class TonicHelperPolicyTests: XCTestCase {
    func testCodableRequestRoundTrip() throws {
        let request = TonicHelperRequest(operation: .setFanTargetRPM(fanID: 1, rpm: 3_200, sessionID: UUID()))
        let decoded = try JSONDecoder().decode(TonicHelperRequest.self,
                                               from: JSONEncoder().encode(request))
        XCTAssertEqual(decoded, request)
        XCTAssertNil(TonicHelperPolicy.validated(decoded))
    }

    func testRejectsUnknownVersionAndUnsafeArguments() {
        XCTAssertEqual(TonicHelperPolicy.validated(TonicHelperRequest(
            version: 99, operation: .deleteLocalTimeMachineSnapshots)), .unsupportedVersion)
        XCTAssertEqual(TonicHelperPolicy.validated(TonicHelperRequest(
            operation: .purgeStaleDocumentRevisions(minimumAgeDays: 0))), .invalidArgument)
        XCTAssertEqual(TonicHelperPolicy.validated(TonicHelperRequest(
            operation: .setFanTargetRPM(fanID: 0, rpm: 99_999, sessionID: UUID()))), .invalidArgument)
        XCTAssertEqual(TonicHelperPolicy.validated(TonicHelperRequest(
            operation: .setFanMode(fanID: 99, automatic: false, sessionID: UUID()))), .invalidArgument)
    }
}

final class MenuBarRecommendationPlannerTests: XCTestCase {
    func testOnlyKnownUtilityIsPreselectedAndQuietIsNeverRecommended() {
        let planner = MenuBarRecommendationPlanner(knownUtilityBundleIdentifiers: ["com.example.utility"])
        let results = planner.recommendations(for: [
            .init(stableKey: "system", ownerName: "Control Center", bundleIdentifier: "com.apple.controlcenter"),
            .init(stableKey: "known", ownerName: "Utility", bundleIdentifier: "com.example.utility"),
            .init(stableKey: "unknown", ownerName: "Mystery", bundleIdentifier: "com.example.mystery")
        ])
        XCTAssertEqual(results.first(where: { $0.stableKey == "known" })?.target, .hidden)
        XCTAssertEqual(results.first(where: { $0.stableKey == "known" })?.confidence, .high)
        XCTAssertTrue(results.first(where: { $0.stableKey == "known" })?.isPreselected == true)
        XCTAssertEqual(results.first(where: { $0.stableKey == "system" })?.target, .visible)
        XCTAssertEqual(results.first(where: { $0.stableKey == "unknown" })?.target, .visible)
        XCTAssertFalse(results.contains { $0.target == .alwaysHidden })
    }

    func testUnknownOwnerIsAlwaysProtected() {
        let result = MenuBarRecommendationPlanner().recommendation(for: .init(
            stableKey: "unknown", ownerName: "Unknown", bundleIdentifier: nil
        ))
        XCTAssertEqual(result.confidence, .protected)
        XCTAssertFalse(result.isPreselected)
    }
}

final class MenuBarDisplayGeometryTests: XCTestCase {
    func testOverflowUsesQuartzDisplayRegionsWithoutChangingAssignments() {
        let geometry = MenuBarDisplayGeometry(
            displayFrame: CGRect(x: 2_000, y: 0, width: 1_440, height: 900),
            usableTopRegions: [CGRect(x: 2_000, y: 0, width: 560, height: 24),
                               CGRect(x: 2_880, y: 0, width: 560, height: 24)]
        )
        let visible = MenuBarItemInfo(windowID: 90, ownerPID: 1, ownerName: "Visible",
                                      frame: CGRect(x: 3_100, y: 0, width: 24, height: 24),
                                      isOnScreen: true, isSystemControlled: false, section: .visible)
        let underNotch = MenuBarItemInfo(windowID: 91, ownerPID: 1, ownerName: "Notch",
                                         frame: CGRect(x: 2_700, y: 0, width: 24, height: 24),
                                         isOnScreen: true, isSystemControlled: false, section: .hidden)
        XCTAssertFalse(geometry.isOverflow(visible))
        XCTAssertTrue(geometry.isOverflow(underNotch))
        XCTAssertEqual(underNotch.section, .hidden)
    }
}

final class MenuBarAccentPolicyTests: XCTestCase {
    func testAccentMustContrastAgainstLightAndDarkMenuBars() {
        XCTAssertTrue(MenuBarAccentPolicy.isSafe(hex: "#777777"))
        XCTAssertFalse(MenuBarAccentPolicy.isSafe(hex: "#000000"))
        XCTAssertFalse(MenuBarAccentPolicy.isSafe(hex: "#FFFFFF"))
        XCTAssertFalse(MenuBarAccentPolicy.isSafe(hex: "#777777", increasedContrast: true))
    }
}

final class CustomItemFormatterTests: XCTestCase {
    private let snapshot = CustomItemRuntimeSnapshot(
        date: Date(timeIntervalSince1970: 0), batteryPercent: 82, cpuPercent: 24,
        memoryPercent: 61, uploadBytesPerSecond: 1_000, downloadBytesPerSecond: 2_000,
        weatherText: "21°"
    )

    func testFormatsSupportedTokensAndSanitizesNewlines() throws {
        let formatter = CustomItemFormatter()
        let output = formatter.format(.formatted(template: "CPU {cpu}\nBattery {battery} {weather}"), snapshot: snapshot)
        XCTAssertEqual(output, "CPU 24%Battery 82% 21°")
    }

    func testRejectsUnknownTemplateTokenAndUnsafeURL() {
        let formatter = CustomItemFormatter()
        XCTAssertThrowsError(try formatter.validate(template: "{secret}"))
        let item = CustomMenuBarItem(name: "Unsafe", dataSource: .staticLabel("Unsafe"),
                                     actions: [.openURL(URL(string: "http://example.com")!)])
        XCTAssertThrowsError(try formatter.validate(item, snapshot: snapshot))
        let invalidDestination = CustomMenuBarItem(name: "Route", dataSource: .staticLabel("Route"),
                                                   actions: [.openTonicDestination("missing")])
        XCTAssertThrowsError(try formatter.validate(invalidDestination, snapshot: snapshot))
        let validDestination = CustomMenuBarItem(name: "Route", dataSource: .staticLabel("Route"),
                                                 actions: [.openTonicDestination(CustomTonicDestination.menuBar.rawValue)])
        XCTAssertNoThrow(try formatter.validate(validDestination, snapshot: snapshot))
    }
}
