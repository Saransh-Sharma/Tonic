//
//  MenuBarItemListView.swift
//  Tonic
//
//  Grouped detail list of every discovered menu bar item with per-item
//  Show / Hide / Always-hide / Open actions.
//

import AppKit
import SwiftUI

struct MenuBarItemListView: View {
    @State private var manager = MenuBarManager.shared
    @State private var store = MenuBarManagerSettingsStore.shared
    @State private var updateStore = MenuBarUpdateWatchStore.shared
    @State private var workspace = MenuBarWorkspaceStore.shared

    let onMove: (MenuBarItemInfo, MenuBarSection) -> Void
    let onActivate: (MenuBarItemInfo) -> Void
    let onCreateTrigger: (MenuBarItemInfo) -> Void

    private var groups: [(section: MenuBarSection, items: [MenuBarItemInfo])] {
        let order: [MenuBarSection] = [.visible, .hidden, .alwaysHidden]
        return order.compactMap { section in
            let matches = manager.items.filter { workspace.section(for: $0) == section }
            return matches.isEmpty ? nil : (section, matches)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.sm) {
            HStack {
                MonoLabel("ALL ITEMS")
                Spacer()
                if let scanned = manager.lastScanDate {
                    Text(scanned, style: .relative).tonicType(.caption).foregroundStyle(TonicDS.Colors.textMuted)
                    Text("ago").tonicType(.caption).foregroundStyle(TonicDS.Colors.textMuted)
                }
                TextAction("Refresh", systemImage: "arrow.clockwise", color: TonicDS.Colors.linkBlue) {
                    manager.refreshScan()
                }
            }

            if manager.items.isEmpty {
                TonicEmptyState(
                    systemImage: "menubar.rectangle",
                    title: "No items discovered yet",
                    message: "Scanning the menu bar… If this persists, other apps may not have status items running."
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(groups, id: \.section) { group in
                        sectionHeader(group.section)
                        ForEach(group.items) { item in
                            row(item)
                            TonicHairline().padding(.leading, TonicDS.Space.md)
                        }
                    }
                }
                .background(TonicDS.Colors.surface,
                            in: RoundedRectangle(cornerRadius: TonicDS.Radius.lg, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: TonicDS.Radius.lg, style: .continuous)
                        .strokeBorder(TonicDS.Colors.hairline, lineWidth: 1)
                )
            }
        }
    }

    private func sectionHeader(_ section: MenuBarSection) -> some View {
        HStack(spacing: TonicDS.Space.xs) {
            Image(systemName: icon(section)).font(.system(size: 10, weight: .medium))
                .foregroundStyle(TonicDS.Colors.textMuted)
            MonoLabel(section.displayName.uppercased())
            Spacer()
        }
        .padding(.horizontal, TonicDS.Space.md)
        .frame(height: 30, alignment: .bottomLeading)
        .padding(.top, TonicDS.Space.xs)
    }

    private func icon(_ section: MenuBarSection) -> String {
        switch section {
        case .visible: return "eye"
        case .hidden: return "eye.slash"
        case .alwaysHidden: return "eye.slash.fill"
        }
    }

    private func row(_ item: MenuBarItemInfo) -> some View {
        SystemListRow {
            appIcon(item)
        } center: {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName).tonicType(.body).foregroundStyle(TonicDS.Colors.textPrimary).lineLimit(1)
                if let bundle = item.bundleIdentifier {
                    Text(bundle).tonicType(.caption).foregroundStyle(TonicDS.Colors.textMuted).lineLimit(1)
                }
            }
        } trailing: {
            trailing(item)
        }
    }

    @ViewBuilder
    private func trailing(_ item: MenuBarItemInfo) -> some View {
        if item.isSystemControlled {
            StatusChip("System", color: TonicDS.Colors.textMuted)
        } else {
            HStack(spacing: TonicDS.Space.xs) {
                Menu {
                    if manager.canControlItems {
                        Button("Open") { onActivate(item) }
                        Divider()
                        let draftSection = workspace.section(for: item)
                        if draftSection != .visible { Button("Move to Visible") { onMove(item, .visible) } }
                        if draftSection != .hidden { Button("Move to On Demand") { onMove(item, .hidden) } }
                        if store.settings.alwaysHiddenSectionEnabled, draftSection != .alwaysHidden {
                            Button("Move to Quiet") { onMove(item, .alwaysHidden) }
                        }
                        Divider()
                    }
                    Button("Create Trigger…") { onCreateTrigger(item) }
                    Button(updateStore.watchedKeys.contains(item.stableKey) ? "Stop Watching for Updates" : "Watch for Updates") {
                        let enables = !updateStore.watchedKeys.contains(item.stableKey)
                        if enables { _ = CGRequestScreenCaptureAccess() }
                        updateStore.setWatching(enables, key: item.stableKey)
                    }
                    Divider()
                    Button("Move Earlier") { workspace.move(.foreign(stableKey: item.stableKey), by: -1) }
                    Button("Move Later") { workspace.move(.foreign(stableKey: item.stableKey), by: 1) }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .tint(TonicDS.Colors.textMuted)
            }
        }
    }

    private func appIcon(_ item: MenuBarItemInfo) -> some View {
        Group {
            if let icon = item.nsImage {
                Image(nsImage: icon).resizable().aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "app.dashed").font(.system(size: 14)).foregroundStyle(TonicDS.Colors.textMuted)
            }
        }
        .frame(width: 22, height: 22)
    }
}
