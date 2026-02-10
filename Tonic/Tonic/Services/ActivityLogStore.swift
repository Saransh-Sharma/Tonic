//
//  ActivityLogStore.swift
//  Tonic
//
//  Persistent activity log store
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class ActivityLogStore {
    static let shared = ActivityLogStore()

    private enum Keys {
        static let log = "tonic.activity.log"
        static let hasLoggedInstall = "tonic.activity.hasLoggedInstall"
        static let lastLoggedVersion = "tonic.activity.lastLoggedVersion"
    }

    private let userDefaults: UserDefaults
    private let maxEntries = 200

    private(set) var entries: [ActivityEvent] = []

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        load()
    }

    func record(_ event: ActivityEvent) {
        entries.insert(event, at: 0)
        pruneIfNeeded()
        save()
    }

    func clear() {
        entries.removeAll()
        userDefaults.removeObject(forKey: Keys.log)
    }

    func recordInstallIfNeeded(version: String, build: String) {
        guard !userDefaults.bool(forKey: Keys.hasLoggedInstall) else { return }

        let detail = "Version \(version) (Build \(build))"
        let event = ActivityEvent(
            category: .install,
            title: "Tonic installed",
            detail: detail,
            impact: .low
        )
        record(event)

        userDefaults.set(true, forKey: Keys.hasLoggedInstall)
        userDefaults.set(versionKey(version: version, build: build), forKey: Keys.lastLoggedVersion)
    }

    func recordUpdateIfNeeded(version: String, build: String) {
        guard userDefaults.bool(forKey: Keys.hasLoggedInstall) else { return }

        let current = versionKey(version: version, build: build)
        guard let last = userDefaults.string(forKey: Keys.lastLoggedVersion) else {
            userDefaults.set(current, forKey: Keys.lastLoggedVersion)
            return
        }

        guard last != current else { return }

        let detail = "From \(last) -> \(current)"
        let event = ActivityEvent(
            category: .update,
            title: "Tonic updated",
            detail: detail,
            impact: .low
        )
        record(event)

        userDefaults.set(current, forKey: Keys.lastLoggedVersion)
    }

    private func versionKey(version: String, build: String) -> String {
        "\(version) (Build \(build))"
    }

    private func load() {
        guard let data = userDefaults.data(forKey: Keys.log) else {
            entries = []
            return
        }

        do {
            let decoded = try JSONDecoder().decode([ActivityEvent].self, from: data)
            entries = decoded.sorted(by: { $0.timestamp > $1.timestamp })
            pruneIfNeeded()
        } catch {
            entries = []
            userDefaults.removeObject(forKey: Keys.log)
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else {
            return
        }
        userDefaults.set(data, forKey: Keys.log)
    }

    private func pruneIfNeeded() {
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
    }
}
