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
}

// MARK: - Buttons

struct PrimaryScanButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    var size: CGFloat = 84

    @Environment(\.tonicTheme) private var theme

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [theme.worldToken.light, theme.worldToken.mid],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(Circle().stroke(TonicNeutralToken.white.opacity(0.28), lineWidth: 1))
                    .shadow(color: theme.glow, radius: 20, x: 0, y: 8)

                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(TonicNeutralToken.white)
            }
            .frame(width: size, height: size)
            .accessibilityLabel(title)
        }
        .buttonStyle(PressEffect())
    }
}

struct PrimaryActionButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    var isEnabled = true

    @Environment(\.tonicTheme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: TonicSpaceToken.two) {
                if let icon {
                    Image(systemName: icon)
                }
                Text(title)
                    .font(TonicTypeToken.body.weight(.semibold))
            }
            .foregroundStyle(TonicNeutralToken.white.opacity(isEnabled ? 1 : 0.6))
            .padding(.horizontal, TonicSpaceToken.four)
            .padding(.vertical, TonicSpaceToken.two)
            .background(theme.accent.opacity(isEnabled ? 0.95 : 0.30))
            .clipShape(Capsule())
        }
        .buttonStyle(PressEffect())
        .disabled(!isEnabled)
    }
}

struct SecondaryPillButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(TonicTypeToken.caption.weight(.medium))
                .foregroundStyle(TonicTextToken.primary)
                .padding(.horizontal, TonicSpaceToken.three)
                .padding(.vertical, TonicSpaceToken.two)
                .background(TonicNeutralToken.white.opacity(0.10))
                .overlay(
                    Capsule().stroke(TonicStrokeToken.subtle, lineWidth: 1)
                )
                .clipShape(Capsule())
        }
        .buttonStyle(PressEffect())
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

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(TonicTextToken.primary)
                .frame(width: 30, height: 30)
                .background(TonicNeutralToken.white.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: TonicRadiusToken.m))
        }
        .buttonStyle(PressEffect())
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
        .background(TonicNeutralToken.white.opacity(0.10))
        .overlay(RoundedRectangle(cornerRadius: TonicRadiusToken.m).stroke(TonicStrokeToken.subtle, lineWidth: 1))
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
            .background(TonicNeutralToken.white.opacity(0.10))
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
                        .background(selected.id == option.id ? TonicNeutralToken.white.opacity(0.18) : Color.clear)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(TonicNeutralToken.white.opacity(0.10))
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

    var body: some View {
        Text("\(count)")
            .font(TonicTypeToken.micro.weight(.semibold))
            .foregroundStyle(TonicTextToken.primary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(TonicNeutralToken.white.opacity(0.14))
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

enum MetaBadgeStyle {
    case safe
    case needsReview
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
        case .safe: return .green
        case .needsReview: return .orange
        case .risky: return .red
        case .recommended: return .blue
        case .unused: return .gray
        case .suspicious: return .pink
        case .large: return .purple
        case .leftovers: return .cyan
        case .store: return .mint
        }
    }
}

struct MetaBadge: View {
    let style: MetaBadgeStyle

