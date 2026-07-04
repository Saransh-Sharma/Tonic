//
//  SystemIntegrityScanner.swift
//  Tonic
//
//  Finds broken configuration remnants:
//    · Corrupt preference plists in ~/Library/Preferences that no parser accepts
//    · Launch agents whose target binary no longer exists (dangling login items)
//
//  Deliberately conservative: Apple-domain plists are never flagged, plists of
//  currently running apps are skipped, and anything matching the protected-apps
//  or whitelist patterns is left alone. Findings are junk-class but never
//  smart-selected — the user opts in.
//

import AppKit
import Foundation

struct BrokenPreferenceEntry: Sendable, Equatable {
    let path: String
    let size: Int64
    let reason: String
}

struct DanglingLaunchAgentEntry: Sendable, Equatable {
    let plistPath: String
    let label: String
    let missingProgramPath: String
}

final class SystemIntegrityScanner: @unchecked Sendable {

    static let shared = SystemIntegrityScanner()

    /// Overridable roots for tests.
    let preferencesRoot: String
    let launchAgentsRoot: String

    init(preferencesRoot: String? = nil, launchAgentsRoot: String? = nil) {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        self.preferencesRoot = preferencesRoot ?? home + "/Library/Preferences"
        self.launchAgentsRoot = launchAgentsRoot ?? home + "/Library/LaunchAgents"
    }

    // MARK: - Broken preferences

    func scanBrokenPreferences(runningBundleIDs: Set<String>? = nil) -> [BrokenPreferenceEntry] {
        let fm = FileManager.default
        guard let children = try? fm.contentsOfDirectory(atPath: preferencesRoot) else { return [] }

        let running = runningBundleIDs ?? Self.currentRunningBundleIDs()
        var entries: [BrokenPreferenceEntry] = []

        for child in children where child.hasSuffix(".plist") {
            let bundleId = String(child.dropLast(".plist".count))

            // Never touch Apple's domains — a "corrupt" system plist is not ours to judge.
            if bundleId.hasPrefix("com.apple.") || bundleId.hasPrefix(".GlobalPreferences") { continue }
            // Skip apps that are running (they may be mid-write).
            if running.contains(bundleId) { continue }

            let path = preferencesRoot + "/" + child
            if ProtectedApps.isPathProtected(path) { continue }

            guard let attrs = try? fm.attributesOfItem(atPath: path),
                  let size = attrs[.size] as? Int64 else { continue }

            // Zero-byte plists are leftovers from crashed writes.
            if size == 0 {
                entries.append(BrokenPreferenceEntry(path: path, size: 0, reason: "Empty file"))
                continue
            }

            guard let data = fm.contents(atPath: path) else { continue }
            do {
                _ = try PropertyListSerialization.propertyList(from: data, format: nil)
            } catch {
                entries.append(BrokenPreferenceEntry(
                    path: path,
                    size: size,
                    reason: "Unreadable property list"
                ))
            }
        }
        return entries.sorted { $0.path < $1.path }
    }

    private static func currentRunningBundleIDs() -> Set<String> {
        Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
    }

    // MARK: - Dangling launch agents

    func scanDanglingLaunchAgents() -> [DanglingLaunchAgentEntry] {
        let fm = FileManager.default
        guard let children = try? fm.contentsOfDirectory(atPath: launchAgentsRoot) else { return [] }

        var entries: [DanglingLaunchAgentEntry] = []
        for child in children where child.hasSuffix(".plist") {
            let plistPath = launchAgentsRoot + "/" + child
            guard let data = fm.contents(atPath: plistPath),
                  let plist = (try? PropertyListSerialization.propertyList(from: data, format: nil))
                    as? [String: Any]
            else { continue }

            // Resolve the executable this agent launches. Only absolute paths
            // are checked — relative names resolve via PATH and can't be
            // declared missing with confidence.
            let program = (plist["Program"] as? String)
                ?? (plist["ProgramArguments"] as? [String])?.first
            guard let program, program.hasPrefix("/") else { continue }

            // BundleProgram/associated-bundle agents are managed by their apps.
            if plist["AssociatedBundleIdentifiers"] != nil { continue }

            if !fm.fileExists(atPath: program) {
                entries.append(DanglingLaunchAgentEntry(
                    plistPath: plistPath,
                    label: plist["Label"] as? String ?? child,
                    missingProgramPath: program
                ))
            }
        }
        return entries.sorted { $0.plistPath < $1.plistPath }
    }
}
