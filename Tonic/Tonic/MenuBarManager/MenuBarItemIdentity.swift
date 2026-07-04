//
//  MenuBarItemIdentity.swift
//  Tonic
//
//  AppKit-backed identity for menu bar items. Lives apart from
//  MenuBarItemModels.swift so the models stay AppKit-free and testable.
//  windowID/PID are session-scoped; presets and triggers key on `stableKey`.
//

import AppKit

public enum MenuBarItemIdentity {
    /// Pure mapping — bundle ID wins, owner name is the fallback.
    public static func stableKey(bundleID: String?, ownerName: String) -> String {
        if let bundleID, !bundleID.isEmpty { return bundleID }
        return ownerName
    }
}

public extension MenuBarItemInfo {
    /// Stable across app relaunches: bundle ID of the owning app, else owner name.
    /// Multi-item apps share one key — layouts treat them as a unit (v1 limitation).
    var stableKey: String {
        MenuBarItemIdentity.stableKey(bundleID: bundleIdentifier, ownerName: ownerName)
    }

    var bundleIdentifier: String? {
        NSRunningApplication(processIdentifier: ownerPID)?.bundleIdentifier
    }

    var displayName: String {
        NSRunningApplication(processIdentifier: ownerPID)?.localizedName ?? ownerName
    }

    var nsImage: NSImage? {
        NSRunningApplication(processIdentifier: ownerPID)?.icon
    }
}
