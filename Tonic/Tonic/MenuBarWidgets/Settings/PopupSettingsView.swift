import SwiftUI

public struct PopupSettingsView: View {
    @State private var settings = PopupSettings.default

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TonicDS.Space.xl) {
                TonicPageHeader("Popover Console", subtitle: "Chart history, scaling, keyboard access, and fixed console dimensions.")

                SettingsPanel(title: "BEHAVIOR") {
                    TonicPreferenceRow(title: "Keyboard Shortcut", description: "Stored shortcut label for opening widget popovers.") {
                        Text(settings.keyboardShortcut ?? "None")
                            .tonicType(.monoLabel)
                            .foregroundStyle(TonicDS.Colors.textMuted)
                    }

                    TonicPreferenceRow(title: "History Window", description: "Seconds retained for popover charts.") {
                        Stepper(value: $settings.chartHistoryDuration, in: 60...300, step: 30) {
                            Text("\(settings.chartHistoryDuration)s")
                                .tonicType(.monoLabel)
                                .monospacedDigit()
                                .foregroundStyle(TonicDS.Colors.textPrimary)
                                .frame(width: 54, alignment: .trailing)
                        }
                    }

                    TonicPreferenceRow(title: "Scaling", description: "Popover chart scale mode.") {
                        Picker("", selection: $settings.scalingMode) {
                            ForEach(PopupSettings.ScalingMode.allCases, id: \.self) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 140)
                    }

                    TonicPreferenceRow(title: "Popover Width", description: "Retained fixed console width.", showsDivider: false) {
                        Text("\(Int(settings.popoverWidth)) pt")
                            .tonicType(.monoLabel)
                            .monospacedDigit()
                            .foregroundStyle(TonicDS.Colors.textPrimary)
                    }
                }
            }
            .padding(TonicDS.Space.xl)
        }
        .background(TonicDS.Colors.canvas)
    }
}
