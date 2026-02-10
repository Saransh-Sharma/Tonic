//
//  AccessBroker.swift
//  Tonic
//
//  Security-scoped bookmark lifecycle management.
//

import AppKit
import Foundation

enum AccessBrokerError: LocalizedError {
    case scopeNotFound
    case bookmarkInvalid
    case bookmarkStale
    case blocked(ScopeBlockedReason)

    var errorDescription: String? {
        switch self {
        case .scopeNotFound:
            return "Scope not found."
        case .bookmarkInvalid:
            return "Saved bookmark is invalid."
        case .bookmarkStale:
            return "Saved bookmark is stale and needs re-authorization."
        case .blocked(let reason):
            return reason.userMessage
        }
    }
}

@Observable
final class AccessBroker: @unchecked Sendable {
    static let shared = AccessBroker()

    private let fileManager = FileManager.default
    private let resolver = ScopeResolver.shared

    private(set) var scopes: [AccessScope] = []
    private(set) var scopeStatuses: [UUID: AccessScopeStatus] = [:]
    private(set) var lastErrorMessage: String?

    private let storageFileName = "access_scopes_v1.json"

    private init() {
        loadScopes()
        refreshStatuses()
    }

    var hasAnyScope: Bool {
        !scopes.isEmpty
    }

    var activeScopes: [AccessScope] {
        scopes.filter { status(for: $0) == .active }
    }

    var hasUsableScope: Bool {
        !activeScopes.isEmpty
    }

    var coverageTier: ScopeCoverageTier {
        let roots = Set(activeScopes.map { resolver.canonicalPath($0.rootPath) })
        let home = resolver.canonicalPath(FileManager.default.homeDirectoryForCurrentUser.path)
        if roots.contains("/") || roots.contains("/System/Volumes/Data") {
            return .fullMac
        }
        if roots.contains(home), roots.contains("/Applications") {
            return .standard
        }
        return .minimal
    }

    func addScope(from url: URL, kind: AccessScopeKind? = nil) throws -> AccessScope {
        let normalizedURL = url.standardizedFileURL
        let rootPath = resolver.canonicalPath(normalizedURL.path)

        if let existing = scopes.first(where: { resolver.canonicalPath($0.rootPath) == rootPath }) {
            return existing
        }

        let bookmark = try normalizedURL.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
        let scope = AccessScope(
            displayName: displayName(for: normalizedURL),
            rootPath: rootPath,
            kind: kind ?? inferKind(for: normalizedURL),
            bookmarkData: bookmark
        )
        scopes.append(scope)
        saveScopes()
        refreshStatuses()
        return scope
    }

    func addScopeUsingOpenPanel(
        title: String = "Grant Access",
        message: String = "Choose a folder or volume for Tonic to scan."
    ) -> AccessScope? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.message = message
        panel.prompt = "Grant Access"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = false

        guard panel.runModal() == .OK, let url = panel.url else {
            return nil
        }

