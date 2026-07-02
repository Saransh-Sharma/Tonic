//
//  TonicEditorialComponents.swift
//  Tonic
//
//  The signature native surfaces of the editorial "Command Center" language
//  (see TonicDesign.md §Components). Every component is flat: hairlines, surface
//  alternation, and one permitted soft card lift do the work — no glass, no glow.
//

import SwiftUI
import AppKit

// MARK: - Interaction helpers

/// Press feedback: subtle scale, fast timing. Used by pills, chips, rows.
/// Collapses to no movement under Reduce Motion.
struct TonicPressStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.97
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? pressedScale : 1)
            .animation(reduceMotion ? nil : TonicDS.Motion.press, value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

private struct TonicFocusableControlModifier: ViewModifier {
    let radius: CGFloat
    @FocusState private var isFocused: Bool

    func body(content: Content) -> some View {
        content
            .focusable()
            .focused($isFocused)
            .tonicFocusRing(isFocused, radius: radius)
    }
}

extension View {
    /// Pointing-hand cursor on hover (Mac pointer affordance). Pass `enabled: false`
    /// for disabled controls so the cursor stays an arrow.
    func tonicPointerCursor(enabled: Bool = true) -> some View {
        self.onHover { inside in
            guard enabled else { return }
            if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }

    /// Keyboard focus ring using the editorial focus color.
    @ViewBuilder
    func tonicFocusRing(_ isFocused: Bool, radius: CGFloat) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(TonicDS.Colors.focus, lineWidth: 1.5)
                .padding(-2)
                .opacity(isFocused ? 1 : 0)
        )
    }

    /// Keyboard focus affordance for custom editorial controls.
    func tonicFocusableControl(radius: CGFloat) -> some View {
        modifier(TonicFocusableControlModifier(radius: radius))
    }

    /// Subtle hover lift for non-`DataCard` surfaces (e.g. `ScanCategoryCard`): a small
    /// scale + the single permitted soft shadow on hover. Reduce-motion collapses it.
    /// Prefer `DataCard(hoverLift:)` on actual data cards to avoid shadow stacking.
    func tonicHoverLift(enabled: Bool = true, radius: CGFloat = TonicDS.Radius.sm) -> some View {
        modifier(TonicHoverLiftModifier(enabled: enabled, radius: radius))
    }

    /// Adaptive screen gutter: tightens horizontal padding on compact windows and
    /// publishes the measured pane width to descendants via `\.tonicLayoutWidth` so
    /// rows can reflow. Replaces a hardcoded `.padding(.horizontal, …)` on a screen's
    /// scrollable content.
    func tonicScreenHPadding() -> some View {
        modifier(TonicScreenHPaddingModifier())
    }
}

/// Hover lift for arbitrary surfaces. One shadow, scale 1.01, fast timing.
private struct TonicHoverLiftModifier: ViewModifier {
    let enabled: Bool
    let radius: CGFloat
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false

    func body(content: Content) -> some View {
        let elev = TonicDS.Elevation.cardLift(scheme)
        let active = enabled && hovering && !reduceMotion
        content
            .scaleEffect(active ? 1.01 : 1)
            .shadow(color: active ? elev.color : .clear,
                    radius: active ? elev.radius : 0,
                    y: active ? elev.y : 0)
            .animation(TonicDS.Motion.press, value: hovering)
            .onHover { if enabled { hovering = $0 } }
    }
}

// MARK: - Adaptive layout plumbing

/// Pane width published down the view tree so rows/sections can reflow at compact widths.
private struct TonicLayoutWidthKey: EnvironmentKey {
    static let defaultValue: CGFloat = TonicDS.Layout.maxContentWidth
}

extension EnvironmentValues {
    /// The measured width of the current screen's content pane (see `tonicScreenHPadding`).
    var tonicLayoutWidth: CGFloat {
        get { self[TonicLayoutWidthKey.self] }
        set { self[TonicLayoutWidthKey.self] = newValue }
    }
}

private struct TonicScreenWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = TonicDS.Layout.maxContentWidth
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct TonicScreenHPaddingModifier: ViewModifier {
    @State private var width: CGFloat = TonicDS.Layout.maxContentWidth

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, TonicDS.Layout.screenHPadding(forWidth: width))
            .environment(\.tonicLayoutWidth, width)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: TonicScreenWidthPreferenceKey.self, value: geo.size.width)
                }
            )
            .onPreferenceChange(TonicScreenWidthPreferenceKey.self) { width = $0 }
    }
}

