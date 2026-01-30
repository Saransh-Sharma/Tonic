//
//  ActionTable.swift
//  Tonic
//
//  A reusable table component for multi-select lists with batch actions,
//  keyboard navigation, and context menu support.
//
//  Used in: App Manager, Disk Analysis (file lists)
//
//  Features:
//  - Multi-select with Shift (range) and Cmd (toggle) modifiers
//  - Batch action buttons shown when items are selected
//  - Keyboard navigation (arrow keys to move, Space to select, Enter to activate)
//  - Context menu support (right-click)
//  - Sortable columns
//
//  Layout:
//  - Header row with sortable columns
//  - Content rows with fixed height (44pt)
//  - Batch action bar (appears when items selected)
//

import SwiftUI

// MARK: - ActionTableItem Protocol

/// Protocol for items that can be displayed in the ActionTable.
/// Implement this protocol to provide data for the table.
protocol ActionTableItem: Identifiable, Hashable {
    associatedtype ID: Hashable
    var id: ID { get }
}

// MARK: - ActionTableColumn

/// Describes a column in the ActionTable
struct ActionTableColumn<Item: ActionTableItem>: Identifiable {
    let id: String
    let title: String
    let width: ActionTableColumnWidth
    let alignment: HorizontalAlignment
    let isSortable: Bool
    let content: (Item) -> AnyView

    /// Initialize a table column
    /// - Parameters:
    ///   - id: Unique identifier for the column
    ///   - title: Column header text
    ///   - width: Column width specification
    ///   - alignment: Content alignment
    ///   - isSortable: Whether the column can be sorted
    ///   - content: View builder for cell content
    init<Content: View>(
        id: String,
        title: String,
        width: ActionTableColumnWidth = .flexible,
        alignment: HorizontalAlignment = .leading,
        isSortable: Bool = false,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.id = id
        self.title = title
        self.width = width
        self.alignment = alignment
        self.isSortable = isSortable
        self.content = { item in AnyView(content(item)) }
    }
}

/// Column width specification
enum ActionTableColumnWidth {
    case fixed(CGFloat)
    case flexible
    case flexibleRange(min: CGFloat, max: CGFloat)

    var minWidth: CGFloat? {
        switch self {
        case .fixed(let width): return width
        case .flexible: return nil
        case .flexibleRange(let min, _): return min
        }
    }

    var maxWidth: CGFloat? {
        switch self {
        case .fixed(let width): return width
        case .flexible: return nil
        case .flexibleRange(_, let max): return max
        }
    }
}

// MARK: - ActionTableAction

/// Describes a batch action that can be performed on selected items
struct ActionTableAction<Item: ActionTableItem>: Identifiable {
    let id: String
    let title: String
    let icon: String?
    let style: ActionStyle
    let isEnabled: ([Item]) -> Bool
    let action: ([Item]) -> Void

    /// Action style for visual appearance
    enum ActionStyle {
        case primary
        case secondary
        case destructive
    }

    /// Initialize a batch action
    /// - Parameters:
    ///   - id: Unique identifier
    ///   - title: Button title
    ///   - icon: Optional SF Symbol name
    ///   - style: Visual style (primary, secondary, destructive)
    ///   - isEnabled: Closure to determine if action is enabled for selection
    ///   - action: Closure to execute when action is triggered
    init(
        id: String,
        title: String,
        icon: String? = nil,
        style: ActionStyle = .secondary,
        isEnabled: @escaping ([Item]) -> Bool = { !$0.isEmpty },
        action: @escaping ([Item]) -> Void
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.style = style
        self.isEnabled = isEnabled
        self.action = action
    }
}

// MARK: - ActionTable

