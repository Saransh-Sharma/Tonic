//
//  ActionReceiptStore.swift
//  Tonic
//
//  Shared proof and recovery history used by Home, Organize, Care, and Automate.
//

import Foundation

@MainActor
@Observable
final class ActionReceiptStore {
    static let shared = ActionReceiptStore()

    private let defaults: UserDefaults
    private let key = "tonic.actionReceipts.v1"
    private let maximumReceipts = 100

    private(set) var receipts: [ActionReceipt] = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func record(_ receipt: ActionReceipt) {
        receipts.removeAll { $0.id == receipt.id }
        receipts.insert(receipt, at: 0)
        if receipts.count > maximumReceipts {
            receipts.removeLast(receipts.count - maximumReceipts)
        }
        persist()
    }

    func markRestored(id: UUID, detail: String) {
        guard let existing = receipts.first(where: { $0.id == id }) else { return }
        record(ActionReceipt(
            id: existing.id,
            tool: existing.tool,
            title: existing.title,
            detail: detail,
            status: .restored,
            startedAt: existing.startedAt,
            affectedItems: existing.affectedItems,
            impact: existing.impact,
            metadata: existing.metadata
        ))
    }

    func removeAll() {
        receipts.removeAll()
        defaults.removeObject(forKey: key)
    }

    private func load() {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([ActionReceipt].self, from: data) else {
            return
        }
        receipts = decoded.sorted { $0.completedAt > $1.completedAt }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(receipts) else { return }
        defaults.set(data, forKey: key)
    }
}
