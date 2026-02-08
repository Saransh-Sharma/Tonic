//
//  FanControlView.swift
//  Tonic
//
//  Fan control component with mode selection and per-fan sliders
//  Task ID: fn-8-v3b.11
//
//  NOTE: Actual SMC fan speed control requires privileged helper (task fn-8-v3b.13)
//  This component provides the UI and state management; SMC writes are deferred.
//

import SwiftUI

// MARK: - Fan Control View

/// Comprehensive fan control UI with mode selection and per-fan speed sliders
/// Matches Stats Master's fan control implementation pattern
///
/// Features:
/// - Mode selector: Auto / Manual / System
/// - Per-fan controls with min/max labels and sliders
/// - Safety features: warning dialog, thermal auto-switch
/// - Settings persistence via SensorsModuleSettings
///
/// **IMPORTANT:** SMC fan speed writes require the privileged helper tool.
/// This component stores target speeds and will send them to the helper
/// once it's implemented in task fn-8-v3b.13.
public struct FanControlView: View {

    // MARK: - Properties

    @State private var dataManager = WidgetDataManager.shared
    @State private var currentMode: SensorsModuleSettings.FanControlMode = .auto
    @State private var fanSpeeds: [String: Int] = [:]  // fanId -> speed (0-100%)
    @State private var showWarningDialog = false
    @State private var hasPendingModeChange = false
    @State private var pendingMode: SensorsModuleSettings.FanControlMode = .manual

    private let fanSpeedStorageKey = "tonic.widget.sensors.manualFanSpeeds"

    // Privileged helper availability check
    // Uses PrivilegedHelperManager to check if SMC writes are available
    // SMC writes may work directly on Apple Silicon, or require helper on Intel
    private var isHelperAvailable: Bool {
        return PrivilegedHelperManager.shared.isFanControlAvailable
    }

    private let thermalThreshold: Double = 85.0  // Celsius
    private var shouldShowThermalWarning: Bool {
        guard let maxTemp = dataManager.sensorsData.temperatures.map(\.value).max() else {
            return false
        }
        return maxTemp >= thermalThreshold && currentMode == .manual
    }

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

