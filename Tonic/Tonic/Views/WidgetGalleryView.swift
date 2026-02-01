//
//  WidgetGalleryView.swift
//  Tonic
//
//  Horizontal widget selector matching Stats Master's design
//  Active widgets on left, separator, inactive on right
//

import SwiftUI

// MARK: - Widget Gallery View

/// Horizontal widget gallery with drag-drop reordering
/// Matches Stats Master's widget selector pattern
struct WidgetGalleryView: View {
    @Bindable var preferences: WidgetPreferences
    @Binding var selectedWidget: WidgetType?
    @State private var draggedWidget: WidgetType?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Widgets")
                .font(DesignTokens.Typography.captionEmphasized)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .textCase(.uppercase)

            HStack(spacing: DesignTokens.Spacing.sm) {
                // Active widgets (colored, draggable)
                activeWidgetsSection

                // Separator
                if !preferences.enabledWidgets.isEmpty && !inactiveWidgets.isEmpty {
                    Rectangle()
                        .fill(DesignTokens.Colors.separator)
                        .frame(width: 2, height: 44)
                        .padding(.horizontal, DesignTokens.Spacing.xs)
                }

                // Inactive widgets (grayscale)
                inactiveWidgetsSection

                Spacer()
            }
            .padding(DesignTokens.Spacing.md)
            .background(DesignTokens.Colors.backgroundSecondary)
            .cornerRadius(DesignTokens.CornerRadius.medium)
        }
    }

    // MARK: - Active Widgets Section

    private var activeWidgetsSection: some View {
        ForEach(preferences.enabledWidgets) { config in
            WidgetGalleryItem(
                widgetType: config.type,
                isActive: true,
                isSelected: selectedWidget == config.type,
                accentColor: config.accentColor.colorValue(for: config.type)
            )
            .onTapGesture {
                withAnimation(DesignTokens.Animation.fast) {
                    selectedWidget = config.type
                }
            }
            .onDrag {
                draggedWidget = config.type
                return NSItemProvider(object: config.type.rawValue as NSString)
            }
            .onDrop(of: [.text], delegate: GalleryDropDelegate(
                targetType: config.type,
                draggedWidget: $draggedWidget,
                preferences: preferences
            ))
        }
    }

    // MARK: - Inactive Widgets Section

    private var inactiveWidgetsSection: some View {
        ForEach(inactiveWidgets, id: \.self) { type in
            WidgetGalleryItem(
                widgetType: type,
                isActive: false,
                isSelected: false,
                accentColor: defaultColor(for: type)
            )
            .onTapGesture {
                withAnimation(DesignTokens.Animation.fast) {
                    activateWidget(type)
                }
            }
        }
    }

    // MARK: - Helpers

    private var inactiveWidgets: [WidgetType] {
        WidgetType.allCases.filter { type in
            preferences.config(for: type)?.isEnabled != true
        }
    }

    private func activateWidget(_ type: WidgetType) {
        let maxPosition = preferences.widgetConfigs.map { $0.position }.max() ?? 0
        var newConfig = WidgetConfiguration.default(for: type, at: maxPosition + 1)
        newConfig.isEnabled = true
        preferences.updateConfig(for: type) { config in
            config = newConfig
        }
        selectedWidget = type
    }

    private func defaultColor(for type: WidgetType) -> Color {
        switch type {
        case .cpu: return Color(red: 0.37, green: 0.62, blue: 1.0)
        case .memory: return Color(red: 0.19, green: 0.82, blue: 0.35)
        case .disk: return Color(red: 1.0, green: 0.62, blue: 0.04)
        case .network: return Color(red: 0.39, green: 0.82, blue: 1.0)
        case .gpu: return Color(red: 0.75, green: 0.35, blue: 0.95)
        case .battery: return Color(red: 0.19, green: 0.82, blue: 0.35)
        case .weather: return Color(red: 1.0, green: 0.84, blue: 0.04)
        case .sensors: return Color(red: 1.0, green: 0.45, blue: 0.35)
        case .bluetooth: return Color(red: 0.0, green: 0.48, blue: 1.0)
        case .clock: return Color(red: 0.55, green: 0.35, blue: 0.95)
        }
    }
}

// MARK: - Widget Gallery Item

/// Individual widget item in the gallery
struct WidgetGalleryItem: View {
    let widgetType: WidgetType
    let isActive: Bool
    let isSelected: Bool
    let accentColor: Color

    @State private var isHovering = false

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xxs) {
            // Icon container
            ZStack {
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.small)
                    .fill(isActive ? accentColor.opacity(0.15) : Color.gray.opacity(0.1))
                    .frame(width: 44, height: 44)

                Image(systemName: widgetType.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isActive ? accentColor : Color.gray.opacity(0.5))
            }
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.small)
                    .stroke(isSelected ? accentColor : Color.clear, lineWidth: 2)
            )
            .scaleEffect(isHovering ? 1.05 : 1.0)

            // Label
            Text(widgetType.shortName)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(isActive ? DesignTokens.Colors.textSecondary : Color.gray.opacity(0.5))
        }
        .opacity(isActive ? 1.0 : 0.6)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .help(widgetType.displayName)
    }
}

// MARK: - Gallery Drop Delegate

private struct GalleryDropDelegate: DropDelegate {
    let targetType: WidgetType
    @Binding var draggedWidget: WidgetType?
    let preferences: WidgetPreferences

    func performDrop(info: DropInfo) -> Bool {
        guard let draggedType = draggedWidget, draggedType != targetType else {
            return false
        }

        preferences.reorderWidgets(move: draggedType, to: targetType)
        draggedWidget = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        // Visual feedback is handled by hover state
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

// MARK: - Widget Type Extension

extension WidgetType {
    /// Short name for gallery display
    var shortName: String {
        switch self {
        case .cpu: return "CPU"
        case .memory: return "RAM"
        case .disk: return "Disk"
        case .network: return "Net"
        case .gpu: return "GPU"
        case .battery: return "Bat"
        case .weather: return "Wx"
        case .sensors: return "Temp"
        case .bluetooth: return "BT"
        case .clock: return "Time"
        }
    }
}

// MARK: - Preview

#Preview("Widget Gallery") {
    VStack {
        WidgetGalleryView(
            preferences: WidgetPreferences.shared,
            selectedWidget: .constant(.cpu)
        )
        .padding()
    }
    .frame(width: 500)
    .background(DesignTokens.Colors.background)
}
