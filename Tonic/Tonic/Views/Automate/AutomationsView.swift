//
//  AutomationsView.swift
//  Tonic
//
//  The real Automate surface: cross-tool automations backed by AutomationStore
//  and AutomationEngine. Templates seed drafts; nothing enables itself — the
//  user reviews a draft, saves it, and flips it on. Every run leaves a receipt.
//

import SwiftUI

struct AutomationsView: View {
    @State private var store = AutomationStore.shared
    @State private var workspaceStore = WindowWorkspaceStore.shared
    @State private var draft: Automation?

    var body: some View {
        TonicScreenScaffold {
            VStack(alignment: .leading, spacing: TonicDS.Space.xl) {
                InstrumentHeader("Automate", state: "Context changes, made repeatable — with restore") {
                    Button {
                        draft = Automation(name: "New Automation",
                                           condition: .onBattery,
                                           actions: [])
                    } label: {
                        Label("New Automation", systemImage: "plus")
                    }
                    .buttonStyle(.borderless)
                }

                StatusNarrative(
                    "When · Do · Restore.",
                    eyebrow: "Cross-tool automations",
                    evidence: "An automation watches one condition and runs steps across Windows, Menu Bar, and Care. Nothing enables itself; every run leaves a receipt in Action History."
                )

                if !store.automations.isEmpty {
                    automationList
                }

                templates
            }
        }
        .sheet(item: $draft) { automation in
            AutomationEditorSheet(automation: automation) { saved in
                if store.automations.contains(where: { $0.id == saved.id }) {
                    store.update(saved)
                } else {
                    store.add(saved)
                }
                draft = nil
            } onCancel: {
                draft = nil
            }
        }
    }

    // MARK: - List

    private var automationList: some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.sm) {
            MonoLabel("Your automations")
            SettingsPanel(title: nil) {
                ForEach(Array(store.automations.enumerated()), id: \.element.id) { index, automation in
                    TonicPreferenceRow(
                        title: automation.name,
                        description: "\(automation.condition.summary) → \(actionSummary(automation))",
                        showsDivider: index < store.automations.count - 1
                    ) {
                        HStack(spacing: TonicDS.Space.sm) {
                            Button {
                                AutomationEngine.shared.run(automation)
                            } label: {
                                Text("Run Now").tonicType(.button)
                                    .foregroundStyle(TonicDS.Colors.linkBlue)
                            }
                            .buttonStyle(.plain)
                            .tonicPointerCursor()

                            Button {
                                draft = automation
                            } label: {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.system(size: 12))
                                    .foregroundStyle(TonicDS.Colors.textMuted)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Edit \(automation.name)")
                            .tonicPointerCursor()

                            Button {
                                store.delete(id: automation.id)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 12))
                                    .foregroundStyle(TonicDS.Colors.textMuted)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Delete \(automation.name)")
                            .tonicPointerCursor()

                            Toggle("", isOn: Binding(
                                get: { automation.isEnabled },
                                set: { store.setEnabled($0, id: automation.id) }
                            ))
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .tint(TonicDS.Colors.ink)
                            .accessibilityLabel("\(automation.name) enabled")
                        }
                    }
                }
            }
        }
    }

    private func actionSummary(_ automation: Automation) -> String {
        let steps = automation.actions.map { action -> String in
            switch action {
            case .applyWorkspace(let id):
                return "workspace \u{201C}\(workspaceStore.workspace(id: id)?.name ?? "deleted")\u{201D}"
            case .applyMenuBarPreset:
                return "menu bar preset"
            case .collapseMenuBar:
                return "hide menu items"
            case .expandMenuBar:
                return "reveal menu items"
            case .runMaintenance:
                return "safe maintenance"
            }
        }
        let joined = steps.isEmpty ? "no steps yet" : steps.joined(separator: " · ")
        return automation.revertsWhenCleared ? "\(joined) · restores when cleared" : joined
    }

    // MARK: - Templates

    private struct Template: Identifiable {
        let id: String
        let title: String
        let symbol: String
        let reason: String
        let make: () -> Automation
    }

    private var templateItems: [Template] {
        [
            Template(id: "battery", title: "Low Battery", symbol: "battery.25percent",
                     reason: "Below 20% → run safe maintenance; restores when charging resumes.") {
                Automation(name: "Low Battery", symbol: "battery.25percent",
                           condition: .batteryBelow(percent: 20),
                           actions: [.runMaintenance], revertsWhenCleared: false)
            },
            Template(id: "work", title: "Work Setup", symbol: "briefcase",
                     reason: "Work Wi-Fi connects → apply your work workspace and menu bar preset.") {
                Automation(name: "Work Setup", symbol: "briefcase",
                           condition: .wifiSSID(""),
                           actions: [], revertsWhenCleared: true)
            },
            Template(id: "present", title: "Presentation", symbol: "rectangle.on.rectangle",
                     reason: "Zoom or Keynote launches → hide menu bar items and arrange windows; restores after.") {
                Automation(name: "Presentation", symbol: "rectangle.on.rectangle",
                           condition: .appRunning(bundleID: "us.zoom.xos"),
                           actions: [.collapseMenuBar], revertsWhenCleared: true)
            },
            Template(id: "morning", title: "Morning Desk", symbol: "sunrise",
                     reason: "Weekday mornings → apply your desk workspace.") {
                Automation(name: "Morning Desk", symbol: "sunrise",
                           condition: .timeWindow(startMinute: 9 * 60, endMinute: 10 * 60,
                                                  weekdays: [2, 3, 4, 5, 6]),
                           actions: [], revertsWhenCleared: false)
            }
        ]
    }

    private var templates: some View {
        VStack(alignment: .leading, spacing: 0) {
            MonoLabel("Templates")
                .padding(.bottom, TonicDS.Space.xs)
            TonicHairline()
            ForEach(templateItems) { template in
                EvidenceRow(symbol: template.symbol, title: template.title,
                            reason: template.reason, metadata: nil) {
                    Button("Use Template") {
                        draft = template.make()
                    }
                    .buttonStyle(.borderless)
                }
                TonicHairline()
            }
        }
    }
}

