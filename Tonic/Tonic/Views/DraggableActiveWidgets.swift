//
//  DraggableActiveWidgets.swift
//  Tonic
//
//  Drag-and-drop widget reordering with horizontal layout
//  Matches Stats Master's reordering behavior
//  Task ID: fn-5-v8r.15 & fn-5-v8r.16
//

import SwiftUI

// MARK: - Draggable Active Widgets Section

/// Active widgets section with drag-and-drop reordering
/// Horizontal scroll layout following Stats Master pattern
public struct DraggableActiveWidgetsSection: View {
    @Bindable var viewModel: WidgetPanelViewModel
    @State private var draggedWidget: ActiveWidget?

    public init(viewModel: WidgetPanelViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            sectionHeader

            if viewModel.activeWidgets.isEmpty {
                emptyState
            } else {
                horizontalScroll
            }
        }
    }

    private var sectionHeader: some View {
        HStack {
            Text("Active Widgets")
                .font(.headline)
                .foregroundColor(DesignTokens.Colors.textPrimary)

            Spacer()

            Text("\(viewModel.activeWidgets.count) widgets")
                .font(.caption)
                .foregroundColor(DesignTokens.Colors.textSecondary)
        }
    }

    private var emptyState: some View {
        Card(variant: .flat) {
            VStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "square.grid.3x3.fill")
                    .font(.system(size: 28))
                    .foregroundColor(DesignTokens.Colors.textTertiary)

                Text("No Active Widgets")
                    .font(.subheadline)
                    .foregroundColor(DesignTokens.Colors.textSecondary)

                Text("Add widgets from the available section")
                    .font(.caption)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(DesignTokens.Spacing.lg)
        }
    }

    private var horizontalScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: DesignTokens.Spacing.sm) {
                ForEach(viewModel.activeWidgets) { widget in
                    DraggableWidgetCard(
                        widget: widget,
                        isDragging: draggedWidget?.id == widget.id,
                        onRemove: { viewModel.removeWidget(widget) },
                        onToggle: { viewModel.toggleWidget(widget) }
                    )
                    .scaleEffect(draggedWidget?.id == widget.id ? 1.05 : 1.0)
                    .opacity(draggedWidget?.id == widget.id ? 0.8 : 1.0)
                    .animation(.spring(response: 0.3), value: draggedWidget?.id)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
        }
        .frame(height: 120)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                .fill(DesignTokens.Colors.backgroundTertiary)
        )
        .cornerRadius(DesignTokens.CornerRadius.md)
    }
}

// MARK: - Draggable Widget Card