/// A true 1-px hairline rule that stays crisp at the display scale.
struct TonicHairline: View {
    var color: Color = TonicDS.Colors.hairline
    @Environment(\.displayScale) private var displayScale
    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: 1 / max(displayScale, 1))
    }
}

// MARK: - Typography atoms

/// Uppercase SF Mono technical label (CPU, MEM, °C, RPM).
struct MonoLabel: View {
    let text: String
    var color: Color = TonicDS.Colors.textMuted
    init(_ text: String, color: Color = TonicDS.Colors.textMuted) {
        self.text = text
        self.color = color
    }
    var body: some View {
        Text(text.uppercased())
            .tonicType(.monoLabel)
            .foregroundStyle(color)
    }
}

/// Large live readout: tabular metric number + baseline-aligned mono unit.
/// Use `role: .metricSmall` in compact console/popover headers.
struct Metric: View {
    let value: String
    var unit: String?
    var color: Color = TonicDS.Colors.textPrimary
    var role: TonicDS.TypeRole = .metric
    init(_ value: String, unit: String? = nil,
         color: Color = TonicDS.Colors.textPrimary, role: TonicDS.TypeRole = .metric) {
        self.value = value
        self.unit = unit
        self.color = color
        self.role = role
    }
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(value)
                .tonicType(role)
                .monospacedDigit()
                .foregroundStyle(color)
                .contentTransition(.numericText())
            if let unit {
                Text(unit)
                    .tonicType(.monoLabel)
                    .foregroundStyle(color.opacity(TonicDS.Emphasis.unit))
            }
        }
    }
}

// MARK: - Primary actions

/// The single highest-priority action per surface. Ink fill on light; white fill on
/// dark / band / console surfaces.
struct PrimaryPill: View {
    let title: String
    var systemImage: String?
    var onDark: Bool = false
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    init(_ title: String, systemImage: String? = nil, onDark: Bool = false,
         isLoading: Bool = false, isDisabled: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.onDark = onDark
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }

    private var fill: Color { onDark ? TonicDS.Colors.onDark : TonicDS.Colors.ink }
    private var fg: Color { onDark ? TonicDS.Colors.onLight : TonicDS.Colors.onDark }
    private var inactive: Bool { isLoading || isDisabled }

    var body: some View {
        Button(action: action) {
            ZStack {
                HStack(spacing: TonicDS.Space.xs) {
                    if let systemImage { Image(systemName: systemImage).font(.system(size: 12, weight: .semibold)) }
                    Text(title).tonicType(.button)
                }
                .opacity(isLoading ? 0 : 1)

                if isLoading { ProgressView().controlSize(.small).tint(fg) }
            }
            .foregroundStyle(fg)
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
            .frame(minHeight: TonicDS.Layout.minControlTarget)
            .background(fill.opacity(isDisabled ? TonicDS.Emphasis.disabled : 1),
                        in: Capsule(style: .continuous))
        }
        .buttonStyle(TonicPressStyle())
        .disabled(inactive)
        .tonicFocusableControl(radius: TonicDS.Radius.pill)
        .accessibilityLabel(title)
        .tonicPointerCursor(enabled: !inactive)
    }
}

/// Text-only companion action — rule-aligned, underlines on hover.
struct TextAction: View {
    let title: String
    var systemImage: String?
    var color: Color = TonicDS.Colors.textPrimary
    let action: () -> Void
    @State private var hovering = false

    init(_ title: String, systemImage: String? = nil,
         color: Color = TonicDS.Colors.textPrimary, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.color = color
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: TonicDS.Space.xxs) {
                if let systemImage { Image(systemName: systemImage).font(.system(size: 12, weight: .regular)) }
                Text(title).tonicType(.body)
            }
            .foregroundStyle(color)
            .underline(hovering, color: color)
            .padding(.vertical, 6)
        }
        .buttonStyle(TonicPressStyle(pressedScale: 0.98))
        .tonicFocusableControl(radius: TonicDS.Radius.xs)
        .accessibilityLabel(title)
        .onHover { hovering = $0 }
        .tonicPointerCursor()
    }
}

// MARK: - Filters & chips

