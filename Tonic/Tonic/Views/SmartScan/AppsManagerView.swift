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
    @State private var focusedItemID: UUID?

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
                            title: "Nothing to process",
                            message: selectedNav == .updater ? "Updater integration is a placeholder in this pass." : "No matching apps were found."
                        )
                    } else {
                        ScrollView {
                            VStack(spacing: TonicSpaceToken.one) {
                                ForEach(currentItems) { item in
                                    HybridRow(
                                        icon: "app.badge",
                                        title: item.title,
                                        subtitle: item.subtitle,
                                        metric: item.formattedSize,
                                        isSelected: selectedItemIDs.contains(item.id),
                                        badges: badges(for: item),
                                        onSelect: {
                                            focusedItemID = item.id
                                        },
                                        onToggle: {
                                            toggleSelection(for: item.id)
                                        }
                                    )
                                }

                                if let focusedItem = currentItems.first(where: { $0.id == focusedItemID }) {
                                    DetailPane(
                                        title: focusedItem.title,
                                        subtitle: focusedItem.subtitle,
                                        riskText: focusedItem.safeToRun ? nil : "Review this item before uninstalling.",
                                        includeExcludeTitle: "Include item",
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
        currentItems.filter { selectedItemIDs.contains($0.id) }
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

    private func toggleSelection(for id: UUID) {
        if selectedItemIDs.contains(id) {
            selectedItemIDs.remove(id)
        } else {
            selectedItemIDs.insert(id)
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
