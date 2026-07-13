//
//  WindowManagementModels.swift
//  Tonic
//

import Foundation
import CoreGraphics

public enum WindowAction: String, CaseIterable, Identifiable, Codable, Sendable {
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
    case leftThird
    case centerThird
    case rightThird
    case topLeftSixth
    case topCenterSixth
    case topRightSixth
    case bottomLeftSixth
    case bottomCenterSixth
    case bottomRightSixth
    case nextDisplay
    case previousDisplay

    public var id: String { rawValue }

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
        case .leftThird: "Left Third"
        case .centerThird: "Center Third"
        case .rightThird: "Right Third"
        case .topLeftSixth: "Top Left Sixth"
        case .topCenterSixth: "Top Center Sixth"
        case .topRightSixth: "Top Right Sixth"
        case .bottomLeftSixth: "Bottom Left Sixth"
        case .bottomCenterSixth: "Bottom Center Sixth"
        case .bottomRightSixth: "Bottom Right Sixth"
        case .nextDisplay: "Next Display"
        case .previousDisplay: "Previous Display"
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
        case .leftThird, .centerThird, .rightThird: "rectangle.split.3x1"
        case .topLeftSixth, .topCenterSixth, .topRightSixth,
             .bottomLeftSixth, .bottomCenterSixth, .bottomRightSixth: "rectangle.split.3x2"
        case .nextDisplay: "arrow.right.square"
        case .previousDisplay: "arrow.left.square"
        }
    }

    /// Actions that move the window between displays rather than reframe it on
    /// the current one. `WindowManagementService.perform` handles these before
    /// the generic frame path.
    var isDisplayMove: Bool {
        self == .nextDisplay || self == .previousDisplay
    }

    /// Frame variants for repeat-press cycling (Magnet/Rectangle-style):
    /// left/right halves cycle ½ → ⅓ → ⅔, the thirds walk left → center → right
    /// starting from their own column; every other action has one frame.
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
        case .leftThird, .centerThird, .rightThird:
            let columns: [WindowAction] = [.leftThird, .centerThird, .rightThird]
            let start = columns.firstIndex(of: self) ?? 0
            return (0..<columns.count).map { offset in
                columns[(start + offset) % columns.count].frame(in: visibleFrame)
            }
        default:
            return [frame(in: visibleFrame)]
        }
    }

    func frame(in visibleFrame: CGRect) -> CGRect {
        let halfWidth = visibleFrame.width / 2
        let halfHeight = visibleFrame.height / 2
        let thirdWidth = visibleFrame.width / 3
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
        case .leftThird:
            return CGRect(x: visibleFrame.minX, y: visibleFrame.minY, width: thirdWidth, height: visibleFrame.height)
        case .centerThird:
            return CGRect(x: visibleFrame.minX + thirdWidth, y: visibleFrame.minY, width: thirdWidth, height: visibleFrame.height)
        case .rightThird:
            return CGRect(x: visibleFrame.maxX - thirdWidth, y: visibleFrame.minY, width: thirdWidth, height: visibleFrame.height)
        case .topLeftSixth:
            return CGRect(x: visibleFrame.minX, y: visibleFrame.midY, width: thirdWidth, height: halfHeight)
        case .topCenterSixth:
            return CGRect(x: visibleFrame.minX + thirdWidth, y: visibleFrame.midY, width: thirdWidth, height: halfHeight)
        case .topRightSixth:
            return CGRect(x: visibleFrame.maxX - thirdWidth, y: visibleFrame.midY, width: thirdWidth, height: halfHeight)
        case .bottomLeftSixth:
            return CGRect(x: visibleFrame.minX, y: visibleFrame.minY, width: thirdWidth, height: halfHeight)
        case .bottomCenterSixth:
            return CGRect(x: visibleFrame.minX + thirdWidth, y: visibleFrame.minY, width: thirdWidth, height: halfHeight)
        case .bottomRightSixth:
            return CGRect(x: visibleFrame.maxX - thirdWidth, y: visibleFrame.minY, width: thirdWidth, height: halfHeight)
        case .nextDisplay, .previousDisplay:
            // Display moves keep the window's relative frame; the generic frame
            // path never runs for them (see `isDisplayMove`).
            return visibleFrame
        }
    }
}

// MARK: - Tiling geometry helpers

enum WindowTilingGeometry {
    /// Inset a tiled frame so adjacent tiles end up `gap` points apart and
    /// screen-touching edges keep a full `gap` margin: edges on the visible-frame
    /// boundary inset by `gap`, shared interior edges by `gap / 2`. Returns the
    /// original frame when the gap is zero or would degenerate the frame.
    static func applyingGap(_ rect: CGRect, gap: CGFloat, in visibleFrame: CGRect,
                            tolerance: CGFloat = 1) -> CGRect {
        guard gap > 0 else { return rect }

        let leftInset = abs(rect.minX - visibleFrame.minX) <= tolerance ? gap : gap / 2
        let rightInset = abs(rect.maxX - visibleFrame.maxX) <= tolerance ? gap : gap / 2
        let bottomInset = abs(rect.minY - visibleFrame.minY) <= tolerance ? gap : gap / 2
        let topInset = abs(rect.maxY - visibleFrame.maxY) <= tolerance ? gap : gap / 2

        let result = CGRect(
            x: rect.minX + leftInset,
            y: rect.minY + bottomInset,
            width: rect.width - leftInset - rightInset,
            height: rect.height - bottomInset - topInset
        )
        guard result.width >= 40, result.height >= 40 else { return rect }
        return result
    }

    /// Re-project a frame from one display's visible area onto another's,
    /// preserving its relative position and size (the workspace-snapshot
    /// normalization, as a pure function). Falls back to the destination frame
    /// when the source is degenerate.
    static func projecting(_ rect: CGRect, from source: CGRect, onto destination: CGRect) -> CGRect {
        guard source.width > 0, source.height > 0 else { return destination }
        let relative = CGRect(
            x: (rect.minX - source.minX) / source.width,
            y: (rect.minY - source.minY) / source.height,
            width: rect.width / source.width,
            height: rect.height / source.height
        )
        return CGRect(
            x: destination.minX + relative.minX * destination.width,
            y: destination.minY + relative.minY * destination.height,
            width: relative.width * destination.width,
            height: relative.height * destination.height
        )
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
