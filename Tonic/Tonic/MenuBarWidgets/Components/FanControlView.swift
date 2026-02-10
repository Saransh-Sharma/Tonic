//
//  FanControlView.swift
//  Tonic
//
//  Fan control component with mode selection and per-fan sliders
//

import SwiftUI

// MARK: - Fan Control View

/// Comprehensive fan control UI with mode selection and per-fan speed sliders
///
/// Features:
/// - Read-only Auto mode indicator
/// - Per-fan speed visualization with disabled controls
/// - Settings persistence for stored fan speed percentages
public struct FanControlView: View {

    // MARK: - Properties

    @State private var dataManager = WidgetDataManager.shared
    @State private var currentMode: SensorsModuleSettings.FanControlMode = .auto
    @State private var fanSpeeds: [String: Int] = [:]  // fanId -> speed (0-100%)

    private let fanSpeedStorageKey = "tonic.widget.sensors.manualFanSpeeds"

    // MARK: - Body

    public var body: some View {
        VStack(spacing: PopoverConstants.sectionSpacing) {
            // Mode Selector
            modeSelector

            Divider()

            // Fan Controls
            if dataManager.sensorsData.fans.isEmpty {
                emptyStateView
            } else {
                fanControlsList
            }
        }
        .padding(PopoverConstants.horizontalPadding)
        .padding(.vertical, PopoverConstants.verticalPadding)
        .onAppear {
            loadSettings()
            initializeFanSpeeds()
            enforceReadOnlyMode()
        }
    }

    // MARK: - Mode Selector

    private var modeSelector: some View {
        VStack(spacing: PopoverConstants.compactSpacing) {
            HStack {
                Text("Fan Control")
                    .font(PopoverConstants.sectionTitleFont)
                    .foregroundColor(DesignTokens.Colors.textPrimary)

                Spacer()
            }

            Picker("", selection: $currentMode) {
                Label(SensorsModuleSettings.FanControlMode.auto.displayName, systemImage: SensorsModuleSettings.FanControlMode.auto.icon)
                    .tag(SensorsModuleSettings.FanControlMode.auto)
            }
            .pickerStyle(.segmented)
            .disabled(true)

            Text("Manual fan control is disabled in this build.")
                .font(PopoverConstants.detailLabelFont)
                .foregroundColor(DesignTokens.Colors.textSecondary)
        }
    }

    // MARK: - Fan Controls List

    private var fanControlsList: some View {
        VStack(spacing: PopoverConstants.compactSpacing) {
            ForEach(dataManager.sensorsData.fans) { fan in
                FanControlRow(
                    fan: fan,
                    speed: Binding(
                        get: { fanSpeeds[fan.id] ?? 50 },
                        set: { _ in }
                    ),
                    isEditable: false
                )
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: PopoverConstants.itemSpacing) {
            Image(systemName: "fan.slash")
                .font(.system(size: 32))
                .foregroundColor(DesignTokens.Colors.textSecondary)

            Text("No Fans Detected")
                .font(PopoverConstants.sectionTitleFont)
                .foregroundColor(DesignTokens.Colors.textPrimary)

            Text("Fan control is not available on this Mac.")
                .font(PopoverConstants.detailLabelFont)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, PopoverConstants.sectionSpacing)
    }

    // MARK: - Helper Methods

    private func loadSettings() {
        // Get sensors widget config to read fan control mode
        if let sensorsWidget = WidgetPreferences.shared.widgetConfigs.first(where: { $0.type == .sensors }) {
            currentMode = sensorsWidget.moduleSettings.sensors.fanControlMode
            if sensorsWidget.moduleSettings.sensors.saveFanSpeed {
                fanSpeeds = loadPersistedFanSpeeds()
            } else {
                fanSpeeds.removeAll()
            }
        }
    }

    private func enforceReadOnlyMode() {
        currentMode = .auto
        WidgetPreferences.shared.updateConfig(for: .sensors) { config in
            config.moduleSettings.sensors.fanControlMode = .auto
        }
    }

    private func initializeFanSpeeds() {
        let saveSpeed = WidgetPreferences.shared.widgetConfigs
            .first(where: { $0.type == .sensors })?.moduleSettings.sensors.saveFanSpeed ?? false
        let persistedSpeeds = saveSpeed ? loadPersistedFanSpeeds() : [:]

        for fan in dataManager.sensorsData.fans {
            if let persisted = persistedSpeeds[fan.id] {
                fanSpeeds[fan.id] = max(0, min(100, persisted))
                continue
            }

            // Initialize current speed as percentage of max
            if let maxRPM = fan.maxRPM, maxRPM > 0 {
                fanSpeeds[fan.id] = Int((Double(fan.rpm) / Double(maxRPM)) * 100)
            } else {
                fanSpeeds[fan.id] = 50  // Default to 50%
            }
        }
    }

    private func loadPersistedFanSpeeds() -> [String: Int] {
        guard let raw = UserDefaults.standard.dictionary(forKey: fanSpeedStorageKey), !raw.isEmpty else {
            return [:]
        }

        var persisted: [String: Int] = [:]
        for (fanId, value) in raw {
            if let speed = value as? Int {
                persisted[fanId] = speed
            } else if let speed = value as? Double {
                persisted[fanId] = Int(speed.rounded())
            }
        }
        return persisted
    }

    // MARK: - Initializer

    public init() {}
}

// MARK: - Fan Control Row

/// Individual fan control row with slider and speed display
struct FanControlRow: View {
    let fan: FanReading
    @Binding var speed: Int
    let isEditable: Bool

