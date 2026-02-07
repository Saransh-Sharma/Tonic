import SwiftUI

extension AppFilter: Identifiable {
    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .unused: return "Unused"
        case .suspicious: return "Suspicious"
        case .large: return "Large"
        }
    }
}

struct AppsManagerView: View {
    let domainResult: SmartCareDomainResult?
    let focus: AppsFocus
    @Binding var selectedItemIDs: Set<UUID>
    let onBack: () -> Void
    let onRunSelected: ([SmartCareItem]) -> Void

    @State private var selectedNav: AppsNav
    @State private var selectedFilter: AppFilter
    @State private var expandedItemIDs: Set<UUID> = []
    @State private var childSelectionByParent: [UUID: Set<String>] = [:]

    init(
        domainResult: SmartCareDomainResult?,
        focus: AppsFocus,
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
        case .root(let defaultNav):
            _selectedNav = State(initialValue: defaultNav)
            _selectedFilter = State(initialValue: .all)
        case .uninstaller(let filter):
            _selectedNav = State(initialValue: .uninstaller)
            _selectedFilter = State(initialValue: filter)
        case .updater:
            _selectedNav = State(initialValue: .updater)
            _selectedFilter = State(initialValue: .all)
        case .leftovers:
            _selectedNav = State(initialValue: .leftovers)
            _selectedFilter = State(initialValue: .all)
        }
    }

    var body: some View {
        ManagerShell(
            header: AnyView(
                PageHeader(
                    title: "Applications Manager",
                    subtitle: "Uninstall + Updates + Leftovers",
                    showsBack: true,
                    searchText: nil,
                    onBack: onBack,
                    trailing: AnyView(RecommendationBadge())
                )
            ),
            left: {
                LeftNavPane {
                    LeftNavListItem(
                        title: "Uninstaller",
                        count: allUninstallerItems.count,
                        isSelected: selectedNav == .uninstaller,
                        action: { selectedNav = .uninstaller }
                    )
                    LeftNavListItem(
                        title: "Updater",
                        count: updaterItems.count,
                        isSelected: selectedNav == .updater,
                        action: { selectedNav = .updater }
                    )
                    LeftNavListItem(
                        title: "Leftovers",
                        count: leftoversItems.count,
                        isSelected: selectedNav == .leftovers,
                        action: { selectedNav = .leftovers }
                    )
                }
            },
            middle: {
                MiddleSummaryPane {
                    SectionSummaryCard(
                        title: selectedNavTitle,
                        description: selectedNavDescription,
                        metrics: [
                            "All: \(currentItems.count)",
                            "Selected: \(selectedItems.count)",
                            "Estimated: \(formatBytes(selectedItems.reduce(0) { $0 + $1.size }))"
                        ]
                    )

                    if selectedNav == .uninstaller {
                        SegmentedFilter(
                            options: AppFilter.allCases,
                            selected: $selectedFilter,
                            title: { $0.title }
                        )
                    }

                    if currentItems.isEmpty {
                        PlaceholderStatePanel(
                            title: "No app items",
                            message: selectedNav == .updater ? "Updater data is not wired in this pass." : "No items found for this section."
                        )
                    } else {
                        ForEach(currentItems) { item in
                            LeftNavListItem(
                                title: item.title,
                                count: item.count,
                                isSelected: expandedItemIDs.contains(item.id),
                                action: {
                                    guard isExpandable(item) else { return }
                                    if expandedItemIDs.contains(item.id) {
                                        expandedItemIDs.remove(item.id)
                                    } else {
                                        expandedItemIDs.insert(item.id)
                                    }
                                }
                            )
                        }
                    }
                }
            },
            right: {
                RightItemsPane {
                    ManagerSummaryStrip(text: summaryText)

                    if currentItems.isEmpty {
                        PlaceholderStatePanel(
                            title: "Nothing to process",
                            message: selectedNav == .updater ? "Updater integration is a placeholder in this pass." : "No matching apps were found."
                        )
                    } else {
                        ScrollView {
                            VStack(spacing: TonicSpaceToken.one) {
                                ForEach(currentItems) { item in
                                    ExpandableSelectionRow(
                                        icon: "app.badge",
                                        title: item.title,
                                        subtitle: item.subtitle,
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
                            }
                        }
                    }
                }
            },
            footer: AnyView(
                StickyActionBar(
                    summary: "Selected: \(selectedItems.count) apps • Estimated space: \(formatBytes(selectedItems.reduce(0) { $0 + $1.size }))",
                    variant: .uninstall,
                    enabled: !selectedRunnableItems.isEmpty,
                    action: {
                        onRunSelected(selectedRunnableItems)
                    }
                )
            )
        )
        .padding(TonicSpaceToken.three)
    }

    private var allItems: [SmartCareItem] {
        domainResult?.items ?? []
    }

    private var allUninstallerItems: [SmartCareItem] {
        allItems.filter { item in
            let title = item.title.lowercased()
            return title.contains("unused") || title.contains("duplicate") || title.contains("large")
        }
    }

    private var leftoversItems: [SmartCareItem] {
        allItems.filter { $0.title.lowercased().contains("orphaned") }
    }

    private var updaterItems: [SmartCareItem] {
        []
    }

    private var currentItems: [SmartCareItem] {
        switch selectedNav {
        case .uninstaller:
            return allUninstallerItems.filter(matchesFilter)
        case .updater:
            return updaterItems
        case .leftovers:
            return leftoversItems
        }
    }

    private var selectedItems: [SmartCareItem] {
        currentItems.compactMap(projectedSelectedItem(for:))
    }

    private var selectedRunnableItems: [SmartCareItem] {
        selectedItems.filter { $0.safeToRun && $0.action.isRunnable }
    }

    private var selectedNavTitle: String {
        switch selectedNav {
        case .uninstaller: return "Uninstaller"
        case .updater: return "Updater"
        case .leftovers: return "Leftovers"
        }
    }

    private var selectedNavDescription: String {
        switch selectedNav {
        case .uninstaller: return "Remove apps with related support files."
        case .updater: return "Review outdated apps before updating."
        case .leftovers: return "Remove orphaned files from removed apps."
        }
    }

    private var summaryText: String {
        "\(selectedNavTitle) · Selected: \(selectedItems.count) · Estimated: \(formatBytes(selectedItems.reduce(0) { $0 + $1.size }))"
    }

    private func matchesFilter(_ item: SmartCareItem) -> Bool {
        switch selectedFilter {
        case .all:
            return true
        case .unused:
            return item.title.lowercased().contains("unused")
        case .suspicious:
            return item.title.lowercased().contains("duplicate")
        case .large:
            return item.title.lowercased().contains("large")
        }
    }

    private func badges(for item: SmartCareItem) -> [MetaBadgeStyle] {
        let title = item.title.lowercased()
        var results: [MetaBadgeStyle] = []

        if title.contains("unused") {
            results.append(.unused)
        }
        if title.contains("duplicate") {
            results.append(.suspicious)
        }
        if title.contains("large") {
            results.append(.large)
        }
        if title.contains("orphaned") {
            results.append(.leftovers)
        }
        if item.safeToRun {
            results.append(.recommended)
        }

        if results.isEmpty {
            results.append(.needsReview)
        }
        return results
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
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
                scoreImpact: item.scoreImpact
            )
        case .runOptimization:
            return item
        case .none:
            return item
        }
    }
}
