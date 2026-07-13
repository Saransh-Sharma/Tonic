//
//  MenuBarStripView.swift
//  Tonic
//
//  The hero: a live representation of the menu bar split into
//  [always-hidden ┃ hidden ┃ visible], each a drop target. Drag an item
//  between sections to move it (Tonic performs the ⌘-drag); click to open it.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct MenuBarStripView: View {
    @State private var manager = MenuBarManager.shared
    @State private var store = MenuBarManagerSettingsStore.shared
    @State private var workspace = MenuBarWorkspaceStore.shared

    /// Called with a stableKey → section request from a drop.
    let onMove: (MenuBarItemInfo, MenuBarSection) -> Void
    let onActivate: (MenuBarItemInfo) -> Void

    var body: some View {
        DataCard(lift: true) {
            VStack(alignment: .leading, spacing: TonicDS.Space.md) {
                DataCardHeader(label: workspace.isDirty ? "LAYOUT DRAFT" : "MENU BAR PREVIEW") {
                    HStack(spacing: TonicDS.Space.sm) {
                        if manager.isPerformingMove {
                            ProgressView().controlSize(.small)
                        }
                        StatusChip(manager.isExpanded ? "Revealed" : "Collapsed",
                                   color: manager.isExpanded ? TonicDS.Colors.statusInfo : TonicDS.Colors.textMuted)
                        TextAction(manager.isExpanded ? "Collapse" : "Reveal",
                                   systemImage: manager.isExpanded ? "chevron.right" : "chevron.left",
                                   color: TonicDS.Colors.linkBlue) {
                            manager.toggle()
                        }
                    }
                }

                consoleStrip
            }
        }
        .accessibilityIdentifier("menu-bar-layout-editor")
    }

    private var consoleStrip: some View {
        MonitoringConsole {
            HStack(spacing: TonicDS.Space.sm) {
                if store.settings.alwaysHiddenSectionEnabled {
                    section(.alwaysHidden, icon: "eye.slash.fill")
                    separatorGlyph
                }
                section(.hidden, icon: "eye.slash")
                separatorGlyph
                section(.visible, icon: "eye", fillRemaining: true)
            }
            .frame(minHeight: 64)
        }
    }

    private var separatorGlyph: some View {
        Rectangle()
            .fill(TonicDS.Colors.onDarkMuted.opacity(0.6))
            .frame(width: 2, height: 40)
            .accessibilityLabel("Separator")
    }

    private func section(_ section: MenuBarSection, icon: String, fillRemaining: Bool = false) -> some View {
        return VStack(alignment: .leading, spacing: TonicDS.Space.xxs) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 9))
                MonoLabel(section.displayName.uppercased(), color: TonicDS.Colors.onDarkMuted)
            }
            HStack(spacing: 4) {
                if nodes(in: section).isEmpty {
                    Text("—")
                        .tonicType(.caption)
                        .foregroundStyle(TonicDS.Colors.onDarkMuted.opacity(0.5))
                        .frame(minWidth: 30, minHeight: 28)
                } else {
                    ForEach(nodes(in: section), id: \.stableID) { node in
                        nodeView(node)
                    }
                }
                if fillRemaining { Spacer(minLength: 0) }
            }
            .frame(maxWidth: fillRemaining ? .infinity : nil, minHeight: 32, alignment: .leading)
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: TonicDS.Radius.sm, style: .continuous)
                    .fill(TonicDS.Colors.onDark.opacity(0.04))
            )
            .dropDestination(for: String.self) { keys, _ in
                _ = handleDrop(keys: keys, to: section)
            }
        }
        .frame(maxWidth: fillRemaining ? .infinity : nil, alignment: .leading)
    }

    private func nodes(in section: MenuBarSection) -> [MenuBarLayoutNode] {
        workspace.envelope.draft.orderedNodes.filter { node in
            switch node {
            case .foreign(let key):
                guard let item = manager.items.first(where: { $0.stableKey == key }) else { return false }
                return workspace.section(for: item) == section
            case .spacer(let id):
                return workspace.spacers.first(where: { $0.id == id }).map { $0.section == section && !$0.isHidden } ?? false
            case .group(let id):
                return section == .visible && (workspace.groups.first(where: { $0.id == id })?.isPinned ?? false)
            case .customItem(let id):
                return workspace.customItems.first(where: { $0.id == id })?.section == section
            }
        }
    }

    @ViewBuilder
    private func nodeView(_ node: MenuBarLayoutNode) -> some View {
        switch node {
        case .foreign(let key):
            if let item = manager.items.first(where: { $0.stableKey == key }) { stripIcon(item, node: node) }
        case .spacer(let id):
            if let spacer = workspace.spacers.first(where: { $0.id == id }) {
                RoundedRectangle(cornerRadius: 2).fill(TonicDS.Colors.onDarkMuted.opacity(0.35))
                    .frame(width: CGFloat(min(max(spacer.width, 4), 40)), height: 20).help(spacer.label)
                    .accessibilityLabel("\(spacer.label), \(Int(spacer.width)) point spacer")
                    .accessibilityAction(named: "Move Earlier") { workspace.move(node, by: -1) }
                    .accessibilityAction(named: "Move Later") { workspace.move(node, by: 1) }
                    .draggable(node.stableID)
                    .contextMenu { orderMenu(node) }
            }
        case .group(let id):
            if let group = workspace.groups.first(where: { $0.id == id }) {
                Image(systemName: group.symbolName).frame(width: 24, height: 24).help(group.name)
                    .accessibilityLabel("Pinned group \(group.name)")
                    .accessibilityAction(named: "Move Earlier") { workspace.move(node, by: -1) }
                    .accessibilityAction(named: "Move Later") { workspace.move(node, by: 1) }
                    .draggable(node.stableID)
                    .contextMenu { orderMenu(node) }
            }
        case .customItem(let id):
            if let custom = workspace.customItems.first(where: { $0.id == id }) {
                HStack(spacing: 2) {
                    Image(systemName: custom.symbolName)
                    Text(CustomItemFormatter().format(custom.dataSource,
                                                      snapshot: WidgetCustomItemDataProvider.shared.snapshot()))
                }
                .font(.caption).lineLimit(1).help(custom.name)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(custom.name)
                .accessibilityAction(named: "Move Earlier") { workspace.move(node, by: -1) }
                .accessibilityAction(named: "Move Later") { workspace.move(node, by: 1) }
                .draggable(node.stableID)
                .contextMenu { orderMenu(node) }
            }
        }
    }

    private func stripIcon(_ item: MenuBarItemInfo, node: MenuBarLayoutNode) -> some View {
        Group {
            if let icon = item.nsImage {
                Image(nsImage: icon).resizable().aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "app.dashed").foregroundStyle(TonicDS.Colors.onDarkMuted)
            }
        }
        .frame(width: 24, height: 24)
        .opacity(item.isSystemControlled ? 0.45 : 1)
        .draggable(node.stableID) {
            // Drag preview.
            if let icon = item.nsImage {
                Image(nsImage: icon).resizable().frame(width: 24, height: 24)
            } else {
                Image(systemName: "app.dashed")
            }
        }
        .onTapGesture { onActivate(item) }
        .help(item.displayName)
        .accessibilityElement()
        .accessibilityLabel(item.displayName)
        .accessibilityHint(manager.canControlItems ? "Activates this menu bar item" : "Foreign-item activation requires the direct edition")
        .accessibilityAddTraits(manager.canControlItems ? .isButton : [])
        .accessibilityAction {
            if manager.canControlItems { onActivate(item) }
        }
        .accessibilityAction(named: "Move to Visible") { if manager.canControlItems { onMove(item, .visible) } }
        .accessibilityAction(named: "Move to On Demand") { if manager.canControlItems { onMove(item, .hidden) } }
        .accessibilityAction(named: "Move to Quiet") {
            if manager.canControlItems && store.settings.alwaysHiddenSectionEnabled { onMove(item, .alwaysHidden) }
        }
        .accessibilityAction(named: "Move Earlier") { workspace.move(node, by: -1) }
        .accessibilityAction(named: "Move Later") { workspace.move(node, by: 1) }
        .contextMenu {
            itemContextMenu(item)
            Divider()
            orderMenu(node)
        }
    }

    @ViewBuilder
    private func orderMenu(_ node: MenuBarLayoutNode) -> some View {
        Button("Move Earlier") { workspace.move(node, by: -1) }
        Button("Move Later") { workspace.move(node, by: 1) }
    }

    @ViewBuilder
    private func itemContextMenu(_ item: MenuBarItemInfo) -> some View {
        if manager.canControlItems {
            let draftSection = workspace.section(for: item)
            Button("Open") { onActivate(item) }
            Divider()
            if draftSection != .visible {
                Button("Move to Visible") { onMove(item, .visible) }
            }
            if draftSection != .hidden {
                Button("Move to On Demand") { onMove(item, .hidden) }
            }
            if store.settings.alwaysHiddenSectionEnabled, draftSection != .alwaysHidden {
                Button("Move to Quiet") { onMove(item, .alwaysHidden) }
            }
        } else {
            Text("Item control requires the direct download")
        }
    }

    private func handleDrop(keys: [String], to section: MenuBarSection) -> Bool {
        guard let payload = keys.first else { return false }
        if payload.hasPrefix("foreign:"),
           let item = manager.items.first(where: { payload == MenuBarLayoutNode.foreign(stableKey: $0.stableKey).stableID }),
           !item.isSystemControlled, workspace.section(for: item) != section {
            onMove(item, section)
            return true
        }
        for node in workspace.envelope.draft.orderedNodes where node.stableID == payload {
            return workspace.stageOwned(node, in: section)
        }
        return false
    }
}
