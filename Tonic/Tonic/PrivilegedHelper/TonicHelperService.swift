#if TONIC_HELPER

import Foundation
import Darwin
import Security
import SystemConfiguration

private final class HelperBoundedCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()
    private let limit: Int
    init(limit: Int = 4_096) { self.limit = limit }
    func append(_ chunk: Data) { lock.withLock { if data.count < limit { data.append(chunk.prefix(limit - data.count)) } } }
    func value() -> Data { lock.withLock { data } }
}

private final class HelperReplyBox: @unchecked Sendable {
    let reply: (Data) -> Void
    init(_ reply: @escaping (Data) -> Void) { self.reply = reply }
}

/// Mutable lifecycle state confined to `TonicHelperService.queue`. The box is
/// explicitly sendable so Process/Dispatch callbacks can hand control back to
/// that queue without Swift 6 treating local captured vars as data races.
private final class HelperProcessState: @unchecked Sendable {
    var timedOut = false
    var completed = false
}

final class TonicHelperService: NSObject, NSXPCListenerDelegate, TonicHelperXPCProtocol, @unchecked Sendable {
    private struct FixedToolInvocation: Sendable {
        let executable: String
        let arguments: [String]
    }

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let queue = DispatchQueue(label: "com.saransh.tonic.helper.operations")
    private var touchedFans = Set<Int>()
    private var fanSessionID: UUID?
    private var watchdog: DispatchSourceTimer?

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        guard Self.authorizedClient(processIdentifier: connection.processIdentifier) else { return false }
        connection.exportedInterface = NSXPCInterface(with: TonicHelperXPCProtocol.self)
        connection.exportedObject = self
        connection.invalidationHandler = { [weak self] in
            guard let self else { return }
            self.queue.async { self.restoreFansToAutomatic() }
        }
        connection.interruptionHandler = { [weak self] in
            guard let self else { return }
            self.queue.async { self.restoreFansToAutomatic() }
        }
        connection.resume()
        return true
    }

    func perform(requestData: Data, withReply reply: @escaping (Data) -> Void) {
        let replyBox = HelperReplyBox(reply)
        queue.async { [weak self] in
            guard let self else { return }
            if requestData.count > TonicHelperPolicy.maximumRequestBytes {
                send(TonicHelperResult(requestID: UUID(), succeeded: false,
                                       detail: "Request exceeds the helper size limit.", error: .requestTooLarge),
                     to: replyBox)
            } else if let request = try? decoder.decode(TonicHelperRequest.self, from: requestData) {
                if let error = TonicHelperPolicy.validated(request) {
                    send(TonicHelperResult(requestID: request.requestID, succeeded: false,
                                           detail: "The helper rejected this operation.", error: error),
                         to: replyBox)
                } else if let tools = fixedTools(for: request.operation) {
                    runFixedTools(requestID: request.requestID, tools: tools) { [weak self] result in
                        self?.send(result, to: replyBox)
                    }
                } else {
                    send(dispatch(request), to: replyBox)
                }
            } else {
                send(TonicHelperResult(requestID: UUID(), succeeded: false,
                                       detail: "Malformed helper request.", error: .malformedRequest),
                     to: replyBox)
            }
        }
    }

    private func send(_ result: TonicHelperResult, to replyBox: HelperReplyBox) {
        replyBox.reply((try? encoder.encode(result)) ?? Data())
    }

    private func dispatch(_ request: TonicHelperRequest) -> TonicHelperResult {
        switch request.operation {
        case .deleteLocalTimeMachineSnapshots, .refreshDNS, .renewPrimaryNetworkService,
             .rebuildSpotlight, .rebuildLaunchServices, .restartSystemService:
            return TonicHelperResult(requestID: request.requestID, succeeded: false,
                                     detail: "The fixed operation was dispatched incorrectly.",
                                     error: .operationFailed)
        case .purgeStaleDocumentRevisions(let days):
            return purgeDocumentRevisions(requestID: request.requestID, minimumAgeDays: days)
        case .purgeStaleSystemData(let domain, let days):
            return purgeStaleSystemData(requestID: request.requestID, domain: domain, minimumAgeDays: days)
        case .setFanMode(let fanID, let automatic, let sessionID):
            guard acceptFanSession(sessionID) else { return staleSessionResult(request.requestID) }
            let ok = SMCReader.shared.setFanMode(fanID, mode: automatic ? .automatic : .forced)
            if !automatic {
                touchedFans.insert(fanID); renewWatchdog()
            } else {
                touchedFans.remove(fanID)
                if touchedFans.isEmpty { watchdog?.cancel(); watchdog = nil; fanSessionID = nil }
            }
            return TonicHelperResult(requestID: request.requestID, succeeded: ok,
                                     detail: ok ? "Fan mode updated." : "The SMC rejected the fan mode.",
                                     affectedItems: ok ? 1 : 0, error: ok ? nil : .operationFailed)
        case .setFanTargetRPM(let fanID, let rpm, let sessionID):
            guard acceptFanSession(sessionID) else { return staleSessionResult(request.requestID) }
            let clamped = min(max(rpm, TonicHelperPolicy.minimumFanRPM), TonicHelperPolicy.maximumFanRPM)
            let ok = SMCReader.shared.setFanSpeed(fanID, rpm: clamped)
            if ok { touchedFans.insert(fanID); renewWatchdog() }
            return TonicHelperResult(requestID: request.requestID, succeeded: ok,
                                     detail: ok ? "Fan target set to \(clamped) RPM." : "The SMC rejected the fan target.",
                                     affectedItems: ok ? 1 : 0, error: ok ? nil : .operationFailed)
        case .renewFanSession(let sessionID):
            guard fanSessionID == sessionID else { return staleSessionResult(request.requestID) }
            renewWatchdog()
            return TonicHelperResult(requestID: request.requestID, succeeded: true, detail: "Fan session renewed.")
        case .restoreAutomaticFanControl(let sessionID):
            guard fanSessionID == sessionID else { return staleSessionResult(request.requestID) }
            let count = touchedFans.count
            restoreFansToAutomatic()
            return TonicHelperResult(requestID: request.requestID, succeeded: true,
                                     detail: "Automatic fan control restored.", affectedItems: count)
        }
    }

    private func fixedTools(for operation: TonicPrivilegedOperation) -> [FixedToolInvocation]? {
        switch operation {
        case .deleteLocalTimeMachineSnapshots:
            return [.init(executable: "/usr/bin/tmutil", arguments: ["deletelocalsnapshots", "/"])]
        case .refreshDNS:
            return [
                .init(executable: "/usr/bin/dscacheutil", arguments: ["-flushcache"]),
                .init(executable: "/usr/bin/killall", arguments: ["-HUP", "mDNSResponder"])
            ]
        case .renewPrimaryNetworkService:
            guard let interface = primaryNetworkInterface() else { return [] }
            return [.init(executable: "/usr/sbin/ipconfig", arguments: ["set", interface, "DHCP"])]
        case .rebuildSpotlight(let scope):
            guard scope == .startupDisk else { return [] }
            return [.init(executable: "/usr/bin/mdutil", arguments: ["-E", "/"])]
        case .rebuildLaunchServices:
            return [.init(
                executable: "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister",
                arguments: ["-kill", "-r", "-domain", "local", "-domain", "system", "-domain", "user"]
            )]
        case .restartSystemService(let service):
            let label: String
            switch service {
            case .dnsResponder: label = "system/com.apple.mDNSResponder"
            case .audio: label = "system/com.apple.audio.coreaudiod"
            case .bluetooth: label = "system/com.apple.bluetoothd"
            case .printing: label = "system/org.cups.cupsd"
            case .timeMachine: label = "system/com.apple.backupd"
            }
            return [.init(executable: "/bin/launchctl", arguments: ["kickstart", "-k", label])]
        case .purgeStaleDocumentRevisions, .purgeStaleSystemData,
             .setFanMode, .setFanTargetRPM, .renewFanSession, .restoreAutomaticFanControl:
            return nil
        }
    }

    private func primaryNetworkInterface() -> String? {
        guard let store = SCDynamicStoreCreate(nil, "com.saransh.tonic.helper" as CFString, nil, nil),
              let value = SCDynamicStoreCopyValue(store, "State:/Network/Global/IPv4" as CFString)
                as? [String: Any],
              let interface = value["PrimaryInterface"] as? String,
              interface.range(of: #"^en[0-9]+$"#, options: .regularExpression) != nil else { return nil }
        return interface
    }

    private func acceptFanSession(_ sessionID: UUID) -> Bool {
        if fanSessionID == nil { fanSessionID = sessionID }
        return fanSessionID == sessionID
    }

    private func staleSessionResult(_ requestID: UUID) -> TonicHelperResult {
        TonicHelperResult(requestID: requestID, succeeded: false,
                          detail: "The fan-control session is stale or unauthorized.", error: .staleSession)
    }

    /// Launch a closed, helper-owned executable without blocking the serial
    /// state queue. That keeps fan heartbeats and watchdog restoration
    /// responsive even if `tmutil` takes a long time.
    private func runFixedTools(requestID: UUID, tools: [FixedToolInvocation],
                               completion: @escaping @Sendable (TonicHelperResult) -> Void) {
        guard !tools.isEmpty else {
            completion(TonicHelperResult(requestID: requestID, succeeded: false,
                                         detail: "The helper could not resolve a safe fixed target.",
                                         error: .invalidArgument))
            return
        }
        runFixedTools(requestID: requestID, tools: tools, index: 0, details: [], completion: completion)
    }

    private func runFixedTools(requestID: UUID, tools: [FixedToolInvocation], index: Int,
                               details: [String], completion: @escaping @Sendable (TonicHelperResult) -> Void) {
        guard index < tools.count else {
            completion(TonicHelperResult(requestID: requestID, succeeded: true,
                                         detail: details.filter { !$0.isEmpty }.joined(separator: "\n"),
                                         affectedItems: tools.count))
            return
        }
        let tool = tools[index]
        runFixedTool(requestID: requestID, executable: tool.executable, arguments: tool.arguments) { [weak self] result in
            guard let self else { return }
            guard result.succeeded else { completion(result); return }
            self.runFixedTools(requestID: requestID, tools: tools, index: index + 1,
                               details: details + [result.detail], completion: completion)
        }
    }

    private func runFixedTool(requestID: UUID, executable: String, arguments: [String],
                              completion: @escaping @Sendable (TonicHelperResult) -> Void) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let stdoutPipe = Pipe(), stderrPipe = Pipe()
        let stdout = HelperBoundedCollector(), stderr = HelperBoundedCollector()
        stdoutPipe.fileHandleForReading.readabilityHandler = { stdout.append($0.availableData) }
        stderrPipe.fileHandleForReading.readabilityHandler = { stderr.append($0.availableData) }
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        let state = HelperProcessState()
        let finish: @Sendable (TonicHelperResult) -> Void = { result in
            guard !state.completed else { return }
            state.completed = true
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            stdout.append(stdoutPipe.fileHandleForReading.readDataToEndOfFile())
            stderr.append(stderrPipe.fileHandleForReading.readDataToEndOfFile())
            completion(result)
        }
        process.terminationHandler = { [weak self] terminated in
            self?.queue.async {
                let combined = stdout.value() + stderr.value()
                let output = String(decoding: combined.prefix(4_096), as: UTF8.self)
                let ok = terminated.terminationStatus == 0 && !state.timedOut
                let detail = state.timedOut ? "The privileged operation timed out."
                    : (output.isEmpty ? (ok ? "Operation completed." : "Operation failed.") : output)
                finish(TonicHelperResult(requestID: requestID, succeeded: ok, detail: detail,
                                         error: ok ? nil : .operationFailed))
            }
        }
        do {
            try process.run()
            queue.asyncAfter(deadline: .now() + 300) {
                guard process.isRunning, !state.completed else { return }
                state.timedOut = true
                process.terminate()
            }
        } catch {
            finish(TonicHelperResult(requestID: requestID, succeeded: false,
                                     detail: error.localizedDescription, error: .operationFailed))
        }
    }

    private func purgeStaleSystemData(requestID: UUID, domain: TonicCleanupDomain,
                                      minimumAgeDays: Int) -> TonicHelperResult {
        let root: URL
        switch domain {
        case .systemCaches: root = URL(fileURLWithPath: "/Library/Caches", isDirectory: true)
        case .diagnosticReports: root = URL(fileURLWithPath: "/Library/Logs/DiagnosticReports", isDirectory: true)
        case .packageUpdates: root = URL(fileURLWithPath: "/Library/Updates", isDirectory: true)
        }
        let standardizedRoot = root.standardizedFileURL
        let cutoff = Date().addingTimeInterval(-Double(minimumAgeDays) * 86_400)
        let keys: Set<URLResourceKey> = [.contentModificationDateKey, .isDirectoryKey,
                                         .isSymbolicLinkKey]
        guard let enumerator = FileManager.default.enumerator(
            at: standardizedRoot,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsPackageDescendants]
        ) else {
            return TonicHelperResult(requestID: requestID, succeeded: false,
                                     detail: "The fixed cleanup domain is unavailable.", error: .operationFailed)
        }
        var removed = 0
        for case let url as URL in enumerator {
            guard removed < 10_000 else { break }
            let candidate = url.standardizedFileURL
            guard candidate.path.hasPrefix(standardizedRoot.path + "/"),
                  let values = try? candidate.resourceValues(forKeys: keys),
                  values.isDirectory != true, values.isSymbolicLink != true,
                  isOwnedByRoot(candidate),
                  let modified = values.contentModificationDate, modified < cutoff else { continue }
            if (try? FileManager.default.removeItem(at: candidate)) != nil { removed += 1 }
        }
        return TonicHelperResult(requestID: requestID, succeeded: true,
                                 detail: "Removed \(removed) stale item\(removed == 1 ? "" : "s") from the fixed \(domain.rawValue) domain.",
                                 affectedItems: removed)
    }

    private func purgeDocumentRevisions(requestID: UUID, minimumAgeDays: Int) -> TonicHelperResult {
        let root = URL(fileURLWithPath: "/System/Volumes/Data/.DocumentRevisions-V100", isDirectory: true)
            .standardizedFileURL
        let cutoff = Date().addingTimeInterval(-Double(minimumAgeDays) * 86_400)
        let keys: Set<URLResourceKey> = [.contentModificationDateKey, .isDirectoryKey, .isSymbolicLinkKey]
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: Array(keys),
                                                              options: [.skipsHiddenFiles]) else {
            return TonicHelperResult(requestID: requestID, succeeded: false,
                                     detail: "DocumentRevisions storage is unavailable.", error: .operationFailed)
        }
        var removed = 0
        for case let url as URL in enumerator {
            let candidate = url.standardizedFileURL
            guard candidate.path.hasPrefix(root.path + "/"),
                  let values = try? candidate.resourceValues(forKeys: keys),
                  values.isDirectory != true, values.isSymbolicLink != true,
                  let modified = values.contentModificationDate, modified < cutoff else { continue }
            if (try? FileManager.default.removeItem(at: candidate)) != nil { removed += 1 }
        }
        return TonicHelperResult(requestID: requestID, succeeded: true,
                                 detail: "Removed \(removed) stale revision file\(removed == 1 ? "" : "s").",
                                 affectedItems: removed)
    }

    private func isOwnedByRoot(_ url: URL) -> Bool {
        url.withUnsafeFileSystemRepresentation { path in
            guard let path else { return false }
            var information = stat()
            return lstat(path, &information) == 0 && information.st_uid == 0
        }
    }

    private func renewWatchdog() {
        watchdog?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 15)
        timer.setEventHandler { [weak self] in self?.restoreFansToAutomatic() }
        timer.resume()
        watchdog = timer
    }

    private func restoreFansToAutomatic() {
        watchdog?.cancel()
        watchdog = nil
        for fanID in touchedFans { _ = SMCReader.shared.setFanMode(fanID, mode: .automatic) }
        touchedFans.removeAll()
        fanSessionID = nil
    }

    static let clientRequirement = "anchor apple generic and certificate leaf[subject.OU] = \"CJ43UNM3AR\" and identifier \"com.saransh.tonic\""

    private static func authorizedClient(processIdentifier: pid_t) -> Bool {
        let attributes = [kSecGuestAttributePid: processIdentifier] as CFDictionary
        var code: SecCode?
        guard SecCodeCopyGuestWithAttributes(nil, attributes, [], &code) == errSecSuccess,
              let code else { return false }
        var requirement: SecRequirement?
        guard SecRequirementCreateWithString(clientRequirement as CFString, [], &requirement) == errSecSuccess,
              let requirement else { return false }
        return SecCodeCheckValidity(code, [], requirement) == errSecSuccess
    }
}

#endif
