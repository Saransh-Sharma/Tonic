import AppKit
import SwiftUI

@MainActor
public final class TopShelfPanelController {
    public static let shared = TopShelfPanelController()
    private var panel: NSPanel?
    private var dismissTask: Task<Void, Never>?

    public var isVisible: Bool { panel?.isVisible == true }

    public func toggle() { isVisible ? hide() : TopShelfCoordinator.shared.deliberateOpen() }

    public func show(ambient: Bool = false) {
        guard !NSApp.presentationOptions.contains(.fullScreen) else { return }
        let panel = panel ?? makePanel()
        self.panel = panel
        let compact = ambient || resolvedCompactMode()
        panel.contentView = NSHostingView(rootView: TopShelfView(ambient: ambient, compact: compact))
        position(panel, ambient: ambient, compact: compact)
        if ambient { panel.orderFrontRegardless() } else { panel.makeKeyAndOrderFront(nil) }
        dismissTask?.cancel()
        if ambient {
            let delay = TopShelfStore.shared.state.ambientPolicy.dismissSeconds
            dismissTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled else { return }
                self?.hide()
            }
        }
    }

    public func hide() { dismissTask?.cancel(); panel?.orderOut(nil) }

    private func makePanel() -> NSPanel {
        let panel = TopShelfPanel(contentRect: .zero,
            styleMask: [.borderless, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = true
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        return panel
    }

    private func position(_ panel: NSPanel, ambient: Bool, compact: Bool) {
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        guard let screen else { return }
        let size = ambient ? CGSize(width: 380, height: 88)
            : (compact ? CGSize(width: 420, height: 132) : CGSize(width: 520, height: 480))
        let visible = screen.visibleFrame
        panel.setFrame(NSRect(x: visible.midX - size.width / 2,
                              y: visible.maxY - size.height - 12,
                              width: size.width, height: size.height), display: true)
    }

    private func resolvedCompactMode() -> Bool {
        switch TopShelfStore.shared.state.layout.mode {
        case .compact: return true
        case .expanded: return false
        case .adaptive:
            let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }
                ?? NSScreen.main
            return (screen?.visibleFrame.width ?? 1_000) < 700
        }
    }
}

private final class TopShelfPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private struct TopShelfView: View {
    let ambient: Bool
    let compact: Bool
    @State private var coordinator = TopShelfCoordinator.shared
    @State private var note = ""
    @State private var searchText = ""
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "rectangle.topthird.inset.filled").foregroundStyle(.tint)
                Text("Top Shelf").font(.headline)
                Spacer()
                if coordinator.isRefreshing { ProgressView().controlSize(.small) }
                if !ambient { Button("Done") { TopShelfPanelController.shared.hide() }.buttonStyle(.plain) }
            }
            if coordinator.snapshots.isEmpty {
                ContentUnavailableView("Nothing on Top Shelf", systemImage: "square.stack.3d.up.slash",
                    description: Text("Enable modules in Top Shelf settings."))
            } else if ambient || compact {
                snapshotRow(coordinator.snapshots.first!)
            } else {
                TextField("Search Top Shelf", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel(String(localized: "Search Top Shelf modules"))
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredSnapshots) { snapshotRow($0) }
                    }
                }
                HStack {
                    TextField("Add a private local note", text: $note)
                    Button("Add") {
                        TopShelfStore.shared.addNote(note); note = ""
                        coordinator.refresh(context: .init(isDeliberateOpen: true))
                    }.disabled(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("5 min Timer") {
                        TopShelfStore.shared.addTimer()
                        coordinator.refresh(context: .init(isDeliberateOpen: true))
                    }
                }
            }
        }
        .padding(16)
        .background(reduceTransparency ? Color(nsColor: .windowBackgroundColor) : Color(nsColor: .windowBackgroundColor).opacity(0.88))
        .clipShape(RoundedRectangle(cornerRadius: ambient ? 22 : 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ambient ? 22 : 26).stroke(.separator.opacity(0.6)))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "Top Shelf"))
        .dropDestination(for: URL.self) { urls, _ in
            guard !ambient else { return false }
            let accepted = urls.reduce(false) { result, url in
                TopShelfStore.shared.addRecentFile(url) || result
            }
            if accepted { coordinator.refresh(context: .init(isDeliberateOpen: true)) }
            return accepted
        }
    }

    private var filteredSnapshots: [TopShelfModuleSnapshot] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return coordinator.snapshots }
        return coordinator.snapshots.filter {
            $0.title.localizedCaseInsensitiveContains(query)
                || $0.primaryText.localizedCaseInsensitiveContains(query)
                || ($0.secondaryText?.localizedCaseInsensitiveContains(query) == true)
        }
    }

    private func snapshotRow(_ snapshot: TopShelfModuleSnapshot) -> some View {
        HStack(spacing: 12) {
            Image(systemName: snapshot.symbol).font(.title3).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.title).font(.caption).foregroundStyle(.secondary)
                Text(snapshot.primaryText).lineLimit(2)
                if let secondary = snapshot.secondaryText { Text(secondary).font(.caption).foregroundStyle(.secondary) }
            }
            Spacer()
            ForEach(snapshot.actions.prefix(3)) { action in
                Button { coordinator.perform(action) } label: { Image(systemName: action.symbolName) }
                    .buttonStyle(.borderless).accessibilityLabel(action.accessibilityTitle)
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 14))
    }
}
