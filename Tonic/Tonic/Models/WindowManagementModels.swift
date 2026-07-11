//
//  WindowManagementModels.swift
//  Tonic
//

import Foundation
import CoreGraphics

enum WindowAction: String, CaseIterable, Identifiable, Codable, Sendable {
    case leftHalf
    case rightHalf
    case topHalf
    case bottomHalf
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
    case maximize
    case centered
    case leftTwoThirds
    case rightTwoThirds

    var id: String { rawValue }

    var title: String {
        switch self {
        case .leftHalf: "Left Half"
        case .rightHalf: "Right Half"
        case .topHalf: "Top Half"
        case .bottomHalf: "Bottom Half"
        case .topLeft: "Top Left"
        case .topRight: "Top Right"
        case .bottomLeft: "Bottom Left"
        case .bottomRight: "Bottom Right"
        case .maximize: "Maximize"
        case .centered: "Center"
        case .leftTwoThirds: "Left Two Thirds"
        case .rightTwoThirds: "Right Two Thirds"
        }
    }

    var symbol: String {
        switch self {
        case .leftHalf: "rectangle.lefthalf.inset.filled"
        case .rightHalf: "rectangle.righthalf.inset.filled"
        case .topHalf: "rectangle.tophalf.inset.filled"
        case .bottomHalf: "rectangle.bottomhalf.inset.filled"
        case .topLeft: "rectangle.inset.topleft.filled"
        case .topRight: "rectangle.inset.topright.filled"
        case .bottomLeft: "rectangle.inset.bottomleft.filled"
        case .bottomRight: "rectangle.inset.bottomright.filled"
        case .maximize: "rectangle.inset.filled"
        case .centered: "rectangle.center.inset.filled"
        case .leftTwoThirds: "rectangle.split.3x1.fill"
        case .rightTwoThirds: "rectangle.split.3x1.fill"
        }
    }

    /// Frame variants for repeat-press cycling (Magnet/Rectangle-style):
    /// left/right halves cycle ½ → ⅓ → ⅔; every other action has one frame.
    func cycleFrames(in visibleFrame: CGRect) -> [CGRect] {
        let fractions: [CGFloat] = [1 / 2, 1 / 3, 2 / 3]
        switch self {
        case .leftHalf:
            return fractions.map { fraction in
                CGRect(x: visibleFrame.minX, y: visibleFrame.minY,
                       width: visibleFrame.width * fraction, height: visibleFrame.height)
            }
        case .rightHalf:
            return fractions.map { fraction in
                let width = visibleFrame.width * fraction
                return CGRect(x: visibleFrame.maxX - width, y: visibleFrame.minY,
                              width: width, height: visibleFrame.height)
            }
        default:
            return [frame(in: visibleFrame)]
        }
    }

    func frame(in visibleFrame: CGRect) -> CGRect {
        let halfWidth = visibleFrame.width / 2
        let halfHeight = visibleFrame.height / 2
        switch self {
        case .leftHalf:
            return CGRect(x: visibleFrame.minX, y: visibleFrame.minY, width: halfWidth, height: visibleFrame.height)
        case .rightHalf:
            return CGRect(x: visibleFrame.midX, y: visibleFrame.minY, width: halfWidth, height: visibleFrame.height)
        case .topHalf:
            return CGRect(x: visibleFrame.minX, y: visibleFrame.midY, width: visibleFrame.width, height: halfHeight)
        case .bottomHalf:
            return CGRect(x: visibleFrame.minX, y: visibleFrame.minY, width: visibleFrame.width, height: halfHeight)
        case .topLeft:
            return CGRect(x: visibleFrame.minX, y: visibleFrame.midY, width: halfWidth, height: halfHeight)
        case .topRight:
            return CGRect(x: visibleFrame.midX, y: visibleFrame.midY, width: halfWidth, height: halfHeight)
        case .bottomLeft:
            return CGRect(x: visibleFrame.minX, y: visibleFrame.minY, width: halfWidth, height: halfHeight)
        case .bottomRight:
            return CGRect(x: visibleFrame.midX, y: visibleFrame.minY, width: halfWidth, height: halfHeight)
        case .maximize:
            return visibleFrame
        case .centered:
            let width = min(visibleFrame.width * 0.72, 1100)
            let height = min(visibleFrame.height * 0.78, 820)
            return CGRect(x: visibleFrame.midX - width / 2, y: visibleFrame.midY - height / 2, width: width, height: height)
        case .leftTwoThirds:
            return CGRect(x: visibleFrame.minX, y: visibleFrame.minY, width: visibleFrame.width * 2 / 3, height: visibleFrame.height)
        case .rightTwoThirds:
            let width = visibleFrame.width * 2 / 3
            return CGRect(x: visibleFrame.maxX - width, y: visibleFrame.minY, width: width, height: visibleFrame.height)
        }
    }
}