/// Lightweight outlined pill for list filters / scopes / time ranges.
struct FilterPill: View {
    let title: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .tonicType(.button)
                .foregroundStyle(isActive ? TonicDS.Colors.onDark : TonicDS.Colors.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .frame(minHeight: TonicDS.Layout.minControlTarget)
                .background {
                    if isActive {
                        Capsule(style: .continuous).fill(TonicDS.Colors.ink)
                    } else {
                        Capsule(style: .continuous).strokeBorder(TonicDS.Colors.hairline, lineWidth: 1)
                    }
                }
        }
        .buttonStyle(TonicPressStyle())
        .tonicFocusableControl(radius: TonicDS.Radius.pill)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isActive ? .isSelected : AccessibilityTraits())
        .tonicPointerCursor()
    }
}

/// Taxonomy chip — THE one place brand coral appears on an interactive control.
/// Active inverts to coral fill; inactive is a coral outline on pale fill.
///
/// `.hero` is the oversized scan-taxonomy control; `.compact` fits a dense horizontal
/// category row (e.g. the Apps manager) without a 28pt face dominating the list.
struct CategoryFilterChip: View {
    enum Size { case hero, compact }

    let title: String
    let isActive: Bool
    var size: Size = .hero
    /// When true, inactive chips render neutral (ink outline) so only the active chip
    /// carries coral — keeps a dense filter row from becoming a full coral bar.
    var neutralWhenInactive: Bool = false
    let action: () -> Void

    private var role: TonicDS.TypeRole { size == .hero ? .cardHeading : .featureHeading }
    private var hPad: CGFloat { size == .hero ? 14 : TonicDS.Space.sm }
    private var vPad: CGFloat { size == .hero ? 8 : TonicDS.Space.xs }

    private var inactiveText: Color {
        neutralWhenInactive ? TonicDS.Colors.textMuted : TonicDS.Colors.accentCoral
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .tonicType(role)
                .foregroundStyle(isActive ? TonicDS.Colors.onLight : inactiveText)
                .padding(.horizontal, hPad)
                .padding(.vertical, vPad)
                .background {
                    let shape = RoundedRectangle(cornerRadius: TonicDS.Radius.sm, style: .continuous)
                    if isActive {
                        shape.fill(TonicDS.Colors.accentCoral)
                    } else if neutralWhenInactive {
                        shape.fill(Color.clear)
                            .overlay(shape.strokeBorder(TonicDS.Colors.hairline, lineWidth: 1))
                    } else {
                        shape.fill(TonicDS.Colors.accentCoral.opacity(0.06))
                            .overlay(shape.strokeBorder(TonicDS.Colors.accentCoralSoft, lineWidth: 1))
                    }
                }
        }
        .buttonStyle(TonicPressStyle(pressedScale: 0.98))
        .tonicFocusableControl(radius: TonicDS.Radius.sm)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isActive ? .isSelected : AccessibilityTraits())
        .tonicPointerCursor()
    }
}

/// The 6pt status dot — the atomic machine-state marker. Status scale only.
struct StatusDot: View {
    let color: Color
    var size: CGFloat = TonicDS.Layout.statusDotSize
    init(_ color: Color, size: CGFloat = TonicDS.Layout.statusDotSize) {
        self.color = color
        self.size = size
    }
    var body: some View {
        Circle().fill(color)
            .frame(width: size, height: size)
            .accessibilityHidden(true) // meaning is voiced by the accompanying label
    }
}

/// Small machine-state marker: status-colored dot + mono label. Status scale only.
/// Pass a `level` so VoiceOver hears the state word, not just the raw value —
/// color is never the only carrier of meaning.
struct StatusChip: View {
    let label: String
    let color: Color
    var level: TonicDS.StatusLevel?

    init(_ label: String, color: Color, level: TonicDS.StatusLevel? = nil) {
        self.label = label
        self.color = color
        self.level = level
    }

    init(_ label: String, level: TonicDS.StatusLevel) {
        self.label = label
        self.color = level.color
        self.level = level
    }