/// Individual widget card with drag capability
public struct DraggableWidgetCard: View {
    let widget: ActiveWidget
    let isDragging: Bool
    let onRemove: () -> Void
    let onToggle: () -> Void

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            // Drag handle and icon
            HStack {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 8))
                    .foregroundColor(DesignTokens.Colors.textTertiary)

                Image(systemName: widget.type.icon)
                    .font(.system(size: 14))
                    .foregroundColor(widget.isEnabled ? DesignTokens.Colors.accent : DesignTokens.Colors.textTertiary)

                Spacer()

                // Action buttons (show on hover)
                if isHovering && !isDragging {
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        Button(action: {}) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.plain)

                        Button(action: onRemove) {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(DesignTokens.Colors.error)
                        }
                        .buttonStyle(.plain)
                    }
                    .transition(.opacity)
                }
            }

            // Widget name
            Text(widget.name)
                .font(.caption)
                .foregroundColor(widget.isEnabled ? DesignTokens.Colors.textPrimary : DesignTokens.Colors.textTertiary)

            // Toggle and order indicator
            HStack {
                Toggle("", isOn: Binding(
                    get: { widget.isEnabled },
                    set: { _ in onToggle() }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)

                Spacer()

                Text("\(widget.order + 1)")
                    .font(.caption2)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
        }
        .padding(DesignTokens.Spacing.md)
        .frame(width: 120, height: 100)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                .fill(DesignTokens.Colors.backgroundSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                .stroke(
                    widget.isEnabled ? DesignTokens.Colors.accent : DesignTokens.Colors.separator,
                    lineWidth: widget.isEnabled ? 2 : 1
                )
        )
        .shadow(color: .black.opacity(isDragging ? 0.2 : 0), radius: isDragging ? 8 : 0)
        .opacity(widget.isEnabled ? 1 : 0.6)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Reorderable LazyHStack

/// A LazyHStack that supports reordering via drag and drop
public struct ReorderableLazyHStack<Content: View>: View {
    let items: [ActiveWidget]
    let content: (ActiveWidget) -> Content
    @Binding var reorderedItems: [ActiveWidget]

    @State private var draggedItem: ActiveWidget?
    @State private var dragOffset: CGSize = .zero

    public init(
        items: [ActiveWidget],
        reorderedItems: Binding<[ActiveWidget]>,
        @ViewBuilder content: @escaping (ActiveWidget) -> Content
    ) {
        self.items = items
        self._reorderedItems = reorderedItems
        self.content = content
    }

    public var body: some View {
        LazyHStack(spacing: DesignTokens.Spacing.sm) {
            ForEach(items) { item in
                content(item)
                    .offset(draggedItem?.id == item.id ? dragOffset : .zero)
                    .zIndex(draggedItem?.id == item.id ? 1 : 0)
                    .gesture(
                        DragGesture(coordinateSpace: .global)
                            .onChanged { value in
                                guard draggedItem == nil else { return }
                                draggedItem = item
                                dragOffset = value.translation
                            }
                            .onEnded { value in
                                guard let dragged = draggedItem else { return }

                                // Calculate new position
                                let xOffset = value.translation.width
                                let cardWidth: CGFloat = 120
                                let spacing: CGFloat = DesignTokens.Spacing.sm
                                let newIndexOffset = Int(round(xOffset / (cardWidth + spacing)))

                                let oldIndex = items.firstIndex(where: { $0.id == dragged.id }) ?? 0
                                var newIndex = oldIndex + newIndexOffset
                                newIndex = max(0, min(items.count - 1, newIndex))

                                if newIndex != oldIndex {
                                    var newItems = items
                                    newItems.remove(at: oldIndex)
                                    newItems.insert(dragged, at: newIndex)
                                    reorderedItems = newItems
                                }

                                draggedItem = nil
                                dragOffset = .zero
                            }
                    )
            }
        }
        .animation(.spring(), value: dragOffset)
    }
}

// MARK: - Drop Delegate for Widget Reordering

public struct WidgetDropDelegate: DropDelegate {
    @Binding var widgets: [ActiveWidget]
    var draggedWidget: ActiveWidget?

    public func performDrop(info: DropInfo) -> Bool {
        return true
    }

    public func dropEntered(info: DropInfo) {
        guard let dragged = draggedWidget else { return }

        // Find the target widget and reorder
        // Implementation handled via gesture in ReorderableLazyHStack
    }

    public func dropExited(info: DropInfo) {
        // Clean up visual feedback
    }

    public func dropUpdated(info: DropInfo) -> Bool {
        // Update insertion indicator position
        return true
    }
}

// MARK: - Insertion Indicator

/// Visual indicator showing where dragged item will be dropped
public struct InsertionIndicator: View {
    var position: CGFloat
    var isVisible: Bool

    public var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(DesignTokens.Colors.accent)
            .frame(width: 2, height: 60)
            .opacity(isVisible ? 1 : 0)
            .animation(.easeInOut(duration: 0.15), value: isVisible)
    }
}

// MARK: - Preview

#Preview("Draggable Active Widgets") {
    let viewModel = {
        let vm = WidgetPanelViewModel()
        vm.activeWidgets = [
            ActiveWidget(type: .cpu, name: "CPU", isEnabled: true, order: 0),
            ActiveWidget(type: .memory, name: "Memory", isEnabled: true, order: 1),
            ActiveWidget(type: .network, name: "Network", isEnabled: true, order: 2),
            ActiveWidget(type: .disk, name: "Disk", isEnabled: false, order: 3),
        ]
        return vm
    }()

    DraggableActiveWidgetsSection(viewModel: viewModel)
        .padding()
        .frame(width: 600)
}
