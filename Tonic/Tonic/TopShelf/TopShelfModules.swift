import AppKit
import EventKit
import Foundation

public struct TopShelfSystemHealthModule: TopShelfModule {
    public let descriptor = TopShelfModuleDescriptor(
        id: "system-health", kind: .systemHealth, title: String(localized: "System Health"),
        symbol: "waveform.path.ecg", allowsAmbientPresentation: true
    )

    public init() {}

    public func snapshot(in context: TopShelfPresentationContext) async -> TopShelfModuleSnapshot {
        await MainActor.run {
            let manager = WidgetDataManager.shared
            let cpu = manager.cpuData.totalUsage
            let memory = manager.memoryData.usagePercentage
            let hottest = manager.sensorsData.temperatures.map(\.value).max()
            let warning = cpu >= 90 || memory >= 90 || (hottest ?? 0) >= 90
            let details = hottest.map { String(localized: "Memory \(Int(memory))% · \(Int($0))°C") }
                ?? String(localized: "Memory \(Int(memory))%")
            return TopShelfModuleSnapshot(moduleID: descriptor.id, title: descriptor.title,
                primaryText: String(localized: "CPU \(Int(cpu))%"), secondaryText: details,
                symbol: descriptor.symbol, status: warning ? .attention : .good,
                actions: [.openTonicDestination("monitor")])
        }
    }
}

/// macOS does not provide a public API for reading another application's Now
/// Playing session. The direct build's compatibility-gated adapter can replace
/// this module at runtime; the shared fallback remains explicit and useful.
public struct TopShelfNowPlayingModule: TopShelfModule {
    public let descriptor = TopShelfModuleDescriptor(
        id: "now-playing", kind: .nowPlaying, title: String(localized: "Now Playing"),
        symbol: "play.circle", allowsAmbientPresentation: true
    )

    public init() {}

    public func snapshot(in context: TopShelfPresentationContext) async -> TopShelfModuleSnapshot {
        TopShelfModuleSnapshot(
            moduleID: descriptor.id,
            title: descriptor.title,
            primaryText: String(localized: "No supported playback session"),
            secondaryText: String(localized: "Playback controls appear only when the current macOS build passes Tonic's signed compatibility check."),
            symbol: descriptor.symbol,
            status: .unavailable
        )
    }
}

public struct TopShelfRecommendationsModule: TopShelfModule {
    public let descriptor = TopShelfModuleDescriptor(
        id: "recommendations", kind: .recommendations, title: String(localized: "Recommended"),
        symbol: "sparkles", allowsAmbientPresentation: true
    )

    public init() {}

    public func snapshot(in context: TopShelfPresentationContext) async -> TopShelfModuleSnapshot {
        await MainActor.run {
            let manager = WidgetDataManager.shared
            let cpu = manager.cpuData.totalUsage
            let memory = manager.memoryData.usagePercentage
            if !manager.networkData.isConnected {
                return TopShelfModuleSnapshot(moduleID: descriptor.id, title: descriptor.title,
                    primaryText: String(localized: "Check network recovery"),
                    secondaryText: String(localized: "The live monitor reports no active connection."), symbol: "network.slash",
                    status: .attention, actions: [.openTonicDestination("care")])
            }
            if cpu >= 90 || memory >= 90 {
                return TopShelfModuleSnapshot(moduleID: descriptor.id, title: descriptor.title,
                    primaryText: String(localized: "Inspect system pressure"),
                    secondaryText: String(localized: "CPU \(Int(cpu))% · Memory \(Int(memory))%"), symbol: "waveform.path.ecg",
                    status: .attention, actions: [.openTonicDestination("monitor")])
            }
            return TopShelfModuleSnapshot(moduleID: descriptor.id, title: descriptor.title,
                primaryText: String(localized: "No urgent action"), secondaryText: String(localized: "Tonic will surface evidence-backed actions here."),
                symbol: "checkmark.circle", status: .good)
        }
    }
}

public struct TopShelfWeatherModule: TopShelfModule {
    public let descriptor = TopShelfModuleDescriptor(id: "weather", kind: .weather,
        title: String(localized: "Weather"), symbol: "cloud.sun")
    public init() {}

