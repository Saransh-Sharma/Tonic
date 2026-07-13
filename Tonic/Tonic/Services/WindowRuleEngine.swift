import AppKit
import Foundation
import Observation

private final class WindowRuleAXElementBox: @unchecked Sendable {
    let element: AXUIElement
    init(_ element: AXUIElement) { self.element = element }
}

private func windowRuleAXCallback(_ observer: AXObserver, _ element: AXUIElement,
                                  _ notification: CFString, _ context: UnsafeMutableRawPointer?) {
    let box = WindowRuleAXElementBox(element)
    let name = notification as String
    Task { @MainActor in WindowRuleEngine.shared.handleAXNotification(name, element: box.element) }
}

struct WindowRuleMatcher: Sendable {
    func winner(rules: [WindowRule], context: WindowRuleEvaluationContext) -> WindowRule? {
        rules.filter { matches($0, context: context) }.sorted(by: precedes).first
    }

    func matches(_ rule: WindowRule, context: WindowRuleEvaluationContext) -> Bool {
        guard rule.isEnabled, !rule.match.bundleIdentifier.isEmpty,
              rule.match.bundleIdentifier == context.bundleIdentifier else { return false }
        if let role = rule.match.role, role != context.role { return false }
        if let subrole = rule.match.subrole, subrole != context.subrole { return false }
        if let pattern = rule.match.titlePattern {
            guard let title = context.title,
                  let expression = try? NSRegularExpression(pattern: pattern),
                  expression.firstMatch(in: title, range: NSRange(title.startIndex..., in: title)) != nil else { return false }
        }
        if let display = rule.condition.display, display != context.display { return false }
        if let expected = rule.condition.context, expected != context.context { return false }
        if let fullScreen = rule.condition.fullScreen, fullScreen != context.isFullScreen { return false }
        return true
    }

    private func precedes(_ lhs: WindowRule, _ rhs: WindowRule) -> Bool {
        if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
        let left = specificity(lhs), right = specificity(rhs)
        if left != right { return left > right }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private func specificity(_ rule: WindowRule) -> Int {
        [rule.match.role != nil, rule.match.subrole != nil, rule.match.titlePattern != nil,
         rule.condition.display != nil, rule.condition.context != nil, rule.condition.fullScreen != nil]
            .filter { $0 }.count
    }
}

@MainActor
@Observable
final class WindowRuleStore {
    static let shared = WindowRuleStore()
    private static let key = "tonic.windowRules.v2"
    private(set) var rules: [WindowRule]

    private init(defaults: UserDefaults = .standard) {
        rules = defaults.data(forKey: Self.key).flatMap { try? JSONDecoder().decode([WindowRule].self, from: $0) } ?? []
    }

    func replace(_ rules: [WindowRule]) {
        self.rules = rules
        if let data = try? JSONEncoder().encode(rules) { UserDefaults.standard.set(data, forKey: Self.key) }
    }


    func add(_ rule: WindowRule) { replace(rules + [rule]) }

    func update(_ rule: WindowRule) {
        var values = rules
        if let index = values.firstIndex(where: { $0.id == rule.id }) { values[index] = rule }
        else { values.append(rule) }
        replace(values)
    }

    func remove(id: UUID) { replace(rules.filter { $0.id != id }) }
}

@MainActor
@Observable
final class WindowRuleEngine {
    static let shared = WindowRuleEngine()
    private(set) var lastReceipt: WindowRuleReceipt?
    private var launchObserver: NSObjectProtocol?
    private var activationObserver: NSObjectProtocol?
    private var screenObserver: NSObjectProtocol?
    private var accessibilityObservers: [pid_t: AXObserver] = [:]
    private var tasks: [pid_t: Task<Void, Never>] = [:]
    private var cooldownUntil: [String: Date] = [:]
    private var applyingUntil: [String: Date] = [:]

