//
//  ProcessExplorerView.swift
//  Tonic
//
//  Live process table on the signature near-black console: PID, name, CPU%,
//  memory in mono columns, sortable, with a polite SIGTERM behind a
//  confirmation. Sampling runs only while the view is on screen.
//

import SwiftUI

struct ProcessExplorerView: View {

    private enum SortKey: String, CaseIterable {
        case cpu = "CPU"
        case memory = "MEM"
    }

    @State private var processes: [ProcessUsage] = []
    @State private var sortKey: SortKey = .cpu
    @State private var confirmKill: ProcessUsage?
    @State private var killMessage: String?
    @State private var timer: Timer?

    private let rowLimit = 12

    var body: some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.sm) {
            HStack(spacing: TonicDS.Space.sm) {
                MonoLabel("Processes")
                Spacer()
                ForEach(SortKey.allCases, id: \.self) { key in
                    FilterPill(title: key.rawValue, isActive: sortKey == key) {
                        sortKey = key
                        resort()
                    }
                }
            }

            MonitoringConsole {
                VStack(alignment: .leading, spacing: 0) {
                    headerRow
                    if processes.isEmpty {
                        Text("Sampling…")
                            .tonicType(.monoLabel)
                            .foregroundStyle(TonicDS.Colors.onDarkMuted)
                            .padding(.vertical, TonicDS.Space.sm)
                    } else {
                        ForEach(processes.prefix(rowLimit)) { process in
                            processRow(process)
                        }
                    }
                }
            }

            if let killMessage {
                Text(killMessage)
                    .tonicType(.caption)
                    .foregroundStyle(TonicDS.Colors.textMuted)
            }
        }
        .onAppear(perform: startSampling)
        .onDisappear(perform: stopSampling)
        .alert(
            "Quit \(confirmKill?.name ?? "process")?",
            isPresented: Binding(get: { confirmKill != nil }, set: { if !$0 { confirmKill = nil } })
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Quit Process", role: .destructive) {
                if let process = confirmKill { kill(process) }
            }
        } message: {
            Text("Sends a polite quit request (SIGTERM). Unsaved work in that process may be lost.")
        }
    }

    // MARK: - Rows

    private var headerRow: some View {
        HStack(spacing: TonicDS.Space.md) {
            Text("PID").frame(width: 52, alignment: .trailing)
            Text("NAME").frame(maxWidth: .infinity, alignment: .leading)
            Text("CPU").frame(width: 56, alignment: .trailing)
            Text("MEM").frame(width: 72, alignment: .trailing)
            Color.clear.frame(width: 40)
        }
        .tonicType(.monoLabel)
        .foregroundStyle(TonicDS.Colors.onDarkMuted)
        .padding(.bottom, TonicDS.Space.xs)
    }

    private func processRow(_ process: ProcessUsage) -> some View {
        let cpu = process.cpuUsage ?? 0
        return HStack(spacing: TonicDS.Space.md) {
            Text("\(process.id)")
                .frame(width: 52, alignment: .trailing)
                .foregroundStyle(TonicDS.Colors.onDarkMuted)
            Text(process.name)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
                .foregroundStyle(TonicDS.Colors.onDark)
            Text(String(format: "%.1f%%", cpu))
                .frame(width: 56, alignment: .trailing)
                .foregroundStyle(TonicDS.status(forFraction: min(cpu / 100, 1)))
            Text(Self.bytes(process.memoryUsage ?? 0))
                .frame(width: 72, alignment: .trailing)
                .foregroundStyle(TonicDS.Colors.onDark)
            Button {
                confirmKill = process
            } label: {
                Image(systemName: "xmark.circle")
                    .foregroundStyle(TonicDS.Colors.onDarkMuted)
            }
            .buttonStyle(.plain)
            .frame(width: 40)
            .accessibilityLabel("Quit \(process.name)")
        }
        .tonicType(.monoLabel)
        .monospacedDigit()
        .padding(.vertical, 3)
    }

    // MARK: - Sampling

    private func startSampling() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
            Task { @MainActor in refresh() }
        }
    }

    private func stopSampling() {
        timer?.invalidate()
        timer = nil
    }

    private func refresh() {
        Task.detached(priority: .utility) {
            let sampled = ProcessSampler.shared.topByCPU(limit: 40)
            await MainActor.run {
                processes = sampled
                resort()
            }
        }
    }

    private func resort() {
        switch sortKey {
        case .cpu:
            processes.sort { ($0.cpuUsage ?? 0) > ($1.cpuUsage ?? 0) }
        case .memory:
            processes.sort { ($0.memoryUsage ?? 0) > ($1.memoryUsage ?? 0) }
        }
    }

    // MARK: - Kill

    private func kill(_ process: ProcessUsage) {
        switch ProcessSampler.shared.terminate(pid: process.id) {
        case .terminated:
            killMessage = "Asked \(process.name) to quit."
        case .notPermitted:
            killMessage = "\(process.name) belongs to another user or the system — not permitted."
        case .failed(let code):
            killMessage = "Couldn't quit \(process.name) (errno \(code))."
        }
        confirmKill = nil
    }

    private static func bytes(_ value: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(value))
    }
}