    public func snapshot(in context: TopShelfPresentationContext) async -> TopShelfModuleSnapshot {
        await MainActor.run {
            let service = WeatherService.shared
            guard let current = service.currentWeather?.current else {
                return TopShelfModuleSnapshot(moduleID: descriptor.id, title: descriptor.title,
                    primaryText: String(localized: "Weather unavailable"), secondaryText: String(localized: "Choose a location in Widgets"),
                    symbol: descriptor.symbol, status: .unavailable,
                    actions: [.refresh(moduleID: descriptor.id)])
            }
            return TopShelfModuleSnapshot(moduleID: descriptor.id, title: descriptor.title,
                primaryText: "\(Int(current.temperature))°", secondaryText: current.locationName,
                symbol: descriptor.symbol, actions: [.refresh(moduleID: descriptor.id)])
        }
    }
}

public struct TopShelfClipboardModule: TopShelfModule {
    public let descriptor = TopShelfModuleDescriptor(id: "clipboard", kind: .clipboard,
        title: String(localized: "Clipboard"), symbol: "clipboard", isSensitive: true)
    public init() {}

    public func snapshot(in context: TopShelfPresentationContext) async -> TopShelfModuleSnapshot {
        guard context.isDeliberateOpen, !context.isAmbient else {
            return TopShelfModuleSnapshot(moduleID: descriptor.id, title: descriptor.title,
                primaryText: String(localized: "Open Top Shelf to preview"), symbol: descriptor.symbol, status: .unavailable)
        }
        return await MainActor.run {
            let value = NSPasteboard.general.string(forType: .string)?
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return TopShelfModuleSnapshot(moduleID: descriptor.id, title: descriptor.title,
                primaryText: value.map { String($0.prefix(160)) } ?? String(localized: "No text on the clipboard"),
                secondaryText: String(localized: "Read for this open session only"), symbol: descriptor.symbol,
                status: value == nil ? .unavailable : .neutral)
        }
    }
}

public actor TopShelfCalendarModule: TopShelfModule {
    public nonisolated let descriptor = TopShelfModuleDescriptor(id: "calendar", kind: .calendar,
        title: String(localized: "Next Event"), symbol: "calendar", isSensitive: true, allowsAmbientPresentation: true)
    private let eventStore = EKEventStore()

    public init() {}

    public func snapshot(in context: TopShelfPresentationContext) async -> TopShelfModuleSnapshot {
        let status = EKEventStore.authorizationStatus(for: .event)
        guard status == .fullAccess else {
            return TopShelfModuleSnapshot(moduleID: descriptor.id, title: descriptor.title,
                primaryText: String(localized: "Calendar access is off"), secondaryText: String(localized: "Enable this module to request access"),
                symbol: descriptor.symbol, status: .unavailable)
        }
        let end = context.now.addingTimeInterval(7 * 86_400)
        let predicate = eventStore.predicateForEvents(withStart: context.now, end: end, calendars: nil)
        guard let event = eventStore.events(matching: predicate).first else {
            return TopShelfModuleSnapshot(moduleID: descriptor.id, title: descriptor.title,
                primaryText: String(localized: "No upcoming events"), symbol: descriptor.symbol, status: .good)
        }
        return TopShelfModuleSnapshot(moduleID: descriptor.id, title: descriptor.title,
            primaryText: String(event.title.prefix(120)), secondaryText: event.startDate.formatted(date: .omitted, time: .shortened),
            symbol: descriptor.symbol,
            status: event.startDate.timeIntervalSince(context.now) <= 15 * 60 ? .attention : .neutral)
    }

    public func requestAccess() async -> Bool {
        (try? await eventStore.requestFullAccessToEvents()) == true
    }
}

public struct TopShelfNotesModule: TopShelfModule {
    public let descriptor = TopShelfModuleDescriptor(id: "quick-notes", kind: .quickNotes,
        title: String(localized: "Quick Notes"), symbol: "note.text")
    public init() {}
    public func snapshot(in context: TopShelfPresentationContext) async -> TopShelfModuleSnapshot {
        await MainActor.run {
            let notes = TopShelfStore.shared.state.notes
            return TopShelfModuleSnapshot(moduleID: descriptor.id, title: descriptor.title,
                primaryText: notes.first?.text ?? String(localized: "No quick notes"),
                secondaryText: notes.isEmpty ? String(localized: "Add one from expanded Top Shelf")
                    : String(localized: "\(notes.count) saved locally"),
                symbol: descriptor.symbol,
                actions: notes.first.map { [.removeNote($0.id)] } ?? [])
        }
    }
}

