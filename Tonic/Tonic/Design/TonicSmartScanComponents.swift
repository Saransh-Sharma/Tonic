//
//  TonicSmartScanComponents.swift
//  Tonic
//
//  Reusable Smart Scan primitives and composed UI modules.
//

import SwiftUI

private struct OptionalAccessibilityIdentifier: ViewModifier {
    let identifier: String?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let identifier {
            content.accessibilityIdentifier(identifier)
        } else {
            content
        }
    }
}

private extension View {
    func optionalAccessibilityIdentifier(_ identifier: String?) -> some View {
        modifier(OptionalAccessibilityIdentifier(identifier: identifier))
    }

    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Buttons

struct PrimaryScanButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    var size: CGFloat = 84

    @Environment(\.tonicTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let style = TonicButtonTokens.style(
            variant: .primary,
            state: .default,
            colorScheme: colorScheme,
            accent: theme.accent
        )

        Button(action: action) {
            ZStack {
                Circle()
                    .fill(style.background)
                    .overlay(Circle().fill(theme.worldToken.light.opacity(colorScheme == .dark ? 0.10 : 0.06)))
                    .overlay(Circle().stroke(style.stroke, lineWidth: 1))
                    .shadow(color: theme.glowSoft.opacity(colorScheme == .dark ? 1 : 0.35), radius: 18, x: 0, y: 7)

                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(style.foreground)
            }
            .frame(width: size, height: size)
            .accessibilityLabel(title)
        }
        .buttonStyle(PressEffect(focusShape: .circle))
    }
}

struct PrimaryActionButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    var isEnabled = true

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let style = TonicButtonTokens.style(variant: .primary, colorScheme: colorScheme)

        Button(action: action) {
            HStack(spacing: TonicSpaceToken.two) {
                if let icon {
                    Image(systemName: icon)
                }
                Text(title)
                    .font(TonicTypeToken.body.weight(.semibold))
            }
            .foregroundStyle(style.foreground.opacity(isEnabled ? 1 : 0.6))
            .padding(.horizontal, TonicSpaceToken.four)
            .padding(.vertical, TonicSpaceToken.two)
            .background(style.background.opacity(isEnabled ? 1 : 0.4))
            .overlay(
                Capsule()
                    .stroke(style.stroke.opacity(isEnabled ? 1 : 0.4), lineWidth: 1)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(PressEffect(focusShape: .capsule))
        .disabled(!isEnabled)
    }
}

struct SecondaryPillButton: View {
    let title: String
    let action: () -> Void
    var accessibilityIdentifier: String? = nil
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let style = TonicButtonTokens.style(variant: .secondary, colorScheme: colorScheme)

        Button(action: action) {
            Text(title)
                .font(TonicTypeToken.caption.weight(.medium))
                .foregroundStyle(style.foreground)
                .padding(.horizontal, TonicSpaceToken.three)
                .padding(.vertical, TonicSpaceToken.two)
                .background(style.background)
                .overlay(
                    Capsule().stroke(style.stroke, lineWidth: 1)
                )
                .clipShape(Capsule())
        }
        .buttonStyle(PressEffect(focusShape: .capsule))
        .optionalAccessibilityIdentifier(accessibilityIdentifier)
    }
}

struct TertiaryGhostButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .font(TonicTypeToken.caption.weight(.semibold))
            .foregroundStyle(TonicTextToken.secondary)
    }
}

struct IconOnlyButton: View {
    let systemName: String
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let style = TonicButtonTokens.style(variant: .secondary, colorScheme: colorScheme)

        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(style.foreground)
                .frame(width: 30, height: 30)
                .background(style.background)
                .overlay(
                    RoundedRectangle(cornerRadius: TonicRadiusToken.m)
                        .stroke(style.stroke, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: TonicRadiusToken.m))
        }
        .buttonStyle(PressEffect(focusShape: .rounded(TonicRadiusToken.m)))
    }
}

// MARK: - Inputs

struct SearchField: View {
    @Binding var text: String
    var placeholder = "Search"

    var body: some View {
        HStack(spacing: TonicSpaceToken.two) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(TonicTextToken.tertiary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(TonicTypeToken.caption)
                .foregroundStyle(TonicTextToken.primary)
        }
        .padding(.horizontal, TonicSpaceToken.two)
        .padding(.vertical, TonicSpaceToken.one)
        .background(TonicGlassToken.fill)
        .overlay(RoundedRectangle(cornerRadius: TonicRadiusToken.m).stroke(TonicGlassToken.stroke, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: TonicRadiusToken.m))
    }
}

struct SortMenuButton<Option: Hashable & CaseIterable & RawRepresentable>: View where Option.RawValue == String {
    @Binding var selected: Option

    var body: some View {
        Menu {
            ForEach(Array(Option.allCases), id: \.self) { option in
                Button(option.rawValue) {
                    selected = option
                }
            }
        } label: {
            HStack(spacing: TonicSpaceToken.one) {
                Image(systemName: "arrow.up.arrow.down")
                Text(selected.rawValue)
                    .font(TonicTypeToken.caption)
            }
            .foregroundStyle(TonicTextToken.primary)
            .padding(.horizontal, TonicSpaceToken.two)
            .padding(.vertical, TonicSpaceToken.one)
            .background(TonicGlassToken.fill)
            .clipShape(RoundedRectangle(cornerRadius: TonicRadiusToken.m))
        }
        .menuStyle(.borderlessButton)
    }
}

struct SegmentedFilter<Option: Hashable & Identifiable>: View {
    let options: [Option]
    @Binding var selected: Option
    let title: (Option) -> String

    var body: some View {
        HStack(spacing: TonicSpaceToken.one) {
            ForEach(options) { option in
                Button {
                    selected = option
                } label: {
                    Text(title(option))
                        .font(TonicTypeToken.micro.weight(.semibold))
                        .foregroundStyle(selected.id == option.id ? TonicNeutralToken.white : TonicTextToken.secondary)
                        .padding(.horizontal, TonicSpaceToken.two)
                        .padding(.vertical, 6)
                        .background(selected.id == option.id ? TonicGlassToken.stroke : Color.clear)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(TonicGlassToken.fill)
        .clipShape(Capsule())
    }
}

// MARK: - Sidebar

struct SidebarSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(TonicTypeToken.micro.weight(.semibold))
            .foregroundStyle(TonicTextToken.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, TonicSpaceToken.three)
    }
}

struct SidebarBadge: View {
    let count: Int
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let status = TonicStatusPalette.style(.neutral, for: colorScheme)

