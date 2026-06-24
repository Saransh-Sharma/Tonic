//
//  RecentlyCleanedView.swift
//  Tonic
//
//  History of Smart Care cleanups with per-item restore for recoverable
//  (trashed) personal files. Permanent system-junk removals are shown as
//  history only.
//

import SwiftUI
import AppKit

struct RecentlyCleanedView: View {
    @State private var history = CleanupHistoryStore.shared
    @State private var restoringBatchID: UUID?
    @State private var purgeTarget: CleanupHistoryBatch?

    var body: some View {
        TonicThemeProvider(world: .cleanupGreen) {
            ZStack {
                WorldCanvasBackground()

                VStack(spacing: 0) {
                    PageHeader(
                        title: "Recently Cleaned",
                        subtitle: headerSubtitle,
                        trailing: history.batches.isEmpty ? nil : AnyView(headerTrailing)
                    )
                    .padding(.horizontal, TonicSpaceToken.three)
                    .padding(.top, TonicSpaceToken.two)

                    if history.batches.isEmpty {
                        Spacer()
                        EmptyStatePanel(
                            icon: "clock.arrow.circlepath",
                            title: "Nothing cleaned yet",
                            message: "After a Smart Clean, removed items appear here. Personal files moved to the Trash can be restored; reclaimed system junk is listed for your records."
                        )
                        .padding(.horizontal, TonicSpaceToken.three)
                        Spacer()
                    } else {
                        ScrollView {
                            VStack(spacing: TonicSpaceToken.three) {
                                ForEach(history.batches) { batch in
                                    batchCard(batch)
                                }
                            }
                            .padding(.horizontal, TonicSpaceToken.three)
                            .padding(.top, TonicSpaceToken.two)
                            .padding(.bottom, TonicSpaceToken.four)
                        }
                    }
                }
            }
        }
        .onAppear { history.prune() }
        .confirmationDialog(
            "Permanently remove these items from the Trash?",
            isPresented: Binding(get: { purgeTarget != nil }, set: { if !$0 { purgeTarget = nil } }),
            presenting: purgeTarget
        ) { batch in
            Button("Empty \(batch.formattedTotalSize) from Trash", role: .destructive) {
                purge(batch: batch)
            }
            Button("Cancel", role: .cancel) { purgeTarget = nil }
        } message: { _ in
            Text("This reclaims the space now and can't be undone. Items you haven't emptied stay restorable in the Trash.")
        }
    }

    private var headerSubtitle: String {
        let recoverable = history.batches.reduce(0) { $0 + $1.recoverableEntries.count }
        if recoverable == 0 {
            return "Cleanup history"
        }
        return "\(recoverable) item\(recoverable == 1 ? "" : "s") can be restored from the Trash"
    }

    private var headerTrailing: some View {
        TertiaryGhostButton(title: "Clear History") {
            history.clear()
        }
    }

    // MARK: - Batch Card

    private func batchCard(_ batch: CleanupHistoryBatch) -> some View {
        VStack(alignment: .leading, spacing: TonicSpaceToken.two) {
            HStack(alignment: .firstTextBaseline, spacing: TonicSpaceToken.two) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(batch.title)
                        .font(TonicTypeToken.caption.weight(.semibold))
                        .foregroundStyle(TonicTextToken.primary)
                    Text("\(Self.dateFormatter.string(from: batch.date)) · \(batch.formattedTotalSize) · \(batch.entries.count) item\(batch.entries.count == 1 ? "" : "s")")
                        .font(TonicTypeToken.micro)
                        .foregroundStyle(TonicTextToken.tertiary)
                }

                Spacer()

                if batch.hasRecoverable {
                    if restoringBatchID == batch.id {
                        ProgressView().controlSize(.small)
                    } else {
                        TertiaryGhostButton(title: "Empty from Trash") {
                            purgeTarget = batch
                        }
                        SecondaryPillButton(title: "Restore All") {
                            restore(batch: batch)
                        }
                    }
                }
            }

            VStack(spacing: 0) {
                ForEach(batch.entries) { entry in
                    entryRow(entry)
                    if entry.id != batch.entries.last?.id {
                        Divider().opacity(0.4)
                    }
                }
            }
        }
        .padding(TonicSpaceToken.three)
        .glassSurface(radius: TonicRadiusToken.l)
    }

    private func entryRow(_ entry: CleanupHistoryEntry) -> some View {
        HStack(spacing: TonicSpaceToken.two) {
            Image(systemName: entry.isRestorable ? "arrow.uturn.backward.circle" : "trash.circle")
                .font(.system(size: 15))
                .foregroundStyle(entry.isRestorable ? TonicTextToken.secondary : TonicTextToken.tertiary)

            VStack(alignment: .leading, spacing: 1) {
                Text(entry.fileName)
                    .font(TonicTypeToken.micro.weight(.medium))
                    .foregroundStyle(TonicTextToken.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(statusText(for: entry))
                    .font(TonicTypeToken.micro)
                    .foregroundStyle(TonicTextToken.tertiary)
            }

            Spacer()

            Text(entry.formattedSize)
                .font(TonicTypeToken.micro)
                .foregroundStyle(TonicTextToken.secondary)

            if entry.isRestorable {
                TertiaryGhostButton(title: "Restore") {
                    restore(entry: entry)
                }
            } else if case .trashed = entry.recovery, entry.restoredDate != nil {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, TonicSpaceToken.one)
    }

    private func statusText(for entry: CleanupHistoryEntry) -> String {
        if entry.restoredDate != nil {
            return "Restored · \(entry.category)"
        }
        switch entry.recovery {
        case .trashed:
            return "In Trash · \(entry.category)"
        case .permanent:
            return "Removed · \(entry.category)"
        }
    }

    // MARK: - Actions

    private func restore(batch: CleanupHistoryBatch) {
        restoringBatchID = batch.id
        Task {
            _ = await history.restoreBatch(batch.id)
            await MainActor.run { restoringBatchID = nil }
        }
    }

    private func restore(entry: CleanupHistoryEntry) {
        guard let batch = history.batches.first(where: { $0.entries.contains(where: { $0.id == entry.id }) }) else { return }
        Task {
            _ = await history.restoreEntries([entry.id], in: batch.id)
        }
    }

    private func purge(batch: CleanupHistoryBatch) {
        purgeTarget = nil
        Task { _ = await history.purgeBatch(batch.id) }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
