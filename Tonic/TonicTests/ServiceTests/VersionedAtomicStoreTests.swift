import Foundation
import XCTest
@testable import Tonic

private final class MemoryAtomicFiles: AtomicFileAccess, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [URL: Data] = [:]
    private(set) var quarantined: [URL] = []

    func read(from url: URL) throws -> Data {
        try lock.withLock {
            guard let value = values[url] else { throw CocoaError(.fileNoSuchFile) }
            return value
        }
    }
    func write(_ data: Data, to url: URL) throws { lock.withLock { values[url] = data } }
    func fileExists(at url: URL) -> Bool { lock.withLock { values[url] != nil } }
    func quarantine(_ url: URL, suffix: String) throws {
        lock.withLock { values.removeValue(forKey: url); quarantined.append(url) }
    }
    func seed(_ data: Data, at url: URL) { lock.withLock { values[url] = data } }
}

final class VersionedAtomicStoreTests: XCTestCase {
    private struct Payload: Codable, Equatable, Sendable { var value: Int }

    func testRoundTripAndDefault() async throws {
        let files = MemoryAtomicFiles(), url = URL(fileURLWithPath: "/state.json")
        let store = VersionedAtomicStore<Payload>(fileURL: url, files: files)
        let initial = await store.loadOrDefault(Payload(value: 1))
        XCTAssertEqual(initial, Payload(value: 1))
        try await store.save(Payload(value: 8))
        let loaded = try await store.load(default: Payload(value: 0))
        XCTAssertEqual(loaded, Payload(value: 8))
    }

    func testCorruptionIsQuarantined() async {
        let files = MemoryAtomicFiles(), url = URL(fileURLWithPath: "/state.json")
        files.seed(Data("not json".utf8), at: url)
        let store = VersionedAtomicStore<Payload>(fileURL: url, files: files,
                                                  now: { Date(timeIntervalSince1970: 1_000) })
        do {
            _ = try await store.load(default: Payload(value: 0))
            XCTFail("Expected corruption")
        } catch {
            XCTAssertEqual(error as? VersionedStoreError, .corrupted)
        }
        XCTAssertEqual(files.quarantined, [url])
    }
}
