//
//  BuildFlavor.swift
//  Tonic
//
//  Compile-time distribution capabilities.
//

import Foundation

enum BuildFlavor: String, Sendable {
    case direct
    case store

    static var current: BuildFlavor {
        #if TONIC_STORE
        return .store
        #else
        return .direct
        #endif
    }

    var requiresScopeAccess: Bool {
        self == .store
    }
}

struct BuildCapabilities: Sendable {
    let usesStoreUpdates: Bool
    let supportsSparkle: Bool
    let allowsPrivilegedFlows: Bool
    let requiresScopeAccess: Bool

    static var current: BuildCapabilities {
        switch BuildFlavor.current {
        case .store:
            return BuildCapabilities(
                usesStoreUpdates: true,
                supportsSparkle: false,
                allowsPrivilegedFlows: false,
                requiresScopeAccess: true
            )
        case .direct:
            return BuildCapabilities(
                usesStoreUpdates: false,
                supportsSparkle: true,
                allowsPrivilegedFlows: true,
                requiresScopeAccess: false
            )
        }
    }
}