public struct TopShelfTimerModule: TopShelfModule {
    public let descriptor = TopShelfModuleDescriptor(id: "timers", kind: .timers,
        title: String(localized: "Timers"), symbol: "timer")
    public init() {}
    public func snapshot(in context: TopShelfPresentationContext) async -> TopShelfModuleSnapshot {
        await MainActor.run {
            let timers = TopShelfStore.shared.state.timers
            guard let timer = timers.first else {
                return TopShelfModuleSnapshot(moduleID: descriptor.id, title: descriptor.title,
                    primaryText: String(localized: "No active timers"), symbol: descriptor.symbol)
            }
            let elapsed = timer.startedAt.map { context.now.timeIntervalSince($0) } ?? 0
            let remaining = max(0, timer.duration - elapsed)
            return TopShelfModuleSnapshot(moduleID: descriptor.id, title: descriptor.title,
                primaryText: timer.title,
                secondaryText: String(format: "%02d:%02d", Int(remaining) / 60, Int(remaining) % 60),
                symbol: descriptor.symbol, status: remaining == 0 ? .attention : .neutral,
                actions: [timer.startedAt == nil ? .startTimer(timer.id) : .pauseTimer(timer.id)])
        }
    }
}

public struct TopShelfFilesModule: TopShelfModule {
    public let descriptor = TopShelfModuleDescriptor(id: "files", kind: .files,
        title: String(localized: "Files"), symbol: "folder")
    public init() {}
    public func snapshot(in context: TopShelfPresentationContext) async -> TopShelfModuleSnapshot {
        await MainActor.run {
            let files = TopShelfStore.shared.state.recentFiles
            guard let file = files.first else {
                return TopShelfModuleSnapshot(moduleID: descriptor.id, title: descriptor.title,
                    primaryText: String(localized: "Drop a file onto Top Shelf"),
                    secondaryText: String(localized: "Tonic stores only a security-scoped bookmark after your selection."),
                    symbol: descriptor.symbol)
            }
            return TopShelfModuleSnapshot(moduleID: descriptor.id, title: descriptor.title,
                primaryText: file.displayName,
                secondaryText: files.count == 1 ? String(localized: "Recent Tonic file")
                    : String(localized: "\(files.count) recent Tonic files"),
                symbol: descriptor.symbol, actions: [.openRecentFile(file.id)])
        }
    }
}

public struct TopShelfShortcutsModule: TopShelfModule {
    public let descriptor = TopShelfModuleDescriptor(id: "shortcuts", kind: .shortcuts,
        title: String(localized: "Shortcuts"), symbol: "square.stack.3d.up")
    public init() {}
    public func snapshot(in context: TopShelfPresentationContext) async -> TopShelfModuleSnapshot {
        await MainActor.run {
            let names = MenuBarWorkspaceStore.shared.envelope.committed.customItems
                .flatMap(\.actions).compactMap { action -> String? in
                    if case .runShortcut(let name) = action { return name }
                    return nil
                }
            guard let first = names.first else {
                return TopShelfModuleSnapshot(moduleID: descriptor.id, title: descriptor.title,
                    primaryText: String(localized: "No Shortcut launchers"),
                    secondaryText: String(localized: "Add a reviewed Apple Shortcut action in the custom-item builder."),
                    symbol: descriptor.symbol, status: .unavailable,
                    actions: [.openTonicDestination("organize")])
            }
            return TopShelfModuleSnapshot(moduleID: descriptor.id, title: descriptor.title,
                primaryText: first, secondaryText: names.count == 1 ? String(localized: "Apple Shortcut")
                    : String(localized: "\(names.count) Apple Shortcuts"),
                symbol: descriptor.symbol, actions: names.prefix(3).map(TopShelfAction.runShortcut))
        }
    }
}

public struct TopShelfProviderCardsModule: TopShelfModule {
    public let descriptor = TopShelfModuleDescriptor(id: "provider-cards", kind: .provider,
        title: String(localized: "Provider Cards"), symbol: "shippingbox")
    public init() {}
    public func snapshot(in context: TopShelfPresentationContext) async -> TopShelfModuleSnapshot {
        let manifests = await TonicProviderRegistry.shared.manifests()
        return TopShelfModuleSnapshot(moduleID: descriptor.id, title: descriptor.title,
            primaryText: manifests.isEmpty ? String(localized: "No providers installed")
                : String(localized: "\(manifests.count) providers ready"),
            secondaryText: manifests.first.map { String($0.displayName.prefix(80)) }, symbol: descriptor.symbol,
            status: manifests.isEmpty ? .unavailable : .good,
            actions: [.openTonicDestination("organize")])
    }
}
