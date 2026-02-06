//
//  ProjectArtifactPurge.swift
//  Tonic
//
//  Project artifact cleanup service
//  Task ID: fn-1.28
//

import Foundation

/// Project types with specific artifact patterns
public enum ProjectType: String, Sendable, CaseIterable, Identifiable {
    case node = "Node.js"
    case python = "Python"
    case ruby = "Ruby"
    case java = "Java"
    case dotnet = ".NET"
    case go = "Go"
    case rust = "Rust"
    case swift = "Swift"
    case flutter = "Flutter"
    case docker = "Docker"
    case generic = "Generic"

    public var id: String { rawValue }

    var icon: String {
        switch self {
        case .node: return "nodejs"
        case .python: return "python"
        case .ruby: return "ruby"
        case .java: return "java"
        case .dotnet: return "dotnet"
        case .go: return "globe"
        case .rust: return "hammer"
        case .swift: return "swift"
        case .flutter: return "butterfly"
        case .docker: return "shippingbox"
        case .generic: return "folder.fill"
        }
    }

    var identifierFiles: [String] {
        switch self {
        case .node:
            return ["package.json", "package-lock.json", "yarn.lock", "node_modules/"]
        case .python:
            return ["requirements.txt", "setup.py", "Pipfile", "pyproject.toml", "__pycache__/"]
        case .ruby:
            return ["Gemfile", "Gemfile.lock", ".bundle/"]
        case .java:
            return ["pom.xml", "build.gradle", "gradlew"]
        case .dotnet:
            return ["*.csproj", "*.sln", "packages/"]
        case .go:
            return ["go.mod", "go.sum"]
        case .rust:
            return ["Cargo.toml", "Cargo.lock", "target/"]
        case .swift:
            return ["Package.swift", ".build/"]
        case .flutter:
            return ["pubspec.yaml", "build/"]
        case .docker:
            return ["Dockerfile", "docker-compose.yml"]
        case .generic:
            return [".git/"]
        }
    }
}

/// Project artifact result
public struct ProjectArtifactResult: Sendable {
    let projectPath: String
    let projectType: ProjectType
    let artifacts: [Artifact]
    let totalSize: Int64

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
}

/// Individual artifact
public struct Artifact: Sendable {
    let name: String
    let path: String
    let size: Int64
    let type: ArtifactType

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

/// Artifact type classification
public enum ArtifactType: String, Sendable, CaseIterable, Identifiable {
    case dependencies = "Dependencies"
    case buildCache = "Build Cache"
    case logs = "Logs"
    case temp = "Temporary Files"
    case ide = "IDE Files"
    case docker = "Docker Images"
    case git = "Git Objects"

    public var id: String { rawValue }

    var isSafeToDelete: Bool {
        switch self {
        case .dependencies, .buildCache, .logs, .temp, .docker:
            return true
        case .ide, .git:
            return false
        }
    }
}

/// Project artifact scanner and cleaner
@Observable
public final class ProjectArtifactPurge: @unchecked Sendable {

    public static let shared = ProjectArtifactPurge()

    private let fileManager = FileManager.default
    private let sizeCache = DirectorySizeCache.shared
    private let maxScanDepth = 6
    private let maxProjects = 200

    private var isScanning = false
    public var scanProgress: Double = 0
    public var currentScanningPath: String?

    private init() {}

    /// Scan a directory for project artifacts
    public func scanDirectory(_ path: String) async -> [ProjectArtifactResult] {
        isScanning = true
        defer { isScanning = false }

        var results: [ProjectArtifactResult] = []

        guard fileManager.fileExists(atPath: path) else { return results }

        // Find project directories
        let projectDirs = await findProjectDirectories(in: path)

        for detected in projectDirs.prefix(maxProjects) {
            currentScanningPath = detected.path
            if let result = await scanProject(detected.path, type: detected.type) {
                results.append(result)
            }
        }

        currentScanningPath = nil
        scanProgress = 1.0

        return results
    }

