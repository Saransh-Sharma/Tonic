//
//  OutlineView.swift
//  Tonic
//
//  A reusable outline view component for directory browsing with disclosure triangles,
//  sortable columns, and lazy-loaded children.
//
//  Used in: Disk Analysis view
//
//  Layout:
//  - Disclosure triangle | Icon | Name column | Size column | % of parent column
//  - Fixed row height: 32pt
//  - Three columns: Name (flexible), Size (80pt), Percentage (60pt)
//
//  Features:
//  - Disclosure triangles for expand/collapse with 0.15s animation
//  - Lazy-loaded children (fetched on expand)
//  - Sortable by size (ascending/descending)
//  - Selection highlighting
//  - Keyboard navigation support (arrow keys, space to expand/collapse)
//

import SwiftUI

// MARK: - OutlineItem Protocol

/// Protocol for items that can be displayed in the OutlineView.
/// Implement this protocol to provide data for the outline view.
protocol OutlineItem: Identifiable, Hashable {
    var id: String { get }
    var name: String { get }
    var size: Int64 { get }
    var isDirectory: Bool { get }
    var isExpandable: Bool { get }
}

// MARK: - OutlineViewNode

/// A node in the outline view hierarchy.
/// Wraps an OutlineItem with expansion state and children.
@Observable
final class OutlineViewNode<Item: OutlineItem>: Identifiable, Hashable {
    let id: String
    let item: Item
    let depth: Int
    var isExpanded: Bool = false
    var isLoading: Bool = false
    var children: [OutlineViewNode<Item>]?

    /// Percentage of parent size (0-100)
    var percentageOfParent: Double = 0

    init(item: Item, depth: Int = 0) {
        self.id = item.id
        self.item = item
        self.depth = depth
    }

    static func == (lhs: OutlineViewNode<Item>, rhs: OutlineViewNode<Item>) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - OutlineView

/// A reusable outline view component for hierarchical data browsing.
///
/// Features:
/// - Disclosure triangles for expand/collapse
/// - Three columns: Name, Size, % of parent
/// - Lazy-loaded children
/// - Sortable by size
///
/// Usage:
/// ```swift
/// OutlineView(
///     nodes: $nodes,
///     selection: $selectedId,
///     loadChildren: { node in
///         // Return children for the given node
///         return await fetchChildren(for: node.item)
///     },
///     onDoubleClick: { node in
///         // Handle double-click (e.g., navigate into directory)
///     }
/// )
/// ```
struct OutlineView<Item: OutlineItem>: View {
    @Binding var nodes: [OutlineViewNode<Item>]
    @Binding var selection: String?

    /// Called when a node is expanded to load its children
    let loadChildren: (OutlineViewNode<Item>) async -> [Item]

    /// Called when a row is double-clicked
    var onDoubleClick: ((OutlineViewNode<Item>) -> Void)?

    /// Called when a row is right-clicked (context menu)
    var onContextMenu: ((OutlineViewNode<Item>) -> Void)?

    /// Sort order for the size column
    @State private var sortAscending: Bool = false

