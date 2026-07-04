//
//  SemanticVersion.swift
//  Tonic
//
//  Version comparison for app-update checks. Handles the shapes that appear
//  in real appcasts and Info.plists: "1.2.3", "v2.0", "1.2.0b3", "3.5-beta.2",
//  "141.0.7390.55". A version with a pre-release suffix orders BELOW the same
//  version without one (1.2.0b3 < 1.2.0).
//

import Foundation

struct SemanticVersion: Comparable, Equatable, CustomStringConvertible, Sendable {
    /// Dot-separated numeric components ("1.2.3" → [1, 2, 3]).
    let numbers: [Int]
    /// Anything after the numeric core ("1.2.0b3" → "b3", "1.0-beta.2" → "beta.2").
    let prerelease: String?
    /// The original string, preserved for display.
    let raw: String

    init(_ string: String) {
        raw = string
        var s = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("v") || s.hasPrefix("V") {
            s = String(s.dropFirst())
        }

        // Numeric core: leading digits and dots. Remainder is the pre-release tag.
        var coreEnd = s.startIndex
        while coreEnd < s.endIndex, s[coreEnd].isNumber || s[coreEnd] == "." {
            coreEnd = s.index(after: coreEnd)
        }
        let core = s[s.startIndex..<coreEnd]
        var tail = s[coreEnd...].trimmingCharacters(in: CharacterSet(charactersIn: " -_.+("))
        if tail.hasSuffix(")") { tail.removeLast() }

        numbers = core.split(separator: ".").compactMap { Int($0) }
        prerelease = tail.isEmpty ? nil : tail
    }

    var description: String { raw }

    /// True when the string produced no usable numeric components.
    var isEmpty: Bool { numbers.isEmpty }

    static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        let count = max(lhs.numbers.count, rhs.numbers.count)
        for i in 0..<count {
            let l = i < lhs.numbers.count ? lhs.numbers[i] : 0
            let r = i < rhs.numbers.count ? rhs.numbers[i] : 0
            if l != r { return l < r }
        }
        // Equal numeric cores: a pre-release orders below the release.
        switch (lhs.prerelease, rhs.prerelease) {
        case (nil, nil): return false
        case (.some, nil): return true
        case (nil, .some): return false
        case let (.some(l), .some(r)):
            return l.compare(r, options: [.numeric, .caseInsensitive]) == .orderedAscending
        }
    }

    static func == (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        !(lhs < rhs) && !(rhs < lhs)
    }
}
