//
//  FolderScanReportView.swift
//  Tonic
//
//  One-shot folder report for File ▸ Scan Folder… and Dock drops: total size
//  plus the largest files inside, each revealable or trash-able (recoverable,
//  like every Tonic removal). Honest states while sizing runs.
//

import SwiftUI
import AppKit

struct FolderScanReportView: View {
    let folderPath: String
    let onDismiss: () -> Void

    private struct Entry: Identifiable {
        var id: String { path }
        let path: String
        let size: Int64
        var name: String { (path as NSString).lastPathComponent }
    }

    @State private var totalSize: Int64?
    @State private var largestFiles: [Entry] = []
    @State private var isScanning = true
    @State private var trashedPaths: Set<String> = []
    @State private var message: String?

    private let fileLimit = 12

    var body: some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.md) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text((folderPath as NSString).lastPathComponent)
                        .tonicType(.cardHeading)
                        .foregroundStyle(TonicDS.Colors.textPrimary)
                    Text(folderPath).tonicType(.micro).monospaced()
                        .foregroundStyle(TonicDS.Colors.textMuted)
                        .lineLimit(1).truncationMode(.middle)
                }
                Spacer()
                TextAction("Done", color: TonicDS.Colors.linkBlue, action: onDismiss)
            }

            HStack(spacing: TonicDS.Space.xl) {
                VStack(alignment: .leading, spacing: 2) {
                    MonoLabel("TOTAL SIZE")
                    if let totalSize {
                        Metric(Self.bytes(totalSize), color: TonicDS.Colors.textPrimary)
                    } else {
                        HStack(spacing: TonicDS.Space.xs) {
                            ProgressView().controlSize(.small)
                            MonoLabel("SIZING…")
                        }
                        .frame(height: 34)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    MonoLabel("LARGEST FILES")
                    Metric(isScanning ? "—" : "\(largestFiles.count)", color: TonicDS.Colors.textPrimary)
                }
            }

            if let message {
                TonicInlineNotice(message: message, tone: .info)
            }

            TonicHairline()

            if isScanning && largestFiles.isEmpty {
                MonoLabel("Scanning folder contents…")
            } else if largestFiles.isEmpty {
                TonicEmptyState(
                    systemImage: "folder",
                    title: "No large files here",
                    message: "Nothing over 1 MB was found in this folder."
                )
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(largestFiles) { entry in
                            fileRow(entry)
                            TonicHairline()
                        }
                    }
                }
            }
        }
        .padding(TonicDS.Space.lg)
        .frame(width: 560, height: 480)
        .tonicSheetBackground()
        .task(id: folderPath) { await scan() }
    }

    private func fileRow(_ entry: Entry) -> some View {
        let isTrashed = trashedPaths.contains(entry.path)
        return SystemListRow(
            leading: {
                Image(nsImage: NSWorkspace.shared.icon(forFile: entry.path))
                    .resizable().frame(width: 22, height: 22)
                    .opacity(isTrashed ? 0.4 : 1)
            },
            center: {
                Text(entry.name).tonicType(.body)
                    .foregroundStyle(isTrashed ? TonicDS.Colors.textMuted : TonicDS.Colors.textPrimary)
                    .strikethrough(isTrashed)
                    .lineLimit(1)
            },
            trailing: {
                HStack(spacing: TonicDS.Space.md) {
                    Text(Self.bytes(entry.size)).tonicType(.monoLabel).monospacedDigit()
                        .foregroundStyle(TonicDS.Colors.textPrimary)
                    if isTrashed {
                        StatusChip("IN TRASH", color: TonicDS.Colors.statusInfo)
                    } else {
                        TextAction("Reveal", color: TonicDS.Colors.linkBlue) {
                            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: entry.path)])
                        }
                        TextAction("Trash", color: TonicDS.Colors.statusCritical) {
                            Task { await trash(entry) }
                        }
                    }
                }
            }
        )
        .help(entry.path)
    }

    // MARK: - Scanning

    private func scan() async {
        isScanning = true
        totalSize = nil
        largestFiles = []
        trashedPaths = []

        let path = folderPath
        let limit = fileLimit
        let result: (total: Int64, files: [Entry]) = await Task.detached(priority: .userInitiated) {
            var files: [Entry] = []
            var total: Int64 = 0
            let root = URL(fileURLWithPath: path)
            if let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            ) {
                var visited = 0
                while let url = enumerator.nextObject() as? URL {
                    visited += 1
                    if visited > 200_000 { break }
                    guard let values = try? url.resourceValues(
                        forKeys: [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileSizeKey]
                    ), values.isRegularFile == true else { continue }
                    let size = Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
                    total += size
                    if size >= 1024 * 1024 {
                        files.append(Entry(path: url.path, size: size))
                    }
                }
            }
            let top = files.sorted { $0.size > $1.size }.prefix(limit).map { $0 }
            return (total, top)
        }.value

        totalSize = result.total
        largestFiles = result.files
        isScanning = false
    }

    private func trash(_ entry: Entry) async {
        let result = await FileOperations.shared.moveFilesToTrash(atPaths: [entry.path])
        if result.errors.isEmpty {
            trashedPaths.insert(entry.path)
            message = "\(entry.name) moved to Trash — recoverable from there."
        } else {
            message = "Couldn't trash \(entry.name): \(result.errors.first?.errorType.rawValue ?? "unknown error")"
        }
    }

    private static func bytes(_ value: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: value, countStyle: .file)
    }
}
