//
//  TonicWindowChrome.swift
//  Tonic
//
//  Z0 of the Liquid Tonic model: the window itself is the glass sheet. A
//  behind-window blur pulls the desktop in as the light source; a canvas wash at
//  the user's glass intensity keeps content legible. When glass is reduced the
//  chrome collapses to the flat editorial canvas — identical to the shipped look.
//

import SwiftUI
import AppKit

// MARK: - Behind-window blur

/// `NSVisualEffectView` bridged for the window floor. SwiftUI `Material` cannot
/// blend behind the window — only AppKit reaches the desktop.
///
/// Material matters enormously here: `.underWindowBackground` is nearly opaque
/// (it's for solid window backing); `.hudWindow` is the genuinely translucent
/// tier that lets the desktop glow through — the Liquid Tonic look.
struct BehindWindowBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.material = material
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
    }
}

/// Shared desktop-glass recipe for the shell's floating surfaces (slab + rail):
/// behind-window blur + canvas wash, clipped to a shape, with the glass rim.
struct TonicDesktopGlass<S: InsettableShape>: View {
    let shape: S
    let wash: Double

    var body: some View {
        ZStack {
            BehindWindowBlur()
            TonicDS.Colors.canvas.opacity(wash)
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(TonicDS.Colors.glassStroke, lineWidth: 1))
    }
}

// MARK: - Window configuration

/// Zero-size bridge that makes the hosting `NSWindow` transparent so the
/// behind-window blur can reach the desktop. Attach once at the shell root.
struct WindowConfigurator: NSViewRepresentable {
    final class TrackingView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            configureWindow()
        }

        override func layout() {
            super.layout()
            configureWindow()
        }

        func configureWindow() {
            guard let window else { return }
            window.isOpaque = false
            window.backgroundColor = .clear
            window.titlebarAppearsTransparent = true
            window.styleMask.insert(.fullSizeContentView)
            window.isMovableByWindowBackground = true
            positionTrafficLights(in: window)
        }

        private func positionTrafficLights(in window: NSWindow) {
            let kinds: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
            let buttons = kinds.compactMap(window.standardWindowButton)
            guard let close = buttons.first, let container = close.superview else { return }

            let currentWindowX = container.convert(close.frame, to: nil).minX
            let desiredWindowX = TonicDS.Glass.Shell.slabLeadingInset
                + TonicDS.Glass.Shell.trafficLightLeadingInset
            let delta = desiredWindowX - currentWindowX
            guard abs(delta) > 0.5 else { return }

            for button in buttons {
                button.setFrameOrigin(NSPoint(x: button.frame.origin.x + delta,
                                              y: button.frame.origin.y))
            }
        }
    }

    func makeNSView(context: Context) -> TrackingView { TrackingView() }

    func updateNSView(_ nsView: TrackingView, context: Context) {
        nsView.configureWindow()
    }
}

// MARK: - Z0 chrome

/// The window floor. Replaces the flat `Colors.canvas` background at the shell
/// root: desktop blur + canvas wash under glass, plain canvas otherwise.
struct TonicWindowChrome: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Group {
            if TonicGlassPolicy.shared.isGlassEnabled {
                ZStack {
                    BehindWindowBlur()
                    TonicDS.Colors.canvas
                        .opacity(TonicDS.Glass.canvasWash(
                            AppearancePreferences.shared.glassIntensity,
                            scheme: scheme
                        ))
                }
            } else {
                TonicDS.Colors.canvas
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Glass slab

/// The app surface as a distinct rounded sheet inside a fully transparent
/// window. Its geometry remains stable when transparency is reduced; only the
/// material resolves to an opaque accessibility fallback.
enum TonicGlassSlabMetrics {
    static let cornerRadius = TonicDS.Glass.Shell.slabCornerRadius
    static let leadingGutter = TonicDS.Glass.Shell.slabLeadingInset
}

struct TonicGlassSlab<Content: View>: View {
    @ViewBuilder var content: () -> Content
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: TonicGlassSlabMetrics.cornerRadius, style: .continuous)
        content()
            .background {
                if TonicGlassPolicy.shared.isGlassEnabled {
                    TonicDesktopGlass(
                        shape: shape,
                        wash: TonicDS.Glass.canvasWash(
                            AppearancePreferences.shared.glassIntensity,
                            scheme: scheme
                        )
                    )
                } else {
                    shape.fill(TonicDS.Colors.canvas)
                        .overlay(shape.strokeBorder(TonicDS.Colors.hairline, lineWidth: 1))
                }
            }
            .clipShape(shape)
    }
}
