//
//  HomebrewService.swift
//  Tonic
//
//  Homebrew cask detection and upgrades for the direct build. Maps installed
//  casks to app bundle paths so the Updates tab can offer `brew upgrade --cask`
//  as the apply mechanism (brew handles quit/replace/quarantine correctly).
//
//  Entirely compiled out of the Mac App Store build: a sandboxed process
//  cannot usefully run brew, and shipping the capability would fail review.
//

#if !TONIC_STORE

import Foundation

/// One installed cask, as reported by `brew info --installed --cask --json=v2`.
struct CaskInfo: Sendable, Equatable {
    let token: String
    let installedVersion: String?
    let latestVersion: String?
    let outdated: Bool
    /// Absolute app-bundle paths this cask installs (e.g. /Applications/iTerm.app).
    let appPaths: [String]
}

@MainActor
@Observable
final class HomebrewService {

    static let shared = HomebrewService()

    private(set) var brewPath: String?
    private(set) var casksByAppPath: [String: CaskInfo] = [:]
    private(set) var lastRefresh: Date?

    private init() {
        brewPath = Self.detectBrew()
    }

    var isAvailable: Bool {
        brewPath != nil && BuildCapabilities.current.allowsPrivilegedFlows
    }

    nonisolated static func detectBrew() -> String? {
        for candidate in ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
        where FileManager.default.isExecutableFile(atPath: candidate) {
            return candidate
        }
        return nil
    }

    /// The cask that owns an app bundle, if any.
    func cask(forAppAt appPath: URL) -> CaskInfo? {
        casksByAppPath[appPath.standardizedFileURL.path]
    }

    // MARK: - Inventory

    /// Refresh the cask → app-path map. Cheap to call repeatedly (10 min TTL).
    func refreshInventory(force: Bool = false) async {
        guard isAvailable, let brewPath else { return }
        if !force, let lastRefresh, Date().timeIntervalSince(lastRefresh) < 600 { return }

        do {
            let json = try await Self.runBrew(
                brewPath,
                arguments: ["info", "--installed", "--cask", "--json=v2"]
            )
            let casks = try Self.parseCaskInventory(json: json)
            var map: [String: CaskInfo] = [:]
            for cask in casks {
                for path in cask.appPaths {
                    map[path] = cask
                }
            }
            casksByAppPath = map
            lastRefresh = Date()
        } catch {
            // Brew being broken should never block update checks; the Sparkle
            // and MAS paths still run. Leave the previous map in place.
        }
    }

    /// Pure parsing of brew's JSON so tests can drive it with fixtures.
    nonisolated static func parseCaskInventory(json: Data, applicationsDir: String = "/Applications") throws -> [CaskInfo] {
        struct Response: Decodable {
            let casks: [Cask]
        }
        struct Cask: Decodable {
            let token: String
            let installed: String?
            let version: String?
            let outdated: Bool?
            let artifacts: [Artifact]?
        }
        // Artifacts are heterogeneous ({"app": ["Foo.app"]}, {"zap": …}, strings…).
        // Decode only the app arrays and ignore everything else.
        struct Artifact: Decodable {
            let app: [String]?

            private enum CodingKeys: String, CodingKey { case app }

            init(from decoder: Decoder) throws {
                if let keyed = try? decoder.container(keyedBy: CodingKeys.self) {
                    // App entries can be ["Foo.app"] or [{"target": …}] — keep strings only.
                    if var nested = try? keyed.nestedUnkeyedContainer(forKey: .app) {
                        var names: [String] = []
                        while !nested.isAtEnd {
                            if let name = try? nested.decode(String.self) {
                                names.append(name)
                            } else {
                                _ = try? nested.decode(AnyIgnored.self)
                            }
                        }
                        app = names.isEmpty ? nil : names
                        return
                    }
                }
                app = nil
            }
        }
        struct AnyIgnored: Decodable {}

        let response = try JSONDecoder().decode(Response.self, from: json)
        return response.casks.map { cask in
            let appNames = (cask.artifacts ?? []).compactMap(\.app).flatMap { $0 }
            let paths = appNames.map { name -> String in
                name.hasPrefix("/") ? name : applicationsDir + "/" + name
            }
            return CaskInfo(
                token: cask.token,
                installedVersion: cask.installed,
                latestVersion: cask.version,
                outdated: cask.outdated ?? false,
                appPaths: paths
            )
        }
    }

