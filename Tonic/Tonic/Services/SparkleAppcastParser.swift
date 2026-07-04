//
//  SparkleAppcastParser.swift
//  Tonic
//
//  Proper XMLParser-based parsing of Sparkle appcast feeds, replacing the
//  regex approach that could never match real feeds. Handles both metadata
//  shapes found in the wild:
//
//    1. Element style:
//         <item>
//           <sparkle:version>2029</sparkle:version>
//           <sparkle:shortVersionString>1.4.2</sparkle:shortVersionString>
//           <enclosure url="…" length="…"/>
//         </item>
//
//    2. Enclosure-attribute style (most common):
//         <item>
//           <enclosure url="…" sparkle:version="2029"
//                      sparkle:shortVersionString="1.4.2" length="…"/>
//         </item>
//
//  Also respects <sparkle:channel> (non-default channels are excluded) and
//  <sparkle:minimumSystemVersion> (items requiring a newer macOS are excluded).
//

import Foundation

/// One `<item>` from an appcast feed.
struct AppcastItem: Sendable, Equatable {
    var title: String?
    /// `sparkle:version` — the build number (CFBundleVersion).
    var version: String?
    /// `sparkle:shortVersionString` — the marketing version (CFBundleShortVersionString).
    var shortVersionString: String?
    var enclosureURL: URL?
    var enclosureLength: Int64?
    var minimumSystemVersion: String?
    var channel: String?
    var pubDate: String?
    var releaseNotesLink: String?
    var descriptionHTML: String?
    var edSignature: String?

    /// The version to show and compare against CFBundleShortVersionString.
    var displayVersion: String? { shortVersionString ?? version }
}

enum AppcastError: Error, Equatable {
    case malformedXML(String)
    case noItems
    case noCompatibleItems
}

final class SparkleAppcastParser: NSObject, XMLParserDelegate {

    // MARK: - Public API

    /// Parse appcast data into items. Throws `AppcastError.malformedXML` on
    /// invalid XML and `.noItems` when the feed has no `<item>` entries.
    static func parseItems(from data: Data) throws -> [AppcastItem] {
        let delegate = SparkleAppcastParser()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldProcessNamespaces = false
        guard parser.parse() else {
            let reason = parser.parserError?.localizedDescription ?? "unknown parser error"
            throw AppcastError.malformedXML(reason)
        }
        guard !delegate.items.isEmpty else { throw AppcastError.noItems }
        return delegate.items
    }

    /// The newest item that runs on this macOS and sits on the default channel.
    /// Throws `.noCompatibleItems` when every item is excluded.
    static func bestItem(
        from data: Data,
        currentOS: OperatingSystemVersion = ProcessInfo.processInfo.operatingSystemVersion
    ) throws -> AppcastItem {
        let items = try parseItems(from: data)
        let candidates = items.filter { item in
            isDefaultChannel(item.channel) && isCompatible(item.minimumSystemVersion, with: currentOS)
        }
        guard let best = candidates.max(by: { lhs, rhs in
            SemanticVersion(lhs.displayVersion ?? "") < SemanticVersion(rhs.displayVersion ?? "")
        }), best.displayVersion != nil else {
            throw AppcastError.noCompatibleItems
        }
        return best
    }

    // MARK: - Selection rules

    /// Sparkle's default channel is "no channel element"; anything named is opt-in.
    static func isDefaultChannel(_ channel: String?) -> Bool {
        guard let channel, !channel.isEmpty else { return true }
        return channel.lowercased() == "release" || channel.lowercased() == "stable"
    }

    static func isCompatible(_ minimumSystemVersion: String?, with os: OperatingSystemVersion) -> Bool {
        guard let minimumSystemVersion, !minimumSystemVersion.isEmpty else { return true }
        let required = SemanticVersion(minimumSystemVersion)
        let current = SemanticVersion("\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)")
        return !(current < required)
    }

    // MARK: - XMLParserDelegate state

    private var items: [AppcastItem] = []
    private var currentItem: AppcastItem?
    private var currentElement = ""
    private var currentText = ""

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentElement = elementName
        currentText = ""

        switch elementName {
        case "item":
            currentItem = AppcastItem()
        case "enclosure":
            guard currentItem != nil else { return }
            if let urlString = attributeDict["url"], let url = URL(string: urlString) {
                currentItem?.enclosureURL = url
            }
            if let lengthString = attributeDict["length"], let length = Int64(lengthString) {
                currentItem?.enclosureLength = length
            }
            // Attribute-style metadata wins only when the element form is absent.
            if currentItem?.version == nil {
                currentItem?.version = attributeDict["sparkle:version"]
            }
            if currentItem?.shortVersionString == nil {
                currentItem?.shortVersionString = attributeDict["sparkle:shortVersionString"]
            }
            if currentItem?.minimumSystemVersion == nil {
                currentItem?.minimumSystemVersion = attributeDict["sparkle:minimumSystemVersion"]
            }
            currentItem?.edSignature = attributeDict["sparkle:edSignature"]
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        guard currentItem != nil else {
            if elementName == "item" { currentItem = nil }
            return
        }
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        switch elementName {
        case "item":
            if let item = currentItem { items.append(item) }
            currentItem = nil
        case "title":
            if currentItem?.title == nil, !text.isEmpty { currentItem?.title = text }
        case "sparkle:version":
            if !text.isEmpty { currentItem?.version = text }
        case "sparkle:shortVersionString":
            if !text.isEmpty { currentItem?.shortVersionString = text }
        case "sparkle:minimumSystemVersion":
            if !text.isEmpty { currentItem?.minimumSystemVersion = text }
        case "sparkle:channel":
            if !text.isEmpty { currentItem?.channel = text }
        case "sparkle:releaseNotesLink":
            if !text.isEmpty { currentItem?.releaseNotesLink = text }
        case "pubDate":
            if !text.isEmpty { currentItem?.pubDate = text }
        case "description":
            if !text.isEmpty { currentItem?.descriptionHTML = text }
        default:
            break
        }
        currentText = ""
    }
}