        do {
            return try addScope(from: url)
        } catch {
            lastErrorMessage = error.localizedDescription
            return nil
        }
    }

    func addStartupDiskScope() -> AccessScope? {
        addScopeUsingOpenPanel(
            title: "Enable Full Mac Scan",
            message: "Choose your startup disk (usually \"Macintosh HD\") to enable full coverage."
        )
    }

    func removeScope(id: UUID) {
        scopes.removeAll { $0.id == id }
        saveScopes()
        refreshStatuses()
    }

    func reauthorizeScope(id: UUID) -> Bool {
        guard let index = scopes.firstIndex(where: { $0.id == id }) else { return false }
        let old = scopes[index]
        let panel = NSOpenPanel()
        panel.title = "Re-authorize Access"
        panel.message = "Re-authorize access for \(old.displayName)."
        panel.prompt = "Re-authorize"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else {
            return false
        }

        do {
            let bookmark = try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
            scopes[index].bookmarkData = bookmark
            scopes[index].rootPath = resolver.canonicalPath(url.standardizedFileURL.path)
            scopes[index].displayName = displayName(for: url)
            scopes[index].lastVerifiedAt = Date()
            saveScopes()
            refreshStatuses()
            return true
        } catch {
            lastErrorMessage = error.localizedDescription
            return false
        }
    }

    func status(for scope: AccessScope) -> AccessScopeStatus {
        scopeStatuses[scope.id] ?? .invalid
    }

    func scope(forID id: UUID) -> AccessScope? {
        scopes.first(where: { $0.id == id })
    }

    func withAccess<T>(scopeID: UUID, operation: (URL) throws -> T) throws -> T {
        guard let scope = scope(forID: scopeID) else {
            throw AccessBrokerError.scopeNotFound
        }
        return try withAccess(scope: scope, operation: operation)
    }

    func withAccess<T>(scope: AccessScope, operation: (URL) throws -> T) throws -> T {
        var isStale = false
        let resolvedURL: URL
        do {
            resolvedURL = try URL(
                resolvingBookmarkData: scope.bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
        } catch {
            throw AccessBrokerError.bookmarkInvalid
        }

        if isStale {
            throw AccessBrokerError.bookmarkStale
        }

        let didStart = resolvedURL.startAccessingSecurityScopedResource()
        if !didStart, BuildCapabilities.current.requiresScopeAccess {
            throw AccessBrokerError.blocked(.sandboxReadDenied)
        }
        defer {
            if didStart {
                resolvedURL.stopAccessingSecurityScopedResource()
            }
        }

        return try operation(resolvedURL)
    }

    func withAccess<T>(forPath path: String, operation: (URL) throws -> T) throws -> T {
        if !BuildCapabilities.current.requiresScopeAccess {
            return try operation(URL(fileURLWithPath: resolver.canonicalPath(path)))
        }

        let canonicalPath = resolver.canonicalPath(path)
        guard let scope = resolver.bestScope(forPath: canonicalPath, scopes: scopes) else {
            throw AccessBrokerError.blocked(.missingScope)
        }

        let scopeStatus = status(for: scope)
        switch scopeStatus {
        case .staleBookmark:
            throw AccessBrokerError.blocked(.staleBookmark)
        case .disconnected:
            throw AccessBrokerError.blocked(.disconnectedScope)
        case .invalid:
            throw AccessBrokerError.blocked(.sandboxReadDenied)
        case .active:
            break
        }

        let targetURL = URL(fileURLWithPath: canonicalPath)
        return try withAccess(scope: scope) { _ in
            try operation(targetURL)
        }
    }

    func refreshStatuses() {
        var next: [UUID: AccessScopeStatus] = [:]
        for scope in scopes {
            var stale = false
            do {
                let resolvedURL = try URL(
                    resolvingBookmarkData: scope.bookmarkData,
                    options: [.withSecurityScope],
                    relativeTo: nil,
                    bookmarkDataIsStale: &stale
                )
                if stale {
                    next[scope.id] = .staleBookmark
                } else {
                    let didStart = resolvedURL.startAccessingSecurityScopedResource()
                    defer {
                        if didStart {
                            resolvedURL.stopAccessingSecurityScopedResource()
                        }
                    }

                    if !didStart, BuildCapabilities.current.requiresScopeAccess {
                        next[scope.id] = .invalid
                    } else if fileManager.fileExists(atPath: resolvedURL.path) {
                        next[scope.id] = .active
                    } else {
                        next[scope.id] = .disconnected
                    }
                }
            } catch {
                next[scope.id] = .invalid
            }
        }
        scopeStatuses = next
    }

    private func scopesStorageURL() -> URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let tonicDir = appSupport.appendingPathComponent("Tonic", isDirectory: true)
        if !fileManager.fileExists(atPath: tonicDir.path) {
            try? fileManager.createDirectory(at: tonicDir, withIntermediateDirectories: true)
        }
        return tonicDir.appendingPathComponent(storageFileName)
    }

    private func loadScopes() {
        let url = scopesStorageURL()
        guard fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([AccessScope].self, from: data) else {
            scopes = []
            return
        }
        scopes = decoded.map { scope in
            var normalized = scope
            normalized.rootPath = resolver.canonicalPath(scope.rootPath)
            return normalized
        }
    }

    private func saveScopes() {
        let url = scopesStorageURL()
        do {
            let data = try JSONEncoder().encode(scopes)
            try data.write(to: url, options: .atomic)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func displayName(for url: URL) -> String {
        let path = resolver.canonicalPath(url.path)
        if path == "/" {
            return "Startup Disk"
        }
        if path == "/Applications" {
            return "Applications"
        }
        if path == resolver.canonicalPath(fileManager.homeDirectoryForCurrentUser.path) {
            return "Home"
        }
        return fileManager.displayName(atPath: path)
    }

    private func inferKind(for url: URL) -> AccessScopeKind {
        let path = resolver.canonicalPath(url.path)
        if path == "/" { return .startupDisk }
        if path == "/Applications" { return .applications }
        if path == resolver.canonicalPath(fileManager.homeDirectoryForCurrentUser.path) { return .home }
        if path.hasPrefix("/Volumes/") { return .externalVolume }
        return .folder
    }
}