        Text("\(count)")
            .font(TonicTypeToken.micro.weight(.semibold))
            .foregroundStyle(status.text)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(status.fill)
            .overlay(Capsule().stroke(status.stroke, lineWidth: 1))
            .clipShape(Capsule())
    }
}

struct SidebarWorldItem: View {
    let icon: String
    let title: String
    let isSelected: Bool
    var badgeCount: Int?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: TonicSpaceToken.two) {
                Image(systemName: icon)
                Text(title)
                    .font(TonicTypeToken.caption.weight(.semibold))
                Spacer()
                if let badgeCount {
                    SidebarBadge(count: badgeCount)
                }
            }
            .foregroundStyle(isSelected ? TonicTextToken.primary : TonicTextToken.secondary)
            .padding(.horizontal, TonicSpaceToken.three)
            .padding(.vertical, TonicSpaceToken.two)
            .background(isSelected ? TonicNeutralToken.white.opacity(0.10) : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: TonicRadiusToken.m)
                    .stroke(isSelected ? TonicStrokeToken.subtle : Color.clear, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: TonicRadiusToken.m))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Badges & Metrics

struct GlassChip: View {
    let title: String
    var icon: String? = nil
    var role: TonicChipRole = .semantic(.neutral)
    var strength: TonicChipStrength = .subtle
    var controlState: TonicControlState = .default
    var isEnabled = true

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let style = TonicChipTokens.style(
            role: role,
            strength: strength,
            colorScheme: colorScheme,
            state: controlState,
            isEnabled: isEnabled
        )
        let shape = RoundedRectangle(cornerRadius: style.radius, style: .continuous)

        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: style.iconSize, weight: .semibold))
                    .foregroundStyle(style.icon)
            }
            Text(title)
                .font(style.font)
                .kerning(style.tracking)
                .monospacedDigit()
                .foregroundStyle(style.text)
        }
        .lineLimit(1)
        .padding(.horizontal, style.paddingX)
        .padding(.vertical, style.paddingY)
        .frame(minHeight: style.height)
        .background(style.backgroundBase)
        .background(style.backgroundTint)
        .overlay(
            shape
                .stroke(style.stroke, lineWidth: style.strokeWidth)
        )
        .overlay(
            shape
                .stroke(style.strokeOverlay, lineWidth: style.strokeWidth)
        )
        .clipShape(shape)
    }
}

enum MetaBadgeStyle {
    case safe
    case needsReview
    case needsAccess
    case limitedByMacOS
    case risky
    case recommended
    case unused
    case suspicious
    case large
    case leftovers
    case store

    var text: String {
        switch self {
        case .safe: return "Safe"
        case .needsReview: return "Needs Review"
        case .needsAccess: return "Needs Access"
        case .limitedByMacOS: return "Limited by macOS"
        case .risky: return "Risky"
        case .recommended: return "Recommended"
        case .unused: return "Unused"
        case .suspicious: return "Suspicious"
        case .large: return "Large"
        case .leftovers: return "Has leftovers"
        case .store: return "From Store"
        }
    }

    var color: Color {
        switch self {
        case .safe, .store:
            return TonicStatusPalette.text(.success)
        case .needsReview, .large, .needsAccess, .limitedByMacOS:
            return TonicStatusPalette.text(.warning)
        case .risky, .suspicious:
            return TonicStatusPalette.text(.danger)
        case .recommended, .leftovers:
            return TonicStatusPalette.text(.info)
        case .unused:
            return TonicStatusPalette.text(.neutral)
        }
    }

    var chipRole: TonicChipRole {
        switch self {
        case .safe, .store:
            return .semantic(.success)
        case .needsReview, .large, .needsAccess, .limitedByMacOS:
            return .semantic(.warning)
        case .risky, .suspicious:
            return .semantic(.danger)
        case .recommended, .leftovers:
            return .semantic(.info)
        case .unused:
            return .semantic(.neutral)
        }
    }

    var chipStrength: TonicChipStrength {
        switch self {
        case .risky, .suspicious:
            return .strong
        default:
            return .subtle
        }
    }
}

struct MetaBadge: View {
    let style: MetaBadgeStyle

    var body: some View {
        GlassChip(
            title: style.text,
            role: style.chipRole,
            strength: style.chipStrength
        )
    }
}

struct SafetyBadge: View {
    let style: MetaBadgeStyle

    var body: some View {
        MetaBadge(style: style)
    }
}

struct RecommendationBadge: View {
    var body: some View {
        MetaBadge(style: .recommended)
    }
}

struct TrailingMetric: View {
    let value: String
    var world: TonicWorld? = nil

    var body: some View {
        GlassChip(
            title: value,
            role: world.map { .world($0) } ?? .semantic(.neutral),
            strength: .subtle
        )
        .contentTransition(.numericText())
        .animation(TonicMotionToken.springTap, value: value)
    }
}

struct CounterChip: View {
    let title: String
    let value: String?
    var world: TonicWorld? = nil
    var isActive = false
    var isComplete = false

    var body: some View {
        GlassChip(
            title: chipText,
            role: world.map { .world($0) } ?? .semantic(.neutral),
            strength: isActive ? .strong : .subtle,
            controlState: chipControlState
        )
        .contentTransition(.numericText())
        .scaleEffect(isActive ? 1.08 : 1)
        .animation(.easeInOut(duration: TonicMotionToken.hover), value: isActive)
        .animation(.easeInOut(duration: TonicMotionToken.fade), value: isComplete)
        .animation(TonicMotionToken.springTap, value: chipText)
    }

    private var chipText: String {
        if title.isEmpty {
            return value ?? ""
        }
        guard let value, !value.isEmpty else {
            return title
        }
        return "\(title) \(value)"
    }

    private var chipControlState: TonicControlState {
        if isActive {
            return .focused
        }
        if isComplete {
            return .hover
        }
        return .default
    }
}

// MARK: - Rows

struct RowAccessoryInfoButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "info.circle")
                .foregroundStyle(TonicTextToken.secondary)
        }
        .buttonStyle(.plain)
    }
}

enum ParentSelectionState {
    case none
    case some
    case all

    var iconName: String {
        switch self {
        case .none:
            return "square"
        case .some:
            return "minus.square.fill"
        case .all:
            return "checkmark.square.fill"
        }
    }
}

struct ExpandableSelectionChild: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String?
    let isSelected: Bool
}

