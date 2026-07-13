//
//  CustomItemRuntime.swift
//  Tonic
//
//  Shared, sandbox-safe custom item formatting and actions.
//

import AppKit
import Foundation

public struct CustomItemRuntimeSnapshot: Equatable, Sendable {
    public var date: Date
    public var batteryPercent: Double?
    public var cpuPercent: Double?
    public var memoryPercent: Double?
    public var uploadBytesPerSecond: Double?
    public var downloadBytesPerSecond: Double?
    public var weatherText: String?

    public init(date: Date = Date(), batteryPercent: Double? = nil, cpuPercent: Double? = nil,
                memoryPercent: Double? = nil, uploadBytesPerSecond: Double? = nil,
                downloadBytesPerSecond: Double? = nil, weatherText: String? = nil) {
        self.date = date
        self.batteryPercent = batteryPercent
        self.cpuPercent = cpuPercent
        self.memoryPercent = memoryPercent
        self.uploadBytesPerSecond = uploadBytesPerSecond
        self.downloadBytesPerSecond = downloadBytesPerSecond
        self.weatherText = weatherText
    }
}

public enum CustomTonicDestination: String, Codable, CaseIterable, Identifiable, Sendable {
    case smartCare, storage, apps, windows, menuBar, widgets, systemMonitor, automations, actionHistory, settings
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .smartCare: "Smart Care"
        case .storage: "Storage"
        case .apps: "Apps"
        case .windows: "Windows"
        case .menuBar: "Menu Bar"
        case .widgets: "Widgets"
        case .systemMonitor: "System Monitor"
        case .automations: "Automations"
        case .actionHistory: "Action History"
        case .settings: "Settings"
        }
    }
}

@MainActor
public protocol CustomItemDataProvider: AnyObject {
    func snapshot() -> CustomItemRuntimeSnapshot
}

@MainActor
public final class WidgetCustomItemDataProvider: CustomItemDataProvider {
    public static let shared = WidgetCustomItemDataProvider()
    private let manager: WidgetDataManager

    init(manager: WidgetDataManager = .shared) { self.manager = manager }

    public func snapshot() -> CustomItemRuntimeSnapshot {
        let memoryPercent = manager.memoryData.totalBytes > 0
            ? Double(manager.memoryData.usedBytes) / Double(manager.memoryData.totalBytes) * 100 : nil
        let weather = manager.weatherData.map { "\(Int($0.temperature.rounded()))°" }
        return CustomItemRuntimeSnapshot(
            batteryPercent: manager.batteryData.isPresent ? manager.batteryData.chargePercentage : nil,
            cpuPercent: manager.cpuData.totalUsage,
            memoryPercent: memoryPercent,
            uploadBytesPerSecond: Double(manager.networkData.uploadBytesPerSecond),
            downloadBytesPerSecond: Double(manager.networkData.downloadBytesPerSecond),
            weatherText: weather
        )
    }
}

public enum CustomItemValidationError: LocalizedError, Equatable {
    case invalidSymbol
    case invalidImage
    case invalidTemplate(String)
    case tooManyActions
    case unsafeURL
    case displayTooLong
    case invalidAction

    public var errorDescription: String? {
        switch self {
        case .invalidSymbol: "Choose a valid SF Symbol."
        case .invalidImage: "Choose an image that Tonic can still access."
        case .invalidTemplate(let token): "Unknown template token: \(token)."
        case .tooManyActions: "A custom item can have at most five actions."
        case .unsafeURL: "Only HTTPS, approved system links, and local file actions are allowed."
        case .displayTooLong: "The preview is too long for the menu bar."
        case .invalidAction: "Review the custom item action and choose a valid target."
        }
    }
}

public struct CustomItemFormatter: Sendable {
    public static let supportedTokens: Set<String> = [
        "date", "time", "battery", "cpu", "memory", "upload", "download", "weather"
    ]
    public static let maximumDisplayCharacters = 48

    public init() {}

