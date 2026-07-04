//
//  AppUpdater.swift
//  Tonic
//
//  Service for checking and managing app updates
//

import Foundation
import SwiftData

// MARK: - App Update Models

/// Where an app's updates come from, which determines how Tonic can apply them.
enum UpdateSource: String, Sendable, Codable {
    case sparkle
    case macAppStore
    case homebrewCask
    case unknown

    var displayName: String {
        switch self {
        case .sparkle: return "Sparkle"
        case .macAppStore: return "App Store"
        case .homebrewCask: return "Homebrew"
        case .unknown: return "Unknown"
        }
    }
}

/// Represents an available update for an installed app
struct AppUpdate: Identifiable, Sendable, Codable {
    let id: UUID
    let bundleIdentifier: String
    let appName: String
    let currentVersion: String?
    let latestVersion: String
    let appPath: URL
    let updateAvailable: Bool
    let updateURL: URL?
    let releaseNotes: String?
    let lastChecked: Date
    let source: UpdateSource
    let minimumSystemVersion: String?
    let enclosureLength: Int64?
    let edSignature: String?
    /// App Store track identifier, used for `macappstore://` deep links.
    let trackId: Int?

    public init(
        bundleIdentifier: String,
        appName: String,
        currentVersion: String?,
        latestVersion: String,
        appPath: URL,
        updateAvailable: Bool,
        updateURL: URL? = nil,
        releaseNotes: String? = nil,
        lastChecked: Date = Date(),
        source: UpdateSource = .unknown,
        minimumSystemVersion: String? = nil,
        enclosureLength: Int64? = nil,
        edSignature: String? = nil,
        trackId: Int? = nil
    ) {
        self.id = UUID()
        self.bundleIdentifier = bundleIdentifier
        self.appName = appName
        self.currentVersion = currentVersion
        self.latestVersion = latestVersion
        self.appPath = appPath
        self.updateAvailable = updateAvailable
        self.updateURL = updateURL
        self.releaseNotes = releaseNotes
        self.lastChecked = lastChecked
        self.source = source
        self.minimumSystemVersion = minimumSystemVersion
        self.enclosureLength = enclosureLength
        self.edSignature = edSignature
        self.trackId = trackId
    }

    /// Version comparison result
    public enum VersionComparison {
        case upToDate      // Current == Latest
        case updateAvailable // Current < Latest
        case beta          // Current > Latest (might be beta)
        case unknown       // Cannot compare
    }

    /// Compare two version strings using semantic ordering (see SemanticVersion).
    static func compareVersions(_ current: String?, _ latest: String) -> VersionComparison {
        guard let current, !current.isEmpty else { return .unknown }
        let currentVersion = SemanticVersion(current)
        let latestVersion = SemanticVersion(latest)
        guard !currentVersion.isEmpty, !latestVersion.isEmpty else { return .unknown }
        if currentVersion < latestVersion { return .updateAvailable }
        if latestVersion < currentVersion { return .beta }
        return .upToDate
    }
}

/// Result of an update check operation
struct UpdateCheckResult: Sendable {
    let appsChecked: Int
    let updatesAvailable: Int
    let updates: [AppUpdate]
    let duration: TimeInterval
    let errors: [UpdateCheckError]

    var formattedDuration: String {
        String(format: "%.2fs", duration)
    }
}

/// Error during update checking
struct UpdateCheckError: Sendable, Error, LocalizedError, Identifiable {
    let id = UUID()
    let bundleIdentifier: String
    let appName: String?
    let errorType: ErrorType
    let underlyingError: String?

    init(bundleIdentifier: String, appName: String? = nil, errorType: ErrorType, underlyingError: String? = nil) {
        self.bundleIdentifier = bundleIdentifier
        self.appName = appName
        self.errorType = errorType
        self.underlyingError = underlyingError
    }

