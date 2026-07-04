//
//  SidebarView.swift
//  Tonic
//
//  Editorial sidebar — quiet, monochrome, custom selection (no OS accent highlight).
//

import SwiftUI

// MARK: - Sidebar Section Model

/// Defines a section group in the sidebar navigation
struct SidebarSection: Identifiable {
    let id: String
    let title: String?
    let items: [NavigationDestination]

    init(_ title: String?, items: [NavigationDestination]) {
        self.id = title ?? items.map(\.rawValue).joined(separator: ".")
        self.title = title
        self.items = items
    }
}

// MARK: - Sidebar View

struct SidebarView: View {
    @Binding var selectedDestination: NavigationDestination

    /// Grouped navigation sections following the new IA.
    private let baseSections: [SidebarSection] = [
        SidebarSection(nil, items: [.dashboard]),
        SidebarSection("Maintenance", items: [.systemCleanup, .appManager]),
        SidebarSection("Explore", items: [.liveMonitoring, .menuBarManager]),
        SidebarSection("Advanced", items: [.developerTools, .designSandbox]),
        SidebarSection(nil, items: [.settings])
    ]

    private var sections: [SidebarSection] {
        baseSections.compactMap { section in
            let enabledItems = section.items.filter(FeatureFlags.isEnabled)
            guard !enabledItems.isEmpty else { return nil }
            return SidebarSection(section.title, items: enabledItems)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            appHeader

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: TonicDS.Space.lg) {
                    ForEach(sections) { section in
                        sectionView(section)
                    }
                }
                .padding(.horizontal, TonicDS.Space.xs)
                .padding(.vertical, TonicDS.Space.md)
            }
        }
        .frame(minWidth: TonicDS.Layout.sidebarWidth, maxHeight: .infinity, alignment: .top)
        .background(TonicDS.Colors.canvasSoft)
    }

    // MARK: - App Header

    private var appHeader: some View {
        HStack(spacing: TonicDS.Space.xs) {
            TonicBrandAssets.appImage()
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)

            Text("TONIC")
                .tonicType(.monoLabel)
                .tracking(2)
                .foregroundStyle(TonicDS.Colors.textPrimary)

            Spacer()
        }
        .padding(.horizontal, TonicDS.Space.md)
        .padding(.vertical, TonicDS.Space.md)
    }

    // MARK: - Section

    @ViewBuilder
    private func sectionView(_ section: SidebarSection) -> some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.xxs) {
            if let title = section.title {
                MonoLabel(title)
                    .padding(.horizontal, TonicDS.Space.sm)
                    .padding(.bottom, 2)
            }
            ForEach(section.items, id: \.self) { destination in
                SidebarRow(
                    destination: destination,
                    isSelected: destination == selectedDestination,
                    action: { selectedDestination = destination }
                )
            }
        }
    }
}

// MARK: - Sidebar Row

private struct SidebarRow: View {
    let destination: NavigationDestination
    let isSelected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: TonicDS.Space.sm) {
                Image(systemName: destination.systemImage)
                    .font(.system(size: 13, weight: .regular))
                    .frame(width: 18)
                    .foregroundStyle(isSelected ? TonicDS.Colors.textPrimary : TonicDS.Colors.textMuted)

                Text(destination.sidebarDisplayName)
                    .tonicType(.body)
                    .foregroundStyle(isSelected ? TonicDS.Colors.textPrimary : TonicDS.Colors.textMuted)

                Spacer(minLength: 0)

                #if DEBUG
                if destination.wipFeature != nil {
                    Text("WIP")
                        .tonicType(.monoLabel)
                        .foregroundStyle(TonicDS.Colors.statusWarning)
                }
                #endif
            }
            .padding(.horizontal, TonicDS.Space.sm)
            .frame(height: TonicDS.Layout.minControlTarget)
            .background(rowBackground)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .tonicFocusableControl(radius: TonicDS.Radius.sm)
        .accessibilityLabel(destination.sidebarDisplayName)
        .accessibilityAddTraits(isSelected ? .isSelected : AccessibilityTraits())
        .onHover { hovering = $0 }
        .tonicPointerCursor()
    }

    @ViewBuilder
    private var rowBackground: some View {
        let shape = RoundedRectangle(cornerRadius: TonicDS.Radius.sm, style: .continuous)
        if isSelected {
            shape.fill(TonicDS.Colors.surface)
                .overlay(shape.strokeBorder(TonicDS.Colors.hairline, lineWidth: 1))
        } else if hovering {
            shape.fill(TonicDS.Colors.rowHover(0.05))
        } else {
            Color.clear
        }
    }
}

// MARK: - NavigationDestination Extension

extension NavigationDestination {
    /// Display name for sidebar (may differ from rawValue for brevity)
    var sidebarDisplayName: String {
        switch self {
        case .dashboard: return "Home"
        case .systemCleanup: return "Clean"
        case .appManager: return "Apps"
        case .diskAnalysis: return "Storage"
        case .recentlyCleaned: return "History"
        case .liveMonitoring: return "Monitor"
        case .menuBarManager: return "Menu Bar"
        case .menuBarWidgets: return "Widgets"
        case .developerTools: return "Developer Tools"
        case .designSandbox: return "Design Gallery"
        case .settings: return "Settings"
        }
    }
}

// MARK: - Preview

#Preview {
    SidebarView(selectedDestination: .constant(.dashboard))
        .frame(width: 220, height: 500)
}
