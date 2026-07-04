//
//  MenuBarBehaviorCard.swift
//  Tonic
//
//  Reveal/rehide behavior toggles (ported from the original management view)
//  plus the reveal-mode picker (menu bar vs Tonic Bar).
//

import SwiftUI

struct MenuBarBehaviorCard: View {
    @State private var manager = MenuBarManager.shared
    @State private var store = MenuBarManagerSettingsStore.shared

    var body: some View {
        SettingsPanel(title: "BEHAVIOR") {
            if manager.canControlItems {
                TonicPreferenceRow(title: "Reveal hidden items",
                                   description: "Slide items back onto the menu bar, or show them in a floating Tonic Bar.") {
                    Picker("", selection: $store.settings.revealMode) {
                        ForEach(MenuBarRevealMode.allCases, id: \.self) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 160)
                }
            }

            TonicToggleRow(title: "Auto-rehide",
                           description: "Collapse the hidden section again after a delay.",
                           isOn: $store.settings.autoRehide)
            if store.settings.autoRehide {
                TonicPreferenceRow(title: "Rehide delay") {
                    Stepper(value: $store.settings.rehideDelaySeconds, in: 2...120, step: 5) {
                        Text("\(Int(store.settings.rehideDelaySeconds))s")
                            .tonicType(.monoLabel).monospacedDigit()
                            .foregroundStyle(TonicDS.Colors.textPrimary)
                            .frame(width: 44, alignment: .trailing)
                    }
                }
            }
            TonicToggleRow(title: "Rehide on app switch",
                           description: "Collapse when you activate another app.",
                           isOn: $store.settings.rehideOnFocusChange)
            TonicToggleRow(title: "Show on hover",
                           description: "Reveal hidden items when the pointer dwells in the menu bar.",
                           isOn: $store.settings.showOnHover)
            if store.settings.showOnHover {
                TonicPreferenceRow(title: "Hover delay") {
                    Stepper(value: $store.settings.hoverDelaySeconds, in: 0...2, step: 0.1) {
                        Text(String(format: "%.1fs", store.settings.hoverDelaySeconds))
                            .tonicType(.monoLabel).monospacedDigit()
                            .foregroundStyle(TonicDS.Colors.textPrimary)
                            .frame(width: 44, alignment: .trailing)
                    }
                }
            }
            TonicToggleRow(title: "Click empty menu bar to toggle",
                           description: "A click on unoccupied menu bar space reveals or hides items.",
                           isOn: $store.settings.showOnClickEmptyMenuBar)
            TonicToggleRow(title: "Always-hidden section",
                           description: "A second ┃ separator further left. Items beyond it stay hidden even when expanded — ⌥-click the ‹ toggle to peek.",
                           showsDivider: false,
                           isOn: $store.settings.alwaysHiddenSectionEnabled)
        }
    }
}