/// A reusable table component supporting multi-select, batch actions, and keyboard navigation.
///
/// Usage:
/// ```swift
/// ActionTable(
///     items: apps,
///     selection: $selectedIds,
///     columns: [
///         ActionTableColumn(id: "name", title: "Name") { app in
///             Text(app.name)
///         },
///         ActionTableColumn(id: "size", title: "Size", width: .fixed(80), isSortable: true) { app in
///             Text(app.formattedSize)
///         }
///     ],
///     batchActions: [
///         ActionTableAction(id: "delete", title: "Delete", icon: "trash", style: .destructive) { items in
///             deleteApps(items)
///         }
///     ],
///     contextMenu: { item in
///         Button("Reveal in Finder") { revealInFinder(item) }
///         Divider()
///         Button("Delete", role: .destructive) { delete(item) }
///     }
/// )
/// ```
struct ActionTable<Item: ActionTableItem, ContextMenu: View>: View {
    let items: [Item]
    @Binding var selection: Set<Item.ID>
    let columns: [ActionTableColumn<Item>]
    let batchActions: [ActionTableAction<Item>]
    let contextMenu: ((Item) -> ContextMenu)?
    let onDoubleClick: ((Item) -> Void)?
    let onActivate: ((Item) -> Void)?

    /// Sorting state
    @State private var sortColumnId: String?
    @State private var sortAscending: Bool = true

    /// Keyboard focus tracking
    @State private var focusedItemId: Item.ID?
    @FocusState private var isTableFocused: Bool

    /// Last selected item for Shift-click range selection
    @State private var lastSelectedId: Item.ID?

    /// Row height constant
    private let rowHeight: CGFloat = 44

    /// Initialize ActionTable
    /// - Parameters:
    ///   - items: Array of items to display
    ///   - selection: Binding to the set of selected item IDs
    ///   - columns: Column definitions
    ///   - batchActions: Actions available for selected items
    ///   - contextMenu: Optional context menu builder
    ///   - onDoubleClick: Optional double-click handler
    ///   - onActivate: Optional activation handler (Enter key)
    init(
        items: [Item],
        selection: Binding<Set<Item.ID>>,
        columns: [ActionTableColumn<Item>],
        batchActions: [ActionTableAction<Item>] = [],
        @ViewBuilder contextMenu: @escaping (Item) -> ContextMenu,
        onDoubleClick: ((Item) -> Void)? = nil,
        onActivate: ((Item) -> Void)? = nil
    ) {
        self.items = items
        self._selection = selection
        self.columns = columns
        self.batchActions = batchActions
        self.contextMenu = contextMenu
        self.onDoubleClick = onDoubleClick
        self.onActivate = onActivate
    }

