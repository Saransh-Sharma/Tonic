import SwiftUI

public struct TabbedSettingsView: View {
    @State private var selection: Tab = .widgets
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum Tab: String, CaseIterable, Identifiable {
        case widgets = "Widgets"
        case modules = "Modules"
        case popovers = "Popovers"
        var id: String { rawValue }
    }

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: TonicDS.Space.xs) {
                ForEach(Tab.allCases) { tab in
                    FilterPill(title: tab.rawValue, isActive: selection == tab) {
                        selection = tab
                    }
                }
                Spacer()
            }
            .padding(TonicDS.Space.md)
            TonicHairline()

            Group {
                switch selection {
                case .widgets:
                    WidgetsPanelView()
                case .modules:
                    ModulesSettingsContent()
                case .popovers:
                    PopupSettingsView()
                }
            }
            .id(selection)
            .transition(.opacity)
            .animation(reduceMotion ? nil : TonicDS.Motion.present, value: selection)
        }
        .background(TonicDS.Colors.canvas)
    }
}