// MARK: - Editor

struct AutomationEditorSheet: View {
    @State var automation: Automation
    let onSave: (Automation) -> Void
    let onCancel: () -> Void

    private enum ConditionKind: String, CaseIterable, Identifiable {
        case onBattery = "On battery"
        case charging = "Charging"
        case batteryBelow = "Battery below"
        case wifi = "Wi-Fi network"
        case appRunning = "App running"
        case timeWindow = "Time window"
        var id: String { rawValue }

        var needsParameter: Bool {
            switch self {
            case .onBattery, .charging: return false
            default: return true
            }
        }
    }

    @State private var conditionKind: ConditionKind = .onBattery
    @State private var batteryThreshold = 20
    @State private var ssid = ""
    @State private var bundleID = ""
    @State private var startTime = Calendar.current.date(from: DateComponents(hour: 9)) ?? Date()
    @State private var endTime = Calendar.current.date(from: DateComponents(hour: 17)) ?? Date()
    @State private var workspaceStore = WindowWorkspaceStore.shared

    var body: some View {
        SheetChrome(title: automation.name.isEmpty ? "Automation" : automation.name, onClose: onCancel) {
            VStack(alignment: .leading, spacing: TonicDS.Space.lg) {
                namePanel
                conditionPanel
                actionsPanel
                restorePanel
            }
            .frame(width: 520)
        } footer: {
            TextAction("Cancel", action: onCancel)
            PrimaryPill("Save Automation") {
                var saved = automation
                saved.condition = builtCondition
                onSave(saved)
            }
        }
        .onAppear(perform: seedFromAutomation)
    }

    private var namePanel: some View {
        SettingsPanel(title: "Name") {
            TonicPreferenceRow(title: "Automation name", showsDivider: false) {
                TextField("Name", text: $automation.name)
                    .textFieldStyle(.plain)
                    .tonicType(.body)
                    .frame(width: 200)
                    .padding(.horizontal, TonicDS.Space.sm)
                    .frame(height: TonicDS.Layout.inputHeight)
                    .tonicSurface(.surface,
                                  in: RoundedRectangle(cornerRadius: TonicDS.Radius.sm, style: .continuous),
                                  flatStroke: TonicDS.Colors.hairline)
            }
        }
    }

