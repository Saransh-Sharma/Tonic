//
//  TriggerEditorSheet.swift
//  Tonic
//
//  Create or edit a menu bar trigger: a condition paired with an action.
//

import AppKit
import SwiftUI

struct TriggerEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store = MenuBarTriggerStore.shared
    @State private var presetStore = MenuBarPresetStore.shared

    /// nil when creating; an existing trigger when editing.
    let editing: MenuBarTrigger?
    /// Pre-filled stable key when spawned from an item's "Create Trigger…".
    let seedItemKey: String?

    @State private var name = ""
    @State private var conditionKind: ConditionKind = .batteryBelow
    @State private var batteryPercent = 20
    @State private var ssid = ""
    @State private var appBundleID = ""
    @State private var startHour = 22
    @State private var endHour = 8
    @State private var actionKind: ActionKind = .applyPreset
    @State private var selectedPresetID: UUID?
    @State private var revealItemKey = ""
    @State private var selectedContextID: UUID?
    #if !TONIC_STORE
    @State private var selectedScriptID: UUID?
    #endif
    @State private var revertsWhenCleared = false

    enum ConditionKind: String, CaseIterable, Identifiable {
        case batteryBelow = "Battery below"
        case onBattery = "On battery"
        case charging = "Charging"
        case wifi = "Wi-Fi network"
        case appRunning = "App running"
        case timeWindow = "Time of day"
        var id: String { rawValue }
    }

    enum ActionKind: String, CaseIterable, Identifiable {
        case applyPreset = "Apply preset"
        case revealItem = "Reveal item"
        case expand = "Reveal all"
        case collapse = "Hide all"
        case manualContext = "Select context"
        #if !TONIC_STORE
        case runScript = "Run reviewed script"
        #endif
        var id: String { rawValue }
    }

    var body: some View {
        SheetChrome(title: editing == nil ? "New Trigger" : "Edit Trigger") {
            VStack(alignment: .leading, spacing: TonicDS.Space.lg) {
                SettingsPanel(title: "NAME") {
                    TonicPreferenceRow(title: "Trigger name", showsDivider: false) {
                        TextField("e.g. On the go", text: $name)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 180)
                    }
                }
                conditionPanel
                actionPanel
                SettingsPanel(title: "OPTIONS") {
                    TonicToggleRow(title: "Revert when condition clears",
                                   description: "Restore the previous layout once the condition is no longer met.",
                                   showsDivider: false,
                                   isOn: $revertsWhenCleared)
                }
            }
        } footer: {
            PrimaryPill(editing == nil ? "Add Trigger" : "Save", action: save)
                .disabled(!canSave)
            TextAction("Cancel") { dismiss() }
        }
        .frame(width: 460)
        .onAppear(perform: load)
    }

    private var conditionPanel: some View {
        SettingsPanel(title: "WHEN") {
            TonicPreferenceRow(title: "Condition", showsDivider: conditionKind != .charging && conditionKind != .onBattery) {
                Picker("", selection: $conditionKind) {
                    ForEach(ConditionKind.allCases) { Text($0.rawValue).tag($0) }
                }
                .labelsHidden().frame(width: 160)
            }
            switch conditionKind {
            case .batteryBelow:
                TonicPreferenceRow(title: "Below", showsDivider: false) {
                    Stepper("\(batteryPercent)%", value: $batteryPercent, in: 5...95, step: 5)
                        .fixedSize()
                }
            case .wifi:
                TonicPreferenceRow(title: "Network name", showsDivider: false) {
                    TextField("SSID", text: $ssid).textFieldStyle(.roundedBorder).frame(width: 160)
                }
            case .appRunning:
                TonicPreferenceRow(title: "App bundle ID", showsDivider: false) {
                    TextField("com.example.App", text: $appBundleID).textFieldStyle(.roundedBorder).frame(width: 180)
                }
            case .timeWindow:
                TonicPreferenceRow(title: "From", showsDivider: true) {
                    Stepper("\(startHour):00", value: $startHour, in: 0...23).fixedSize()
                }
                TonicPreferenceRow(title: "To", showsDivider: false) {
                    Stepper("\(endHour):00", value: $endHour, in: 0...23).fixedSize()
                }
            case .onBattery, .charging:
                EmptyView()
            }
        }
    }

    private var actionPanel: some View {
        SettingsPanel(title: "DO") {
            TonicPreferenceRow(title: "Action", showsDivider: actionKind == .applyPreset || actionKind == .revealItem || actionKind == .manualContext
                               || isScriptAction) {
                Picker("", selection: $actionKind) {
                    ForEach(ActionKind.allCases) { Text($0.rawValue).tag($0) }
                }
                .labelsHidden().frame(width: 160)
            }
            switch actionKind {
            case .applyPreset:
                TonicPreferenceRow(title: "Preset", showsDivider: false) {
                    Picker("", selection: $selectedPresetID) {
                        Text("None").tag(UUID?.none)
                        ForEach(presetStore.presets) { Text($0.name).tag(UUID?.some($0.id)) }
                    }
                    .labelsHidden().frame(width: 160)
                }
            case .revealItem:
                TonicPreferenceRow(title: "Item key", showsDivider: false) {
                    TextField("bundle id", text: $revealItemKey).textFieldStyle(.roundedBorder).frame(width: 180)
                }
            case .manualContext:
                TonicPreferenceRow(title: "Context", showsDivider: false) {
                    Picker("", selection: $selectedContextID) {
                        Text("Global").tag(UUID?.none)
                        ForEach(MenuBarProfileStore.shared.manualContexts) { Text($0.name).tag(UUID?.some($0.id)) }
                    }.labelsHidden().frame(width: 160)
                }
            #if !TONIC_STORE
            case .runScript:
                TonicPreferenceRow(title: "Reviewed script", showsDivider: false) {
                    Picker("", selection: $selectedScriptID) {
                        Text("None").tag(UUID?.none)
                        ForEach(CustomItemScriptStore.shared.definitions) { script in
                            Text(script.executable).tag(UUID?.some(script.id))
                        }
                    }.labelsHidden().frame(width: 180)
                }
            #endif
            case .expand, .collapse:
                EmptyView()
            }
        }
    }

    private func load() {
        if let key = seedItemKey {
            actionKind = .revealItem
            revealItemKey = key
        }
        guard let trigger = editing else { return }
        name = trigger.name
        revertsWhenCleared = trigger.revertsWhenCleared
        switch trigger.condition {
        case .batteryBelow(let percent): conditionKind = .batteryBelow; batteryPercent = percent
        case .onBattery: conditionKind = .onBattery
        case .charging: conditionKind = .charging
        case .wifiSSID(let value): conditionKind = .wifi; ssid = value
        case .appRunning(let bundleID): conditionKind = .appRunning; appBundleID = bundleID
        case .timeWindow(let start, let end, _):
            conditionKind = .timeWindow; startHour = start / 60; endHour = end / 60
        }
        switch trigger.action {
        case .applyPreset(let id): actionKind = .applyPreset; selectedPresetID = id
        case .revealItem(let key): actionKind = .revealItem; revealItemKey = key
        case .expand: actionKind = .expand
        case .collapse: actionKind = .collapse
        case .selectManualContext(let id): actionKind = .manualContext; selectedContextID = id
        case .runReviewedScript(let id):
            #if !TONIC_STORE
            actionKind = .runScript; selectedScriptID = id
            #else
            actionKind = .collapse
            #endif
        }
    }

    private func buildCondition() -> TriggerCondition {
        switch conditionKind {
        case .batteryBelow: return .batteryBelow(percent: batteryPercent)
        case .onBattery: return .onBattery
        case .charging: return .charging
        case .wifi: return .wifiSSID(ssid)
        case .appRunning: return .appRunning(bundleID: appBundleID)
        case .timeWindow: return .timeWindow(startMinute: startHour * 60, endMinute: endHour * 60, weekdays: [])
        }
    }

    private func buildAction() -> TriggerAction {
        switch actionKind {
        case .applyPreset: return .applyPreset(selectedPresetID ?? UUID())
        case .revealItem: return .revealItem(stableKey: revealItemKey)
        case .expand: return .expand
        case .collapse: return .collapse
        case .manualContext: return .selectManualContext(selectedContextID)
        #if !TONIC_STORE
        case .runScript: return .runReviewedScript(selectedScriptID ?? UUID())
        #endif
        }
    }

    private var isScriptAction: Bool {
        #if !TONIC_STORE
        actionKind == .runScript
        #else
        false
        #endif
    }

    private func save() {
        let trigger = MenuBarTrigger(
            id: editing?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            isEnabled: editing?.isEnabled ?? true,
            condition: buildCondition(),
            action: buildAction(),
            revertsWhenCleared: revertsWhenCleared
        )
        if editing == nil {
            store.add(trigger)
        } else {
            store.update(trigger)
        }
        dismiss()
    }

    private var canSave: Bool {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        if conditionKind == .wifi && ssid.trimmingCharacters(in: .whitespaces).isEmpty { return false }
        if conditionKind == .appRunning && appBundleID.trimmingCharacters(in: .whitespaces).isEmpty { return false }
        switch actionKind {
        case .applyPreset: return selectedPresetID != nil
        case .revealItem: return !revealItemKey.trimmingCharacters(in: .whitespaces).isEmpty
        #if !TONIC_STORE
        case .runScript: return selectedScriptID != nil
        #endif
        case .expand, .collapse, .manualContext: return true
        }
    }
}