    /// Parent size for percentage calculation (sum of all top-level nodes)
    private var parentSize: Int64 {
        nodes.reduce(0) { $0 + $1.item.size }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            headerRow

            Divider()

            // Content list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(sortedFlattenedNodes) { node in
                        OutlineRowView(
                            node: node,
                            isSelected: selection == node.id,
                            parentSize: parentSize,
                            onToggleExpand: { toggleExpand(node) },
                            onSelect: { selection = node.id },
                            onDoubleClick: { onDoubleClick?(node) }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack(spacing: 0) {
            // Name column header
            HStack(spacing: DesignTokens.Spacing.xxxs) {
                Text("Name")
                    .font(DesignTokens.Typography.captionEmphasized)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, DesignTokens.Spacing.lg + DesignTokens.Spacing.sm) // Account for disclosure + icon

            // Size column header (sortable)
            Button {
                withAnimation(DesignTokens.Animation.fast) {
                    sortAscending.toggle()
                }
            } label: {
                HStack(spacing: DesignTokens.Spacing.xxxs) {
                    Text("Size")
                        .font(DesignTokens.Typography.captionEmphasized)
                        .foregroundColor(DesignTokens.Colors.textSecondary)

                    Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                }
            }
            .buttonStyle(.plain)
            .frame(width: 80, alignment: .trailing)

            // Percentage column header
            Text("%")
                .font(DesignTokens.Typography.captionEmphasized)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.xxs)
        .background(DesignTokens.Colors.backgroundSecondary)
    }

    // MARK: - Flattened Nodes

    /// Flattens the tree structure for display in a LazyVStack
    private var sortedFlattenedNodes: [OutlineViewNode<Item>] {
        var result: [OutlineViewNode<Item>] = []

        // Sort top-level nodes by size
        let sortedTopLevel = nodes.sorted { first, second in
            sortAscending ? first.item.size < second.item.size : first.item.size > second.item.size
        }

        for node in sortedTopLevel {
            // Update percentage of parent for top-level nodes
            if parentSize > 0 {
                node.percentageOfParent = Double(node.item.size) / Double(parentSize) * 100
            }
            result.append(node)

            if node.isExpanded, let children = node.children {
                appendChildren(children, to: &result, parentSize: node.item.size)
            }
        }

        return result
    }

    /// Recursively appends children to the flattened list
    private func appendChildren(
        _ children: [OutlineViewNode<Item>],
        to result: inout [OutlineViewNode<Item>],
        parentSize: Int64
    ) {
        // Sort children by size
        let sortedChildren = children.sorted { first, second in
            sortAscending ? first.item.size < second.item.size : first.item.size > second.item.size
        }

        for child in sortedChildren {
            // Update percentage of parent
            if parentSize > 0 {
                child.percentageOfParent = Double(child.item.size) / Double(parentSize) * 100
            }
            result.append(child)

            if child.isExpanded, let grandchildren = child.children {
                appendChildren(grandchildren, to: &result, parentSize: child.item.size)
            }
        }
    }

    // MARK: - Expand/Collapse

    /// Toggle expansion state for a node
    private func toggleExpand(_ node: OutlineViewNode<Item>) {
        guard node.item.isExpandable else { return }

        if node.isExpanded {
            // Collapse
            withAnimation(DesignTokens.Animation.fast) {
                node.isExpanded = false
            }
        } else {
            // Expand - load children if needed
            if node.children == nil {
                node.isLoading = true
                Task {
                    let childItems = await loadChildren(node)
                    let childNodes = childItems.map { OutlineViewNode(item: $0, depth: node.depth + 1) }

                    await MainActor.run {
                        node.children = childNodes
                        node.isLoading = false
                        withAnimation(DesignTokens.Animation.fast) {
                            node.isExpanded = true
                        }
                    }
                }
            } else {
                withAnimation(DesignTokens.Animation.fast) {
                    node.isExpanded = true
                }
            }
        }
    }
}

// MARK: - OutlineRowView

/// A single row in the OutlineView
private struct OutlineRowView<Item: OutlineItem>: View {
    let node: OutlineViewNode<Item>
    let isSelected: Bool
    let parentSize: Int64
    let onToggleExpand: () -> Void
    let onSelect: () -> Void
    let onDoubleClick: () -> Void

    @State private var isHovered: Bool = false

    /// Row height constant
    private let rowHeight: CGFloat = 32

    /// Indentation per depth level
    private let indentPerLevel: CGFloat = 20

