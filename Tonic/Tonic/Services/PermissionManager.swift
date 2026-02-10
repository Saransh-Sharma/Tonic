//
//  PermissionManager.swift
//  Tonic
//
//  System permissions manager for Full Disk Access and other permissions
//  Task ID: fn-1.11
//

import Foundation
import Security
import ApplicationServices
import AppKit
import UserNotifications

/// Permission status
public enum PermissionStatus: String, Sendable {
    case notDetermined = "Not Determined"
    case denied = "Denied"
    case authorized = "Authorized"
}

/// System permissions that Tonic needs
public enum TonicPermission: String, CaseIterable, Sendable {
    case fullDiskAccess = "Full Disk Access"
    case accessibility = "Accessibility"
    case notifications = "Notifications"

    public var id: String { rawValue }

    var icon: String {
        switch self {
        case .fullDiskAccess: return "externaldrive.fill"
        case .accessibility: return "hand.raised.fill"
        case .notifications: return "bell.fill"
        }
    }

    var description: String {
        switch self {
        case .fullDiskAccess:
            if BuildCapabilities.current.requiresScopeAccess {
                return "Grant authorized locations for scanning and cleanup"
            }
            return "Required to scan all files on your Mac"
        case .accessibility:
            return "Required for enhanced system monitoring"
        case .notifications:
            return "Get notified about scan results and updates"
        }
    }
}

/// Permission manager
@MainActor
@Observable
public final class PermissionManager: @unchecked Sendable {

    public static let shared = PermissionManager()

    private let fileManager = FileManager.default

    public private(set) var permissionStatuses: [TonicPermission: PermissionStatus] = [:]
    public private(set) var isCheckingPermissions = false

    private init() {
        // Initialize with default statuses
        for permission in TonicPermission.allCases {
            permissionStatuses[permission] = .notDetermined
        }
    }

    // MARK: - Permission Checking

    public func checkAllPermissions() async {
        isCheckingPermissions = true
        defer { isCheckingPermissions = false }

        for permission in TonicPermission.allCases {
            let status = await checkPermission(permission)
            permissionStatuses[permission] = status
        }
    }

    public func checkPermission(_ permission: TonicPermission) async -> PermissionStatus {
        switch permission {
        case .fullDiskAccess:
            return await checkFullDiskAccess()
        case .accessibility:
            return checkAccessibility()
        case .notifications:
            return await checkNotificationPermission()
        }
    }

    // MARK: - Full Disk Access

    private func checkFullDiskAccess() async -> PermissionStatus {
        if BuildCapabilities.current.requiresScopeAccess {
            AccessBroker.shared.refreshStatuses()
            return AccessBroker.shared.hasUsableScope ? .authorized : .notDetermined
        }

        // Try to access a protected location
        let testPaths = [
            "/Library/Application Support",
            fileManager.homeDirectoryForCurrentUser.path + "/Library/Messages",
            fileManager.homeDirectoryForCurrentUser.path + "/Library/Mail"
        ]

        for path in testPaths {
            if fileManager.fileExists(atPath: path) {
                // Try to read directory contents
                if let _ = try? fileManager.contentsOfDirectory(atPath: path) {
                    return .authorized
                }
            }
        }

        return .denied
    }

    public func requestFullDiskAccess() -> Bool {
        if BuildCapabilities.current.requiresScopeAccess {
            return AccessBroker.shared.addScopeUsingOpenPanel(
                title: "Grant Access Scope",
                message: "Choose a folder or disk to authorize for scanning."
            ) != nil
        }

        // Open System Settings to Privacy & Security > Full Disk Access (macOS 14+)
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!

        if NSWorkspace.shared.open(url) {
            return true
        }
        return false
    }

    // MARK: - Accessibility

    private func checkAccessibility() -> PermissionStatus {
        // Check without prompting
        let trusted = AXIsProcessTrusted()
        return trusted ? .authorized : .denied
    }

    public func requestAccessibility() -> Bool {
        // Open System Settings directly
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        return NSWorkspace.shared.open(url)
    }

    // MARK: - Notifications

    private func checkNotificationPermission() async -> PermissionStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional:
            return .authorized
        case .denied:
            return .denied
        default:
            return .notDetermined
        }
    }

    // MARK: - Permission Summary

    public var allPermissionsGranted: Bool {
        permissionStatuses.allSatisfy { $0.value == .authorized }
    }

    public var criticalPermissionsGranted: Bool {
        guard let fdaStatus = permissionStatuses[.fullDiskAccess] else { return false }
        return fdaStatus == .authorized
    }

    public var hasFullDiskAccess: Bool {
        permissionStatuses[.fullDiskAccess] == .authorized
    }

    // MARK: - Permission Gating for Features

    /// Returns whether a feature can be used based on permissions
    public func canUseFeature(_ feature: Feature) -> (allowed: Bool, reason: String?) {
        if BuildCapabilities.current.requiresScopeAccess {
            switch feature {
            case .diskScan, .appManager, .smartScan:
                if !hasFullDiskAccess {
                    return (false, "Grant at least one authorized location to continue.")
                }
                return (true, nil)
            case .basicScan:
                return (true, nil)
            }
        }

        switch feature {
        case .diskScan, .appManager:
            if !hasFullDiskAccess {
                return (false, "Full Disk Access is required to scan all files and apps")
            }
            return (true, nil)

        case .smartScan:
            if !hasFullDiskAccess {
                return (false, "Full Disk Access is required for comprehensive scanning")
            }
            return (true, nil)

        case .basicScan:
            return (true, nil)
        }
    }

    public enum Feature {
        case diskScan
        case appManager
        case smartScan
        case basicScan
    }
}

/// Permission gating result
public struct PermissionGate: Sendable {
    let allowed: Bool
    let missingPermissions: [TonicPermission]
    let message: String

    static let allowed = PermissionGate(allowed: true, missingPermissions: [], message: "")
}