    var body: some View {
        HStack(spacing: TonicDS.Space.xxs) {
            StatusDot(color)
            Text(label.uppercased()).tonicType(.monoLabel).foregroundStyle(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .overlay(Capsule().strokeBorder(color.opacity(0.35), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(level.map { "\($0.word): \(label)" } ?? label)
    }
}

/// Editorial inline notice for non-blocking state, warnings, and operation results.
struct TonicInlineNotice: View {
    enum Tone {
        case info, success, warning, error

        var color: Color {
            switch self {
            case .info: return TonicDS.Colors.statusInfo
            case .success: return TonicDS.Colors.statusSuccess
            case .warning: return TonicDS.Colors.statusWarning
            case .error: return TonicDS.Colors.statusCritical
            }
        }

        var icon: String {
            switch self {
            case .info: return "info.circle"
            case .success: return "checkmark.circle"
            case .warning: return "exclamationmark.triangle"
            case .error: return "xmark.circle"
            }
        }
    }

    let message: String
    var tone: Tone = .info

    var body: some View {
        HStack(spacing: TonicDS.Space.xs) {
            Image(systemName: tone.icon)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(tone.color)
            Text(message)
                .tonicType(.caption)
                .foregroundStyle(TonicDS.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, TonicDS.Space.sm)
        .padding(.vertical, TonicDS.Space.xs)
        .background(TonicDS.Colors.softStone,
                    in: RoundedRectangle(cornerRadius: TonicDS.Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TonicDS.Radius.sm, style: .continuous)
                .strokeBorder(tone.color.opacity(0.28), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Banners

/// Thin near-black strip for global system states.
struct AlertBanner: View {
    let message: String
    var actionTitle: String?
    var onAction: (() -> Void)?
    var onDismiss: (() -> Void)?

    var body: some View {
        HStack(spacing: TonicDS.Space.sm) {
            Text(message).tonicType(.micro).foregroundStyle(TonicDS.Colors.onDark)
            if let actionTitle, let onAction {
                Button(action: onAction) {
                    Text(actionTitle).tonicType(.micro).foregroundStyle(TonicDS.Colors.linkBlue)
                }
                .buttonStyle(.plain)
                .tonicPointerCursor()
            }
            Spacer(minLength: 0)
            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(TonicDS.Colors.onDarkMuted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss")
                .tonicPointerCursor()
            }
        }
        .padding(.horizontal, TonicDS.Space.md)
        .frame(height: 32)
        .frame(maxWidth: .infinity)
        .background(TonicDS.Colors.inkPure)
    }
}

// MARK: - Surfaces

/// Rounded 22pt card whose body is a live visualization. Hairline + canvas chrome,
/// one permitted soft lift; all expression lives in the readout.
struct DataCard<Content: View>: View {
    var lift: Bool = false
    /// When true the card responds to hover with a subtle scale + a single deepened
    /// shadow (never a second stacked shadow). Use for tappable cards.
    var hoverLift: Bool = false
    @ViewBuilder var content: () -> Content
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false

    var body: some View {
        let elev = TonicDS.Elevation.cardLift(scheme)
        let active = hoverLift && hovering && !reduceMotion
        content()
            .padding(TonicDS.Space.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(TonicDS.Colors.surface,
                        in: RoundedRectangle(cornerRadius: TonicDS.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: TonicDS.Radius.card, style: .continuous)
                    .strokeBorder(TonicDS.Colors.cardBorder, lineWidth: 1)
            )
            .scaleEffect(active ? 1.01 : 1)
            // One shadow only — it deepens on hover; it is never stacked.
            .shadow(color: lift ? elev.color : .clear,
                    radius: lift ? (active ? elev.radius * 1.6 : elev.radius) : 0,
                    y: lift ? (active ? elev.y * 1.6 : elev.y) : 0)
            .animation(TonicDS.Motion.press, value: hovering)
            .onHover { if hoverLift { hovering = $0 } }
    }
}

/// Header row for a data card: mono label left, optional trailing control.
struct DataCardHeader<Trailing: View>: View {
    let label: String
    @ViewBuilder var trailing: () -> Trailing
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            MonoLabel(label)
            Spacer(minLength: TonicDS.Space.xs)
            trailing()
        }
    }
}

extension DataCardHeader where Trailing == EmptyView {
    init(_ label: String) { self.init(label: label, trailing: { EmptyView() }) }
}

/// The signature near-black console surface for live readouts.
struct MonitoringConsole<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        content()
            .padding(TonicDS.Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(TonicDS.Colors.console,
                        in: RoundedRectangle(cornerRadius: TonicDS.Radius.md, style: .continuous))
            .environment(\.colorScheme, .dark) // children read as on-dark by default
    }
}

/// Full-bleed deep-green / navy section band — the hero surface for modules.
struct ModuleBand<Content: View>: View {
    var band: TonicDS.Band = .green
    /// Overrides the adaptive 24/48 hero padding — use for slimmer identity/utility bands.
    var contentPadding: CGFloat? = nil
    @ViewBuilder var content: () -> Content
    @Environment(\.tonicLayoutWidth) private var layoutWidth
    var body: some View {
        content()
            .padding(contentPadding ?? (TonicDS.Layout.isCompact(layoutWidth) ? TonicDS.Space.lg : TonicDS.Space.xxxl))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(TonicDS.bandFill(band),
                        in: RoundedRectangle(cornerRadius: TonicDS.Radius.lg, style: .continuous))
            .environment(\.colorScheme, .dark)
    }
}

/// Warm soft-stone card summarizing a cleanup category or scan result.
/// Set `hoverLift` when the card is tappable so it carries a pointer affordance.
struct ScanCategoryCard<Content: View>: View {
    var hoverLift: Bool = false
    @ViewBuilder var content: () -> Content
    var body: some View {
        content()
            .padding(TonicDS.Space.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(TonicDS.Colors.softStone,
                        in: RoundedRectangle(cornerRadius: TonicDS.Radius.sm, style: .continuous))
            .tonicHoverLift(enabled: hoverLift, radius: TonicDS.Radius.sm)
    }
}

/// A settings/grouped panel container.
struct SettingsPanel<Content: View>: View {
    var title: String?
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.sm) {
            if let title { MonoLabel(title) }
            VStack(spacing: 0) { content() }
                .background(TonicDS.Colors.surface,
                            in: RoundedRectangle(cornerRadius: TonicDS.Radius.lg, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: TonicDS.Radius.lg, style: .continuous)
                        .strokeBorder(TonicDS.Colors.hairline, lineWidth: 1)
                )
        }
    }
}

// MARK: - Strips, rows, headers

/// Unboxed line of the user's hardware identity, set below the dashboard hero.
struct SystemIdentityStrip: View {
    let segments: [String]
    var body: some View {
        Text(segments.joined(separator: "  ·  "))
            .tonicType(.monoLabel)
            .foregroundStyle(TonicDS.Colors.textMuted)
    }
}

/// Rule-separated row for processes / files / apps / cleaned items.
struct SystemListRow<Leading: View, Center: View, Trailing: View>: View {
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var center: () -> Center
    @ViewBuilder var trailing: () -> Trailing
    var isSelected: Bool = false
    /// When true the trailing (metadata) column stacks below the title on compact panes.
    var reflowWhenCompact: Bool = false
    /// Dims the row and suspends hover/tap — for items that are present but unavailable.
    var isDisabled: Bool = false
    var onTap: (() -> Void)?
    @State private var hovering = false
    @FocusState private var focused: Bool
    @Environment(\.tonicLayoutWidth) private var layoutWidth

    private var isCompact: Bool {
        reflowWhenCompact && TonicDS.Layout.isCompact(layoutWidth)
    }

    var body: some View {
        Group {
            if let onTap {
                Button(action: onTap) {
                    rowContent
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Open details")
                .disabled(isDisabled)
                .tonicPointerCursor(enabled: !isDisabled)
            } else {
                rowContent
            }
        }
        .opacity(isDisabled ? TonicDS.Emphasis.disabled : 1)
    }

    @ViewBuilder
    private var rowContent: some View {
        Group {
            if isCompact {
                HStack(alignment: .top, spacing: TonicDS.Space.sm) {
                    leading()
                    VStack(alignment: .leading, spacing: TonicDS.Space.xs) {
                        center()
                        trailing()
                    }
                    Spacer(minLength: 0)
                }
            } else {
                HStack(spacing: TonicDS.Space.sm) {
                    leading()
                    center()
                    Spacer(minLength: TonicDS.Space.sm)
                    trailing()
                }
            }
        }
        .padding(.horizontal, TonicDS.Space.md)
        .padding(.vertical, isCompact ? TonicDS.Space.sm : 0)
        .frame(minHeight: TonicDS.Layout.minRowHeight)
        .background(rowFill)
        .contentShape(Rectangle())
        .onHover { if !isDisabled { hovering = $0 } }
        .focusable(onTap != nil && !isDisabled)
        .focused($focused)
        .tonicFocusRing(focused, radius: TonicDS.Radius.sm)
    }

    private var rowFill: Color {
        if isDisabled { return .clear }
        if isSelected { return TonicDS.Colors.rowHover(0.08) }
        return hovering ? TonicDS.Colors.rowHover(0.05) : .clear
    }
}

/// Title + optional subtitle + trailing actions atop each detail screen.
/// Named `TonicPageHeader` to avoid colliding with the legacy `PageHeader`
/// (which gets re-pointed to editorial styling during the flip).
struct TonicPageHeader<Trailing: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: TonicDS.Space.xxs) {
                Text(title).tonicType(.cardHeading).foregroundStyle(TonicDS.Colors.textPrimary)
                if let subtitle {
                    Text(subtitle).tonicType(.body).foregroundStyle(TonicDS.Colors.textMuted)
                }
            }
            Spacer(minLength: TonicDS.Space.md)
            trailing()
        }
    }
}

extension TonicPageHeader where Trailing == EmptyView {
    init(_ title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle, trailing: { EmptyView() })
    }
}

/// Centered thin-line glyph + title + message + optional action.
struct TonicEmptyState: View {
    let systemImage: String
    let title: String
    var message: String?
    var actionTitle: String?
    var onAction: (() -> Void)?

    var body: some View {
        VStack(spacing: TonicDS.Space.md) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .thin))
                .foregroundStyle(TonicDS.Colors.textMuted)
            VStack(spacing: TonicDS.Space.xs) {
                Text(title).tonicType(.cardHeading).foregroundStyle(TonicDS.Colors.textPrimary)
                if let message {
                    Text(message).tonicType(.caption).foregroundStyle(TonicDS.Colors.textMuted)
                        .multilineTextAlignment(.center)
                }
            }
            if let actionTitle, let onAction {
                TextAction(actionTitle, color: TonicDS.Colors.linkBlue, action: onAction)
            }
        }
        .frame(maxWidth: 360)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Text input with leading glyph + clear control. Named `TonicSearchField`
/// to avoid colliding with the legacy `SearchField`.
struct TonicSearchField: View {
    var placeholder: String = "Search"
    @Binding var text: String
    /// Pass a screen-owned FocusState binding to drive focus externally (⌘F).
    var externalFocus: FocusState<Bool>.Binding?
    @FocusState private var internalFocus: Bool

