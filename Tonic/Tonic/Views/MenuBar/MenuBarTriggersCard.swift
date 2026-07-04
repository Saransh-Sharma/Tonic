//
//  MenuBarTriggersCard.swift
//  Tonic
//
//  Rules that reshape the menu bar automatically (battery, Wi-Fi, app, time).
//

import SwiftUI

struct MenuBarTriggersCard: View {
    @State private var manager = MenuBarManager.shared
    @State private var store = MenuBarTriggerStore.shared

    let onEdit: (MenuBarTrigger?) -> Void

    var body: some View {
        SettingsPanel(title: "TRIGGERS") {
            if store.triggers.isEmpty {
                TonicPreferenceRow(title: "No triggers yet",
                                   description: "Apply a preset automatically on battery, Wi-Fi, an app, or a time of day.",
                                   showsDivider: true) { EmptyView() }
            } else {
                ForEach(store.triggers) { trigger in
                    triggerRow(trigger, isLast: false)
                }
            }
            TonicPreferenceRow(title: "New trigger",
                               description: "Automate the menu bar based on context.",
                               showsDivider: false) {
                TextAction("Add…", systemImage: "plus", color: TonicDS.Colors.linkBlue) {
                    onEdit(nil)
                }
            }
        }
    }

    private func triggerRow(_ trigger: MenuBarTrigger, isLast: Bool) -> some View {
        TonicPreferenceRow(title: trigger.name,
                           description: "\(trigger.condition.summary) → \(trigger.action.summary)",
                           showsDivider: true) {
            HStack(spacing: TonicDS.Space.sm) {
                Toggle("", isOn: Binding(
                    get: { trigger.isEnabled },
                    set: { store.setEnabled($0, for: trigger) }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(TonicDS.Colors.ink)
                .disabled(!manager.canControlItems)

                Menu {
                    Button("Edit…") { onEdit(trigger) }
                    Button("Delete", role: .destructive) { store.delete(trigger) }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .tint(TonicDS.Colors.textMuted)
            }
        }
    }
}