    /// Scan user's home directory for projects
    public func scanUserProjects() async -> [ProjectArtifactResult] {
        let roots = candidateRoots()
        var results: [ProjectArtifactResult] = []

        for root in roots {
            results.append(contentsOf: await scanDirectory(root))
            if results.count >= maxProjects {
                break
            }
        }

        return results
    }

    /// Clean artifacts from specific projects
    public func cleanArtifacts(_ results: [ProjectArtifactResult], artifactTypes: [ArtifactType]) async -> Int64 {
        var bytesFreed: Int64 = 0

        for result in results {
            for artifact in result.artifacts {
                guard artifactTypes.contains(artifact.type) else { continue }
                guard artifact.type.isSafeToDelete else { continue }

                do {
                    let attrs = try? fileManager.attributesOfItem(atPath: artifact.path)
                    let size = attrs?[.size] as? Int64 ?? 0

                    try fileManager.removeItem(atPath: artifact.path)
                    bytesFreed += size
                } catch {
                    // Skip items that can't be deleted
                    continue
                }
            }
        }

        return bytesFreed
    }

    // MARK: - Project Detection

    private struct DetectedProject: Sendable {
        let path: String
        let type: ProjectType
    }

    private func findProjectDirectories(in path: String) async -> [DetectedProject] {
        var projects: [DetectedProject] = []
        let rootURL = URL(fileURLWithPath: path)

        var queue: [(url: URL, depth: Int)] = [(rootURL, 0)]
        var index = 0

        while index < queue.count, projects.count < maxProjects {
            let (currentURL, depth) = queue[index]
            index += 1

            if shouldSkipDirectory(currentURL) {
                continue
            }

            guard let contents = try? fileManager.contentsOfDirectory(
                at: currentURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                continue
            }

            let names = Set(contents.map { $0.lastPathComponent })

            if let type = detectProjectType(at: currentURL.path, contents: names) {
                projects.append(DetectedProject(path: currentURL.path, type: type))
                continue
            }

            guard depth < maxScanDepth else { continue }

            for url in contents {
                guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey]),
                      values.isDirectory == true else { continue }
                if shouldSkipDirectory(url) { continue }
                queue.append((url, depth + 1))
            }
        }

