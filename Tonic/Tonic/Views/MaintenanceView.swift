//
//  MaintenanceView.swift
//  Tonic
//
//  Maintenance screen hosting Smart Care only
//

import SwiftUI

struct MaintenanceView: View {
    @ObservedObject var smartCareSession: SmartCareSessionStore

    var body: some View {
        SmartCareView(smartCareSession: smartCareSession)
    }
}

#Preview("Maintenance View") {
    MaintenanceView(smartCareSession: SmartCareSessionStore())
        .frame(width: 800, height: 600)
}
