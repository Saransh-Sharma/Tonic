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
}
