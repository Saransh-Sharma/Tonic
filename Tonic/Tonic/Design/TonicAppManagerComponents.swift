//
//  TonicAppManagerComponents.swift
//  Tonic
//
//  App Manager-specific primitives: hero module, item cards, command dock, and animations.
//

import SwiftUI
import AppKit

// MARK: - App Hero State

enum AppHeroState {
    case ready
    case scanning(progress: Double)
    case idle(appCount: Int, totalSize: Int64, updatesAvailable: Int)
}

// MARK: - App Hero Module

struct AppHeroModule: View {
    let state: AppHeroState
    let topAppIcons: [NSImage]

    @Environment(\.tonicTheme) private var theme

    var body: some View {
        GlassPanel(radius: TonicRadiusToken.container, variant: .raised) {
            VStack(spacing: TonicSpaceToken.two) {
                switch state {
                case .ready:
                    Image(systemName: "app.badge.checkmark")
                        .font(.system(size: 70, weight: .semibold))
                        .foregroundStyle(TonicTextToken.primary)
                        .heroBloom()
                        .breathingHero()

                    DisplayText("App Manager")
                    BodyText("Discover installed apps, manage updates, and reclaim disk space.")

                case .scanning(let progress):
                    // Hero icon
                    Image(systemName: "app.badge.checkmark")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(TonicTextToken.primary)
                        .heroBloom()
                        .breathingHero()
                        .heroSweep(active: true, radius: TonicRadiusToken.container)

                    DisplayText("Scanning Apps")
                    BodyText("Discovering installed applications...")

                    // Scanning dots
                    ScanningDotsView()

                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .tint(theme.worldToken.light)
                        .frame(maxWidth: 240)
                        .progressGlow(progress, radius: TonicRadiusToken.s)

                case .idle(let appCount, let totalSize, let updatesAvailable):
                    HStack(spacing: TonicSpaceToken.three) {
                        // Icon cluster of top apps (or fallback icon)
                        if !topAppIcons.isEmpty {
                            AppIconCluster(icons: topAppIcons)
                        } else {
                            Image(systemName: "app.badge.checkmark")
                                .font(.system(size: 36, weight: .semibold))
                                .foregroundStyle(TonicTextToken.primary)
                                .heroBloom()
                        }

                        // Counter chips
                        HStack(spacing: TonicSpaceToken.one) {
                            CounterChip(
                                title: "\(appCount) apps",
                                value: nil,
                                world: .applicationsBlue,
                                isActive: true
                            )
                            .contentTransition(.numericText())

                            CounterChip(
                                title: formatBytes(totalSize),
                                value: nil,
                                world: .cleanupGreen
                            )
                            .contentTransition(.numericText())

                            if updatesAvailable > 0 {
                                CounterChip(
                                    title: "\(updatesAvailable) updates",
                                    value: nil,
                                    world: .performanceOrange,
                                    isActive: true
                                )
                                .contentTransition(.numericText())
                            }
                        }
                        .animation(TonicMotionToken.springTap, value: appCount)
                    }
                }
            }
            .multilineTextAlignment(.center)
        }
        .pulseGlow(active: isScanning, progress: scanProgress)
    }

    private var isScanning: Bool {
        if case .scanning = state { return true }
        return false
    }

    private var scanProgress: Double {
        if case .scanning(let progress) = state { return progress }
        return 0
    }

    private var appCount: Int {
        if case .idle(let count, _, _) = state { return count }
        return 0
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

// MARK: - App Icon Cluster

private struct AppIconCluster: View {
    let icons: [NSImage]

    @State private var offsets: [CGFloat] = []

    var body: some View {
        HStack(spacing: -6) {
            ForEach(Array(icons.prefix(5).enumerated()), id: \.offset) { index, icon in
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(TonicGlassToken.stroke, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                    .offset(y: floatOffset(for: index))
                    .zIndex(Double(5 - index))
            }
        }
        .onAppear { startFloating() }
    }

    private func floatOffset(for index: Int) -> CGFloat {
        guard index < offsets.count else { return 0 }
        return offsets[index]
    }

    private func startFloating() {
        offsets = Array(repeating: CGFloat(0), count: min(icons.count, 5))
        for i in offsets.indices {
            let duration = 3.5 + Double(i) * 0.5
            withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true).delay(Double(i) * 0.3)) {
                offsets[i] = -4
            }
        }
    }
}

// MARK: - App Item Card

struct AppItemCard: View {
    let app: AppMetadata
    let isSelected: Bool
    let hasUpdate: Bool
    let isProtected: Bool
    let formattedSize: String
    let onTap: () -> Void
    let onDetail: () -> Void
    let onReveal: () -> Void