    func start() {
        guard launchObserver == nil else { return }
        launchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main
        ) { notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            Task { @MainActor in WindowRuleEngine.shared.applicationLaunched(app) }
        }
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            Task { @MainActor in
                WindowRuleEngine.shared.observeApplication(app)
                WindowRuleEngine.shared.reevaluateFrontmost(reason: "Application activated")
            }
        }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { _ in Task { @MainActor in WindowRuleEngine.shared.reevaluateFrontmost(reason: "Display changed", reapplyOnly: true) } }
        for app in NSWorkspace.shared.runningApplications { observeApplication(app) }
    }

    func noteUserAdjustedWindow(bundleIdentifier: String, policy: WindowRulePolicy) {
        guard policy.ignoreAfterUserAdjustment else { return }
        cooldownUntil[bundleIdentifier] = Date().addingTimeInterval(policy.cooldownSeconds)
    }

    private func applicationLaunched(_ app: NSRunningApplication) {
        observeApplication(app)
        guard let bundleID = app.bundleIdentifier else { return }
        let candidates = WindowRuleStore.shared.rules.filter { $0.match.bundleIdentifier == bundleID && $0.policy.applyWhenWindowAppears }
        guard let delay = candidates.map(\.policy.delaySeconds).min() else { return }
        tasks[app.processIdentifier]?.cancel()
        tasks[app.processIdentifier] = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.reevaluateFrontmost(reason: "Matching window appeared")
        }
    }

    fileprivate func handleAXNotification(_ notification: String, element: AXUIElement) {
        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)
        guard let app = NSRunningApplication(processIdentifier: pid),
              let bundleID = app.bundleIdentifier else { return }
        if notification == kAXMovedNotification as String || notification == kAXResizedNotification as String {
            guard Date() >= applyingUntil[bundleID, default: .distantPast] else { return }
            if let policy = WindowRuleStore.shared.rules.first(where: { $0.match.bundleIdentifier == bundleID })?.policy {
                noteUserAdjustedWindow(bundleIdentifier: bundleID, policy: policy)
            }
            return
        }
        if notification == kAXWindowCreatedNotification as String
            || notification == kAXFocusedWindowChangedNotification as String {
            attachWindowNotifications(element, observer: accessibilityObservers[pid])
            scheduleEvaluation(app: app, reason: notification == kAXWindowCreatedNotification as String
                ? "Matching window appeared" : "Focused window changed")
        }
    }

    func observeApplication(_ app: NSRunningApplication) {
        let pid = app.processIdentifier
        guard pid > 0, accessibilityObservers[pid] == nil,
              WindowRuleStore.shared.rules.contains(where: { $0.match.bundleIdentifier == app.bundleIdentifier }) else { return }
        var observer: AXObserver?
        guard AXObserverCreate(pid, windowRuleAXCallback, &observer) == .success, let observer else { return }
        let application = AXUIElementCreateApplication(pid)
        AXObserverAddNotification(observer, application, kAXWindowCreatedNotification as CFString, nil)
        AXObserverAddNotification(observer, application, kAXFocusedWindowChangedNotification as CFString, nil)
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        accessibilityObservers[pid] = observer
        var focused: CFTypeRef?
        if AXUIElementCopyAttributeValue(application, kAXFocusedWindowAttribute as CFString, &focused) == .success,
           let focused { attachWindowNotifications(focused as! AXUIElement, observer: observer) }
    }

    private func attachWindowNotifications(_ window: AXUIElement, observer: AXObserver?) {
        guard let observer else { return }
        AXObserverAddNotification(observer, window, kAXMovedNotification as CFString, nil)
        AXObserverAddNotification(observer, window, kAXResizedNotification as CFString, nil)
    }

    private func scheduleEvaluation(app: NSRunningApplication, reason: String) {
        guard let bundleID = app.bundleIdentifier else { return }
        let candidates = WindowRuleStore.shared.rules.filter {
            $0.match.bundleIdentifier == bundleID && $0.policy.applyWhenWindowAppears
        }
        guard let delay = candidates.map(\.policy.delaySeconds).min() else { return }
        tasks[app.processIdentifier]?.cancel()
        tasks[app.processIdentifier] = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.reevaluateFrontmost(reason: reason)
        }
    }

    fileprivate func reevaluateFrontmost(reason: String, reapplyOnly: Bool = false) {
        guard DistributionEdition.current == .direct, AXIsProcessTrusted(),
              let app = NSWorkspace.shared.frontmostApplication,
              let bundleID = app.bundleIdentifier,
              Date() >= cooldownUntil[bundleID, default: .distantPast] else { return }
        let context = WindowRuleEvaluationContext(bundleIdentifier: bundleID, role: nil, subrole: nil,
            title: WindowManagementService.shared.focusedWindowTitle, display: nil,
            context: MenuBarProfileStore.shared.selectedManualContextID.map(WindowRuleContext.manual),
            isFullScreen: NSApp.presentationOptions.contains(.fullScreen))
        let eligible = WindowRuleStore.shared.rules.filter { !reapplyOnly || $0.policy.reapplyOnDisplayOrContextChange }
        guard let rule = WindowRuleMatcher().winner(rules: eligible, context: context) else { return }
        let originalFrame = WindowManagementService.shared.focusedFrame
        applyingUntil[bundleID] = Date().addingTimeInterval(1.5)
        WindowManagementService.shared.perform(rule.action)
        lastReceipt = WindowRuleReceipt(ruleID: rule.id, matchedReason: reason,
            originalFrame: originalFrame,
            appliedFrame: WindowManagementService.shared.focusedFrame,
            failure: WindowManagementService.shared.lastError)
        cooldownUntil[bundleID] = Date().addingTimeInterval(rule.policy.cooldownSeconds)
    }
}