enum WindowTarget: Hashable, Codable, Sendable {
    case currentDisplay
    case display(DisplaySignature)
}

struct DisplaySignature: Hashable, Codable, Sendable {
    let name: String
    let width: Int
    let height: Int
    let scale: Double
}

struct WindowPlacement: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let bundleIdentifier: String
    let action: WindowAction
    let target: WindowTarget

    init(id: UUID = UUID(), bundleIdentifier: String, action: WindowAction, target: WindowTarget = .currentDisplay) {
        self.id = id
        self.bundleIdentifier = bundleIdentifier
        self.action = action
        self.target = target
    }
}

struct WindowLayout: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var name: String
    var placements: [WindowPlacement]

    init(id: UUID = UUID(), name: String, placements: [WindowPlacement]) {
        self.id = id
        self.name = name
        self.placements = placements
    }
}

struct WindowRule: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var bundleIdentifier: String
    var action: WindowAction
    var target: WindowTarget
    var isEnabled: Bool

    init(id: UUID = UUID(), bundleIdentifier: String, action: WindowAction, target: WindowTarget = .currentDisplay, isEnabled: Bool = true) {
        self.id = id
        self.bundleIdentifier = bundleIdentifier
        self.action = action
        self.target = target
        self.isEnabled = isEnabled
    }
}

// MARK: - Workspaces (multi-app frame capture/restore)

/// One captured window: its owning app, the display it lived on, and its frame
/// normalized to that display's visible frame so it survives resolution changes.
struct WorkspaceWindowSnapshot: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let bundleIdentifier: String
    let appName: String
    let windowTitle: String?
    let display: DisplaySignature
    /// x/y/width/height as 0…1 fractions of the display's visible frame.
    let relativeFrame: CGRect

    init(id: UUID = UUID(), bundleIdentifier: String, appName: String,
         windowTitle: String?, display: DisplaySignature, relativeFrame: CGRect) {
        self.id = id
        self.bundleIdentifier = bundleIdentifier
        self.appName = appName
        self.windowTitle = windowTitle
        self.display = display
        self.relativeFrame = relativeFrame
    }
}

/// A named multi-app arrangement — every standard window's frame at capture time.
struct WindowWorkspace: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var name: String
    var capturedAt: Date
    var windows: [WorkspaceWindowSnapshot]

    init(id: UUID = UUID(), name: String, capturedAt: Date = Date(),
         windows: [WorkspaceWindowSnapshot]) {
        self.id = id
        self.name = name
        self.capturedAt = capturedAt
        self.windows = windows
    }

    /// Distinct apps in the workspace, for summaries ("Xcode, Safari + 2 more").
    var appNames: [String] {
        var seen = Set<String>()
        return windows.compactMap { seen.insert($0.appName).inserted ? $0.appName : nil }
    }
}

/// Auto-apply a workspace when a display (matched by name) connects.
struct DisplayRule: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var display: DisplaySignature
    var workspaceID: UUID
    var isEnabled: Bool

    init(id: UUID = UUID(), display: DisplaySignature, workspaceID: UUID, isEnabled: Bool = true) {
        self.id = id
        self.display = display
        self.workspaceID = workspaceID
        self.isEnabled = isEnabled
    }
}