    private var focused: Bool { externalFocus?.wrappedValue ?? internalFocus }

    var body: some View {
        HStack(spacing: TonicDS.Space.xs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(TonicDS.Colors.textMuted)
            field
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(TonicDS.Colors.textMuted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
                .tonicPointerCursor()
            }
        }
        .padding(.horizontal, TonicDS.Space.sm)
        .frame(height: TonicDS.Layout.inputHeight)
        .background(TonicDS.Colors.surface,
                    in: RoundedRectangle(cornerRadius: TonicDS.Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TonicDS.Radius.sm, style: .continuous)
                .strokeBorder(TonicDS.Colors.hairline, lineWidth: 1)
        )
        .tonicFocusRing(focused, radius: TonicDS.Radius.sm)
    }

    @ViewBuilder
    private var field: some View {
        let base = TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .tonicType(.body)
            .foregroundStyle(TonicDS.Colors.textPrimary)
        if let externalFocus {
            base.focused(externalFocus)
        } else {
            base.focused($internalFocus)
        }
    }
}

// MARK: - Settings rows

/// A grouped preference row: label + optional description + trailing control.
/// Named `TonicPreferenceRow` to avoid colliding with the legacy `PreferenceRow`.
struct TonicPreferenceRow<Control: View>: View {
    let title: String
    var description: String?
    var showsDivider: Bool = true
    @ViewBuilder var control: () -> Control

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: TonicDS.Space.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).tonicType(.body).foregroundStyle(TonicDS.Colors.textPrimary)
                    if let description {
                        Text(description).tonicType(.caption).foregroundStyle(TonicDS.Colors.textMuted)
                    }
                }
                Spacer(minLength: TonicDS.Space.md)
                control()
            }
            .padding(.horizontal, TonicDS.Space.md)
            .frame(minHeight: TonicDS.Layout.minRowHeight)
            if showsDivider { TonicHairline().padding(.leading, TonicDS.Space.md) }
        }
    }
}

