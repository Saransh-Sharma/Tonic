//
//  DiskMapView.swift
//  Tonic
//
//  The sunburst disk map: three rings of directory segments on a smoked-glass
//  console, angles proportional to allocated size. Hover reads out the segment;
//  click drills in (a fresh scan rooted at that folder); the center steps back
//  up. Categorical map colors identify directories — never health.
//

import SwiftUI

struct DiskMapCard: View {
    @State private var scanner = DiskMapScanner()
    /// Drill trail; last element is the current map root path.
    @State private var trail: [String] = []
    @State private var hovered: DiskMapNode?

    private var homePath: String { NSHomeDirectory() }

    var body: some View {
        DataCard {
            VStack(alignment: .leading, spacing: TonicDS.Space.md) {
                DataCardHeader(label: "Disk map") {
                    headerControls
                }

                if let root = scanner.root {
                    HStack(alignment: .top, spacing: TonicDS.Space.lg) {
                        SunburstChart(root: root, hovered: $hovered) { node in
                            drill(into: node)
                        } onCenterTap: {
                            goUp()
                        }
                        .frame(width: 320, height: 320)

                        mapSidebar(root: root)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(TonicDS.Space.md)
                    .tonicSurface(.smoked,
                                  in: RoundedRectangle(cornerRadius: TonicDS.Radius.md, style: .continuous))
                    .environment(\.colorScheme, .dark)
                } else if scanner.isScanning {
                    scanningState
                } else if let message = scanner.errorMessage {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .tonicType(.caption)
                        .foregroundStyle(TonicDS.Colors.textMuted)
                } else {
                    idleState
                }
            }
        }
    }

    // MARK: - States

    private var headerControls: some View {
        HStack(spacing: TonicDS.Space.sm) {
            if trail.count > 1 {
                TextAction("Back", color: TonicDS.Colors.linkBlue) { goUp() }
            }
            if scanner.isScanning {
                TextAction("Cancel") { scanner.cancel() }
            } else if scanner.root != nil {
                TextAction("Rescan", color: TonicDS.Colors.linkBlue) {
                    scanner.scan(path: trail.last ?? homePath)
                }
            }
        }
    }

    private var idleState: some View {
        HStack(spacing: TonicDS.Space.md) {
            Text("Map where your space goes — every folder drawn to scale, three levels deep.")
                .tonicType(.body)
                .foregroundStyle(TonicDS.Colors.textMuted)
            Spacer()
            PrimaryPill("Map Home Folder") {
                trail = [homePath]
                scanner.scan(path: homePath)
            }
            TextAction("Choose Folder…", color: TonicDS.Colors.linkBlue) { chooseFolder() }
        }
    }

    private var scanningState: some View {
        HStack(spacing: TonicDS.Space.md) {
            ProgressView().controlSize(.small)
            Text("\(scanner.progress.files.formatted()) files · \(ByteCountFormatter.string(fromByteCount: scanner.progress.bytes, countStyle: .file))")
                .tonicType(.monoLabel)
                .foregroundStyle(TonicDS.Colors.textMuted)
                .monospacedDigit()
            Spacer()
        }
        .frame(minHeight: 60)
    }

    private func mapSidebar(root: DiskMapNode) -> some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.sm) {
            // Readout: hovered segment, else the root.
            let subject = hovered ?? root
            MonoLabel(breadcrumb(for: subject), color: TonicDS.Colors.onDarkMuted)
                .lineLimit(1)
                .truncationMode(.head)
            HStack(alignment: .firstTextBaseline, spacing: TonicDS.Space.xs) {
                Text(subject.formattedSize)
                    .tonicType(.metricSmall)
                    .foregroundStyle(TonicDS.Colors.onDark)
                    .monospacedDigit()
                if subject.size != root.size, root.size > 0 {
                    Text("\(Int((Double(subject.size) / Double(root.size) * 100).rounded()))%")
                        .tonicType(.monoLabel)
                        .foregroundStyle(TonicDS.Colors.onDarkMuted)
                }
            }

            TonicHairline(color: TonicDS.Colors.hairlineOnDark)

            // Legend: the root's top children.
            ForEach(Array(root.children.prefix(8).enumerated()), id: \.element.id) { index, child in
                HStack(spacing: TonicDS.Space.xs) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(SunburstChart.color(forTopLevelIndex: index, isAggregate: child.isAggregate))
                        .frame(width: 8, height: 8)
                    Text(child.name)
                        .tonicType(.caption)
                        .foregroundStyle(TonicDS.Colors.onDark)
                        .lineLimit(1)
                    Spacer(minLength: TonicDS.Space.xs)
                    Text(child.formattedSize)
                        .tonicType(.monoLabel)
                        .foregroundStyle(TonicDS.Colors.onDarkMuted)
                        .monospacedDigit()
                }
            }

            Spacer(minLength: 0)

