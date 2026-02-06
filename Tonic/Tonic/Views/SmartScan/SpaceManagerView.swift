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
    @State private var focusedItemID: UUID?

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
                                    focusedItemID = nil
                                }
                            )
                        }
                    }
                }
            },
            right: {
                RightItemsPane {
                    ManagerSummaryStrip(text: summaryText)

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

                                    if let focusedItem = activeCategory.items.first(where: { $0.id == focusedItemID }) {
                                        DetailPane(
                                            title: focusedItem.title,
                                            subtitle: focusedItem.subtitle,
                                            riskText: focusedItem.safeToRun ? nil : "This item requires manual review before cleanup.",
                                            includeExcludeTitle: "Include in cleanup",
                                            include: Binding(
                                                get: { selectedItemIDs.contains(focusedItem.id) },
                                                set: { isIncluded in
                                                    if isIncluded {
                                                        selectedItemIDs.insert(focusedItem.id)
                                                    } else {
                                                        selectedItemIDs.remove(focusedItem.id)
                                                    }
                                                }
                                            )
                                        )
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
        categories.flatMap(\.items).filter { selectedItemIDs.contains($0.id) }.count
    }

    private var selectedRunnableItems: [SmartCareItem] {
        categories
            .flatMap(\.items)
            .filter { selectedItemIDs.contains($0.id) && $0.safeToRun && $0.action.isRunnable }
    }

    private var summaryText: String {
        guard let activeCategory else {
            return "No category selected"
        }

        let total = activeCategory.items.count
        let safe = activeCategory.items.filter { $0.safeToRun }.count
        let needsReview = max(0, total - safe)
        let size = activeCategory.items.reduce(0) { $0 + $1.size }
        return "\(activeCategory.title) · \(formatBytes(size)) · Safe items: \(safe) · Needs review: \(needsReview)"
    }

    @ViewBuilder
    private func row(for item: SmartCareItem) -> some View {
        if item.safeToRun && item.action.isRunnable {
            SelectableRow(
                icon: iconName(for: item),
                title: item.title,
                subtitle: item.subtitle,
                metric: item.formattedSize,
                isSelected: selectedItemIDs.contains(item.id),
                onSelect: {
                    focusedItemID = item.id
                },
                onToggle: {
                    toggleSelection(for: item.id)
                }
            )
        } else {
            DrilldownRow(
                icon: iconName(for: item),
                title: item.title,
                subtitle: item.subtitle,
                metric: item.formattedSize,
                action: {
                    focusedItemID = item.id
                }
            )
        }
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

    private func toggleSelection(for id: UUID) {
        if selectedItemIDs.contains(id) {
            selectedItemIDs.remove(id)
        } else {
            selectedItemIDs.insert(id)
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
}