    var body: some View {
        HStack(spacing: 0) {
            // Indentation based on depth
            Color.clear
                .frame(width: CGFloat(node.depth) * indentPerLevel)

            // Disclosure triangle
            disclosureTriangle
                .frame(width: 20, alignment: .center)

            // Icon
            itemIcon
                .frame(width: 20, alignment: .center)
                .padding(.trailing, DesignTokens.Spacing.xxs)

            // Name column
            Text(node.item.name)
                .font(DesignTokens.Typography.subhead)
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Size column
            Text(formattedSize)
                .font(DesignTokens.Typography.monoCaption)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .frame(width: 80, alignment: .trailing)

            // Percentage column with bar
            percentageView
                .frame(width: 60, alignment: .trailing)
        }
        .frame(height: rowHeight)
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .background(rowBackground)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            onDoubleClick()
        }
        .onTapGesture(count: 1) {
            onSelect()
        }
        .onHover { hovering in
            withAnimation(DesignTokens.Animation.fast) {
                isHovered = hovering
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(node.item.isExpandable ? "Double-tap to expand" : "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Subviews

    @ViewBuilder
    private var disclosureTriangle: some View {
        if node.item.isExpandable {
            if node.isLoading {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 12, height: 12)
            } else {
                Button {
                    onToggleExpand()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                        .rotationEffect(.degrees(node.isExpanded ? 90 : 0))
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var itemIcon: some View {
        if node.item.isDirectory {
            Image(systemName: node.isExpanded ? "folder.fill" : "folder")
                .font(.system(size: 14))
                .foregroundColor(.blue)
        } else {
            Image(systemName: "doc.fill")
                .font(.system(size: 14))
                .foregroundColor(DesignTokens.Colors.textTertiary)
        }
    }

    private var percentageView: some View {
        HStack(spacing: DesignTokens.Spacing.xxxs) {
            // Percentage bar (mini)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(DesignTokens.Colors.separator.opacity(0.3))

                    Rectangle()
                        .fill(percentageBarColor)
                        .frame(width: geometry.size.width * CGFloat(min(node.percentageOfParent, 100)) / 100)
                }
            }
            .frame(width: 24, height: 4)
            .cornerRadius(2)

            // Percentage text
            Text(formattedPercentage)
                .font(DesignTokens.Typography.monoCaption)
                .foregroundColor(DesignTokens.Colors.textTertiary)
        }
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

    // MARK: - Formatting

    private var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: node.item.size, countStyle: .file)
    }

    private var formattedPercentage: String {
        if node.percentageOfParent >= 10 {
            return String(format: "%.0f%%", node.percentageOfParent)
        } else if node.percentageOfParent >= 1 {
            return String(format: "%.1f%%", node.percentageOfParent)
        } else if node.percentageOfParent > 0 {
            return "<1%"
        } else {
            return "0%"
        }
    }

    private var percentageBarColor: Color {
        if node.percentageOfParent >= 50 {
            return DesignTokens.Colors.warning
        } else if node.percentageOfParent >= 25 {
            return DesignTokens.Colors.info
        } else {
            return DesignTokens.Colors.accent
        }
    }

    private var accessibilityLabel: String {
        let typeLabel = node.item.isDirectory ? "Folder" : "File"
        return "\(typeLabel): \(node.item.name), Size: \(formattedSize), \(formattedPercentage) of parent"
    }
}

// MARK: - DirEntryOutlineItem

/// Adapter to make DirEntry conform to OutlineItem protocol
struct DirEntryOutlineItem: OutlineItem {
    let dirEntry: DirEntry

    var id: String { dirEntry.path }
    var name: String { dirEntry.name }
    var size: Int64 { dirEntry.size }
    var isDirectory: Bool { dirEntry.isDir }
    var isExpandable: Bool { dirEntry.isDir }

    init(_ dirEntry: DirEntry) {
        self.dirEntry = dirEntry
    }

    static func == (lhs: DirEntryOutlineItem, rhs: DirEntryOutlineItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Previews

#if DEBUG
/// Preview item for testing
struct PreviewOutlineItem: OutlineItem {
    let id: String
    let name: String
    let size: Int64
    let isDirectory: Bool
    let isExpandable: Bool

    static func == (lhs: PreviewOutlineItem, rhs: PreviewOutlineItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct OutlineView_Previews: PreviewProvider {
    static var previews: some View {
        OutlineViewPreviewWrapper()
            .frame(width: 500, height: 400)
            .background(DesignTokens.Colors.background)
            .previewDisplayName("OutlineView")
    }
}

private struct OutlineViewPreviewWrapper: View {
    @State private var nodes: [OutlineViewNode<PreviewOutlineItem>] = [
        OutlineViewNode(item: PreviewOutlineItem(
            id: "1",
            name: "Applications",
            size: 15_000_000_000,
            isDirectory: true,
            isExpandable: true
        )),
        OutlineViewNode(item: PreviewOutlineItem(
            id: "2",
            name: "Documents",
            size: 8_500_000_000,
            isDirectory: true,
            isExpandable: true
        )),
        OutlineViewNode(item: PreviewOutlineItem(
            id: "3",
            name: "Downloads",
            size: 4_200_000_000,
            isDirectory: true,
            isExpandable: true
        )),
        OutlineViewNode(item: PreviewOutlineItem(
            id: "4",
            name: "Desktop",
            size: 1_200_000_000,
            isDirectory: true,
            isExpandable: true
        )),
        OutlineViewNode(item: PreviewOutlineItem(
            id: "5",
            name: "large_backup.zip",
            size: 2_500_000_000,
            isDirectory: false,
            isExpandable: false
        ))
    ]

    @State private var selection: String?

    var body: some View {
        OutlineView(
            nodes: $nodes,
            selection: $selection,
            loadChildren: { node in
                // Simulate loading delay
                try? await Task.sleep(nanoseconds: 500_000_000)

                // Return mock children
                return [
                    PreviewOutlineItem(
                        id: "\(node.id)-child1",
                        name: "Subfolder 1",
                        size: Int64.random(in: 100_000_000...1_000_000_000),
                        isDirectory: true,
                        isExpandable: true
                    ),
                    PreviewOutlineItem(
                        id: "\(node.id)-child2",
                        name: "Subfolder 2",
                        size: Int64.random(in: 50_000_000...500_000_000),
                        isDirectory: true,
                        isExpandable: true
                    ),
                    PreviewOutlineItem(
                        id: "\(node.id)-file1",
                        name: "document.pdf",
                        size: Int64.random(in: 1_000_000...50_000_000),
                        isDirectory: false,
                        isExpandable: false
                    ),
                    PreviewOutlineItem(
                        id: "\(node.id)-file2",
                        name: "image.png",
                        size: Int64.random(in: 500_000...10_000_000),
                        isDirectory: false,
                        isExpandable: false
                    )
                ]
            },
            onDoubleClick: { node in
                print("Double-clicked: \(node.item.name)")
            }
        )
    }
}
#endif
