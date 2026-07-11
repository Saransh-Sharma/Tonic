//
//  DiskMapScanner.swift
//  Tonic
//
//  Builds the bounded directory tree behind the sunburst disk map: one deep
//  enumeration pass aggregates allocated sizes into a path trie limited to a
//  few levels below the root; deeper content rolls up into its ancestor.
//  Cancelable, with live progress. Read-only — the map never deletes.
//

import Foundation

/// A frozen node of the disk map tree, children sorted largest-first.
struct DiskMapNode: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let path: String
    let size: Int64
    let children: [DiskMapNode]
    /// True for the synthetic "Other" bucket that absorbs long tails.
    let isAggregate: Bool

    init(id: UUID = UUID(), name: String, path: String, size: Int64,
         children: [DiskMapNode] = [], isAggregate: Bool = false) {
        self.id = id
        self.name = name
        self.path = path
        self.size = size
        self.children = children
        self.isAggregate = isAggregate
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

@Observable
@MainActor
final class DiskMapScanner {
    struct Progress: Equatable {
        var files: Int = 0
        var bytes: Int64 = 0
    }

    private(set) var isScanning = false
    private(set) var progress = Progress()
    private(set) var root: DiskMapNode?
    private(set) var errorMessage: String?

    /// Levels of the trie kept below the scan root; deeper sizes roll up.
    nonisolated static let maxDepth = 3
    /// Children kept per node, largest first; the rest merge into "Other".
    nonisolated static let maxChildren = 14

    private var task: Task<Void, Never>?
    private var workerTask: Task<ScanOutcome, Never>?

    func scan(path: String) {
        cancel()
        errorMessage = nil
        root = nil
        progress = Progress()

        let access = ScopedFileSystem.shared.accessState(forPath: path, requiresWrite: false)
        guard access.state == .ready else {
            errorMessage = BuildCapabilities.current.requiresScopeAccess
                ? "Authorize this location in Settings › Access to map it."
                : "Full Disk Access is required to map \(path)."
            return
        }

        isScanning = true
        let onProgress: @Sendable (Int, Int64) -> Void = { [weak self] files, bytes in
            Task { @MainActor in
                self?.progress = Progress(files: files, bytes: bytes)
            }
        }
        let worker = Task.detached(priority: .userInitiated) {
            Self.buildTree(rootPath: path, onProgress: onProgress)
        }
        workerTask = worker
        task = Task { [weak self] in
            let result = await worker.value
            guard let self, !Task.isCancelled else { return }
            self.isScanning = false
            switch result {
            case .success(let node): self.root = node
            case .cancelled: break
            case .failed(let message): self.errorMessage = message
            }
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        workerTask?.cancel()
        workerTask = nil
        isScanning = false
    }

    // MARK: - Tree building (off-main)

    private enum ScanOutcome {
        case success(DiskMapNode)
        case cancelled
        case failed(String)
    }

    /// Mutable trie used during the single enumeration pass.
    private final class TrieNode {
        let name: String
        let path: String
        var size: Int64 = 0
        var children: [String: TrieNode] = [:]

        init(name: String, path: String) {
            self.name = name
            self.path = path
        }
    }

    private nonisolated static func buildTree(
        rootPath: String,
        onProgress: @escaping @Sendable (Int, Int64) -> Void
    ) -> ScanOutcome {
        let rootURL = URL(fileURLWithPath: rootPath)
        let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .isDirectoryKey]
        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: keys,
            options: [.producesRelativePathURLs]
        ) else {
            return .failed("Could not read \(rootPath).")
        }

        let root = TrieNode(name: rootURL.lastPathComponent, path: rootPath)
        var files = 0
        var bytes: Int64 = 0

        for case let url as URL in enumerator {
            if files % 512 == 0, Task.isCancelled { return .cancelled }

            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.isDirectory != true else { continue }
            let size = Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
            guard size > 0 else { continue }

            files += 1
            bytes += size
            if files % 2000 == 0 { onProgress(files, bytes) }

            // Aggregate into the first `maxDepth` components below the root.
            let components = url.relativePath.split(separator: "/", omittingEmptySubsequences: true)
            root.size += size
            var node = root
            for component in components.prefix(maxDepth) {
                let name = String(component)
                let child = node.children[name] ?? {
                    let created = TrieNode(name: name, path: node.path + "/" + name)
                    node.children[name] = created
                    return created
                }()
                child.size += size
                node = child
            }
        }

        onProgress(files, bytes)
        guard root.size > 0 else { return .failed("Nothing to map at \(rootPath).") }
        return .success(freeze(root))
    }

    /// Sort children largest-first, keep the top `maxChildren`, and merge the
    /// tail into a single non-navigable "Other" bucket.
    private nonisolated static func freeze(_ node: TrieNode) -> DiskMapNode {
        let sorted = node.children.values.sorted { $0.size > $1.size }
        var children = sorted.prefix(maxChildren).map(freeze)
        let tail = sorted.dropFirst(maxChildren)
        if !tail.isEmpty {
            let tailSize = tail.reduce(Int64(0)) { $0 + $1.size }
            children.append(DiskMapNode(name: "Other (\(tail.count) items)",
                                        path: node.path, size: tailSize,
                                        isAggregate: true))
        }
        return DiskMapNode(name: node.name, path: node.path, size: node.size, children: children)
    }
}
