//
//  HomeInsightsBand.swift
//  Tonic
//
//  "Your Mac this week" — a quiet bento of trend facts: health-score
//  sparkline, space recovered in the last seven days, and the last scheduled
//  maintenance run. Every tile is honest: tiles without data say so or stay
//  hidden rather than inventing numbers.
//

import SwiftUI

struct HomeInsightsBand: View {

    /// Recomputed on appear; these stores are cheap file-backed reads.
    @State private var scores: [HealthScoreSample] = []
    @State private var recoveredThisWeek: Int64 = 0
    @State private var lastMaintenance: (date: Date, summary: String?)?

    var body: some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.md) {
            MonoLabel("Your Mac this week")
            TonicBentoGrid(minTileWidth: 200) {
                scoreTile
                recoveredTile
                maintenanceTile
            }
        }
        .onAppear(perform: refresh)
    }

    private func refresh() {
        scores = HealthScoreHistoryStore.shared.recentScores(days: 30)

        let cutoff = Date().addingTimeInterval(-7 * 24 * 3600)
        recoveredThisWeek = CleanupHistoryStore.shared.batches
            .filter { $0.date >= cutoff }
            .flatMap(\.entries)
            .reduce(0) { $0 + $1.size }

        if let date = MaintenanceScheduler.shared.lastRunDate {
            lastMaintenance = (date, MaintenanceScheduler.shared.lastRunSummary)
        } else {
            lastMaintenance = nil
        }
    }

    // MARK: - Tiles

    private var scoreTile: some View {
        DataCard(lift: false) {
            VStack(alignment: .leading, spacing: TonicDS.Space.sm) {
                MonoLabel("HEALTH SCORE")
                if let latest = scores.last {
                    Metric("\(latest.score)", color: TonicDS.status(forFraction: 1 - Double(latest.score) / 100))
                        .contentTransition(.numericText())
                    if scores.count >= 2 {
                        NetworkSparklineChart(
                            data: scores.map { Double($0.score) },
                            color: TonicDS.status(forFraction: 1 - Double(latest.score) / 100),
                            height: 28
                        )
                    } else {
                        Text("Trend appears after another scan.")
                            .tonicType(.micro).foregroundStyle(TonicDS.Colors.textMuted)
                    }
                } else {
                    Text("Run a Smart Scan to start tracking.")
                        .tonicType(.caption).foregroundStyle(TonicDS.Colors.textMuted)
                }
            }
        }
    }

    private var recoveredTile: some View {
        DataCard(lift: false) {
            VStack(alignment: .leading, spacing: TonicDS.Space.sm) {
                MonoLabel("RECOVERED · 7 DAYS")
                if recoveredThisWeek > 0 {
                    Metric(Self.bytes(recoveredThisWeek), color: TonicDS.Colors.textPrimary)
                        .contentTransition(.numericText())
                    Text("Across cleanups and maintenance runs.")
                        .tonicType(.micro).foregroundStyle(TonicDS.Colors.textMuted)
                } else {
                    Metric("0 MB", color: TonicDS.Colors.textMuted)
                    Text("Nothing cleaned this week.")
                        .tonicType(.micro).foregroundStyle(TonicDS.Colors.textMuted)
                }
            }
        }
    }

    private var maintenanceTile: some View {
        DataCard(lift: false) {
            VStack(alignment: .leading, spacing: TonicDS.Space.sm) {
                MonoLabel("LAST MAINTENANCE")
                if let lastMaintenance {
                    Text(Self.relative(lastMaintenance.date))
                        .tonicType(.featureHeading)
                        .foregroundStyle(TonicDS.Colors.textPrimary)
                    Text(lastMaintenance.summary ?? "Completed.")
                        .tonicType(.micro).foregroundStyle(TonicDS.Colors.textMuted)
                        .lineLimit(1)
                } else if MaintenanceScheduler.shared.cadence == .off {
                    Text("Off")
                        .tonicType(.featureHeading)
                        .foregroundStyle(TonicDS.Colors.textMuted)
                    Text("Enable scheduled care in Settings → Maintenance.")
                        .tonicType(.micro).foregroundStyle(TonicDS.Colors.textMuted)
                } else {
                    Text("Scheduled")
                        .tonicType(.featureHeading)
                        .foregroundStyle(TonicDS.Colors.textPrimary)
                    Text("First run is coming up.")
                        .tonicType(.micro).foregroundStyle(TonicDS.Colors.textMuted)
                }
            }
        }
    }

    // MARK: - Formatting

    private static func bytes(_ value: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: value, countStyle: .file)
    }

    private static func relative(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
