//
//  TonicWidgetComponents.swift
//  Tonic
//
//  Widget-specific primitives for the Menu Bar Widgets screen.
//

import SwiftUI

// MARK: - Widget Hero Module

enum WidgetHeroState {
    case idle
    case active(count: Int)
}

struct WidgetHeroModule: View {
    let state: WidgetHeroState
    let activeIcons: [String]

    @Environment(\.tonicTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var countBump = false

    var body: some View {
        GlassPanel(radius: TonicRadiusToken.container, variant: .raised) {
            VStack(spacing: TonicSpaceToken.three) {
                Image(systemName: "menubar.dock.rectangle.badge.record")
                    .font(.system(size: heroIconSize, weight: .semibold))
                    .foregroundStyle(TonicTextToken.primary)
                    .heroBloom()
                    .breathingHero()
                    .scaleEffect(countBump ? 1.05 : 1.0)
                    .animation(TonicMotionToken.stageCheckmarkSpring, value: countBump)

                switch state {
                case .idle:
                    DisplayText("Menu Bar Widgets")
                    BodyText("Configure your menu bar with live system monitors.")

                case .active(let count):
                    DisplayText("Menu Bar Widgets")

                    HStack(spacing: TonicSpaceToken.one) {
                        ForEach(activeIcons.prefix(6), id: \.self) { icon in
                            Image(systemName: icon)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(theme.worldToken.light.opacity(0.85))
                                .frame(width: 28, height: 28)
                                .background(TonicGlassToken.fill)
                                .glassSurface(radius: TonicRadiusToken.m, variant: .base)
                        }
                    }

                    CounterChip(
                        title: "\(count) active",
                        value: nil,
                        world: .protectionMagenta,
                        isActive: true
                    )
                    .contentTransition(.numericText())
                    .animation(TonicMotionToken.springTap, value: count)
                }
            }
            .multilineTextAlignment(.center)
        }
        .onChange(of: activeCount) { _, _ in
            guard !reduceMotion else { return }
            countBump = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                countBump = false
            }
        }
    }

    private var heroIconSize: CGFloat {
        switch state {
        case .idle: return 60
        case .active: return 48
        }
    }

    private var activeCount: Int {
        switch state {
        case .idle: return 0
        case .active(let count): return count
        }
    }
}

// MARK: - Widget Card

struct WidgetCard: View {
    let config: WidgetConfiguration
    let sparklineData: [Double]
    let currentValue: String
    let isDragging: Bool
    let isDropTarget: Bool
    let onSettings: () -> Void
    let onRemove: () -> Void

    @Environment(\.tonicTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @State private var gearHovering = false

    var body: some View {
        HStack(spacing: TonicSpaceToken.two) {
            // Drag handle
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(TonicTextToken.tertiary)
                .frame(width: 16)

            // Widget icon
            Image(systemName: config.type.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(theme.worldToken.light)
                .frame(width: 28, height: 28)
                .background(TonicGlassToken.fill)
                .glassSurface(radius: TonicRadiusToken.s, variant: .base)

            // Name and details
            VStack(alignment: .leading, spacing: 3) {
                Text(config.type.displayName)
                    .font(TonicTypeToken.caption.weight(.semibold))
                    .foregroundStyle(TonicTextToken.primary)

                HStack(spacing: TonicSpaceToken.one) {
                    Text(config.displayMode.displayName)
                        .font(TonicTypeToken.micro)
                        .foregroundStyle(TonicTextToken.tertiary)

                    WidgetMiniSparkline(data: sparklineData, color: theme.worldToken.light)
                        .frame(width: 36, height: 12)
                }
            }

            Spacer()

            // Live value
            Text(currentValue)
                .font(TonicTypeToken.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(TonicTextToken.primary)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: TonicMotionToken.fast), value: currentValue)

            // Settings gear
            Button(action: onSettings) {
                Image(systemName: "gear")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TonicTextToken.secondary)
                    .rotationEffect(.degrees(gearHovering ? 15 : 0))
                    .animation(.easeInOut(duration: TonicMotionToken.fast), value: gearHovering)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                gearHovering = hovering
            }
            .frame(width: 24)
        }
        .padding(.horizontal, TonicSpaceToken.three)
        .padding(.vertical, TonicSpaceToken.two)
        .glassSurface(radius: TonicRadiusToken.l, variant: .base)
        .overlay(
            RoundedRectangle(cornerRadius: TonicRadiusToken.l)
                .stroke(
                    isDropTarget ? theme.worldToken.light.opacity(0.4) : Color.clear,
                    lineWidth: 1.5
                )
                .allowsHitTesting(false)
        )
        .opacity(isDragging ? 0.5 : 1.0)
        .scaleEffect(isDragging ? 0.97 : 1.0)
        .animation(.easeInOut(duration: TonicMotionToken.fast), value: isDragging)
        .animation(.easeInOut(duration: TonicMotionToken.fast), value: isDropTarget)
        .depthLift()
        .contextMenu {
            Button(action: onSettings) {
                Label("Settings", systemImage: "gear")
            }
            Divider()
            Button(role: .destructive, action: onRemove) {
                Label("Remove", systemImage: "minus.circle")
            }
        }
    }
}

// MARK: - Widget Mini Sparkline

private struct WidgetMiniSparkline: View {
    let data: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                guard data.count > 1 else { return }

                let stepX = geometry.size.width / CGFloat(data.count - 1)
                let maxY = data.max() ?? 1
                let minY = data.min() ?? 0
                let range = max(maxY - minY, 0.1)

