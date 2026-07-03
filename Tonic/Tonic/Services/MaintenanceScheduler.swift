//
//  MaintenanceScheduler.swift
//  Tonic
//
//  Scheduled automatic maintenance: on a daily/weekly cadence Tonic runs a
//  Smart Care scan and cleans ONLY safe, smart-selected system junk. Personal
//  data (.personal) is never touched automatically — that policy is enforced
//  here in addition to the review-sheet flow.
//
//  Design: an in-app timer plus a catch-up check on activation. Tonic is a
//  resident menu-bar app, so no separate agent target is required; "Open at
//  Login" (Settings) keeps the schedule alive across reboots.
//

import AppKit
import Foundation

enum MaintenanceCadence: String, Codable, CaseIterable, Identifiable {
    case off
    case daily
    case weekly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .off: return "Off"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        }
    }

    var interval: TimeInterval? {
        switch self {
        case .off: return nil
        case .daily: return 24 * 3600
        case .weekly: return 7 * 24 * 3600
        }
    }
}

@MainActor
@Observable
final class MaintenanceScheduler {

    static let shared = MaintenanceScheduler()

    private enum Keys {
        static let cadence = "tonic.maintenance.cadence"
        static let quietHours = "tonic.maintenance.quietHours"
        static let lastRun = "tonic.maintenance.lastRunDate"
        static let lastSummary = "tonic.maintenance.lastSummary"
    }

    var cadence: MaintenanceCadence {
        didSet {
            UserDefaults.standard.set(cadence.rawValue, forKey: Keys.cadence)
            configureTimer()
        }
    }

    /// When enabled, scheduled runs are deferred out of 22:00–08:00.
    var respectQuietHours: Bool {
        didSet { UserDefaults.standard.set(respectQuietHours, forKey: Keys.quietHours) }
    }

    private(set) var lastRunDate: Date? {
        didSet { UserDefaults.standard.set(lastRunDate, forKey: Keys.lastRun) }
    }

    private(set) var lastRunSummary: String? {
        didSet { UserDefaults.standard.set(lastRunSummary, forKey: Keys.lastSummary) }
    }

    private(set) var isRunning = false

    private var timer: DispatchSourceTimer?
    private var activationObserver: NSObjectProtocol?

    private init() {
        cadence = MaintenanceCadence(
            rawValue: UserDefaults.standard.string(forKey: Keys.cadence) ?? ""
        ) ?? .off
        respectQuietHours = UserDefaults.standard.object(forKey: Keys.quietHours) as? Bool ?? true
        lastRunDate = UserDefaults.standard.object(forKey: Keys.lastRun) as? Date
        lastRunSummary = UserDefaults.standard.string(forKey: Keys.lastSummary)
    }

    // MARK: - Lifecycle

    /// Called once from app launch; re-arms whenever cadence changes.
    func start() {
        configureTimer()
        if activationObserver == nil {
            activationObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    await MaintenanceScheduler.shared.runIfDue()
                }
            }
        }
        Task { await runIfDue() }
    }

    private func configureTimer() {
        timer?.cancel()
        timer = nil
        guard cadence.interval != nil else { return }

        // Hourly tick; runIfDue applies the real cadence + quiet-hours rules.
        let source = DispatchSource.makeTimerSource(queue: .main)
        source.schedule(deadline: .now() + 3600, repeating: 3600, leeway: .seconds(300))
        source.setEventHandler {
            Task { @MainActor in
                await MaintenanceScheduler.shared.runIfDue()
            }
        }
        source.resume()
        timer = source
    }

    // MARK: - Run rules

    func isDue(now: Date = Date()) -> Bool {
        guard let interval = cadence.interval else { return false }
        if respectQuietHours, Self.isQuietHour(now: now) { return false }
        guard let last = lastRunDate else { return true }
        return now.timeIntervalSince(last) >= interval
    }

    nonisolated static func isQuietHour(now: Date = Date()) -> Bool {
        let hour = Calendar.current.component(.hour, from: now)
        return hour >= 22 || hour < 8
    }

    func runIfDue() async {
        guard isDue(), !isRunning else { return }
        await runNow()
    }

    /// Scan, filter to the auto-safe policy, clean, notify. Never prompts:
    /// on the Store build without usable scopes it simply skips.
    func runNow() async {
        guard !isRunning else { return }

        if BuildCapabilities.current.requiresScopeAccess,
           AccessBroker.shared.activeScopes.isEmpty {
            return
        }

        isRunning = true
        defer { isRunning = false }

        let engine = SmartCareEngine()
        let result = await engine.runSmartCareScan { _ in }

        // Auto-clean policy: safe, runnable, smart-selected, and NEVER personal.
        let items = result.domainResults.values
            .flatMap(\.items)
            .filter {
                $0.safeToRun && $0.action.isRunnable && $0.isSmartSelected
                    && $0.dataClass == .systemJunk
            }

        guard !items.isEmpty else {
            lastRunDate = Date()
            lastRunSummary = "Nothing needed cleaning."
            return
        }

        let store = SmartCareSessionStore()
        let summary = await store.performRun(
            items: items,
            title: "Scheduled Maintenance",
            progressUpdate: { _ in }
        )

        lastRunDate = Date()
        let freed = ByteCountFormatter.string(fromByteCount: summary.spaceFreed, countStyle: .file)
        lastRunSummary = "Freed \(freed) · \(summary.tasksRun) tasks"

        ActivityLogStore.shared.record(ActivityEvent(
            category: .clean,
            title: "Scheduled maintenance completed",
            detail: lastRunSummary ?? "",
            impact: summary.spaceFreed > 500 * 1024 * 1024 ? .medium : .low
        ))

        NotificationManager.shared.sendNotification(
            title: "Maintenance complete",
            body: "Freed \(freed) across \(summary.tasksRun) tasks. Personal files were not touched.",
            thresholdId: "maintenance",
            category: NotificationDelegate.maintenanceDoneCategory
        )
    }
}