    // MARK: - Upgrade

    /// Run `brew upgrade --cask <token>`, streaming output lines as they arrive.
    /// The stream finishes normally on exit 0 and throws on a non-zero exit.
    func upgradeCask(_ token: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            guard let brewPath = self.brewPath else {
                continuation.finish(throwing: HomebrewError.brewNotFound)
                return
            }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: brewPath)
            process.arguments = ["upgrade", "--cask", token]
            var environment = ProcessInfo.processInfo.environment
            environment["HOMEBREW_NO_AUTO_UPDATE"] = "1"
            environment["HOMEBREW_NO_COLOR"] = "1"
            process.environment = environment

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            // The readability and termination handlers fire on different
            // queues; the buffer needs a lock to broker the handoff.
            let buffer = LineBuffer()
            pipe.fileHandleForReading.readabilityHandler = { handle in
                let chunk = handle.availableData
                guard !chunk.isEmpty else { return }
                for line in buffer.appendAndDrainLines(chunk) {
                    continuation.yield(line)
                }
            }

            process.terminationHandler = { process in
                pipe.fileHandleForReading.readabilityHandler = nil
                let remainder = pipe.fileHandleForReading.readDataToEndOfFile()
                for line in buffer.drainAll(appending: remainder) {
                    continuation.yield(line)
                }
                if process.terminationStatus == 0 {
                    continuation.finish()
                } else {
                    continuation.finish(throwing: HomebrewError.upgradeFailed(
                        token: token,
                        exitCode: process.terminationStatus
                    ))
                }
            }

            do {
                try process.run()
            } catch {
                pipe.fileHandleForReading.readabilityHandler = nil
                continuation.finish(throwing: error)
            }

            continuation.onTermination = { _ in
                if process.isRunning { process.terminate() }
            }
        }
    }

    /// One-shot brew invocation returning stdout.
    private nonisolated static func runBrew(_ brewPath: String, arguments: [String]) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: brewPath)
            process.arguments = arguments
            var environment = ProcessInfo.processInfo.environment
            environment["HOMEBREW_NO_AUTO_UPDATE"] = "1"
            process.environment = environment

            let stdout = Pipe()
            process.standardOutput = stdout
            process.standardError = Pipe()

            process.terminationHandler = { process in
                let data = stdout.fileHandleForReading.readDataToEndOfFile()
                if process.terminationStatus == 0 {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: HomebrewError.commandFailed(
                        arguments: arguments,
                        exitCode: process.terminationStatus
                    ))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

/// Lock-protected line assembly shared between pipe callbacks.
private final class LineBuffer: @unchecked Sendable {
    private var data = Data()
    private let lock = NSLock()

    func appendAndDrainLines(_ chunk: Data) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        data.append(chunk)
        var lines: [String] = []
        while let newline = data.firstIndex(of: UInt8(ascii: "\n")) {
            let lineData = data[..<newline]
            data.removeSubrange(...newline)
            if let line = String(data: lineData, encoding: .utf8), !line.isEmpty {
                lines.append(line)
            }
        }
        return lines
    }

    func drainAll(appending remainder: Data) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        data.append(remainder)
        let tail = String(data: data, encoding: .utf8) ?? ""
        data.removeAll()
        return tail.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
    }
}

enum HomebrewError: Error, LocalizedError {
    case brewNotFound
    case commandFailed(arguments: [String], exitCode: Int32)
    case upgradeFailed(token: String, exitCode: Int32)

    var errorDescription: String? {
        switch self {
        case .brewNotFound:
            return "Homebrew is not installed."
        case .commandFailed(let arguments, let exitCode):
            return "brew \(arguments.joined(separator: " ")) failed (exit \(exitCode))."
        case .upgradeFailed(let token, let exitCode):
            return "Upgrading \(token) failed (exit \(exitCode))."
        }
    }
}

#endif
