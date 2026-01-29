//
//  SidebarView.swift
//  Tonic
//
//  Sidebar navigation component with grouped sections
//

import SwiftUI

// MARK: - Sidebar Section Model

/// Defines a section group in the sidebar navigation
struct SidebarSection: Identifiable {
    let id: String
    let title: String?
    let items: [NavigationDestination]

    init(_ title: String?, items: [NavigationDestination]) {
        self.id = title ?? UUID().uuidString
        self.title = title
        self.items = items
    }
}

// MARK: - Sidebar View

struct SidebarView: View {
    @Binding var selectedDestination: NavigationDestination

    /// Grouped navigation sections following the new IA
    private let sections: [SidebarSection] = [
        SidebarSection(nil, items: [.dashboard]),
        SidebarSection("Maintenance", items: [.systemCleanup]),
        SidebarSection("Explore", items: [.diskAnalysis, .appManager, .liveMonitoring]),
        SidebarSection("Menu Bar", items: [.menuBarWidgets]),
        SidebarSection("Advanced", items: [.developerTools]),
        SidebarSection(nil, items: [.settings])
    ]

    var body: some View {
        VStack(spacing: 0) {
            // App header
            appHeader

            Divider()

            // Navigation list with grouped sections
            List(selection: $selectedDestination) {
                ForEach(sections) { section in
                    sectionContent(section)
                }
            }
            .listStyle(.sidebar)
        }
        .frame(minWidth: DesignTokens.Layout.sidebarWidth)
    }

    // MARK: - App Header

    private var appHeader: some View {
        HStack(spacing: DesignTokens.Spacing.xxs) {
            Image(systemName: "drop.circle.fill")
                .font(.title2)
                .foregroundStyle(.linearGradient(
                    colors: [DesignTokens.Colors.accent, DesignTokens.Colors.accent.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))

            Text("Tonic")
                .font(DesignTokens.Typography.bodyEmphasized)

            Spacer()
        }
        .padding(DesignTokens.Spacing.sm)
    }

    // MARK: - Section Content

    @ViewBuilder
    private func sectionContent(_ section: SidebarSection) -> some View {
        if let title = section.title {
            // Section with header
            Section {
                ForEach(section.items, id: \.self) { destination in
                    navigationRow(destination)
                }
            } header: {
                Text(title)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .textCase(.uppercase)
                    .padding(.top, section.id == sections.first?.id ? 0 : DesignTokens.Spacing.xxs)
            }
        } else {
            // Items without section header
            ForEach(section.items, id: \.self) { destination in
                navigationRow(destination)
            }
        }
    }

    // MARK: - Navigation Row

    private func navigationRow(_ destination: NavigationDestination) -> some View {
        Label(destination.displayName, systemImage: destination.systemImage)
            .tag(destination)
    }
}

// MARK: - NavigationDestination Extension

extension NavigationDestination {
    /// Display name for sidebar (may differ from rawValue for brevity)
    var displayName: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .systemCleanup: return "Smart Scan"
        case .appManager: return "Apps"
        case .diskAnalysis: return "Disk"
        case .liveMonitoring: return "Activity"
        case .menuBarWidgets: return "Widgets"
        case .developerTools: return "Developer Tools"
        case .settings: return "Settings"
        }
    }
}

// MARK: - Preview

#Preview {
    SidebarView(selectedDestination: .constant(.dashboard))
        .frame(width: 220, height: 500)
}
