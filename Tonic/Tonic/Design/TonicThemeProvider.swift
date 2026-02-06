//
//  TonicThemeProvider.swift
//  Tonic
//
//  Environment plumbing for immersive Smart Scan theme.
//

import SwiftUI

private struct TonicThemeKey: EnvironmentKey {
    static let defaultValue = TonicTheme(world: .smartScanPurple)
}

extension EnvironmentValues {
    var tonicTheme: TonicTheme {
        get { self[TonicThemeKey.self] }
        set { self[TonicThemeKey.self] = newValue }
    }
}

struct TonicThemeProvider<Content: View>: View {
    let theme: TonicTheme
    @ViewBuilder let content: () -> Content

    init(world: TonicWorld, @ViewBuilder content: @escaping () -> Content) {
        self.theme = TonicTheme(world: world)
        self.content = content
    }

    var body: some View {
        content()
            .environment(\.tonicTheme, theme)
    }
}

extension View {
    func tonicTheme(_ world: TonicWorld) -> some View {
        environment(\.tonicTheme, TonicTheme(world: world))
    }
}
