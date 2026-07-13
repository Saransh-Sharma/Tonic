import Foundation

public enum SupportBundleCategory: String, Codable, CaseIterable, Hashable, Sendable {
    case application
    case capabilities
    case receipts
    case helper
    case providers
    case compatibility
    case logs
}

public struct SupportBundleManifest: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var createdAt: Date
    public var categories: Set<SupportBundleCategory>
    public var privacyNotice: String

    public init(schemaVersion: Int = 1, createdAt: Date = Date(),
                categories: Set<SupportBundleCategory>,
                privacyNotice: String = "This bundle was created locally after review and is not uploaded automatically.") {
        self.schemaVersion = schemaVersion; self.createdAt = createdAt
        self.categories = categories; self.privacyNotice = privacyNotice
    }
}

public struct SupportBundlePayload: Codable, Equatable, Sendable {
    public var manifest: SupportBundleManifest
    public var application: [String: String]?
    public var capabilities: [String: String]?
    public var receipts: [[String: String]]?
    public var helper: [String: String]?
    public var providers: [[String: String]]?
    public var compatibility: [[String: String]]?
    public var logs: [String]?
}

public struct SupportBundlePreview: Equatable, Sendable {
    public var categories: [SupportBundleCategory: Int]
    public var excludedData: [String]

    public init(categories: [SupportBundleCategory: Int], excludedData: [String]) {
        self.categories = categories; self.excludedData = excludedData
    }
}

public enum SupportBundleExportError: LocalizedError, Equatable {
    case archiveTooLarge

    public var errorDescription: String? {
        switch self { case .archiveTooLarge: "The reviewed support data is too large to archive safely." }
    }
}

public enum SupportBundleRedactor {
    private static let tokenPatterns = [
        #"(?i)\b(bearer|token|secret|password|api[_-]?key)\s*[:=]\s*[^\s,;]+"#,
        #"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b"#,
        #"(?i)(https?://)([^/@\s]+@)?([^/?#\s]+)([^\s]*)"#,
        #"/(Users|home)/[^/\s]+"#,
        #"\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b"#,
        #"(?i)\b(command|arguments?|argv)\s*[:=]\s*[^\n]+"#
    ]

    public static func redact(_ value: String) -> String {
        var result = value
        result = replacing(pattern: tokenPatterns[0], in: result, with: "$1=[REDACTED]")
        result = replacing(pattern: tokenPatterns[1], in: result, with: "[EMAIL]")
        result = replacing(pattern: tokenPatterns[2], in: result, with: "$1$3/[REDACTED]")
        result = replacing(pattern: tokenPatterns[3], in: result, with: "/$1/[USER]")
        result = replacing(pattern: tokenPatterns[4], in: result, with: "[TOKEN]")
        result = replacing(pattern: tokenPatterns[5], in: result, with: "$1=[EXCLUDED]")
        result = result.replacingOccurrences(of: NSHomeDirectory(), with: "~")
        return String(result.prefix(16_384))
    }

    public static func redactDictionary(_ values: [String: String]) -> [String: String] {
        values.reduce(into: [:]) { output, pair in
            let key = pair.key.lowercased()
            if key.contains("clipboard") || key.contains("calendar") || key.contains("note")
                || key.contains("filename") || key.contains("environment") || key.contains("stdout")
                || key.contains("stderr") || key.contains("command") || key.contains("spaceid") {
                output[pair.key] = "[EXCLUDED]"
            } else {
                output[pair.key] = redact(pair.value)
            }
        }
    }

    private static func replacing(pattern: String, in value: String, with replacement: String) -> String {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return value }
        return expression.stringByReplacingMatches(in: value, range: NSRange(value.startIndex..., in: value),
                                                   withTemplate: replacement)
    }
}

