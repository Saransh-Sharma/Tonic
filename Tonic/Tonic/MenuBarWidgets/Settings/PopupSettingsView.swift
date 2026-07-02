import SwiftUI

public struct PopupSettingsView: View {
    @State private var store = PopupSettingsStore.shared

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TonicDS.Space.xl) {
                TonicPageHeader("Popover Console",
                                subtitle: "Chart history and scaling for the fixed 280 pt menu-bar consoles.")

                SettingsPanel(title: "CHARTS") {
                    TonicPreferenceRow(title: "History Window", description: "How much recent history popover charts keep on screen.") {
                        Stepper(value: $store.settings.chartHistoryDuration, in: 60...300, step: 30) {
                            Text("\(store.settings.chartHistoryDuration)s")
                                .tonicType(.monoLabel)
                                .monospacedDigit()
                                .foregroundStyle(TonicDS.Colors.textPrimary)
                                .frame(width: 54, alignment: .trailing)
                        }
                    }

                    TonicPreferenceRow(title: "Scaling", description: "How popover charts fit their vertical range.", showsDivider: false) {
                        Picker("", selection: $store.settings.scalingMode) {
                            ForEach(PopupSettings.ScalingMode.allCases, id: \.self) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 140)
                        .accessibilityLabel("Chart scaling mode")
                    }
                }
            }
            .padding(TonicDS.Space.xl)
        }
        .background(TonicDS.Colors.canvas)
    }
}
