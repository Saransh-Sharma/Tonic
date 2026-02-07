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

enum TonicGlassRenderingMode: Sendable {
    case legacy
    case liquid
}

private struct TonicGlassRenderingModeKey: EnvironmentKey {
    static var defaultValue: TonicGlassRenderingMode {
        if #available(macOS 26.0, *) {
            return .liquid
        } else {
            return .legacy
        }
    }
}

private struct TonicForceLegacyGlassKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var tonicTheme: TonicTheme {
        get { self[TonicThemeKey.self] }
        set { self[TonicThemeKey.self] = newValue }
    }

    var tonicGlassRenderingMode: TonicGlassRenderingMode {
        get { self[TonicGlassRenderingModeKey.self] }
        set { self[TonicGlassRenderingModeKey.self] = newValue }
    }

    var tonicForceLegacyGlass: Bool {
        get { self[TonicForceLegacyGlassKey.self] }
        set { self[TonicForceLegacyGlassKey.self] = newValue }
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

    func tonicGlassRenderingMode(_ mode: TonicGlassRenderingMode) -> some View {
        environment(\.tonicGlassRenderingMode, mode)
    }

    func tonicForceLegacyGlass(_ value: Bool) -> some View {
        environment(\.tonicForceLegacyGlass, value)
    }
}