struct ExpandableSelectionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let metric: String
    let selectionState: ParentSelectionState
    let isExpandable: Bool
    let isExpanded: Bool
    var badges: [MetaBadgeStyle] = []
    let children: [ExpandableSelectionChild]
    var onToggleParent: () -> Void
    var onToggleExpanded: () -> Void
    var onToggleChild: (String) -> Void

    var body: some View {
        VStack(spacing: TonicSpaceToken.one) {
            HStack(spacing: TonicSpaceToken.two) {
                Button(action: onToggleParent) {
                    Image(systemName: selectionState.iconName)
                        .foregroundStyle(TonicTextToken.primary)
                }
                .buttonStyle(.plain)

                Image(systemName: icon)
                    .foregroundStyle(TonicTextToken.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(TonicTypeToken.caption.weight(.semibold))
                        .foregroundStyle(TonicTextToken.primary)
                    Text(subtitle)
                        .font(TonicTypeToken.micro)
                        .foregroundStyle(TonicTextToken.tertiary)
                    if !badges.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(Array(badges.enumerated()), id: \.offset) { _, badge in
                                MetaBadge(style: badge)
                            }
                        }
                    }
                }

                Spacer()
                TrailingMetric(value: metric)

                if isExpandable {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(TonicTextToken.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
            }
            .padding(.horizontal, TonicSpaceToken.two)
            .padding(.vertical, TonicSpaceToken.two)
            .background(TonicGlassToken.fill)
            .overlay(RoundedRectangle(cornerRadius: TonicRadiusToken.m).stroke(TonicGlassToken.stroke, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: TonicRadiusToken.m))
            .contentShape(Rectangle())
            .onTapGesture(perform: onToggleExpanded)

            if isExpandable, isExpanded {
                VStack(spacing: 6) {
                    ForEach(children) { child in
                        ExpandableSelectionChildRow(
                            title: child.title,
                            subtitle: child.subtitle,
                            isSelected: child.isSelected,
                            onToggle: { onToggleChild(child.id) }
                        )
                    }
                }
                .padding(.leading, TonicSpaceToken.five)
            }
        }
    }
}

private struct ExpandableSelectionChildRow: View {
    let title: String
    let subtitle: String?
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: TonicSpaceToken.two) {
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundStyle(TonicTextToken.primary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(TonicTypeToken.micro.weight(.semibold))
                    .foregroundStyle(TonicTextToken.primary)
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(TonicTypeToken.micro)
                        .foregroundStyle(TonicTextToken.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.horizontal, TonicSpaceToken.two)
        .padding(.vertical, 6)
        .background(TonicGlassToken.fill.opacity(0.7))
        .overlay(
            RoundedRectangle(cornerRadius: TonicRadiusToken.s)
                .stroke(TonicGlassToken.stroke.opacity(0.7), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: TonicRadiusToken.s))
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
    }
}

struct SelectableRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let metric: String
    let isSelected: Bool
    var onSelect: () -> Void
    var onToggle: () -> Void

    var body: some View {
        HStack(spacing: TonicSpaceToken.two) {
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? TonicTextToken.primary : TonicTextToken.secondary)
            }
            .buttonStyle(.plain)

            Image(systemName: icon)
                .foregroundStyle(TonicTextToken.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(TonicTypeToken.caption.weight(.semibold))
                    .foregroundStyle(TonicTextToken.primary)
                Text(subtitle)
                    .font(TonicTypeToken.micro)
                    .foregroundStyle(TonicTextToken.tertiary)
            }

            Spacer()
            TrailingMetric(value: metric)
        }
        .padding(.horizontal, TonicSpaceToken.two)
        .padding(.vertical, TonicSpaceToken.two)
        .background(TonicGlassToken.fill)
        .overlay(RoundedRectangle(cornerRadius: TonicRadiusToken.m).stroke(TonicGlassToken.stroke, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: TonicRadiusToken.m))
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }
}

struct DrilldownRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let metric: String
    var action: () -> Void

    var body: some View {
        HStack(spacing: TonicSpaceToken.two) {
            Image(systemName: icon)
                .foregroundStyle(TonicTextToken.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(TonicTypeToken.caption.weight(.semibold))
                    .foregroundStyle(TonicTextToken.primary)
                Text(subtitle)
                    .font(TonicTypeToken.micro)
                    .foregroundStyle(TonicTextToken.tertiary)
            }

            Spacer()
            TrailingMetric(value: metric)
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(TonicTextToken.tertiary)
        }
        .padding(.horizontal, TonicSpaceToken.two)
        .padding(.vertical, TonicSpaceToken.two)
        .background(TonicGlassToken.fill)
        .overlay(RoundedRectangle(cornerRadius: TonicRadiusToken.m).stroke(TonicGlassToken.stroke, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: TonicRadiusToken.m))
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
    }
}

struct HybridRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let metric: String
    let isSelected: Bool
    var badges: [MetaBadgeStyle]
    var onSelect: () -> Void
    var onToggle: () -> Void

    var body: some View {
        HStack(spacing: TonicSpaceToken.two) {
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundStyle(TonicTextToken.primary)
            }
            .buttonStyle(.plain)

            Image(systemName: icon)
                .foregroundStyle(TonicTextToken.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(TonicTypeToken.caption.weight(.semibold))
                    .foregroundStyle(TonicTextToken.primary)
                Text(subtitle)
                    .font(TonicTypeToken.micro)
                    .foregroundStyle(TonicTextToken.tertiary)
                if !badges.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(Array(badges.enumerated()), id: \.offset) { _, badge in
                            MetaBadge(style: badge)
                        }
                    }
                }
            }

            Spacer()
            TrailingMetric(value: metric)
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(TonicTextToken.tertiary)
        }
        .padding(.horizontal, TonicSpaceToken.two)
        .padding(.vertical, TonicSpaceToken.two)
        .background(TonicGlassToken.fill)
        .overlay(RoundedRectangle(cornerRadius: TonicRadiusToken.m).stroke(TonicGlassToken.stroke, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: TonicRadiusToken.m))
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }
}

// MARK: - Shell

struct PageHeader: View {
    let title: String
    var subtitle: String?
    var showsBack: Bool = false
    var searchText: Binding<String>?
    var onBack: (() -> Void)?
    var trailing: AnyView?

