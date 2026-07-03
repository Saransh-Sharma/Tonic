//
//  UpdateInstaller.swift
//  Tonic
//
//  Tier-3 update application for Sparkle apps (direct build only): download
//  the enclosure, extract, verify — codesign validity AND Team ID match with
//  the installed copy — quit the app with consent, move the old bundle to the
//  Trash (recoverable), install the new one, re-register with LaunchServices.
//
//  Refuses rather than guesses: unsigned apps, Team ID mismatches, unknown
//  archive formats, and running-app veto all abort with a clear reason and
//  leave the installed copy untouched.
//

#if !TONIC_STORE

import AppKit
import Foundation

enum UpdateInstallError: Error, LocalizedError {
    case noDownloadURL
    case downloadFailed(String)
    case unsupportedArchive(String)
    case extractionFailed(String)
    case noAppInArchive
    case signatureInvalid(String)
    case installedAppUnsigned
    case teamIdentifierMismatch(installed: String, downloaded: String)
    case appDeclinedToQuit
    case installFailed(String)

    var errorDescription: String? {
        switch self {
        case .noDownloadURL:
            return "The update feed doesn't publish a download."
        case .downloadFailed(let reason):
            return "Download failed: \(reason)"
        case .unsupportedArchive(let ext):
            return "Unsupported archive type “.\(ext)” — opening the download page instead is safer."
        case .extractionFailed(let reason):
            return "Couldn't extract the update: \(reason)"
        case .noAppInArchive:
            return "The download didn't contain an app bundle."
        case .signatureInvalid(let reason):
            return "The downloaded app failed signature verification: \(reason)"
        case .installedAppUnsigned:
            return "The installed copy isn't code-signed, so Tonic can't verify the update belongs to the same developer."
        case .teamIdentifierMismatch(let installed, let downloaded):
            return "Developer mismatch: installed app is signed by \(installed), the download by \(downloaded). Install refused."
        case .appDeclinedToQuit:
            return "The app didn't quit — update cancelled. Save your work and try again."
        case .installFailed(let reason):
            return "Couldn't install the update: \(reason)"
        }
    }
}

final class UpdateInstaller: @unchecked Sendable {

    static let shared = UpdateInstaller()

