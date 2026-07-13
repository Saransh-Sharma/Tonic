import Foundation

public struct RecoveryProbeSnapshot: Codable, Equatable, Sendable {
    public var dnsHealthy: Bool?
    public var networkHealthy: Bool?
    public var spotlightHealthy: Bool?
    public var launchServicesHealthy: Bool?
    public var userServices: [TonicUserService: Bool]
    public var systemServices: [TonicSystemService: Bool]
    public var timeMachineHealthy: Bool?
    public var staleBytes: [TonicCleanupDomain: Int64]

    public init(dnsHealthy: Bool? = nil, networkHealthy: Bool? = nil,
                spotlightHealthy: Bool? = nil, launchServicesHealthy: Bool? = nil,
                userServices: [TonicUserService: Bool] = [:],
                systemServices: [TonicSystemService: Bool] = [:],
                timeMachineHealthy: Bool? = nil,
                staleBytes: [TonicCleanupDomain: Int64] = [:]) {
        self.dnsHealthy = dnsHealthy
        self.networkHealthy = networkHealthy
        self.spotlightHealthy = spotlightHealthy
        self.launchServicesHealthy = launchServicesHealthy
        self.userServices = userServices
        self.systemServices = systemServices
        self.timeMachineHealthy = timeMachineHealthy
        self.staleBytes = staleBytes
    }
}

public protocol RecoveryProbing: Sendable {
    func snapshot() async -> RecoveryProbeSnapshot
}

private struct RecoveryCommandResult: Sendable {
    var status: Int32
    var output: String
}

public actor SystemRecoveryProbe: RecoveryProbing {
    public init() {}

    public func snapshot() async -> RecoveryProbeSnapshot {
        async let dns = command("/usr/bin/dscacheutil", ["-q", "host", "-a", "name", "apple.com"])
        async let network = command("/usr/sbin/scutil", ["--nwi"])
        async let spotlight = command("/usr/bin/mdutil", ["-s", "/"])
        async let timeMachine = command("/usr/bin/tmutil", ["status"])
        async let finder = command("/usr/bin/pgrep", ["-x", "Finder"])
        async let dock = command("/usr/bin/pgrep", ["-x", "Dock"])
        async let systemUI = command("/usr/bin/pgrep", ["-x", "SystemUIServer"])
        async let audio = command("/bin/launchctl", ["print", "system/com.apple.audio.coreaudiod"])
        async let bluetooth = command("/bin/launchctl", ["print", "system/com.apple.bluetoothd"])
        async let printing = command("/bin/launchctl", ["print", "system/org.cups.cupsd"])

        async let cacheBytes = Self.staleSize(at: "/Library/Caches", olderThanDays: 30)
        async let reportBytes = Self.staleSize(at: "/Library/Logs/DiagnosticReports", olderThanDays: 30)
        async let updateBytes = Self.staleSize(at: "/Library/Updates", olderThanDays: 30)

        let values = await (dns, network, spotlight, timeMachine, finder, dock, systemUI, audio, bluetooth, printing,
                            cacheBytes, reportBytes, updateBytes)
        let networkHealthy = values.1.status == 0
            && values.1.output.localizedCaseInsensitiveContains("Network interfaces")
            && !values.1.output.localizedCaseInsensitiveContains("Network interfaces: 0")
        let launchServicesPath = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
        return RecoveryProbeSnapshot(
            dnsHealthy: values.0.status == 0,
            networkHealthy: networkHealthy,
            spotlightHealthy: values.2.status == 0 && values.2.output.localizedCaseInsensitiveContains("enabled"),
            launchServicesHealthy: FileManager.default.isExecutableFile(atPath: launchServicesPath),
            userServices: [.finder: values.4.status == 0, .dock: values.5.status == 0,
                           .systemUIServer: values.6.status == 0],
            systemServices: [.audio: values.7.status == 0, .bluetooth: values.8.status == 0,
                             .printing: values.9.status == 0],
            timeMachineHealthy: values.3.status == 0,
            staleBytes: [.systemCaches: values.10, .diagnosticReports: values.11,
                         .packageUpdates: values.12]
        )
    }

    private nonisolated static func staleSize(at path: String, olderThanDays days: Int) -> Int64 {
        let root = URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
        let cutoff = Date().addingTimeInterval(-Double(days) * 86_400)
        let keys: [URLResourceKey] = [.isRegularFileKey, .isSymbolicLinkKey,
                                      .contentModificationDateKey, .fileAllocatedSizeKey]
        guard let enumerator = FileManager.default.enumerator(at: root,
            includingPropertiesForKeys: keys, options: [.skipsPackageDescendants, .skipsHiddenFiles]) else { return 0 }
        var total: Int64 = 0
        var visited = 0
        for case let url as URL in enumerator {
            visited += 1
            guard visited <= 100_000 else { break }
            let candidate = url.standardizedFileURL
            guard candidate.path.hasPrefix(root.path + "/"),
                  let values = try? candidate.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true, values.isSymbolicLink != true,
                  let modified = values.contentModificationDate, modified < cutoff else { continue }
            total = min(Int64.max, total + Int64(values.fileAllocatedSize ?? 0))
        }
        return total
    }

    private func command(_ executable: String, _ arguments: [String]) async -> RecoveryCommandResult {
        do {
            let result = try await RecoveryBoundedProcessRunner.run(
                executable: executable,
                arguments: arguments,
                timeout: .seconds(15),
                outputLimit: 64 * 1_024
            )
            let output = String(decoding: result.stdout + result.stderr, as: UTF8.self)
            return RecoveryCommandResult(
                status: result.timedOut ? -1 : result.terminationStatus,
                output: result.timedOut ? "Diagnostic command timed out.\n" + output : output
            )
        } catch {
            return RecoveryCommandResult(status: -1, output: error.localizedDescription)
        }
    }
}