    var body: some View {
        VStack(spacing: 0) {
            // Batch action bar (shown when items selected)
            if !selection.isEmpty {
                batchActionBar
            }

            // Header row
            headerRow

            Divider()

            // Content list
            ScrollViewReader { scrollProxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(items) { item in
                            ActionTableRow(
                                item: item,
                                columns: columns,
                                isSelected: selection.contains(item.id),
                                isFocused: focusedItemId == item.id,
                                rowHeight: rowHeight,
                                contextMenu: contextMenu,
                                onSelect: { modifiers in
                                    handleSelection(item: item, modifiers: modifiers)
                                },
                                onDoubleClick: {
                                    onDoubleClick?(item)
                                }
                            )
                            .id(item.id)
                        }
                    }
                }
                .focused($isTableFocused)
                .onKeyPress(.upArrow) {
                    moveSelection(direction: -1, scrollProxy: scrollProxy)
                    return .handled
                }
                .onKeyPress(.downArrow) {
                    moveSelection(direction: 1, scrollProxy: scrollProxy)
                    return .handled
                }
                .onKeyPress(.space) {
                    toggleFocusedSelection()
                    return .handled
                }
                .onKeyPress(.return) {
                    activateFocused()
                    return .handled
                }
                .onKeyPress(characters: .alphanumerics, phases: .down) { press in
                    if press.characters == "a" && press.modifiers.contains(.command) {
                        selectAll()
                        return .handled
                    }
                    return .ignored
                }
            }
        }
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack(spacing: 0) {
            ForEach(columns) { column in
                columnHeader(column)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.xxs)
        .background(DesignTokens.Colors.backgroundSecondary)
    }

    @ViewBuilder
    private func columnHeader(_ column: ActionTableColumn<Item>) -> some View {
        let isCurrentSort = sortColumnId == column.id

        Group {
            if column.isSortable {
                Button {
                    withAnimation(DesignTokens.Animation.fast) {
                        if sortColumnId == column.id {
                            sortAscending.toggle()
                        } else {
                            sortColumnId = column.id
                            sortAscending = true
                        }
                    }
                } label: {
                    HStack(spacing: DesignTokens.Spacing.xxxs) {
                        Text(column.title)
                            .font(DesignTokens.Typography.captionEmphasized)
                            .foregroundColor(DesignTokens.Colors.textSecondary)

                        if isCurrentSort {
                            Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundColor(DesignTokens.Colors.textTertiary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Sort by \(column.title)")
                .accessibilityHint(isCurrentSort ? "Currently sorted \(sortAscending ? "ascending" : "descending"). Click to reverse" : "Click to sort")
            } else {
                Text(column.title)
                    .font(DesignTokens.Typography.captionEmphasized)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
        }
        .frame(maxWidth: column.width.maxWidth ?? .infinity, alignment: Alignment(horizontal: column.alignment, vertical: .center))
        .frame(minWidth: column.width.minWidth)
    }

    // MARK: - Batch Action Bar

    private var batchActionBar: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            // Selection count
            Text("\(selection.count) selected")
                .font(DesignTokens.Typography.subheadEmphasized)
                .foregroundColor(DesignTokens.Colors.textPrimary)

            // Clear selection button
            Button {
                withAnimation(DesignTokens.Animation.fast) {
                    selection.removeAll()
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Clear selection")
            .accessibilityHint("Deselects all selected items")

            Spacer()

            // Batch action buttons
            ForEach(batchActions) { action in
                batchActionButton(action)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(DesignTokens.Colors.selectedContentBackground.opacity(0.3))
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    @ViewBuilder
    private func batchActionButton(_ action: ActionTableAction<Item>) -> some View {
        let selectedItems = items.filter { selection.contains($0.id) }
        let isEnabled = action.isEnabled(selectedItems)

        Button {
            action.action(selectedItems)
        } label: {
            HStack(spacing: DesignTokens.Spacing.xxxs) {
                if let icon = action.icon {
                    Image(systemName: icon)
                }
                Text(action.title)
            }
            .font(DesignTokens.Typography.subhead)
        }
        .buttonStyle(.bordered)
        .tint(action.style == .destructive ? DesignTokens.Colors.destructive : nil)
        .disabled(!isEnabled)
        .accessibilityLabel("\(action.title) \(selection.count) selected items")
        .accessibilityHint(isEnabled ? "Click to \(action.title.lowercased())" : "Not available for selected items")
    }

    // MARK: - Selection Handling

    private func handleSelection(item: Item, modifiers: EventModifiers) {
        if modifiers.contains(.command) {
            // Cmd+click: Toggle selection
            if selection.contains(item.id) {
                selection.remove(item.id)
            } else {
                selection.insert(item.id)
            }
            lastSelectedId = item.id
        } else if modifiers.contains(.shift), let lastId = lastSelectedId {
            // Shift+click: Range selection
            if let lastIndex = items.firstIndex(where: { $0.id == lastId }),
               let currentIndex = items.firstIndex(where: { $0.id == item.id }) {
                let range = min(lastIndex, currentIndex)...max(lastIndex, currentIndex)
                for i in range {
                    selection.insert(items[i].id)
                }
            }
        } else {
            // Regular click: Single selection
            selection = [item.id]
            lastSelectedId = item.id
        }
        focusedItemId = item.id
    }

    // MARK: - Keyboard Navigation

    private func moveSelection(direction: Int, scrollProxy: ScrollViewProxy) {
        guard !items.isEmpty else { return }

        let currentIndex: Int
        if let focusedId = focusedItemId,
           let index = items.firstIndex(where: { $0.id == focusedId }) {
            currentIndex = index
        } else if let firstSelectedId = selection.first,
                  let index = items.firstIndex(where: { $0.id == firstSelectedId }) {
            currentIndex = index
        } else {
            currentIndex = direction > 0 ? -1 : items.count
        }

        let newIndex = max(0, min(items.count - 1, currentIndex + direction))
        let newItem = items[newIndex]

        withAnimation(DesignTokens.Animation.fast) {
            focusedItemId = newItem.id
            if !NSEvent.modifierFlags.contains(.shift) {
                selection = [newItem.id]
                lastSelectedId = newItem.id
            } else {
                // Shift+arrow: Extend selection
                selection.insert(newItem.id)
            }
            scrollProxy.scrollTo(newItem.id, anchor: .center)
        }
    }

    private func toggleFocusedSelection() {
        guard let focusedId = focusedItemId else { return }
        withAnimation(DesignTokens.Animation.fast) {
            if selection.contains(focusedId) {
                selection.remove(focusedId)
            } else {
                selection.insert(focusedId)
            }
        }
    }

    private func activateFocused() {
        guard let focusedId = focusedItemId,
              let item = items.first(where: { $0.id == focusedId }) else { return }
        onActivate?(item)
    }

    private func selectAll() {
        withAnimation(DesignTokens.Animation.fast) {
            selection = Set(items.map { $0.id })
        }
    }
}

// MARK: - ActionTable without context menu

extension ActionTable where ContextMenu == EmptyView {
    /// Initialize ActionTable without context menu
    init(
        items: [Item],
        selection: Binding<Set<Item.ID>>,
        columns: [ActionTableColumn<Item>],
        batchActions: [ActionTableAction<Item>] = [],
        onDoubleClick: ((Item) -> Void)? = nil,
        onActivate: ((Item) -> Void)? = nil
    ) {
        self.items = items
        self._selection = selection
        self.columns = columns
        self.batchActions = batchActions
        self.contextMenu = nil
        self.onDoubleClick = onDoubleClick
        self.onActivate = onActivate
    }
}

// MARK: - ActionTableRow

/// A single row in the ActionTable
private struct ActionTableRow<Item: ActionTableItem, ContextMenu: View>: View {
    let item: Item
    let columns: [ActionTableColumn<Item>]
    let isSelected: Bool
    let isFocused: Bool
    let rowHeight: CGFloat
    let contextMenu: ((Item) -> ContextMenu)?
    let onSelect: (EventModifiers) -> Void
    let onDoubleClick: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            ForEach(columns) { column in
                column.content(item)
                    .frame(maxWidth: column.width.maxWidth ?? .infinity, alignment: Alignment(horizontal: column.alignment, vertical: .center))
                    .frame(minWidth: column.width.minWidth)
            }
        }
        .frame(height: rowHeight)
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .background(rowBackground)
        .overlay(focusRing)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            onDoubleClick()
        }
        .simultaneousGesture(
            TapGesture(count: 1)
                .modifiers([])
                .onEnded { _ in
                    let modifiers = NSEvent.modifierFlags
                    var eventModifiers: EventModifiers = []
                    if modifiers.contains(.command) { eventModifiers.insert(.command) }
                    if modifiers.contains(.shift) { eventModifiers.insert(.shift) }
                    onSelect(eventModifiers)
                }
        )
        .onHover { hovering in
            withAnimation(DesignTokens.Animation.fast) {
                isHovered = hovering
            }
        }
        .contextMenu {
            if let menuBuilder = contextMenu {
                menuBuilder(item)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var rowBackground: some View {
        Group {
            if isSelected {
                DesignTokens.Colors.selectedContentBackground
            } else if isHovered {
                DesignTokens.Colors.unemphasizedSelectedContentBackground.opacity(0.5)
            } else {
                Color.clear
            }
        }
    }

    @ViewBuilder
    private var focusRing: some View {
        if isFocused {
            RoundedRectangle(cornerRadius: 2)
                .stroke(DesignTokens.Colors.accent, lineWidth: 2)
                .padding(1)
        }
    }
}

// MARK: - Previews

#if DEBUG
/// Preview item for testing
private struct PreviewTableItem: ActionTableItem {
    let id: String
    let name: String
    let size: Int64
    let category: String
    let lastUsed: Date?

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var formattedLastUsed: String {
        guard let date = lastUsed else { return "Never" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct ActionTable_Previews: PreviewProvider {
    static var previews: some View {
        ActionTablePreviewWrapper()
            .frame(width: 600, height: 500)
            .background(DesignTokens.Colors.background)
            .previewDisplayName("ActionTable")
    }
}

private struct ActionTablePreviewWrapper: View {
    @State private var selection: Set<String> = []

    private let items: [PreviewTableItem] = [
        PreviewTableItem(id: "1", name: "Safari", size: 150_000_000, category: "Browser", lastUsed: Date()),
        PreviewTableItem(id: "2", name: "Xcode", size: 12_500_000_000, category: "Developer", lastUsed: Date().addingTimeInterval(-86400)),
        PreviewTableItem(id: "3", name: "Slack", size: 450_000_000, category: "Communication", lastUsed: Date().addingTimeInterval(-3600)),
        PreviewTableItem(id: "4", name: "Figma", size: 380_000_000, category: "Design", lastUsed: Date().addingTimeInterval(-7200)),
        PreviewTableItem(id: "5", name: "VS Code", size: 650_000_000, category: "Developer", lastUsed: Date().addingTimeInterval(-1800)),
        PreviewTableItem(id: "6", name: "Spotify", size: 280_000_000, category: "Music", lastUsed: nil),
        PreviewTableItem(id: "7", name: "Discord", size: 420_000_000, category: "Communication", lastUsed: Date().addingTimeInterval(-172800)),
        PreviewTableItem(id: "8", name: "Notes", size: 25_000_000, category: "Productivity", lastUsed: Date()),
    ]

    private var columns: [ActionTableColumn<PreviewTableItem>] {
        [
            ActionTableColumn(id: "name", title: "Name") { item in
                HStack(spacing: DesignTokens.Spacing.xxs) {
                    Image(systemName: "app.fill")
                        .foregroundColor(DesignTokens.Colors.accent)
                    Text(item.name)
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                }
            },
            ActionTableColumn(id: "category", title: "Category", width: .fixed(100)) { item in
                Text(item.category)
                    .font(DesignTokens.Typography.subhead)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            },
            ActionTableColumn(id: "size", title: "Size", width: .fixed(80), alignment: .trailing, isSortable: true) { item in
                Text(item.formattedSize)
                    .font(DesignTokens.Typography.monoSubhead)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            },
            ActionTableColumn(id: "lastUsed", title: "Last Used", width: .fixed(100), alignment: .trailing) { item in
                Text(item.formattedLastUsed)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
        ]
    }

    private var batchActions: [ActionTableAction<PreviewTableItem>] {
        [
            ActionTableAction(id: "reveal", title: "Reveal", icon: "folder") { items in
                print("Reveal: \(items.map { $0.name })")
            },
            ActionTableAction(id: "delete", title: "Delete", icon: "trash", style: .destructive) { items in
                print("Delete: \(items.map { $0.name })")
            }
        ]
    }

    var body: some View {
        ActionTable(
            items: items,
            selection: $selection,
            columns: columns,
            batchActions: batchActions,
            contextMenu: { item in
                Button("Open") { print("Open \(item.name)") }
                Button("Reveal in Finder") { print("Reveal \(item.name)") }
                Divider()
                Button("Delete", role: .destructive) { print("Delete \(item.name)") }
            },
            onDoubleClick: { item in
                print("Double-clicked: \(item.name)")
            },
            onActivate: { item in
                print("Activated: \(item.name)")
            }
        )
    }
}
#endif
