//
//  SpeedStatusItem.swift
//  Tonic
//
//  Status item for network speed visualization
//

import AppKit
import SwiftUI

/// Status item that displays network up/down speeds in the menu bar
@MainActor
public final class SpeedStatusItem: WidgetStatusItem {

    public override func createCompactView() -> AnyView {
        let dataManager = WidgetDataManager.shared
        let upload = dataManager.networkData.uploadBytesPerSecond
        let download = dataManager.networkData.downloadBytesPerSecond

        // TODO: Implement SpeedWidgetView
        return AnyView(
            Text("↑\(formatSpeed(upload)) ↓\(formatSpeed(download))")
                .font(.system(size: 10))
                .foregroundColor(configuration.accentColor.colorValue(for: widgetType))
        )
    }

    public override func createDetailView() -> AnyView {
        // Use SwiftUI NetworkPopoverView
        return AnyView(NetworkPopoverView())
    }

    private func formatSpeed(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond < 1024 {
            return "\(Int(bytesPerSecond)) B/s"
        } else if bytesPerSecond < 1024 * 1024 {
            return String(format: "%.1f KB/s", bytesPerSecond / 1024)
        } else {
            return String(format: "%.2f MB/s", bytesPerSecond / (1024 * 1024))
        }
    }
}
