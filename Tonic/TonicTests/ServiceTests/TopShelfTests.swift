import XCTest
@testable import Tonic

private struct FixedTopShelfModule: TopShelfModule {
    let descriptor: TopShelfModuleDescriptor
    let value: String
    func snapshot(in context: TopShelfPresentationContext) async -> TopShelfModuleSnapshot {
        TopShelfModuleSnapshot(moduleID: descriptor.id, title: descriptor.title,
                               primaryText: value, symbol: descriptor.symbol)
    }
}

final class TopShelfTests: XCTestCase {
    func testClipboardRefusesAmbientOrBackgroundRead() async {
        let module = TopShelfClipboardModule()
        let background = await module.snapshot(in: .init(isDeliberateOpen: false))
        let ambient = await module.snapshot(in: .init(isDeliberateOpen: false, isAmbient: true))
        XCTAssertEqual(background.status, .unavailable)
        XCTAssertEqual(ambient.status, .unavailable)
        XCTAssertEqual(background.primaryText, "Open Top Shelf to preview")
    }

    @MainActor
    func testCoordinatorPreservesConfiguredOrdering() async {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let atomic = VersionedAtomicStore<TopShelfState>(fileURL: root)
        let store = TopShelfStore(store: atomic)
        await store.load()
        store.update {
            $0.enabledModuleIDs = ["a", "b"]
            $0.layout.orderedModuleIDs = ["b", "a"]
        }
        let coordinator = TopShelfCoordinator(store: store, modules: [
            FixedTopShelfModule(descriptor: .init(id: "a", kind: .provider, title: "A", symbol: "a.circle"), value: "A"),
            FixedTopShelfModule(descriptor: .init(id: "b", kind: .provider, title: "B", symbol: "b.circle"), value: "B")
        ])
        coordinator.refresh(context: .init(isDeliberateOpen: true))
        try? await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(coordinator.snapshots.map(\.moduleID), ["b", "a"])
    }

    @MainActor
    func testRecommendedAmbientConsentAlsoEnablesRecommendedModules() async {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = TopShelfStore(store: VersionedAtomicStore(fileURL: root))
        await store.load()

        store.confirmRecommendedAmbientSet()

        XCTAssertTrue(store.state.ambientPolicy.hasConfirmedRecommendedSet)
        XCTAssertEqual(store.state.ambientPolicy.enabledModuleIDs,
                       ["now-playing", "calendar", "system-health"])
        XCTAssertTrue(store.state.enabledModuleIDs.isSuperset(of:
            ["now-playing", "calendar", "system-health"]))
    }

    @MainActor
    func testAmbientRefreshContainsOnlyTheTriggeringModule() async {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = TopShelfStore(store: VersionedAtomicStore(fileURL: root))
        await store.load()
        store.update { $0.enabledModuleIDs = ["a", "b"] }
        let coordinator = TopShelfCoordinator(store: store, modules: [
            FixedTopShelfModule(descriptor: .init(id: "a", kind: .provider, title: "A", symbol: "a.circle"), value: "A"),
            FixedTopShelfModule(descriptor: .init(id: "b", kind: .provider, title: "B", symbol: "b.circle"), value: "B")
        ])

        coordinator.refresh(context: .init(isDeliberateOpen: false, isAmbient: true), moduleIDs: ["b"])
        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(coordinator.snapshots.map(\.moduleID), ["b"])
    }

    func testSensitiveContentIsAbsentFromPersistedStateModel() throws {
        let data = try JSONEncoder().encode(TopShelfState())
        let value = String(decoding: data, as: UTF8.self).lowercased()
        XCTAssertFalse(value.contains("clipboardcontent"))
        XCTAssertFalse(value.contains("calendarevent"))
    }

    func testAmbientEvaluatorLimitsPresentationToActionableRecommendedContent() {
        let healthGood = TopShelfModuleSnapshot(moduleID: "system-health", title: "Health",
            primaryText: "Normal", symbol: "heart", status: .good)
        let healthWarning = TopShelfModuleSnapshot(moduleID: "system-health", title: "Health",
            primaryText: "CPU high", symbol: "heart", status: .attention)
        let futureCalendar = TopShelfModuleSnapshot(moduleID: "calendar", title: "Calendar",
            primaryText: "Later", symbol: "calendar", status: .neutral)
        let currentTrack = TopShelfModuleSnapshot(moduleID: "now-playing", title: "Now Playing",
            primaryText: "Track", symbol: "play", status: .neutral)
        let clipboard = TopShelfModuleSnapshot(moduleID: "clipboard", title: "Clipboard",
            primaryText: "Sensitive", symbol: "clipboard", status: .attention)

        XCTAssertFalse(TopShelfAmbientEvaluator.isActionable(healthGood))
        XCTAssertTrue(TopShelfAmbientEvaluator.isActionable(healthWarning))
        XCTAssertFalse(TopShelfAmbientEvaluator.isActionable(futureCalendar))
        XCTAssertTrue(TopShelfAmbientEvaluator.isActionable(currentTrack))
        XCTAssertFalse(TopShelfAmbientEvaluator.isActionable(clipboard))
        XCTAssertEqual(TopShelfAmbientEvaluator.eventID(for: currentTrack),
                       TopShelfAmbientEvaluator.eventID(for: currentTrack))
    }

    func testLegacyTopShelfStateDecodesWithoutRecentFiles() throws {
        let legacy = #"{"layout":{"orderedModuleIDs":[],"hiddenModuleIDs":[],"pinnedModuleIDs":[],"mode":"adaptive"},"ambientPolicy":{"hasConfirmedRecommendedSet":false,"enabledModuleIDs":[],"cooldownSeconds":300,"dismissSeconds":8},"enabledModuleIDs":["system-health"],"notes":[],"timers":[]}"#.data(using: .utf8)!
        let state = try JSONDecoder().decode(TopShelfState.self, from: legacy)
        XCTAssertTrue(state.recentFiles.isEmpty)
        XCTAssertEqual(state.enabledModuleIDs, ["system-health"])
    }

    #if !TONIC_STORE
    func testForeignProxyLoadsOnlyAfterActivationAndDisposesAfterForward() async throws {
        actor Events {
            var values: [String] = []
            func append(_ value: String) { values.append(value) }
            func snapshot() -> [String] { values }
        }
        let events = Events()
        let session = ForeignMenuProxySession(
            stableItemKey: "item",
            activateOriginal: {
                await events.append("activate")
                return true
            },
            capabilityAllowed: { true },
            permissionsAllowed: { true }
        )
        let rows = try await session.open {
            await events.append("load")
            return [ForeignMenuProxyItem(title: "Open", isEnabled: true, path: [2])]
        }
        let recorded = await events.snapshot()
        XCTAssertEqual(recorded, ["activate", "load"])
        try await session.activate(rows[0].id) { path in
            await events.append("forward:\(path)")
            return path == [2]
        }
        let remaining = await session.items
        XCTAssertTrue(remaining.isEmpty)
    }

    func testForeignProxyRejectsSecureContentAndClearsOnClose() async throws {
        let session = ForeignMenuProxySession(stableItemKey: "item", activateOriginal: { true },
            capabilityAllowed: { true }, permissionsAllowed: { true })
        do {
            _ = try await session.open(accessibilityItems: [
                ForeignMenuProxyItem(title: "Password", isEnabled: true, isSecure: true)
            ])
            XCTFail("Secure menu content must fail closed")
        } catch {
            XCTAssertEqual(error as? ForeignMenuProxyError, .secureItem)
        }
        await session.close()
        let remaining = await session.items
        XCTAssertTrue(remaining.isEmpty)
    }
    #endif
}
