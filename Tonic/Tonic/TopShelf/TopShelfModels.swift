import Foundation

public enum TopShelfModuleKind: String, Codable, CaseIterable, Hashable, Sendable {
    case nowPlaying
    case weather
    case calendar
    case clipboard
    case systemHealth
    case recommendations
    case timers
    case quickNotes
    case files
    case shortcuts
    case provider
}

public struct TopShelfModuleDescriptor: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var kind: TopShelfModuleKind
    public var title: String
    public var symbol: String
    public var isSensitive: Bool
    public var allowsAmbientPresentation: Bool

    public init(id: String, kind: TopShelfModuleKind, title: String, symbol: String,
                isSensitive: Bool = false, allowsAmbientPresentation: Bool = false) {
        self.id = id
        self.kind = kind
        self.title = title
        self.symbol = symbol
        self.isSensitive = isSensitive
        self.allowsAmbientPresentation = allowsAmbientPresentation
    }
}

public enum TopShelfSemanticStatus: String, Codable, Hashable, Sendable {
    case neutral
    case good
    case attention
    case critical
    case unavailable
}

public enum TopShelfAction: Codable, Hashable, Identifiable, Sendable {
    case refresh(moduleID: String)
    case openURL(URL)
    case openTonicDestination(String)
    case startTimer(UUID)
    case pauseTimer(UUID)
    case removeNote(UUID)
    case runShortcut(String)
    case nowPlaying(TopShelfPlaybackCommand)
    case openRecentFile(UUID)

    public var id: String {
        switch self {
        case .refresh(let value): "refresh:\(value)"
        case .openURL(let value): "url:\(value.absoluteString)"
        case .openTonicDestination(let value): "tonic:\(value)"
        case .startTimer(let value): "timer-start:\(value.uuidString)"
        case .pauseTimer(let value): "timer-pause:\(value.uuidString)"
        case .removeNote(let value): "note-remove:\(value.uuidString)"
        case .runShortcut(let value): "shortcut:\(value)"
        case .nowPlaying(let value): "now-playing:\(value.rawValue)"
        case .openRecentFile(let value): "file:\(value.uuidString)"
        }
    }

    public var symbolName: String {
        switch self {
        case .refresh: "arrow.clockwise"
        case .openURL, .openTonicDestination, .openRecentFile: "arrow.up.right"
        case .startTimer: "play.fill"
        case .pauseTimer: "pause.fill"
        case .removeNote: "trash"
        case .runShortcut: "square.stack.3d.up"
        case .nowPlaying(.togglePlayPause): "playpause.fill"
        case .nowPlaying(.nextTrack): "forward.end.fill"
        case .nowPlaying(.previousTrack): "backward.end.fill"
        }
    }

    public var accessibilityTitle: String {
        switch self {
        case .refresh: String(localized: "Refresh module")
        case .openURL: String(localized: "Open link")
        case .openTonicDestination: String(localized: "Open in Tonic")
        case .startTimer: String(localized: "Start timer")
        case .pauseTimer: String(localized: "Pause timer")
        case .removeNote: String(localized: "Remove note")
        case .runShortcut: String(localized: "Run Apple Shortcut")
        case .nowPlaying(.togglePlayPause): String(localized: "Play or pause")
        case .nowPlaying(.nextTrack): String(localized: "Next track")
        case .nowPlaying(.previousTrack): String(localized: "Previous track")
        case .openRecentFile: String(localized: "Open recent file")
        }
    }
}

public enum TopShelfPlaybackCommand: String, Codable, Hashable, Sendable {
    case togglePlayPause
    case nextTrack
    case previousTrack
}

public struct TopShelfModuleSnapshot: Codable, Equatable, Identifiable, Sendable {
    public var id: String { moduleID }
    public var moduleID: String
    public var title: String
    public var primaryText: String
    public var secondaryText: String?
    public var symbol: String
    public var status: TopShelfSemanticStatus
    public var actions: [TopShelfAction]
    public var refreshedAt: Date

    public init(moduleID: String, title: String, primaryText: String, secondaryText: String? = nil,
                symbol: String, status: TopShelfSemanticStatus = .neutral,
                actions: [TopShelfAction] = [], refreshedAt: Date = Date()) {
        self.moduleID = moduleID
        self.title = title
        self.primaryText = primaryText
        self.secondaryText = secondaryText
        self.symbol = symbol
        self.status = status
        self.actions = actions
        self.refreshedAt = refreshedAt
    }
}

public struct TopShelfPresentationContext: Sendable {
    public var isDeliberateOpen: Bool
    public var isAmbient: Bool
    public var activeDisplayName: String?
    public var now: Date

    public init(isDeliberateOpen: Bool, isAmbient: Bool = false,
                activeDisplayName: String? = nil, now: Date = Date()) {
        self.isDeliberateOpen = isDeliberateOpen
        self.isAmbient = isAmbient
        self.activeDisplayName = activeDisplayName
        self.now = now
    }
}

