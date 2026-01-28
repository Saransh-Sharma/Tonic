//
//  LoginItem.swift
//  Tonic
//
//  Model for macOS login items (user-facing apps that launch at login)
//

import Foundation
import AppKit

/// A login item that launches automatically when the user logs in
public struct LoginItem: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let name: String
    public let path: URL
    public let bundleIdentifier: String
    public let isHidden: Bool
    public let itemType: LoginItemType
    public let isEnabled: Bool

    public enum LoginItemType: String, Codable, Sendable {
        case application = "Application"
        case file = "File"
        case service = "Service"
        case unknown = "Unknown"
    }

    public init(
        id: UUID = UUID(),
        name: String,
        path: URL,
        bundleIdentifier: String,
        isHidden: Bool = false,
        itemType: LoginItemType = .application,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.bundleIdentifier = bundleIdentifier
        self.isHidden = isHidden
        self.itemType = itemType
        self.isEnabled = isEnabled
    }

    /// Check if this login item is an app bundle
    public var isApp: Bool {
        itemType == .application && path.pathExtension == "app"
    }

    /// Get the app icon if available
    public var icon: NSImage? {
        NSWorkspace.shared.icon(forFile: path.path)
    }
}

/// A launch agent or daemon (background service)
public struct LaunchService: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let name: String
    public let path: URL
    public let bundleIdentifier: String
    public let serviceType: LaunchServiceType
    public let isEnabled: Bool
    public let runAtLoad: Bool

    public enum LaunchServiceType: String, Codable, Sendable {
        case agent = "LaunchAgent"
        case daemon = "LaunchDaemon"
    }

    public init(
        id: UUID = UUID(),
        name: String,
        path: URL,
        bundleIdentifier: String,
        serviceType: LaunchServiceType,
        isEnabled: Bool = true,
        runAtLoad: Bool = false
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.bundleIdentifier = bundleIdentifier
        self.serviceType = serviceType
        self.isEnabled = isEnabled
        self.runAtLoad = runAtLoad
    }

    /// Get the display label
    public var label: String {
        // The label is typically the filename without .plist extension
        path.deletingPathExtension().lastPathComponent
    }

    /// Get the associated app if this service belongs to one
    public var associatedApp: URL? {
        // Try to find the parent app
        let pathString = path.path

        // Check common patterns
        if pathString.contains("/Contents/Library/LaunchAgents/") {
            // Extract app path
            if let contentsIndex = pathString.range(of: "/Contents/", options: .backwards)?.lowerBound {
                let appPath = String(pathString[..<contentsIndex]) + ".app"
                return URL(fileURLWithPath: appPath)
            }
        }

        return nil
    }
}
