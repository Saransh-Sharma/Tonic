import SwiftUI

struct SpaceManagerView: View {
    private enum SidebarItem: Hashable, Identifiable {
        case cleanup(CleanupNav)
        case clutter(ClutterNav)

        var id: String {
            switch self {
            case .cleanup(let nav): return "cleanup-\(nav.rawValue)"
            case .clutter(let nav): return "clutter-\(nav.rawValue)"
            }
        }

        var title: String {
            switch self {
            case .cleanup(let nav):
                switch nav {
                case .systemJunk: return "System Junk"
                case .mailAttachments: return "Mail Attachments"
                case .downloads: return "Downloads"
                case .trashBins: return "Trash Bins"
                case .xcodeJunk: return "Xcode Junk"
                case .hiddenSpace: return "Hidden Space"
                }
            case .clutter(let nav):
                switch nav {
                case .downloads: return "Clutter Downloads"
                case .duplicates: return "Duplicates"
                case .similarImages: return "Similar Images"
                case .largeOld: return "Large & Old"
                }
            }
        }
    }

    private struct SpaceCategory: Identifiable {
        let id: String
        let title: String
        let description: String
        let items: [SmartCareItem]
    }

    let domainResult: SmartCareDomainResult?
    let focus: SpaceFocus
    @Binding var selectedItemIDs: Set<UUID>
    let onBack: () -> Void
    let onRunSelected: ([SmartCareItem]) -> Void

    @State private var selectedSidebar: SidebarItem
    @State private var selectedCategoryID: String?
    @State private var expandedItemIDs: Set<UUID> = []
    @State private var childSelectionByParent: [UUID: Set<String>] = [:]
    private let accessBroker = AccessBroker.shared

    init(
        domainResult: SmartCareDomainResult?,
        focus: SpaceFocus,
        selectedItemIDs: Binding<Set<UUID>>,
        onBack: @escaping () -> Void,
        onRunSelected: @escaping ([SmartCareItem]) -> Void
    ) {
        self.domainResult = domainResult
        self.focus = focus
        self._selectedItemIDs = selectedItemIDs
        self.onBack = onBack
        self.onRunSelected = onRunSelected

        switch focus {
        case .spaceRoot:
            _selectedSidebar = State(initialValue: .cleanup(.systemJunk))
            _selectedCategoryID = State(initialValue: nil)
        case .cleanup(let nav, let categoryId, _):
            _selectedSidebar = State(initialValue: .cleanup(nav))
            _selectedCategoryID = State(initialValue: categoryId?.raw)
        case .clutter(let nav, _, _, _):
            _selectedSidebar = State(initialValue: .clutter(nav))
            _selectedCategoryID = State(initialValue: nav.rawValue)
        }
    }

