//
//  MenuBarRecommendationPlanner.swift
//  Tonic
//
//  Trust-first cleanup recommendations. The planner is deliberately pure so
//  onboarding can explain every suggestion before requesting Accessibility.
//

import Foundation

public struct MenuBarRecommendationCandidate: Equatable, Sendable {
    public var stableKey: String
    public var ownerName: String
    public var bundleIdentifier: String?
    public var isSystemControlled: Bool

    public init(stableKey: String, ownerName: String, bundleIdentifier: String? = nil,
                isSystemControlled: Bool = false) {
        self.stableKey = stableKey
        self.ownerName = ownerName
        self.bundleIdentifier = bundleIdentifier
        self.isSystemControlled = isSystemControlled
    }
}

public struct MenuBarRecommendation: Identifiable, Equatable, Sendable {
    public enum Confidence: String, Codable, Sendable { case protected, high, insufficient }
    public var id: String { stableKey }
    public let stableKey: String
    public let target: MenuBarSection
    public let reason: String
    public let confidence: Confidence
    public var isPreselected: Bool
}

public struct MenuBarRecommendationPlanner: Sendable {
    public let knownUtilityBundleIdentifiers: Set<String>

    public init(knownUtilityBundleIdentifiers: Set<String> = Self.defaultKnownUtilities) {
        self.knownUtilityBundleIdentifiers = knownUtilityBundleIdentifiers
    }

    public func recommendations(for candidates: [MenuBarRecommendationCandidate]) -> [MenuBarRecommendation] {
        candidates.map(recommendation).sorted { $0.stableKey < $1.stableKey }
    }

    public func recommendation(for candidate: MenuBarRecommendationCandidate) -> MenuBarRecommendation {
        let owner = candidate.ownerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let bundle = candidate.bundleIdentifier?.lowercased()
        if candidate.isSystemControlled || isProtected(owner: owner, bundleIdentifier: bundle) {
            return MenuBarRecommendation(stableKey: candidate.stableKey, target: .visible,
                                         reason: "Kept visible because it is a system, connectivity, battery, clock, or Tonic control.",
                                         confidence: .protected, isPreselected: false)
        }
        guard let bundle, knownUtilityBundleIdentifiers.contains(bundle) else {
            return MenuBarRecommendation(stableKey: candidate.stableKey, target: .visible,
                                         reason: "Kept visible because Tonic cannot identify this item with high confidence.",
                                         confidence: .insufficient, isPreselected: false)
        }
        return MenuBarRecommendation(stableKey: candidate.stableKey, target: .hidden,
                                     reason: "Known third-party utility; available instantly from Quick Shelf.",
                                     confidence: .high, isPreselected: true)
    }

    private func isProtected(owner: String, bundleIdentifier: String?) -> Bool {
        if owner.isEmpty || owner.caseInsensitiveCompare("Unknown") == .orderedSame { return true }
        let normalized = owner.lowercased()
        let protectedTerms = ["control center", "controlcenter", "systemuiserver", "clock", "battery",
                              "wi-fi", "wifi", "bluetooth", "spotlight", "siri", "tonic"]
        if protectedTerms.contains(where: normalized.contains) { return true }
        guard let bundleIdentifier else { return true }
        return bundleIdentifier.hasPrefix("com.apple.") || bundleIdentifier.hasPrefix("com.saransh.tonic")
    }

    public static let defaultKnownUtilities: Set<String> = [
        "com.1password.1password", "com.agilebits.onepassword7", "com.culturedcode.thingsmac",
        "com.dropbox.dropbox", "com.google.drivefs", "com.microsoft.onedrive",
        "com.getcleanshot.app", "com.iconfactory.xscope", "com.macpaw.cleanshotx",
        "com.raycast.macos", "com.runningwithcrayons.alfred", "com.setapp.desktop-client",
        "com.tinyspeck.slackmacgap", "com.toggl.toggldesktop", "com.vitorgalvao.shortcutkeeper"
    ]
}
