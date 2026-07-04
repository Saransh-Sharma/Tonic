import XCTest
@testable import Tonic

final class HomebrewServiceTests: XCTestCase {

    private let inventoryJSON = """
    {
      "casks": [
        {
          "token": "iterm2",
          "installed": "3.5.11",
          "version": "3.5.12",
          "outdated": true,
          "artifacts": [
            {"app": ["iTerm.app"]},
            {"zap": [{"trash": ["~/Library/Preferences/com.googlecode.iterm2.plist"]}]}
          ]
        },
        {
          "token": "rectangle",
          "installed": "0.80",
          "version": "0.80",
          "outdated": false,
          "artifacts": [
            {"app": ["Rectangle.app"]}
          ]
        },
        {
          "token": "no-app-cask",
          "installed": "1.0",
          "version": "1.0",
          "outdated": false,
          "artifacts": [
            {"pkg": ["installer.pkg"]}
          ]
        }
      ]
    }
    """

    func testParsesCaskInventory() throws {
        let casks = try HomebrewService.parseCaskInventory(json: Data(inventoryJSON.utf8))
        XCTAssertEqual(casks.count, 3)

        let iterm = try XCTUnwrap(casks.first { $0.token == "iterm2" })
        XCTAssertEqual(iterm.installedVersion, "3.5.11")
        XCTAssertEqual(iterm.latestVersion, "3.5.12")
        XCTAssertTrue(iterm.outdated)
        XCTAssertEqual(iterm.appPaths, ["/Applications/iTerm.app"])

        let rectangle = try XCTUnwrap(casks.first { $0.token == "rectangle" })
        XCTAssertFalse(rectangle.outdated)
        XCTAssertEqual(rectangle.appPaths, ["/Applications/Rectangle.app"])

        let pkgOnly = try XCTUnwrap(casks.first { $0.token == "no-app-cask" })
        XCTAssertTrue(pkgOnly.appPaths.isEmpty, "non-app artifacts must not produce app paths")
    }

    func testAbsoluteAppArtifactPathsAreKept() throws {
        let json = """
        {"casks": [{"token": "x", "installed": "1", "version": "1", "outdated": false,
                    "artifacts": [{"app": ["/Custom/Location/X.app"]}]}]}
        """
        let casks = try HomebrewService.parseCaskInventory(json: Data(json.utf8))
        XCTAssertEqual(casks.first?.appPaths, ["/Custom/Location/X.app"])
    }

    func testCustomApplicationsDirectory() throws {
        let json = """
        {"casks": [{"token": "y", "installed": "1", "version": "1", "outdated": false,
                    "artifacts": [{"app": ["Y.app"]}]}]}
        """
        let casks = try HomebrewService.parseCaskInventory(
            json: Data(json.utf8),
            applicationsDir: "/Users/me/Applications"
        )
        XCTAssertEqual(casks.first?.appPaths, ["/Users/me/Applications/Y.app"])
    }

    func testMalformedJSONThrows() {
        XCTAssertThrowsError(
            try HomebrewService.parseCaskInventory(json: Data("not json".utf8))
        )
    }

    func testBrewDetectionReturnsExecutableOrNil() {
        // Environment-dependent: assert only the contract, not the machine.
        if let path = HomebrewService.detectBrew() {
            XCTAssertTrue(FileManager.default.isExecutableFile(atPath: path))
        }
    }
}