    /// Install `update` over the app at `update.appPath`.
    /// `progress` receives short human-readable stage lines.
    func install(_ update: AppUpdate, progress: @escaping @Sendable (String) -> Void) async throws {
        guard let downloadURL = update.updateURL else { throw UpdateInstallError.noDownloadURL }

        let workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TonicUpdate-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workDir) }

        // 1. Download.
        progress("Downloading \(downloadURL.lastPathComponent)…")
        let archiveURL: URL
        do {
            let (tempURL, response) = try await URLSession.shared.download(from: downloadURL)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                throw UpdateInstallError.downloadFailed("HTTP \(http.statusCode)")
            }
            archiveURL = workDir.appendingPathComponent(downloadURL.lastPathComponent)
            try FileManager.default.moveItem(at: tempURL, to: archiveURL)
        } catch let error as UpdateInstallError {
            throw error
        } catch {
            throw UpdateInstallError.downloadFailed(error.localizedDescription)
        }

        // 2. Extract.
        progress("Extracting…")
        let extractDir = workDir.appendingPathComponent("extracted", isDirectory: true)
        try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)
        let newAppURL = try await extractApp(from: archiveURL, into: extractDir)

        // 3. Verify.
        progress("Verifying signature…")
        try verifySignature(of: newAppURL)
        progress("Verifying developer identity…")
        try verifyTeamIdentity(installed: update.appPath, downloaded: newAppURL)

        // 4. Quit the running app, with its consent.
        if let running = NSRunningApplication.runningApplications(
            withBundleIdentifier: update.bundleIdentifier
        ).first {
            progress("Asking \(update.appName) to quit…")
            running.terminate()
            let deadline = Date().addingTimeInterval(10)
            while !running.isTerminated, Date() < deadline {
                try await Task.sleep(nanoseconds: 200_000_000)
            }
            if !running.isTerminated { throw UpdateInstallError.appDeclinedToQuit }
        }

        // 5. Swap: old bundle to the Trash (recoverable), new bundle in.
        progress("Installing…")
        let destination = update.appPath
        let trashResult = await FileOperations.shared.moveFilesToTrash(atPaths: [destination.path])
        guard trashResult.errors.isEmpty else {
            throw UpdateInstallError.installFailed(
                trashResult.errors.first?.errorType.rawValue ?? "couldn't move the old version to the Trash"
            )
        }
        do {
            try FileManager.default.copyItem(at: newAppURL, to: destination)
        } catch {
            // Restore the old copy from the Trash on failure.
            if let trashPath = trashResult.trashMap[destination.path] {
                try? FileManager.default.moveItem(
                    at: URL(fileURLWithPath: trashPath), to: destination
                )
            }
            throw UpdateInstallError.installFailed(error.localizedDescription)
        }

        // 6. Tell LaunchServices about the new bundle.
        LSRegisterURL(destination as CFURL, true)
        progress("Installed \(update.latestVersion).")
    }

    // MARK: - Extraction

    private func extractApp(from archive: URL, into directory: URL) async throws -> URL {
        switch archive.pathExtension.lowercased() {
        case "zip":
            try await runProcess("/usr/bin/ditto", ["-xk", archive.path, directory.path])
            guard let app = findApp(in: directory) else { throw UpdateInstallError.noAppInArchive }
            return app

        case "dmg":
            let mountPoint = directory.appendingPathComponent("mount", isDirectory: true)
            try FileManager.default.createDirectory(at: mountPoint, withIntermediateDirectories: true)
            try await runProcess("/usr/bin/hdiutil", [
                "attach", archive.path, "-nobrowse", "-readonly", "-noautoopen",
                "-mountpoint", mountPoint.path,
            ])
            defer {
                Task.detached {
                    try? await Self.shared.runProcess("/usr/bin/hdiutil", ["detach", mountPoint.path, "-force"])
                }
            }
            guard let mounted = findApp(in: mountPoint) else { throw UpdateInstallError.noAppInArchive }
            // Copy out of the image before detaching.
            let copied = directory.appendingPathComponent(mounted.lastPathComponent)
            try FileManager.default.copyItem(at: mounted, to: copied)
            return copied

        case let ext:
            throw UpdateInstallError.unsupportedArchive(ext)
        }
    }

    private func findApp(in directory: URL) -> URL? {
        guard let children = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil
        ) else { return nil }
        if let app = children.first(where: { $0.pathExtension == "app" }) { return app }
        // One level deep covers "Foo 1.2/Foo.app" archive layouts.
        for child in children {
            if let nested = try? FileManager.default.contentsOfDirectory(
                at: child, includingPropertiesForKeys: nil
            ), let app = nested.first(where: { $0.pathExtension == "app" }) {
                return app
            }
        }
        return nil
    }

    // MARK: - Verification

    private func verifySignature(of appURL: URL) throws {
        var staticCode: SecStaticCode?
        var status = SecStaticCodeCreateWithPath(appURL as CFURL, [], &staticCode)
        guard status == errSecSuccess, let code = staticCode else {
            throw UpdateInstallError.signatureInvalid("couldn't read code signature (\(status))")
        }
        let flags = SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSCheckNestedCode)
        status = SecStaticCodeCheckValidity(code, flags, nil)
        guard status == errSecSuccess else {
            throw UpdateInstallError.signatureInvalid("validity check failed (\(status))")
        }
    }

    func teamIdentifier(of appURL: URL) -> String? {
        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(appURL as CFURL, [], &staticCode) == errSecSuccess,
              let code = staticCode else { return nil }
        var info: CFDictionary?
        guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess,
              let dictionary = info as? [String: Any] else { return nil }
        return dictionary[kSecCodeInfoTeamIdentifier as String] as? String
    }

    private func verifyTeamIdentity(installed: URL, downloaded: URL) throws {
        guard let installedTeam = teamIdentifier(of: installed) else {
            throw UpdateInstallError.installedAppUnsigned
        }
        guard let downloadedTeam = teamIdentifier(of: downloaded),
              downloadedTeam == installedTeam else {
            throw UpdateInstallError.teamIdentifierMismatch(
                installed: installedTeam,
                downloaded: teamIdentifier(of: downloaded) ?? "unknown"
            )
        }
    }

    // MARK: - Process helper

    @discardableResult
    private func runProcess(_ path: String, _ arguments: [String]) async throws -> Int32 {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = arguments
            process.standardOutput = Pipe()
            let errorPipe = Pipe()
            process.standardError = errorPipe
            process.terminationHandler = { process in
                if process.terminationStatus == 0 {
                    continuation.resume(returning: process.terminationStatus)
                } else {
                    let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let reason = String(data: data, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? "exit \(process.terminationStatus)"
                    continuation.resume(throwing: UpdateInstallError.extractionFailed(reason))
                }
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: UpdateInstallError.extractionFailed(error.localizedDescription))
            }
        }
    }
}

#endif
