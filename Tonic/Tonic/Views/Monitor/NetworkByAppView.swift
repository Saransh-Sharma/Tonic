//
//  NetworkByAppView.swift
//  Tonic
//
//  Per-app network bandwidth console (direct build only). First sample
//  establishes the baseline; rates appear from the second pass on — the view
//  says so instead of showing zeros as if they were truth.
//

import SwiftUI

#if !TONIC_STORE

struct NetworkByAppView: View {

    @State private var rows: [ProcessBandwidth] = []
    @State private var hasBaseline = false
    @State private var timer: Timer?

    var body: some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.sm) {
            MonoLabel("Network by app")
            MonitoringConsole {
                VStack(alignment: .leading, spacing: 0) {
                    headerRow
                    if !hasBaseline {
                        Text("Measuring baseline…")
                            .tonicType(.monoLabel)
                            .foregroundStyle(TonicDS.Colors.onDarkMuted)
                            .padding(.vertical, TonicDS.Space.sm)
                    } else if rows.isEmpty {
                        Text("No network activity right now.")
                            .tonicType(.monoLabel)
                            .foregroundStyle(TonicDS.Colors.onDarkMuted)
                            .padding(.vertical, TonicDS.Space.sm)
                    } else {
                        ForEach(rows) { row in
                            bandwidthRow(row)
                        }
                    }
                }
            }
        }
        .onAppear(perform: start)
        .onDisappear(perform: stop)
    }

    private var headerRow: some View {
        HStack(spacing: TonicDS.Space.md) {
            Text("APP").frame(maxWidth: .infinity, alignment: .leading)
            Text("↓").frame(width: 84, alignment: .trailing)
            Text("↑").frame(width: 84, alignment: .trailing)
        }
        .tonicType(.monoLabel)
        .foregroundStyle(TonicDS.Colors.onDarkMuted)
        .padding(.bottom, TonicDS.Space.xs)
    }

    private func bandwidthRow(_ row: ProcessBandwidth) -> some View {
        HStack(spacing: TonicDS.Space.md) {
            Text(row.name)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
                .foregroundStyle(TonicDS.Colors.onDark)
            Text(Self.rate(row.bytesInPerSecond))
                .frame(width: 84, alignment: .trailing)
                .foregroundStyle(row.bytesInPerSecond > 0 ? TonicDS.Colors.statusInfo : TonicDS.Colors.onDarkMuted)
            Text(Self.rate(row.bytesOutPerSecond))
                .frame(width: 84, alignment: .trailing)
                .foregroundStyle(row.bytesOutPerSecond > 0 ? TonicDS.Colors.statusInfo : TonicDS.Colors.onDarkMuted)
        }
        .tonicType(.monoLabel)
        .monospacedDigit()
        .padding(.vertical, 3)
    }

    // MARK: - Sampling

    private func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
            Task { @MainActor in refresh() }
        }
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func refresh() {
        Task {
            let sampled = await NetworkPerProcessSampler.shared.sample()
            await MainActor.run {
                if hasBaseline {
                    // Hide idle rows once real rates exist.
                    rows = sampled.filter { $0.bytesInPerSecond + $0.bytesOutPerSecond > 0 }
                } else {
                    hasBaseline = !sampled.isEmpty
                }
            }
        }
    }

    private static func rate(_ value: Double) -> String {
        guard value >= 1 else { return "0" }
        return ByteCountFormatter.string(fromByteCount: Int64(value), countStyle: .binary) + "/s"
    }
}

#endif
