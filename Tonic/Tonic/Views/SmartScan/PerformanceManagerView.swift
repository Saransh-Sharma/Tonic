import SwiftUI

struct PerformanceManagerView: View {
    let domainResult: SmartCareDomainResult?
    let focus: PerformanceFocus
    @Binding var selectedItemIDs: Set<UUID>
    let onBack: () -> Void
    let onRunSelected: ([SmartCareItem]) -> Void

    @State private var selectedNav: PerformanceNav
    @State private var focusedItemID: UUID?

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
                                isSelected: focusedItemID == item.id,
                                action: {
                                    focusedItemID = item.id
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
                                    if selectedNav == .maintenanceTasks {
                                        SelectableRow(
                                            icon: "bolt.circle",
                                            title: item.title,
                                            subtitle: item.subtitle,
                                            metric: "Task",
                                            isSelected: selectedItemIDs.contains(item.id),
                                            onSelect: {
                                                focusedItemID = item.id
                                            },
                                            onToggle: {
                                                toggleSelection(for: item.id)
                                            }
                                        )
                                    } else {
                                        HybridRow(
                                            icon: "power",
                                            title: item.title,
                                            subtitle: item.subtitle,
                                            metric: item.formattedSize,
                                            isSelected: selectedItemIDs.contains(item.id),
                                            badges: item.safeToRun ? [.recommended] : [.needsReview],
                                            onSelect: {
                                                focusedItemID = item.id
                                            },
                                            onToggle: {
                                                toggleSelection(for: item.id)
                                            }
                                        )
                                    }
                                }

                                if let focusedItem = currentItems.first(where: { $0.id == focusedItemID }) {
                                    DetailPane(
                                        title: focusedItem.title,
                                        subtitle: focusedItem.subtitle,
                                        riskText: focusedItem.safeToRun ? nil : "This startup item is system-managed. Use System Settings when needed.",
                                        includeExcludeTitle: selectedNav == .maintenanceTasks ? "Include task" : "Include item",
                                        include: Binding(
                                            get: { selectedItemIDs.contains(focusedItem.id) },
                                            set: { include in
                                                if include {
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
        currentItems.filter { selectedItemIDs.contains($0.id) }
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

    private func toggleSelection(for id: UUID) {
        if selectedItemIDs.contains(id) {
            selectedItemIDs.remove(id)
        } else {
            selectedItemIDs.insert(id)
        }
    }
}