    var body: some View {
        HStack(spacing: TonicSpaceToken.three) {
            if showsBack {
                IconOnlyButton(systemName: "chevron.left") {
                    onBack?()
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(TonicTypeToken.caption.weight(.semibold))
                    .foregroundStyle(TonicTextToken.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(TonicTypeToken.micro)
                        .foregroundStyle(TonicTextToken.tertiary)
                }
            }

            Spacer()

            if let searchText {
                SearchField(text: searchText, placeholder: "Search")
                    .frame(width: 200)
            }

            trailing
        }
        .padding(.horizontal, TonicSpaceToken.three)
        .padding(.vertical, TonicSpaceToken.two)
        .glassSurface(radius: TonicRadiusToken.l)
    }
}

enum StickyActionVariant {
    case remove
    case cleanUp
    case uninstall
    case run
    case disable

    var title: String {
        switch self {
        case .remove: return "Remove"
        case .cleanUp: return "Clean Up"
        case .uninstall: return "Uninstall"
        case .run: return "Run"
        case .disable: return "Disable Selected"
        }
    }

    var icon: String {
        switch self {
        case .remove: return "minus.circle.fill"
        case .cleanUp: return "trash.fill"
        case .uninstall: return "xmark.bin.fill"
        case .run: return "play.fill"
        case .disable: return "pause.fill"
        }
    }
}

struct StickyActionBar: View {
    let summary: String
    let variant: StickyActionVariant
    let enabled: Bool
    var secondaryTitle: String? = nil
    var onSecondaryAction: (() -> Void)? = nil
    var secondaryAccessibilityIdentifier: String? = nil
    let action: () -> Void

    var body: some View {
        HStack {
            Text(summary)
                .font(TonicTypeToken.caption)
                .foregroundStyle(TonicTextToken.secondary)

            Spacer()

            if let secondaryTitle, let onSecondaryAction {
                SecondaryPillButton(title: secondaryTitle, action: onSecondaryAction)
                    .optionalAccessibilityIdentifier(secondaryAccessibilityIdentifier)
            }

            PrimaryActionButton(
                title: variant.title,
                icon: variant.icon,
                action: action,
                isEnabled: enabled
            )
        }
        .padding(.horizontal, TonicSpaceToken.three)
        .padding(.vertical, TonicSpaceToken.two)
        .glassSurface(radius: TonicRadiusToken.l)
    }
}

struct LeftNavListItem: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        SidebarWorldItem(icon: "folder", title: title, isSelected: isSelected, badgeCount: count, action: action)
    }
}

struct SectionSummaryCard: View {
    let title: String
    let description: String
    let metrics: [String]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: TonicSpaceToken.two) {
                Text(title)
                    .font(TonicTypeToken.caption.weight(.semibold))
                    .foregroundStyle(TonicTextToken.primary)
                Text(description)
                    .font(TonicTypeToken.micro)
                    .foregroundStyle(TonicTextToken.tertiary)

                HStack(spacing: TonicSpaceToken.one) {
                    ForEach(metrics, id: \.self) { metric in
                        CounterChip(title: "", value: metric)
                    }
                }
            }
        }
    }
}

struct ManagerSummaryStrip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(TonicTypeToken.caption)
            .foregroundStyle(TonicTextToken.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, TonicSpaceToken.two)
            .padding(.vertical, TonicSpaceToken.one)
            .background(TonicGlassToken.fill)
            .overlay(
                RoundedRectangle(cornerRadius: TonicRadiusToken.m)
                    .stroke(TonicGlassToken.stroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: TonicRadiusToken.m))
    }
}

struct LeftNavPane<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: TonicSpaceToken.two) {
            content()
            Spacer()
        }
        .padding(TonicSpaceToken.three)
        .glassSurface(radius: TonicRadiusToken.container, variant: .sunken)
    }
}

struct MiddleSummaryPane<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: TonicSpaceToken.two) {
            content()
            Spacer()
        }
        .padding(TonicSpaceToken.three)
        .glassSurface(radius: TonicRadiusToken.container, variant: .sunken)
    }
}

struct RightItemsPane<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: TonicSpaceToken.two) {
            content()
            Spacer()
        }
        .padding(TonicSpaceToken.three)
        .glassSurface(radius: TonicRadiusToken.container, variant: .sunken)
    }
}

struct ManagerShell<Left: View, Middle: View, Right: View>: View {
    let header: AnyView
    let left: Left
    let middle: Middle
    let right: Right
    let footer: AnyView

    init(
        header: AnyView,
        @ViewBuilder left: () -> Left,
        @ViewBuilder middle: () -> Middle,
        @ViewBuilder right: () -> Right,
        footer: AnyView
    ) {
        self.header = header
        self.left = left()
        self.middle = middle()
        self.right = right()
        self.footer = footer
    }

    var body: some View {
        VStack(spacing: TonicSpaceToken.two) {
            header
            HStack(alignment: .top, spacing: TonicSpaceToken.two) {
                left
                    .frame(width: 240)
                middle
                    .frame(width: 320)
                right
                    .frame(maxWidth: .infinity)
            }
            footer
        }
    }
}

// MARK: - Hub Components

enum ScanHeroState {
    case ready
    case scanning(progress: Double)
    case results(space: String, performance: String, apps: String)
}

struct ScanHeroModule: View {
    let state: ScanHeroState
    var currentScanItem: String? = nil
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.tonicTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var completionGlowOpacity: Double = 0
    @State private var previouslyScanning = false

