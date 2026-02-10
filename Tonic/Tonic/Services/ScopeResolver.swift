//
//  ScopeResolver.swift
//  Tonic
//
//  Resolves authorized scopes for file-system paths.
//

import Foundation

final class ScopeResolver {
    static let shared = ScopeResolver()

    private init() {}

    func canonicalPath(_ path: String) -> String {
        let expanded = NSString(string: path).expandingTildeInPath
        let standardized = URL(fileURLWithPath: expanded).standardizedFileURL
        var canonical = standardized.resolvingSymlinksInPath().path
        if canonical.count > 1, canonical.hasSuffix("/") {
            canonical.removeLast()
        }
        return canonical
    }

    func bestScope(forPath path: String, scopes: [AccessScope]) -> AccessScope? {
        let target = canonicalPath(path)
        return scopes
            .filter { scope in
                let root = canonicalPath(scope.rootPath)
                return target == root || target.hasPrefix(root + "/")
            }
            .max { lhs, rhs in
                canonicalPath(lhs.rootPath).count < canonicalPath(rhs.rootPath).count
            }
    }

    func isProtectedByMacOS(_ path: String) -> Bool {
        let canonical = canonicalPath(path)
        let protectedPrefixes = [
            "/System",
            "/private/var/db",
            "/private/var/root",
            "/Library/Apple/System",
            "/usr/lib",
            "/sbin",
        ]
        return protectedPrefixes.contains { prefix in
            let canonicalPrefix = canonicalPath(prefix)
            return canonical == prefix
                || canonical.hasPrefix(prefix + "/")
                || canonical == canonicalPrefix
                || canonical.hasPrefix(canonicalPrefix + "/")
        }
    }
}