    var body: some View {
        Text(style.text)
            .font(TonicTypeToken.micro.weight(.semibold))
            .foregroundStyle(TonicNeutralToken.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(style.color.opacity(0.70))
            .clipShape(Capsule())
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

    var body: some View {
        Text(value)
            .font(TonicTypeToken.micro.weight(.semibold))
            .foregroundStyle(TonicTextToken.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(TonicNeutralToken.white.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: TonicRadiusToken.s))
    }
}

struct CounterChip: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: TonicSpaceToken.one) {
            Text(title)
                .font(TonicTypeToken.micro)
                .foregroundStyle(TonicTextToken.tertiary)
            Text(value)
                .font(TonicTypeToken.micro.weight(.semibold))
                .foregroundStyle(TonicTextToken.primary)
        }
        .padding(.horizontal, TonicSpaceToken.two)
        .padding(.vertical, 6)
        .background(TonicNeutralToken.white.opacity(0.10))
        .clipShape(Capsule())
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
        .background(TonicNeutralToken.white.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: TonicRadiusToken.m).stroke(TonicStrokeToken.subtle, lineWidth: 1))
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
        .background(TonicNeutralToken.white.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: TonicRadiusToken.m).stroke(TonicStrokeToken.subtle, lineWidth: 1))
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
        .background(TonicNeutralToken.white.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: TonicRadiusToken.m).stroke(TonicStrokeToken.subtle, lineWidth: 1))
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
            .background(TonicNeutralToken.white.opacity(0.10))
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
        .glassSurface(radius: TonicRadiusToken.l)
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
        .glassSurface(radius: TonicRadiusToken.l)
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
        .glassSurface(radius: TonicRadiusToken.l)
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

    var body: some View {
        GlassPanel(radius: TonicRadiusToken.xl) {
            VStack(spacing: TonicSpaceToken.three) {
                Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                    .font(.system(size: 70, weight: .semibold))
                    .foregroundStyle(TonicTextToken.primary)
                    .heroBloom()
                    .breathingHero()

                switch state {
                case .ready:
                    DisplayText("Smart Scan")
                    BodyText("Run an intelligent scan across Space, Performance, and Apps.")
                case .scanning(let progress):
                    DisplayText("Scanning")
                    ProgressBar(value: progress, total: 1.0, color: TonicNeutralToken.white, showPercentage: true)
                        .frame(maxWidth: 260)
                    BodyText("We are analyzing your Mac across all pillars.")
                case .results(let space, let performance, let apps):
                    DisplayText("Scan Complete")
                    BodyText("Reclaim \(space) • Improve startup by \(performance) • Review \(apps)")
                }
            }
            .multilineTextAlignment(.center)
        }
    }
}

struct ScanTimelineStepper: View {
    let stages: [String]
    let activeIndex: Int
    let completed: Set<Int>

    var body: some View {
        HStack(spacing: TonicSpaceToken.two) {
            ForEach(Array(stages.enumerated()), id: \.offset) { index, stage in
                HStack(spacing: TonicSpaceToken.one) {
                    Circle()
                        .fill(completed.contains(index) ? TonicNeutralToken.white : (index == activeIndex ? TonicNeutralToken.white.opacity(0.75) : TonicNeutralToken.white.opacity(0.25)))
                        .frame(width: 8, height: 8)
                    Text(stage)
                        .font(TonicTypeToken.micro.weight(index == activeIndex ? .semibold : .regular))
                        .foregroundStyle(index == activeIndex ? TonicTextToken.primary : TonicTextToken.tertiary)
                }
            }
        }
    }
}

struct LiveCounterChip: View {
    let label: String
    let value: String

    var body: some View {
        CounterChip(title: label, value: value)
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

    var body: some View {
        let token = world.token
        ZStack {
            RadialGradient(
                gradient: Gradient(colors: [token.light, token.mid, token.dark]),
                center: UnitPoint(x: 0.55, y: 0.35),
                startRadius: 24,
                endRadius: 520
            )

            LinearGradient(
                colors: [token.mid.opacity(0.15), token.dark.opacity(0.35)],
                startPoint: .top,
                endPoint: .bottom
            )
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
        GlassCard(radius: TonicRadiusToken.xl) {
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
                    .clipShape(RoundedRectangle(cornerRadius: TonicRadiusToken.xl))
            }
        }
        .depthLift()
    }
}

// MARK: - Detail + Safety

struct RiskExplanationBlock: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: TonicSpaceToken.two) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(text)
                .font(TonicTypeToken.micro)
                .foregroundStyle(TonicTextToken.secondary)
        }
        .padding(TonicSpaceToken.two)
        .background(TonicNeutralToken.white.opacity(0.10))
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

    var body: some View {
        GlassCard {
            VStack(spacing: TonicSpaceToken.two) {
                Image(systemName: icon)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(TonicTextToken.secondary)
                Text(title)
                    .font(TonicTypeToken.caption.weight(.semibold))
                    .foregroundStyle(TonicTextToken.primary)
                Text(message)
                    .font(TonicTypeToken.micro)
                    .foregroundStyle(TonicTextToken.tertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(TonicSpaceToken.four)
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
