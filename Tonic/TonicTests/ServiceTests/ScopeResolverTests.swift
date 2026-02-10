import XCTest
@testable import Tonic

final class ScopeResolverTests: XCTestCase {
    private let resolver = ScopeResolver.shared

    func testBestScopeExactMatch() {
        let scopes = [
            makeScope(path: "/Applications", name: "Applications"),
            makeScope(path: "/Users/test", name: "Home"),
        ]

        let match = resolver.bestScope(forPath: "/Applications", scopes: scopes)
        XCTAssertEqual(match?.rootPath, "/Applications")
    }

    func testBestScopeChoosesDeepestAncestor() {
        let scopes = [
            makeScope(path: "/Users/test", name: "Home"),
            makeScope(path: "/Users/test/Developer", name: "Developer"),
        ]

        let match = resolver.bestScope(forPath: "/Users/test/Developer/Projects/App", scopes: scopes)
        XCTAssertEqual(match?.rootPath, "/Users/test/Developer")
    }

    func testCanonicalPathExpandsTildeAndNormalizes() {
        let canonical = resolver.canonicalPath("~/../\(NSUserName())/Documents")
        XCTAssertTrue(canonical.hasPrefix("/Users/"))
        XCTAssertFalse(canonical.contains(".."))
    }

    func testCanonicalPathResolvesSymlink() throws {
        let base = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tonic_scope_tests_\(UUID().uuidString)")
        let target = base.appendingPathComponent("target")
        let link = base.appendingPathComponent("link")

        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: target.path)
        defer { try? FileManager.default.removeItem(at: base) }

        XCTAssertEqual(resolver.canonicalPath(link.path), resolver.canonicalPath(target.path))
    }

    func testProtectedPathDetection() {
        XCTAssertTrue(resolver.isProtectedByMacOS("/System/Library/Caches"))
        XCTAssertTrue(resolver.isProtectedByMacOS("/private/var/db"))
        XCTAssertFalse(resolver.isProtectedByMacOS("/Users/test/Downloads"))
    }

    private func makeScope(path: String, name: String) -> AccessScope {
        AccessScope(
            displayName: name,
            rootPath: path,
            kind: .folder,
            bookmarkData: Data()
        )
    }
}
