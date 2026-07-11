//
//  TonicGlass.swift
//  Tonic
//
//  Liquid Tonic material resolution — the single authority deciding whether the
//  shell renders glass or the flat editorial fallback, plus the two modifiers the
//  entire migration rides on: `.tonicSurface(_:in:)` and `.tonicCanvas()`.
//
//  THE DATA IS THE MEDIA; THE DESKTOP IS THE LIGHT SOURCE. Glass is chrome, never
//  meaning. When any transparency reduction is active (app preference, system
//  accessibility setting, or intensity "Off"), every layer resolves to the exact
//  flat fill the editorial system shipped with — pixel-identical, fully QA'd.
//

import SwiftUI
import AppKit

// MARK: - Policy

/// Global glass on/off authority. Observable so surfaces re-resolve live when the
/// user (or the system accessibility setting) changes transparency.
@Observable
public final class TonicGlassPolicy: @unchecked Sendable {
    public static let shared = TonicGlassPolicy()

    /// Mirrors the macOS "Reduce transparency" accessibility setting.
    public private(set) var systemReducesTransparency: Bool

    private var observer: NSObjectProtocol?

    private init() {
        systemReducesTransparency = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.systemReducesTransparency =
                NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        }
    }

    /// True when the shell may render glass. Any reduction wins: the app's own
    /// Reduce Transparency, the system accessibility setting, or intensity Off.
    public var isGlassEnabled: Bool {
        Self.resolvesGlass(
            systemReducesTransparency: systemReducesTransparency,
            appReducesTransparency: AppearancePreferences.shared.reduceTransparency,
            intensity: AppearancePreferences.shared.glassIntensity
        )
    }

    static func resolvesGlass(
        systemReducesTransparency: Bool,
        appReducesTransparency: Bool,
        intensity: GlassIntensity
    ) -> Bool {
        !systemReducesTransparency && !appReducesTransparency && intensity != .off
    }

    /// Effective intensity after reductions — `.off` when glass is disabled.
    public var effectiveIntensity: GlassIntensity {
        isGlassEnabled ? AppearancePreferences.shared.glassIntensity : .off
    }
}

// MARK: - Surface resolution

private struct TonicSurfaceModifier<S: InsettableShape>: ViewModifier {
    let layer: TonicDS.Glass.Layer
    let shape: S
    /// Glass-mode wash override for `.surface` — warm components (soft-stone
    /// cards) tint their material with their own color instead of `surface`.
    var tint: Color?
    /// Flat-mode fill override when the legacy fill differs from the layer
    /// default (e.g. ScanCategoryCard uses `softStone`, not `surface`).
    var flatFill: Color?
    /// Flat-mode stroke override for components whose legacy border differs from
    /// the layer default (e.g. SettingsPanel uses `hairline`, not `cardBorder`).
    /// Pass `Color.clear` for legacy surfaces that had no border.
    var flatStroke: Color?

    func body(content: Content) -> some View {
        if TonicGlassPolicy.shared.isGlassEnabled {
            glassBody(content)
        } else {
            flatBody(content)
        }
    }

    // -- Glass tier ----------------------------------------------------------

    @ViewBuilder
    private func glassBody(_ content: Content) -> some View {
        switch layer {
        case .chrome:
            // Z3 — true Liquid Glass. The system rim replaces our hairline.
            content.glassEffect(.regular, in: shape)
        case .overlay:
            content
                .background {
                    ZStack {
                        shape.fill(.thickMaterial)
                        shape.fill(TonicDS.Colors.canvas.opacity(TonicDS.Glass.overlayWash))
                    }
                }
                .overlay(shape.strokeBorder(TonicDS.Colors.glassStroke, lineWidth: 1))
        case .surface:
            content
                .background {
                    ZStack {
                        shape.fill(.thinMaterial)
                        shape.fill((tint ?? TonicDS.Colors.surface)
                            .opacity(TonicDS.Glass.surfaceWash))
                    }
                }
                .overlay(shape.strokeBorder(TonicDS.Colors.glassStroke, lineWidth: 1))
        case .smoked:
            content
                .background {
                    ZStack {
                        shape.fill(.ultraThinMaterial)
                        shape.fill(TonicDS.Colors.console.opacity(TonicDS.Glass.smokedWash))
                    }
                    // Smoke must stay dark regardless of the window's scheme.
                    .environment(\.colorScheme, .dark)
                }
                .overlay(shape.strokeBorder(TonicDS.Colors.hairlineOnDark, lineWidth: 1))
        case .band(let kind):
            content
                .background {
                    ZStack {
                        shape.fill(.thinMaterial)
                        shape.fill(TonicDS.bandFill(kind).opacity(TonicDS.Glass.bandWash))
                    }
                    .environment(\.colorScheme, .dark)
                }
        }
    }

