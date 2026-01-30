//
//  WidgetRefreshScheduler.swift
//  Tonic
//
//  Unified refresh scheduler that replaces per-widget timers
//  Task ID: fn-5-v8r.2
//

import Foundation
import AppKit

/// Unified refresh scheduler that replaces per-widget timers
/// Follows Stats Master's Repeater pattern but uses Swift Concurrency
@Observable
@MainActor
final class WidgetRefreshScheduler {
    static let shared = WidgetRefreshScheduler()

    private var updateTask: Task<Void, Never>?
    private let readerManager = WidgetReaderManager.shared
    private var currentInterval: TimeInterval = 2.0
    private var isMonitoring = false

    // App lifecycle observation
    private var observers: [NSObjectProtocol] = []

    private init() {
        setupAppLifecycleObservers()
    }

    deinit {
        stopMonitoring()
        removeObservers()
    }

    /// Start periodic refresh monitoring
    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        updateTask = Task { [weak self] in
            await self?.refreshLoop()
        }
    }

    /// Stop refresh monitoring
    func stopMonitoring() {
        isMonitoring = false
        updateTask?.cancel()
        updateTask = nil
    }

    /// Update refresh interval
    /// - Parameter interval: New interval in seconds (1, 2, 3, 5, 10, 15, 30, 60)
    func updateInterval(_ interval: TimeInterval) {
        currentInterval = interval
        // Restart with new interval if monitoring
        if isMonitoring {
            stopMonitoring()
            startMonitoring()
        }
    }

    // MARK: - Private

    private func refreshLoop() async {
        while !Task.isCancelled && isMonitoring {
            await readerManager.refreshReaders()

            // Sleep for current interval
            do {
                try? await Task.sleep(nanoseconds: UInt64(currentInterval * 1_000_000_000))
            } catch {
                // Task cancelled - exit loop
                break
            }
        }
    }

    private func setupAppLifecycleObservers() {
        let nc = NSWorkspace.shared.notificationCenter

        // Suspend when app hides
        let hideObserver = nc.addObserver(forName: NSWorkspace.didHideApplicationNotification,
                                          object: nil,
                                          queue: .main) { [weak self] _ in
            self?.stopMonitoring()
        }
        observers.append(hideObserver)

        // Resume when app shows
        let unhideObserver = nc.addObserver(forName: NSWorkspace.didUnhideApplicationNotification,
                                            object: nil,
                                            queue: .main) { [weak self] _ in
            self?.startMonitoring()
        }
        observers.append(unhideObserver)

        // Suspend when system sleeps
        let sleepObserver = nc.addObserver(forName: NSWorkspace.screensDidSleepNotification,
                                          object: nil,
                                          queue: .main) { [weak self] _ in
            self?.stopMonitoring()
        }
        observers.append(sleepObserver)

        // Resume when system wakes
        let wakeObserver = nc.addObserver(forName: NSWorkspace.screensDidWakeNotification,
                                         object: nil,
                                         queue: .main) { [weak self] _ in
            self?.startMonitoring()
        }
        observers.append(wakeObserver)
    }

    private func removeObservers() {
        let nc = NSWorkspace.shared.notificationCenter
        observers.forEach { nc.removeObserver($0) }
        observers.removeAll()
    }
}
