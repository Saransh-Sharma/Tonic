//
//  MaintenanceView.swift
//  Tonic
//
//  Maintenance screen hosting Smart Care only
//

import SwiftUI

struct MaintenanceView: View {
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            SmartCareView()
        }
        .background(DesignTokens.Colors.background)
    }

    private var header: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Label("Maintenance", systemImage: "wrench.and.screwdriver")
                .font(DesignTokens.Typography.bodyEmphasized)

            Spacer()
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(DesignTokens.Colors.backgroundSecondary)
    }
}

#Preview("Maintenance View") {
    MaintenanceView()
        .frame(width: 800, height: 600)
}
