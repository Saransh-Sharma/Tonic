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
    @State private var preview = MenuBarManagerSettings.default.styling
    @State private var original = MenuBarManagerSettings.default.styling
    @State private var isPreviewing = false

    #if !TONIC_STORE
    @State private var spacingPreset: MenuBarSpacingPreset = .system
    #endif

    var body: some View {
        SettingsPanel(title: "APPEARANCE") {
            presetRows
            #if !TONIC_STORE
            spacingRow
            stylingRows
            #else
            TonicPreferenceRow(title: "Real menu bar preview",
                               description: "Explore and save styles here. Applying the overlay to the system menu bar requires the direct build.",
                               showsDivider: false) { EmptyView() }
            #endif
        }
        #if !TONIC_STORE
        .onAppear {
            spacingPreset = MenuBarSpacingController.shared.currentPreset()
            preview = store.settings.styling
            original = preview
        }
        .onChange(of: preview) { _, styling in
            guard styling != store.settings.styling else { return }
            if !isPreviewing { original = store.settings.styling; isPreviewing = true }
            MenuBarStyleOverlayController.shared.apply(styling)
        }
        .onDisappear {
            if isPreviewing { MenuBarStyleOverlayController.shared.apply(store.settings.styling) }
        }
        #endif
    }

    private var presetRows: some View {
        TonicPreferenceRow(title: "Style presets",
                           description: "Preview a calm system bar or a more expressive Liquid Tonic surface.") {
            HStack(spacing: 6) {
                ForEach(MenuBarStylePreset.allCases) { preset in
                    Button(preset.title) { beginPreview(preset.styling) }
                        .buttonStyle(.bordered)
                }
            }
        }
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
                           isOn: $preview.isEnabled)
            if preview.isEnabled {
                TonicPreferenceRow(title: "Color") {
                    ColorPicker("", selection: tintBinding, supportsOpacity: false)
                        .labelsHidden()
                }
                TonicToggleRow(title: "Gradient",
                               description: "Fade the tint from top to bottom.",
                               isOn: $preview.usesGradient)
                if preview.usesGradient {
                    TonicPreferenceRow(title: "Second color") {
                        ColorPicker("", selection: gradientBinding, supportsOpacity: false).labelsHidden()
                    }
                }
                TonicPreferenceRow(title: "Opacity") {
                    Slider(value: $preview.opacity, in: 0.1...1)
                        .frame(width: 130)
                }
                TonicPreferenceRow(title: "Corner radius") {
                    Slider(value: $preview.cornerRadius, in: 0...16)
                        .frame(width: 130)
                }
                TonicPreferenceRow(title: "Border") {
                    Slider(value: $preview.borderWidth, in: 0...4).frame(width: 130)
                }
                TonicPreferenceRow(title: "Shadow") {
                    Slider(value: $preview.shadowStrength, in: 0...1).frame(width: 130)
                }
                TonicToggleRow(title: "Full width", isOn: $preview.isFullWidth)
                TonicToggleRow(title: "Match wallpaper",
                               description: "Refresh the tint when the desktop, Space, or display changes.",
                               isOn: $preview.matchesWallpaper)
                TonicPreferenceRow(title: "Preview changes",
                                   description: "Preview is temporary until you apply it.",
                                   showsDivider: false) {
                    HStack(spacing: 8) {
                        Button("Cancel", action: cancelPreview).buttonStyle(.bordered)
                        PrimaryPill("Apply", action: applyPreview)
                    }
                }
            }
        }
    }

    private var tintBinding: Binding<Color> {
        Binding(
            get: {
                preview.tintHex.flatMap { Color(menuBarHex: $0) } ?? TonicDS.Colors.darkNavy
            },
            set: { preview.tintHex = $0.menuBarHexString; isPreviewing = true }
        )
    }

    private var gradientBinding: Binding<Color> {
        Binding(get: {
            preview.gradientEndHex.flatMap { Color(menuBarHex: $0) } ?? TonicDS.Colors.linkBlue
        }, set: { preview.gradientEndHex = $0.menuBarHexString; isPreviewing = true })
    }
    #endif

    private func beginPreview(_ styling: MenuBarStyling) {
        #if !TONIC_STORE
        if !isPreviewing { original = store.settings.styling }
        preview = styling
        isPreviewing = true
        #else
        store.settings.styling = styling
        #endif
    }

    #if !TONIC_STORE
    private func applyPreview() {
        store.settings.styling = preview
        original = preview
        isPreviewing = false
        TonicFeedback.alignment()
    }

    private func cancelPreview() {
        preview = original
        store.settings.styling = original
        isPreviewing = false
        MenuBarStyleOverlayController.shared.apply(original)
    }
    #endif
}
