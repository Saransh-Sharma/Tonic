//
//  SettingsSection.swift
//  Tonic
//
//  Settings section model for the consolidated Settings IA. Extracted from the legacy
//  PreferencesView.swift so it survives the presentation-layer rewrite and can back
//  the `openSettingsSection` deep-links from the new shell.
//

import Foundation

enum SettingsSection: String, CaseIterable, Identifiable {
    case general = "General"
    case modules = "Modules"
    case topShelf = "Top Shelf"
    case shortcuts = "Shortcuts"
    case maintenance = "Automations"
    case notifications = "Notifications"
    case permissions = "Access"
    case licensing = "Licensing"
    case updates = "Updates"
    case advanced = "Advanced"
    case support = "Support"
    case about = "About"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .licensing: "Edition"
        default: rawValue
        }
    }

    var icon: String {
        switch self {
        case .general: return "gearshape.fill"
        case .modules: return "square.grid.2x2.fill"
        case .topShelf: return "rectangle.topthird.inset.filled"
        case .shortcuts: return "command"
        case .maintenance: return "clock.arrow.2.circlepath"
        case .notifications: return "bell.fill"
        case .permissions: return "hand.raised.fill"
        case .licensing: return "checkmark.seal.fill"
        case .updates: return "arrow.down.circle.fill"
        case .advanced: return "slider.horizontal.3"
        case .support: return "lifepreserver.fill"
        case .about: return "info.circle.fill"
        }
    }

    var description: String {
        switch self {
        case .general: return "Behavior, units, and data"
        case .modules: return "Widget configuration"
        case .topShelf: return "Context modules and ambient consent"
        case .shortcuts: return "Keyboard control"
        case .maintenance: return "Scheduled care"
        case .notifications: return "Alerts and digests"
        case .permissions: return BuildCapabilities.current.requiresScopeAccess ? "Access & permissions" : "System access"
        case .licensing: return "Distribution and capabilities"
        case .updates: return "Software updates"
        case .advanced: return "Expert controls"
        case .support: return "Reviewed local diagnostics"
        case .about: return "App information"
        }
    }
}
