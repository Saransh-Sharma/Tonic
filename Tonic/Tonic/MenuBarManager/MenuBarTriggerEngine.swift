//
//  MenuBarTriggerEngine.swift
//  Tonic
//
//  Evaluates triggers against a snapshot of the environment and drives the
//  manager. Evaluation is pure (TriggerEvaluator) so it is unit-testable; the
//  engine is the adapter that gathers the snapshot and applies actions.
//

import AppKit
import Combine

/// A pure snapshot of everything triggers evaluate against.
public struct TriggerEnvironment: Sendable, Equatable {
    public var batteryPercent: Int?
    public var isCharging: Bool
    public var onBattery: Bool
    public var ssid: String?
    public var runningBundleIDs: Set<String>
    public var now: Date

    public init(batteryPercent: Int? = nil, isCharging: Bool = false, onBattery: Bool = false,
                ssid: String? = nil, runningBundleIDs: Set<String> = [], now: Date = Date()) {
        self.batteryPercent = batteryPercent
        self.isCharging = isCharging
        self.onBattery = onBattery
        self.ssid = ssid
        self.runningBundleIDs = runningBundleIDs
        self.now = now
    }
}

/// Pure trigger logic — no side effects, fully testable.
public enum TriggerEvaluator {
    public static func isSatisfied(_ condition: TriggerCondition,
                                   in env: TriggerEnvironment,
                                   calendar: Calendar = .current) -> Bool {
        switch condition {
        case .batteryBelow(let percent):
            guard let level = env.batteryPercent else { return false }
            return level < percent
        case .onBattery:
            return env.onBattery
        case .charging:
            return env.isCharging
        case .wifiSSID(let ssid):
            return env.ssid == ssid
        case .appRunning(let bundleID):
            return env.runningBundleIDs.contains(bundleID)
        case .timeWindow(let start, let end, let weekdays):
            return timeWindowSatisfied(start: start, end: end, weekdays: weekdays,
                                       now: env.now, calendar: calendar)
        }
    }

    static func timeWindowSatisfied(start: Int, end: Int, weekdays: Set<Int>,
                                    now: Date, calendar: Calendar) -> Bool {
        let components = calendar.dateComponents([.hour, .minute, .weekday], from: now)
        let minutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        let weekday = components.weekday ?? 1

        let dayMatches = weekdays.isEmpty || weekdays.contains(weekday)
        guard dayMatches else { return false }

        if start <= end {
            return minutes >= start && minutes < end
        }
        // Wraps past midnight (e.g. 22:00 → 06:00).
        return minutes >= start || minutes < end
    }

    /// Which trigger ids just became satisfied vs. just cleared.
    public static func transitions(previous: Set<UUID>,
                                   current: Set<UUID>) -> (fired: Set<UUID>, cleared: Set<UUID>) {
        (fired: current.subtracting(previous), cleared: previous.subtracting(current))
    }
}

#if !TONIC_STORE

/// Adapter: samples the environment, evaluates enabled triggers on an interval
/// and on app launch/quit, and applies actions edge-triggered.
@MainActor
final class MenuBarTriggerEngine {

    private var timer: Timer?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var satisfied: Set<UUID> = []
    /// Layout captured just before a reverting trigger fired, keyed by trigger id.
    private var revertSnapshots: [UUID: [String: MenuBarSection]] = [:]
    private var lastActionAt: [UUID: Date] = [:]

    func start() {
        stop()
        // 60s serves both time windows and battery/ssid polling.
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            Task { @MainActor [weak self] in self?.evaluate() }
        }
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification,
                     NSWorkspace.didTerminateApplicationNotification] {
            workspaceObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { _ in
                Task { @MainActor [weak self] in self?.evaluate() }
            })
        }
        evaluate()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers.forEach { center.removeObserver($0) }
        workspaceObservers.removeAll()
    }

    private func currentEnvironment() -> TriggerEnvironment {
        let battery = WidgetDataManager.shared.batteryData
        let network = WidgetDataManager.shared.networkData
        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        return TriggerEnvironment(
            batteryPercent: battery.isPresent ? Int(battery.chargePercentage) : nil,
            isCharging: battery.isCharging,
            onBattery: battery.isPresent && !battery.isCharging,
            ssid: network.wifiDetails?.ssid ?? network.ssid,
            runningBundleIDs: running,
            now: Date()
        )
    }

    private func evaluate() {
        let manager = MenuBarManager.shared
        // Don't perturb the bar mid-move; the next tick will catch up.
        guard !manager.isPerformingMove else { return }

        let triggers = MenuBarTriggerStore.shared.triggers.filter(\.isEnabled)
        let env = currentEnvironment()

        var nowSatisfied: Set<UUID> = []
        for trigger in triggers where TriggerEvaluator.isSatisfied(trigger.condition, in: env) {
            nowSatisfied.insert(trigger.id)
        }

        let (fired, cleared) = TriggerEvaluator.transitions(previous: satisfied, current: nowSatisfied)
        satisfied = nowSatisfied

        for id in fired {
            guard let trigger = triggers.first(where: { $0.id == id }) else { continue }
            // Debounce repeated fires within 5s.
            if let last = lastActionAt[id], Date().timeIntervalSince(last) < 5 { continue }
            lastActionAt[id] = Date()
            apply(trigger, manager: manager)
        }
        for id in cleared {
            revert(triggerID: id, manager: manager)
        }
    }

    private func apply(_ trigger: MenuBarTrigger, manager: MenuBarManager) {
        if trigger.revertsWhenCleared {
            revertSnapshots[trigger.id] = currentLayout(manager)
        }
        Task { @MainActor in
            switch trigger.action {
            case .applyPreset(let presetID):
                guard let preset = MenuBarPresetStore.shared.presets.first(where: { $0.id == presetID }) else { return }
                await manager.applyLayout(preset.layout)
            case .revealItem(let key):
                if manager.items.contains(where: { $0.stableKey == key }) {
                    manager.expand(showAlwaysHidden: true)
                }
            case .expand:
                manager.expand()
            case .collapse:
                manager.collapse()
            }
        }
    }

    private func revert(triggerID: UUID, manager: MenuBarManager) {
        guard let snapshot = revertSnapshots.removeValue(forKey: triggerID) else { return }
        Task { @MainActor in
            await manager.applyLayout(snapshot)
        }
    }

    private func currentLayout(_ manager: MenuBarManager) -> [String: MenuBarSection] {
        var layout: [String: MenuBarSection] = [:]
        for item in manager.items where !item.isSystemControlled {
            if let section = item.section { layout[item.stableKey] = section }
        }
        return layout
    }
}

#endif