    @Environment(\.tonicTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @State private var chevronHovering = false
    @State private var checkboxPop = false
    @State private var appIcon: NSImage?

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: TonicSpaceToken.two) {
                // Checkbox
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isSelected ? theme.worldToken.light : TonicTextToken.tertiary)
                    .scaleEffect(checkboxPop ? 1.15 : 1.0)
                    .rotationEffect(.degrees(checkboxPop ? -10 : 0))
                    .animation(TonicMotionToken.springTap, value: checkboxPop)
                    .frame(width: 24)

                // App icon
                Group {
                    if let icon = appIcon {
                        Image(nsImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        Image(systemName: "app.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(TonicTextToken.tertiary)
                    }
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(TonicGlassToken.fill)
                )
                // App info
                VStack(alignment: .leading, spacing: 3) {
                    Text(app.name)
                        .font(TonicTypeToken.caption.weight(.semibold))
                        .foregroundStyle(TonicTextToken.primary)
                        .lineLimit(1)

                    Text(app.bundleIdentifier)
                        .font(TonicTypeToken.micro)
                        .foregroundStyle(TonicTextToken.tertiary)
                        .lineLimit(1)

                    if let version = app.version {
                        Text("v\(version)")
                            .font(TonicTypeToken.micro)
                            .foregroundStyle(TonicTextToken.tertiary)
                    }
                }

                Spacer()

                // Status badges
                HStack(spacing: TonicSpaceToken.one) {
                    if hasUpdate {
                        MetaBadge(style: .needsReview)
                            .updatePulseBadge()
                    }

                    if isProtected {
                        MetaBadge(style: .safe)
                    }

                    if app.totalSize > 1_073_741_824 { // > 1 GB
                        MetaBadge(style: .large)
                    }
                }

                // Size metric
                TrailingMetric(value: formattedSize, world: .applicationsBlue)

                // Detail chevron
                Button(action: onDetail) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(TonicTextToken.secondary)
                        .rotationEffect(.degrees(chevronHovering ? 15 : 0))
                        .animation(.easeInOut(duration: TonicMotionToken.fast), value: chevronHovering)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    chevronHovering = hovering
                }
                .frame(width: 24)
            }
            .padding(.horizontal, TonicSpaceToken.three)
            .padding(.vertical, TonicSpaceToken.two)
            .glassSurface(radius: TonicRadiusToken.l, variant: .base)
            .overlay(
                RoundedRectangle(cornerRadius: TonicRadiusToken.l)
                    .stroke(
                        isSelected ? theme.worldToken.light.opacity(0.4) : Color.clear,
                        lineWidth: 1.5
                    )
                    .allowsHitTesting(false)
            )
            .clipShape(RoundedRectangle(cornerRadius: TonicRadiusToken.l))
        }
        .buttonStyle(.plain)
        .depthLift()
        .contextMenu {
            Button { onReveal() } label: {
                Label("Reveal in Finder", systemImage: "folder")
            }
            Divider()
            Button { onDetail() } label: {
                Label("Show Details", systemImage: "info.circle")
            }
        }
        .onChange(of: isSelected) { _, newValue in
            checkboxPop = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                checkboxPop = false
            }
        }
        .task {
            appIcon = await loadIconAsync(for: app.path)
        }
    }

    private func loadIconAsync(for path: URL) async -> NSImage? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .default).async {
                let icon = NSWorkspace.shared.icon(forFile: path.path)
                if icon.isValid && icon.representations.count > 0 {
                    continuation.resume(returning: icon)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

// MARK: - App Item Grid Card

struct AppItemGridCard: View {
    let app: AppMetadata
    let isSelected: Bool
    let hasUpdate: Bool
    let isProtected: Bool
    let formattedSize: String
    let onTap: () -> Void
    let onDetail: () -> Void
    let onReveal: () -> Void

    @Environment(\.tonicTheme) private var theme
    @State private var appIcon: NSImage?

    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(spacing: TonicSpaceToken.one) {
                // Top row: checkbox + update badge
                HStack {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isSelected ? theme.worldToken.light : TonicTextToken.tertiary)

                    Spacer()

                    if hasUpdate {
                        MetaBadge(style: .needsReview)
                            .updatePulseBadge()
                    } else if isProtected {
                        MetaBadge(style: .safe)
                    }
                }

                // App icon
                Group {
                    if let icon = appIcon {
                        Image(nsImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        Image(systemName: "app.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(TonicTextToken.tertiary)
                    }
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(TonicGlassToken.fill)
                )

                // App name
                Text(app.name)
                    .font(TonicTypeToken.caption.weight(.semibold))
                    .foregroundStyle(TonicTextToken.primary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)

                // Version + category
                HStack(spacing: 4) {
                    if let version = app.version {
                        Text("v\(version)")
                            .font(TonicTypeToken.micro)
                            .foregroundStyle(TonicTextToken.tertiary)
                            .lineLimit(1)
                    }

                    Text(app.category.rawValue)
                        .font(TonicTypeToken.micro)
                        .foregroundStyle(theme.worldToken.light.opacity(0.8))
                        .lineLimit(1)
                }

                // Size
                Text(formattedSize)
                    .font(TonicTypeToken.micro.weight(.semibold))
                    .foregroundStyle(TonicTextToken.secondary)

                // Last used
                Text(lastUsedText)
                    .font(TonicTypeToken.micro)
                    .foregroundStyle(TonicTextToken.tertiary)
                    .lineLimit(1)

                // Size badge for large apps
                if app.totalSize > 1_073_741_824 {
                    MetaBadge(style: .large)
                }
            }
            .padding(TonicSpaceToken.two)
            .frame(maxWidth: .infinity)
            .glassSurface(radius: TonicRadiusToken.l, variant: .base)
            .overlay(
                RoundedRectangle(cornerRadius: TonicRadiusToken.l)
                    .stroke(
                        isSelected ? theme.worldToken.light.opacity(0.4) : Color.clear,
                        lineWidth: 1.5
                    )
                    .allowsHitTesting(false)
            )
            .clipShape(RoundedRectangle(cornerRadius: TonicRadiusToken.l))
        }
        .buttonStyle(.plain)
        .depthLift()
        .contextMenu {
            Button { onReveal() } label: {
                Label("Reveal in Finder", systemImage: "folder")
            }
            Divider()
            Button { onDetail() } label: {
                Label("Show Details", systemImage: "info.circle")
            }
        }
        .task {
            appIcon = await loadIconAsync(for: app.path)
        }
    }

    private var lastUsedText: String {
        guard let lastUsed = app.lastUsed else { return "Never used" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastUsed, relativeTo: Date())
    }

    private func loadIconAsync(for path: URL) async -> NSImage? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .default).async {
                let icon = NSWorkspace.shared.icon(forFile: path.path)
                if icon.isValid && icon.representations.count > 0 {
                    continuation.resume(returning: icon)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

// MARK: - App Command Dock

struct AppCommandDock: View {
    let selectedCount: Int
    let selectedSize: String
    let onUninstall: () -> Void
    let onReveal: () -> Void

    @Environment(\.tonicTheme) private var theme
    @State private var appeared = false
    @State private var counterBounce = false

    var body: some View {
        HStack(spacing: TonicSpaceToken.two) {
            // Summary text
            HStack(spacing: TonicSpaceToken.one) {
                Text("\(selectedCount) app\(selectedCount == 1 ? "" : "s") selected")
                    .font(TonicTypeToken.caption)
                    .foregroundStyle(TonicTextToken.secondary)
                    .contentTransition(.numericText())
                    .scaleEffect(counterBounce ? 1.15 : 1.0)
                    .animation(TonicMotionToken.stageCheckmarkSpring, value: counterBounce)

                Text("·")
                    .foregroundStyle(TonicTextToken.tertiary)

                Text(selectedSize)
                    .font(TonicTypeToken.caption.weight(.semibold))
                    .foregroundStyle(TonicTextToken.primary)
                    .contentTransition(.numericText())
            }
            .animation(.easeInOut(duration: TonicMotionToken.fast), value: selectedCount)

            Spacer()

            SecondaryPillButton(title: "Reveal in Finder", action: onReveal)

            PrimaryActionButton(title: "Uninstall", icon: "trash", action: onUninstall)
        }
        .padding(.horizontal, TonicSpaceToken.three)
        .padding(.vertical, TonicSpaceToken.two)
        .glassSurface(radius: TonicRadiusToken.container, variant: .raised)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .onAppear {
            withAnimation(TonicMotionToken.modalPresentSpring.delay(0.2)) {
                appeared = true
            }
        }
        .onChange(of: selectedCount) { _, _ in
            counterBounce = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                counterBounce = false
            }
        }
    }
}

// MARK: - Login Item Row

struct LoginItemRow: View {
    let item: AppMetadata
    let onTap: () -> Void

    @Environment(\.tonicTheme) private var theme
    @State private var appIcon: NSImage?

    private var itemTypeDisplay: String {
        switch item.itemType {
        case "loginItem": return "Login Item"
        case "LaunchAgent": return "Launch Agent"
        case "LaunchDaemon": return "Launch Daemon"
        default: return "Login Item"
        }
    }

    private var itemTypeColor: TonicWorld {
        switch item.itemType {
        case "LaunchAgent": return .applicationsBlue
        case "LaunchDaemon": return .protectionMagenta
        default: return .cleanupGreen
        }
    }

    private var itemBadgeIcon: String {
        switch item.itemType {
        case "LaunchAgent", "LaunchDaemon": return "gear.circle.fill"
        default: return "person.circle.fill"
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: TonicSpaceToken.two) {
                // Icon with type badge
                ZStack(alignment: .bottomTrailing) {
                    Group {
                        if let icon = appIcon {
                            Image(nsImage: icon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } else {
                            Image(systemName: "app.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(TonicTextToken.tertiary)
                        }
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(TonicGlassToken.fill)
                    )

                    Image(systemName: itemBadgeIcon)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(3)
                        .background(theme.worldToken.light)
                        .clipShape(Circle())
                        .offset(x: 4, y: 4)
                }

                // Info
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name)
                        .font(TonicTypeToken.caption.weight(.semibold))
                        .foregroundStyle(TonicTextToken.primary)
                        .lineLimit(1)

                    Text(item.bundleIdentifier)
                        .font(TonicTypeToken.micro)
                        .foregroundStyle(TonicTextToken.tertiary)
                        .lineLimit(1)
                }

                Spacer()

                // Type chip
                GlassChip(
                    title: itemTypeDisplay,
                    role: .world(itemTypeColor),
                    strength: .subtle
                )

                // Status
                GlassChip(
                    title: "Active",
                    icon: "checkmark.circle.fill",
                    role: .semantic(.success),
                    strength: .subtle
                )

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(TonicTextToken.tertiary)
            }
            .padding(.horizontal, TonicSpaceToken.three)
            .padding(.vertical, TonicSpaceToken.two)
            .glassSurface(radius: TonicRadiusToken.l, variant: .base)
            .depthLift()
        }
        .buttonStyle(.plain)
        .task {
            appIcon = await loadIconAsync(for: item.path)
        }
    }

    private func loadIconAsync(for path: URL) async -> NSImage? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let icon = NSWorkspace.shared.icon(forFile: path.path)
                if icon.isValid && icon.representations.count > 0 {
                    continuation.resume(returning: icon)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

// MARK: - Animations

/// Subtle metallic shimmer sweep across app icons on first appearance
private struct IconShimmerModifier: ViewModifier {
    @State private var xOffset: CGFloat = -60

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [.clear, TonicNeutralToken.white.opacity(0.18), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 40)
                .offset(x: xOffset)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.linear(duration: 0.8)) {
                            xOffset = 60
                        }
                    }
                }
            )
            .clipped()
    }
}