    public func validate(_ item: CustomMenuBarItem, snapshot: CustomItemRuntimeSnapshot = .init()) throws {
        if let bookmark = item.imageBookmark {
            var stale = false
            guard let url = try? URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope],
                                     relativeTo: nil, bookmarkDataIsStale: &stale), !stale else {
                throw CustomItemValidationError.invalidImage
            }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url), NSImage(data: data) != nil else {
                throw CustomItemValidationError.invalidImage
            }
        } else if NSImage(systemSymbolName: item.symbolName, accessibilityDescription: nil) == nil {
            throw CustomItemValidationError.invalidSymbol
        }
        guard item.actions.count <= 5 else { throw CustomItemValidationError.tooManyActions }
        if case .formatted(let template) = item.dataSource { try validate(template: template) }
        if case .provider(let identifier) = item.dataSource,
           identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw CustomItemValidationError.invalidTemplate("provider identifier")
        }
        for action in item.actions {
            switch action {
            case .openURL(let url):
                if !Self.isApproved(url) { throw CustomItemValidationError.unsafeURL }
            case .openApplication(let identifier):
                guard identifier.range(of: #"^[A-Za-z0-9][A-Za-z0-9.-]+$"#, options: .regularExpression) != nil else {
                    throw CustomItemValidationError.invalidAction
                }
            case .openFile(let bookmark):
                var stale = false
                guard (try? URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope],
                                relativeTo: nil, bookmarkDataIsStale: &stale)) != nil, !stale else {
                    throw CustomItemValidationError.invalidAction
                }
            case .openTonicDestination(let destination):
                guard CustomTonicDestination(rawValue: destination) != nil else {
                    throw CustomItemValidationError.invalidAction
                }
            case .runShortcut(let name):
                guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, name.count <= 128 else {
                    throw CustomItemValidationError.invalidAction
                }
            #if !TONIC_STORE
            case .runScript:
                break
            #endif
            }
        }
        guard format(item.dataSource, snapshot: snapshot).count <= Self.maximumDisplayCharacters else {
            throw CustomItemValidationError.displayTooLong
        }
    }

    public func format(_ source: CustomMenuBarDataSource, snapshot: CustomItemRuntimeSnapshot) -> String {
        switch source {
        case .staticLabel(let label): return sanitized(label)
        case .date(let format):
            let formatter = DateFormatter(); formatter.dateFormat = format
            return sanitized(formatter.string(from: snapshot.date))
        case .battery: return percent(snapshot.batteryPercent, fallback: "Battery —")
        case .cpu: return percent(snapshot.cpuPercent, fallback: "CPU —")
        case .memory: return percent(snapshot.memoryPercent, fallback: "Memory —")
        case .network:
            return "↓\(rate(snapshot.downloadBytesPerSecond)) ↑\(rate(snapshot.uploadBytesPerSecond))"
        case .weather: return sanitized(snapshot.weatherText ?? "Weather —")
        case .formatted(let template):
            return sanitized(replacingTokens(in: template, snapshot: snapshot))
        case .provider: return "Loading…"
        }
    }

    public func validate(template: String) throws {
        let tokens = Self.tokens(in: template)
        if let unknown = tokens.first(where: { !Self.supportedTokens.contains($0) }) {
            throw CustomItemValidationError.invalidTemplate(unknown)
        }
    }

    private func replacingTokens(in template: String, snapshot: CustomItemRuntimeSnapshot) -> String {
        let date = DateFormatter(); date.dateStyle = .short
        let time = DateFormatter(); time.timeStyle = .short
        let values = [
            "date": date.string(from: snapshot.date), "time": time.string(from: snapshot.date),
            "battery": percent(snapshot.batteryPercent, fallback: "—"),
            "cpu": percent(snapshot.cpuPercent, fallback: "—"),
            "memory": percent(snapshot.memoryPercent, fallback: "—"),
            "upload": rate(snapshot.uploadBytesPerSecond), "download": rate(snapshot.downloadBytesPerSecond),
            "weather": snapshot.weatherText ?? "—"
        ]
        return values.reduce(template) { $0.replacingOccurrences(of: "{\($1.key)}", with: $1.value) }
    }

    private static func tokens(in template: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #"\{([^{}]+)\}"#) else { return [] }
        let range = NSRange(template.startIndex..., in: template)
        return regex.matches(in: template, range: range).compactMap { match in
            guard let swiftRange = Range(match.range(at: 1), in: template) else { return nil }
            return String(template[swiftRange])
        }
    }

    static func isApproved(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "https" || scheme == "shortcuts" || scheme == "x-apple.systempreferences"
    }

    private func percent(_ value: Double?, fallback: String) -> String {
        value.map { "\(Int(min(max($0, 0), 100).rounded()))%" } ?? fallback
    }
    private func rate(_ value: Double?) -> String {
        guard let value else { return "—" }
        return ByteCountFormatter.string(fromByteCount: Int64(max(0, value)), countStyle: .file) + "/s"
    }
    private func sanitized(_ value: String) -> String {
        String(value.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) })
            .prefix(Self.maximumDisplayCharacters).description
    }
}

@MainActor
public final class CustomItemSafeActionExecutor {
    public static let shared = CustomItemSafeActionExecutor()

    public func execute(_ action: CustomMenuBarSafeAction) throws {
        switch action {
        case .openApplication(let bundleIdentifier):
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
                throw CocoaError(.fileNoSuchFile)
            }
            NSWorkspace.shared.open(url)
        case .openFile(let bookmark):
            var stale = false
            let url = try URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope],
                              relativeTo: nil, bookmarkDataIsStale: &stale)
            guard !stale else { throw CocoaError(.fileReadUnknown) }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            NSWorkspace.shared.open(url)
        case .openURL(let url):
            guard CustomItemFormatter.isApproved(url) else { throw CustomItemValidationError.unsafeURL }
            NSWorkspace.shared.open(url)
        case .openTonicDestination(let destination):
            guard CustomTonicDestination(rawValue: destination) != nil else {
                throw CustomItemValidationError.invalidAction
            }
            NotificationCenter.default.post(name: .openTonicDestination, object: destination)
        case .runShortcut(let name):
            var components = URLComponents(); components.scheme = "shortcuts"; components.host = "run-shortcut"
            components.queryItems = [URLQueryItem(name: "name", value: name)]
            guard let url = components.url else { throw CustomItemValidationError.unsafeURL }
            NSWorkspace.shared.open(url)
        #if !TONIC_STORE
        case .runScript(let id):
            Task { await ScriptExecutionCoordinator.shared.executeReviewed(scriptID: id) }
        #endif
        }
    }
}

extension Notification.Name {
    static let openTonicDestination = Notification.Name("tonic.navigation.openDestination")
}