    var body: some View {
        VStack(spacing: PopoverConstants.compactSpacing) {
            // Header: fan name and current speed
            HStack {
                Text(fan.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(DesignTokens.Colors.textPrimary)

                Spacer()

                Text(speedDisplay)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isEditable ? DesignTokens.Colors.accent : DesignTokens.Colors.textSecondary)
            }

            // Slider with min/max labels
            HStack(spacing: PopoverConstants.compactSpacing) {
                // Min speed label
                if let minRPM = fan.minRPM {
                    Text("\(minRPM)")
                        .font(.system(size: 8))
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                        .frame(width: 30, alignment: .leading)
                } else {
                    Text("0")
                        .font(.system(size: 8))
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                        .frame(width: 30, alignment: .leading)
                }

                // Speed slider
                Slider(value: Binding(
                    get: { Double(speed) },
                    set: { newSpeed in
                        guard isEditable else { return }
                        speed = Int(newSpeed)
                    }
                ), in: 0...100, step: 1)
                .disabled(!isEditable)
                .accentColor(isEditable ? DesignTokens.Colors.accent : DesignTokens.Colors.textSecondary)

                // Max speed label
                if let maxRPM = fan.maxRPM {
                    Text("\(maxRPM)")
                        .font(.system(size: 8))
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                        .frame(width: 30, alignment: .trailing)
                } else {
                    Text("6000")
                        .font(.system(size: 8))
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                        .frame(width: 30, alignment: .trailing)
                }
            }

            // Current RPM indicator
            HStack {
                Text("Current: \(fan.rpm) RPM")
                    .font(.system(size: 9))
                    .foregroundColor(DesignTokens.Colors.textSecondary)

                Spacer()

                if isEditable {
                    Text("Manual")
                        .font(.system(size: 8))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(DesignTokens.Colors.accent.opacity(0.2))
                        .foregroundColor(DesignTokens.Colors.accent)
                        .cornerRadius(PopoverConstants.smallCornerRadius)
                }
            }
        }
        .padding(PopoverConstants.compactSpacing)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(PopoverConstants.innerCornerRadius)
    }

    private var speedDisplay: String {
        let estimatedRPM: Int
        if let maxRPM = fan.maxRPM {
            estimatedRPM = Int((Double(speed) / 100.0) * Double(maxRPM))
        } else {
            estimatedRPM = Int((Double(speed) / 100.0) * 6000)
        }
        return "\(estimatedRPM) RPM"
    }
}

// MARK: - Preview

#Preview("Fan Control View") {
    VStack {
        FanControlView()
            .frame(width: 280)
    }
    .background(Color(nsColor: .windowBackgroundColor))
}

#Preview("Fan Control Row") {
    VStack(spacing: 16) {
        FanControlRow(
            fan: FanReading(
                id: "fan0",
                name: "CPU Fan",
                rpm: 1800,
                minRPM: 800,
                maxRPM: 6000,
                mode: .automatic
            ),
            speed: .constant(30),
            isEditable: true
        )

        FanControlRow(
            fan: FanReading(
                id: "fan1",
                name: "GPU Fan",
                rpm: 2400,
                minRPM: 1000,
                maxRPM: 5500,
                mode: .forced
            ),
            speed: .constant(40),
            isEditable: false
        )
    }
    .padding()
    .background(Color(nsColor: .windowBackgroundColor))
}
