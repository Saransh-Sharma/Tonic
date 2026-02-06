//
//  TonicVisualPrimitives.swift
//  Tonic
//
//  Reusable immersive background, glass, depth, and motion primitives.
//

import SwiftUI

// MARK: - Typography Primitives

struct DisplayText: View {
    let value: String

    init(_ value: String) {
        self.value = value
    }

    var body: some View {
        Text(value)
            .font(TonicTypeToken.display)
            .foregroundStyle(TonicTextToken.primary)
    }
}

struct TitleText: View {
    let value: String

    init(_ value: String) {
        self.value = value
    }

    var body: some View {
        Text(value)
            .font(TonicTypeToken.title)
            .foregroundStyle(TonicTextToken.primary)
    }
}

struct BodyText: View {
    let value: String

    init(_ value: String) {
        self.value = value
    }

    var body: some View {
        Text(value)
            .font(TonicTypeToken.body)
            .foregroundStyle(TonicTextToken.secondary)
    }
}

struct CaptionText: View {
    let value: String

    init(_ value: String) {
        self.value = value
    }

    var body: some View {
        Text(value)
            .font(TonicTypeToken.caption)
            .foregroundStyle(TonicTextToken.secondary)
    }
}

struct MicroText: View {
    let value: String

    init(_ value: String) {
        self.value = value
    }

    var body: some View {
        Text(value)
            .font(TonicTypeToken.micro)
            .foregroundStyle(TonicTextToken.tertiary)
    }
}

// MARK: - Background

struct WorldGradientRecipe {
    let center: UnitPoint

    static let `default` = WorldGradientRecipe(center: UnitPoint(x: 0.55, y: 0.35))
}

struct WorldCanvasBackground: View {
    @Environment(\.tonicTheme) private var theme
    let recipe: WorldGradientRecipe

    init(recipe: WorldGradientRecipe = .default) {
        self.recipe = recipe
    }

    var body: some View {
        ZStack {
            RadialGradient(
                gradient: Gradient(colors: [theme.canvasLight, theme.canvasMid, theme.canvasDark]),
                center: recipe.center,
                startRadius: 40,
                endRadius: 900
            )

            LinearGradient(
                colors: [theme.canvasMid.opacity(0.15), theme.canvasDark.opacity(0.35)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

struct SectionTintOverlay: ViewModifier {
    @Environment(\.tonicTheme) private var theme
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .background(theme.accent.opacity(opacity))
    }
}

// MARK: - Glass

struct GlassSurface: ViewModifier {
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                TonicGlassToken.fill
                    .allowsHitTesting(false)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(TonicGlassToken.stroke, lineWidth: 1)
                    .allowsHitTesting(false)
            )
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(
                LinearGradient(
                    colors: [TonicNeutralToken.white.opacity(0.10), .clear],
                    startPoint: .top,
                    endPoint: .center
                )
                .clipShape(RoundedRectangle(cornerRadius: radius))
                .allowsHitTesting(false)
            )
            .shadow(color: TonicShadowToken.elev2.color, radius: TonicShadowToken.elev2.blur, x: 0, y: TonicShadowToken.elev2.y)
    }
}

struct GlassCard<Content: View>: View {
    let radius: CGFloat
    @ViewBuilder let content: () -> Content

    init(radius: CGFloat = TonicRadiusToken.l, @ViewBuilder content: @escaping () -> Content) {
        self.radius = radius
        self.content = content
    }

    var body: some View {
        content()
            .padding(TonicSpaceToken.three)
            .modifier(GlassSurface(radius: radius))
    }
}

struct GlassPanel<Content: View>: View {
    let radius: CGFloat
    @ViewBuilder let content: () -> Content

    init(radius: CGFloat = TonicRadiusToken.xl, @ViewBuilder content: @escaping () -> Content) {
        self.radius = radius
        self.content = content
    }

    var body: some View {
        content()
            .padding(TonicSpaceToken.four)
            .modifier(GlassSurface(radius: radius))
    }
}

struct GlassStrokeOverlay: View {
    let radius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: radius)
            .stroke(TonicStrokeToken.subtle, lineWidth: 1)
    }
}

struct GlassInnerHighlight: View {
    let radius: CGFloat

    var body: some View {
        LinearGradient(
            colors: [TonicNeutralToken.white.opacity(0.10), .clear],
            startPoint: .top,
            endPoint: .center
        )
        .clipShape(RoundedRectangle(cornerRadius: radius))
    }
}

// MARK: - Depth

struct SoftShadowStyle: ViewModifier {
    let style: TonicShadowStyle

    func body(content: Content) -> some View {
        content
            .shadow(color: style.color, radius: style.blur, x: 0, y: style.y)
    }
}

struct HeroBloom: ViewModifier {
    @Environment(\.tonicTheme) private var theme

    func body(content: Content) -> some View {
        content
            .shadow(color: theme.glow, radius: 40, x: 0, y: 0)
    }
}

struct DepthLiftEffect: ViewModifier {
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .offset(y: hovering ? -2 : 0)
            .shadow(color: TonicShadowToken.elev1.color, radius: hovering ? TonicShadowToken.elev2.blur : TonicShadowToken.elev1.blur, x: 0, y: hovering ? TonicShadowToken.elev2.y : TonicShadowToken.elev1.y)
            .animation(.easeInOut(duration: TonicMotionToken.hover), value: hovering)
            .onHover { isHovering in
                hovering = isHovering
            }
    }
}

// MARK: - Motion

struct CalmHoverEffect: ViewModifier {
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovering ? 1.01 : 1.0)
            .animation(.easeInOut(duration: TonicMotionToken.hover), value: isHovering)
            .onHover { isHovering in
                self.isHovering = isHovering
            }
    }
}

struct PressEffect: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: TonicMotionToken.press), value: configuration.isPressed)
    }
}

struct BreathingHeroAnimation: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(reduceMotion ? 1 : (expanded ? 1.02 : 1.0))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) {
                    expanded = true
                }
            }
    }
}

struct SectionTransitionEffect: ViewModifier {
    func body(content: Content) -> some View {
        content
            .transition(.opacity)
            .animation(.easeInOut(duration: TonicMotionToken.fade), value: UUID())
    }
}

extension View {
    func sectionTint(_ opacity: Double = 0.06) -> some View {
        modifier(SectionTintOverlay(opacity: opacity))
    }

    func glassSurface(radius: CGFloat = TonicRadiusToken.l) -> some View {
        modifier(GlassSurface(radius: radius))
    }

    func softShadow(_ style: TonicShadowStyle) -> some View {
        modifier(SoftShadowStyle(style: style))
    }

    func heroBloom() -> some View {
        modifier(HeroBloom())
    }

    func depthLift() -> some View {
        modifier(DepthLiftEffect())
    }

    func calmHover() -> some View {
        modifier(CalmHoverEffect())
    }

    func breathingHero() -> some View {
        modifier(BreathingHeroAnimation())
    }
}
