//
//  AutomationEngine.swift
//  Tonic
//
//  Evaluates automations against the shared TriggerEnvironment and runs their
//  cross-tool actions edge-triggered, with a restore point captured before a
//  reverting automation fires. Every fire and revert records an ActionReceipt.
//

import AppKit
import Foundation

@MainActor
final class AutomationEngine {
    static let shared = AutomationEngine()

    /// Restore point captured just before a reverting automation fired.
    private struct RestorePoint {
        var arrangement: WindowWorkspace?
        #if !TONIC_STORE
        var menuBarLayout: [String: MenuBarSection]?
        #endif
    }

    private var timer: Timer?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var satisfied: Set<UUID> = []
    private var restorePoints: [UUID: RestorePoint] = [:]
    private var lastFireAt: [UUID: Date] = [:]

    private init() {}

    func start() {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            Task { @MainActor in AutomationEngine.shared.evaluate() }
        }
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification,
                     NSWorkspace.didTerminateApplicationNotification] {
            workspaceObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { _ in
                Task { @MainActor in AutomationEngine.shared.evaluate() }
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

    // MARK: - Evaluation

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
        let automations = AutomationStore.shared.automations.filter(\.isEnabled)
        guard !automations.isEmpty else { return }
        let env = currentEnvironment()

        var nowSatisfied: Set<UUID> = []
        for automation in automations
            where TriggerEvaluator.isSatisfied(automation.condition, in: env) {
            nowSatisfied.insert(automation.id)
        }

        let (fired, cleared) = TriggerEvaluator.transitions(previous: satisfied, current: nowSatisfied)
        satisfied = nowSatisfied

        for id in fired {
            guard let automation = automations.first(where: { $0.id == id }) else { continue }
            if let last = lastFireAt[id], Date().timeIntervalSince(last) < 30 { continue }
            lastFireAt[id] = Date()
            run(automation)
        }
        for id in cleared {
            revert(automationID: id)
        }
    }

    // MARK: - Actions

    /// Run an automation's steps now (also the "Run Now" entry point from the UI).
    func run(_ automation: Automation) {
        if automation.revertsWhenCleared {
            restorePoints[automation.id] = captureRestorePoint(for: automation)
        }

        Task { @MainActor in
            var performed: [String] = []
            for action in automation.actions where action.isAvailable {
                switch action {
                case .applyWorkspace(let workspaceID):
                    guard let workspace = WindowWorkspaceStore.shared.workspace(id: workspaceID) else { continue }
                    WindowManagementService.shared.apply(workspace)
                    performed.append("workspace \u{201C}\(workspace.name)\u{201D}")
                case .applyMenuBarPreset(let presetID):
                    #if !TONIC_STORE
                    guard let preset = MenuBarPresetStore.shared.presets.first(where: { $0.id == presetID }) else { continue }
                    await MenuBarManager.shared.applyLayout(preset.layout)
                    performed.append("menu bar preset \u{201C}\(preset.name)\u{201D}")
                    #endif
                case .collapseMenuBar:
                    #if !TONIC_STORE
                    MenuBarManager.shared.collapse()
                    performed.append("hid menu bar items")
                    #endif
                case .expandMenuBar:
                    #if !TONIC_STORE
                    MenuBarManager.shared.expand()
                    performed.append("revealed menu bar items")
                    #endif
                case .runMaintenance:
                    await MaintenanceScheduler.shared.runNow()
                    performed.append("safe maintenance")
                }
            }

            guard !performed.isEmpty else { return }
            ActionReceiptStore.shared.record(ActionReceipt(
                tool: .automations,
                title: "Automation \u{201C}\(automation.name)\u{201D} ran",
                detail: "\(automation.condition.summary) → \(performed.joined(separator: " · "))",
                affectedItems: performed.count,
                impact: "\(performed.count) step\(performed.count == 1 ? "" : "s")"
            ))
        }
    }

    private func captureRestorePoint(for automation: Automation) -> RestorePoint {
        var point = RestorePoint(arrangement: nil)
        let touchesWindows = automation.actions.contains {
            if case .applyWorkspace = $0 { return true } else { return false }
        }
        if touchesWindows {
            point.arrangement = WindowManagementService.shared
                .snapshotCurrentArrangement(named: "Before \(automation.name)")
        }
        #if !TONIC_STORE
        let touchesMenuBar = automation.actions.contains {
            switch $0 {
            case .applyMenuBarPreset, .collapseMenuBar, .expandMenuBar: return true
            default: return false
            }
        }
        if touchesMenuBar {
            var layout: [String: MenuBarSection] = [:]
            for item in MenuBarManager.shared.items where !item.isSystemControlled {
                if let section = item.section { layout[item.stableKey] = section }
            }
            point.menuBarLayout = layout
        }
        #endif
        return point
    }

    private func revert(automationID: UUID) {
        guard let point = restorePoints.removeValue(forKey: automationID) else { return }
        let name = AutomationStore.shared.automations
            .first(where: { $0.id == automationID })?.name ?? "Automation"

        Task { @MainActor in
            var restored: [String] = []
            if let arrangement = point.arrangement {
                WindowManagementService.shared.apply(arrangement)
                restored.append("window arrangement")
            }
            #if !TONIC_STORE
            if let layout = point.menuBarLayout {
                await MenuBarManager.shared.applyLayout(layout)
                restored.append("menu bar layout")
            }
            #endif
            guard !restored.isEmpty else { return }
            ActionReceiptStore.shared.record(ActionReceipt(
                tool: .automations,
                title: "\u{201C}\(name)\u{201D} restored",
                detail: "Condition cleared → restored \(restored.joined(separator: " and "))",
                status: .restored,
                affectedItems: restored.count
            ))
        }
    }
}
