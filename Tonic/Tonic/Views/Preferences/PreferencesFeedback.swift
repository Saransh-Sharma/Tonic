//
//  PreferencesFeedback.swift
//  Tonic
//
//  Extracted from PreferencesView.swift to keep settings sections modular.
//

import SwiftUI
import AppKit
import UserNotifications

#if canImport(Sparkle)
import Sparkle
#endif


// MARK: - Feedback Types

enum FeedbackReportType: String {
    case bug
    case featureRequest = "feature_request"
    case performance
    case crash
    case general
}

// MARK: - Minimal Feedback Manager for PreferencesView

class SimpleFeedbackManager {
    static let shared = SimpleFeedbackManager()

    func getApplicationLogs() -> String? {
        guard let logsURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first else { return nil }
        let logFile = logsURL.appendingPathComponent("Logs/com.tonic.Tonic/system.log")

        guard FileManager.default.fileExists(atPath: logFile.path) else { return nil }

        do {
            let logContent = try String(contentsOf: logFile, encoding: .utf8)
            let logLines = logContent.split(separator: "\n").suffix(100).joined(separator: "\n")
            return logLines.isEmpty ? nil : logLines
        } catch {
            return nil
        }
    }

    func submitFeedback(
        type: FeedbackReportType,
        title: String,
        description: String,
        logs: String? = nil
    ) throws {
        let label = type == .bug ? "bug" : (type == .featureRequest ? "enhancement" : "feedback")
        let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Issue"
        let fullDescription = logs.map { "\(description)\n\nLogs:\n\($0)" } ?? description
        let encodedDescription = fullDescription.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        let gitHubURL = URL(string: "https://github.com/Saransh-Sharma/PreTonic/issues/new?title=\(encodedTitle)&labels=\(label)&body=\(encodedDescription)")!

        DispatchQueue.main.async {
            NSWorkspace.shared.open(gitHubURL)
        }
    }
}

// MARK: - Settings Navigation


struct FeedbackSheetView: View {
    @Environment(\.dismiss) var dismiss
    @State private var feedbackType: FeedbackReportType = .general
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var includeLogs = false
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                HStack(spacing: DesignTokens.Spacing.md) {
                    Image(systemName: "bubble.right.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(TonicColors.accent)

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
                        Text("Send Feedback")
                            .font(DesignTokens.Typography.h3)
                            .foregroundColor(DesignTokens.Colors.textPrimary)

                        Text("Help us improve Tonic by sharing your feedback")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    }

                    Spacer()
                }
                .padding(DesignTokens.Spacing.lg)
            }
            .background(DesignTokens.Colors.backgroundSecondary.opacity(0.5))

            Divider()

            // Content
            ScrollView {
                VStack(spacing: DesignTokens.Spacing.lg) {
                    // Feedback Type
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        Text("Feedback Type")
                            .font(DesignTokens.Typography.captionEmphasized)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                            .fontWeight(.medium)

                        Picker("Type", selection: $feedbackType) {
                            Text("General Feedback").tag(FeedbackReportType.general)
                            Text("Bug Report").tag(FeedbackReportType.bug)
                            Text("Feature Request").tag(FeedbackReportType.featureRequest)
                            Text("Performance Issue").tag(FeedbackReportType.performance)
                        }
                        .pickerStyle(.segmented)
                    }

                    // Title
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text("Title")
                            .font(DesignTokens.Typography.captionEmphasized)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                            .fontWeight(.medium)

                        TextField("Brief summary of your feedback", text: $title)
                            .font(DesignTokens.Typography.body)
                            .padding(DesignTokens.Spacing.sm)
                            .background(DesignTokens.Colors.backgroundSecondary)
                            .cornerRadius(DesignTokens.CornerRadius.medium)
                    }

                    // Description
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            Text("Description")
                                .font(DesignTokens.Typography.captionEmphasized)
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                                .fontWeight(.medium)

                            Spacer()

                            Text("\(description.count)/500")
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(DesignTokens.Colors.textTertiary)
                        }

                        TextEditor(text: $description)
                            .font(DesignTokens.Typography.body)
                            .scrollContentBackground(.hidden)
                            .background(DesignTokens.Colors.backgroundSecondary)
                            .cornerRadius(DesignTokens.CornerRadius.medium)
                            .frame(height: 120)
                            .onChange(of: description) { _, newValue in
                                if newValue.count > 500 {
                                    description = String(newValue.prefix(500))
                                }
                            }
                    }

                    // Include Logs
                    Toggle(isOn: $includeLogs) {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
                            Text("Include Application Logs")
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(DesignTokens.Colors.textPrimary)

                            Text("Help us diagnose issues faster by including recent logs")
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                        }
                    }

                    // System Info
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text("System Information")
                            .font(DesignTokens.Typography.captionEmphasized)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                            .fontWeight(.medium)

                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                            SystemInfoRow(label: "macOS Version", value: systemMacOSVersion)
                            SystemInfoRow(label: "App Version", value: appVersion)
                            SystemInfoRow(label: "Architecture", value: systemArchitecture)
                        }
                        .padding(DesignTokens.Spacing.sm)
                        .background(DesignTokens.Colors.backgroundSecondary)
                        .cornerRadius(DesignTokens.CornerRadius.medium)
                    }

                    if let error = errorMessage {
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(DesignTokens.Colors.error)

                            Text(error)
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(DesignTokens.Colors.error)

                            Spacer()
                        }
                        .padding(DesignTokens.Spacing.sm)
                        .background(DesignTokens.Colors.error.opacity(0.1))
                        .cornerRadius(DesignTokens.CornerRadius.medium)
                    }
                }
                .padding(DesignTokens.Spacing.lg)
            }

            Divider()

            // Footer
            HStack(spacing: DesignTokens.Spacing.md) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button {
                    submitFeedback()
                } label: {
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        if isSubmitting {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "paperplane.fill")
                        }
                        Text(isSubmitting ? "Sending..." : "Send Feedback")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSubmitting || title.trimmingCharacters(in: .whitespaces).isEmpty || description.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .frame(width: 500, height: 700)
        .alert("Success", isPresented: $showSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Thank you for your feedback! We appreciate your input.")
        }
    }

    private func submitFeedback() {
        isSubmitting = true
        errorMessage = nil

        Task {
            do {
                let logs = includeLogs ? SimpleFeedbackManager.shared.getApplicationLogs() : nil
                try SimpleFeedbackManager.shared.submitFeedback(
                    type: feedbackType,
                    title: title,
                    description: description,
                    logs: logs
                )
                await MainActor.run {
                    isSubmitting = false
                    showSuccess = true
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private var appVersion: String {
        Bundle.main.appVersion
    }

    private var systemMacOSVersion: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }

    private var systemArchitecture: String {
        var sysinfo = utsname()
        uname(&sysinfo)
        // Convert Int8 array to UInt8 array for String(decodingCString:as:)
        let machineData = withUnsafeBytes(of: &sysinfo.machine) { rawBuffer in
            Data(rawBuffer)
        }
        return String(data: machineData, encoding: .utf8)?.trimmingCharacters(in: .controlCharacters) ?? "unknown"
    }
}

// MARK: - System Info Row

