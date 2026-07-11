//
//  TonicBarView.swift
//  Tonic
//
//  Contents of the floating Tonic Bar: a horizontal row of hidden menu bar
//  item icons. Clicking one opens that item's menu.
//

import AppKit
import SwiftUI

struct TonicBarView: View {
    let items: [MenuBarItemInfo]
    let onActivate: (MenuBarItemInfo) -> Void

    var body: some View {
        HStack(spacing: 4) {
            if items.isEmpty {
                Text("No hidden items")
                    .tonicType(.caption)
                    .foregroundStyle(TonicDS.Colors.onDarkMuted)
                    .padding(.horizontal, TonicDS.Space.sm)
            } else {
                ForEach(items) { item in
                    Button {
                        onActivate(item)
                    } label: {
                        iconView(item)
                    }
                    .buttonStyle(.plain)
                    .help(item.displayName)
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