/// Convenience toggle preference row.
struct TonicToggleRow: View {
    let title: String
    var description: String?
    var showsDivider: Bool = true
    @Binding var isOn: Bool
    var body: some View {
        TonicPreferenceRow(title: title, description: description, showsDivider: showsDivider) {
            Toggle("", isOn: $isOn).labelsHidden().toggleStyle(.switch)
                .tint(TonicDS.Colors.ink)
                .accessibilityLabel(title)
        }
    }
}

// MARK: - Loading, progress, validation

struct TonicSkeleton: View {
    var height: CGFloat = 14
    var width: CGFloat?
    var radius: CGFloat = TonicDS.Radius.xs
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = false

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(TonicDS.Colors.rowHover(reduceMotion ? 0.08 : (phase ? 0.12 : 0.05)))
            .frame(width: width, height: height)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    phase = true
                }
            }
            .accessibilityHidden(true)
    }
}

extension View {
    func tonicSkeleton(active: Bool = true) -> some View {
        redacted(reason: active ? .placeholder : [])
            .opacity(active ? 0.62 : 1)
    }

    /// Give an already-filled placeholder shape the standard skeleton pulse.
    /// Reduce-motion collapses to a static, dimmed opacity.
    func skeleton() -> some View {
        modifier(SkeletonPulse())
    }
}