            if let hovered, !hovered.isAggregate {
                TextAction("Reveal in Finder", color: TonicDS.Colors.linkBlue) {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: hovered.path)
                }
            }
        }
    }

    // MARK: - Navigation

    private func drill(into node: DiskMapNode) {
        guard !node.isAggregate, !node.children.isEmpty || nodeIsDirectory(node) else { return }
        trail.append(node.path)
        hovered = nil
        scanner.scan(path: node.path)
    }

    private func goUp() {
        guard trail.count > 1 else { return }
        trail.removeLast()
        hovered = nil
        if let parent = trail.last { scanner.scan(path: parent) }
    }

    private func nodeIsDirectory(_ node: DiskMapNode) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: node.path, isDirectory: &isDirectory)
            && isDirectory.boolValue
    }

    private func breadcrumb(for node: DiskMapNode) -> String {
        node.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Map Folder"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        trail = [url.path]
        scanner.scan(path: url.path)
    }
}

// MARK: - Sunburst chart

struct SunburstChart: View {
    let root: DiskMapNode
    @Binding var hovered: DiskMapNode?
    let onSelect: (DiskMapNode) -> Void
    let onCenterTap: () -> Void

    /// One drawable/hit-testable arc.
    private struct Segment {
        let node: DiskMapNode
        let depth: Int          // 1-based ring
        let startAngle: Double  // radians, 0 at 12 o'clock, clockwise
        let endAngle: Double
        let color: Color
    }

    private static let holeRadius: CGFloat = 56
    private static let ringWidth: CGFloat = 32
    /// Segments spanning less than this angle (radians) aren't drawn.
    private static let minAngle = 0.008

    static func color(forTopLevelIndex index: Int, isAggregate: Bool) -> Color {
        if isAggregate { return TonicDS.Colors.onDarkMuted.opacity(0.35) }
        let palette = TonicDS.Chart.categorical
        return palette[index % palette.count]
    }

    private var segments: [Segment] {
        var result: [Segment] = []
        guard root.size > 0 else { return result }

        func walk(_ node: DiskMapNode, depth: Int, start: Double, end: Double, color: Color?) {
            guard depth <= DiskMapScanner.maxDepth else { return }
            var cursor = start
            for (index, child) in node.children.enumerated() {
                let span = (end - start) * Double(child.size) / Double(max(node.size, 1))
                let childEnd = cursor + span
                defer { cursor = childEnd }
                guard span >= Self.minAngle else { continue }
                // Top-level children own a palette hue; descendants inherit it
                // at reduced opacity so rings read as one family.
                let base = color ?? Self.color(forTopLevelIndex: index, isAggregate: child.isAggregate)
                let shade = depth == 1 ? base : base.opacity(depth == 2 ? 0.72 : 0.5)
                result.append(Segment(node: child, depth: depth,
                                      startAngle: cursor, endAngle: childEnd, color: shade))
                walk(child, depth: depth + 1, start: cursor, end: childEnd, color: base)
            }
        }
        walk(root, depth: 1, start: 0, end: .pi * 2, color: nil)
        return result
    }

    var body: some View {
        let segments = segments
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            for segment in segments {
                let inner = Self.holeRadius + CGFloat(segment.depth - 1) * Self.ringWidth + 1.5
                let outer = inner + Self.ringWidth - 3
                var path = Path()
                // Angular gap of ~0.4° keeps segments visually separated.
                let gap = min(0.007, (segment.endAngle - segment.startAngle) * 0.15)
                let from = Angle(radians: segment.startAngle + gap - .pi / 2)
                let to = Angle(radians: segment.endAngle - gap - .pi / 2)
                path.addArc(center: center, radius: outer, startAngle: from, endAngle: to, clockwise: false)
                path.addArc(center: center, radius: inner, startAngle: to, endAngle: from, clockwise: true)
                path.closeSubpath()

                let isHovered = hovered?.id == segment.node.id
                context.fill(path, with: .color(segment.color.opacity(isHovered ? 1.0 : 0.88)))
                if isHovered {
                    context.stroke(path, with: .color(TonicDS.Colors.onDark.opacity(0.7)), lineWidth: 1.5)
                }
            }

            // Center label: the root's own size.
            let title = Text(root.formattedSize)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(TonicDS.Colors.onDark)
            context.draw(title, at: center, anchor: .center)
        }
        .contentShape(Rectangle())
        .onContinuousHover { phase in
            switch phase {
            case .active(let point):
                hovered = hitTest(point, segments: segments)
            case .ended:
                hovered = nil
            }
        }
        .onTapGesture { location in
            if let hit = hitTest(location, segments: segments) {
                onSelect(hit)
            } else if distanceFromCenter(location) < Self.holeRadius {
                onCenterTap()
            }
        }
        .accessibilityLabel("Disk map of \(root.name), \(root.formattedSize)")
        .accessibilityHint("Hover to inspect folders; click a segment to map that folder.")
    }

    private func distanceFromCenter(_ point: CGPoint) -> CGFloat {
        hypot(point.x - 160, point.y - 160)
    }

    private func hitTest(_ point: CGPoint, segments: [Segment]) -> DiskMapNode? {
        let dx = point.x - 160
        let dy = point.y - 160
        let radius = hypot(dx, dy)
        guard radius >= Self.holeRadius else { return nil }
        let ring = Int((radius - Self.holeRadius) / Self.ringWidth) + 1
        guard ring <= DiskMapScanner.maxDepth else { return nil }
        // atan2 with 0 at 12 o'clock, clockwise, normalized to 0…2π.
        var angle = atan2(dy, dx) + .pi / 2
        if angle < 0 { angle += .pi * 2 }
        return segments.first {
            $0.depth == ring && angle >= $0.startAngle && angle < $0.endAngle
        }?.node
    }
}
