//
//  FloatingRailView.swift
//  Tonic
//
//  Detached Liquid Glass navigation. The compact five-icon rail mirrors the
//  reference composition; hovering morphs it rightward over the application
//  slab, while pinning reserves content space for the expanded labels.
//

import SwiftUI

enum RailPresentationState: Equatable, Sendable {
    case collapsed
    case hoverExpanded
    case pinnedExpanded

    static func resolve(isPointerInside: Bool, isPinned: Bool) -> Self {
        if isPinned { return .pinnedExpanded }
        return isPointerInside ? .hoverExpanded : .collapsed
    }

    var isExpanded: Bool { self != .collapsed }
}

enum RailPinPreference {
    static let key = "tonic.navigation.railPinned"

    static func isPinned(in defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: key)
    }

    static func setPinned(_ isPinned: Bool, in defaults: UserDefaults = .standard) {
        defaults.set(isPinned, forKey: key)
    }
}

struct FloatingRailView: View {
    @Binding var route: TonicRoute
    @Binding var isPinned: Bool
    let openAllTools: () -> Void

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var systemReducesMotion
    @State private var appearance = AppearancePreferences.shared
    @State private var isPointerInside = false
    @State private var hoverTask: Task<Void, Never>?

    private var presentation: RailPresentationState {
        .resolve(isPointerInside: isPointerInside, isPinned: isPinned)
    }

    private var reduceMotion: Bool {
        TonicMotionPolicy.shouldReduceMotion(
            systemReducesMotion: systemReducesMotion,
            appReducesMotion: appearance.reduceMotion
        )
    }

    private var railWidth: CGFloat {
        presentation.isExpanded
            ? TonicDS.Glass.Shell.railExpandedWidth
            : TonicDS.Glass.Shell.railCollapsedWidth
    }

    var body: some View {
        let elevation = TonicDS.Elevation.cardLift(scheme)

        VStack(spacing: 0) {
            Spacer(minLength: TonicDS.Space.md)

            GlassEffectContainer {
                railContent
                    .frame(width: railWidth)
                    .tonicSurface(
                        .chrome,
                        in: RoundedRectangle(
                            cornerRadius: presentation.isExpanded
                                ? TonicDS.Glass.Shell.railCornerRadius
                                : TonicDS.Glass.Shell.railCollapsedWidth / 2,
                            style: .continuous
                        )
                    )
            }
            .shadow(color: elevation.color, radius: elevation.radius, y: elevation.y)
            .padding(.vertical, TonicDS.Glass.Shell.railHoverCorridor)
            .padding(.trailing, TonicDS.Glass.Shell.railHoverCorridor)
            .contentShape(Rectangle())
            .onHover(perform: scheduleHoverChange)

            Spacer(minLength: TonicDS.Space.md)
        }
        .frame(width: railWidth + TonicDS.Glass.Shell.railHoverCorridor)
        .animation(reduceMotion ? .linear(duration: 0.10) : TonicDS.Motion.settle,
                   value: presentation)
        .onExitCommand {
            guard !isPinned else { return }
            hoverTask?.cancel()
            isPointerInside = false
        }
        .onDisappear { hoverTask?.cancel() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Navigation")
    }

    private var railContent: some View {
        VStack(spacing: TonicDS.Space.xxs) {
            if presentation.isExpanded {
                expandedHeader
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            ForEach(TonicHub.allCases) { hub in
                RailItem(
                    symbol: hub.symbol,
                    title: hub.title,
                    isSelected: route.hub == hub,
                    isExpanded: presentation.isExpanded
                ) {
                    route = .hub(hub)
                }
            }

            if presentation.isExpanded {
                expandedUtilities
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, TonicDS.Space.xs)
    }

    private var expandedHeader: some View {
        HStack(spacing: TonicDS.Space.sm) {
            TonicBrandAssets.appImage()
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text("Tonic")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TonicDS.Colors.textPrimary)
                Text("System control")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(TonicDS.Colors.textMuted)
            }

            Spacer(minLength: TonicDS.Space.xs)

            Button {
                isPinned.toggle()
            } label: {
                Image(systemName: isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 32, height: 32)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(isPinned ? TonicDS.Colors.brandAccent : TonicDS.Colors.textMuted)
            .tonicFocusableControl(radius: TonicDS.Radius.full)
            .help(isPinned ? "Unpin navigation" : "Pin navigation open")
            .accessibilityLabel(isPinned ? "Unpin navigation" : "Pin navigation open")
        }
        .frame(height: 44)
        .padding(.horizontal, TonicDS.Space.xs)
    }

    private var expandedUtilities: some View {
        VStack(spacing: TonicDS.Space.xxs) {
            TonicHairline(color: TonicDS.Colors.rowHover(0.15))
                .padding(.horizontal, TonicDS.Space.xs)
                .padding(.vertical, TonicDS.Space.xxs)

            RailItem(
                symbol: "square.grid.3x3",
                title: "All Tools",
                isSelected: false,
                isExpanded: true,
                shortcut: "⌘K",
                action: openAllTools
            )
            RailItem(
                symbol: "gearshape",
                title: "Settings",
                isSelected: route == .settings,
                isExpanded: true
            ) {
                route = .settings
            }

            HStack(spacing: TonicDS.Space.xs) {
                Circle()
                    .fill(TonicDS.Colors.textMuted.opacity(0.65))
                    .frame(width: 6, height: 6)
                Text(DistributionEdition.current == .direct ? "Direct Edition" : "App Store Edition")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(TonicDS.Colors.textMuted)
                Spacer()
            }
            .padding(.horizontal, TonicDS.Space.sm)
            .frame(height: 24)
            .accessibilityElement(children: .combine)
        }
    }

    private func scheduleHoverChange(_ hovering: Bool) {
        hoverTask?.cancel()
        let delay = hovering
            ? TonicDS.Glass.Shell.hoverOpenDelay
            : TonicDS.Glass.Shell.hoverCloseDelay

        hoverTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            isPointerInside = hovering
        }
    }
}

private struct RailItem: View {
    let symbol: String
    let title: String
    let isSelected: Bool
    let isExpanded: Bool
    var shortcut: String?
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: TonicDS.Space.sm) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected
                                     ? TonicDS.Colors.brandAccent
                                     : TonicDS.Colors.textMuted)
                    .frame(width: 44, height: 40)

                if isExpanded {
                    Text(title)
                        .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(TonicDS.Colors.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: TonicDS.Space.xs)
                    if let shortcut {
                        Text(shortcut)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(TonicDS.Colors.textMuted)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: isExpanded ? 12 : 22, style: .continuous)
                    .fill(isSelected
                          ? TonicDS.Colors.rowHover(0.10)
                          : (isHovering ? TonicDS.Colors.rowHover(0.05) : .clear))
            }
            .contentShape(RoundedRectangle(cornerRadius: isExpanded ? 12 : 22,
                                           style: .continuous))
        }
        .buttonStyle(.plain)
        .tonicFocusableControl(radius: isExpanded ? 12 : TonicDS.Radius.full)
        .help(isExpanded ? "" : title)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .onHover { isHovering = $0 }
        .tonicPointerCursor()
    }
}

#Preview {
    FloatingRailView(
        route: .constant(.hub(.home)),
        isPinned: .constant(false),
        openAllTools: {}
    )
    .frame(height: 620)
    .background(Color.gray)
}
