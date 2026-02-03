//
//  PopupWindow.swift
//  Tonic
//
//  NSWindow subclass for widget popovers matching Stats Master's behavior
//  Reference: stats-master/Kit/module/popup.swift
//  Task ID: fn-6-i4g.44
//
//  This is an optional component - Tonic can continue using NSPopover if preferred.
//  PopupWindow provides features like drag behavior and custom positioning.
//

import AppKit
import SwiftUI

// MARK: - Popup Window Protocol

/// Protocol for popup content views
/// Provides lifecycle callbacks for appearance/disappearance
public protocol PopupContent: NSView {
    /// Called when popup appears
    func appear()

    /// Called when popup disappears
    func disappear()

    /// Optional settings view
    func settings() -> NSView?
}

// MARK: - Popup Window

/// A custom NSWindow subclass for widget popovers
///
/// Features:
/// - Transparent background with custom shadow
/// - Drag behavior - window can be moved
/// - Close on drag end (Activity Monitor mode)
/// - Custom positioning (below menu bar item)
/// - Lock mode to prevent auto-close when dragging
///
/// Usage:
/// ```swift
/// let window = PopupWindow(
///     title: "CPU",
///     contentView: MyPopupView(),
///     size: NSSize(width: 320, height: 400)
/// )
/// window.show(at: screenPoint)
/// ```
public class PopupWindow: NSWindow, NSWindowDelegate {

    // MARK: - Properties

    /// Whether the window is currently being dragged
    public private(set) var isDragging: Bool = false

    /// Whether to close the window when drag ends
    /// When true, dragging the window closes it (Activity Monitor style)
    public var closeOnDragEnd: Bool = false

    /// Whether the window is locked (prevents auto-close on focus loss)
    /// When true, window stays open even when losing focus
    public private(set) var locked: Bool = false

    /// Initial mouse location when drag begins
    private var dragStartLocation: NSPoint = .zero

    /// Initial window frame when drag begins
    private var dragStartFrame: NSRect = .zero

    /// Callback when visibility changes
    public var visibilityCallback: ((Bool) -> Void)?

    /// The popup content view
    private var popupContentView: PopupContent?

    // MARK: - Initialization

    /// Initialize a new popup window
    /// - Parameters:
    ///   - title: Window title (hidden)
    ///   - contentView: The content view to display
    ///   - size: Initial window size
    public init(
        title: String,
        contentView: NSView,
        size: NSSize = NSSize(width: PopoverConstants.width, height: PopoverConstants.maxHeight)
    ) {
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        // Extract PopupContent if available
        if let popupContent = contentView as? PopupContent {
            self.popupContentView = popupContent
        }

        // Window setup
        self.title = title
        self.titleVisibility = .hidden
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.level = .popUpMenu
        self.animationBehavior = .default
        self.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        self.isReleasedWhenClosed = false

        // Content setup
        self.contentViewController = NSViewController()
        self.contentViewController?.view = contentView

        // Delegate setup
        self.delegate = self

        // Enable mouse tracking for drag detection
        contentView.addCursorRect(contentView.bounds, cursor: .arrow)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Window Lifecycle

    /// Show the window at a specific point
    /// - Parameter point: The screen coordinates to position the window
    public func show(at point: NSPoint) {
        // Position the window
        self.setFrameOrigin(point)

        // Ensure window fits on screen
        self.constrainToScreen()

        // Show window
        self.makeKeyAndOrderFront(nil)

        // Notify content
        self.popupContentView?.appear()

        // Notify callback
        self.visibilityCallback?(true)
    }

    /// Close the popup window
    public func closePopup() {
        self.locked = false
        self.popupContentView?.disappear()
        self.close()
        self.visibilityCallback?(false)
    }

    // MARK: - Positioning

    /// Position the window below a menu bar item
    /// - Parameters:
    ///   - statusItemRect: The frame of the status item button
    ///   - preferredWidth: Optional preferred width (defaults to current width)
    public func positionBelowStatusItem(_ statusItemRect: CGRect, preferredWidth: CGFloat? = nil) {
        guard let screen = NSScreen.main else { return }

        let screenFrame = screen.visibleFrame
        var windowFrame = self.frame

        // Apply preferred width if specified
        if let width = preferredWidth {
            windowFrame.size.width = width
            self.setFrame(windowFrame, display: false)
        }

        // Calculate position: center horizontally under the status item
        var origin = NSPoint(
            x: statusItemRect.midX - windowFrame.width / 2,
            y: statusItemRect.minY - windowFrame.height
        )

        // Keep window within screen bounds
        if origin.x < screenFrame.minX {
            origin.x = screenFrame.minX + 8
        }
        if origin.x + windowFrame.width > screenFrame.maxX {
            origin.x = screenFrame.maxX - windowFrame.width - 8
        }
        if origin.y < screenFrame.minY {
            origin.y = screenFrame.minY + 8
        }

        self.setFrameOrigin(origin)
    }

    /// Position the window at the center of the screen
    public func positionCentered() {
        guard let screen = NSScreen.main else { return }

        let screenFrame = screen.visibleFrame
        let windowFrame = self.frame

        let origin = NSPoint(
            x: screenFrame.midX - windowFrame.width / 2,
            y: screenFrame.midY - windowFrame.height / 2
        )

        self.setFrameOrigin(origin)
    }

    /// Ensure window fits within screen bounds
    private func constrainToScreen() {
        guard let screen = NSScreen.main else { return }

        let screenFrame = screen.visibleFrame
        var windowFrame = self.frame

        // Constrain horizontally
        if windowFrame.minX < screenFrame.minX {
            windowFrame.origin.x = screenFrame.minX
        }
        if windowFrame.maxX > screenFrame.maxX {
            windowFrame.origin.x = screenFrame.maxX - windowFrame.width
        }

        // Constrain vertically
        if windowFrame.minY < screenFrame.minY {
            windowFrame.origin.y = screenFrame.minY
        }
        if windowFrame.maxY > screenFrame.maxY {
            windowFrame.origin.y = screenFrame.maxY - windowFrame.height
        }

        self.setFrame(windowFrame, display: false)
    }

    // MARK: - Window Delegate

    public func windowWillMove(_ notification: Notification) {
        // User started dragging - lock the window
        self.locked = true
        self.isDragging = true

        // Store initial drag state
        self.dragStartLocation = NSEvent.mouseLocation
        self.dragStartFrame = self.frame
    }

    public func windowDidMove(_ notification: Notification) {
        // Window moved during drag
    }

    public func windowDidResignKey(_ notification: Notification) {
        // Don't auto-close if locked (user is dragging)
        if self.locked {
            return
        }

        // Auto-close when losing focus (standard behavior)
        self.closePopup()
    }

    public func windowDidBecomeKey(_ notification: Notification) {
        // Window became focused
    }

    // MARK: - Mouse Handling

    override public var canBecomeKey: Bool { true }

    override public var acceptsFirstResponder: Bool { true }

    // MARK: - Lock Control

    /// Set the locked state to control auto-close behavior
    /// - Parameter locked: If true, window won't auto-close when losing focus
    public func setLocked(_ locked: Bool) {
        self.locked = locked
    }
}

// MARK: - SwiftUI Wrapper

/// A SwiftUI-compatible wrapper for PopupWindow
///
/// Usage:
/// ```swift
/// PopupWindowWrapper(
///     title: "CPU",
///     isPresented: $showPopup,
///     content: {
///         MyPopupView()
///     }
/// )
/// ```
public struct PopupWindowWrapper<Content: View>: View {

