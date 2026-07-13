//
//  MenuBarBehaviorCard.swift
//  Tonic
//
//  Reveal/rehide behavior toggles (ported from the original management view)
//  plus the reveal-mode picker (menu bar vs Quick Shelf).
//

import SwiftUI

struct MenuBarBehaviorCard: View {
    @State private var manager = MenuBarManager.shared
    @State private var store = MenuBarManagerSettingsStore.shared
    @State private var workspace = MenuBarWorkspaceStore.shared
    @State private var showsLiveDisclosure = false

    var body: some View {
        SettingsPanel(title: "BEHAVIOR") {
            if MenuBarCapabilities.current.canMoveForeignItems {
                TonicPreferenceRow(title: "Layout enforcement",
                                   description: workspace.layoutMode == .live
                                    ? "Live reapplies the committed layout after apps change."
                                    : "On-Demand changes placement only when you press Apply.") {
                    Picker("Layout enforcement", selection: layoutModeBinding) {
                        ForEach(MenuBarLayoutMode.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .labelsHidden().frame(width: 130)
                }
            } else {
                TonicPreferenceRow(title: "Layout enforcement",
                                   description: "The Store edition preserves an On-Demand draft and leaves foreign placement manual.") {
                    StatusChip("On-Demand", color: TonicDS.Colors.textMuted)
                }
            }
            TonicPreferenceRow(title: "Reveal hidden items",
                               description: manager.canControlItems
                                ? "Slide items back onto the menu bar, or show them in Quick Shelf."
                                : "Manual Command-drag layouts can reveal in place or through a view-only Quick Shelf.") {
                Picker("", selection: $store.settings.revealMode) {
                    ForEach(MenuBarRevealMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .labelsHidden()
                .frame(width: 160)
            }

            if store.settings.revealMode == .tonicBar || !manager.canControlItems {
                TonicPreferenceRow(title: "Quick Shelf presentation",
                                   description: "Use one presentation everywhere unless a group overrides it.") {
                    Picker("", selection: $store.settings.quickShelfPresentation) {
                        ForEach(QuickShelfPresentation.allCases, id: \.self) { mode in
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
            TonicToggleRow(title: "Scroll or swipe to reveal",
                           description: "A deliberate trackpad or mouse scroll in the menu bar reveals hidden items.",
                           isOn: $store.settings.showOnScroll)
            TonicToggleRow(title: "Suppress in full screen",
                           description: "Avoid surprise reveals while the active app occupies a full-screen Space.",
                           isOn: $store.settings.suppressInFullScreen)
            TonicToggleRow(title: "Hide on inactive displays",
                           description: "A presentation-only preference; physical foreign-item ordering remains global.",
                           isOn: $store.settings.hideOnInactiveDisplays)
            TonicToggleRow(title: "Always-hidden section",
                           description: "A second ┃ separator further left. Items beyond it stay hidden even when expanded — ⌥-click the ‹ toggle to peek.",
                           showsDivider: false,
                           isOn: $store.settings.alwaysHiddenSectionEnabled)
        }
        .confirmationDialog("Enable Live layout enforcement?", isPresented: $showsLiveDisclosure) {
            Button("Enable Live") { workspace.layoutMode = .live }
            Button("Keep On-Demand", role: .cancel) {}
        } message: {
            Text("Live mode reacts when apps add or remove menu bar items. Reapplying may briefly interrupt the pointer for a second or two.")
        }
    }

    private var layoutModeBinding: Binding<MenuBarLayoutMode> {
        Binding(get: { workspace.layoutMode }, set: { mode in
            if mode == .live, workspace.layoutMode != .live { showsLiveDisclosure = true }
            else { workspace.layoutMode = mode }
        })
    }
}
