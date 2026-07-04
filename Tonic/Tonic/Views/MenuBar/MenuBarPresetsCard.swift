//
//  MenuBarPresetsCard.swift
//  Tonic
//
//  Save the current menu bar layout as a named preset and apply it later.
//

import SwiftUI

struct MenuBarPresetsCard: View {
    @State private var manager = MenuBarManager.shared
    @State private var store = MenuBarPresetStore.shared
    @State private var newName = ""
    @State private var showingSave = false

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
                    Button("Duplicate") { store.duplicate(preset) }
                    Button("Delete", role: .destructive) { store.delete(preset) }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .tint(TonicDS.Colors.textMuted)
                .disabled(!manager.canControlItems)
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
                }
            } else {
                TextAction("Save…", systemImage: "plus", color: TonicDS.Colors.linkBlue) {
                    showingSave = true
                }
                .disabled(!manager.canControlItems)
            }
        }
    }

    private func commitSave() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { showingSave = false; return }
        _ = store.captureCurrent(name: name, items: manager.items)
        newName = ""
        showingSave = false
    }
}
