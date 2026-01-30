//
//  GeneralPreferencesSection.swift
//  Tonic
//
//  General preferences section - extracted from PreferencesView
//  Handles launch at login, update checking, and startup options
//

import SwiftUI

// MARK: - General Preferences Section

struct GeneralPreferencesSection: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("checkForUpdates") private var checkForUpdates = true
    @AppStorage("updateFrequency") private var updateFrequency: Int = 1  // Daily
    @State private var showRestartAlert = false
    @State private var error: TonicError?

    var body: some View {
        Section("General") {
            // Launch at Login Toggle
            Toggle("Launch at Login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { oldValue, newValue in
                    handleLaunchAtLoginChange(newValue)
                }
                .help("Start Tonic automatically when you log in")

            Divider()

            // Update Checking
            Toggle("Check for Updates", isOn: $checkForUpdates)
                .onChange(of: checkForUpdates) { _, newValue in
                    if newValue {
                        checkForUpdatesNow()
                    }
                }
                .help("Automatically check for app updates")

            // Update Frequency
            if checkForUpdates {
                Picker("Check Frequency", selection: $updateFrequency) {
                    Text("Daily").tag(1)
                    Text("Weekly").tag(7)
                    Text("Monthly").tag(30)
                }
                .pickerStyle(.segmented)
                .help("How often to check for updates")
            }

            Divider()

            // About and Support
            HStack(spacing: DesignTokens.Spacing.md) {
                Button(action: openAbout) {
                    HStack {
                        Image(systemName: "info.circle")
                        Text("About Tonic")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer()

                Button(action: openDocumentation) {
                    HStack {
                        Image(systemName: "book.circle")
                        Text("Documentation")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Divider()

            // Feedback & Support
            Button(action: openFeedback) {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: "message.circle")
                    Text("Send Feedback")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                }
            }
            .buttonStyle(.borderless)
            .foregroundColor(DesignTokens.Colors.accent)
        }
        .alert("Restart Required", isPresented: $showRestartAlert) {
            Button("Restart", action: restartApp)
            Button("Later", role: .cancel) { }
        } message: {
            Text("Changes will take effect after restart.")
        }

        // Error handling
        if let error = error {
            ErrorView(
                error: error,
                action: nil,
                dismiss: { self.error = nil }
            )
        }
    }

    // MARK: - Actions

    private func handleLaunchAtLoginChange(_ enabled: Bool) {
        do {
            try updateLaunchAtLoginSetting(enabled)
        } catch let err as TonicError {
            error = err
            launchAtLogin = !enabled
        } catch {
            error = .settingsFailed(reason: error.localizedDescription)
            launchAtLogin = !enabled
        }
    }

    private func checkForUpdatesNow() {
        // Trigger immediate update check
        Task {
            do {
                // await updateChecker.checkForUpdates()
            } catch let err as TonicError {
                error = err
            }
        }
    }

    private func updateLaunchAtLoginSetting(_ enabled: Bool) throws {
        let loginItemsManager = LoginItemsManager.shared
        if enabled {
            try loginItemsManager.addCurrentAppToLoginItems()
        } else {
            try loginItemsManager.removeCurrentAppFromLoginItems()
        }
    }

    private func openAbout() {
        // Navigate to about screen
    }

    private func openDocumentation() {
        if let url = URL(string: "https://tonic.help/docs") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openFeedback() {
        // Open feedback sheet
    }

    private func restartApp() {
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", "sleep 0.5 && open \(Bundle.main.bundlePath)"]
        try? task.run()
        NSApplication.shared.terminate(self)
    }
}

// MARK: - Preview

#if DEBUG
struct GeneralPreferencesSection_Previews: PreviewProvider {
    static var previews: some View {
        Form {
            GeneralPreferencesSection()
        }
        .padding()
        .background(DesignTokens.Colors.background)
    }
}
#endif
