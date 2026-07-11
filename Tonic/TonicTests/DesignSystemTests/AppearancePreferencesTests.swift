import XCTest
@testable import Tonic

final class AppearancePreferencesTests: XCTestCase {

    private let themeKey = "tonic.appearance.themeMode"
    private let reduceMotionKey = "tonic.appearance.reduceMotion"
    private let legacyPaletteKey = "tonic.appearance.colorPalette"

    override func setUp() {
        super.setUp()
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: themeKey)
        defaults.removeObject(forKey: reduceMotionKey)
        defaults.removeObject(forKey: legacyPaletteKey)
    }

    func testThemeModePersistsToUserDefaults() {
        let preferences = AppearancePreferences.shared
        preferences.setThemeMode(.dark)

        XCTAssertEqual(UserDefaults.standard.string(forKey: themeKey), ThemeMode.dark.rawValue)
        XCTAssertEqual(preferences.themeMode, .dark)
    }

    func testReduceMotionPersistsToUserDefaults() {
        let preferences = AppearancePreferences.shared
        preferences.setReduceMotion(true)

        XCTAssertTrue(UserDefaults.standard.bool(forKey: reduceMotionKey))
        XCTAssertTrue(preferences.reduceMotion)
    }

    func testLegacyPaletteKeyIsNotWritten() {
        let preferences = AppearancePreferences.shared
        preferences.setThemeMode(.light)
        preferences.setReduceTransparency(true)
        preferences.setReduceMotion(false)

        XCTAssertNil(UserDefaults.standard.object(forKey: legacyPaletteKey))
    }

    // MARK: - Liquid shell policy

    func testRailPresentationStatePrioritizesPinOverHover() {
        XCTAssertEqual(
            RailPresentationState.resolve(isPointerInside: false, isPinned: false),
            .collapsed
        )
        XCTAssertEqual(
            RailPresentationState.resolve(isPointerInside: true, isPinned: false),
            .hoverExpanded
        )
        XCTAssertEqual(
            RailPresentationState.resolve(isPointerInside: false, isPinned: true),
            .pinnedExpanded
        )
        XCTAssertEqual(
            RailPresentationState.resolve(isPointerInside: true, isPinned: true),
            .pinnedExpanded
        )
    }

    func testRailPinPreferencePersists() throws {
        let suiteName = "AppearancePreferencesTests.rail.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        XCTAssertFalse(RailPinPreference.isPinned(in: defaults))
        RailPinPreference.setPinned(true, in: defaults)
        XCTAssertTrue(RailPinPreference.isPinned(in: defaults))
        RailPinPreference.setPinned(false, in: defaults)
        XCTAssertFalse(RailPinPreference.isPinned(in: defaults))
    }

    func testGlassPolicyAnyReductionWins() {
        XCTAssertTrue(TonicGlassPolicy.resolvesGlass(
            systemReducesTransparency: false,
            appReducesTransparency: false,
            intensity: .regular
        ))
        XCTAssertFalse(TonicGlassPolicy.resolvesGlass(
            systemReducesTransparency: true,
            appReducesTransparency: false,
            intensity: .regular
        ))
        XCTAssertFalse(TonicGlassPolicy.resolvesGlass(
            systemReducesTransparency: false,
            appReducesTransparency: true,
            intensity: .regular
        ))
        XCTAssertFalse(TonicGlassPolicy.resolvesGlass(
            systemReducesTransparency: false,
            appReducesTransparency: false,
            intensity: .off
        ))
    }

    func testMotionPolicyCombinesSystemAndAppPreferences() {
        XCTAssertFalse(TonicMotionPolicy.shouldReduceMotion(
            systemReducesMotion: false,
            appReducesMotion: false
        ))
        XCTAssertTrue(TonicMotionPolicy.shouldReduceMotion(
            systemReducesMotion: true,
            appReducesMotion: false
        ))
        XCTAssertTrue(TonicMotionPolicy.shouldReduceMotion(
            systemReducesMotion: false,
            appReducesMotion: true
        ))
    }

    func testCollapsedRailHasReferenceGapBeforeSlab() {
        let railTrailing = TonicDS.Glass.Shell.railLeadingInset
            + TonicDS.Glass.Shell.railCollapsedWidth
        XCTAssertEqual(
            TonicDS.Glass.Shell.slabLeadingInset - railTrailing,
            TonicDS.Glass.Shell.railToSlabGap,
            accuracy: 0.001
        )
        XCTAssertGreaterThan(
            TonicDS.Glass.Shell.railExpandedWidth,
            TonicDS.Glass.Shell.slabLeadingInset - TonicDS.Glass.Shell.railLeadingInset
        )
    }
}
