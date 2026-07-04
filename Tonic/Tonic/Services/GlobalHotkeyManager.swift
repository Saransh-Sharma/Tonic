//
//  GlobalHotkeyManager.swift
//  Tonic
//
//  Global keyboard shortcut for toggling the primary menu-bar console.
//  Uses Carbon RegisterEventHotKey: system-wide, sandbox-safe, and needs no
//  Accessibility permission (unlike NSEvent global key monitors).
//

import AppKit
import Carbon.HIToolbox

// MARK: - Shortcut Spec

/// A recorded global shortcut: Carbon key code + Carbon modifier flags.
/// Serialized as "keyCode:modifiers" into `PopupSettings.keyboardShortcut`.
public struct ShortcutSpec: Equatable, Sendable {
    public let keyCode: UInt32
    public let carbonModifiers: UInt32

    public init(keyCode: UInt32, carbonModifiers: UInt32) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
    }

    public init?(string: String) {
        let parts = string.split(separator: ":")
        guard parts.count == 2,
              let code = UInt32(parts[0]),
              let mods = UInt32(parts[1]) else { return nil }
        self.init(keyCode: code, carbonModifiers: mods)
    }

    /// From a recorder keyDown event. Requires ⌘, ⌃, or ⌥ so plain typing
    /// can't become a system-wide hotkey.
    public init?(event: NSEvent) {
        let mods = Self.carbonModifiers(from: event.modifierFlags)
        guard mods & (UInt32(cmdKey) | UInt32(controlKey) | UInt32(optionKey)) != 0 else { return nil }
        self.init(keyCode: UInt32(event.keyCode), carbonModifiers: mods)
    }

    public var stringValue: String { "\(keyCode):\(carbonModifiers)" }

    public static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var mods: UInt32 = 0
        if flags.contains(.command) { mods |= UInt32(cmdKey) }
        if flags.contains(.option) { mods |= UInt32(optionKey) }
        if flags.contains(.control) { mods |= UInt32(controlKey) }
        if flags.contains(.shift) { mods |= UInt32(shiftKey) }
        return mods
    }

    /// "⌃⌥⇧⌘M"-style rendering for the settings row.
    public var displayString: String {
        var out = ""
        if carbonModifiers & UInt32(controlKey) != 0 { out += "⌃" }
        if carbonModifiers & UInt32(optionKey) != 0 { out += "⌥" }
        if carbonModifiers & UInt32(shiftKey) != 0 { out += "⇧" }
        if carbonModifiers & UInt32(cmdKey) != 0 { out += "⌘" }
        return out + Self.keyName(for: keyCode)
    }

    static func keyName(for keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case kVK_Space: return "Space"
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Escape: return "⎋"
        case kVK_Delete: return "⌫"
        case kVK_ForwardDelete: return "⌦"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_Home: return "↖"
        case kVK_End: return "↘"
        case kVK_PageUp: return "⇞"
        case kVK_PageDown: return "⇟"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        default:
            return layoutCharacter(for: keyCode) ?? "Key \(keyCode)"
        }
    }

    /// Character for the key under the current keyboard layout.
    private static func layoutCharacter(for keyCode: UInt32) -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutDataPtr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }
        let layoutData = Unmanaged<CFData>.fromOpaque(layoutDataPtr).takeUnretainedValue() as Data
        return layoutData.withUnsafeBytes { rawBuffer -> String? in
            guard let keyboardLayout = rawBuffer.bindMemory(to: UCKeyboardLayout.self).baseAddress else {
                return nil
            }
            var deadKeyState: UInt32 = 0
            var chars = [UniChar](repeating: 0, count: 4)
            var length = 0
            let error = UCKeyTranslate(
                keyboardLayout,
                UInt16(keyCode),
                UInt16(kUCKeyActionDisplay),
                0,
                UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                chars.count,
                &length,
                &chars
            )
            guard error == noErr, length > 0 else { return nil }
            return String(utf16CodeUnits: chars, count: length).uppercased()
        }
    }
}

// MARK: - Global Hotkey Manager

/// Registers the persisted popup shortcut system-wide and toggles the primary
/// menu-bar console when it fires.
@MainActor
@Observable
public final class GlobalHotkeyManager {

    public static let shared = GlobalHotkeyManager()

    /// Actions whose last registration was rejected (usually a conflict with
    /// another app's hotkey) — surfaced in the recorder rows.
    public private(set) var registrationFailures: Set<HotkeyAction> = []

    /// Legacy alias retained for the console recorder call site.
    public var registrationFailed: Bool { registrationFailures.contains(.toggleConsole) }

    private var hotKeyRefs: [HotkeyAction: EventHotKeyRef] = [:]
    private var eventHandler: EventHandlerRef?

    private static let signature: OSType = 0x544F_4E43 // 'TONC'

    private init() {}

    /// Install the Carbon handler and register all persisted shortcuts.
    public func start() {
        installHandlerIfNeeded()
        applyAll()
    }

    /// Re-read the hotkey store and (re)register every slot.
    public func applyAll() {
        for action in HotkeyAction.allCases {
            register(action, spec: HotkeySettingsStore.shared.spec(for: action))
        }
    }

    /// Legacy name kept for existing call sites (TonicApp, recorder).
    public func applyCurrentShortcut() { applyAll() }

    private func register(_ action: HotkeyAction, spec: ShortcutSpec?) {
        if let existing = hotKeyRefs[action] {
            UnregisterEventHotKey(existing)
            hotKeyRefs[action] = nil
        }
        registrationFailures.remove(action)

        guard let spec else { return }

        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: action.hotKeyID)
        let status = RegisterEventHotKey(
            spec.keyCode,
            spec.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        if status == noErr, let ref {
            hotKeyRefs[action] = ref
        } else {
            registrationFailures.insert(action)
        }
    }

    private func installHandlerIfNeeded() {
        guard eventHandler == nil else { return }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            guard hotKeyID.signature == GlobalHotkeyManager.signature else { return noErr }
            let firedID = hotKeyID.id
            Task { @MainActor in
                GlobalHotkeyManager.shared.dispatch(hotKeyID: firedID)
            }
            return noErr
        }, 1, &eventType, nil, &eventHandler)
    }

    private func dispatch(hotKeyID: UInt32) {
        guard let action = HotkeyAction.allCases.first(where: { $0.hotKeyID == hotKeyID }) else { return }
        switch action {
        case .toggleConsole:
            WidgetCoordinator.shared.togglePrimaryPopover()
        case .quickSearch:
            QuickSearchPanelController.shared.toggle()
        case .toggleMenuBar:
            MenuBarManager.shared.toggle()
        }
    }
}
