import Foundation

public protocol AtomicFileAccess: Sendable {
    func read(from url: URL) throws -> Data
    func write(_ data: Data, to url: URL) throws
    func fileExists(at url: URL) -> Bool
    func quarantine(_ url: URL, suffix: String) throws
}

public struct FoundationAtomicFileAccess: AtomicFileAccess, @unchecked Sendable {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func read(from url: URL) throws -> Data { try Data(contentsOf: url) }

    public func write(_ data: Data, to url: URL) throws {
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    public func fileExists(at url: URL) -> Bool { fileManager.fileExists(atPath: url.path) }

    public func quarantine(_ url: URL, suffix: String) throws {
        guard fileExists(at: url) else { return }
        let destination = url.deletingLastPathComponent()
            .appendingPathComponent(url.lastPathComponent + ".corrupt-" + suffix)
        if fileManager.fileExists(atPath: destination.path) { try fileManager.removeItem(at: destination) }
        try fileManager.moveItem(at: url, to: destination)
    }
}

public enum VersionedStoreError: Error, Equatable, Sendable {
    case unsupportedVersion(found: Int, supported: Int)
    case corrupted
}

public struct VersionedEnvelope<Payload: Codable & Equatable & Sendable>: Codable, Equatable, Sendable {
    public var version: Int
    public var payload: Payload

    public init(version: Int, payload: Payload) {
        self.version = version
        self.payload = payload
    }
}

public actor VersionedAtomicStore<Payload: Codable & Equatable & Sendable> {
    private let fileURL: URL
    private let supportedVersion: Int
    private let files: any AtomicFileAccess
    private let now: @Sendable () -> Date

    public init(fileURL: URL, supportedVersion: Int = 1,
                files: any AtomicFileAccess = FoundationAtomicFileAccess(),
                now: @escaping @Sendable () -> Date = { Date() }) {
        self.fileURL = fileURL
        self.supportedVersion = supportedVersion
        self.files = files
        self.now = now
    }

    public func load(default defaultValue: Payload) throws -> Payload {
        guard files.fileExists(at: fileURL) else { return defaultValue }
        do {
            let envelope = try SignedArtifactCoding.decoder().decode(
                VersionedEnvelope<Payload>.self,
                from: files.read(from: fileURL)
            )
            guard envelope.version <= supportedVersion else {
                throw VersionedStoreError.unsupportedVersion(found: envelope.version, supported: supportedVersion)
            }
            return envelope.payload
        } catch let error as VersionedStoreError {
            throw error
        } catch {
            let formatter = ISO8601DateFormatter()
            let suffix = formatter.string(from: now()).replacingOccurrences(of: ":", with: "-")
            try? files.quarantine(fileURL, suffix: suffix)
            throw VersionedStoreError.corrupted
        }
    }

    public func save(_ payload: Payload) throws {
        let envelope = VersionedEnvelope(version: supportedVersion, payload: payload)
        try files.write(SignedArtifactCoding.canonicalData(for: envelope), to: fileURL)
    }

    public func loadOrDefault(_ defaultValue: Payload) -> Payload {
        (try? load(default: defaultValue)) ?? defaultValue
    }
}
