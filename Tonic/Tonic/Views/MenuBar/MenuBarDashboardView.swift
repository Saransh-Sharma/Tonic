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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var toast: ToastData?
    @State private var editingTrigger: TriggerEditorContext?

    /// Wraps an optional trigger so the sheet can distinguish "new" (nil) from
    /// "edit" while still being Identifiable.
    private struct TriggerEditorContext: Identifiable {
        let id = UUID()
        let trigger: MenuBarTrigger?
        let seedItemKey: String?
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: TonicDS.Space.lg) {
                TonicPageHeader("Menu Bar", subtitle: "Hide, organize, and automate your menu bar")
                    .tonicAppear(appeared, index: 0, reduceMotion: reduceMotion)

                enableCard
                    .tonicAppear(appeared, index: 1, reduceMotion: reduceMotion)

                if store.settings.isEnabled {
                    if manager.canControlItems {
                        AccessibilityGateBanner()
                            .tonicAppear(appeared, index: 2, reduceMotion: reduceMotion)
                    }

                    MenuBarStripView(onMove: performMove, onActivate: performActivate)
                        .tonicAppear(appeared, index: 3, reduceMotion: reduceMotion)

                    quickActionsRow
                        .tonicAppear(appeared, index: 4, reduceMotion: reduceMotion)

                    TonicBentoGrid(minTileWidth: 340) {
                        MenuBarPresetsCard(onApply: performApplyPreset)
                        MenuBarTriggersCard { context in
                            editingTrigger = TriggerEditorContext(trigger: context, seedItemKey: nil)
                        }
                        MenuBarBehaviorCard()
                        MenuBarAppearanceCard()
                        MenuBarHotkeysCard()
                    }
                    .tonicAppear(appeared, index: 5, reduceMotion: reduceMotion)

                    MenuBarItemListView(
                        onMove: performMove,
                        onActivate: performActivate,
                        onCreateTrigger: { item in
                            editingTrigger = TriggerEditorContext(trigger: nil, seedItemKey: item.stableKey)
                        }
                    )
                    .tonicAppear(appeared, index: 6, reduceMotion: reduceMotion)

                    guidanceCard
                        .tonicAppear(appeared, index: 7, reduceMotion: reduceMotion)
                }
            }
            .frame(maxWidth: TonicDS.Layout.maxContentWidth)
            .frame(maxWidth: .infinity, alignment: .center)
            .tonicScreenHPadding()
            .padding(.vertical, TonicDS.Space.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TonicDS.Colors.canvas)
        .tonicToast($toast)
        .sheet(item: $editingTrigger) { context in
            TriggerEditorSheet(editing: context.trigger, seedItemKey: context.seedItemKey)
        }
        .onChange(of: manager.lastActionError) { _, error in
            if let error { toast = ToastData(message: error) }
        }
        .onAppear {
            manager.setInspectorVisible(isActive)
            appeared = true
        }
        .onDisappear {
            manager.setInspectorVisible(false)
        }
        .onChange(of: isActive) { _, active in
            manager.setInspectorVisible(active)
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
        if store.settings.alwaysHiddenSectionEnabled { parts.append("\(always) always-hidden") }
        return parts.joined(separator: " · ")
    }

    // MARK: - Quick actions

    private var quickActionsRow: some View {
        HStack(spacing: TonicDS.Space.lg) {
            TextAction("Quick Search", systemImage: "magnifyingglass", color: TonicDS.Colors.linkBlue) {
                QuickSearchPanelController.shared.show()
            }
            if manager.canControlItems, store.settings.alwaysHiddenSectionEnabled {
                TextAction("Peek Always-Hidden", systemImage: "eye", color: TonicDS.Colors.linkBlue) {
                    manager.expand(showAlwaysHidden: true)
                }
            }
            Spacer()
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
        Task { await manager.move(item, to: section) }
    }

    private func performActivate(_ item: MenuBarItemInfo) {
        guard manager.canControlItems else { return }
        Task { await manager.activate(item) }
    }

    private func performApplyPreset(_ preset: MenuBarPreset) {
        Task {
            let ok = await manager.applyLayout(preset.layout)
            if ok { toast = ToastData(message: "Applied “\(preset.name)”") }
        }
    }
}
