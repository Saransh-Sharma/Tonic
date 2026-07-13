//
//  TonicBarView.swift
//  Tonic
//
//  Contents of Quick Shelf. The implementation name remains migration-safe;
//  users can choose a compact strip, labeled grid, or searchable list.
//

import AppKit
import SwiftUI

struct TonicBarView: View {
    let items: [MenuBarItemInfo]
    let presentation: QuickShelfPresentation
    var canActivate: Bool = true
    let onActivate: (MenuBarItemInfo) -> Void
    @State private var query = ""
    @State private var updateStore = MenuBarUpdateWatchStore.shared

    private var filteredItems: [MenuBarItemInfo] {
        guard !query.isEmpty else { return items }
        return items.filter {
            $0.displayName.localizedCaseInsensitiveContains(query) ||
            $0.ownerName.localizedCaseInsensitiveContains(query) ||
            ($0.bundleIdentifier?.localizedCaseInsensitiveContains(query) ?? false) ||
            $0.stableKey.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        Group {
            if items.isEmpty {
                Text("No hidden items")
                    .tonicType(.caption)
                    .foregroundStyle(TonicDS.Colors.onDarkMuted)
                    .padding(.horizontal, TonicDS.Space.sm)
            } else {
                switch presentation {
                case .compactStrip:
                    HStack(spacing: 4) {
                        ForEach(items) { item in itemButton(item, labeled: false) }
                    }
                case .labeledGrid:
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 6)], spacing: 6) {
                        ForEach(items) { item in itemButton(item, labeled: true) }
                    }
                case .searchableList:
                    VStack(spacing: 6) {
                        TextField("Search menu bar items", text: $query)
                            .textFieldStyle(.roundedBorder)
                        ScrollView {
                            LazyVStack(spacing: 2) {
                                ForEach(filteredItems) { item in itemButton(item, labeled: true) }
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, TonicDS.Space.sm)
        .frame(maxHeight: .infinity)
        .tonicSurface(.chrome,
                      in: RoundedRectangle(cornerRadius: TonicDS.Radius.md, style: .continuous),
                      flatFill: TonicDS.Colors.console,
                      flatStroke: TonicDS.Colors.hairlineOnDark)
        .environment(\.colorScheme, .dark)
    }

    private func itemButton(_ item: MenuBarItemInfo, labeled: Bool) -> some View {
        Button {
            onActivate(item)
        } label: {
            HStack(spacing: 7) {
                iconView(item)
                    .overlay(alignment: .topTrailing) {
                        if updateStore.unseenKeys.contains(item.stableKey) {
                            Circle().fill(TonicDS.Colors.statusWarning).frame(width: 7, height: 7)
                                .accessibilityHidden(true)
                        }
                    }
                if labeled {
                    Text(item.displayName)
                        .lineLimit(1)
                        .tonicType(.caption)
                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, labeled ? 7 : 3)
            .padding(.vertical, labeled ? 5 : 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!canActivate)
        .help(item.displayName)
        .accessibilityLabel(updateStore.unseenKeys.contains(item.stableKey)
                            ? "\(item.displayName), updated" : item.displayName)
        .accessibilityHint(canActivate ? "Opens this menu bar item" : "Foreign-item activation requires the direct edition")
    }

    @ViewBuilder
    private func iconView(_ item: MenuBarItemInfo) -> some View {
        if let icon = item.nsImage {
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 22, height: 22)
        } else {
            Image(systemName: "app.dashed")
                .font(.system(size: 15))
                .foregroundStyle(TonicDS.Colors.onDarkMuted)
                .frame(width: 22, height: 22)
        }
    }
}
