//
//  TonicVisualPrimitives.swift
//  Tonic
//
//  Reusable immersive background, glass, depth, and motion primitives.
//

import SwiftUI

private struct AnyInsettableShape: InsettableShape {
    private let pathBuilder: @Sendable (CGRect) -> Path
    private let insetBuilder: @Sendable (CGFloat) -> AnyInsettableShape

    init<S: InsettableShape & Sendable>(_ shape: S) {
        self.pathBuilder = { rect in shape.path(in: rect) }
        self.insetBuilder = { amount in AnyInsettableShape(shape.inset(by: amount)) }
    }

    func path(in rect: CGRect) -> Path {
        pathBuilder(rect)
    }

    func inset(by amount: CGFloat) -> AnyInsettableShape {
        insetBuilder(amount)
    }
}

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
            .lineSpacing(4)
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
            .lineSpacing(3)
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
            .lineSpacing(2)
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
    @Environment(\.colorScheme) private var colorScheme
    let recipe: WorldGradientRecipe

    init(recipe: WorldGradientRecipe = .default) {
        self.recipe = recipe
    }

    var body: some View {
        ZStack {
            TonicCanvasTokens.fill(for: theme.world, colorScheme: colorScheme)

            TonicCanvasTokens.tint(for: theme.world, colorScheme: colorScheme)

            RadialGradient(
                colors: [TonicCanvasTokens.edgeGlow(for: theme.world, colorScheme: colorScheme), .clear],
                center: .topLeading,
                startRadius: 20,
                endRadius: 360
            )

            RadialGradient(
                colors: [TonicCanvasTokens.edgeGlow(for: theme.world, colorScheme: colorScheme).opacity(0.85), .clear],
                center: .bottomTrailing,
                startRadius: 20,
                endRadius: 360
            )

            // Keep a subtle mid-tone wash so the world identity stays visible.
            RadialGradient(
                gradient: Gradient(colors: [theme.canvasMid.opacity(colorScheme == .dark ? 0.14 : 0.10), .clear]),
                center: recipe.center,
                startRadius: 30,
                endRadius: 680
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

struct TonicLegacyGlassSurface: ViewModifier {
    let radius: CGFloat
    let variant: TonicGlassVariant
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let style = TonicGlassToken.style(for: colorScheme, variant: variant)
        let shadow = variant == .raised ? TonicShadowToken.level2(for: colorScheme) : TonicShadowToken.level1(for: colorScheme)

        return content
            .background(style.fill)
            .overlay(
                style.vignette
                    .allowsHitTesting(false)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(style.stroke, lineWidth: 1)
                    .allowsHitTesting(false)
            )
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(
                LinearGradient(
                    colors: [style.innerHighlight, .clear],
                    startPoint: .top,
                    endPoint: .center
                )
                .clipShape(RoundedRectangle(cornerRadius: radius))
                .allowsHitTesting(false)
            )
            .shadow(color: style.shadow, radius: shadow.blur, x: 0, y: shadow.y)
    }
}

@available(macOS 26.0, *)
struct TonicLiquidGlassSurface: ViewModifier {
    let radius: CGFloat
    let variant: TonicGlassVariant
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let style = TonicGlassToken.style(for: colorScheme, variant: variant)
        let shadow = variant == .raised ? TonicShadowToken.level2(for: colorScheme) : TonicShadowToken.level1(for: colorScheme)
        let shape = RoundedRectangle(cornerRadius: radius)

        return content
            .clipShape(shape)
            .glassEffect(.regular, in: shape)
            .overlay(shape.fill(style.fill).allowsHitTesting(false))
            .overlay(shape.stroke(style.stroke, lineWidth: 1).allowsHitTesting(false))
            .shadow(color: style.shadow, radius: shadow.blur, x: 0, y: shadow.y)
    }
}

struct TonicAdaptiveGlassSurface: ViewModifier {
    let radius: CGFloat
    let variant: TonicGlassVariant
    @Environment(\.tonicGlassRenderingMode) private var renderingMode
    @Environment(\.tonicForceLegacyGlass) private var forceLegacy

    @ViewBuilder
    func body(content: Content) -> some View {
        if shouldUseLiquidGlass {
            if #available(macOS 26.0, *) {
                content.modifier(TonicLiquidGlassSurface(radius: radius, variant: variant))
            } else {
                content.modifier(TonicLegacyGlassSurface(radius: radius, variant: variant))
            }
        } else {
            content.modifier(TonicLegacyGlassSurface(radius: radius, variant: variant))
        }
    }

    private var shouldUseLiquidGlass: Bool {
        !forceLegacy && renderingMode == .liquid
    }
}

struct GlassSurface: ViewModifier {
    let radius: CGFloat
    let variant: TonicGlassVariant

    func body(content: Content) -> some View {
        content.modifier(TonicAdaptiveGlassSurface(radius: radius, variant: variant))
    }
}

struct GlassCard<Content: View>: View {
    let radius: CGFloat
    let variant: TonicGlassVariant
    @ViewBuilder let content: () -> Content