public actor SupportBundleBuilder {
    public typealias ReceiptSource = @Sendable () async -> [[String: String]]
    public typealias ProviderSource = @Sendable () async -> [[String: String]]
    public typealias LogSource = @Sendable () async -> [String]
    public typealias HelperSource = @Sendable () async -> [String: String]
    public typealias CompatibilitySource = @Sendable () async -> [[String: String]]

    private let receipts: ReceiptSource
    private let providers: ProviderSource
    private let logs: LogSource
    private let helper: HelperSource
    private let compatibility: CompatibilitySource
    private let now: @Sendable () -> Date

    public init(receipts: @escaping ReceiptSource = { [] },
                providers: @escaping ProviderSource = { [] },
                logs: @escaping LogSource = { [] },
                helper: @escaping HelperSource = { [:] },
                compatibility: @escaping CompatibilitySource = { [] },
                now: @escaping @Sendable () -> Date = { Date() }) {
        self.receipts = receipts; self.providers = providers; self.logs = logs
        self.helper = helper; self.compatibility = compatibility; self.now = now
    }

    public func preview(categories: Set<SupportBundleCategory>) async -> SupportBundlePreview {
        var counts: [SupportBundleCategory: Int] = [:]
        for category in categories { counts[category] = 1 }
        if categories.contains(.receipts) { counts[.receipts] = await receipts().count }
        if categories.contains(.providers) { counts[.providers] = await providers().count }
        if categories.contains(.logs) { counts[.logs] = min(await logs().count, 200) }
        return SupportBundlePreview(categories: counts,
            excludedData: ["Clipboard and calendar content", "Notes and file names", "Provider secrets",
                           "Script commands and output", "Captures and foreign menu text", "Raw Space identifiers"])
    }

    public func build(categories: Set<SupportBundleCategory>) async -> SupportBundlePayload {
        let app: [String: String]? = categories.contains(.application) ? [
            "version": Bundle.main.appVersion,
            "build": Bundle.main.buildNumber,
            "edition": DistributionEdition.current.rawValue,
            "os": ProcessInfo.processInfo.operatingSystemVersionString,
            "architecture": CompatibilityRuntime.current.architecture
        ] : nil
        let caps: [String: String]? = categories.contains(.capabilities)
            ? Dictionary(uniqueKeysWithValues: TonicFeatureID.allCases.map { ($0.rawValue, "unlocked") }) : nil
        return SupportBundlePayload(
            manifest: SupportBundleManifest(createdAt: now(), categories: categories),
            application: app.map(SupportBundleRedactor.redactDictionary),
            capabilities: caps,
            receipts: categories.contains(.receipts) ? await receipts().map(SupportBundleRedactor.redactDictionary) : nil,
            helper: categories.contains(.helper)
                ? SupportBundleRedactor.redactDictionary(await helper()) : nil,
            providers: categories.contains(.providers) ? await providers().map(SupportBundleRedactor.redactDictionary) : nil,
            compatibility: categories.contains(.compatibility)
                ? await compatibility().map(SupportBundleRedactor.redactDictionary) : nil,
            logs: categories.contains(.logs) ? Array(await logs().prefix(200)).map(SupportBundleRedactor.redact) : nil
        )
    }

    /// Writes a locally reviewable archive. Each selected category is kept in a
    /// separate JSON file so users and support staff can inspect or remove it
    /// after export without decoding an opaque binary container.
    public func writeArchive(_ payload: SupportBundlePayload, to url: URL) async throws {
        var entries: [SupportZIPEntry] = []
        try appendJSON(payload.manifest, named: "manifest.json", to: &entries)
        try payload.application.map { try appendJSON($0, named: "application.json", to: &entries) }
        try payload.capabilities.map { try appendJSON($0, named: "capabilities.json", to: &entries) }
        try payload.receipts.map { try appendJSON($0, named: "receipts.json", to: &entries) }
        try payload.helper.map { try appendJSON($0, named: "helper.json", to: &entries) }
        try payload.providers.map { try appendJSON($0, named: "providers.json", to: &entries) }
        try payload.compatibility.map { try appendJSON($0, named: "compatibility.json", to: &entries) }
        if let logs = payload.logs {
            entries.append(SupportZIPEntry(name: "Tonic Support/logs.txt",
                data: Data(logs.joined(separator: "\n").appending("\n").utf8)))
        }
        entries.append(SupportZIPEntry(name: "Tonic Support/README.txt", data: Data("""
        Tonic Support Bundle

        This archive was created locally after your category review. Tonic did not upload it.
        Every included value passed deterministic redaction. Clipboard and Calendar content,
        notes, file names, provider secrets, script commands and output, captures, foreign menu
        text, and raw Space identifiers are always excluded.
        """.utf8)))

        let archive = try SupportZIPWriter.archive(entries: entries)
        try archive.write(to: url, options: .atomic)
    }

    private func appendJSON<Value: Encodable>(_ value: Value, named name: String,
                                               to entries: inout [SupportZIPEntry]) throws {
        let data = try SignedArtifactCoding.canonicalData(for: value)
        entries.append(SupportZIPEntry(name: "Tonic Support/\(name)", data: data))
    }
}

