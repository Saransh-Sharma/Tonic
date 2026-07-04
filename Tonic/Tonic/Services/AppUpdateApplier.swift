//
//  AppUpdateApplier.swift
//  Tonic
//
//  Applies detected app updates. Tiered by capability:
//
//    Tier 1 (all builds): Mac App Store deep link, launch the app so its own
//           updater runs (Sparkle), or download the new version in the browser.
//    Tier 2 (direct build): `brew upgrade --cask` for Homebrew-managed apps,
//           streamed into the UI.
//    Tier 3 (direct build, planned): download-verify-install for Sparkle apps.
//
//  The applier never guesses: the resolved method is shown to the user before
//  anything runs, and every outcome lands in per-app `applyStates` for the UI.
//

import AppKit
import Foundation

/// How Tonic will apply a given update.
enum UpdateApplyMethod: Equatable {
    /// Open the app's App Store page (MAS apps can't be installed by third parties).
    case openAppStore
    /// Launch the app so its built-in Sparkle updater takes over.
    case launchApp
    /// Download the new version with the browser; the user installs it.
    case downloadInBrowser
    /// Upgrade in place via Homebrew (direct build only).
    case homebrewUpgrade(token: String)
    /// Download, verify (signature + Team ID), and install (direct build only).
    case directInstall

    var actionLabel: String {
        switch self {
        case .openAppStore: return "Open App Store"
        case .launchApp: return "Open App to Update"
        case .downloadInBrowser: return "Download Update"
        case .homebrewUpgrade: return "Update"
        case .directInstall: return "Update"
        }
    }

    var explanation: String {
        switch self {
        case .openAppStore:
            return "App Store apps update through Apple. Tonic opens the store page for you."
        case .launchApp:
            return "This app updates itself. Tonic opens it so its updater can run."
        case .downloadInBrowser:
            return "Tonic downloads the new version; drag it to Applications to install."
        case .homebrewUpgrade:
            return "Managed by Homebrew. Tonic runs the upgrade and shows the output."
        case .directInstall:
            return "Tonic downloads the update, verifies it's signed by the same developer, and installs it. The old version goes to the Trash."
        }
    }
}

/// Per-app apply progress for the Updates UI.
enum UpdateApplyState: Equatable {
    case idle
    case running(detail: String?)
    case succeeded(String)
    case failed(String)
}

@MainActor
@Observable
final class AppUpdateApplier {

    static let shared = AppUpdateApplier()

    /// Keyed by bundle identifier.
    private(set) var applyStates: [String: UpdateApplyState] = [:]
    /// Streamed console lines for in-flight Homebrew upgrades, keyed by bundle id.
    private(set) var consoleLines: [String: [String]] = [:]

    private init() {}

    func state(for bundleIdentifier: String) -> UpdateApplyState {
        applyStates[bundleIdentifier] ?? .idle
    }

    // MARK: - Method resolution

    /// Decide how this update can be applied on this build.
    func method(for update: AppUpdate) -> UpdateApplyMethod {
        #if !TONIC_STORE
        if BuildCapabilities.current.allowsPrivilegedFlows,
           let cask = HomebrewService.shared.cask(forAppAt: update.appPath) {
            return .homebrewUpgrade(token: cask.token)
        }
        #endif

        switch update.source {
        case .macAppStore:
            return .openAppStore
        case .sparkle:
            #if !TONIC_STORE
            // Direct install only when everything checks out up front: a zip/dmg
            // enclosure and a signed installed copy whose Team ID we can pin.
            if BuildCapabilities.current.allowsPrivilegedFlows,
               let enclosure = update.updateURL,
               ["zip", "dmg"].contains(enclosure.pathExtension.lowercased()),
               UpdateInstaller.shared.teamIdentifier(of: update.appPath) != nil {
                return .directInstall
            }
            #endif
            return .launchApp
        case .homebrewCask:
            #if !TONIC_STORE
            if let cask = HomebrewService.shared.cask(forAppAt: update.appPath) {
                return .homebrewUpgrade(token: cask.token)
            }
            #endif
            return update.updateURL != nil ? .downloadInBrowser : .launchApp
        case .unknown:
            return update.updateURL != nil ? .downloadInBrowser : .launchApp
        }
    }

    // MARK: - Apply

    func apply(_ update: AppUpdate) async {
        let bundleId = update.bundleIdentifier
        applyStates[bundleId] = .running(detail: nil)

        switch method(for: update) {
        case .openAppStore:
            openAppStorePage(for: update)
            applyStates[bundleId] = .succeeded("Opened App Store — finish the update there.")

        case .launchApp:
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            do {
                _ = try await NSWorkspace.shared.openApplication(at: update.appPath, configuration: config)
                applyStates[bundleId] = .succeeded("App opened — its updater takes it from here.")
            } catch {
                applyStates[bundleId] = .failed("Couldn't open the app: \(error.localizedDescription)")
            }

        case .downloadInBrowser:
            if let url = update.updateURL {
                NSWorkspace.shared.open(url)
                applyStates[bundleId] = .succeeded("Download started in your browser.")
            } else {
                applyStates[bundleId] = .failed("No download link is published for this app.")
            }

        case .homebrewUpgrade(let token):
            await applyViaHomebrew(update: update, token: token)

        case .directInstall:
            await applyViaDirectInstall(update)
        }
    }

    private func applyViaDirectInstall(_ update: AppUpdate) async {
        #if TONIC_STORE
        applyStates[update.bundleIdentifier] = .failed("Direct installs aren't available in this edition.")
        #else
        let bundleId = update.bundleIdentifier
        consoleLines[bundleId] = []
        do {
            try await UpdateInstaller.shared.install(update) { line in
                Task { @MainActor in
                    AppUpdateApplier.shared.consoleLines[bundleId, default: []].append(line)
                    AppUpdateApplier.shared.applyStates[bundleId] = .running(detail: line)
                }
            }
            applyStates[bundleId] = .succeeded(
                "Updated to \(update.latestVersion). The old version is in the Trash if you need it."
            )
        } catch {
            applyStates[bundleId] = .failed(error.localizedDescription)
        }
        #endif
    }

    private func openAppStorePage(for update: AppUpdate) {
        if let trackId = update.trackId,
           let url = URL(string: "macappstore://apps.apple.com/app/id\(trackId)?mt=12") {
            NSWorkspace.shared.open(url)
        } else if let url = update.updateURL {
            NSWorkspace.shared.open(url)
        } else if let url = URL(string: "macappstore://showUpdatesPage") {
            NSWorkspace.shared.open(url)
        }
    }

    private func applyViaHomebrew(update: AppUpdate, token: String) async {
        #if TONIC_STORE
        applyStates[update.bundleIdentifier] = .failed("Homebrew upgrades aren't available in this edition.")
        #else
        let bundleId = update.bundleIdentifier
        consoleLines[bundleId] = []
        do {
            for try await line in HomebrewService.shared.upgradeCask(token) {
                consoleLines[bundleId, default: []].append(line)
                applyStates[bundleId] = .running(detail: line)
            }
            applyStates[bundleId] = .succeeded("Updated to \(update.latestVersion) via Homebrew.")
        } catch {
            applyStates[bundleId] = .failed(error.localizedDescription)
        }
        #endif
    }

    /// Clear a finished state (row returns to idle after the user dismisses it).
    func reset(_ bundleIdentifier: String) {
        applyStates[bundleIdentifier] = nil
        consoleLines[bundleIdentifier] = nil
    }
}
