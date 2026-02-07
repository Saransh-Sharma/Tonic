import SwiftUI

struct PerformanceManagerView: View {
    let domainResult: SmartCareDomainResult?
    let focus: PerformanceFocus
    @Binding var selectedItemIDs: Set<UUID>
    let onBack: () -> Void
    let onRunSelected: ([SmartCareItem]) -> Void

    @State private var selectedNav: PerformanceNav
    @State private var expandedItemIDs: Set<UUID> = []
    @State private var childSelectionByParent: [UUID: Set<String>] = [:]

    init(
        domainResult: SmartCareDomainResult?,
        focus: PerformanceFocus,
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
        case .maintenanceTasks:
            _selectedNav = State(initialValue: .maintenanceTasks)
        case .loginItems:
            _selectedNav = State(initialValue: .loginItems)
        case .backgroundItems:
            _selectedNav = State(initialValue: .backgroundItems)
        }
    }

    var body: some View {
        ManagerShell(
            header: AnyView(
                PageHeader(
                    title: "Performance Manager",
                    subtitle: "Optimize + Startup Control",
                    showsBack: true,
                    searchText: nil,
                    onBack: onBack,
                    trailing: AnyView(RecommendationBadge())
                )
            ),
            left: {
                LeftNavPane {
                    SidebarSectionHeader(title: "Optimize")
                    LeftNavListItem(
                        title: "Maintenance Tasks",
                        count: items(for: .maintenanceTasks).count,
                        isSelected: selectedNav == .maintenanceTasks,
                        action: { selectedNav = .maintenanceTasks }
                    )

                    SidebarSectionHeader(title: "Startup")
                    LeftNavListItem(
                        title: "Login Items",
                        count: items(for: .loginItems).count,
                        isSelected: selectedNav == .loginItems,
                        action: { selectedNav = .loginItems }
                    )
                    LeftNavListItem(
                        title: "Background Items",
                        count: items(for: .backgroundItems).count,
                        isSelected: selectedNav == .backgroundItems,
                        action: { selectedNav = .backgroundItems }
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
                            "Selected: \(selectedInCurrent.count)",
                            selectedNav == .maintenanceTasks ? "Action: Run" : "Action: Disable"
                        ]
                    )

                    if currentItems.isEmpty {
                        EmptyStatePanel(
                            icon: "checkmark.circle",
                            title: "No items found",
                            message: selectedNav == .maintenanceTasks ? "No maintenance tasks available." : "No startup items found."
                        )
                    } else {
                        ForEach(currentItems) { item in
                            LeftNavListItem(
                                title: item.title,
                                count: item.count,
                                isSelected: expandedItemIDs.contains(item.id),
                                action: {
                                    if isExpandable(item) {
                                        if expandedItemIDs.contains(item.id) {
                                            expandedItemIDs.remove(item.id)
                                        } else {
                                            expandedItemIDs.insert(item.id)
                                        }
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
                            title: "Nothing to review",
                            message: selectedNav == .maintenanceTasks ? "No maintenance tasks returned by the scanner." : "No startup control items returned by the scanner."
                        )
                    } else {
                        ScrollView {
                            VStack(spacing: TonicSpaceToken.one) {
                                ForEach(currentItems) { item in
                                    ExpandableSelectionRow(
                                        icon: selectedNav == .maintenanceTasks ? "bolt.circle" : "power",
                                        title: item.title,
                                        subtitle: item.subtitle,
                                        metric: selectedNav == .maintenanceTasks ? "Task" : item.formattedSize,
                                        selectionState: selectionState(for: item),
                                        isExpandable: isExpandable(item),
                                        isExpanded: expandedItemIDs.contains(item.id),
                                        badges: selectedNav == .maintenanceTasks ? [] : (item.safeToRun ? [.recommended] : [.needsReview]),
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
                    summary: footerSummary,
                    variant: selectedNav == .maintenanceTasks ? .run : .disable,
                    enabled: footerEnabled,
                    action: {
                        onRunSelected(selectedRunnableItems)
                    }
                )
            )
        )
        .padding(TonicSpaceToken.three)
    }

    private var selectedNavTitle: String {
        switch selectedNav {
        case .maintenanceTasks: return "Maintenance Tasks"
        case .loginItems: return "Login Items"
        case .backgroundItems: return "Background Items"
        }
    }

    private var selectedNavDescription: String {
        switch selectedNav {
        case .maintenanceTasks:
            return "Run curated optimization routines in a single pass."
        case .loginItems:
            return "Review applications that launch when you sign in."
        case .backgroundItems:
            return "Review processes that run continuously in the background."
        }
    }

    private var currentItems: [SmartCareItem] {
        items(for: selectedNav)
    }

    private var selectedInCurrent: [SmartCareItem] {
        currentItems.compactMap(projectedSelectedItem(for:))
    }

    private var selectedRunnableItems: [SmartCareItem] {
        selectedInCurrent.filter { $0.safeToRun && $0.action.isRunnable }
    }

    private var summaryText: String {
        switch selectedNav {
        case .maintenanceTasks:
            return "Maintenance Tasks · \(currentItems.count) tasks · Ready to run: \(selectedRunnableItems.count)"
        case .loginItems:
            return "Startup Control · Login Items · Selected: \(selectedInCurrent.count)"
        case .backgroundItems:
            return "Startup Control · Background Items · Selected: \(selectedInCurrent.count)"
        }
    }

    private var footerSummary: String {
        if selectedNav == .maintenanceTasks {
            return "Selected: \(selectedRunnableItems.count) tasks"
        }
        return "Selected: \(selectedInCurrent.count) items"
    }

    private var footerEnabled: Bool {
        if selectedNav == .maintenanceTasks {
            return !selectedRunnableItems.isEmpty
        }
        return !selectedInCurrent.isEmpty
    }

    private func items(for nav: PerformanceNav) -> [SmartCareItem] {
        let groupTitle: String
        switch nav {
        case .maintenanceTasks:
            groupTitle = "Maintenance Tasks"
        case .loginItems:
            groupTitle = "Login Items"
        case .backgroundItems:
            groupTitle = "Background Items"
        }

        return domainResult?.groups.first(where: { $0.title == groupTitle })?.items ?? []
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