public actor RecoveryDiagnosticActor {
    private let probe: any RecoveryProbing

    public init(probe: any RecoveryProbing = SystemRecoveryProbe()) {
        self.probe = probe
    }

    public func diagnose() async -> [RecoveryDiagnostic] {
        Self.diagnostics(from: await probe.snapshot())
    }

    public nonisolated static func diagnostics(from snapshot: RecoveryProbeSnapshot) -> [RecoveryDiagnostic] {
        var output: [RecoveryDiagnostic] = []
        output.append(healthDiagnostic(id: .dns, title: String(localized: "DNS resolution"), healthy: snapshot.dnsHealthy,
            failure: String(localized: "The DNS resolver did not return a healthy lookup."), action: .refreshDNS))
        output.append(healthDiagnostic(id: .network, title: String(localized: "Active network service"), healthy: snapshot.networkHealthy,
            failure: String(localized: "The primary network service could not complete a normal lookup."), action: .renewPrimaryNetwork))
        output.append(healthDiagnostic(id: .spotlight, title: String(localized: "Spotlight index"), healthy: snapshot.spotlightHealthy,
            failure: String(localized: "Indexing is disabled or did not report a healthy state for the startup disk."),
            action: .rebuildSpotlightStartupDisk))
        output.append(healthDiagnostic(id: .launchServices, title: String(localized: "Application registration"), healthy: snapshot.launchServicesHealthy,
            failure: String(localized: "The LaunchServices registration tool is unavailable or unhealthy."), action: .rebuildLaunchServices))
        for service in TonicUserService.allCases {
            let id: RecoveryDiagnosticID = switch service {
            case .finder: .finder
            case .dock: .dock
            case .systemUIServer: .systemUIServer
            }
            output.append(healthDiagnostic(id: id, title: service.rawValue, healthy: snapshot.userServices[service],
                failure: String(localized: "\(service.rawValue) is not responding normally."), action: .restartUserService(service: service)))
        }
        for service in [TonicSystemService.printing, .audio, .bluetooth] {
            let id: RecoveryDiagnosticID = switch service {
            case .printing: .printing
            case .audio: .audio
            case .bluetooth: .bluetooth
            default: .timeMachine
            }
            output.append(healthDiagnostic(id: id, title: service.title.capitalized,
                healthy: snapshot.systemServices[service], failure: String(localized: "The \(service.title) did not report a healthy state."),
                action: .restartSystemService(service: service)))
        }
        output.append(healthDiagnostic(id: .timeMachine, title: String(localized: "Time Machine"), healthy: snapshot.timeMachineHealthy,
            failure: String(localized: "Time Machine status could not be read normally."), action: .restartSystemService(service: .timeMachine)))
        for domain in TonicCleanupDomain.allCases {
            guard let bytes = snapshot.staleBytes[domain], bytes > 0 else { continue }
            let id: RecoveryDiagnosticID = switch domain {
            case .systemCaches: .systemCaches
            case .diagnosticReports: .diagnosticReports
            case .packageUpdates: .packageUpdates
            }
            output.append(RecoveryDiagnostic(id: id, title: domain.title,
                detail: String(localized: "Stale data is available for reviewed reclamation."),
                evidence: ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file),
                severity: .information,
                suggestedAction: .purgeStaleSystemData(domain: domain, minimumAgeDays: 30)))
        }
        return output
    }

    private static func healthDiagnostic(id: RecoveryDiagnosticID, title: String, healthy: Bool?,
                                         failure: String, action: RecoveryActionID) -> RecoveryDiagnostic {
        switch healthy {
        case true:
            RecoveryDiagnostic(id: id, title: title, detail: String(localized: "No repair is recommended."),
                               evidence: String(localized: "Healthy"), severity: .healthy)
        case false:
            RecoveryDiagnostic(id: id, title: title, detail: failure,
                               evidence: String(localized: "Diagnostic check failed"), severity: .warning, suggestedAction: action)
        case nil:
            RecoveryDiagnostic(id: id, title: title, detail: String(localized: "Tonic could not inspect this subsystem in the current edition or permission state."),
                               evidence: String(localized: "Not inspected"), severity: .information)
        }
    }
}