    var body: some View {
        GlassPanel(radius: TonicRadiusToken.container, variant: .raised) {
            VStack(spacing: TonicSpaceToken.three) {
                Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                    .font(.system(size: heroIconSize, weight: .semibold))
                    .foregroundStyle(TonicTextToken.primary)
                    .heroBloom()
                    .breathingHero()
                    .animation(TonicMotionToken.resultMetricSpring, value: heroIconSize)

                switch state {
                case .ready:
                    DisplayText("Smart Scan")
                    BodyText("Run an intelligent scan across Space, Performance, and Apps.")
                case .scanning(let progress):
                    DisplayText("Scanning")
                    ProgressBar(
                        value: progress,
                        total: 1.0,
                        color: colorScheme == .dark ? TonicNeutralToken.white.opacity(0.9) : TonicNeutralToken.black.opacity(0.84),
                        showPercentage: true
                    )
                        .frame(maxWidth: 260)
                    if let currentScanItem, !currentScanItem.isEmpty {
                        Text(currentScanItem)
                            .font(TonicTypeToken.micro.monospaced())
                            .foregroundStyle(TonicTextToken.tertiary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: 300)
                            .contentTransition(.numericText())
                            .animation(.easeInOut(duration: TonicMotionToken.fast), value: currentScanItem)
                            .accessibilityAddTraits(.updatesFrequently)
                    }
                    BodyText("We are analyzing your Mac across all pillars.")
                case .results(let space, let performance, let apps):
                    DisplayText("Scan Complete")
                    HStack(spacing: TonicSpaceToken.two) {
                        CounterChip(title: "Space", value: space, world: .cleanupGreen, isComplete: true)
                        CounterChip(title: "Perf", value: performance, world: .performanceOrange, isComplete: true)
                        CounterChip(title: "Apps", value: apps, world: .applicationsBlue, isComplete: true)
                    }
                }
            }
            .multilineTextAlignment(.center)
        }
        .overlay(
            RoundedRectangle(cornerRadius: TonicRadiusToken.container)
                .stroke(theme.worldToken.light.opacity(completionGlowOpacity), lineWidth: 2)
                .shadow(color: theme.worldToken.light.opacity(completionGlowOpacity), radius: 20, x: 0, y: 0)
                .allowsHitTesting(false)
        )
        .progressGlow(scanProgress, radius: TonicRadiusToken.container)
        .heroSweep(active: isScanning, radius: TonicRadiusToken.container)
        .onChange(of: isResults) { _, isNowResults in
            if isNowResults && previouslyScanning {
                triggerCompletionGlow()
            }
        }
        .onChange(of: isScanning) { _, scanning in
            if scanning {
                previouslyScanning = true
            }
        }
    }

    private var heroIconSize: CGFloat {
        switch state {
        case .ready: return 70
        case .scanning: return 50
        case .results: return 40
        }
    }

    private var isScanning: Bool {
        if case .scanning = state {
            return true
        }
        return false
    }

    private var isResults: Bool {
        if case .results = state {
            return true
        }
        return false
    }

    private var scanProgress: Double {
        if case .scanning(let value) = state {
            return value
        }
        return 0
    }

    private func triggerCompletionGlow() {
        guard !reduceMotion else { return }
        withAnimation(.easeIn(duration: 0.3)) {
            completionGlowOpacity = 0.40
        }
        withAnimation(.easeOut(duration: 1.2).delay(0.3)) {
            completionGlowOpacity = 0
        }
    }
}

struct ScanTimelineStepper: View {
    let stages: [String]
    let activeIndex: Int
    let completed: Set<Int>
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: TonicSpaceToken.two) {
            ForEach(Array(stages.enumerated()), id: \.offset) { index, stage in
                StageStepperItem(
                    stage: stage,
                    isActive: index == activeIndex,
                    isComplete: completed.contains(index),
                    world: worldForStage(stage),
                    reduceMotion: reduceMotion
                )
            }
        }
    }

    private func worldForStage(_ stage: String) -> TonicWorld {
        switch stage.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "space":
            return .cleanupGreen
        case "performance":
            return .performanceOrange
        case "apps":
            return .applicationsBlue
        default:
            return .smartScanPurple
        }
    }
}

private struct StageStepperItem: View {
    let stage: String
    let isActive: Bool
    let isComplete: Bool
    let world: TonicWorld
    let reduceMotion: Bool
    @State private var pulseScale: CGFloat = 1.0
    @State private var wasComplete = false

    var body: some View {
        HStack(spacing: TonicSpaceToken.one) {
            Circle()
                .fill(isComplete || isActive ? TonicNeutralToken.white : TonicNeutralToken.white.opacity(0.40))
                .frame(width: 7, height: 7)
            Text(stage)
                .font(TonicTypeToken.micro.weight(isActive ? .semibold : .regular))
                .foregroundStyle(isActive || isComplete ? TonicTextToken.primary : TonicTextToken.secondary)
        }
        .padding(.horizontal, TonicSpaceToken.two)
        .padding(.vertical, 6)
        .background(PillarWorldCanvas(world: world))
        .glassSurface(radius: 999, variant: .sunken)
        .opacity(isActive || isComplete ? 1 : 0.55)
        .scaleEffect(pulseScale)
        .onChange(of: isComplete) { _, nowComplete in
            if nowComplete && !wasComplete && !reduceMotion {
                // Stage completion pulse
                withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) {
                    pulseScale = 1.12
                }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7).delay(0.15)) {
                    pulseScale = 1.0
                }
            }
            wasComplete = nowComplete
        }
    }
}

struct LiveCounterChip: View {
    let label: String
    var value: String? = nil
    var isActive = false
    var isComplete = false

    var body: some View {
        CounterChip(
            title: label,
            value: value,
            world: worldForLabel(label),
            isActive: isActive,
            isComplete: isComplete
        )
    }

    private func worldForLabel(_ label: String) -> TonicWorld {
        switch label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "space":
            return .cleanupGreen
        case "performance":
            return .performanceOrange
        case "apps":
            return .applicationsBlue
        default:
            return .smartScanPurple
        }
    }
}

struct SmartScanCommandDock: View {
    let mode: SmartScanHubMode
    let summary: String
    let primaryEnabled: Bool
    let secondaryTitle: String?
    let onSecondaryAction: (() -> Void)?
    let action: () -> Void
    var primaryAccessibilityIdentifier: String = "smartscan.primary.action"
    var secondaryAccessibilityIdentifier: String = "smartscan.review.customize"

    @Environment(\.tonicTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dotPulsing = false

    private var primaryTitle: String {
        switch mode {
        case .ready:
            return "Run Smart Scan"
        case .scanning, .running:
            return "Stop"
        case .results:
            return "Run Smart Clean"
        }
    }

    private var primaryIcon: String {
        switch mode {
        case .ready:
            return "magnifyingglass"
        case .scanning, .running:
            return "stop.fill"
        case .results:
            return "sparkles"
        }
    }

    private var isScanning: Bool {
        mode == .scanning || mode == .running
    }

    var body: some View {
        HStack(spacing: TonicSpaceToken.two) {
            if isScanning {
                Circle()
                    .fill(theme.worldToken.light)
                    .frame(width: 6, height: 6)
                    .opacity(dotPulsing ? 1.0 : 0.4)
                    .onAppear {
                        guard !reduceMotion else {
                            dotPulsing = true
                            return
                        }
                        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                            dotPulsing = true
                        }
                    }
                    .onDisappear {
                        dotPulsing = false
                    }
            }

            Text(summary)
                .font(TonicTypeToken.caption)
                .foregroundStyle(TonicTextToken.secondary)
                .lineLimit(2)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: TonicMotionToken.fast), value: summary)

            Spacer()

