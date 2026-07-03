//
//  MobileBackupScanner.swift
//  Tonic
//
//  Finds iOS/iPadOS device backups stored by Finder/iTunes under
//  ~/Library/Application Support/MobileSync/Backup. Each backup folder is one
//  device snapshot; its Info.plist names the device and the last backup date.
//
//  Backups are personal data: Tonic reports them, never smart-selects them,
//  and deletion always routes through the Trash + review sheet.
//

import Foundation

struct MobileBackupEntry: Sendable, Equatable {
    let path: String
    let deviceName: String
    let productType: String?
    let lastBackupDate: Date?
    let size: Int64

    /// Older than six months — likely from a device that's gone or re-backed elsewhere.
    var isStale: Bool {
        guard let lastBackupDate else { return true }
        return Date().timeIntervalSince(lastBackupDate) > 180 * 24 * 3600
    }
}

final class MobileBackupScanner: @unchecked Sendable {

    static let shared = MobileBackupScanner()

    private let sizeCache = DirectorySizeCache.shared

    /// Override for tests.
    let backupRoot: String

    init(backupRoot: String? = nil) {
        self.backupRoot = backupRoot
            ?? FileManager.default.homeDirectoryForCurrentUser.path
            + "/Library/Application Support/MobileSync/Backup"
    }

    func scanBackups() -> [MobileBackupEntry] {
        let fm = FileManager.default
        guard let children = try? fm.contentsOfDirectory(atPath: backupRoot) else {
            return []
        }

        var entries: [MobileBackupEntry] = []
        for child in children where !child.hasPrefix(".") {
            let backupPath = backupRoot + "/" + child
            var isDirectory: ObjCBool = false
            guard fm.fileExists(atPath: backupPath, isDirectory: &isDirectory),
                  isDirectory.boolValue else { continue }

            let info = readInfoPlist(at: backupPath + "/Info.plist")
            let size = sizeCache.size(for: backupPath, includeHidden: true) ?? 0

            entries.append(MobileBackupEntry(
                path: backupPath,
                deviceName: info?["Device Name"] as? String ?? child,
                productType: info?["Product Type"] as? String,
                lastBackupDate: info?["Last Backup Date"] as? Date,
                size: size
            ))
        }
        return entries.sorted { $0.size > $1.size }
    }

    private func readInfoPlist(at path: String) -> [String: Any]? {
        guard let data = FileManager.default.contents(atPath: path) else { return nil }
        return (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any]
    }
}
