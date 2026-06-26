import SwiftUI

struct AtelierAmbientCanvas: View {
    let world: TonicWorld

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation(minimumInterval: reduceMotion ? 1.2 : 0.05)) { timeline in
                let phase = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate * 0.12
                let token = AtelierTokens.World.token(for: world)
                let dark = Color(hex: token.darkMode.darkHex)
                let mid = Color(hex: token.darkMode.midHex)
                let light = Color(hex: token.darkMode.lightHex)

                ZStack {
                    LinearGradient(
                        colors: [AtelierTokens.Color.obsidian, AtelierTokens.Color.cinder, dark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    Circle()
                        .fill(mid.opacity(0.28))
                        .frame(width: proxy.size.width * 0.56)
                        .blur(radius: 110)
                        .offset(
                            x: cos(phase) * proxy.size.width * 0.16 - proxy.size.width * 0.12,
                            y: sin(phase * 0.7) * 90 - 190
                        )

                    Circle()
                        .fill(light.opacity(0.20))
                        .frame(width: proxy.size.width * 0.48)
                        .blur(radius: 120)
                        .offset(
                            x: sin(phase * 1.1) * proxy.size.width * 0.12 + proxy.size.width * 0.22,
                            y: cos(phase * 0.8) * 100 + 130
                        )

                    LinearGradient(
                        colors: [Color.white.opacity(0.08), .clear, Color.black.opacity(0.28)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
        }
        .ignoresSafeArea()
    }
}

private struct AtelierSurfaceModifier: ViewModifier {
    let radius: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }

    // Surface fill: translucent white on dark, faint ink on light (definition comes from
    // the stroke + shadow so the card reads cleanly over a light window background).
    private var fillColor: Color {
        isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.03)
    }

    private var highlightGradient: LinearGradient {
        if isDark {
            return LinearGradient(
                colors: [Color.white.opacity(0.12), Color.white.opacity(0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        // Subtle top sheen in light mode, fading out so it never washes the card.
        return LinearGradient(
            colors: [Color.white.opacity(0.55), Color.white.opacity(0.0)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var strokeColor: Color {
        isDark ? Color.white.opacity(0.22) : Color.black.opacity(0.10)
    }

    private var shadowColor: Color {
        isDark ? Color.black.opacity(0.32) : Color.black.opacity(0.08)
    }

    private var shadowRadius: CGFloat { isDark ? 26 : 18 }
    private var shadowY: CGFloat { isDark ? 14 : 8 }

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(fillColor)
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(highlightGradient)
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(strokeColor, lineWidth: 1)
            }
            .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowY)
    }
}

private struct AtelierHoverLiftModifier: ViewModifier {
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .offset(y: hovering ? -2 : 0)
            .scaleEffect(hovering ? 1.006 : 1)
            .animation(AtelierMotion.standard, value: hovering)
            .onHover { hovering in
                self.hovering = hovering
            }
    }
}

private struct AtelierStaggerModifier: ViewModifier {
    let index: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 18)
            .scaleEffect(shown ? 1 : 0.98)
            .onAppear {
                guard !shown else { return }
                withAnimation(
                    reduceMotion
                        ? .linear(duration: 0.01)
                        : AtelierMotion.springHero.delay(Double(index) * AtelierMotion.staggerStep)
                ) {
                    shown = true
                }
            }
    }
}

extension View {
    func atelierSurface(radius: CGFloat = AtelierLayout.radiusMd) -> some View {
        modifier(AtelierSurfaceModifier(radius: radius))
    }

    func atelierHoverLift() -> some View {
        modifier(AtelierHoverLiftModifier())
    }

    func atelierStagger(_ index: Int) -> some View {
        modifier(AtelierStaggerModifier(index: index))
    }
}