    var body: some View {
        ManagerShell(
            header: AnyView(
                PageHeader(
                    title: "Space Manager",
                    subtitle: "System Cleanup + Clutter",
                    showsBack: true,
                    searchText: nil,
                    onBack: onBack,
                    trailing: AnyView(RecommendationBadge())
                )
            ),
            left: {
                LeftNavPane {
                    SidebarSectionHeader(title: "Cleanup")
                    ForEach(cleanupSidebarItems, id: \.id) { item in
                        LeftNavListItem(
                            title: item.title,
                            count: countForSidebar(item),
                            isSelected: selectedSidebar == item,
                            action: {
                                selectedSidebar = item
                                selectedCategoryID = categories.first?.id
                            }
                        )
                    }

                    SidebarSectionHeader(title: "Clutter")
                    ForEach(clutterSidebarItems, id: \.id) { item in
                        LeftNavListItem(
                            title: item.title,
                            count: countForSidebar(item),
                            isSelected: selectedSidebar == item,
                            action: {
                                selectedSidebar = item
                                selectedCategoryID = categories.first?.id
                            }
                        )
                    }
                }
            },
            middle: {
                MiddleSummaryPane {
                    SectionSummaryCard(
                        title: selectedSidebar.title,
                        description: "Choose a category before selecting items to clean.",
                        metrics: [
                            "All: \(categories.reduce(0) { $0 + $1.items.count })",
                            "Selected: \(selectedCount)",
                            "Space: \(formatBytes(totalCategorySize))"
                        ]
                    )

                    if categories.isEmpty {
                        PlaceholderStatePanel(
                            title: "No categories",
                            message: "No categories available for this section."
                        )
                    } else {
                        ForEach(categories) { category in
                            LeftNavListItem(
                                title: category.title,
                                count: category.items.count,
                                isSelected: category.id == activeCategory?.id,
                                action: {
                                    selectedCategoryID = category.id
                                }
                            )
                        }
                    }
                }
            },
            right: {
                RightItemsPane {
                    ManagerSummaryStrip(text: summaryText)

                    if blockedItemsCount > 0 {
                        HStack(spacing: TonicSpaceToken.two) {
                            Text("\(blockedItemsCount) item\(blockedItemsCount == 1 ? "" : "s") need additional access.")
                                .font(TonicTypeToken.micro)
                                .foregroundStyle(TonicTextToken.secondary)
                            Spacer()
                            Button("Grant Access") {
                                _ = accessBroker.addScopeUsingOpenPanel()
                                accessBroker.refreshStatuses()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                        .padding(.horizontal, TonicSpaceToken.two)
                        .padding(.vertical, TonicSpaceToken.one)
                        .background(TonicGlassToken.fill)
                        .clipShape(RoundedRectangle(cornerRadius: TonicRadiusToken.m))
                    }

                    if let activeCategory {
                        if activeCategory.items.isEmpty {
                            PlaceholderStatePanel(
                                title: "Coming soon",
                                message: activeCategory.description
                            )
                        } else {
                            ScrollView {
                                VStack(spacing: TonicSpaceToken.one) {
                                    ForEach(activeCategory.items) { item in
                                        row(for: item)
                                    }
                                }
                            }
                        }
                    } else {
                        PlaceholderStatePanel(
                            title: "Select a category",
                            message: "Choose a category from the middle pane to review items."
                        )
                    }
                }
            },
            footer: AnyView(
                StickyActionBar(
                    summary: "Selected: \(selectedRunnableItems.count) items • \(formatBytes(selectedRunnableItems.reduce(0) { $0 + $1.size }))",
                    variant: .cleanUp,
                    enabled: !selectedRunnableItems.isEmpty,
                    action: {
                        onRunSelected(selectedRunnableItems)
                    }
                )
            )
        )
        .padding(TonicSpaceToken.three)
        .onAppear {
            if selectedCategoryID == nil {
                selectedCategoryID = categories.first?.id
            }
        }
    }

    private var cleanupSidebarItems: [SidebarItem] {
        [
            .cleanup(.systemJunk),
            .cleanup(.mailAttachments),
            .cleanup(.downloads),
            .cleanup(.trashBins),
            .cleanup(.xcodeJunk),
            .cleanup(.hiddenSpace)
        ]
    }

    private var clutterSidebarItems: [SidebarItem] {
        [
            .clutter(.downloads),
            .clutter(.duplicates),
            .clutter(.similarImages),
            .clutter(.largeOld)
        ]
    }

    private var categories: [SpaceCategory] {
        switch selectedSidebar {
        case .cleanup(let nav):
            return cleanupCategories(for: nav)
        case .clutter(let nav):
            return clutterCategories(for: nav)
        }
    }

    private var activeCategory: SpaceCategory? {
        if let selectedCategoryID,
           let selected = categories.first(where: { $0.id == selectedCategoryID }) {
            return selected
        }
        return categories.first
    }

    private var totalCategorySize: Int64 {
        categories.flatMap(\.items).reduce(0) { $0 + $1.size }
    }

    private var selectedCount: Int {
        categories.flatMap(\.items).filter { hasSelection(for: $0) }.count
    }

    private var selectedRunnableItems: [SmartCareItem] {
        categories
            .flatMap(\.items)
            .compactMap(projectedSelectedItem(for:))
            .filter { $0.safeToRun && $0.action.isRunnable }
    }

    private var blockedItemsCount: Int {
        categories
            .flatMap(\.items)
            .filter { $0.accessState != .ready }
            .count
    }

    private var summaryText: String {
        guard let activeCategory else {
            return "No category selected"
        }

        let total = activeCategory.items.count
        let safe = activeCategory.items.filter { $0.safeToRun }.count
        let needsReview = max(0, total - safe)
        let needsAccess = activeCategory.items.filter { $0.accessState != .ready }.count
        let size = activeCategory.items.reduce(0) { $0 + $1.size }
        return "\(activeCategory.title) · \(formatBytes(size)) · Safe items: \(safe) · Needs review: \(needsReview) · Needs access: \(needsAccess)"
    }

    @ViewBuilder
    private func row(for item: SmartCareItem) -> some View {
        ExpandableSelectionRow(
            icon: iconName(for: item),
            title: item.title,
            subtitle: itemSubtitle(for: item),
            metric: item.formattedSize,
            selectionState: selectionState(for: item),
            isExpandable: isExpandable(item),
            isExpanded: expandedItemIDs.contains(item.id),
            badges: badges(for: item),
            children: childRows(for: item),
            onToggleParent: {
                toggleParentSelection(for: item)
            },
            onToggleExpanded: {
                guard isExpandable(item) else { return }
                if expandedItemIDs.contains(item.id) {
                    expandedItemIDs.remove(item.id)
                } else {
                    expandedItemIDs.insert(item.id)
                }
            },
            onToggleChild: { childID in
                toggleChildSelection(for: item, childID: childID)
            }
        )
    }

    private func cleanupCategories(for nav: CleanupNav) -> [SpaceCategory] {
        switch nav {
        case .systemJunk:
            return [
                category(id: "systemJunk", title: "System Junk", fallbackDescription: "Cached files and logs", groupTitle: "System Junk"),
                category(id: "xcodeJunk", title: "Xcode Junk", fallbackDescription: "Build artifacts and developer caches", groupTitle: "Xcode Junk"),
                category(id: "hiddenSpace", title: "Hidden Space", fallbackDescription: "Project and cache artifacts", groupTitle: "Hidden Space")
            ]
        case .mailAttachments:
            return [category(id: "mailAttachments", title: "Mail Attachments", fallbackDescription: "Mail attachments stored locally", groupTitle: "Mail Attachments")]
        case .downloads:
            return [category(id: "downloads", title: "Downloads", fallbackDescription: "Downloads and old files", groupTitle: "Downloads")]
        case .trashBins:
            return [category(id: "trashBins", title: "Trash Bins", fallbackDescription: "Items in Trash", groupTitle: "Trash Bins")]
        case .xcodeJunk:
            return [category(id: "xcodeJunk", title: "Xcode Junk", fallbackDescription: "Build artifacts and developer caches", groupTitle: "Xcode Junk")]
        case .hiddenSpace:
            return [category(id: "hiddenSpace", title: "Hidden Space", fallbackDescription: "Project and cache artifacts", groupTitle: "Hidden Space")]
        }
    }

    private func clutterCategories(for nav: ClutterNav) -> [SpaceCategory] {
        switch nav {
        case .downloads:
            return [category(id: "downloads", title: "Downloads", fallbackDescription: "Downloads and old files", groupTitle: "Downloads")]
        case .duplicates:
            return [placeholderCategory(id: "duplicates", title: "Duplicates", description: "Duplicate scanner data is not wired in this pass.")]
        case .similarImages:
            return [placeholderCategory(id: "similarImages", title: "Similar Images", description: "Similar image scanner data is not wired in this pass.")]
        case .largeOld:
            return [placeholderCategory(id: "largeOld", title: "Large & Old Files", description: "Large/old file scanner data is not wired in this pass.")]
        }
    }

    private func category(id: String, title: String, fallbackDescription: String, groupTitle: String) -> SpaceCategory {
        guard let group = domainResult?.groups.first(where: { $0.title == groupTitle }) else {
            return SpaceCategory(id: id, title: title, description: fallbackDescription, items: [])
        }
        return SpaceCategory(id: id, title: title, description: group.description, items: group.items)
    }

    private func placeholderCategory(id: String, title: String, description: String) -> SpaceCategory {
        SpaceCategory(id: id, title: title, description: description, items: [])
    }

    private func countForSidebar(_ item: SidebarItem) -> Int {
        switch item {
        case .cleanup(let nav):
            return cleanupCategories(for: nav).flatMap(\.items).count
        case .clutter(let nav):
            return clutterCategories(for: nav).flatMap(\.items).count
        }
    }

    private func hasSelection(for item: SmartCareItem) -> Bool {
        !selectedChildIDs(for: item).isEmpty
    }

    private func selectedChildIDs(for item: SmartCareItem) -> Set<String> {
        let childIDs = childEntries(for: item).map(\.id)
        if let explicit = childSelectionByParent[item.id] {
            return explicit.intersection(Set(childIDs))
        }
        if selectedItemIDs.contains(item.id) {
            return Set(childIDs)
        }
        return []
    }

    private func selectionState(for item: SmartCareItem) -> ParentSelectionState {
        let total = childEntries(for: item).count
        let selected = selectedChildIDs(for: item).count
        if selected == 0 { return .none }
        if selected >= total { return .all }
        return .some
    }

    private func isExpandable(_ item: SmartCareItem) -> Bool {
        childEntries(for: item).count > 1
    }

    private func childRows(for item: SmartCareItem) -> [ExpandableSelectionChild] {
        let childEntries = childEntries(for: item)
        let selected = selectedChildIDs(for: item)

        return childEntries.map { entry in
            ExpandableSelectionChild(
                id: entry.id,
                title: entry.title,
                subtitle: entry.subtitle,
                isSelected: selected.contains(entry.id)
            )
        }
    }

    private func childEntries(for item: SmartCareItem) -> [(id: String, title: String, subtitle: String?)] {
        let uniquePaths = uniqueOrderedPaths(item.paths)
        if !uniquePaths.isEmpty {
            return uniquePaths.map { path in
                let fileName = URL(fileURLWithPath: path).lastPathComponent
                return (id: path, title: fileName.isEmpty ? path : fileName, subtitle: path)
            }
        }

        if item.count > 1 {
            return (1...item.count).map { index in
                let id = "\(item.id.uuidString)-\(index)"
                return (id: id, title: "\(item.title) \(index)", subtitle: nil)
            }
        }

        return [(id: "__self__", title: item.title, subtitle: nil)]
    }

    private func uniqueOrderedPaths(_ paths: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for path in paths where !seen.contains(path) {
            seen.insert(path)
            result.append(path)
        }
        return result
    }

    private func toggleParentSelection(for item: SmartCareItem) {
        let childIDs = Set(childEntries(for: item).map(\.id))
        let currentlySelected = selectedChildIDs(for: item)
        let shouldSelectAll = currentlySelected.count < childIDs.count
        let updated = shouldSelectAll ? childIDs : []
        childSelectionByParent[item.id] = updated
        syncParentSelectionFlag(itemID: item.id, selectedChildCount: updated.count)
    }

    private func toggleChildSelection(for item: SmartCareItem, childID: String) {
        var updated = selectedChildIDs(for: item)
        if updated.contains(childID) {
            updated.remove(childID)
        } else {
            updated.insert(childID)
        }
        childSelectionByParent[item.id] = updated
        syncParentSelectionFlag(itemID: item.id, selectedChildCount: updated.count)
    }

    private func syncParentSelectionFlag(itemID: UUID, selectedChildCount: Int) {
        if selectedChildCount > 0 {
            selectedItemIDs.insert(itemID)
        } else {
            selectedItemIDs.remove(itemID)
        }
    }

    private func projectedSelectedItem(for item: SmartCareItem) -> SmartCareItem? {
        let selectedChildIDs = selectedChildIDs(for: item)
        guard !selectedChildIDs.isEmpty else { return nil }

        switch item.action {
        case .delete:
            let paths = uniqueOrderedPaths(item.paths).filter { selectedChildIDs.contains($0) }
            guard !paths.isEmpty else { return nil }
            let fullCount = max(uniqueOrderedPaths(item.paths).count, 1)
            let proportion = Double(paths.count) / Double(fullCount)
            let scaledSize = Int64((Double(item.size) * proportion).rounded())
            let adjustedSize = item.size == 0 ? 0 : max(1, scaledSize)

            return SmartCareItem(
                id: item.id,
                domain: item.domain,
                groupId: item.groupId,
                title: item.title,
                subtitle: item.subtitle,
                size: adjustedSize,
                count: paths.count,
                safeToRun: item.safeToRun,
                isSmartSelected: item.isSmartSelected,
                action: .delete(paths: paths),
                paths: paths,
                scoreImpact: item.scoreImpact,
                accessState: item.accessState,
                blockedReason: item.blockedReason
            )
        case .runOptimization:
            return item
        case .none:
            return item
        }
    }

    private func iconName(for item: SmartCareItem) -> String {
        let lowercased = item.title.lowercased()
        if lowercased.contains("cache") { return "archivebox" }
        if lowercased.contains("trash") { return "trash" }
        if lowercased.contains("xcode") { return "hammer" }
        if lowercased.contains("download") { return "arrow.down.circle" }
        if lowercased.contains("log") { return "doc.text" }
        return "folder"
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func badges(for item: SmartCareItem) -> [MetaBadgeStyle] {
        switch item.accessState {
        case .ready:
            return item.safeToRun ? [.recommended] : [.needsReview]
        case .needsAccess:
            return [.needsAccess]
        case .limited:
            return [item.blockedReason == .macOSProtected ? .limitedByMacOS : .needsAccess]
        }
    }

    private func itemSubtitle(for item: SmartCareItem) -> String {
        if let blocked = item.blockedReason {
            return "\(item.subtitle) • \(blocked.userMessage)"
        }
        switch item.accessState {
        case .ready:
            return item.subtitle
        case .needsAccess:
            return "\(item.subtitle) • Needs access"
        case .limited:
            return "\(item.subtitle) • Limited by macOS"
        }
    }
}
