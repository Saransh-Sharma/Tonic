//
//  NotificationManager.swift
//  Tonic
//
//  Central notification management service
//  Task ID: fn-6-i4g.3
//

import Foundation
import UserNotifications
import AppKit
import os

// MARK: - Notification Time Tracker

/// Actor for thread-safe tracking of notification times
private actor NotificationTimeTracker {
    private var times: [String: Date] = [:]

    func getLastTime(for thresholdId: String) -> Date? {
        times[thresholdId]
    }

    func setLastTime(_ date: Date, for thresholdId: String) {
        times[thresholdId] = date
    }

    func removeTime(for thresholdId: String) {
        times.removeValue(forKey: thresholdId)
    }

    func removeAll() {
        times.removeAll()
    }

    func getAll() -> [String: Date] {
        times
    }

    func setAll(_ newTimes: [String: Date]) {
        times = newTimes
    }
}

// MARK: - Notification Manager

/// Central manager for threshold-based notifications
@MainActor
@Observable
public final class NotificationManager: Sendable {

    // MARK: - Singleton

    public static let shared = NotificationManager()

    private let logger = Logger(subsystem: "com.tonic.app", category: "NotificationManager")

    // MARK: - Configuration

    /// Current notification configuration
    public private(set) var config: NotificationConfig {
        didSet {
            config.save()
        }
    }