            if let secondaryTitle, let onSecondaryAction {
                SecondaryPillButton(
                    title: secondaryTitle,
                    action: onSecondaryAction,
                    accessibilityIdentifier: secondaryAccessibilityIdentifier
                )
            }

            PrimaryActionButton(
                title: primaryTitle,
                icon: primaryIcon,
                action: action,
                isEnabled: primaryEnabled
            )
            .accessibilityIdentifier(primaryAccessibilityIdentifier)
        }
        .padding(.horizontal, TonicSpaceToken.four)
        .padding(.vertical, TonicSpaceToken.three)
        .glassSurface(radius: TonicRadiusToken.container, variant: .sunken)
    }
}

struct PillarSectionHeader: View {
    let title: String
    let subtitle: String
    let summary: String
    let sectionActionTitle: String
    let world: TonicWorld
    var sectionAccessibilityIdentifier: String? = nil
    let onSectionAction: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: TonicSpaceToken.two) {
            HStack(alignment: .top, spacing: TonicSpaceToken.two) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(TonicTypeToken.pillarTitle)
                        .foregroundStyle(TonicTextToken.primary)
                    Text(subtitle)
                        .font(TonicTypeToken.caption)
                        .foregroundStyle(TonicTextToken.secondary)
                        .lineLimit(1)
                    Text(summary)
                        .font(TonicTypeToken.body.weight(.semibold))
                        .foregroundStyle(TonicTextToken.primary)
                }

                Spacer()

                SecondaryPillButton(
                    title: sectionActionTitle,
                    action: onSectionAction,
                    accessibilityIdentifier: sectionAccessibilityIdentifier
                )
            }
        }
        .padding(TonicSpaceToken.three)
        .background(PillarHeaderSurface(world: world))
        .glassSurface(radius: TonicRadiusToken.container, variant: .raised)
        .softShadow(colorScheme == .dark ? TonicShadowToken.elev2 : TonicShadowToken.lightE1)
    }
}

struct MetricHeadline: View {
    let value: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(TonicTypeToken.tileMetric)
                .monospacedDigit()
                .foregroundStyle(TonicTextToken.primary)
                .contentTransition(.numericText())
                .animation(TonicMotionToken.resultCardSpring, value: value)
            Text(title)
                .font(TonicTypeToken.caption.weight(.semibold))
                .foregroundStyle(TonicTextToken.primary)
        }
    }
}

struct IconCluster: View {
    let symbols: [String]
    @Environment(\.tonicTheme) private var theme

    var body: some View {
        HStack(spacing: TonicSpaceToken.one) {
            ForEach(Array(symbols.prefix(1).enumerated()), id: \.offset) { _, symbol in
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.worldToken.light.opacity(0.85))
                    .frame(width: 28, height: 28)
                    .background(TonicGlassToken.fill)
                    .glassSurface(radius: TonicRadiusToken.m, variant: .base)
            }
        }
    }
}

struct BentoTileActions: View {
    let tileID: SmartScanTileID
    let actions: [SmartScanBentoTileActionModel]
    let onReview: (SmartScanReviewTarget) -> Void
    let reviewTarget: SmartScanReviewTarget
    let onAction: (SmartScanTileID, SmartScanTileActionKind) -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: TonicSpaceToken.one) {
            ForEach(actions) { action in
                tileActionButton(for: action)
                .disabled(!action.enabled)
                .opacity(action.enabled ? 1 : 0.45)
                .accessibilityIdentifier(buttonAccessibilityIdentifier(for: action))
            }
        }
    }

    private func buttonAccessibilityIdentifier(for action: SmartScanBentoTileActionModel) -> String {
        switch action.kind {
        case .review:
            return "smartscan.review.contributor.\(tileID.rawValue)"
        case .clean:
            return "smartscan.execute.clean.\(tileID.rawValue)"
        case .remove:
            return "smartscan.execute.remove.\(tileID.rawValue)"
        case .run:
            return "smartscan.execute.run.\(tileID.rawValue)"
        case .update:
            return "smartscan.execute.update.\(tileID.rawValue)"
        }
    }

    @ViewBuilder
    private func tileActionButton(for action: SmartScanBentoTileActionModel) -> some View {
        Button {
            if action.kind == .review {
                onReview(reviewTarget)
            } else {
                onAction(tileID, action.kind)
            }
        } label: {
            let isReview = action.kind == .review
            let style = isReview ? TonicButtonTokens.secondary(for: colorScheme) : TonicButtonTokens.primary(for: colorScheme)

            Text(action.title)
                .font(TonicTypeToken.caption.weight(.semibold))
                .foregroundStyle(style.foreground)
                .padding(.horizontal, TonicSpaceToken.two)
                .padding(.vertical, 7)
                .background(style.background)
                .overlay(
                    Capsule().stroke(style.stroke, lineWidth: 1)
                )
                .clipShape(Capsule())
        }
        .buttonStyle(PressEffect(focusShape: .capsule))
    }
}

struct BentoTile: View {
    let model: SmartScanBentoTileModel
    let world: TonicWorld
    let onReview: (SmartScanReviewTarget) -> Void
    let onAction: (SmartScanTileID, SmartScanTileActionKind) -> Void

    private var tileHeight: CGFloat {
        switch model.size {
        case .large:
            return 368
        case .wide:
            return 178
        case .small:
            return 178
        }
    }

    private var tileRadius: CGFloat {
        switch model.size {
        case .small:
            return TonicRadiusToken.l
        case .large, .wide:
            return TonicRadiusToken.xl
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TonicSpaceToken.two) {
            HStack(alignment: .top) {
                MetricHeadline(value: model.metricTitle, title: model.title)
                Spacer()
                if !model.iconSymbols.isEmpty && model.size != .large {
                    IconCluster(symbols: model.iconSymbols)
                }
            }

            Text(model.subtitle)
                .font(TonicTypeToken.body)
                .foregroundStyle(TonicTextToken.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            HStack {
                Spacer()
                BentoTileActions(
                    tileID: model.id,
                    actions: model.actions,
                    onReview: onReview,
                    reviewTarget: model.reviewTarget,
                    onAction: onAction
                )
            }
        }
        .padding(TonicSpaceToken.three)
        .frame(maxWidth: .infinity, minHeight: tileHeight, maxHeight: tileHeight, alignment: .topLeading)
        .background(BentoTileSurface(world: world))
        .glassSurface(radius: tileRadius, variant: .raised)
        .depthLift()
    }
}

struct BentoGrid: View {
    let world: TonicWorld
    let tiles: [SmartScanBentoTileModel]
    let onReview: (SmartScanReviewTarget) -> Void
    let onAction: (SmartScanTileID, SmartScanTileActionKind) -> Void