private struct SupportZIPEntry {
    let name: String
    let data: Data
}

/// Minimal ZIP32 writer using the uncompressed storage method. Support bundles
/// are already tightly bounded, so compression would add attack surface without
/// a meaningful user benefit. Fixed UTF-8 paths also prevent path traversal.
private enum SupportZIPWriter {
    private struct CentralRecord {
        let entry: SupportZIPEntry
        let crc: UInt32
        let offset: UInt32
    }

    static func archive(entries: [SupportZIPEntry]) throws -> Data {
        guard entries.count <= Int(UInt16.max) else { throw SupportBundleExportError.archiveTooLarge }
        var output = Data()
        var central: [CentralRecord] = []

        for entry in entries {
            guard entry.name.hasPrefix("Tonic Support/"), !entry.name.contains(".."),
                  let name = entry.name.data(using: .utf8), name.count <= Int(UInt16.max),
                  entry.data.count <= Int(UInt32.max), output.count <= Int(UInt32.max) else {
                throw SupportBundleExportError.archiveTooLarge
            }
            let crc = crc32(entry.data)
            let offset = UInt32(output.count)
            output.appendLE(UInt32(0x04034b50))
            output.appendLE(UInt16(20))
            output.appendLE(UInt16(0x0800))
            output.appendLE(UInt16(0))
            output.appendLE(UInt16(0)); output.appendLE(UInt16(0))
            output.appendLE(crc)
            output.appendLE(UInt32(entry.data.count)); output.appendLE(UInt32(entry.data.count))
            output.appendLE(UInt16(name.count)); output.appendLE(UInt16(0))
            output.append(name); output.append(entry.data)
            central.append(CentralRecord(entry: entry, crc: crc, offset: offset))
        }

        guard output.count <= Int(UInt32.max) else { throw SupportBundleExportError.archiveTooLarge }
        let centralOffset = UInt32(output.count)
        for record in central {
            let name = Data(record.entry.name.utf8)
            output.appendLE(UInt32(0x02014b50))
            output.appendLE(UInt16(20)); output.appendLE(UInt16(20))
            output.appendLE(UInt16(0x0800)); output.appendLE(UInt16(0))
            output.appendLE(UInt16(0)); output.appendLE(UInt16(0))
            output.appendLE(record.crc)
            output.appendLE(UInt32(record.entry.data.count)); output.appendLE(UInt32(record.entry.data.count))
            output.appendLE(UInt16(name.count)); output.appendLE(UInt16(0)); output.appendLE(UInt16(0))
            output.appendLE(UInt16(0)); output.appendLE(UInt16(0)); output.appendLE(UInt32(0))
            output.appendLE(record.offset); output.append(name)
        }
        let centralSize = output.count - Int(centralOffset)
        guard centralSize <= Int(UInt32.max) else { throw SupportBundleExportError.archiveTooLarge }
        output.appendLE(UInt32(0x06054b50))
        output.appendLE(UInt16(0)); output.appendLE(UInt16(0))
        output.appendLE(UInt16(central.count)); output.appendLE(UInt16(central.count))
        output.appendLE(UInt32(centralSize)); output.appendLE(centralOffset); output.appendLE(UInt16(0))
        return output
    }

    private static func crc32(_ data: Data) -> UInt32 {
        var crc = UInt32.max
        for byte in data {
            var value = (crc ^ UInt32(byte)) & 0xff
            for _ in 0..<8 { value = (value & 1) == 1 ? (value >> 1) ^ 0xedb88320 : value >> 1 }
            crc = (crc >> 8) ^ value
        }
        return crc ^ UInt32.max
    }
}

private extension Data {
    mutating func appendLE<Integer: FixedWidthInteger>(_ value: Integer) {
        var little = value.littleEndian
        Swift.withUnsafeBytes(of: &little) { append(contentsOf: $0) }
    }
}
