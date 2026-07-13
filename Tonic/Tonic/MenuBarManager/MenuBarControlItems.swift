//
//  MenuBarControlItems.swift
//  Tonic
//
//  The three control status items behind menu bar management:
//  - toggle: chevron button, rightmost — expands/collapses the hidden section
//  - separator: thin rule; inflating its length to 10,000 pt pushes every
//    item the user ⌘-dragged to its left past the screen edge (the
//    Ice/Hidden Bar trick — macOS offers no API to hide other apps' items)
//  - alwaysHiddenSeparator: same trick, permanently inflated, for items that
//    stay hidden even when expanded (⌥-click the toggle to peek)
//
//  Positions persist through NSStatusItem autosave names.
//

import AppKit

@MainActor
final class MenuBarControlItem {

    enum Kind {
        case toggle
        case separator
        case alwaysHiddenSeparator

        var autosaveName: String {
            switch self {
            case .toggle: return "TonicMBToggle"
            case .separator: return "TonicMBSeparator"
            case .alwaysHiddenSeparator: return "TonicMBAlwaysHidden"
            }
        }

        /// Distance from the right edge of the menu bar (larger = further
        /// left). Seeded on first run so the initial order is deterministic:
        /// toggle · separator · always-hidden, right to left.
        var seedPreferredPosition: CGFloat {
            switch self {
            case .toggle: return 100
            case .separator: return 140
            case .alwaysHiddenSeparator: return 180
            }
        }
    }

    static let inflatedLength: CGFloat = 10_000
    static let separatorLength: CGFloat = 8

    let kind: Kind
    let statusItem: NSStatusItem

    /// Left-click on the toggle.
    var onToggle: (() -> Void)?
    /// ⌥-click on the toggle: peek at the always-hidden section.
    var onToggleAlwaysHidden: (() -> Void)?
    /// Right-click menu items.
    var onOpenSettings: (() -> Void)?
    var onDisable: (() -> Void)?

    /// Seed "NSStatusItem Preferred Position <name>" defaults before the items
    /// are first created — without this, new items land leftmost and the
    /// separator starts on the wrong side of the toggle.
    static func seedInitialPositionsIfNeeded() {
        let defaults = UserDefaults.standard
        for kind in [Kind.toggle, .separator, .alwaysHiddenSeparator] {
            let key = "NSStatusItem Preferred Position \(kind.autosaveName)"
            if defaults.object(forKey: key) == nil {
                defaults.set(Double(kind.seedPreferredPosition), forKey: key)
            }
        }
    }

    init(kind: Kind) {
        self.kind = kind
        switch kind {
        case .toggle:
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        case .separator:
            statusItem = NSStatusBar.system.statusItem(withLength: Self.separatorLength)
        case .alwaysHiddenSeparator:
            statusItem = NSStatusBar.system.statusItem(withLength: Self.inflatedLength)
        }
        statusItem.autosaveName = kind.autosaveName
        configureButton()
    }

    /// The window's left edge in global coordinates — the classification
    /// boundary for items in this section.
    var windowMinX: CGFloat? {
        statusItem.button?.window?.frame.minX
    }

    /// Separators: thin rule when expanded, inflated when hiding.
    func setExpanded(_ expanded: Bool) {
        guard kind != .toggle else { return }
        statusItem.length = expanded ? Self.separatorLength : Self.inflatedLength
        statusItem.button?.image = expanded ? Self.separatorImage() : nil
    }

    func updateToggleIcon(isExpanded: Bool) {
        guard kind == .toggle else { return }
        let symbol = isExpanded ? "chevron.right" : "chevron.left"
        let description = isExpanded ? "Hide menu bar items" : "Show hidden menu bar items"
        statusItem.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: description)
    }

    func updateBadge(unseenCount: Int) {
        guard kind == .toggle else { return }
        statusItem.button?.title = unseenCount > 0 ? " \(unseenCount)" : ""
        statusItem.button?.setAccessibilityValue(unseenCount > 0 ? "\(unseenCount) unseen updates" : "No unseen updates")
    }

    func remove() {
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    // MARK: - Setup

    private func configureButton() {
        guard let button = statusItem.button else { return }
        switch kind {
        case .toggle:
            updateToggleIcon(isExpanded: false)
            button.target = self
            button.action = #selector(toggleClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        case .separator:
            button.image = Self.separatorImage()
            button.appearsDisabled = true
        case .alwaysHiddenSeparator:
            button.image = nil
            button.appearsDisabled = true
        }
    }

    @objc private func toggleClicked() {
        guard let event = NSApp.currentEvent else {
            onToggle?()
            return
        }
        if event.type == .rightMouseUp {
            showContextMenu()
        } else if event.modifierFlags.contains(.option) {
            onToggleAlwaysHidden?()
        } else {
            onToggle?()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()

        let peek = NSMenuItem(title: "Show Quiet Items", action: #selector(menuToggleAlwaysHidden), keyEquivalent: "")
        peek.target = self
        menu.addItem(peek)

        let search = NSMenuItem(title: "Quick Search…", action: #selector(menuQuickSearch), keyEquivalent: "")
        search.target = self
        menu.addItem(search)

        let topShelf = NSMenuItem(title: "Top Shelf", action: #selector(menuTopShelf), keyEquivalent: "")
        topShelf.target = self
        menu.addItem(topShelf)

        menu.addItem(.separator())

        let settings = NSMenuItem(title: "Menu Bar Settings…", action: #selector(menuOpenSettings), keyEquivalent: "")
        settings.target = self
        menu.addItem(settings)

        let disable = NSMenuItem(title: "Turn Off Menu Bar Management", action: #selector(menuDisable), keyEquivalent: "")
        disable.target = self
        menu.addItem(disable)

        // Transient menu: attach, pop, detach — keeps left-click as a plain action.
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func menuToggleAlwaysHidden() { onToggleAlwaysHidden?() }
    @objc private func menuOpenSettings() { onOpenSettings?() }
    @objc private func menuDisable() { onDisable?() }
    @objc private func menuQuickSearch() { QuickSearchPanelController.shared.show() }
    @objc private func menuTopShelf() { TopShelfCoordinator.shared.deliberateOpen() }

    private static func separatorImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 8, height: 16), flipped: false) { rect in
            NSColor.labelColor.withAlphaComponent(0.45).setFill()
            NSRect(x: rect.midX - 0.5, y: 2, width: 1, height: rect.height - 4).fill()
            return true
        }
        image.isTemplate = true
        return image
    }
}
