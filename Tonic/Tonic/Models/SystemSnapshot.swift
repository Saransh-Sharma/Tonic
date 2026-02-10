//
//  SystemSnapshot.swift
//  Tonic
//
//  Snapshot model for Dashboard system specs.
//

import Foundation

struct SystemSnapshot: Sendable, Equatable {
    let deviceDisplayName: String
    let osString: String
    let processorSummary: String
    let memorySummary: String
    let graphicsSummary: String
    let diskSummary: String
    let displaySummary: String
    let modelIdentifier: String
    let modelYear: String?
    let serialNumber: String?
    let uptimeSummary: String

    func serialDisplay(revealed: Bool) -> String {
        guard let serialNumber, !serialNumber.isEmpty else { return "—" }
        guard !revealed else { return serialNumber }
        let suffix = String(serialNumber.suffix(4))
        return "••••••••\(suffix)"
    }

    func exportText(serialRevealed: Bool) -> String {
        var lines: [String] = []
        lines.append(deviceDisplayName)
        lines.append(osString)
        lines.append("")
        lines.append("Processor: \(processorSummary)")
        lines.append("Memory: \(memorySummary)")
        lines.append("Graphics: \(graphicsSummary)")
        lines.append("Disks: \(diskSummary)")
        lines.append("Display: \(displaySummary)")
        lines.append("")
        lines.append("Model identifier: \(modelIdentifier)")
        lines.append("Model year: \(modelYear ?? "—")")
        lines.append("Serial number: \(serialDisplay(revealed: serialRevealed))")
        lines.append("Uptime: \(uptimeSummary)")
        return lines.joined(separator: "\n")
    }
}
