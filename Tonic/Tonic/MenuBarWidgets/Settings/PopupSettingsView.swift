import SwiftUI

public struct PopupSettingsView: View {
    @State private var store = PopupSettingsStore.shared

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TonicDS.Space.xl) {
                TonicPageHeader("Popover Console",
                                subtitle: "Chart history, scaling, and width for the menu-bar consoles.")

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

                    TonicPreferenceRow(title: "Scaling", description: "How percentage charts fit their vertical range. Rate charts always auto-scale.",
                                       showsDivider: store.settings.scalingMode == .fixed) {
                        Picker("", selection: $store.settings.scalingMode) {
                            ForEach(PopupSettings.ScalingMode.allCases, id: \.self) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 140)
                        .accessibilityLabel("Chart scaling mode")
                    }

                    if store.settings.scalingMode == .fixed {
                        TonicPreferenceRow(title: "Fixed Ceiling", description: "Percentage charts pin their top to this value.", showsDivider: false) {
                            Stepper(value: $store.settings.fixedScaleValue, in: 10...200, step: 10) {
                                Text("\(Int(store.settings.fixedScaleValue))%")
                                    .tonicType(.monoLabel)
                                    .monospacedDigit()
                                    .foregroundStyle(TonicDS.Colors.textPrimary)
                                    .frame(width: 54, alignment: .trailing)
                            }
                        }
                    }
                }

                SettingsPanel(title: "SHORTCUT") {
                    TonicPreferenceRow(title: "Toggle Console",
                                       description: "System-wide shortcut that opens the primary menu-bar console. While recording, Esc cancels and Delete clears.",
                                       showsDivider: false) {
                        KeyboardShortcutRecorder()
                    }
                }

                SettingsPanel(title: "CONSOLE") {
                    TonicPreferenceRow(title: "Width", description: "Popover console width in points.", showsDivider: false) {
                        HStack(spacing: TonicDS.Space.sm) {
                            Slider(value: $store.settings.popoverWidth, in: 260...360, step: 10)
                                .frame(width: 140)
                                .accessibilityLabel("Popover width")
                            Text("\(Int(store.settings.popoverWidth)) pt")
                                .tonicType(.monoLabel)
                                .monospacedDigit()
                                .foregroundStyle(TonicDS.Colors.textPrimary)
                                .frame(width: 54, alignment: .trailing)
                        }
                    }
                }
            }
            .padding(TonicDS.Space.xl)
        }
        .background(TonicDS.Colors.canvas)
    }
}