    /// Whether notification permission has been granted
    public private(set) var hasPermission: Bool = false

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let lastNotificationTime = "tonic.notifications.lastNotification"
    }

    // MARK: - Private State

    /// Tracks the last notification time for each threshold ID
    private let timeTracker = NotificationTimeTracker()

    // MARK: - Initialization

    private init() {
        // Load configuration from UserDefaults
        self.config = NotificationConfig.load()

        // Load last notification times
        Task {
            await loadLastNotificationTimes()
        }

        // Check initial permission status
        Task {
            _ = await checkPermissionStatus()
        }

        logger.info("NotificationManager initialized with \(self.config.thresholds.count) thresholds")
    }

    // MARK: - Permission Management

    /// Check if notification permission is granted
    public func checkPermissionStatus() async -> Bool {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                let granted = settings.authorizationStatus == .authorized
                Task { @MainActor in
                    self.hasPermission = granted
                }
                continuation.resume(returning: granted)
            }
        }
    }

    /// Request notification permission from the user
    /// - Parameter completionHandler: Optional callback with the result
    public func requestPermission(completionHandler: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            Task { @MainActor in
                self.hasPermission = granted
                if let error = error {
                    self.logger.error("Notification permission error: \(error.localizedDescription)")
                } else if granted {
                    self.logger.info("Notification permission granted")
                } else {
                    self.logger.info("Notification permission denied")
                }
                completionHandler?(granted)
            }
        }
    }

    /// Open macOS notification settings for Tonic (app-specific deep link, macOS 14+)
    public func openNotificationSettings() {
        let bundleId = Bundle.main.bundleIdentifier ?? "com.tonic.Tonic"
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications?id=\(bundleId)") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Threshold Checking

    /// Check if a value triggers any configured thresholds for a widget type
    /// - Parameters:
    ///   - widgetType: The type of widget to check
    ///   - value: The current value to evaluate
    public func checkThreshold(widgetType: WidgetType, value: Double) {
        guard config.notificationsEnabled else { return }

        let enabledThresholds = config.enabledThresholds(for: widgetType)

        for threshold in enabledThresholds {
            if threshold.matches(currentValue: value) {
                Task {
                    await triggerNotificationIfNeeded(threshold: threshold, currentValue: value)
                }
            }
        }
    }

    /// Check if a specific threshold should trigger a notification
    /// - Parameters:
    ///   - threshold: The threshold to check
    ///   - currentValue: The current value that matched the threshold
    private func triggerNotificationIfNeeded(threshold: NotificationThreshold, currentValue: Double) async {
        // Check if enough time has passed since last notification for this threshold
        let shouldSend = await shouldSendNotification(for: threshold.id)
        if !shouldSend {
            logger.debug("Skipping notification for \(threshold.widgetType.displayName) - debounce active")
            return
        }

        // Check Do Not Disturb if configured
        if config.respectDoNotDisturb && isInDoNotDisturb() {
            logger.debug("Skipping notification - Do Not Disturb is active")
            return
        }

        // Check permission
        guard hasPermission else {
            logger.warning("Cannot send notification - permission not granted")
            return
        }

        // Generate notification content and send
        let (title, body) = generateNotificationContent(threshold: threshold, currentValue: currentValue)
        sendNotification(title: title, body: body, thresholdId: threshold.id.uuidString)

        // Update last notification time
        await setLastNotificationTime(for: threshold.id)
    }

    /// Check if enough time has passed to send another notification for a threshold
    /// - Parameter thresholdId: The threshold ID to check
    /// - Returns: True if notification should be sent
    private func shouldSendNotification(for thresholdId: UUID) async -> Bool {
        guard let lastTime = await timeTracker.getLastTime(for: thresholdId.uuidString) else {
            return true // Never sent, can send now
        }

        let elapsed = Date().timeIntervalSince(lastTime)
        return elapsed >= config.minimumInterval
    }

    /// Update the last notification time for a threshold
    /// - Parameter thresholdId: The threshold ID to update
    private func setLastNotificationTime(for thresholdId: UUID) async {
        await timeTracker.setLastTime(Date(), for: thresholdId.uuidString)
        await saveLastNotificationTimes()
    }

    // MARK: - Notification Sending

    /// Generate title and body for a threshold notification
    /// - Parameters:
    ///   - threshold: The threshold that was triggered
    ///   - currentValue: The current value
    /// - Returns: A tuple of (title, body)
    private func generateNotificationContent(threshold: NotificationThreshold, currentValue: Double) -> (String, String) {
        let widgetName = threshold.widgetType.displayName

        let title: String
        let body: String

        switch threshold.widgetType {
        case .cpu, .gpu, .memory:
            let currentPercent = String(format: "%.0f%%", currentValue)
            title = "\(widgetName) Usage Alert"
            body = "Current usage is \(currentPercent) (threshold: \(threshold.formattedValue))"

        case .disk:
            let currentPercent = String(format: "%.0f%%", currentValue)
            title = "Disk Space Alert"
            body = "Disk usage is \(currentPercent) (threshold: \(threshold.formattedValue))"

        case .battery:
            if currentValue <= 20 {
                title = "Low Battery Warning"
                body = "Battery is at \(threshold.formattedValue)"
            } else {
                title = "Battery Alert"
                body = "Battery is at \(threshold.formattedValue)"
            }

        case .network:
            let currentSpeed = String(format: "%.1f MB/s", currentValue)
            title = "Network Alert"
            body = "Network speed is \(currentSpeed) (threshold: \(threshold.formattedValue))"

        case .sensors:
            let currentTemp = String(format: "%.1f°", currentValue)
            title = "Temperature Alert"
            body = "Sensor temperature is \(currentTemp) (threshold: \(threshold.formattedValue))"

        case .weather:
            title = "Weather Alert"
            body = "Temperature is \(threshold.formattedValue)"

        case .bluetooth:
            let currentPercent = String(format: "%.0f%%", currentValue)
            title = "Bluetooth Device Alert"
            body = "Device battery at \(currentPercent) (threshold: \(threshold.formattedValue))"

        case .clock:
            title = "Clock Alert"
            body = "Clock threshold triggered"
        }

        return (title, body)
    }

    /// Send a notification
    /// - Parameters:
    ///   - title: Notification title
    ///   - body: Notification body
    ///   - thresholdId: Unique identifier for this notification
    public func sendNotification(title: String, body: String, thresholdId: String = UUID().uuidString) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        // Create notification request
        let request = UNNotificationRequest(
            identifier: "tonic_\(thresholdId)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil // Immediate delivery
        )

        // Add the notification request
        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error = error {
                self?.logger.error("Failed to send notification: \(error.localizedDescription)")
            } else {
                self?.logger.info("Notification sent: \(title)")
            }
        }
    }

    /// Send a test notification for verification
    public func sendTestNotification() {
        sendNotification(
            title: "Tonic Notifications",
            body: "Notification system is working correctly!",
            thresholdId: "test"
        )
    }

    // MARK: - Do Not Disturb Detection

    /// Check if macOS Do Not Disturb / Focus mode is active
    /// - Returns: True if DND is active
    private func isInDoNotDisturb() -> Bool {
        // Check notification center materials
        // Note: macOS doesn't provide a direct API to check DND status
        // This is a best-effort implementation using NSWorkspace
        let workspace = NSWorkspace.shared

        // Check if we're in fullscreen mode which often suppresses notifications
        if let frontmostApp = workspace.frontmostApplication {
            if frontmostApp.activationPolicy == .regular {
                // For regular apps, check if the app has presentation options that might suppress notifications
                let options = NSApp.presentationOptions
                if options.contains(.hideDock) || options.contains(.disableProcessSwitching) {
                    return true
                }
            }
        }

        return false
    }

    // MARK: - Configuration Management

    /// Update a threshold in the configuration
    /// - Parameter threshold: The threshold to add or update
    public func updateThreshold(_ threshold: NotificationThreshold) {
        config.setThreshold(threshold)
    }

    /// Remove a threshold from the configuration
    /// - Parameter id: The ID of the threshold to remove
    public func removeThreshold(id: UUID) {
        config.removeThreshold(id: id)
        // Clear last notification time for this threshold
        Task {
            await timeTracker.removeTime(for: id.uuidString)
            await saveLastNotificationTimes()
        }
    }

    /// Toggle a threshold's enabled state
    /// - Parameter id: The ID of the threshold to toggle
    public func toggleThreshold(id: UUID) {
        config.toggleThreshold(id: id)
    }

    /// Toggle the enabled state of notifications
    public func toggleNotifications() {
        config.notificationsEnabled.toggle()
    }

    /// Update the minimum interval between notifications
    /// - Parameter interval: New interval in seconds
    public func setMinimumInterval(_ interval: TimeInterval) {
        config.minimumInterval = interval
    }

    /// Toggle respect for Do Not Disturb
    public func toggleRespectDoNotDisturb() {
        config.respectDoNotDisturb.toggle()
    }

    /// Reset all notification settings to defaults
    public func resetToDefaults() {
        config.reset()
        Task {
            await timeTracker.removeAll()
            await saveLastNotificationTimes()
        }
        logger.info("Notification configuration reset to defaults")
    }

    // MARK: - Persistence

    /// Load last notification times from UserDefaults
    private func loadLastNotificationTimes() async {
        guard let data = UserDefaults.standard.data(forKey: Keys.lastNotificationTime),
              let decoded = try? JSONDecoder().decode([String: Date].self, from: data) else {
            return
        }

        await timeTracker.setAll(decoded)
    }

    /// Save last notification times to UserDefaults
    private func saveLastNotificationTimes() async {
        let timesToSave = await timeTracker.getAll()

        if let encoded = try? JSONEncoder().encode(timesToSave) {
            UserDefaults.standard.set(encoded, forKey: Keys.lastNotificationTime)
        }
    }

    // MARK: - Cleanup

    /// Remove all pending notifications
    public func removeAllPendingNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        logger.info("All pending notifications removed")
    }

    /// Remove all delivered notifications
    public func removeAllDeliveredNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        logger.info("All delivered notifications removed")
    }
}
