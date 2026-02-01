//
//  OneViewContentView.swift
//  Tonic
//
//  SwiftUI view for OneView mode - provides the grid layout for unified menu bar display
//  Task ID: fn-6-i4g.11
//

import SwiftUI

// MARK: - One View Content View

/// Standalone SwiftUI view that can be used independently of NSStatusItem
/// Useful for previews and testing
struct OneViewContentView: View {
    @State private var dataManager = WidgetDataManager.shared
    @State private var preferences = WidgetPreferences.shared

    private var enabledWidgets: [WidgetConfiguration] {
        preferences.enabledWidgets.sorted { $0.position < $1.position }
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(enabledWidgets.enumerated()), id: \.element.id) { index, config in
                OneViewWidgetCell(config: config)
                    .frame(width: 32, height: 24)

                // Divider between widgets
                if index < enabledWidgets.count - 1 {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 1, height: 14)
                }
            }
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - One View Grid Layout

/// Grid layout alternative using LazyHGrid for more flexible widget arrangement
struct OneViewGridLayout: View {
    @State private var preferences = WidgetPreferences.shared
    @State private var dataManager = WidgetDataManager.shared

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    private var enabledWidgets: [WidgetConfiguration] {
        preferences.enabledWidgets.sorted { $0.position < $1.position }
    }

    var body: some View {
        LazyHGrid(rows: [GridItem(.flexible())], spacing: 2) {
            ForEach(enabledWidgets) { config in
                OneViewWidgetCell(config: config)
                    .frame(width: 32, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(DesignTokens.Colors.backgroundSecondary)
                    )
            }
        }
        .padding(4)
    }
}

// MARK: - One View Overflow Indicator

/// Visual indicator when more widgets exist than can be shown
struct OneViewOverflowIndicator: View {
    let additionalCount: Int

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 2) {
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 3, height: 3)

                Circle()
                    .fill(Color.secondary)
                    .frame(width: 3, height: 3)

                Circle()
                    .fill(Color.secondary)
                    .frame(width: 3, height: 3)
            }
            .padding(.top, 2)

            if additionalCount > 0 {
                Text("+\(additionalCount)")
                    .font(.system(size: 6, weight: .bold))
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 24, height: 22)
    }
}

// MARK: - One View Menu Bar Preview

/// Preview of how OneView appears in the menu bar
struct OneViewMenuBarPreview: View {
    @State private var dataManager = WidgetDataManager.shared
    @State private var preferences = WidgetPreferences.shared

    var body: some View {
        HStack(spacing: 0) {
            // Simulated menu bar appearance
            Image(systemName: "app.fill")
                .foregroundColor(.secondary)

            Divider()
                .frame(height: 16)

            OneViewContentView()

            Divider()
                .frame(height: 16)

            HStack(spacing: 4) {
                Image(systemName: "wifi")
                Image(systemName: "battery.100")
                Text("9:41")
                    .font(.system(size: 11))
            }
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(4)
    }
}

// MARK: - Preview

#Preview("OneView Compact") {
    OneViewContentView()
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
}

#Preview("OneView Grid Layout") {
    OneViewGridLayout()
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
}

#Preview("OneView Menu Bar Simulation") {
    OneViewMenuBarPreview()
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
}