    public enum ErrorType: String, Sendable {
        case noBundleFound = "App Not Found"
        case noVersionInfo = "No Version Info"
        case networkError = "Network Error"
        case parseError = "Parse Error"
        case feedUnreachable = "Update Feed Unreachable"
        case badFeed = "Malformed Update Feed"
        case masLookupFailed = "App Store Lookup Failed"
        case rateLimited = "Rate Limited"
        case unknown = "Unknown Error"
    }

    var errorDescription: String? {
        var description = "\(errorType.rawValue): \(appName ?? bundleIdentifier)"
        if let underlying = underlyingError {
            description += " - \(underlying)"
        }
        return description
    }
}

// MARK: - App Update Checker Service

/// Service for checking app updates
@MainActor
@Observable
final class AppUpdater: @unchecked Sendable {

    // MARK: - Properties

    private let fileManager = FileManager.default
    private let lock = NSLock()

    private let urlSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        return URLSession(configuration: config)
    }()

    private static let userAgent: String = {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        return "Tonic/\(version)"
    }()

    private var _updates: [AppUpdate] = []
    private var _isChecking = false
    private var _lastCheckDate: Date?

    var updates: [AppUpdate] {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _updates
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _updates = newValue
        }
    }

    var isChecking: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _isChecking
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _isChecking = newValue
        }
    }

    var lastCheckDate: Date? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _lastCheckDate
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _lastCheckDate = newValue
        }
    }

    /// Apps that have updates available
    var availableUpdates: [AppUpdate] {
        updates.filter { $0.updateAvailable }
    }

    /// Count of available updates
    var updateCount: Int {
        availableUpdates.count
    }

    // MARK: - Singleton

    static let shared = AppUpdater()

    private init() {}

    // MARK: - Update Checking

    /// Check for updates for a specific app.
    ///
    /// Detection order: Mac App Store receipt (local, cheap) → Sparkle feed →
    /// unknown source. Throws `UpdateCheckError` when a source exists but the
    /// check fails; returns a non-updatable record when no source is known.
    func checkUpdate(for bundleIdentifier: String, currentVersion: String?, appPath: URL) async throws -> AppUpdate {
        let appName = displayName(forAppAt: appPath)

        if hasMASReceipt(appPath: appPath) {
            if let update = try await checkViaAppStore(
                bundleIdentifier: bundleIdentifier,
                appName: appName,
                currentVersion: currentVersion,
                appPath: appPath
            ) {
                return update
            }
            // Delisted from the store: fall through to other sources.
        }

        if let feedURL = sparkleFeedURL(forAppAt: appPath) {
            return try await checkViaSparkleFeed(
                feedURL: feedURL,
                bundleIdentifier: bundleIdentifier,
                appName: appName,
                currentVersion: currentVersion,
                appPath: appPath
            )
        }

        #if !TONIC_STORE
        // No receipt, no appcast — Homebrew's cask index may still know it.
        if let cask = HomebrewService.shared.cask(forAppAt: appPath) {
            let installed = currentVersion ?? cask.installedVersion
            let latest = cask.latestVersion ?? installed ?? "Unknown"
            let comparison = AppUpdate.compareVersions(installed, latest)
            return AppUpdate(
                bundleIdentifier: bundleIdentifier,
                appName: appName,
                currentVersion: installed,
                latestVersion: latest,
                appPath: appPath,
                updateAvailable: cask.outdated || comparison == .updateAvailable,
                source: .homebrewCask
            )
        }
        #endif

        return AppUpdate(
            bundleIdentifier: bundleIdentifier,
            appName: appName,
            currentVersion: currentVersion,
            latestVersion: currentVersion ?? "Unknown",
            appPath: appPath,
            updateAvailable: false,
            source: .unknown
        )
    }

    /// Check for updates for multiple apps
    /// - Parameter apps: Array of app metadata to check
    /// - Returns: UpdateCheckResult with all updates found and every check failure
    func checkUpdates(for apps: [AppMetadata]) async -> UpdateCheckResult {
        let startTime = Date()
        isChecking = true
        defer { isChecking = false }

        var allUpdates: [AppUpdate] = []
        var errors: [UpdateCheckError] = []

        // Check updates in batches to limit concurrent network requests
        let batchSize = 5
        var index = 0

        while index < apps.count {
            let batch = Array(apps[index..<min(index + batchSize, apps.count)])
            index += batchSize

            await withTaskGroup(of: Result<AppUpdate, UpdateCheckError>.self) { group in
                for app in batch {
                    group.addTask {
                        do {
                            let update = try await self.checkUpdate(
                                for: app.bundleIdentifier,
                                currentVersion: app.version,
                                appPath: app.path
                            )
                            return .success(update)
                        } catch let error as UpdateCheckError {
                            return .failure(error)
                        } catch {
                            return .failure(UpdateCheckError(
                                bundleIdentifier: app.bundleIdentifier,
                                appName: app.appName,
                                errorType: .unknown,
                                underlyingError: error.localizedDescription
                            ))
                        }
                    }
                }

                for await result in group {
                    switch result {
                    case .success(let update):
                        allUpdates.append(update)
                    case .failure(let error):
                        errors.append(error)
                    }
                }
            }
        }

        // Sort updates by app name
        allUpdates.sort { $0.appName.localizedCompare($1.appName) == .orderedAscending }

        updates = allUpdates
        lastCheckDate = Date()

        let availableCount = allUpdates.filter { $0.updateAvailable }.count

        return UpdateCheckResult(
            appsChecked: apps.count,
            updatesAvailable: availableCount,
            updates: allUpdates,
            duration: Date().timeIntervalSince(startTime),
            errors: errors
        )
    }

    // MARK: - Update Detection Methods

    private func displayName(forAppAt appPath: URL) -> String {
        if let bundle = Bundle(url: appPath) {
            if let name = bundle.infoDictionary?["CFBundleDisplayName"] as? String { return name }
            if let name = bundle.infoDictionary?["CFBundleName"] as? String { return name }
        }
        return appPath.deletingPathExtension().lastPathComponent
    }

    /// Mac App Store apps carry a receipt inside the bundle.
    func hasMASReceipt(appPath: URL) -> Bool {
        fileManager.fileExists(atPath: appPath.appendingPathComponent("Contents/_MASReceipt/receipt").path)
    }

    /// The app's Sparkle appcast URL, if it publishes one.
    func sparkleFeedURL(forAppAt appPath: URL) -> URL? {
        guard let bundle = Bundle(url: appPath),
              let feedURLString = bundle.infoDictionary?["SUFeedURL"] as? String,
              let feedURL = URL(string: feedURLString.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = feedURL.scheme?.lowercased(),
              scheme == "https" || scheme == "http"
        else { return nil }
        return feedURL
    }

    /// Fetch and parse a Sparkle appcast, comparing against the installed version.
    private func checkViaSparkleFeed(
        feedURL: URL,
        bundleIdentifier: String,
        appName: String,
        currentVersion: String?,
        appPath: URL
    ) async throws -> AppUpdate {
        let installedVersion = currentVersion
            ?? Bundle(url: appPath)?.infoDictionary?["CFBundleShortVersionString"] as? String

        guard let installedVersion else {
            throw UpdateCheckError(bundleIdentifier: bundleIdentifier, appName: appName, errorType: .noVersionInfo)
        }

        var request = URLRequest(url: feedURL, timeoutInterval: 15)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")

        let data: Data
        do {
            let (body, response) = try await urlSession.data(for: request)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                throw UpdateCheckError(
                    bundleIdentifier: bundleIdentifier,
                    appName: appName,
                    errorType: .feedUnreachable,
                    underlyingError: "HTTP \(http.statusCode)"
                )
            }
            data = body
        } catch let error as UpdateCheckError {
            throw error
        } catch {
            throw UpdateCheckError(
                bundleIdentifier: bundleIdentifier,
                appName: appName,
                errorType: .feedUnreachable,
                underlyingError: error.localizedDescription
            )
        }

        let best: AppcastItem
        do {
            best = try SparkleAppcastParser.bestItem(from: data)
        } catch {
            throw UpdateCheckError(
                bundleIdentifier: bundleIdentifier,
                appName: appName,
                errorType: .badFeed,
                underlyingError: String(describing: error)
            )
        }

        let latestVersion = best.displayVersion ?? installedVersion
        let comparison = AppUpdate.compareVersions(installedVersion, latestVersion)

        return AppUpdate(
            bundleIdentifier: bundleIdentifier,
            appName: appName,
            currentVersion: installedVersion,
            latestVersion: latestVersion,
            appPath: appPath,
            updateAvailable: comparison == .updateAvailable,
            updateURL: best.enclosureURL,
            releaseNotes: best.releaseNotesLink ?? best.descriptionHTML,
            source: .sparkle,
            minimumSystemVersion: best.minimumSystemVersion,
            enclosureLength: best.enclosureLength,
            edSignature: best.edSignature
        )
    }

    // MARK: - Mac App Store Lookup

    struct ITunesLookupApp: Decodable, Sendable {
        let version: String
        let trackId: Int?
        let trackViewUrl: String?
        let minimumOsVersion: String?
        let releaseNotes: String?
    }

    private struct ITunesLookupResponse: Decodable {
        let resultCount: Int
        let results: [ITunesLookupApp]
    }

    /// In-memory cache of iTunes lookups to stay clear of rate limits.
    private var masLookupCache: [String: (date: Date, app: ITunesLookupApp?)] = [:]
    private static let masLookupTTL: TimeInterval = 6 * 60 * 60

    /// Query the iTunes lookup API for the store version of a MAS-installed app.
    /// Returns nil when the app is no longer listed (caller falls through).
    private func checkViaAppStore(
        bundleIdentifier: String,
        appName: String,
        currentVersion: String?,
        appPath: URL
    ) async throws -> AppUpdate? {
        let storeApp: ITunesLookupApp?
        if let cached = masLookupCache[bundleIdentifier], Date().timeIntervalSince(cached.date) < Self.masLookupTTL {
            storeApp = cached.app
        } else {
            storeApp = try await lookupMASApp(bundleIdentifier: bundleIdentifier, appName: appName)
            masLookupCache[bundleIdentifier] = (Date(), storeApp)
        }

        guard let storeApp else { return nil }

        let comparison = AppUpdate.compareVersions(currentVersion, storeApp.version)
        return AppUpdate(
            bundleIdentifier: bundleIdentifier,
            appName: appName,
            currentVersion: currentVersion,
            latestVersion: storeApp.version,
            appPath: appPath,
            updateAvailable: comparison == .updateAvailable,
            updateURL: storeApp.trackViewUrl.flatMap(URL.init(string:)),
            releaseNotes: storeApp.releaseNotes,
            source: .macAppStore,
            minimumSystemVersion: storeApp.minimumOsVersion,
            trackId: storeApp.trackId
        )
    }

    private func lookupMASApp(bundleIdentifier: String, appName: String) async throws -> ITunesLookupApp? {
        var components = URLComponents(string: "https://itunes.apple.com/lookup")!
        components.queryItems = [
            URLQueryItem(name: "bundleId", value: bundleIdentifier),
            URLQueryItem(name: "country", value: Locale.current.region?.identifier ?? "US"),
        ]

        var request = URLRequest(url: components.url!, timeoutInterval: 15)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await urlSession.data(for: request)
            if let http = response as? HTTPURLResponse {
                if http.statusCode == 403 || http.statusCode == 429 {
                    throw UpdateCheckError(bundleIdentifier: bundleIdentifier, appName: appName, errorType: .rateLimited)
                }
                guard (200...299).contains(http.statusCode) else {
                    throw UpdateCheckError(
                        bundleIdentifier: bundleIdentifier,
                        appName: appName,
                        errorType: .masLookupFailed,
                        underlyingError: "HTTP \(http.statusCode)"
                    )
                }
            }
            let decoded = try JSONDecoder().decode(ITunesLookupResponse.self, from: data)
            return decoded.results.first
        } catch let error as UpdateCheckError {
            throw error
        } catch let error as DecodingError {
            throw UpdateCheckError(
                bundleIdentifier: bundleIdentifier,
                appName: appName,
                errorType: .masLookupFailed,
                underlyingError: String(describing: error)
            )
        } catch {
            throw UpdateCheckError(
                bundleIdentifier: bundleIdentifier,
                appName: appName,
                errorType: .networkError,
                underlyingError: error.localizedDescription
            )
        }
    }

    // MARK: - App Bundle Analysis

    /// Get app dependencies/frameworks from an app bundle
    func getAppDependencies(for appPath: URL) -> [AppDependency] {
        var dependencies: [AppDependency] = []

        let frameworksPath = appPath.appendingPathComponent("Contents/Frameworks")

        guard fileManager.fileExists(atPath: frameworksPath.path) else {
            return dependencies
        }

        guard let enumerator = fileManager.enumerator(
            at: frameworksPath,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return dependencies
        }

        for case let url as URL in enumerator {
            let pathExtension = url.pathExtension

            // Frameworks (.framework) and dynamic libraries (.dylib)
            if pathExtension == "framework" || pathExtension == "dylib" {
                let name = url.deletingPathExtension().lastPathComponent

                // Get file size
                var isDirectory: ObjCBool = false
                var size: Int64 = 0

                if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) {
                    if let attributes = try? fileManager.attributesOfItem(atPath: url.path),
                       let fileSize = attributes[.size] as? Int64 {
                        size = isDirectory.boolValue ? getDirectorySize(url) : fileSize
                    }
                }

                let dependencyType: AppDependency.DependencyType = pathExtension == "framework" ? .framework : .dylib

                dependencies.append(AppDependency(
                    name: name,
                    type: dependencyType,
                    path: url,
                    size: size,
                    version: getFrameworkVersion(url)
                ))
            }
        }

        return dependencies.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    /// Get all file locations associated with an app
    func getAppFileLocations(for bundleIdentifier: String, appPath: URL) -> [AppFileLocation] {
        var locations: [AppFileLocation] = []

        // App bundle location
        if let bundleAttrs = try? fileManager.attributesOfItem(atPath: appPath.path),
           let size = bundleAttrs[.size] as? Int64,
           let modDate = bundleAttrs[.modificationDate] as? Date {
            locations.append(AppFileLocation(
                path: appPath.path,
                type: .appBundle,
                size: size,
                lastModified: modDate
            ))
        }

        // Application Support
        if let supportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let appSupportPath = supportURL.appendingPathComponent(bundleIdentifier)
            if fileManager.fileExists(atPath: appSupportPath.path),
               let attrs = try? fileManager.attributesOfItem(atPath: appSupportPath.path),
               let size = attrs[.size] as? Int64,
               let modDate = attrs[.modificationDate] as? Date {
                locations.append(AppFileLocation(
                    path: appSupportPath.path,
                    type: .appSupport,
                    size: size,
                    lastModified: modDate
                ))
            }
        }

        // Caches
        if let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            let cachePath = cachesURL.appendingPathComponent(bundleIdentifier)
            if fileManager.fileExists(atPath: cachePath.path),
               let attrs = try? fileManager.attributesOfItem(atPath: cachePath.path),
               let size = attrs[.size] as? Int64,
               let modDate = attrs[.modificationDate] as? Date {
                locations.append(AppFileLocation(
                    path: cachePath.path,
                    type: .caches,
                    size: size,
                    lastModified: modDate
                ))
            }
        }

        // Preferences
        let prefsPath = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Preferences")
            .appendingPathComponent("\(bundleIdentifier).plist")
        if let prefs = prefsPath, fileManager.fileExists(atPath: prefs.path),
           let attrs = try? fileManager.attributesOfItem(atPath: prefs.path),
           let size = attrs[.size] as? Int64,
           let modDate = attrs[.modificationDate] as? Date {
            locations.append(AppFileLocation(
                path: prefs.path,
                type: .preferences,
                size: size,
                lastModified: modDate
            ))
        }

        // Containers (sandboxed apps)
        let containersBase = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers")
        let containerPath = containersBase.appendingPathComponent(bundleIdentifier)
        if fileManager.fileExists(atPath: containerPath.path),
           let attrs = try? fileManager.attributesOfItem(atPath: containerPath.path),
           let size = attrs[.size] as? Int64,
           let modDate = attrs[.modificationDate] as? Date {
            locations.append(AppFileLocation(
                path: containerPath.path,
                type: .containers,
                size: size,
                lastModified: modDate
            ))
        }

        // Saved Application State
        let savedStateBase = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Saved Application State")
        let savedStatePath = savedStateBase.appendingPathComponent("\(bundleIdentifier).savedState")
        if fileManager.fileExists(atPath: savedStatePath.path),
           let attrs = try? fileManager.attributesOfItem(atPath: savedStatePath.path),
           let size = attrs[.size] as? Int64,
           let modDate = attrs[.modificationDate] as? Date {
            locations.append(AppFileLocation(
                path: savedStatePath.path,
                type: .savedState,
                size: size,
                lastModified: modDate
            ))
        }

        return locations
    }

    // MARK: - Helper Methods

    private func getDirectorySize(_ url: URL) -> Int64 {
        var totalSize: Int64 = 0

        if let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let fileURL as URL in enumerator {
                if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                   let fileSize = resourceValues.fileSize {
                    totalSize += Int64(fileSize)
                }
            }
        }

        return totalSize
    }

    private func getFrameworkVersion(_ frameworkURL: URL) -> String? {
        // For frameworks, check the Info.plist for version
        let infoPlistPath = frameworkURL.appendingPathComponent("Contents/Info.plist")
        if let plist = NSDictionary(contentsOfFile: infoPlistPath.path),
           let version = plist["CFBundleShortVersionString"] as? String {
            return version
        }

        // For standalone dylibs, check the version in the filename
        let name = frameworkURL.deletingPathExtension().lastPathComponent
        let versionPattern = #"(\d+\.\d+(\.\d+)?)$"#
        if let regex = try? NSRegularExpression(pattern: versionPattern),
           let match = regex.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)),
           match.numberOfRanges > 1,
           let range = Range(match.range(at: 1), in: name) {
            return String(name[range])
        }

        return nil
    }

    /// Clear update cache
    func clearCache() {
        updates.removeAll()
        lastCheckDate = nil
    }
}

