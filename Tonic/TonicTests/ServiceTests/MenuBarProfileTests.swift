import XCTest
@testable import Tonic

final class MenuBarProfileTests: XCTestCase {
    private let display = DisplayIdentity(displayID: 7, vendor: 1, model: 2, serial: 3, fallbackName: "Studio")

    func testPrecedenceIsGlobalThenDisplayThenManualContext() {
        let context = UUID()
        let profiles = [
            MenuBarPresentationProfile(name: "Global", scope: .global,
                values: .init(quickShelfPresentation: .compactStrip, showsOverflow: true)),
            MenuBarPresentationProfile(name: "Display", scope: .display(display),
                values: .init(quickShelfPresentation: .labeledGrid)),
            MenuBarPresentationProfile(name: "Recording", scope: .manualContext(context),
                values: .init(quickShelfPresentation: .searchableList, showsOverflow: false))
        ]
        let resolved = MenuBarProfileResolver().resolve(profiles: profiles, display: display, manualContextID: context)
        XCTAssertEqual(resolved.quickShelfPresentation, .searchableList)
        XCTAssertEqual(resolved.showsOverflow, false)
    }

    func testMissingDisplayFallsBackToGlobal() {
        let global = MenuBarPresentationProfile(name: "Global", scope: .global,
                                                 values: .init(quickShelfPresentation: .compactStrip))
        let result = MenuBarProfileResolver().resolve(profiles: [global], display: display, manualContextID: nil)
        XCTAssertEqual(result.quickShelfPresentation, .compactStrip)
    }

    @MainActor
    func testDisplayIdentityChangeUpdatesExistingProfileInsteadOfDuplicating() {
        let suite = "MenuBarProfileTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!; defer { defaults.removePersistentDomain(forName: suite) }
        let store = MenuBarProfileStore(defaults: defaults, migratedLayout: [:], migratedSettings: .default)
        store.updateValues(scope: .display(display), name: "Studio") { $0.showsOverflow = false }
        let reattached = DisplayIdentity(displayID: 99, vendor: display.vendor, model: display.model,
                                         serial: display.serial, fallbackName: "Studio")
        store.updateValues(scope: .display(reattached), name: "Studio") { $0.quickShelfPresentation = .labeledGrid }
        let displayProfiles = store.profiles.filter { if case .display = $0.scope { return true }; return false }
        XCTAssertEqual(displayProfiles.count, 1)
        XCTAssertEqual(store.explicitValues(for: .display(reattached))?.showsOverflow, false)
        XCTAssertEqual(store.explicitValues(for: .display(reattached))?.quickShelfPresentation, .labeledGrid)
    }

    @MainActor
    func testSingleLayoutMigratesOnlyIntoGlobalPhysicalLayout() {
        let suite = "MenuBarProfileTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!; defer { defaults.removePersistentDomain(forName: suite) }
        let layout = ["item": MenuBarSection.hidden]
        let store = MenuBarProfileStore(defaults: defaults, migratedLayout: layout, migratedSettings: .default)
        XCTAssertEqual(store.globalForeignLayout, layout)
        XCTAssertEqual(store.profiles.count, 1)
        XCTAssertEqual(store.profiles.first?.scope, .global)
    }
}