                // Helper not available notice
                if currentMode == .manual && !isHelperAvailable {
                    helperNotAvailableNotice
                }
            }

            // Thermal Warning
            if shouldShowThermalWarning {
                thermalWarningBanner
            }
        }
        .padding(PopoverConstants.horizontalPadding)
        .padding(.vertical, PopoverConstants.verticalPadding)
        .onAppear {
            loadSettings()
            // Revert to auto mode if helper is not available
            if currentMode == .manual && !isHelperAvailable {
                currentMode = .auto
                saveSettings()
            }
            initializeFanSpeeds()
            checkThermalThreshold()
        }
        .onChange(of: currentMode) { _, newValue in
            handleModeChange(newValue)
        }
        .onChange(of: dataManager.sensorsData.temperatures) { _, _ in
            checkThermalThreshold()
        }
        .alert("Manual Fan Control", isPresented: $showWarningDialog) {
            Button("Cancel", role: .cancel) {
                hasPendingModeChange = false
            }
            Button("I Understand", role: .destructive) {
                hasPendingModeChange = false
                applyModeChange(pendingMode)
            }
        } message: {
            Text(manualModeWarningMessage)
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

                // Sync indicator
                let syncEnabled = WidgetPreferences.shared.widgetConfigs
                    .first(where: { $0.type == .sensors })?.moduleSettings.sensors.syncFanControl ?? true
                if syncEnabled && currentMode != .auto {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 10))
                        .foregroundColor(DesignTokens.Colors.accent)
                }
            }

            Picker("", selection: $currentMode) {
                ForEach(SensorsModuleSettings.FanControlMode.allCases, id: \.self) { mode in
                    Label(mode.displayName, systemImage: mode.icon)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
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
                        set: { newSpeed in
                            fanSpeeds[fan.id] = newSpeed
                            updateFanSpeed(fanId: fan.id, speed: newSpeed)
                            // Sync other fans if enabled
                            let syncEnabled = WidgetPreferences.shared.widgetConfigs
                                .first(where: { $0.type == .sensors })?.moduleSettings.sensors.syncFanControl ?? true
                            if syncEnabled {
                                syncAllFans(to: newSpeed)
                            }
                        }
                    ),
                    isEditable: currentMode == .manual
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

    // MARK: - Thermal Warning Banner

    private var thermalWarningBanner: some View {
        HStack(spacing: PopoverConstants.compactSpacing) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("High Temperature")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(DesignTokens.Colors.textPrimary)

                Text("Fans switched to Auto for safety")
                    .font(.system(size: 9))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }

            Spacer()

            Button("Dismiss") {
                // User acknowledged, stay in auto mode
                saveSettings()
            }
            .font(.system(size: 9))
            .buttonStyle(.bordered)
        }
        .padding(PopoverConstants.compactSpacing)
        .background(TonicColors.warning.opacity(0.1))
        .cornerRadius(PopoverConstants.innerCornerRadius)
    }

    // MARK: - Helper Not Available Notice

    private var helperNotAvailableNotice: some View {
        HStack(spacing: PopoverConstants.compactSpacing) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Manual Mode Unavailable")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(DesignTokens.Colors.textPrimary)

                Text("The privileged helper tool is required for manual fan control. This will be available after task fn-8-v3b.13 is completed.")
                    .font(.system(size: 9))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }

            Spacer()

            Button("Return to Auto") {
                currentMode = .auto
            }
            .font(.system(size: 9))
            .buttonStyle(.bordered)
        }
        .padding(PopoverConstants.compactSpacing)
        .background(TonicColors.warning.opacity(0.1))
        .cornerRadius(PopoverConstants.innerCornerRadius)
    }

    // MARK: - Helper Methods

    private var manualModeWarningMessage: String {
        """
        Manual fan control allows you to set fan speeds manually.

        Important:
        • Setting fans too low may cause overheating
        • High temperatures will automatically switch back to Auto mode
        • Actual fan speed control requires the privileged helper (task fn-8-v3b.13)

        Are you sure you want to enable manual fan control?
        """
    }

    /// Check thermal threshold and auto-switch to auto mode if exceeded
    private func checkThermalThreshold() {
        guard let maxTemp = dataManager.sensorsData.temperatures.map(\.value).max() else {
            return
        }

        if maxTemp >= thermalThreshold && currentMode == .manual {
            // Auto-switch to auto mode for safety
            applyModeChange(.auto)
        }
    }

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

    private func saveSettings() {
        WidgetPreferences.shared.updateConfig(for: .sensors) { config in
            config.moduleSettings.sensors.fanControlMode = currentMode
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

    private func handleModeChange(_ newMode: SensorsModuleSettings.FanControlMode) {
        // Prevent manual mode if helper is not available
        if newMode == .manual && !isHelperAvailable {
            // Show alert and revert to auto mode
            DispatchQueue.main.async {
                self.currentMode = .auto
            }
            return
        }

        // Get current warning acknowledged status
        let hasAcknowledged = WidgetPreferences.shared.widgetConfigs
            .first(where: { $0.type == .sensors })?.moduleSettings.sensors.hasAcknowledgedFanWarning ?? false

        // Check if user has acknowledged warning for manual mode
        if newMode == .manual && !hasAcknowledged {
            pendingMode = newMode
            hasPendingModeChange = true
            showWarningDialog = true
            // Revert to previous mode until user acknowledges
            DispatchQueue.main.async {
                self.loadSettings()
            }
            return
        }

        applyModeChange(newMode)
    }

    private func applyModeChange(_ newMode: SensorsModuleSettings.FanControlMode) {
        // Mark warning as acknowledged if entering manual mode
        if newMode == .manual {
            WidgetPreferences.shared.updateConfig(for: .sensors) { config in
                config.moduleSettings.sensors.hasAcknowledgedFanWarning = true
                config.moduleSettings.sensors.fanControlMode = newMode
            }
        } else {
            saveSettings()
        }

        currentMode = newMode

        // Apply mode change to all fans
        if newMode == .auto {
            restoreAutoFanControl()
        }
    }

    private func updateFanSpeed(fanId: String, speed: Int) {
        guard currentMode == .manual else { return }

        // Clamp speed between 0 and 100
        let clampedSpeed = max(0, min(100, speed))

        // NOTE: Actual SMC fan control requires privileged helper (task fn-8-v3b.13)
        // The helper will expose SMC write commands via XPC
        // For now, store the speed value for UI display and persistence
        fanSpeeds[fanId] = clampedSpeed

        // Save speed if preference is enabled
        let saveSpeed = WidgetPreferences.shared.widgetConfigs
            .first(where: { $0.type == .sensors })?.moduleSettings.sensors.saveFanSpeed ?? false
        if saveSpeed {
            persistFanSpeeds()
        }
    }

    private func persistFanSpeeds() {
        UserDefaults.standard.set(fanSpeeds, forKey: fanSpeedStorageKey)
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

    private func syncAllFans(to speed: Int) {
        for fan in dataManager.sensorsData.fans {
            fanSpeeds[fan.id] = speed
            updateFanSpeed(fanId: fan.id, speed: speed)
        }
    }

    private func restoreAutoFanControl() {
        // NOTE: Restoring auto mode requires privileged helper (task fn-8-v3b.13)
        // The helper will send SMC command to re-enable automatic fan control
        // This is a safety-critical operation and must go through the privileged helper
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