                for (index, value) in data.enumerated() {
                    let x = CGFloat(index) * stepX
                    let normalizedY = (value - minY) / range
                    let y = geometry.size.height * (1 - normalizedY)

                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(
                LinearGradient(
                    colors: [color, color.opacity(0.4)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                lineWidth: 1.2
            )
        }
    }
}

// MARK: - Widget Source Tile

struct WidgetSourceTile: View {
    let type: WidgetType
    let isEnabled: Bool
    let description: String
    let onToggle: () -> Void

    @Environment(\.tonicTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: TonicSpaceToken.two) {
            HStack(spacing: TonicSpaceToken.one) {
                Image(systemName: type.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isEnabled ? theme.worldToken.light : TonicTextToken.secondary)

                Spacer()

                Image(systemName: isEnabled ? "checkmark.circle.fill" : "plus.circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isEnabled ? theme.worldToken.light : TonicTextToken.tertiary)
            }

            Text(type.displayName)
                .font(TonicTypeToken.caption.weight(.semibold))
                .foregroundStyle(TonicTextToken.primary)

            Text(description)
                .font(TonicTypeToken.micro)
                .foregroundStyle(TonicTextToken.tertiary)
                .lineLimit(2)
        }
        .padding(TonicSpaceToken.two)
        .glassSurface(radius: TonicRadiusToken.l, variant: .base)
        .overlay(
            RoundedRectangle(cornerRadius: TonicRadiusToken.l)
                .stroke(
                    isEnabled ? theme.worldToken.light.opacity(0.3) : Color.clear,
                    lineWidth: 1
                )
                .allowsHitTesting(false)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(TonicMotionToken.springTap) {
                onToggle()
            }
        }
        .depthLift()
    }
}

// MARK: - OneView Mode Card

struct OneViewModeCard: View {
    @Binding var enabled: Bool
    let onToggle: (Bool) -> Void

    @Environment(\.tonicTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @State private var iconRotation: Double = 0

    var body: some View {
        HStack(spacing: TonicSpaceToken.three) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(enabled ? theme.worldToken.light : TonicTextToken.secondary)
                .rotationEffect(.degrees(iconRotation))

            VStack(alignment: .leading, spacing: 3) {
                Text("Unified Menu Bar Mode")
                    .font(TonicTypeToken.caption.weight(.semibold))
                    .foregroundStyle(TonicTextToken.primary)

                Text("Combine all widgets into a single menu bar item")
                    .font(TonicTypeToken.micro)
                    .foregroundStyle(TonicTextToken.tertiary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { enabled },
                set: { newValue in
                    withAnimation(TonicMotionToken.springTap) {
                        enabled = newValue
                        onToggle(newValue)
                        if newValue {
                            iconRotation += 90
                        }
                    }
                }
            ))
            .toggleStyle(.switch)
        }
        .padding(TonicSpaceToken.three)
        .glassSurface(radius: TonicRadiusToken.l, variant: .raised)
        .overlay(
            RoundedRectangle(cornerRadius: TonicRadiusToken.l)
                .stroke(
                    enabled ? theme.worldToken.light.opacity(0.25) : Color.clear,
                    lineWidth: 1
                )
                .allowsHitTesting(false)
        )
        .depthLift()
    }
}

// MARK: - Widget Mini Preview

struct WidgetMiniPreview: View {
    let config: WidgetConfiguration
    let value: String
    let sparklineData: [Double]

    @Environment(\.tonicTheme) private var theme

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: config.type.icon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))

            WidgetMiniSparkline(data: sparklineData, color: theme.worldToken.light)
                .frame(width: 24, height: 10)

            Text(value)
                .font(.system(size: 9, weight: .semibold).monospacedDigit())
                .foregroundStyle(.white.opacity(0.85))
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: TonicMotionToken.fast), value: value)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.black.opacity(0.75))
        )
    }
}

// MARK: - Widget Command Dock

struct WidgetCommandDock: View {
    let activeWidgets: [WidgetConfiguration]
    let previewValues: [(config: WidgetConfiguration, value: String, sparkline: [Double])]
    let onApply: () -> Void
    let onNotifications: () -> Void

    @Environment(\.tonicTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack(spacing: TonicSpaceToken.two) {
            // Live preview strip
            if !previewValues.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: TonicSpaceToken.one) {
                        ForEach(previewValues, id: \.config.type) { item in
                            WidgetMiniPreview(
                                config: item.config,
                                value: item.value,
                                sparklineData: item.sparkline
                            )
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.8).combined(with: .opacity),
                                removal: .scale(scale: 0.8).combined(with: .opacity)
                            ))
                        }
                    }
                    .animation(TonicMotionToken.stageEnterSpring, value: previewValues.map(\.config.type))
                }
            }

            // Action bar
            HStack(spacing: TonicSpaceToken.two) {
                Text("\(activeWidgets.count) widget\(activeWidgets.count == 1 ? "" : "s") active")
                    .font(TonicTypeToken.caption)
                    .foregroundStyle(TonicTextToken.secondary)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: TonicMotionToken.fast), value: activeWidgets.count)

                Spacer()

                SecondaryPillButton(title: "Notifications", action: onNotifications)

                PrimaryActionButton(
                    title: "Apply Changes",
                    icon: "checkmark",
                    action: onApply
                )
            }
        }
        .padding(.horizontal, TonicSpaceToken.three)
        .padding(.vertical, TonicSpaceToken.two)
        .glassSurface(radius: TonicRadiusToken.container, variant: .raised)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .onAppear {
            guard !reduceMotion else {
                appeared = true
                return
            }
            withAnimation(TonicMotionToken.modalPresentSpring.delay(0.2)) {
                appeared = true
            }
        }
    }
}
