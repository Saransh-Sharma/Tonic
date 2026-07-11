//
//  AutomationModels.swift
//  Tonic
//
//  Cross-tool automations: a TriggerCondition (shared with the menu bar
//  trigger system) firing an ordered list of actions that span tools — window
//  workspaces, menu bar presets, and safe maintenance. "Presentation mode"
//  becomes one automation instead of three manual steps.
//

import Foundation

/// One step an automation performs. Menu-bar steps require the direct build
/// (advanced menu bar control is edition-restricted); the others work everywhere.
public enum AutomationAction: Codable, Equatable, Sendable {
    case applyWorkspace(UUID)
    case applyMenuBarPreset(UUID)
    case collapseMenuBar
    case expandMenuBar
    case runMaintenance

    public var summary: String {
        switch self {
        case .applyWorkspace: return "Apply window workspace"
        case .applyMenuBarPreset: return "Apply menu bar preset"
        case .collapseMenuBar: return "Hide menu bar items"
        case .expandMenuBar: return "Reveal menu bar items"
        case .runMaintenance: return "Run safe maintenance"
        }
    }

    /// True when the step can run in the current edition.
    public var isAvailable: Bool {
        switch self {
        case .applyMenuBarPreset, .collapseMenuBar, .expandMenuBar:
            #if TONIC_STORE
            return false
            #else
            return true
            #endif
        case .applyWorkspace, .runMaintenance:
            return true
        }
    }
}

public struct Automation: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var symbol: String
    public var isEnabled: Bool
    public var condition: TriggerCondition
    /// Ordered "Do" steps.
    public var actions: [AutomationAction]
    /// When true, the pre-fire window arrangement and menu bar layout are
    /// captured before the actions run and restored once the condition clears.
    public var revertsWhenCleared: Bool

    public init(id: UUID = UUID(), name: String, symbol: String = "sparkles",
                isEnabled: Bool = false, condition: TriggerCondition,
                actions: [AutomationAction], revertsWhenCleared: Bool = true) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.isEnabled = isEnabled
        self.condition = condition
        self.actions = actions
        self.revertsWhenCleared = revertsWhenCleared
    }
}

@Observable
public final class AutomationStore: @unchecked Sendable {
    public static let shared = AutomationStore()
    private static let defaultsKey = "tonic.automations"

    public private(set) var automations: [Automation] {
        didSet { persist() }
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
           let decoded = try? JSONDecoder().decode([Automation].self, from: data) {
            automations = decoded
        } else {
            automations = []
        }
    }

    public func add(_ automation: Automation) { automations.append(automation) }

    public func update(_ automation: Automation) {
        guard let index = automations.firstIndex(where: { $0.id == automation.id }) else { return }
        automations[index] = automation
    }

    public func delete(id: UUID) {
        automations.removeAll { $0.id == id }
    }

    public func setEnabled(_ enabled: Bool, id: UUID) {
        guard let index = automations.firstIndex(where: { $0.id == id }) else { return }
        automations[index].isEnabled = enabled
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(automations) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }
}