    init(
        radius: CGFloat = TonicRadiusToken.l,
        variant: TonicGlassVariant = .base,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.radius = radius
        self.variant = variant
        self.content = content
    }

    var body: some View {
        content()
            .padding(TonicSpaceToken.three)
            .modifier(GlassSurface(radius: radius, variant: variant))
    }
}

struct GlassPanel<Content: View>: View {
    let radius: CGFloat
    let variant: TonicGlassVariant
    @ViewBuilder let content: () -> Content

    init(
        radius: CGFloat = TonicRadiusToken.xl,
        variant: TonicGlassVariant = .base,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.radius = radius
        self.variant = variant
        self.content = content
    }

    var body: some View {
        content()
            .padding(TonicSpaceToken.four)
            .modifier(GlassSurface(radius: radius, variant: variant))
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
            colors: [TonicGlassToken.fill, .clear],
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
            .shadow(color: theme.glowSoft, radius: 34, x: 0, y: 0)
    }
}

struct ProgressGlowEffect: ViewModifier {
    @Environment(\.tonicTheme) private var theme
    let progress: Double
    let radius: CGFloat

    func body(content: Content) -> some View {
        let clamped = min(max(progress, 0), 1)
        let intensity = clamped > 0 ? (0.12 + (0.16 * clamped)) : 0
        let shape = RoundedRectangle(cornerRadius: radius)

        return content
            .overlay(
                shape
                    .stroke(theme.worldToken.light.opacity(intensity), lineWidth: 1.3)
                    .shadow(color: theme.worldToken.light.opacity(intensity), radius: 28, x: 0, y: 0)
                    .allowsHitTesting(false)
            )
    }
}

struct DepthLiftEffect: ViewModifier {
    @State private var hovering = false
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let resting = colorScheme == .dark ? TonicShadowToken.elev2 : TonicShadowToken.lightE1
        let lifted = colorScheme == .dark ? TonicShadowToken.elev3 : TonicShadowToken.lightE2

        content
            .offset(y: hovering ? (colorScheme == .dark ? -3 : -2) : 0)
            .scaleEffect(hovering ? 1.005 : 1.0)
            .shadow(
                color: hovering ? lifted.color : resting.color,
                radius: hovering ? lifted.blur : resting.blur,
                x: 0,
                y: hovering ? lifted.y : resting.y
            )
            .animation(.easeInOut(duration: TonicMotionToken.med), value: hovering)
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
            .animation(.easeInOut(duration: TonicMotionToken.fast), value: isHovering)
            .onHover { hovering in
                isHovering = hovering
            }
    }
}

struct PressEffect: ButtonStyle {
    enum FocusShape {
        case capsule
        case rounded(CGFloat)
        case circle
    }

    var focusShape: FocusShape = .capsule

    func makeBody(configuration: Configuration) -> some View {
        StatefulPressEffectBody(configuration: configuration, focusShape: focusShape)
    }
}

private struct StatefulPressEffectBody: View {
    let configuration: PressEffect.Configuration
    let focusShape: PressEffect.FocusShape

    @Environment(\.tonicTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false
    @FocusState private var isFocused: Bool

    private var state: TonicControlState {
        if !isEnabled { return .disabled }
        if configuration.isPressed { return .pressed }
        if isFocused { return .focused }
        if isHovering { return .hover }
        return .default
    }

    private var token: TonicControlStateToken {
        TonicButtonStateTokens.token(for: state)
    }

    var body: some View {
        configuration.label
            .brightness(token.brightnessDelta)
            .scaleEffect(token.scale)
            .opacity(token.contentOpacity)
            .overlay(
                shape
                    .stroke((colorScheme == .dark ? TonicNeutralToken.white : TonicNeutralToken.black).opacity(token.strokeBoostOpacity), lineWidth: 1)
            )
            .overlay(
                shape
                    .inset(by: -3)
                    .stroke(state == .focused ? TonicFocusToken.ring(for: theme.accent) : .clear, lineWidth: 2)
            )
            .focusable(true)
            .focusEffectDisabled()
            .focused($isFocused)
            .onHover { hovering in
                isHovering = hovering
            }
            .animation(.easeInOut(duration: TonicMotionToken.fast), value: state)
    }

    private var shape: AnyInsettableShape {
        switch focusShape {
        case .capsule:
            return AnyInsettableShape(Capsule())
        case .rounded(let cornerRadius):
            return AnyInsettableShape(RoundedRectangle(cornerRadius: cornerRadius))
        case .circle:
            return AnyInsettableShape(Circle())
        }
    }
}

struct BreathingHeroAnimation: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.tonicTheme) private var theme
    @State private var expanded = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(reduceMotion ? 1 : (expanded ? TonicMotionToken.breathingScale.upperBound : TonicMotionToken.breathingScale.lowerBound))
            .shadow(
                color: theme.glowSoft.opacity(reduceMotion ? 0.22 : (expanded ? 0.22 : 0.10)),
                radius: reduceMotion ? 32 : (expanded ? 36 : 28),
                x: 0,
                y: expanded ? 10 : 6
            )
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: TonicMotionToken.breathingDuration).repeatForever(autoreverses: true)) {
                    expanded = true
                }
            }
    }
}