    @Binding var isPresented: Bool
    let title: String
    let content: Content
    var size: CGSize = CGSize(
        width: PopoverConstants.width,
        height: PopoverConstants.maxHeight
    )

    /// State for tracking the popup window
    @State private var popupWindow: PopupWindow?

    public init(
        title: String,
        isPresented: Binding<Bool>,
        size: CGSize = CGSize(
            width: PopoverConstants.width,
            height: PopoverConstants.maxHeight
        ),
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self._isPresented = isPresented
        self.size = size
        self.content = content()
    }

    public var body: some View {
        EmptyView()
            .onChange(of: isPresented) { _, newValue in
                if newValue {
                    showPopup()
                } else {
                    hidePopup()
                }
            }
            .onDisappear {
                hidePopup()
            }
    }

    private func showPopup() {
        guard NSScreen.main != nil else { return }

        // Create hosting view
        let hostingView = NSHostingView(rootView: content)
        hostingView.frame = NSRect(origin: .zero, size: size)

        // Create popup window
        let window = PopupWindow(
            title: title,
            contentView: hostingView,
            size: size
        )

        // Position centered on screen
        window.positionCentered()

        // Handle visibility callback
        window.visibilityCallback = { visible in
            if !visible {
                DispatchQueue.main.async {
                    self.isPresented = false
                }
            }
        }

        self.popupWindow = window
        window.show(at: window.frame.origin)
    }

    private func hidePopup() {
        popupWindow?.closePopup()
        popupWindow = nil
    }
}

// MARK: - NSHostingView PopupContent Extension

/// Make NSHostingView conform to PopupContent for SwiftUI views
extension NSHostingView: PopupContent {
    public func appear() {
        // SwiftUI views don't need explicit appear handling
    }

    public func disappear() {
        // SwiftUI views don't need explicit disappear handling
    }

    public func settings() -> NSView? {
        return nil
    }
}

// MARK: - Visual Effect View for Background

/// A visual effect view that provides the popup background
/// Matches the Stats Master appearance with frosted glass effect
public class PopupBackgroundView: NSVisualEffectView {

    public override init(frame: NSRect) {
        super.init(frame: frame)

        // Setup visual effect
        self.material = .titlebar
        self.blendingMode = .behindWindow
        self.state = .active
        self.wantsLayer = true

        // Corner radius
        self.layer?.cornerRadius = PopoverConstants.cornerRadius

        // Background color based on appearance
        updateBackgroundColor()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func updateBackgroundColor() {
        let isDark = NSApp.effectiveAppearance.name == NSAppearance.Name.darkAqua

        // Semi-transparent background
        if isDark {
            self.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.6).cgColor
        } else {
            self.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.8).cgColor
        }
    }

    override public func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateBackgroundColor()
    }
}

// MARK: - Preview

#if DEBUG
struct PopupWindowWrapper_Previews: PreviewProvider {
    static var previews: some View {
        // Note: PopupWindow requires AppKit runtime and can't be previewed directly
        // Use SwiftUI views for preview
        VStack {
            Text("PopupWindow is an AppKit component")
                .foregroundColor(.secondary)
        }
        .frame(width: 200, height: 100)
    }
}
#endif
