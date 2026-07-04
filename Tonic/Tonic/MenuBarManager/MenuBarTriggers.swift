//
//  MenuBarTriggers.swift
//  Tonic
//
//  Rules that automatically reshape the menu bar based on context — the
//  Bartender "Triggers" equivalent. A trigger fires an action when its
//  condition becomes true, and can revert when the condition clears.
//

import Foundation

public enum TriggerCondition: Codable, Equatable, Sendable {
    case batteryBelow(percent: Int)
    case onBattery
    case charging
    case wifiSSID(String)
    case appRunning(bundleID: String)
    /// Minutes-since-midnight window; `end < start` wraps past midnight.
    /// Empty weekday set means every day (1 = Sunday … 7 = Saturday).
    case timeWindow(startMinute: Int, endMinute: Int, weekdays: Set<Int>)

    public var summary: String {
        switch self {
        case .batteryBelow(let percent): return "Battery below \(percent)%"
        case .onBattery: return "On battery power"
        case .charging: return "Charging"
        case .wifiSSID(let ssid): return "Wi-Fi is \"\(ssid)\""
        case .appRunning(let bundleID): return "\(bundleID) is running"
        case .timeWindow(let start, let end, _):
            return "Between \(Self.clock(start)) and \(Self.clock(end))"
        }
    }

    private static func clock(_ minutes: Int) -> String {
        String(format: "%02d:%02d", (minutes / 60) % 24, minutes % 60)
    }
}

public enum TriggerAction: Codable, Equatable, Sendable {
    case applyPreset(UUID)
    case revealItem(stableKey: String)
    case expand
    case collapse

    public var summary: String {
        switch self {
        case .applyPreset: return "Apply preset"
        case .revealItem(let key): return "Reveal \(key)"
        case .expand: return "Reveal hidden items"
        case .collapse: return "Hide items"
        }
    }
}

public struct MenuBarTrigger: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var isEnabled: Bool
    public var condition: TriggerCondition
    public var action: TriggerAction
    /// When true, the pre-fire layout is restored once the condition clears.
    public var revertsWhenCleared: Bool

    public init(id: UUID = UUID(), name: String, isEnabled: Bool = true,
                condition: TriggerCondition, action: TriggerAction,
                revertsWhenCleared: Bool = false) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.condition = condition
        self.action = action
        self.revertsWhenCleared = revertsWhenCleared
    }
}

@Observable
public final class MenuBarTriggerStore: @unchecked Sendable {
    public static let shared = MenuBarTriggerStore()
    private static let defaultsKey = "tonic.menuBarTriggers"

    public private(set) var triggers: [MenuBarTrigger] {
        didSet {
            persist()
            NotificationCenter.default.post(name: .menuBarTriggersDidChange, object: nil)
        }
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
           let decoded = try? JSONDecoder().decode([MenuBarTrigger].self, from: data) {
            triggers = decoded
        } else {
            triggers = []
        }
    }

    public func add(_ trigger: MenuBarTrigger) { triggers.append(trigger) }

    public func update(_ trigger: MenuBarTrigger) {
        guard let index = triggers.firstIndex(where: { $0.id == trigger.id }) else { return }
        triggers[index] = trigger
    }

    public func delete(_ trigger: MenuBarTrigger) {
        triggers.removeAll { $0.id == trigger.id }
    }

    public func setEnabled(_ enabled: Bool, for trigger: MenuBarTrigger) {
        guard let index = triggers.firstIndex(where: { $0.id == trigger.id }) else { return }
        triggers[index].isEnabled = enabled
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(triggers) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }
}

extension Notification.Name {
    public static let menuBarTriggersDidChange = Notification.Name("tonic.menuBarTriggersDidChange")
}