    // -- Flat tier (the shipped editorial fills, pixel-identical) -------------

    @ViewBuilder
    private func flatBody(_ content: Content) -> some View {
        switch layer {
        case .chrome:
            content
                .background(flatFill ?? TonicDS.Colors.surface, in: shape)
                .overlay(shape.strokeBorder(flatStroke ?? TonicDS.Colors.hairline, lineWidth: 1))
        case .overlay:
            content
                .background(flatFill ?? TonicDS.Colors.canvas, in: shape)
                .overlay(shape.strokeBorder(flatStroke ?? .clear, lineWidth: 1))
        case .surface:
            content
                .background(flatFill ?? TonicDS.Colors.surface, in: shape)
                .overlay(shape.strokeBorder(flatStroke ?? TonicDS.Colors.cardBorder, lineWidth: 1))
        case .smoked:
            content.background(TonicDS.Colors.console, in: shape)
        case .band(let kind):
            content.background(TonicDS.bandFill(kind), in: shape)
        }
    }
}

// MARK: - Canvas resolution

private struct TonicCanvasModifier: ViewModifier {
    /// Flat-mode fill (defaults to `canvas`; rails use `canvasSoft`).
    var flatFill: Color

    func body(content: Content) -> some View {
        // Glass on: the page is transparent so the window's Z0 chrome shows through.
        // Glass off: the flat editorial canvas, exactly as shipped.
        content.background(
            TonicGlassPolicy.shared.isGlassEnabled ? Color.clear : flatFill
        )
    }
}

// MARK: - Sheet resolution

private struct TonicSheetBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        // macOS 26 supplies native Liquid Glass for presented sheets. Only force
        // a background when transparency is reduced; custom material here would
        // compete with the system's presentation glass.
        if TonicGlassPolicy.shared.isGlassEnabled {
            content
        } else {
            content.presentationBackground(TonicDS.Colors.canvas)
        }
    }
}

// MARK: - Public API

extension View {
    /// Resolve a semantic surface layer to glass (material + wash + rim) or the
    /// legacy flat fill, per `TonicGlassPolicy`. Components adopt this internally;
    /// call sites never choose materials directly.
    func tonicSurface(
        _ layer: TonicDS.Glass.Layer,
        in shape: some InsettableShape,
        tint: Color? = nil,
        flatFill: Color? = nil,
        flatStroke: Color? = nil
    ) -> some View {
        modifier(TonicSurfaceModifier(layer: layer, shape: shape, tint: tint,
                                      flatFill: flatFill, flatStroke: flatStroke))
    }

    /// Page background: transparent under glass (desktop light shows through the
    /// window chrome), flat `Colors.canvas` otherwise.
    func tonicCanvas(flatFill: Color = TonicDS.Colors.canvas) -> some View {
        modifier(TonicCanvasModifier(flatFill: flatFill))
    }

    /// Z2 sheet background: overlay glass under a presentation, flat canvas
    /// otherwise. Apply to the root of `.sheet` content instead of a canvas fill.
    func tonicSheetBackground() -> some View {
        modifier(TonicSheetBackgroundModifier())
    }

    /// Smoked console root for NSPopover-hosted content. Under glass the smoke
    /// wash lets the popover's own system material show through (set the
    /// popover's appearance to `.darkAqua`); flat mode is the solid console.
    func tonicPopoverConsole() -> some View {
        background(
            TonicGlassPolicy.shared.isGlassEnabled
                ? TonicDS.Colors.console.opacity(TonicDS.Glass.smokedWash)
                : TonicDS.Colors.console
        )
    }
}
