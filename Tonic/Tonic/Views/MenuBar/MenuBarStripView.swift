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

    /// Called with a stableKey → section request from a drop.
    let onMove: (MenuBarItemInfo, MenuBarSection) -> Void
    let onActivate: (MenuBarItemInfo) -> Void

    private func items(in section: MenuBarSection) -> [MenuBarItemInfo] {
        manager.items.filter { $0.section == section }
    }

    var body: some View {
        DataCard(lift: true) {
            VStack(alignment: .leading, spacing: TonicDS.Space.md) {
                DataCardHeader(label: "LIVE MENU BAR") {
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
        let sectionItems = items(in: section)
        return VStack(alignment: .leading, spacing: TonicDS.Space.xxs) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 9))
                MonoLabel(section.displayName.uppercased(), color: TonicDS.Colors.onDarkMuted)
            }
            HStack(spacing: 4) {
                if sectionItems.isEmpty {
                    Text("—")
                        .tonicType(.caption)
                        .foregroundStyle(TonicDS.Colors.onDarkMuted.opacity(0.5))
                        .frame(minWidth: 30, minHeight: 28)
                } else {
                    ForEach(sectionItems) { item in
                        stripIcon(item)
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
                handleDrop(keys: keys, to: section)
            }
        }
        .frame(maxWidth: fillRemaining ? .infinity : nil, alignment: .leading)
    }

    private func stripIcon(_ item: MenuBarItemInfo) -> some View {
        Group {
            if let icon = item.nsImage {
                Image(nsImage: icon).resizable().aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "app.dashed").foregroundStyle(TonicDS.Colors.onDarkMuted)
            }
        }
        .frame(width: 24, height: 24)
        .opacity(item.isSystemControlled ? 0.45 : 1)
        .draggable(item.stableKey) {
            // Drag preview.
            if let icon = item.nsImage {
                Image(nsImage: icon).resizable().frame(width: 24, height: 24)
            } else {
                Image(systemName: "app.dashed")
            }
        }
        .onTapGesture { onActivate(item) }
        .help(item.displayName)
        .contextMenu { itemContextMenu(item) }
    }

    @ViewBuilder
    private func itemContextMenu(_ item: MenuBarItemInfo) -> some View {
        if manager.canControlItems {
            Button("Open") { onActivate(item) }
            Divider()
            if item.section != .visible {
                Button("Show") { onMove(item, .visible) }
            }
            if item.section != .hidden {
                Button("Hide") { onMove(item, .hidden) }
            }
            if store.settings.alwaysHiddenSectionEnabled, item.section != .alwaysHidden {
                Button("Always Hide") { onMove(item, .alwaysHidden) }
            }
        } else {
            Text("Item control requires the direct download")
        }
    }

    private func handleDrop(keys: [String], to section: MenuBarSection) -> Bool {
        guard manager.canControlItems, let key = keys.first,
              let item = manager.items.first(where: { $0.stableKey == key }),
              !item.isSystemControlled, item.section != section else { return false }
        onMove(item, section)
        return true
    }
}