        return projects
    }

    private func detectProjectType(at path: String, contents: Set<String>) -> ProjectType? {
        for type in ProjectType.allCases {
            for identifier in type.identifierFiles {
                if identifier.hasPrefix("*") {
                    let fileExt = String(identifier.dropFirst())
                    if contents.contains(where: { $0.hasSuffix(fileExt) }) {
                        return type
                    }
                    continue
                }

                if identifier.hasSuffix("/") {
                    let dirName = String(identifier.dropLast())
                    if contents.contains(dirName) {
                        var isDirectory: ObjCBool = false
                        let checkPath = path + "/" + dirName
                        fileManager.fileExists(atPath: checkPath, isDirectory: &isDirectory)
                        if isDirectory.boolValue {
                            return type
                        }
                    }
                    continue
                }

                if contents.contains(identifier) {
                    return type
                }
            }
        }

        return nil
    }

    private func candidateRoots() -> [String] {
        let home = fileManager.homeDirectoryForCurrentUser.path
        let candidates = [
            home + "/Developer",
            home + "/Developers",
            home + "/Projects",
            home + "/Project",
            home + "/Code",
            home + "/Workspace",
            home + "/Workspaces",
            home + "/Documents",
            home + "/Desktop",
            home + "/Downloads"
        ]
        let existing = candidates.filter { fileManager.fileExists(atPath: $0) }
        return existing.isEmpty ? [home] : existing
    }

    private func shouldSkipDirectory(_ url: URL) -> Bool {
        let name = url.lastPathComponent.lowercased()
        if name.hasPrefix(".") && name != ".config" {
            return true
        }
        let skipNames: Set<String> = [
            "library",
            "applications",
            "system",
            "private",
            "volumes",
            "pictures",
            "movies",
            "music",
            "cores",
            "tmp",
            ".trash",
            "node_modules",
            "pods",
            "deriveddata",
            "carthage",
            ".build",
            ".swiftpm",
            ".gradle",
            ".npm",
            ".yarn",
            ".cache",
            ".cargo",
            ".venv",
            "venv"
        ]
        if skipNames.contains(name) {
            return true
        }
        let path = url.path.lowercased()
        if path.contains("/library/containers") || path.contains("/library/application support") {
            return true
        }
        return false
    }

    // MARK: - Project Scanning

    private func scanProject(_ path: String, type: ProjectType) async -> ProjectArtifactResult? {

        var artifacts: [Artifact] = []

        switch type {
        case .node:
            artifacts.append(contentsOf: await scanNodeProject(path))
        case .python:
            artifacts.append(contentsOf: await scanPythonProject(path))
        case .ruby:
            artifacts.append(contentsOf: await scanRubyProject(path))
        case .java:
            artifacts.append(contentsOf: await scanJavaProject(path))
        case .dotnet:
            artifacts.append(contentsOf: await scanDotNetProject(path))
        case .go:
            artifacts.append(contentsOf: await scanGoProject(path))
        case .rust:
            artifacts.append(contentsOf: await scanRustProject(path))
        case .swift:
            artifacts.append(contentsOf: await scanSwiftProject(path))
        case .flutter:
            artifacts.append(contentsOf: await scanFlutterProject(path))
        case .docker:
            artifacts.append(contentsOf: await scanDockerProject(path))
        case .generic:
            artifacts.append(contentsOf: await scanGenericProject(path))
        }

        let totalSize = artifacts.reduce(0) { $0 + $1.size }

        return ProjectArtifactResult(
            projectPath: path,
            projectType: type,
            artifacts: artifacts,
            totalSize: totalSize
        )
    }

    // MARK: - Language-Specific Scanners

    private func scanNodeProject(_ path: String) async -> [Artifact] {
        var artifacts: [Artifact] = []

        // node_modules
        let nodeModules = path + "/node_modules"
        if let size = await getDirectorySize(nodeModules) {
            artifacts.append(Artifact(name: "node_modules", path: nodeModules, size: size, type: .dependencies))
        }

        // TypeScript cache
        let tsBuildInfo = path + "/tsconfig.tsbuildinfo"
        if let size = await getFileSize(tsBuildInfo) {
            artifacts.append(Artifact(name: "TS build info", path: tsBuildInfo, size: size, type: .buildCache))
        }

        // Next.js cache
        let nextCache = path + "/.next"
        if let size = await getDirectorySize(nextCache) {
            artifacts.append(Artifact(name: "Next.js cache", path: nextCache, size: size, type: .buildCache))
        }

        return artifacts
    }

    private func scanPythonProject(_ path: String) async -> [Artifact] {
        var artifacts: [Artifact] = []

        // __pycache__
        let pycache = path + "/__pycache__"
        if let size = await getDirectorySize(pycache) {
            artifacts.append(Artifact(name: "__pycache__", path: pycache, size: size, type: .buildCache))
        }

        // .pytest_cache
        let pytestCache = path + "/.pytest_cache"
        if let size = await getDirectorySize(pytestCache) {
            artifacts.append(Artifact(name: "pytest cache", path: pytestCache, size: size, type: .buildCache))
        }

        // .mypy_cache
        let mypyCache = path + "/.mypy_cache"
        if let size = await getDirectorySize(mypyCache) {
            artifacts.append(Artifact(name: "mypy cache", path: mypyCache, size: size, type: .buildCache))
        }

        // .venv or venv
        for venvName in ["venv", ".venv", "env", ".env"] {
            let venv = path + "/" + venvName
            if let size = await getDirectorySize(venv) {
                artifacts.append(Artifact(name: venvName, path: venv, size: size, type: .dependencies))
                break
            }
        }

        return artifacts
    }

    private func scanRubyProject(_ path: String) async -> [Artifact] {
        var artifacts: [Artifact] = []

        // vendor/bundle
        let vendor = path + "/vendor/bundle"
        if let size = await getDirectorySize(vendor) {
            artifacts.append(Artifact(name: "vendor/bundle", path: vendor, size: size, type: .dependencies))
        }

        return artifacts
    }

    private func scanJavaProject(_ path: String) async -> [Artifact] {
        var artifacts: [Artifact] = []

        // target (Maven)
        let target = path + "/target"
        if let size = await getDirectorySize(target) {
            artifacts.append(Artifact(name: "Maven target", path: target, size: size, type: .buildCache))
        }

        // build (Gradle)
        let build = path + "/build"
        if let size = await getDirectorySize(build) {
            artifacts.append(Artifact(name: "Gradle build", path: build, size: size, type: .buildCache))
        }

        return artifacts
    }

    private func scanDotNetProject(_ path: String) async -> [Artifact] {
        var artifacts: [Artifact] = []

        // bin/obj
        for dirName in ["bin", "obj"] {
            let dir = path + "/" + dirName
            if let size = await getDirectorySize(dir) {
                artifacts.append(Artifact(name: dirName, path: dir, size: size, type: .buildCache))
            }
        }

        return artifacts
    }

    private func scanGoProject(_ path: String) async -> [Artifact] {
        var artifacts: [Artifact] = []

        return artifacts
    }

    private func scanRustProject(_ path: String) async -> [Artifact] {
        var artifacts: [Artifact] = []

        // target/
        let target = path + "/target"
        if let size = await getDirectorySize(target) {
            artifacts.append(Artifact(name: "Cargo target", path: target, size: size, type: .buildCache))
        }

        return artifacts
    }

    private func scanSwiftProject(_ path: String) async -> [Artifact] {
        var artifacts: [Artifact] = []

        // .build/
        let build = path + "/.build"
        if let size = await getDirectorySize(build) {
            artifacts.append(Artifact(name: "SwiftPM build", path: build, size: size, type: .buildCache))
        }

        // .swiftpm/
        let swiftpm = path + "/.swiftpm"
        if let size = await getDirectorySize(swiftpm) {
            artifacts.append(Artifact(name: ".swiftpm cache", path: swiftpm, size: size, type: .buildCache))
        }

        return artifacts
    }

    private func scanFlutterProject(_ path: String) async -> [Artifact] {
        var artifacts: [Artifact] = []

        // build/
        let build = path + "/build"
        if let size = await getDirectorySize(build) {
            artifacts.append(Artifact(name: "Flutter build", path: build, size: size, type: .buildCache))
        }

        // .dart_tool
        let dartTool = path + "/.dart_tool"
        if let size = await getDirectorySize(dartTool) {
            artifacts.append(Artifact(name: ".dart_tool", path: dartTool, size: size, type: .buildCache))
        }

        return artifacts
    }

    private func scanDockerProject(_ path: String) async -> [Artifact] {
        let artifacts: [Artifact] = []

        // This would be handled by DockerAndVMCleanup service
        return artifacts
    }

    private func scanGenericProject(_ path: String) async -> [Artifact] {
        let artifacts: [Artifact] = []

        // Common IDE folders
        let _ = [
            ".idea",
            ".vscode",
            ".vs",
            "*.swp",
            "*.swo",
            ".DS_Store"
        ]

        return artifacts
    }

    // MARK: - Helper Methods

    private func getDirectorySize(_ path: String) async -> Int64? {
        guard fileManager.fileExists(atPath: path) else { return nil }
        let size = sizeCache.size(for: path, includeHidden: true) ?? 0
        return size > 0 ? size : nil
    }

    private func getFileSize(_ path: String) async -> Int64? {
        guard fileManager.fileExists(atPath: path) else { return nil }

        do {
            let attrs = try fileManager.attributesOfItem(atPath: path)
            return attrs[.size] as? Int64
        } catch {
            return nil
        }
    }
}
