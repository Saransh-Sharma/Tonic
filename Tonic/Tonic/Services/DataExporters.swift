//
//  DataExporters.swift
//  Tonic
//
//  Small, dependency-free exporters: monitoring metrics as CSV and the app
//  inventory as CSV or JSON, delivered through NSSavePanel (sandbox-safe:
//  user-selected write access).
//

import AppKit
import Foundation
import UniformTypeIdentifiers

enum MetricsExporter {

    static func csv(from samples: [ResourceMetricSample]) -> String {
        var lines = ["timestamp,cpu_percent,memory_percent,memory_used_bytes,network_up_bps,network_down_bps,disk_used_percent,disk_read_bps,disk_write_bps"]
        let formatter = ISO8601DateFormatter()
        for sample in samples {
            lines.append([
                formatter.string(from: sample.timestamp),
                String(format: "%.2f", sample.cpuPercent),
                String(format: "%.2f", sample.memoryPercent),
                "\(sample.memoryUsedBytes)",
                String(format: "%.0f", sample.networkUploadBytesPerSecond),
                String(format: "%.0f", sample.networkDownloadBytesPerSecond),
                String(format: "%.2f", sample.diskUsedPercent),
                String(format: "%.0f", sample.diskReadBytesPerSecond),
                String(format: "%.0f", sample.diskWriteBytesPerSecond),
            ].joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    @MainActor
    static func exportWithPanel(samples: [ResourceMetricSample], rangeName: String) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "tonic-metrics-\(rangeName.lowercased()).csv"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? csv(from: samples).write(to: url, atomically: true, encoding: .utf8)
    }
}

enum AppInventoryExporter {

    static func csv(from apps: [AppMetadata]) -> String {
        var lines = ["name,bundle_identifier,version,path,total_size_bytes,last_used,category,item_type"]
        let formatter = ISO8601DateFormatter()
        for app in apps {
            let name = app.name.replacingOccurrences(of: "\"", with: "\"\"")
            lines.append([
                "\"\(name)\"",
                app.bundleIdentifier,
                app.version ?? "",
                "\"\(app.path.path)\"",
                "\(app.totalSize)",
                app.lastUsed.map(formatter.string(from:)) ?? "",
                app.category.rawValue,
                app.itemType,
            ].joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    static func json(from apps: [AppMetadata]) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(apps)
    }

    @MainActor
    static func exportWithPanel(apps: [AppMetadata]) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText, .json]
        panel.nameFieldStringValue = "tonic-apps.csv"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if url.pathExtension.lowercased() == "json" {
            try? json(from: apps)?.write(to: url)
        } else {
            try? csv(from: apps).write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