    var body: some View {
        let largeTiles = tiles.filter { $0.size == .large }
        let wideTiles = tiles.filter { $0.size == .wide }
        let smallTiles = tiles.filter { $0.size == .small }

        if let large = largeTiles.first, wideTiles.count >= 1, smallTiles.count >= 2 {
            HStack(alignment: .top, spacing: TonicSpaceToken.gridGap) {
                BentoTile(model: large, world: world, onReview: onReview, onAction: onAction)
                    .frame(maxWidth: .infinity, alignment: .top)

                VStack(spacing: TonicSpaceToken.gridGap) {
                    BentoTile(model: wideTiles[0], world: world, onReview: onReview, onAction: onAction)
                    HStack(spacing: TonicSpaceToken.gridGap) {
                        BentoTile(model: smallTiles[0], world: world, onReview: onReview, onAction: onAction)
                        BentoTile(model: smallTiles[1], world: world, onReview: onReview, onAction: onAction)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
        } else if let large = largeTiles.first, wideTiles.count >= 2 {
            HStack(alignment: .top, spacing: TonicSpaceToken.gridGap) {
                BentoTile(model: large, world: world, onReview: onReview, onAction: onAction)
                    .frame(maxWidth: .infinity, alignment: .top)

                VStack(spacing: TonicSpaceToken.gridGap) {
                    BentoTile(model: wideTiles[0], world: world, onReview: onReview, onAction: onAction)
                    BentoTile(model: wideTiles[1], world: world, onReview: onReview, onAction: onAction)
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
        } else {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: TonicSpaceToken.gridGap),
                    GridItem(.flexible(), spacing: TonicSpaceToken.gridGap)
                ],
                spacing: TonicSpaceToken.gridGap
            ) {
                ForEach(tiles) { tile in
                    BentoTile(model: tile, world: world, onReview: onReview, onAction: onAction)
                        .if(tile.size == .wide) { view in
                            view.gridCellColumns(2)
                        }
                }
            }
        }
    }
}

struct SmartScanQuickActionCard: View {
    let sheet: SmartScanQuickActionSheetState
    let progress: Double
    let summary: SmartScanRunSummary?
    let isRunning: Bool
    let onStart: () -> Void
    let onStop: () -> Void
    let onDone: () -> Void

    var body: some View {
        GlassPanel(radius: TonicRadiusToken.xl) {
            VStack(alignment: .leading, spacing: TonicSpaceToken.three) {
                Text(sheet.title)
                    .font(TonicTypeToken.title)
                    .foregroundStyle(TonicTextToken.primary)

                if let summary {
                    Text(summary.formattedSummary)
                        .font(TonicTypeToken.body)
                        .foregroundStyle(TonicTextToken.secondary)
                        .accessibilityLabel("Quick action summary: \(summary.formattedSummary)")

                    HStack {
                        Spacer()
                        PrimaryActionButton(title: "Done", icon: "checkmark", action: onDone)
                            .accessibilityIdentifier("smartscan.quickaction.done")
                    }
                } else if isRunning {
                    Text("Executing selected actions...")
                        .font(TonicTypeToken.body)
                        .foregroundStyle(TonicTextToken.secondary)

                    ProgressBar(
                        value: progress,
                        total: 1,
                        color: TonicNeutralToken.white,
                        showPercentage: true
                    )

                    HStack {
                        Spacer()
                        SecondaryPillButton(title: "Stop", action: onStop)
                            .accessibilityIdentifier("smartscan.quickaction.stop")
                    }
                } else {
                    Text(sheet.subtitle)
                        .font(TonicTypeToken.body)
                        .foregroundStyle(TonicTextToken.secondary)

                    Text("Items: \(sheet.items.count) • Estimated space: \(ByteCountFormatter.string(fromByteCount: sheet.estimatedSpace, countStyle: .file))")
                        .font(TonicTypeToken.caption)
                        .foregroundStyle(TonicTextToken.tertiary)

                    HStack {
                        SecondaryPillButton(title: "Dismiss", action: onDone)
                        Spacer()
                        PrimaryActionButton(
                            title: "Run Now",
                            icon: "play.fill",
                            action: onStart,
                            isEnabled: !sheet.items.isEmpty
                        )
                        .accessibilityIdentifier("smartscan.quickaction.run")
                    }
                }
            }
        }
        .frame(maxWidth: 520)
    }
}

struct ResultContributor: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let metric: String
}

struct ResultContributorList: View {
    let items: [ResultContributor]
    let onReviewContributor: (ResultContributor) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: TonicSpaceToken.one) {
            ForEach(items, id: \.self) { item in
                HStack(spacing: TonicSpaceToken.two) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(TonicTypeToken.caption.weight(.semibold))
                            .foregroundStyle(TonicTextToken.primary)
                            .lineLimit(1)
                        Text(item.subtitle)
                            .font(TonicTypeToken.micro)
                            .foregroundStyle(TonicTextToken.tertiary)
                            .lineLimit(1)
                    }

                    Spacer()
                    TrailingMetric(value: item.metric)
                    TertiaryGhostButton(title: "Review") {
                        onReviewContributor(item)
                    }
                    .accessibilityIdentifier("smartscan.review.contributor.\(item.id)")
                }
                .padding(.vertical, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PillarWorldCanvas: View {
    let world: TonicWorld
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            TonicCanvasTokens.fill(for: world, colorScheme: colorScheme)
            TonicCanvasTokens.tint(for: world, colorScheme: colorScheme)

            RadialGradient(
                colors: [TonicCanvasTokens.edgeGlow(for: world, colorScheme: colorScheme), .clear],
                center: .topLeading,
                startRadius: 16,
                endRadius: 320
            )

            RadialGradient(
                colors: [TonicCanvasTokens.edgeGlow(for: world, colorScheme: colorScheme).opacity(0.8), .clear],
                center: .bottomTrailing,
                startRadius: 16,
                endRadius: 320
            )
        }
        .allowsHitTesting(false)
    }
}

private struct PillarHeaderSurface: View {
    let world: TonicWorld
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            if colorScheme == .light {
                TonicNeutralToken.neutral2
                world.token.mid.opacity(0.05)
                RadialGradient(
                    colors: [world.token.light.opacity(0.10), .clear],
                    center: .topLeading,
                    startRadius: 14,
                    endRadius: 260
                )
            } else {
                PillarWorldCanvas(world: world)
                RadialGradient(
                    colors: [world.token.light.opacity(0.12), .clear],
                    center: .topLeading,
                    startRadius: 10,
                    endRadius: 300
                )
                LinearGradient(
                    colors: [.clear, TonicNeutralToken.black.opacity(0.20)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .allowsHitTesting(false)
    }
}

private struct BentoTileSurface: View {
    let world: TonicWorld
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            if colorScheme == .light {
                TonicNeutralToken.neutral3
                world.token.mid.opacity(0.04)
                RadialGradient(
                    colors: [world.token.light.opacity(0.08), .clear],
                    center: .topLeading,
                    startRadius: 12,
                    endRadius: 220
                )
            } else {
                PillarWorldCanvas(world: world)
            }
        }
        .allowsHitTesting(false)
    }
}

struct ResultPillarCard: View {
    let title: String
    let metric: String
    let summary: String
    let preview: [ResultContributor]
    let reviewTitle: String
    var world: TonicWorld? = nil
    var reviewAccessibilityIdentifier: String? = nil
    let onReviewSection: () -> Void
    let onReviewContributor: (ResultContributor) -> Void

