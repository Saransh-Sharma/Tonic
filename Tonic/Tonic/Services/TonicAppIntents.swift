//
//  TonicAppIntents.swift
//  Tonic
//
//  Shortcuts / Spotlight integration. Three intents that map to Tonic's most
//  automatable actions: run a Smart Scan, empty the Trash, and read free
//  space. No new target needed — AppIntents compile into the app itself.
//

import AppIntents
import Foundation

// MARK: - Run Smart Scan

struct RunSmartScanIntent: AppIntent {
    static let title: LocalizedStringResource = "Run Smart Scan"
    static let description = IntentDescription(
        "Opens Tonic and starts a Smart Scan of junk files, performance items, and apps."
    )
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .runSmartScanCommand, object: nil)
        return .result()
    }
}

// MARK: - Empty Trash

struct EmptyTrashIntent: AppIntent {
    static let title: LocalizedStringResource = "Empty Trash"
    static let description = IntentDescription(
        "Empties the Trash and reports how much space was freed."
    )

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let result = await FileOperations.shared.emptyTrash()
        let message = result.filesProcessed == 0
            ? "Trash was already empty."
            : "Freed \(ByteCountFormatter.string(fromByteCount: result.bytesFreed, countStyle: .file))."
        return .result(value: message)
    }
}

// MARK: - Get Free Space

struct GetFreeSpaceIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Free Disk Space"
    static let description = IntentDescription(
        "Returns the available space on the startup disk."
    )

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let values = try URL(fileURLWithPath: "/").resourceValues(
            forKeys: [.volumeAvailableCapacityForImportantUsageKey]
        )
        let available = values.volumeAvailableCapacityForImportantUsage ?? 0
        return .result(value: ByteCountFormatter.string(fromByteCount: available, countStyle: .file))
    }
}

// MARK: - Shortcuts provider

struct TonicShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RunSmartScanIntent(),
            phrases: ["Run a smart scan with \(.applicationName)"],
            shortTitle: "Smart Scan",
            systemImageName: "sparkles"
        )
        AppShortcut(
            intent: EmptyTrashIntent(),
            phrases: ["Empty the trash with \(.applicationName)"],
            shortTitle: "Empty Trash",
            systemImageName: "trash"
        )
        AppShortcut(
            intent: GetFreeSpaceIntent(),
            phrases: ["How much free space with \(.applicationName)"],
            shortTitle: "Free Space",
            systemImageName: "internaldrive"
        )
    }
}
