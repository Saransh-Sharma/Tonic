//
//  ScopedFileSystem.swift
//  Tonic
//
//  Scope-aware file system facade for Store Edition.
//

import Foundation

enum ScopedFileSystemError: LocalizedError {
    case accessBlocked(path: String, reason: ScopeBlockedReason)

    var errorDescription: String? {
        switch self {
        case .accessBlocked(_, let reason):
            return reason.userMessage
        }
    }
}

struct ScopedPathFilterResult: Sendable {
    let authorizedPaths: [String]
    let blocked: [String: ScopeBlockedReason]
}

final class ScopedFileSystem {
    static let shared = ScopedFileSystem()

    private let fileManager = FileManager.default
    private let broker = AccessBroker.shared
    private let resolver = ScopeResolver.shared

    private init() {}

    func accessState(forPath path: String, requiresWrite: Bool = false) -> ScopeAccessEvaluation {
        if !BuildCapabilities.current.requiresScopeAccess {
            return ScopeAccessEvaluation(state: .ready, reason: nil, scope: nil)
        }

        let canonical = resolver.canonicalPath(path)
        if resolver.isProtectedByMacOS(canonical) {
            return ScopeAccessEvaluation(state: .limited, reason: .macOSProtected, scope: nil)
        }

        guard let scope = resolver.bestScope(forPath: canonical, scopes: broker.scopes) else {
            return ScopeAccessEvaluation(state: .needsAccess, reason: .missingScope, scope: nil)
        }

        let status = broker.status(for: scope)
        switch status {
        case .active:
            return ScopeAccessEvaluation(state: .ready, reason: nil, scope: scope)
        case .staleBookmark:
            return ScopeAccessEvaluation(state: .needsAccess, reason: .staleBookmark, scope: scope)
        case .disconnected:
            return ScopeAccessEvaluation(state: .needsAccess, reason: .disconnectedScope, scope: scope)
        case .invalid:
            return ScopeAccessEvaluation(state: .needsAccess, reason: .staleBookmark, scope: scope)
        }
    }

    func accessState(forPaths paths: [String], requiresWrite: Bool = false) -> ScopeCoverageSummary {
        if paths.isEmpty {
            return ScopeCoverageSummary(state: .ready, coveredPaths: [], blockedPaths: [:])
        }

        var covered: [String] = []
        var blocked: [String: ScopeBlockedReason] = [:]

        for path in paths {
            let evaluation = accessState(forPath: path, requiresWrite: requiresWrite)
            if evaluation.state == .ready {
                covered.append(path)
            } else if let reason = evaluation.reason {
                blocked[path] = reason
            } else {
                blocked[path] = requiresWrite ? .sandboxWriteDenied : .sandboxReadDenied
            }
        }

        let state: ScopeAccessState
        if covered.isEmpty {
            if blocked.values.contains(.macOSProtected) {
                state = .limited
            } else {
                state = .needsAccess
            }
        } else if blocked.isEmpty {
            state = .ready
        } else {
            state = .limited
        }

        return ScopeCoverageSummary(state: state, coveredPaths: covered, blockedPaths: blocked)
    }

    func filterAuthorizedPaths(_ paths: [String], requiresWrite: Bool = false) -> ScopedPathFilterResult {
        let coverage = accessState(forPaths: paths, requiresWrite: requiresWrite)
        return ScopedPathFilterResult(authorizedPaths: coverage.coveredPaths, blocked: coverage.blockedPaths)
    }

    func canRead(path: String) -> Bool {
        accessState(forPath: path, requiresWrite: false).state == .ready
    }

    func canWrite(path: String) -> Bool {
        accessState(forPath: path, requiresWrite: true).state == .ready
    }

    func fileExists(atPath path: String) -> Bool {
        if !BuildCapabilities.current.requiresScopeAccess {
            return fileManager.fileExists(atPath: path)
        }
        guard canRead(path: path) else { return false }
        return (try? withReadAccess(path: path) { fileManager.fileExists(atPath: path) }) ?? false
    }