    var body: some View {
        GlassCard(radius: TonicRadiusToken.xl, variant: .raised) {
            VStack(alignment: .leading, spacing: TonicSpaceToken.two) {
                HStack {
                    Text(title)
                        .font(TonicTypeToken.title)
                        .foregroundStyle(TonicTextToken.primary)
                    Spacer()
                    Text(metric)
                        .font(TonicTypeToken.caption.weight(.semibold))
                        .foregroundStyle(TonicTextToken.primary)
                }
                Text(summary)
                    .font(TonicTypeToken.micro)
                    .foregroundStyle(TonicTextToken.tertiary)

                ResultContributorList(items: preview, onReviewContributor: onReviewContributor)
                HStack {
                    Spacer()
                    SecondaryPillButton(title: reviewTitle, action: onReviewSection)
                        .optionalAccessibilityIdentifier(reviewAccessibilityIdentifier)
                }
            }
        }
        .background {
            if let world {
                PillarWorldCanvas(world: world)
                    .clipShape(RoundedRectangle(cornerRadius: TonicRadiusToken.container))
            }
        }
        .depthLift()
    }
}

// MARK: - Detail + Safety

struct RiskExplanationBlock: View {
    let text: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let warning = TonicStatusPalette.style(.warning, for: colorScheme)

        HStack(alignment: .top, spacing: TonicSpaceToken.two) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(warning.text)
            Text(text)
                .font(TonicTypeToken.micro)
                .foregroundStyle(TonicTextToken.secondary)
        }
        .padding(TonicSpaceToken.two)
        .background(TonicGlassToken.fill)
        .overlay(
            RoundedRectangle(cornerRadius: TonicRadiusToken.m)
                .stroke(warning.stroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: TonicRadiusToken.m))
    }
}

struct DeleteModeToggle: View {
    @Binding var permanent: Bool

    var body: some View {
        Toggle(isOn: $permanent) {
            Text(permanent ? "Delete permanently" : "Move to Trash")
                .font(TonicTypeToken.caption)
                .foregroundStyle(TonicTextToken.primary)
        }
        .toggleStyle(.switch)
    }
}

struct DetailPane: View {
    let title: String
    let subtitle: String
    let riskText: String?
    let includeExcludeTitle: String
    @Binding var include: Bool

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: TonicSpaceToken.two) {
                Text(title)
                    .font(TonicTypeToken.caption.weight(.semibold))
                    .foregroundStyle(TonicTextToken.primary)
                Text(subtitle)
                    .font(TonicTypeToken.micro)
                    .foregroundStyle(TonicTextToken.secondary)
                if let riskText {
                    RiskExplanationBlock(text: riskText)
                }
                Toggle(includeExcludeTitle, isOn: $include)
                    .toggleStyle(.switch)
                    .font(TonicTypeToken.micro)
                    .foregroundStyle(TonicTextToken.primary)
            }
        }
    }
}

struct DetailSheet<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: TonicSpaceToken.three) {
            Text(title)
                .font(TonicTypeToken.title)
                .foregroundStyle(TonicTextToken.primary)
            content()
        }
        .padding(TonicSpaceToken.four)
        .background(WorldCanvasBackground())
    }
}

struct ActionConfirmationModal: View {
    let title: String
    let message: String
    let confirmTitle: String
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: TonicSpaceToken.three) {
                Text(title)
                    .font(TonicTypeToken.title)
                    .foregroundStyle(TonicTextToken.primary)
                Text(message)
                    .font(TonicTypeToken.body)
                    .foregroundStyle(TonicTextToken.secondary)
                HStack {
                    SecondaryPillButton(title: "Cancel", action: onCancel)
                    PrimaryActionButton(title: confirmTitle, icon: "checkmark", action: onConfirm)
                }
            }
        }
    }
}

// MARK: - States

struct ScanLoadingState: View {
    let message: String

    var body: some View {
        EmptyStatePanel(icon: "hourglass", title: "Scanning", message: message)
    }
}

struct EmptyStatePanel: View {
    let icon: String
    let title: String
    let message: String
    var compact: Bool = false

    var body: some View {
        GlassCard {
            VStack(spacing: compact ? TonicSpaceToken.one : TonicSpaceToken.two) {
                Image(systemName: icon)
                    .font(.system(size: compact ? 20 : 30, weight: .semibold))
                    .foregroundStyle(TonicTextToken.secondary)
                Text(title)
                    .font(TonicTypeToken.caption.weight(.semibold))
                    .foregroundStyle(TonicTextToken.primary)
                Text(message)
                    .font(TonicTypeToken.micro)
                    .foregroundStyle(TonicTextToken.tertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(compact ? TonicSpaceToken.two : TonicSpaceToken.four)
        }
    }
}

struct PlaceholderStatePanel: View {
    let title: String
    let message: String

    var body: some View {
        EmptyStatePanel(icon: "sparkles.rectangle.stack", title: title, message: message)
    }
}

struct ErrorStatePanel: View {
    let message: String

    var body: some View {
        EmptyStatePanel(icon: "xmark.octagon.fill", title: "Something went wrong", message: message)
    }
}

struct NoSelectionState: View {
    let message: String

    var body: some View {
        EmptyStatePanel(icon: "checkmark.circle", title: "No Selection", message: message)
    }
}
