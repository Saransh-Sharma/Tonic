//
//  BackgroundActivityItem.swift
//  Tonic
//
//  Model for app background activity permissions
//

import Foundation
import AppKit

/// An app's background activity permissions
public struct BackgroundActivityItem: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let appName: String
    public let bundleIdentifier: String
    public let path: URL
    public let isEnabled: Bool
    public let permissionCount: Int
    public let permissions: [BackgroundPermission]

    public init(
        id: UUID = UUID(),
        appName: String,
        bundleIdentifier: String,
        path: URL,
        isEnabled: Bool = true,
        permissionCount: Int = 0,
        permissions: [BackgroundPermission] = []
    ) {
        self.id = id
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.path = path
        self.isEnabled = isEnabled
        self.permissionCount = permissionCount
        self.permissions = permissions
    }

    /// Get the app icon
    public var icon: NSImage? {
        NSWorkspace.shared.icon(forFile: path.path)
    }
}

/// Specific background permission types
public struct BackgroundPermission: Codable, Hashable, Sendable {
    public let type: PermissionType
    public let isEnabled: Bool
    public let description: String

    public enum PermissionType: String, Codable, Sendable {
        case backgroundRefresh = "Background Refresh"
        case location = "Location"
        case notifications = "Notifications"
        case audio = "Audio"
        case bluetooth = "Bluetooth"
        case networking = "Networking"
        case fileAccess = "File Access"
        case screenRecording = "Screen Recording"
        case accessibility = "Accessibility"
        case fullDiskAccess = "Full Disk Access"
        case other = "Other"
    }

    public init(type: PermissionType, isEnabled: Bool, description: String = "") {
        self.type = type
        self.isEnabled = isEnabled
        self.description = description
    }
}