public protocol TopShelfModule: Sendable {
    var descriptor: TopShelfModuleDescriptor { get }
    func snapshot(in context: TopShelfPresentationContext) async -> TopShelfModuleSnapshot
}

public enum TopShelfLayoutMode: String, Codable, CaseIterable, Sendable {
    case adaptive
    case compact
    case expanded
}

public struct TopShelfLayout: Codable, Equatable, Sendable {
    public var orderedModuleIDs: [String]
    public var hiddenModuleIDs: Set<String>
    public var pinnedModuleIDs: Set<String>
    public var mode: TopShelfLayoutMode

    public init(orderedModuleIDs: [String] = [], hiddenModuleIDs: Set<String> = [],
                pinnedModuleIDs: Set<String> = [], mode: TopShelfLayoutMode = .adaptive) {
        self.orderedModuleIDs = orderedModuleIDs
        self.hiddenModuleIDs = hiddenModuleIDs
        self.pinnedModuleIDs = pinnedModuleIDs
        self.mode = mode
    }
}

public struct TopShelfAmbientPolicy: Codable, Equatable, Sendable {
    public var hasConfirmedRecommendedSet: Bool
    public var enabledModuleIDs: Set<String>
    public var cooldownSeconds: TimeInterval
    public var dismissSeconds: TimeInterval

    public init(hasConfirmedRecommendedSet: Bool = false, enabledModuleIDs: Set<String> = [],
                cooldownSeconds: TimeInterval = 300, dismissSeconds: TimeInterval = 8) {
        self.hasConfirmedRecommendedSet = hasConfirmedRecommendedSet
        self.enabledModuleIDs = enabledModuleIDs
        self.cooldownSeconds = min(max(cooldownSeconds, 60), 3_600)
        self.dismissSeconds = min(max(dismissSeconds, 3), 30)
    }
}

public struct TopShelfQuickNote: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var text: String
    public var createdAt: Date

    public init(id: UUID = UUID(), text: String, createdAt: Date = Date()) {
        self.id = id
        self.text = String(text.filter { !$0.isNewline }.prefix(280))
        self.createdAt = createdAt
    }
}

public struct TopShelfTimer: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var title: String
    public var duration: TimeInterval
    public var startedAt: Date?

    public init(id: UUID = UUID(), title: String, duration: TimeInterval, startedAt: Date? = nil) {
        self.id = id
        self.title = String(title.prefix(80))
        self.duration = min(max(duration, 60), 86_400)
        self.startedAt = startedAt
    }
}

public struct TopShelfRecentFile: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var displayName: String
    public var bookmark: Data
    public var addedAt: Date

    public init(id: UUID = UUID(), displayName: String, bookmark: Data, addedAt: Date = Date()) {
        self.id = id
        self.displayName = String(displayName.filter { !$0.isNewline }.prefix(120))
        self.bookmark = bookmark
        self.addedAt = addedAt
    }
}

public struct TopShelfState: Codable, Equatable, Sendable {
    public var layout: TopShelfLayout
    public var ambientPolicy: TopShelfAmbientPolicy
    public var enabledModuleIDs: Set<String>
    public var notes: [TopShelfQuickNote]
    public var timers: [TopShelfTimer]
    public var recentFiles: [TopShelfRecentFile]

    public init(layout: TopShelfLayout = .init(), ambientPolicy: TopShelfAmbientPolicy = .init(),
                enabledModuleIDs: Set<String> = ["system-health", "recommendations", "weather"],
                notes: [TopShelfQuickNote] = [], timers: [TopShelfTimer] = [],
                recentFiles: [TopShelfRecentFile] = []) {
        self.layout = layout
        self.ambientPolicy = ambientPolicy
        self.enabledModuleIDs = enabledModuleIDs
        self.notes = notes
        self.timers = timers
        self.recentFiles = Array(recentFiles.prefix(10))
    }


    private enum CodingKeys: String, CodingKey {
        case layout, ambientPolicy, enabledModuleIDs, notes, timers, recentFiles
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        layout = try container.decodeIfPresent(TopShelfLayout.self, forKey: .layout) ?? .init()
        ambientPolicy = try container.decodeIfPresent(TopShelfAmbientPolicy.self, forKey: .ambientPolicy) ?? .init()
        enabledModuleIDs = try container.decodeIfPresent(Set<String>.self, forKey: .enabledModuleIDs)
            ?? ["system-health", "recommendations", "weather"]
        notes = try container.decodeIfPresent([TopShelfQuickNote].self, forKey: .notes) ?? []
        timers = try container.decodeIfPresent([TopShelfTimer].self, forKey: .timers) ?? []
        recentFiles = Array((try container.decodeIfPresent([TopShelfRecentFile].self,
                                                            forKey: .recentFiles) ?? []).prefix(10))
    }
}
