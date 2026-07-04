//
//  MenuBarHotkeysCard.swift
//  Tonic
//
//  Global shortcut recorders for the menu bar actions.
//

import SwiftUI

struct MenuBarHotkeysCard: View {
    private let actions: [HotkeyAction] = [.toggleMenuBar, .quickSearch]

    var body: some View {
        SettingsPanel(title: "SHORTCUTS") {
            ForEach(Array(actions.enumerated()), id: \.element) { index, action in
                TonicPreferenceRow(title: action.title,
                                   description: action.subtitle,
                                   showsDivider: index < actions.count - 1) {
                    KeyboardShortcutRecorder(action: action)
                }
            }
        }
    }
}
