//
//  MailAttachmentScanner.swift
//  Tonic
//
//  Sizes attachments Apple Mail has stored on disk:
//    · Message attachments under ~/Library/Mail/V*/**/Attachments/
//    · Files saved via Quick Look / "Save" in Mail Downloads (container)
//
//  IMAP attachments usually re-download from the server, but Tonic can't know
//  that per-file, so everything here is personal data: reported with sizes,
//  never smart-selected, deleted only through the Trash + review sheet.
//

import Foundation

struct MailAttachmentReport: Sendable, Equatable {
    /// Attachment files at or above the size threshold, largest first.
    let largeAttachments: [(path: String, size: Int64)]
    /// Top-level items in Mail Downloads.
    let mailDownloads: [(path: String, size: Int64)]

    var largeAttachmentsBytes: Int64 { largeAttachments.reduce(0) { $0 + $1.size } }
    var mailDownloadsBytes: Int64 { mailDownloads.reduce(0) { $0 + $1.size } }

    static func == (lhs: MailAttachmentReport, rhs: MailAttachmentReport) -> Bool {
        lhs.largeAttachments.map(\.path) == rhs.largeAttachments.map(\.path)
            && lhs.mailDownloads.map(\.path) == rhs.mailDownloads.map(\.path)
    }
}

final class MailAttachmentScanner: @unchecked Sendable {

    static let shared = MailAttachmentScanner()

    /// Only attachments at least this large are listed individually.
    let sizeThreshold: Int64
    /// Enumeration cap so a giant mail store can't stall the scan.
    let fileVisitCap: Int

    /// Overridable roots for tests.
    let mailRoot: String
    let mailDownloadsRoot: String

    init(
        sizeThreshold: Int64 = 10 * 1024 * 1024,
        fileVisitCap: Int = 120_000,
        mailRoot: String? = nil,
        mailDownloadsRoot: String? = nil
    ) {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        self.sizeThreshold = sizeThreshold
        self.fileVisitCap = fileVisitCap
        self.mailRoot = mailRoot ?? home + "/Library/Mail"
        self.mailDownloadsRoot = mailDownloadsRoot
            ?? home + "/Library/Containers/com.apple.mail/Data/Library/Mail Downloads"
    }

    func scan() -> MailAttachmentReport {
        MailAttachmentReport(
            largeAttachments: scanLargeAttachments(),
            mailDownloads: scanMailDownloads()
        )
    }

    // MARK: - Message attachments

    private func scanLargeAttachments() -> [(path: String, size: Int64)] {
        let fm = FileManager.default
        // Version dirs: V9, V10, V11… — take whatever exists.
        guard let versions = try? fm.contentsOfDirectory(atPath: mailRoot) else { return [] }

        var results: [(path: String, size: Int64)] = []
        var visited = 0

        for version in versions where version.hasPrefix("V") {
            let versionRoot = URL(fileURLWithPath: mailRoot + "/" + version)
            guard let enumerator = fm.enumerator(
                at: versionRoot,
                includingPropertiesForKeys: [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for case let url as URL in enumerator {
                visited += 1
                if visited > fileVisitCap { return results.sorted { $0.size > $1.size } }

                // Only files inside an Attachments directory count as attachments.
                guard url.path.contains("/Attachments/") else { continue }
                guard let values = try? url.resourceValues(
                    forKeys: [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileSizeKey]
                ), values.isRegularFile == true else { continue }

                let size = Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
                if size >= sizeThreshold {
                    results.append((path: url.path, size: size))
                }
            }
        }
        return results.sorted { $0.size > $1.size }
    }

    // MARK: - Mail Downloads

    private func scanMailDownloads() -> [(path: String, size: Int64)] {
        let fm = FileManager.default
        guard let children = try? fm.contentsOfDirectory(atPath: mailDownloadsRoot) else { return [] }

        var results: [(path: String, size: Int64)] = []
        for child in children where !child.hasPrefix(".") {
            let path = mailDownloadsRoot + "/" + child
            var isDirectory: ObjCBool = false
            guard fm.fileExists(atPath: path, isDirectory: &isDirectory) else { continue }
            let size: Int64
            if isDirectory.boolValue {
                size = DirectorySizeCache.shared.size(for: path, includeHidden: true) ?? 0
            } else {
                size = (try? fm.attributesOfItem(atPath: path)[.size] as? Int64) ?? 0
            }
            results.append((path: path, size: size))
        }
        return results.sorted { $0.size > $1.size }
    }
}
