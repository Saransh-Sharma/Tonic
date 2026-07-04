//
//  MenuBarAppearanceCard.swift
//  Tonic
//
//  Menu bar item spacing and cosmetic styling overlay. Both are direct-build
//  only; the card explains the Store limitation.
//

import SwiftUI

struct MenuBarAppearanceCard: View {
    @State private var manager = MenuBarManager.shared
    @State private var store = MenuBarManagerSettingsStore.shared

    #if !TONIC_STORE
    @State private var spacingPreset: MenuBarSpacingPreset = .system
    #endif

    var body: some View {
        SettingsPanel(title: "APPEARANCE") {
            #if !TONIC_STORE
            spacingRow
            stylingRows
            #else
            TonicPreferenceRow(title: "Spacing & styling",
                               description: "Available in the direct download of Tonic.",
                               showsDivider: false) { EmptyView() }
            #endif
        }
        #if !TONIC_STORE
        .onAppear { spacingPreset = MenuBarSpacingController.shared.currentPreset() }
        #endif
    }

    #if !TONIC_STORE
    private var spacingRow: some View {
        Group {
            TonicPreferenceRow(title: "Item spacing",
                               description: "Tighter spacing fits more in the menu bar. Applies as apps relaunch; log out to apply everywhere.") {
                Picker("", selection: $spacingPreset) {
                    ForEach(MenuBarSpacingPreset.allCases) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .frame(width: 130)
                .onChange(of: spacingPreset) { _, preset in
                    MenuBarSpacingController.shared.apply(preset)
                }
            }
        }
    }

    private var stylingRows: some View {
        Group {
            TonicToggleRow(title: "Menu bar tint",
                           description: "Draw a colored band across the menu bar.",
                           isOn: $store.settings.styling.isEnabled)
            if store.settings.styling.isEnabled {
                TonicPreferenceRow(title: "Color") {
                    ColorPicker("", selection: tintBinding, supportsOpacity: false)
                        .labelsHidden()
                }
                TonicToggleRow(title: "Gradient",
                               description: "Fade the tint from top to bottom.",
                               isOn: $store.settings.styling.usesGradient)
                TonicPreferenceRow(title: "Opacity") {
                    Slider(value: $store.settings.styling.opacity, in: 0.1...1)
                        .frame(width: 130)
                }
                TonicPreferenceRow(title: "Corner radius", showsDivider: false) {
                    Slider(value: $store.settings.styling.cornerRadius, in: 0...16)
                        .frame(width: 130)
                }
            }
        }
    }

    private var tintBinding: Binding<Color> {
        Binding(
            get: {
                store.settings.styling.tintHex.flatMap { Color(menuBarHex: $0) } ?? TonicDS.Colors.darkNavy
            },
            set: { store.settings.styling.tintHex = $0.menuBarHexString }
        )
    }
    #endif
}
