//
//  MenuBarPresetsCard.swift
//  Tonic
//
//  Save the current menu bar layout as a named preset and apply it later.
//

import SwiftUI

struct MenuBarPresetsCard: View {
    @State private var store = MenuBarPresetStore.shared
    @State private var newName = ""
    @State private var showingSave = false
    @State private var capturesLayout = true
    @State private var capturesGroups = true
    @State private var capturesAppearance = false
    @State private var capturesReveal = false
    @State private var editingPreset: MenuBarPreset?

    let onApply: (MenuBarPreset) -> Void

    var body: some View {
        SettingsPanel(title: "PRESETS") {
            if store.presets.isEmpty {
                emptyRow
            } else {
                ForEach(store.presets) { preset in
                    presetRow(preset, isLast: preset.id == store.presets.last?.id)
                }
            }
            saveRow
        }
        .sheet(item: $editingPreset) { preset in
            MenuBarPresetEditorSheet(preset: preset) { store.update($0) }
        }
    }

    private var emptyRow: some View {
        TonicPreferenceRow(title: "No presets yet",
                           description: "Arrange your menu bar, then save it as a named layout.",
                           showsDivider: true) { EmptyView() }
    }

    private func presetRow(_ preset: MenuBarPreset, isLast: Bool) -> some View {
        TonicPreferenceRow(title: preset.name,
                           description: "\(preset.layout.count) item\(preset.layout.count == 1 ? "" : "s")",
                           showsDivider: !isLast) {
            HStack(spacing: TonicDS.Space.sm) {
                TextAction("Apply", color: TonicDS.Colors.linkBlue) {
                    onApply(preset)
                }
                Menu {
                    Button("Edit…") { editingPreset = preset }
                    Button("Duplicate") { store.duplicate(preset) }
                    Button("Delete", role: .destructive) { store.delete(preset) }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .tint(TonicDS.Colors.textMuted)
            }
        }
    }

    private var saveRow: some View {
        TonicPreferenceRow(title: "Save current layout",
                           description: "Capture where each item sits right now.",
                           showsDivider: false) {
            if showingSave {
                HStack(spacing: TonicDS.Space.xs) {
                    TextField("Name", text: $newName)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                        .onSubmit(commitSave)
                    TextAction("Save", color: TonicDS.Colors.linkBlue, action: commitSave)
                    Menu("Contents") {
                        Toggle("Layout", isOn: $capturesLayout)
                        Toggle("Groups", isOn: $capturesGroups)
                        Toggle("Appearance", isOn: $capturesAppearance)
                        Toggle("Reveal behavior", isOn: $capturesReveal)
                    }
                }
            } else {
                TextAction("Save…", systemImage: "plus", color: TonicDS.Colors.linkBlue) {
                    showingSave = true
                }
            }
        }
    }

    private func commitSave() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { showingSave = false; return }
        _ = store.captureCurrent(name: name, items: MenuBarManager.shared.items,
                                 capturesLayout: capturesLayout, capturesGroups: capturesGroups,
                                 capturesAppearance: capturesAppearance,
                                 capturesRevealBehavior: capturesReveal)
        newName = ""
        showingSave = false
    }
}

private struct MenuBarPresetEditorSheet: View {
    @State var preset: MenuBarPreset
    let onSave: (MenuBarPreset) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Edit Preset").font(.title2.bold())
            Form {
                TextField("Name", text: $preset.name)
                TextField("SF Symbol", text: $preset.symbolName)
                Toggle("Capture layout", isOn: $preset.capturesLayout)
                Toggle("Capture groups", isOn: $preset.capturesGroups)
                Toggle("Include appearance", isOn: Binding(
                    get: { preset.appearance != nil },
                    set: { preset.appearance = $0 ? MenuBarManagerSettingsStore.shared.settings.styling : nil }
                ))
                Toggle("Include reveal behavior", isOn: Binding(
                    get: { preset.revealBehavior != nil },
                    set: { enabled in
                        let settings = MenuBarManagerSettingsStore.shared.settings
                        preset.revealBehavior = enabled ? MenuBarRevealBehaviorSnapshot(
                            showOnHover: settings.showOnHover,
                            showOnClickEmptyMenuBar: settings.showOnClickEmptyMenuBar,
                            showOnScroll: settings.showOnScroll, autoRehide: settings.autoRehide,
                            quickShelfPresentation: settings.quickShelfPresentation) : nil
                    }
                ))
            }.formStyle(.grouped)
            HStack {
                Button("Cancel") { dismiss() }.buttonStyle(.bordered)
                Spacer()
                PrimaryPill("Save Preset", isDisabled: preset.name.trimmingCharacters(in: .whitespaces).isEmpty) {
                    preset.name = preset.name.trimmingCharacters(in: .whitespaces)
                    onSave(preset); dismiss()
                }
            }
        }
        .padding(24).frame(width: 520, height: 430)
    }
}
