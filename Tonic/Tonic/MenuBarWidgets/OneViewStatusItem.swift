//
//  OneViewStatusItem.swift
//  Tonic
//
//  Unified editorial menu-bar item.
//

import AppKit
import SwiftUI
import os

@MainActor
public final class OneViewStatusItem: WidgetStatusItem {
    private let logger = Logger(subsystem: "com.tonic.app", category: "OneViewStatusItem")
    private let maxVisibleWidgets = 6

    public init() {
        let oneViewConfig = WidgetConfiguration(
            type: .cpu,
            isEnabled: true,
            position: -1,
            displayMode: .compact,
            showLabel: false,
            valueFormat: .percentage
        )
        super.init(widgetType: .cpu, configuration: oneViewConfig)
        logger.info("Initializing unified menu-bar item")
    }

    public override func createCompactView() -> AnyView {
        AnyView(OneViewCompactView(maxVisibleWidgets: maxVisibleWidgets))
    }

    public override func createDetailView() -> AnyView {
        AnyView(OneViewDetailView())
    }

    public func refreshWidgetList() {
        objectWillChange.send()
        refresh()
        logger.debug("Unified item refreshed")
    }
}

private struct OneViewCompactView: View {
    let maxVisibleWidgets: Int

    private var visibleWidgets: [WidgetConfiguration] {
        Array(WidgetPreferences.shared.enabledWidgets.prefix(maxVisibleWidgets))
    }

    private var overflowCount: Int {
        max(0, WidgetPreferences.shared.enabledWidgets.count - maxVisibleWidgets)
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(visibleWidgets) { config in
                WidgetCompactView(widgetType: config.type, configuration: config)
                    .frame(height: TonicDS.Layout.MenuBar.compactHeight)
                if config.type != visibleWidgets.last?.type {
                    Rectangle()
                        .fill(TonicDS.Colors.hairline)
                        .frame(width: 1, height: 12)
                }
            }
            if overflowCount > 0 {
                Text("+\(overflowCount)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(TonicDS.Colors.textMuted)
            }
        }
        .padding(.horizontal, 4)
        .frame(height: TonicDS.Layout.MenuBar.compactHeight)
        .accessibilityLabel("Tonic menu-bar widgets")
    }
}

private struct OneViewDetailView: View {
    private var widgets: [WidgetConfiguration] {
        WidgetPreferences.shared.enabledWidgets
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                MonoLabel("TONIC", color: TonicDS.Colors.onDarkMuted)
                Spacer()
                Button {
                    SettingsDeepLinkNavigator.openModuleSettings(.cpu)
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(TonicDS.Colors.onDarkMuted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open widget settings")
                .tonicPointerCursor()
            }
            .padding(.horizontal, TonicDS.Space.md)
            .frame(height: 44)

            TonicHairline(color: TonicDS.Colors.hairlineOnDark)

            ScrollView {
                VStack(spacing: 0) {
                    if widgets.isEmpty {
                        HStack {
                            Text("No active widgets")
                                .tonicType(.caption)
                                .foregroundStyle(TonicDS.Colors.onDarkMuted)
                            Spacer()
                        }
                        .padding(TonicDS.Space.md)
                    } else {
                        ForEach(widgets) { config in
                            WidgetCompactView(widgetType: config.type, configuration: config)
                                .padding(.horizontal, TonicDS.Space.md)
                                .frame(height: TonicDS.Layout.MenuBar.rowHeight, alignment: .leading)
                            TonicHairline(color: TonicDS.Colors.hairlineOnDark)
                        }
                    }
                }
            }
        }
        .frame(width: TonicDS.Layout.MenuBar.width, height: TonicDS.Layout.MenuBar.maxHeight)
        .background(TonicDS.Colors.console)
        .environment(\.colorScheme, .dark)
    }
}
