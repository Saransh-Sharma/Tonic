//
//  QuickSearchView.swift
//  Tonic
//
//  Content of the Quick Search palette: a search field over the live list of
//  menu bar items with arrow-key navigation and Enter to open.
//

import AppKit
import SwiftUI

/// Pure ranking so it can be unit-tested without AppKit.
enum QuickSearchFilter {
    /// Case-insensitive match on display name or stable key. Prefix matches
    /// rank above substring matches; ties keep scan order.
    static func rank(names: [(index: Int, name: String, key: String)], query: String) -> [Int] {
        let trimmed = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty else { return names.map(\.index) }

        var prefix: [Int] = []
        var contains: [Int] = []
        for entry in names {
            let name = entry.name.lowercased()
            let key = entry.key.lowercased()
            if name.hasPrefix(trimmed) || key.hasPrefix(trimmed) {
                prefix.append(entry.index)
            } else if name.contains(trimmed) || key.contains(trimmed) {
                contains.append(entry.index)
            }
        }
        return prefix + contains
    }
}

struct QuickSearchView: View {
    let onActivate: (MenuBarItemInfo) -> Void
    let onClose: () -> Void

    @State private var manager = MenuBarManager.shared
    @State private var query = ""
    @State private var selection = 0
    @FocusState private var searchFocused: Bool

    private var results: [MenuBarItemInfo] {
        let items = manager.items.filter { !$0.isSystemControlled }
        let named = items.enumerated().map { (index: $0.offset, name: $0.element.displayName, key: $0.element.stableKey) }
        let order = QuickSearchFilter.rank(names: named, query: query)
        return order.compactMap { idx in items.indices.contains(idx) ? items[idx] : nil }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchField
            TonicHairline(color: TonicDS.Colors.hairlineOnDark)
            resultsList
        }
        .frame(width: 480, height: 420)
        .clipShape(RoundedRectangle(cornerRadius: TonicDS.Radius.lg, style: .continuous))
        .tonicSurface(.chrome,
                      in: RoundedRectangle(cornerRadius: TonicDS.Radius.lg, style: .continuous),
                      flatFill: TonicDS.Colors.console,
                      flatStroke: TonicDS.Colors.hairlineOnDark)
        .environment(\.colorScheme, .dark)
        .onAppear { searchFocused = true }
    }

    private var searchField: some View {
        HStack(spacing: TonicDS.Space.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(TonicDS.Colors.onDarkMuted)
            TextField("Search menu bar items…", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 17))
                .foregroundStyle(TonicDS.Colors.onDark)
                .focused($searchFocused)
                .onSubmit(activateSelection)
                .onChange(of: query) { _, _ in selection = 0 }
            if !manager.canControlItems {
                StatusChip("View only", color: TonicDS.Colors.onDarkMuted)
            }
        }
        .padding(TonicDS.Space.md)
        .onKeyPress(.downArrow) { moveSelection(1); return .handled }
        .onKeyPress(.upArrow) { moveSelection(-1); return .handled }
        .onKeyPress(.escape) { onClose(); return .handled }
    }

    private var resultsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    if results.isEmpty {
                        emptyRow
                    } else {
                        ForEach(Array(results.enumerated()), id: \.element.id) { index, item in
                            row(item, isSelected: index == selection)
                                .id(index)
                                .onTapGesture { onActivate(item) }
                        }
                    }
                }
            }
            .onChange(of: selection) { _, newValue in
                withAnimation(.easeOut(duration: 0.12)) { proxy.scrollTo(newValue, anchor: .center) }
            }
        }
    }

    private var emptyRow: some View {
        HStack {
            Text(query.isEmpty ? "No menu bar items found." : "No matches for “\(query)”.")
                .tonicType(.caption)
                .foregroundStyle(TonicDS.Colors.onDarkMuted)
            Spacer()
        }
        .padding(TonicDS.Space.md)
    }

    private func row(_ item: MenuBarItemInfo, isSelected: Bool) -> some View {
        HStack(spacing: TonicDS.Space.sm) {
            if let icon = item.nsImage {
                Image(nsImage: icon).resizable().aspectRatio(contentMode: .fit).frame(width: 20, height: 20)
            } else {
                Image(systemName: "app.dashed").foregroundStyle(TonicDS.Colors.onDarkMuted).frame(width: 20)
            }
            Text(item.displayName)
                .tonicType(.body)
                .foregroundStyle(TonicDS.Colors.onDark)
                .lineLimit(1)
            Spacer(minLength: TonicDS.Space.sm)
            if let section = item.section, section != .visible {
                StatusChip(section.displayName, color: TonicDS.Colors.onDarkMuted)
            }
        }
        .padding(.horizontal, TonicDS.Space.md)
        .frame(height: TonicDS.Layout.MenuBar.rowHeight + 8)
        .background(isSelected ? TonicDS.Colors.onDark.opacity(0.10) : Color.clear)
        .contentShape(Rectangle())
    }

    private func moveSelection(_ delta: Int) {
        let count = results.count
        guard count > 0 else { return }
        selection = max(0, min(count - 1, selection + delta))
    }

    private func activateSelection() {
        guard results.indices.contains(selection) else { return }
        onActivate(results[selection])
    }
}
