//
//  TonicProductArchitecture.swift
//  Tonic
//
//  Typed product vocabulary shared by navigation, commands, permissions,
//  edition gating, automation, and action history.
//

import Foundation

enum TonicHub: String, CaseIterable, Identifiable, Codable, Sendable {
    case home
    case care
    case organize
    case monitor
    case automate

    var id: String { rawValue }

    var title: String { rawValue.capitalized }

    var symbol: String {
        switch self {
        case .home: "house"
        case .care: "cross.case"
        case .organize: "rectangle.3.group"
        case .monitor: "waveform.path.ecg"
        case .automate: "bolt.badge.clock"
        }
    }
}

enum TonicToolID: String, CaseIterable, Identifiable, Codable, Sendable {
    case smartCare
    case storage
    case apps
    case windows
    case menuBar
    case widgets
    case systemMonitor
    case automations
    case actionHistory

    var id: String { rawValue }

    var title: String {
        switch self {
        case .smartCare: "Smart Care"
        case .storage: "Storage"
        case .apps: "Apps"
        case .windows: "Windows"
        case .menuBar: "Menu Bar"
        case .widgets: "Widgets"
        case .systemMonitor: "System Monitor"
        case .automations: "Automations"
        case .actionHistory: "Action History"
        }
    }

    var symbol: String {
        switch self {
        case .smartCare: "wand.and.stars"
        case .storage: "internaldrive"
        case .apps: "square.grid.3x3"
        case .windows: "rectangle.split.3x1"
        case .menuBar: "menubar.rectangle"
        case .widgets: "rectangle.grid.2x2"
        case .systemMonitor: "chart.xyaxis.line"
        case .automations: "point.3.connected.trianglepath.dotted"
        case .actionHistory: "clock.arrow.circlepath"
        }
    }

    var hub: TonicHub {
        switch self {
        case .smartCare, .storage, .apps: .care
        case .windows, .menuBar: .organize
        case .widgets, .systemMonitor: .monitor
        case .automations: .automate
        case .actionHistory: .home
        }
    }

    var aliases: [String] {
        switch self {
        case .smartCare: ["clean", "scan", "junk", "maintenance"]
        case .storage: ["disk", "files", "space", "what grew"]
        case .apps: ["uninstall", "updates", "startup", "background"]
        case .windows: ["snap", "tile", "arrange", "workspace"]
        case .menuBar: ["hide icons", "bartender", "notch", "preset"]
        case .widgets: ["oneview", "status item", "menu widget"]
        case .systemMonitor: ["cpu", "memory", "network", "battery", "process"]
        case .automations: ["workflow", "trigger", "schedule", "focus"]
        case .actionHistory: ["receipt", "undo", "recent changes"]
        }
    }
}

enum TonicRoute: Hashable, Sendable {
    case hub(TonicHub)
    case tool(TonicToolID)
    case settings

    var hub: TonicHub? {
        switch self {
        case .hub(let hub): hub
        case .tool(let tool): tool.hub
        case .settings: nil
        }
    }
}

enum ToolPresentationState: String, Codable, Sendable {
    case ready
    case working
    case success
    case partial
    case empty
    case blocked
    case unsupported
    case failed
}

public enum DistributionEdition: String, Codable, Sendable {
    case store
    case direct

    public static var current: DistributionEdition {
        BuildFlavor.current == .store ? .store : .direct
    }
}

enum CapabilityID: String, CaseIterable, Codable, Sendable {
    case windowManagement
    case standardMenuBarControl
    case advancedMenuBarControl
    case liveMonitoring
    case scopedCare
    case unrestrictedCare
    case privilegedMaintenance
    case directUpdates
}

enum PermissionRequirement: String, Codable, Sendable {
    case accessibility
    case fullDiskAccess
    case authorizedFolder
    case notifications
    case location
}

enum CapabilityAvailability: Equatable, Sendable {
    case available
    case requiresPermission(PermissionRequirement)
    case editionRestricted(required: DistributionEdition)
    case unsupported(reason: String)

    var isAvailable: Bool {
        if case .available = self { return true }
        return false
    }
}