/// Continuous gentle pulse on update-available badges
private struct UpdatePulseBadgeModifier: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.08 : 1.0)
            .opacity(isPulsing ? 1.0 : 0.85)
            .onAppear {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}

/// Empty state icon gently bobs up and down
struct EmptyStateFloatModifier: ViewModifier {
    @State private var floating = false

    func body(content: Content) -> some View {
        content
            .offset(y: floating ? -6 : 6)
            .onAppear {
                withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                    floating = true
                }
            }
    }
}

/// Three dots animating sequentially during scan loading
struct ScanningDotsView: View {
    @State private var activeDot = 0

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0 ..< 3, id: \.self) { index in
                Circle()
                    .fill(TonicTextToken.secondary)
                    .frame(width: 6, height: 6)
                    .opacity(activeDot == index ? 1.0 : 0.3)
            }
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.2)) {
                    activeDot = (activeDot + 1) % 3
                }
            }
        }
    }
}

/// Summary tile with counter roll-up animation
struct SummaryTile: View {
    let title: String
    let value: String
    let icon: String
    var world: TonicWorld = .applicationsBlue

    @Environment(\.tonicTheme) private var theme

    var body: some View {
        GlassCard(radius: TonicRadiusToken.l) {
            VStack(alignment: .leading, spacing: TonicSpaceToken.one) {
                HStack(spacing: TonicSpaceToken.one) {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.worldToken.light)
                    Text(title)
                        .font(TonicTypeToken.micro)
                        .foregroundStyle(TonicTextToken.tertiary)
                }

                Text(value)
                    .font(TonicTypeToken.tileMetric)
                    .foregroundStyle(TonicTextToken.primary)
                    .contentTransition(.numericText())
                    .animation(TonicMotionToken.springTap, value: value)
            }
        }
        .depthLift()
    }
}

// MARK: - View Extensions

extension View {
    func iconShimmer() -> some View {
        modifier(IconShimmerModifier())
    }

    func updatePulseBadge() -> some View {
        modifier(UpdatePulseBadgeModifier())
    }

    func emptyStateFloat() -> some View {
        modifier(EmptyStateFloatModifier())
    }
}