struct StaggeredReveal: ViewModifier {
    let index: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
            .scaleEffect(appeared ? 1 : 0.96)
            .onAppear {
                let delay = reduceMotion ? 0 : TonicMotionToken.resultStaggerDelay * Double(index)
                withAnimation(reduceMotion ? .none : TonicMotionToken.resultCardSpring.delay(delay)) {
                    appeared = true
                }
            }
    }
}

struct CompletionBurst: ViewModifier {
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.tonicTheme) private var theme
    @State private var burst = false

    func body(content: Content) -> some View {
        content
            .overlay(
                Circle()
                    .fill(theme.worldToken.light.opacity(burst ? 0.0 : 0.40))
                    .scaleEffect(burst ? 2.5 : 0.8)
                    .opacity(burst ? 0 : 1)
                    .allowsHitTesting(false)
            )
            .onChange(of: active) { _, isActive in
                guard isActive, !reduceMotion else { return }
                burst = false
                withAnimation(.easeOut(duration: 0.6)) {
                    burst = true
                }
            }
    }
}

struct PulseGlow: ViewModifier {
    let active: Bool
    let progress: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.tonicTheme) private var theme
    @State private var pulsing = false

    func body(content: Content) -> some View {
        let baseOpacity = 0.08 + (0.18 * min(max(progress, 0), 1))
        let pulseOffset = pulsing ? TonicMotionToken.scanPulseAmplitude : -TonicMotionToken.scanPulseAmplitude
        let glowOpacity = reduceMotion ? baseOpacity : (baseOpacity + pulseOffset)
        let glowRadius = 20 + (20 * min(max(progress, 0), 1))

        content
            .shadow(
                color: theme.worldToken.light.opacity(active ? glowOpacity : 0),
                radius: active ? glowRadius : 0,
                x: 0, y: 0
            )
            .onAppear {
                guard active, !reduceMotion else { return }
                withAnimation(.easeInOut(duration: TonicMotionToken.scanPulseDuration).repeatForever(autoreverses: true)) {
                    pulsing = true
                }
            }
            .onChange(of: active) { _, isActive in
                if !isActive {
                    pulsing = false
                    return
                }
                guard !reduceMotion else { return }
                pulsing = false
                withAnimation(.easeInOut(duration: TonicMotionToken.scanPulseDuration).repeatForever(autoreverses: true)) {
                    pulsing = true
                }
            }
    }
}

struct HeroHighlightSweep: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let active: Bool
    let radius: CGFloat?
    @State private var xOffset: CGFloat = -280

    func body(content: Content) -> some View {
        let swept = content
            .overlay {
                if active && !reduceMotion {
                    LinearGradient(
                        colors: [.clear, TonicNeutralToken.white.opacity(0.12), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: 180)
                    .rotationEffect(.degrees(18))
                    .offset(x: xOffset)
                    .onAppear {
                        xOffset = -280
                        withAnimation(.linear(duration: 3.4).repeatForever(autoreverses: false)) {
                            xOffset = 280
                        }
                    }
                }
            }

        if let radius {
            swept.clipShape(RoundedRectangle(cornerRadius: radius))
        } else {
            swept.clipped()
        }
    }
}

struct SectionTransitionEffect: ViewModifier {
    func body(content: Content) -> some View {
        content
            .transition(.opacity)
            .animation(.easeInOut(duration: TonicMotionToken.med), value: UUID())
    }
}

extension View {
    func sectionTint(_ opacity: Double = 0.06) -> some View {
        modifier(SectionTintOverlay(opacity: opacity))
    }

    func glassSurface(radius: CGFloat = TonicRadiusToken.l, variant: TonicGlassVariant = .base) -> some View {
        modifier(GlassSurface(radius: radius, variant: variant))
    }

    func softShadow(_ style: TonicShadowStyle) -> some View {
        modifier(SoftShadowStyle(style: style))
    }

    func heroBloom() -> some View {
        modifier(HeroBloom())
    }

    func progressGlow(_ progress: Double, radius: CGFloat = TonicRadiusToken.xl) -> some View {
        modifier(ProgressGlowEffect(progress: progress, radius: radius))
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

    func heroSweep(active: Bool, radius: CGFloat? = nil) -> some View {
        modifier(HeroHighlightSweep(active: active, radius: radius))
    }

    func staggeredReveal(index: Int) -> some View {
        modifier(StaggeredReveal(index: index))
    }

    func completionBurst(active: Bool) -> some View {
        modifier(CompletionBurst(active: active))
    }

    func pulseGlow(active: Bool, progress: Double) -> some View {
        modifier(PulseGlow(active: active, progress: progress))
    }
}
