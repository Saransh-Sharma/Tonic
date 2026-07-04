//
//  NetworkPerProcessSampler.swift
//  Tonic
//
//  Per-process network bandwidth via `nettop -P -x -L 1` (direct build only —
//  a sandboxed nettop returns nothing useful). nettop reports cumulative
//  bytes since process start, so rates come from diffing two passes, the
//  same trick ProcessSampler uses for CPU%.
//

#if !TONIC_STORE

import Foundation

struct ProcessBandwidth: Sendable, Identifiable, Equatable {
    /// "name.pid" — nettop's row key.
    let id: String
    let name: String
    let pid: Int32
    let bytesInPerSecond: Double
    let bytesOutPerSecond: Double
    let totalBytesIn: UInt64
    let totalBytesOut: UInt64
}

final class NetworkPerProcessSampler: @unchecked Sendable {

    static let shared = NetworkPerProcessSampler()

    private let lock = NSLock()
    private var previous: [String: (bytesIn: UInt64, bytesOut: UInt64, timestamp: TimeInterval)] = [:]

    var isAvailable: Bool {
        BuildCapabilities.current.allowsPrivilegedFlows
            && FileManager.default.isExecutableFile(atPath: "/usr/bin/nettop")
    }

    /// One nettop pass; rates are zero on the first call and real thereafter.
    func sample(limit: Int = 8) async -> [ProcessBandwidth] {
        guard isAvailable else { return [] }
        guard let output = await Self.runNettop() else { return [] }

        let now = ProcessInfo.processInfo.systemUptime
        let rows = Self.parse(output)

        let previousSnapshot = snapshotPrevious()

        var results: [ProcessBandwidth] = []
        var next: [String: (bytesIn: UInt64, bytesOut: UInt64, timestamp: TimeInterval)] = [:]
        for row in rows {
            next[row.key] = (row.bytesIn, row.bytesOut, now)

            var inRate = 0.0
            var outRate = 0.0
            if let prev = previousSnapshot[row.key], now > prev.timestamp {
                let elapsed = now - prev.timestamp
                if row.bytesIn >= prev.bytesIn {
                    inRate = Double(row.bytesIn - prev.bytesIn) / elapsed
                }
                if row.bytesOut >= prev.bytesOut {
                    outRate = Double(row.bytesOut - prev.bytesOut) / elapsed
                }
            }

            // Split "name.pid" from the right — process names may contain dots.
            let pieces = row.key.split(separator: ".")
            let pid = Int32(pieces.last.map(String.init) ?? "") ?? 0
            let name = pieces.dropLast().joined(separator: ".")

            results.append(ProcessBandwidth(
                id: row.key,
                name: name.isEmpty ? row.key : name,
                pid: pid,
                bytesInPerSecond: inRate,
                bytesOutPerSecond: outRate,
                totalBytesIn: row.bytesIn,
                totalBytesOut: row.bytesOut
            ))
        }

        storePrevious(next)

        return results
            .sorted { ($0.bytesInPerSecond + $0.bytesOutPerSecond) > ($1.bytesInPerSecond + $1.bytesOutPerSecond) }
            .prefix(limit)
            .map { $0 }
    }

    // Synchronous accessors keep NSLock out of async contexts.
    private func snapshotPrevious() -> [String: (bytesIn: UInt64, bytesOut: UInt64, timestamp: TimeInterval)] {
        lock.lock()
        defer { lock.unlock() }
        return previous
    }

    private func storePrevious(_ next: [String: (bytesIn: UInt64, bytesOut: UInt64, timestamp: TimeInterval)]) {
        lock.lock()
        defer { lock.unlock() }
        previous = next
    }

    /// Pure CSV parsing so tests can drive it with fixtures.
    /// Lines look like: `mDNSResponder.426,161357628,78966900,`
    static func parse(_ output: String) -> [(key: String, bytesIn: UInt64, bytesOut: UInt64)] {
        output.split(separator: "\n").compactMap { line in
            let columns = line.split(separator: ",", omittingEmptySubsequences: false)
            guard columns.count >= 3 else { return nil }
            let key = String(columns[0])
            // Header row has an empty key column.
            guard !key.isEmpty,
                  let bytesIn = UInt64(columns[1]),
                  let bytesOut = UInt64(columns[2])
            else { return nil }
            return (key, bytesIn, bytesOut)
        }
    }

    private static func runNettop() async -> String? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/nettop")
                process.arguments = ["-P", "-x", "-L", "1", "-J", "bytes_in,bytes_out"]
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = Pipe()
                do {
                    try process.run()
                    process.waitUntilExit()
                } catch {
                    continuation.resume(returning: nil)
                    return
                }
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(returning: String(data: data, encoding: .utf8))
            }
        }
    }
}

#endif