    private var conditionPanel: some View {
        SettingsPanel(title: "When") {
            TonicPreferenceRow(title: "Condition", showsDivider: conditionKind.needsParameter) {
                Picker("Condition", selection: $conditionKind) {
                    ForEach(ConditionKind.allCases) { kind in
                        Text(kind.rawValue).tag(kind)
                    }
                }
                .labelsHidden()
                .frame(width: 180)
            }

            switch conditionKind {
            case .batteryBelow:
                TonicPreferenceRow(title: "Threshold", showsDivider: false) {
                    Stepper("\(batteryThreshold)%", value: $batteryThreshold, in: 5...80, step: 5)
                        .tonicType(.body)
                }
            case .wifi:
                TonicPreferenceRow(title: "Network name (SSID)", showsDivider: false) {
                    TextField("SSID", text: $ssid)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 180)
                }
            case .appRunning:
                TonicPreferenceRow(title: "App", showsDivider: false) {
                    Picker("App", selection: $bundleID) {
                        Text("Choose…").tag("")
                        ForEach(runningApps, id: \.bundleID) { app in
                            Text(app.name).tag(app.bundleID)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 200)
                }
            case .timeWindow:
                TonicPreferenceRow(title: "Between", showsDivider: false) {
                    HStack(spacing: TonicDS.Space.xs) {
                        DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                        Text("and").tonicType(.caption)
                            .foregroundStyle(TonicDS.Colors.textMuted)
                        DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                }
            case .onBattery, .charging:
                EmptyView()
            }
        }
    }

    private var actionsPanel: some View {
        SettingsPanel(title: "Do") {
            TonicPreferenceRow(
                title: "Apply workspace",
                description: workspaceStore.workspaces.isEmpty
                    ? "Capture a workspace in Organize › Windows first."
                    : nil
            ) {
                Picker("Workspace", selection: workspaceBinding) {
                    Text("None").tag(UUID?.none)
                    ForEach(workspaceStore.workspaces) { workspace in
                        Text(workspace.name).tag(UUID?.some(workspace.id))
                    }
                }
                .labelsHidden()
                .frame(width: 180)
                .disabled(workspaceStore.workspaces.isEmpty)
            }

            #if !TONIC_STORE
            TonicPreferenceRow(title: "Apply menu bar preset") {
                Picker("Preset", selection: presetBinding) {
                    Text("None").tag(UUID?.none)
                    ForEach(MenuBarPresetStore.shared.presets) { preset in
                        Text(preset.name).tag(UUID?.some(preset.id))
                    }
                }
                .labelsHidden()
                .frame(width: 180)
                .disabled(MenuBarPresetStore.shared.presets.isEmpty)
            }
            TonicToggleRow(title: "Hide menu bar items",
                           isOn: actionToggleBinding(.collapseMenuBar))
            #endif

            TonicToggleRow(title: "Run safe maintenance",
                           description: "Cleans only system junk Smart Scan marks safe — never personal files.",
                           showsDivider: false,
                           isOn: actionToggleBinding(.runMaintenance))
        }
    }

    private var restorePanel: some View {
        SettingsPanel(title: "Restore") {
            TonicToggleRow(
                title: "Restore when the condition clears",
                description: "Captures the window arrangement and menu bar layout before running, and puts them back afterward.",
                showsDivider: false,
                isOn: $automation.revertsWhenCleared
            )
        }
    }

    // MARK: - Bindings & condition assembly

    private var workspaceBinding: Binding<UUID?> {
        Binding(
            get: {
                for case .applyWorkspace(let id) in automation.actions { return id }
                return nil
            },
            set: { newValue in
                automation.actions.removeAll {
                    if case .applyWorkspace = $0 { return true } else { return false }
                }
                if let id = newValue {
                    automation.actions.insert(.applyWorkspace(id), at: 0)
                }
            }
        )
    }

    private var presetBinding: Binding<UUID?> {
        Binding(
            get: {
                for case .applyMenuBarPreset(let id) in automation.actions { return id }
                return nil
            },
            set: { newValue in
                automation.actions.removeAll {
                    if case .applyMenuBarPreset = $0 { return true } else { return false }
                }
                if let id = newValue {
                    automation.actions.append(.applyMenuBarPreset(id))
                }
            }
        )
    }

    private func actionToggleBinding(_ action: AutomationAction) -> Binding<Bool> {
        Binding(
            get: { automation.actions.contains(action) },
            set: { enabled in
                automation.actions.removeAll { $0 == action }
                if enabled { automation.actions.append(action) }
            }
        )
    }

    private var builtCondition: TriggerCondition {
        switch conditionKind {
        case .onBattery: return .onBattery
        case .charging: return .charging
        case .batteryBelow: return .batteryBelow(percent: batteryThreshold)
        case .wifi: return .wifiSSID(ssid)
        case .appRunning: return .appRunning(bundleID: bundleID)
        case .timeWindow:
            let calendar = Calendar.current
            let start = calendar.dateComponents([.hour, .minute], from: startTime)
            let end = calendar.dateComponents([.hour, .minute], from: endTime)
            return .timeWindow(
                startMinute: (start.hour ?? 9) * 60 + (start.minute ?? 0),
                endMinute: (end.hour ?? 17) * 60 + (end.minute ?? 0),
                weekdays: []
            )
        }
    }

    private func seedFromAutomation() {
        switch automation.condition {
        case .onBattery: conditionKind = .onBattery
        case .charging: conditionKind = .charging
        case .batteryBelow(let percent):
            conditionKind = .batteryBelow
            batteryThreshold = percent
        case .wifiSSID(let value):
            conditionKind = .wifi
            ssid = value
        case .appRunning(let bundle):
            conditionKind = .appRunning
            bundleID = bundle
        case .timeWindow(let start, let end, _):
            conditionKind = .timeWindow
            let calendar = Calendar.current
            startTime = calendar.date(from: DateComponents(hour: start / 60, minute: start % 60)) ?? startTime
            endTime = calendar.date(from: DateComponents(hour: end / 60, minute: end % 60)) ?? endTime
        }
    }

    private var runningApps: [(name: String, bundleID: String)] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app in
                guard let bundle = app.bundleIdentifier, let name = app.localizedName else { return nil }
                return (name: name, bundleID: bundle)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