    func contentsOfDirectory(atPath path: String) throws -> [String] {
        try withReadAccess(path: path) {
            try fileManager.contentsOfDirectory(atPath: path)
        }
    }

    func contentsOfDirectory(
        atPath path: String,
        includingPropertiesForKeys keys: [URLResourceKey]? = nil,
        options: FileManager.DirectoryEnumerationOptions = []
    ) throws -> [URL] {
        try withReadAccess(path: path) {
            try fileManager.contentsOfDirectory(
                at: URL(fileURLWithPath: path),
                includingPropertiesForKeys: keys,
                options: options
            )
        }
    }

    func enumerateDirectory(
        atPath path: String,
        includingPropertiesForKeys keys: [URLResourceKey]? = nil,
        options: FileManager.DirectoryEnumerationOptions = [],
        using body: (URL) throws -> Void
    ) throws {
        try withReadAccess(path: path) {
            guard let enumerator = fileManager.enumerator(
                at: URL(fileURLWithPath: path),
                includingPropertiesForKeys: keys,
                options: options
            ) else {
                return
            }
            while let next = enumerator.nextObject() as? URL {
                try body(next)
            }
        }
    }

    func attributesOfItem(atPath path: String) throws -> [FileAttributeKey: Any] {
        try withReadAccess(path: path) {
            try fileManager.attributesOfItem(atPath: path)
        }
    }

    func resourceValues(for url: URL, keys: Set<URLResourceKey>) throws -> URLResourceValues {
        try withReadAccess(path: url.path) {
            try url.resourceValues(forKeys: keys)
        }
    }

    func resourceValues(atPath path: String, keys: Set<URLResourceKey>) throws -> URLResourceValues {
        let url = URL(fileURLWithPath: path)
        return try withReadAccess(path: path) {
            try url.resourceValues(forKeys: keys)
        }
    }

    func removeItem(atPath path: String) throws {
        try withWriteAccess(path: path) {
            try fileManager.removeItem(atPath: path)
        }
    }

    func trashItem(at path: String, resultingItemURL: inout NSURL?) throws {
        try withWriteAccess(path: path) {
            try fileManager.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: &resultingItemURL)
        }
    }

    func withReadAccess<T>(path: String, operation: () throws -> T) throws -> T {
        try withAccess(path: path, requiresWrite: false, operation: operation)
    }

    func withWriteAccess<T>(path: String, operation: () throws -> T) throws -> T {
        try withAccess(path: path, requiresWrite: true, operation: operation)
    }

    func blockedReason(forPath path: String, requiresWrite: Bool = false) -> ScopeBlockedReason? {
        accessState(forPath: path, requiresWrite: requiresWrite).reason
    }

    func blockedReason(for error: Error, path: String, requiresWrite: Bool) -> ScopeBlockedReason? {
        if let scopedError = error as? ScopedFileSystemError {
            switch scopedError {
            case .accessBlocked(_, let reason):
                return reason
            }
        }
        if let brokerError = error as? AccessBrokerError {
            switch brokerError {
            case .blocked(let reason):
                return reason
            case .bookmarkStale:
                return .staleBookmark
            case .scopeNotFound:
                return .missingScope
            case .bookmarkInvalid:
                return requiresWrite ? .sandboxWriteDenied : .sandboxReadDenied
            }
        }
        return blockedReason(forPath: path, requiresWrite: requiresWrite)
    }

    private func withAccess<T>(path: String, requiresWrite: Bool, operation: () throws -> T) throws -> T {
        let evaluation = accessState(forPath: path, requiresWrite: requiresWrite)
        guard evaluation.state == .ready else {
            throw ScopedFileSystemError.accessBlocked(path: path, reason: evaluation.reason ?? (requiresWrite ? .sandboxWriteDenied : .sandboxReadDenied))
        }

        if !BuildCapabilities.current.requiresScopeAccess {
            return try operation()
        }

        if let scope = evaluation.scope {
            return try broker.withAccess(scope: scope) { _ in
                try operation()
            }
        }

        return try operation()
    }
}