private struct SkeletonPulse: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = false

    func body(content: Content) -> some View {
        content
            .opacity(reduceMotion ? 0.5 : (phase ? 0.85 : 0.35))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    phase = true
                }
            }
            .accessibilityHidden(true)
    }
}

struct TonicProgressBar: View {
    let fraction: Double
    var color: Color?
    var height: CGFloat = 6
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var didDraw = false

    private var normalized: Double { max(0, min(1, fraction)) }
    private var fillColor: Color { color ?? TonicDS.status(forFraction: normalized) }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous).fill(TonicDS.Colors.hairline)
                Capsule(style: .continuous)
                    .fill(fillColor)
                    .frame(width: geo.size.width * (reduceMotion || didDraw ? normalized : 0))
            }
        }
        .frame(height: height)
        .onAppear {
            if reduceMotion {
                didDraw = true
            } else {
                withAnimation(TonicDS.Motion.appear) { didDraw = true }
            }
        }
        .accessibilityLabel("Progress")
        .accessibilityValue("\(Int((normalized * 100).rounded())) percent")
    }
}

struct TonicStatusArc: View {
    let fraction: Double
    var lineWidth: CGFloat = 6
    var color: Color?

    private var normalized: Double { max(0, min(1, fraction)) }
    private var strokeColor: Color { color ?? TonicDS.status(forFraction: normalized) }

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0.12, to: 0.88)
                .stroke(TonicDS.Colors.hairline, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            Circle()
                .trim(from: 0.12, to: 0.12 + (0.76 * normalized))
                .stroke(strokeColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
        }
        .rotationEffect(.degrees(90))
        .accessibilityLabel("Status")
        .accessibilityValue("\(Int((normalized * 100).rounded())) percent")
    }
}

struct TonicErrorNotice: View {
    let title: String
    var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.xs) {
            StatusChip(title, color: TonicDS.Colors.statusCritical)
            if let message {
                Text(message)
                    .tonicType(.caption)
                    .foregroundStyle(TonicDS.Colors.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(TonicDS.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TonicDS.Colors.surface,
                    in: RoundedRectangle(cornerRadius: TonicDS.Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TonicDS.Radius.sm, style: .continuous)
                .strokeBorder(TonicDS.Colors.statusCritical.opacity(0.35), lineWidth: 1)
        )
    }
}

struct TonicValidationField: View {
    let title: String
    @Binding var text: String
    var placeholder: String = ""
    var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.xs) {
            Text(title).tonicType(.caption).foregroundStyle(TonicDS.Colors.textMuted)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .tonicType(.body)
                .foregroundStyle(TonicDS.Colors.textPrimary)
                .padding(.horizontal, TonicDS.Space.sm)
                .frame(height: 34)
                .background(TonicDS.Colors.surface,
                            in: RoundedRectangle(cornerRadius: TonicDS.Radius.sm, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: TonicDS.Radius.sm, style: .continuous)
                        .strokeBorder(error == nil ? TonicDS.Colors.hairline : TonicDS.Colors.statusCritical, lineWidth: 1)
                )
            if let error {
                Text(error).tonicType(.caption).foregroundStyle(TonicDS.Colors.statusCritical)
            }
        }
    }
}
