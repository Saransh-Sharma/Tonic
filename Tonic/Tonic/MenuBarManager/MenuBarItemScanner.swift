//
//  MenuBarItemScanner.swift
//  Tonic
//
//  Discovers third-party menu bar items via CGWindowList metadata. Uses
//  `.optionAll` (not on-screen-only) because collapsed items are pushed past
//  the screen edge and vanish from the on-screen list.
//

import AppKit
import os

@MainActor
@Observable
public final class MenuBarItemScanner {

    private let logger = Logger(subsystem: "com.tonic.app", category: "MenuBarItemScanner")

    /// Discovered items, sorted left→right, classified into sections.
    public private(set) var items: [MenuBarItemInfo] = []
    /// When the last scan ran (drives the "updated Xs ago" caption).
    public private(set) var lastScanDate: Date?

    /// Injected by `MenuBarManager` so classification can compare against the
    /// live separator window positions.
    var classify: (([MenuBarItemInfo]) -> [MenuBarItemInfo])?
    var onItemsChanged: (([MenuBarItemInfo]) -> Void)?

    private var timer: Timer?
    private var workspaceObservers: [NSObjectProtocol] = []

    /// Poll only while the management UI is visible — app launch/quit events
    /// and explicit expand/collapse trigger scans the rest of the time.
    public func setActive(_ active: Bool) {
        if active {
            scanNow()
            guard timer == nil else { return }
            timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
                Task { @MainActor [weak self] in self?.scanNow() }
            }
        } else {
            timer?.invalidate()
            timer = nil
        }
    }

    /// Launch/termination observation is tied to management, not to whether
    /// an editor happens to be visible. Polling remains editor-only.
    public func setManagementEnabled(_ enabled: Bool) {
        enabled ? observeWorkspaceIfNeeded() : removeWorkspaceObservers()
    }

    public func scanNow() {
        let ownPID = pid_t(ProcessInfo.processInfo.processIdentifier)
        let raw = (CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]]) ?? []

        var parsed = raw.compactMap { MenuBarItemClassifier.parseWindowInfo($0, ownPID: ownPID) }

        // Status items mirror once per display; with the primary-band y-filter
        // most duplicates are gone already — drop exact leftovers by owner+frame.
        var seen = Set<String>()
        parsed = parsed.filter { item in
            let key = "\(item.ownerPID)-\(item.frame.minX)-\(item.frame.width)"
            return seen.insert(key).inserted
        }

        parsed.sort { $0.frame.minX < $1.frame.minX }

        if let classify {
            parsed = classify(parsed)
        }

        lastScanDate = Date()
        if parsed != items {
            items = parsed
            onItemsChanged?(parsed)
            logger.debug("Menu bar scan: \(parsed.count) items")
        }
    }

    private func observeWorkspaceIfNeeded() {
        guard workspaceObservers.isEmpty else { return }
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification,
                     NSWorkspace.didTerminateApplicationNotification] {
            workspaceObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { _ in
                // Give the app a beat to create/remove its status item.
                Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    self?.scanNow()
                }
            })
        }
    }

    private func removeWorkspaceObservers() {
        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers.forEach { center.removeObserver($0) }
        workspaceObservers.removeAll()
    }
}
