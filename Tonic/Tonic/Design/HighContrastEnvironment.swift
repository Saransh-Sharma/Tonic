//
//  HighContrastEnvironment.swift
//  Tonic
//
//  Environment key for high contrast mode support
//

import SwiftUI

// MARK: - High Contrast Environment Key

struct HighContrastKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    /// Whether high contrast mode is enabled
    var isHighContrast: Bool {
        get { self[HighContrastKey.self] }
        set { self[HighContrastKey.self] = newValue }
    }
}

// MARK: - High Contrast View Modifier

struct HighContrastModifier: ViewModifier {
    @State private var preferences = AppearancePreferences.shared
    @State private var isHighContrast = false

    func body(content: Content) -> some View {
        content
            .environment(\.isHighContrast, isHighContrast)
            .onReceive(
                NotificationCenter.default.publisher(for: NSNotification.Name("TonicThemeDidChange")),
                perform: { _ in
                    // Reload preferences when theme changes
                    let updated = AppearancePreferences.shared
                    isHighContrast = updated.useHighContrast
                }
            )
            .onAppear {
                isHighContrast = AppearancePreferences.shared.useHighContrast
            }
    }
}

extension View {
    /// Apply high contrast support to this view
    func supportHighContrast() -> some View {
        modifier(HighContrastModifier())
    }
}