enum RecoveryPlanBuilder {
    static func makePlan(diagnostics: [RecoveryDiagnostic], edition: DistributionEdition = .current,
                         now: Date = Date()) -> RecoveryPlan {
        let steps = diagnostics.compactMap { diagnostic -> RecoveryStep? in
            guard let action = diagnostic.suggestedAction else { return nil }
            return RecoveryStep(action: action, reason: diagnostic.detail,
                expectedImpact: impact(for: action), recoveryBehavior: recovery(for: action),
                isReportOnly: edition == .store && (action.requiresPrivilege || isAutomaticForeignAction(action)))
        }
        return RecoveryPlan(createdAt: now, steps: steps)
    }

    private static func impact(for action: RecoveryActionID) -> String {
        switch action {
        case .refreshDNS: String(localized: "Existing connections stay open; new name lookups may pause briefly.")
        case .renewPrimaryNetwork: String(localized: "The active connection may disconnect for several seconds.")
        case .rebuildSpotlightStartupDisk: String(localized: "Search results may be incomplete while macOS rebuilds the index.")
        case .rebuildLaunchServices: String(localized: "Application associations and Open With data are rebuilt.")
        case .restartUserService(let service): String(localized: "\(service.rawValue) disappears briefly and macOS relaunches it.")
        case .restartSystemService(let service): String(localized: "The \(service.title) is interrupted briefly; saved configuration is preserved.")
        case .reclaimLocalSnapshots: String(localized: "Local snapshots are deleted from the startup disk; backup history on the Time Machine destination is unchanged.")
        case .purgeDocumentRevisions: String(localized: "Only revision files older than the reviewed age are removed.")
        case .purgeStaleSystemData(let domain, _): String(localized: "Only old files inside the fixed \(domain.title) domain are removed.")
        }
    }

    private static func recovery(for action: RecoveryActionID) -> String {
        switch action {
        case .restartUserService, .restartSystemService, .refreshDNS, .renewPrimaryNetwork:
            String(localized: "macOS relaunches or repopulates the service automatically.")
        case .rebuildSpotlightStartupDisk, .rebuildLaunchServices:
            String(localized: "macOS reconstructs the database from installed applications and files.")
        case .reclaimLocalSnapshots, .purgeDocumentRevisions, .purgeStaleSystemData:
            String(localized: "The removed stale data is not restorable; the reviewed scope excludes user documents and saved configuration.")
        }
    }

    private static func isAutomaticForeignAction(_ action: RecoveryActionID) -> Bool {
        switch action {
        case .restartUserService, .rebuildLaunchServices: true
        default: false
        }
    }
}