/// Commercial availability is intentionally independent from edition and
/// permission capabilities. Wave 5 ships as a fully unlocked product; the
/// dormant commerce implementation is compiled only with TONIC_COMMERCE.
public enum FeatureAvailability: Equatable, Sendable {
    case unlocked

    public var isUnlocked: Bool { true }
}

public enum TonicFeatureID: String, CaseIterable, Codable, Sendable {
    case smartCare
    case storageIntelligence
    case appManagement
    case monitoring
    case windowManagement
    case menuBarManagement
    case recoveryCenter
    case topShelf
    case providers
    case automations
}

public struct FeatureAvailabilityAuthority: Sendable {
    public static let current = FeatureAvailabilityAuthority()

    public init() {}

    public func availability(of feature: TonicFeatureID) -> FeatureAvailability {
        .unlocked
    }
}

struct CapabilityRegistry: Sendable {
    let edition: DistributionEdition

    init(edition: DistributionEdition = .current) {
        self.edition = edition
    }

    func availability(of capability: CapabilityID) -> CapabilityAvailability {
        switch capability {
        case .windowManagement:
            return .requiresPermission(.accessibility)
        case .standardMenuBarControl, .liveMonitoring:
            return .available
        case .scopedCare:
            return edition == .store ? .requiresPermission(.authorizedFolder) : .available
        case .advancedMenuBarControl, .unrestrictedCare, .privilegedMaintenance, .directUpdates:
            return edition == .direct ? .available : .editionRestricted(required: .direct)
        }
    }
}

protocol TonicModule: Sendable {
    var toolID: TonicToolID { get }
    var commands: [CommandDescriptor] { get }
    var permissionRequirements: [PermissionRequirement] { get }
}

struct CommandDescriptor: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let route: TonicRoute
    let aliases: [String]
    let windowAction: WindowAction?

    init(
        id: String,
        title: String,
        subtitle: String,
        symbol: String,
        route: TonicRoute,
        aliases: [String],
        windowAction: WindowAction? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.route = route
        self.aliases = aliases
        self.windowAction = windowAction
    }

    static var toolCommands: [CommandDescriptor] {
        TonicToolID.allCases.map { tool in
            CommandDescriptor(
                id: "open.\(tool.rawValue)",
                title: "Open \(tool.title)",
                subtitle: tool.hub.title,
                symbol: tool.symbol,
                route: .tool(tool),
                aliases: tool.aliases
            )
        }
    }

    static var windowCommands: [CommandDescriptor] {
        WindowAction.allCases.map { action in
            CommandDescriptor(
                id: "window.\(action.rawValue)",
                title: "Move focused window to \(action.title)",
                subtitle: "Windows · Restorable",
                symbol: action.symbol,
                route: .tool(.windows),
                aliases: ["snap", "tile", "place window", action.title],
                windowAction: action
            )
        }
    }
}

enum UndoCapability: Codable, Equatable, Sendable {
    case unavailable
    case available(token: String, expiresAt: Date?)
}

enum ActionReceiptStatus: String, Codable, Sendable {
    case success
    case partial
    case failed
    case restored
}

struct ActionReceipt: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let tool: TonicToolID
    let title: String
    let detail: String
    let status: ActionReceiptStatus
    let startedAt: Date
    let completedAt: Date
    let affectedItems: Int
    let impact: String?
    let undo: UndoCapability
    let metadata: [String: String]

    init(
        id: UUID = UUID(),
        tool: TonicToolID,
        title: String,
        detail: String,
        status: ActionReceiptStatus = .success,
        startedAt: Date = Date(),
        completedAt: Date = Date(),
        affectedItems: Int = 1,
        impact: String? = nil,
        undo: UndoCapability = .unavailable,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.tool = tool
        self.title = title
        self.detail = detail
        self.status = status
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.affectedItems = affectedItems
        self.impact = impact
        self.undo = undo
        self.metadata = metadata
    }
}

extension Notification.Name {
    static let navigateToTonicHub = Notification.Name("tonic.navigateToHub")
}