// MARK: - App Dependency Model

/// Represents a framework or library dependency
struct AppDependency: Identifiable, Sendable, Codable {
    let id: UUID
    let name: String
    let type: DependencyType
    let path: URL
    let size: Int64
    let version: String?

    // CodingKeys includes 'id' to preserve it when present in encoded data
    enum CodingKeys: String, CodingKey {
        case id, name, type, path, size, version
    }

    init(name: String, type: DependencyType, path: URL, size: Int64, version: String?) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.path = path
        self.size = size
        self.version = version
    }

    // Custom init from decoder to preserve ID when present, generate when missing
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Preserve existing ID if present, otherwise generate new one
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.name = try container.decode(String.self, forKey: .name)
        self.type = try container.decode(DependencyType.self, forKey: .type)
        self.path = try container.decode(URL.self, forKey: .path)
        self.size = try container.decode(Int64.self, forKey: .size)
        self.version = try container.decodeIfPresent(String.self, forKey: .version)
    }

    enum DependencyType: String, Sendable, Codable {
        case framework = "Framework"
        case dylib = "Dynamic Library"
        case xpc = "XPC Service"
        case other = "Other"

        var icon: String {
            switch self {
            case .framework: return "cube.fill"
            case .dylib: return "link"
            case .xpc: return "arrow.up.arrow.down"
            case .other: return "doc.fill"
            }
        }
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

