//
//  MenuBarDashboardView.swift
//  Tonic
//
//  The dedicated Menu Bar management screen — a Bartender-class command center
//  for hiding, organizing, automating, and styling menu bar items. Discovery
//  works everywhere; item control (moves, activation, presets, triggers,
//  spacing, styling) is direct-build only.
//

import AppKit
import SwiftUI

struct MenuBarDashboardView: View {
    var isActive: Bool = true

    @State private var manager = MenuBarManager.shared
    @State private var store = MenuBarManagerSettingsStore.shared
    @State private var workspace = MenuBarWorkspaceStore.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var toast: ToastData?
    @State private var editingTrigger: TriggerEditorContext?
    @State private var lastAppliedLayout: [String: MenuBarSection]?
    @State private var lastUndoToken: MenuBarLayoutUndoToken?
    @State private var lastLayoutReceipt: String?
    @State private var showsSetup = false
    @State private var customItemEditor: CustomItemEditorContext?
    @State private var groupEditor: GroupEditorContext?
    @State private var receiptMotionTrigger = 0
    @State private var completionMotionTrigger = 0

    /// Wraps an optional trigger so the sheet can distinguish "new" (nil) from
    /// "edit" while still being Identifiable.
    private struct TriggerEditorContext: Identifiable {
        let id = UUID()
        let trigger: MenuBarTrigger?
        let seedItemKey: String?
    }
    private struct GroupEditorContext: Identifiable { let id = UUID(); let group: MenuBarItemGroup? }
    private struct CustomItemEditorContext: Identifiable { let id = UUID(); let item: CustomMenuBarItem? }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: TonicDS.Space.lg) {
                TonicPageHeader("Menu Bar", subtitle: "Hide, organize, and automate your menu bar")
                    .tonicAppear(appeared, index: 0, reduceMotion: reduceMotion)

                enableCard
                    .tonicMineralRipple(trigger: receiptMotionTrigger, reduceMotion: reduceMotion)
                    .tonicOrbitalParticles(trigger: completionMotionTrigger, reduceMotion: reduceMotion)
                    .tonicAppear(appeared, index: 1, reduceMotion: reduceMotion)

                if store.settings.isEnabled {
                    if manager.canControlItems {
                        AccessibilityGateBanner()
                            .tonicAppear(appeared, index: 2, reduceMotion: reduceMotion)
                    }

                    MenuBarStripView(onMove: performMove, onActivate: performActivate)
                        .tonicAppear(appeared, index: 3, reduceMotion: reduceMotion)

                    if workspace.isDirty || lastLayoutReceipt != nil {
                        layoutFooter
                            .tonicAppear(appeared, index: 4, reduceMotion: reduceMotion)
                    }

                    layoutPalette
                        .tonicAppear(appeared, index: 5, reduceMotion: reduceMotion)

                    quickActionsRow
                        .tonicAppear(appeared, index: 6, reduceMotion: reduceMotion)

                    TonicBentoGrid(minTileWidth: 340) {
                        MenuBarPresetsCard(onApply: performApplyPreset)
                        MenuBarTriggersCard { context in
                            editingTrigger = TriggerEditorContext(trigger: context, seedItemKey: nil)
                        }
                        MenuBarBehaviorCard()
                        MenuBarAppearanceCard()
                        MenuBarHotkeysCard()
                        MenuBarProfilesCard()
                        MenuBarProvidersCard()
                    }
                    .tonicAppear(appeared, index: 7, reduceMotion: reduceMotion)

                    MenuBarItemListView(
                        onMove: performMove,
                        onActivate: performActivate,
                        onCreateTrigger: { item in
                            editingTrigger = TriggerEditorContext(trigger: nil, seedItemKey: item.stableKey)
                        }
                    )
                    .tonicAppear(appeared, index: 8, reduceMotion: reduceMotion)

                    guidanceCard
                    .tonicAppear(appeared, index: 9, reduceMotion: reduceMotion)
                }
            }
            .frame(maxWidth: TonicDS.Layout.maxContentWidth)
            .frame(maxWidth: .infinity, alignment: .center)
            .tonicScreenHPadding()
            .padding(.vertical, TonicDS.Space.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .tonicCanvas()
        .tonicToast($toast)
        .sheet(item: $editingTrigger) { context in
            TriggerEditorSheet(editing: context.trigger, seedItemKey: context.seedItemKey)
        }
        .sheet(isPresented: $showsSetup) {
            MenuBarSetupView(items: manager.items, canMoveForeignItems: MenuBarCapabilities.current.canMoveForeignItems) {
                mode, recommendations in
                store.settings.isEnabled = true
                workspace.layoutMode = mode
                for recommendation in recommendations where recommendation.isPreselected {
                    if let item = manager.items.first(where: { $0.stableKey == recommendation.stableKey }) {
                        workspace.stage(item, in: recommendation.target)
                    }
                }
                showsSetup = false
                applyDraft()
            } onDefer: {
                showsSetup = false
            }
        }
        .sheet(item: $customItemEditor) { context in
            CustomItemBuilderSheet(existing: context.item) { workspace.saveCustomItem($0) }
        }
        .sheet(item: $groupEditor) { context in
            MenuBarGroupBuilderSheet(existing: context.group, items: manager.items) { workspace.saveGroup($0) }
        }
        .onChange(of: manager.lastActionError) { _, error in
            if let error { toast = ToastData(message: error) }
        }
        .onAppear {
            manager.setInspectorVisible(isActive)
            workspace.synchronize(with: manager.items)
            showsSetup = !workspace.hasCompletedSetup
            appeared = true
        }
        .onDisappear {
            manager.setInspectorVisible(false)
        }
        .onChange(of: isActive) { _, active in
            manager.setInspectorVisible(active)
        }
        .onChange(of: manager.items) { _, items in
            workspace.synchronize(with: items)
        }
    }

    // MARK: - Enable card

    private var enableCard: some View {
        SettingsPanel(title: "MANAGEMENT") {
            TonicToggleRow(
                title: "Manage menu bar items",
                description: managementDescription,
                showsDivider: store.settings.isEnabled,
                isOn: $store.settings.isEnabled
            )
            if store.settings.isEnabled {
                TonicPreferenceRow(
                    title: statusTitle,
                    description: statusLine,
                    showsDivider: false
                ) {
                    TextAction(manager.isExpanded ? "Collapse" : "Reveal",
                               systemImage: manager.isExpanded ? "chevron.right" : "chevron.left",
                               color: TonicDS.Colors.linkBlue) {
                        manager.toggle()
                    }
                }
            }
        }
    }

    private var managementDescription: String {
        if manager.canControlItems {
            return "Adds a ┃ separator and ‹ toggle to the menu bar. Drag items across it here, or ⌘-drag them in the menu bar."
        }
        return "Discovers and organizes menu bar items. One-click moving requires the direct download of Tonic."
    }

    private var statusTitle: String {
        manager.isExpanded ? "Hidden items revealed" : "Hidden items collapsed"
    }

    private var statusLine: String {
        let hidden = manager.items.filter { $0.section == .hidden }.count
        let always = manager.items.filter { $0.section == .alwaysHidden }.count
        let visible = manager.items.filter { $0.section == .visible }.count
        var parts = ["\(visible) visible", "\(hidden) hidden"]
        if store.settings.alwaysHiddenSectionEnabled { parts.append("\(always) quiet") }
        return parts.joined(separator: " · ")
    }

    // MARK: - Quick actions

    private var quickActionsRow: some View {
        HStack(spacing: TonicDS.Space.lg) {
            TextAction("Quick Search", systemImage: "magnifyingglass", color: TonicDS.Colors.linkBlue) {
                QuickSearchPanelController.shared.show()
            }
            if manager.canControlItems, store.settings.alwaysHiddenSectionEnabled {
                TextAction("Peek Quiet", systemImage: "eye", color: TonicDS.Colors.linkBlue) {
                    manager.expand(showAlwaysHidden: true)
                }
            }
            Spacer()
        }
    }

    private var layoutPalette: some View {
        SettingsPanel(title: "LAYOUT PALETTE") {
            TonicPreferenceRow(
                title: "Tonic-owned items",
                description: "Add safe layout elements without modifying another app."
            ) {
                HStack(spacing: 8) {
                    Button("Spacer", systemImage: "space") { workspace.addSpacer() }
                    Button("Group", systemImage: "square.grid.2x2") { groupEditor = GroupEditorContext(group: nil) }
                    Button("Custom Item", systemImage: "plus.square.dashed") {
                        customItemEditor = CustomItemEditorContext(item: nil)
                    }
                }
                .buttonStyle(.bordered)
            }
            if !workspace.spacers.isEmpty || !workspace.groups.isEmpty || !workspace.customItems.isEmpty {
                TonicPreferenceRow(
                    title: "Workspace contents",
                    description: "\(workspace.spacers.count) spacers · \(workspace.groups.count) groups · \(workspace.customItems.count) custom items",
                    showsDivider: false
                ) { EmptyView() }
                ownedItemEditors
            }
        }
    }

    private var layoutFooter: some View {
        SettingsPanel(title: workspace.isDirty ? "UNAPPLIED CHANGES" : "LAYOUT RECEIPT") {
            if workspace.isDirty {
                TonicPreferenceRow(
                    title: "\(workspace.stagedChangeCount) staged change\(workspace.stagedChangeCount == 1 ? "" : "s")",
                    description: "\(workspace.changeSummary). The real menu bar changes only after Apply Layout.",
                    showsDivider: false
                ) {
                    HStack(spacing: 8) {
                        Button("Discard") { workspace.discard() }
                            .buttonStyle(.bordered)
                        PrimaryPill("Apply Layout", isDisabled: manager.isPerformingMove) {
                            applyDraft()
                        }
                        .help(manager.canControlItems ? "Apply staged layout" : "Applies Tonic-owned items; foreign placement remains staged")
                    }
                }
            } else if let lastLayoutReceipt {
                TonicPreferenceRow(title: "Layout applied", description: lastLayoutReceipt, showsDivider: false) {
                    if lastUndoToken != nil {
                        Button("Undo") { undoLastApply() }
                            .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var ownedItemEditors: some View {
        ForEach(workspace.spacers) { spacer in
            TonicPreferenceRow(title: spacer.label, description: "Spacer · \(Int(spacer.width)) pt") {
                HStack {
                    TextField("Label", text: spacerLabel(spacer.id)).textFieldStyle(.roundedBorder).frame(width: 90)
                    Picker("Section", selection: spacerSection(spacer.id)) {
                        ForEach(MenuBarSection.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }.labelsHidden().frame(width: 105)
                    Toggle("Hidden", isOn: spacerHidden(spacer.id)).labelsHidden().help("Hide this spacer")
                    Stepper("Width", value: spacerWidth(spacer.id), in: 4...96, step: 4).labelsHidden()
                    orderButtons(.spacer(spacer.id))
                    Button(role: .destructive) { workspace.spacers.removeAll { $0.id == spacer.id } } label: {
                        Image(systemName: "trash")
                    }.buttonStyle(.borderless)
                }
            }
        }
        ForEach(workspace.groups) { group in
            TonicPreferenceRow(title: group.name,
                               description: "Group · \(group.itemKeys.count) members · \(group.presentationOverride?.title ?? "Global shelf")") {
                HStack {
                    Toggle("Pinned", isOn: groupPinned(group.id)).labelsHidden()
                    orderButtons(.group(group.id))
                    Button("Edit") { groupEditor = GroupEditorContext(group: group) }.buttonStyle(.bordered)
                    Button(role: .destructive) { workspace.groups.removeAll { $0.id == group.id } } label: {
                        Image(systemName: "trash")
                    }.buttonStyle(.borderless)
                }
            }
        }
        ForEach(workspace.customItems) { custom in
            TonicPreferenceRow(title: custom.name, description: "Custom item · \(custom.actions.count) action(s)") {
                HStack {
                    Picker("Section", selection: customItemSection(custom.id)) {
                        ForEach(MenuBarSection.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }.labelsHidden().frame(width: 105)
                    orderButtons(.customItem(custom.id))
                    Button("Edit") { customItemEditor = CustomItemEditorContext(item: custom) }.buttonStyle(.bordered)
                    Button(role: .destructive) { workspace.customItems.removeAll { $0.id == custom.id } } label: {
                        Image(systemName: "trash")
                    }.buttonStyle(.borderless)
                }
            }
        }
    }

    private func orderButtons(_ node: MenuBarLayoutNode) -> some View {
        HStack(spacing: 2) {
            Button("Move Earlier", systemImage: "chevron.left") { workspace.move(node, by: -1) }.labelStyle(.iconOnly)
            Button("Move Later", systemImage: "chevron.right") { workspace.move(node, by: 1) }.labelStyle(.iconOnly)
        }
        .buttonStyle(.borderless)
    }

    private func spacerWidth(_ id: UUID) -> Binding<Double> {
        Binding { workspace.spacers.first(where: { $0.id == id })?.width ?? 12 } set: { width in
            guard let index = workspace.spacers.firstIndex(where: { $0.id == id }) else { return }
            workspace.spacers[index].width = min(max(width, 4), 96)
        }
    }

    private func spacerLabel(_ id: UUID) -> Binding<String> {
        Binding { workspace.spacers.first(where: { $0.id == id })?.label ?? "Spacer" } set: { label in
            guard let index = workspace.spacers.firstIndex(where: { $0.id == id }) else { return }
            workspace.spacers[index].label = String(label.prefix(40))
        }
    }

    private func spacerSection(_ id: UUID) -> Binding<MenuBarSection> {
        Binding { workspace.spacers.first(where: { $0.id == id })?.section ?? .visible } set: { section in
            _ = workspace.stageOwned(.spacer(id), in: section)
        }
    }

    private func spacerHidden(_ id: UUID) -> Binding<Bool> {
        Binding { workspace.spacers.first(where: { $0.id == id })?.isHidden ?? false } set: { hidden in
            guard let index = workspace.spacers.firstIndex(where: { $0.id == id }) else { return }
            workspace.spacers[index].isHidden = hidden
        }
    }

    private func customItemSection(_ id: UUID) -> Binding<MenuBarSection> {
        Binding { workspace.customItems.first(where: { $0.id == id })?.section ?? .visible } set: { section in
            _ = workspace.stageOwned(.customItem(id), in: section)
        }
    }

    private func groupPinned(_ id: UUID) -> Binding<Bool> {
        Binding { workspace.groups.first(where: { $0.id == id })?.isPinned ?? false } set: { pinned in
            guard let index = workspace.groups.firstIndex(where: { $0.id == id }) else { return }
            workspace.groups[index].isPinned = pinned
        }
    }

    // MARK: - Guidance

    private var guidanceCard: some View {
        SettingsPanel(title: "HOW IT WORKS") {
            guidanceRow(icon: "hand.draw",
                        text: "Drag an item between sections above to move it — Tonic performs the ⌘-drag for you. You can still ⌘-drag icons directly in the menu bar.")
            guidanceRow(icon: "rectangle.stack",
                        text: "Save presets for different contexts (work, home, recording) and switch instantly, or let Triggers apply them automatically.")
            guidanceRow(icon: "lock.shield",
                        text: "System items — Control Center, Wi-Fi, Clock — are laid out by macOS and can't be hidden.")
            guidanceRow(icon: "laptopcomputer",
                        text: "On notched MacBooks, macOS silently drops items that don't fit. Hide enough to keep the visible set clear of the notch.",
                        showsDivider: false)
        }
    }

    private func guidanceRow(icon: String, text: String, showsDivider: Bool = true) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: TonicDS.Space.sm) {
                Image(systemName: icon).font(.system(size: 12, weight: .medium))
                    .foregroundStyle(TonicDS.Colors.textMuted).frame(width: 18)
                Text(text).tonicType(.caption).foregroundStyle(TonicDS.Colors.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, TonicDS.Space.md)
            .padding(.vertical, TonicDS.Space.sm)
            if showsDivider { TonicHairline().padding(.leading, TonicDS.Space.md) }
        }
    }

    // MARK: - Actions

    private func performMove(_ item: MenuBarItemInfo, _ section: MenuBarSection) {
        workspace.stage(item, in: section)
    }

    private func performActivate(_ item: MenuBarItemInfo) {
        guard manager.canControlItems else { return }
        Task { await manager.activate(item) }
    }

    private func performApplyPreset(_ preset: MenuBarPreset) {
        Task {
            let ok = await MenuBarPresetApplicator.apply(preset, manager: manager)
            if ok { toast = ToastData(message: "Applied “\(preset.name)”") }
        }
    }

    private func applyDraft() {
        let transaction = workspace.makeTransaction()
        let target = Dictionary(uniqueKeysWithValues: workspace.changes.map { ($0.stableKey, $0.to) })
        let undo = Dictionary(uniqueKeysWithValues: workspace.changes.map { ($0.stableKey, $0.from) })
        let undoToken = MenuBarLayoutUndoToken(foreignSections: transaction.baseline.foreignAssignments,
                                               ownedSnapshot: transaction.baseline)
        let ownedChangedNodeIDs = ownedChanges(from: transaction.baseline, to: transaction.proposed)
        Task {
            let ownedFailures = MenuBarOwnedItemCoordinator.shared.apply(transaction.proposed)
            let foreignResults: [String: Bool]
            if target.isEmpty {
                foreignResults = [:]
            } else if manager.canControlItems {
                foreignResults = await manager.applyLayoutDetailed(target)
            } else {
                foreignResults = Dictionary(uniqueKeysWithValues: target.keys.map { ($0, false) })
            }
            let successfulForeignKeys = Set(foreignResults.compactMap { $0.value ? $0.key : nil })
            let failedOwnedIDs = Set(ownedFailures.map(\.nodeID))
            workspace.commit(successfulForeignKeys: successfulForeignKeys,
                             commitOwnedItems: ownedFailures.isEmpty,
                             failedOwnedNodeIDs: failedOwnedIDs)
            if !ownedFailures.isEmpty { _ = MenuBarOwnedItemCoordinator.shared.apply(workspace.envelope.committed) }
            let foreignFailures = foreignResults.values.filter { !$0 }.count
            let failureCount = ownedFailures.count + foreignFailures
            let successCount = ownedChangedNodeIDs.subtracting(failedOwnedIDs).count + successfulForeignKeys.count
            if failureCount == 0 {
                let completesFirstSetup = !workspace.hasCompletedSetup
                lastAppliedLayout = undo
                lastUndoToken = undoToken
                lastLayoutReceipt = successCount == 0 && !workspace.hasCompletedSetup
                    ? "Menu Bar setup completed. No foreign items were moved."
                    : "Applied \(successCount) change\(successCount == 1 ? "" : "s") with no failures."
                workspace.completeSetup()
                receiptMotionTrigger += 1
                if completesFirstSetup { completionMotionTrigger += 1 }
                toast = ToastData(message: successCount == 0 ? "Menu Bar ready" : "Layout applied")
            } else {
                lastUndoToken = successCount > 0 ? undoToken : nil
                lastLayoutReceipt = "Applied \(successCount); \(failureCount) failed. Failed changes remain staged for retry."
                receiptMotionTrigger += 1
            }
            ActionReceiptStore.shared.record(ActionReceipt(
                tool: .menuBar, title: failureCount == 0 ? "Menu bar layout applied" : "Menu bar layout partially applied",
                detail: lastLayoutReceipt ?? "Layout reviewed.",
                status: failureCount == 0 ? .success : (successCount > 0 ? .partial : .failed),
                affectedItems: successCount,
                undo: successCount > 0 ? .available(token: undoToken.ownedSnapshot.baselineRevision.uuidString,
                                                     expiresAt: nil) : .unavailable,
                metadata: ["failures": String(failureCount)]
            ))
            TonicFeedback.alignment()
        }
    }

    private func ownedChanges(from baseline: MenuBarLayoutDraft, to proposed: MenuBarLayoutDraft) -> Set<String> {
        var changed = Set<String>()
        let spacerIDs = Set(baseline.spacers.map(\.id)).union(proposed.spacers.map(\.id))
        for id in spacerIDs where baseline.spacers.first(where: { $0.id == id }) != proposed.spacers.first(where: { $0.id == id }) {
            changed.insert(MenuBarLayoutNode.spacer(id).stableID)
        }
        let groupIDs = Set(baseline.groups.map(\.id)).union(proposed.groups.map(\.id))
        for id in groupIDs where baseline.groups.first(where: { $0.id == id }) != proposed.groups.first(where: { $0.id == id }) {
            changed.insert(MenuBarLayoutNode.group(id).stableID)
        }
        let customIDs = Set(baseline.customItems.map(\.id)).union(proposed.customItems.map(\.id))
        for id in customIDs where baseline.customItems.first(where: { $0.id == id }) != proposed.customItems.first(where: { $0.id == id }) {
            changed.insert(MenuBarLayoutNode.customItem(id).stableID)
        }
        if baseline.orderedNodes != proposed.orderedNodes { changed.insert("owned:order") }
        return changed
    }

    private func undoLastApply() {
        guard let token = lastUndoToken else { return }
        Task {
            let layout = token.foreignSections
            let ok = await manager.applyLayout(layout)
            if ok {
                workspace.restore(token)
                _ = MenuBarOwnedItemCoordinator.shared.apply(token.ownedSnapshot)
                lastAppliedLayout = nil
                lastUndoToken = nil
                lastLayoutReceipt = "Previous layout restored."
                receiptMotionTrigger += 1
                toast = ToastData(message: "Layout restored")
                TonicFeedback.alignment()
                ActionReceiptStore.shared.record(ActionReceipt(
                    tool: .menuBar, title: "Menu bar layout restored",
                    detail: "Restored the layout and Tonic-owned items from the previous Apply.",
                    status: .success, affectedItems: layout.count, undo: .unavailable
                ))
            }
        }
    }
}
