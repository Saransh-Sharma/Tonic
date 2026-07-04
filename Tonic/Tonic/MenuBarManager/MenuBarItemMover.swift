//
//  MenuBarItemMover.swift
//  Tonic
//
//  Moves third-party menu bar items between sections by simulating the
//  ⌘-drag a user would perform (the Ice technique — macOS offers no API to
//  reorder other apps' status items). Requires Accessibility trust to post
//  events. Direct build only: synthetic event posting is not
//  sandbox-compatible.
//

#if !TONIC_STORE

import AppKit
import ApplicationServices
import os

@MainActor
final class MenuBarItemMover {

    enum MoveError: LocalizedError {
        case notTrusted
        case systemItem
        case separatorMissing
        case itemNotFound
        case verifyFailed
        case busy

        var errorDescription: String? {
            switch self {
            case .notTrusted: return "Accessibility permission is required to move menu bar items."
            case .systemItem: return "macOS lays out system items itself — they can't be moved."
            case .separatorMissing: return "Enable menu bar management first."
            case .itemNotFound: return "That item is no longer in the menu bar."
            case .verifyFailed: return "The item didn't take the new position. Try ⌘-dragging it manually."
            case .busy: return "Another item is still being moved."
            }
        }
    }

    private let logger = Logger(subsystem: "com.tonic.app", category: "MenuBarItemMover")

    private(set) var isMoving = false

    /// True when Tonic can post synthetic events (Accessibility trust).
    /// Calling with `promptIfNeeded` shows the system prompt once.
    static func ensureEventPostingAccess(promptIfNeeded: Bool = true) -> Bool {
        if AXIsProcessTrusted() { return true }
        if CGPreflightPostEventAccess() { return true }
        return promptIfNeeded ? CGRequestPostEventAccess() : false
    }

    /// ⌘-drag `item` across the relevant separator so it lands in `target`.
    func move(item: MenuBarItemInfo, to target: MenuBarSection) async throws {
        guard !isMoving else { throw MoveError.busy }
        guard !item.isSystemControlled else { throw MoveError.systemItem }
        guard Self.ensureEventPostingAccess() else { throw MoveError.notTrusted }

        isMoving = true
        defer { isMoving = false }

        let manager = MenuBarManager.shared

        // The always-hidden section needs its separator on the bar first.
        if target == .alwaysHidden, !MenuBarManagerSettingsStore.shared.settings.alwaysHiddenSectionEnabled {
            MenuBarManagerSettingsStore.shared.settings.alwaysHiddenSectionEnabled = true
            try? await Task.sleep(nanoseconds: 350_000_000)
        }

        // Items must be on screen to drag.
        let wasExpanded = manager.isExpanded
        manager.expand(showAlwaysHidden: true)
        try await settleAndRescan(manager)

        guard let fresh = freshItem(matching: item, in: manager) else {
            if !wasExpanded { manager.collapse() }
            throw MoveError.itemNotFound
        }
        if fresh.section == target {
            if !wasExpanded { manager.collapse() }
            return
        }

        try await performDrag(item: fresh, to: target, manager: manager, overshoot: 14)
        try await settleAndRescan(manager)

        var moved = freshItem(matching: item, in: manager)?.section == target
        if !moved, let again = freshItem(matching: item, in: manager) {
            logger.info("Move verify failed for \(item.ownerName), retrying with overshoot")
            try await performDrag(item: again, to: target, manager: manager, overshoot: 40)
            try await settleAndRescan(manager)
            moved = freshItem(matching: item, in: manager)?.section == target
        }

        if !wasExpanded { manager.collapse() }
        guard moved else { throw MoveError.verifyFailed }
        logger.info("Moved \(item.ownerName) to \(target.rawValue)")
    }

    /// Sequential moves for preset apply. Expands once up front so individual
    /// moves don't flap the bar. Returns per-key success.
    func applyLayout(_ layout: [String: MenuBarSection]) async -> [String: Bool] {
        let manager = MenuBarManager.shared
        var results: [String: Bool] = [:]

        guard Self.ensureEventPostingAccess() else {
            layout.keys.forEach { results[$0] = false }
            return results
        }

        let wasExpanded = manager.isExpanded
        manager.expand(showAlwaysHidden: true)
        try? await settleAndRescan(manager)

        for (key, target) in layout {
            guard let item = manager.items.first(where: { $0.stableKey == key }) else {
                results[key] = false
                continue
            }
            if item.section == target {
                results[key] = true
                continue
            }
            do {
                try await move(item: item, to: target)
                results[key] = true
            } catch {
                logger.warning("Preset move failed for \(key): \(error.localizedDescription)")
                results[key] = false
            }
        }

        if !wasExpanded { manager.collapse() }
        return results
    }

    // MARK: - Drag mechanics

    private func freshItem(matching item: MenuBarItemInfo, in manager: MenuBarManager) -> MenuBarItemInfo? {
        manager.items.first { $0.windowID == item.windowID }
            ?? manager.items.first { $0.stableKey == item.stableKey }
    }

    private func settleAndRescan(_ manager: MenuBarManager) async throws {
        try? await Task.sleep(nanoseconds: 450_000_000)
        manager.refreshScan()
        try? await Task.sleep(nanoseconds: 150_000_000)
    }

    private func performDrag(
        item: MenuBarItemInfo,
        to target: MenuBarSection,
        manager: MenuBarManager,
        overshoot: CGFloat
    ) async throws {
        let frames = manager.separatorWindowFrames()

        // NSWindow frames share the x axis with CG global coordinates; only y
        // is flipped, and the drag stays at the item's own menu bar height.
        let destinationX: CGFloat
        switch target {
        case .visible:
            guard let sep = frames.separator else { throw MoveError.separatorMissing }
            destinationX = sep.maxX + overshoot
        case .hidden:
            guard let sep = frames.separator else { throw MoveError.separatorMissing }
            destinationX = sep.minX - overshoot
        case .alwaysHidden:
            guard let always = frames.alwaysHidden else { throw MoveError.separatorMissing }
            destinationX = always.minX - overshoot
        }

        let source = CGPoint(x: item.frame.midX, y: item.frame.midY)
        let destination = CGPoint(x: destinationX, y: item.frame.midY)
        try await postDrag(from: source, to: destination)
    }

    /// ⌘-flagged leftMouseDown → interpolated drags → leftMouseUp.
    private func postDrag(from source: CGPoint, to destination: CGPoint) async throws {
        func post(_ type: CGEventType, at point: CGPoint) {
            let event = CGEvent(mouseEventSource: nil, mouseType: type,
                                mouseCursorPosition: point, mouseButton: .left)
            event?.flags = .maskCommand
            event?.post(tap: .cghidEventTap)
        }

        post(.leftMouseDown, at: source)
        try await Task.sleep(nanoseconds: 60_000_000)

        let steps = 8
        for step in 1...steps {
            let t = CGFloat(step) / CGFloat(steps)
            let point = CGPoint(
                x: source.x + (destination.x - source.x) * t,
                y: source.y + (destination.y - source.y) * t
            )
            post(.leftMouseDragged, at: point)
            try await Task.sleep(nanoseconds: 30_000_000)
        }

        post(.leftMouseUp, at: destination)
    }
}

#endif
