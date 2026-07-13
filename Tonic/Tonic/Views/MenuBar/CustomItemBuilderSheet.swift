//
//  CustomItemBuilderSheet.swift
//  Tonic
//
//  Live-preview builder for sandbox-safe Tonic-owned status items.
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct CustomItemBuilderSheet: View {
    enum SourceKind: String, CaseIterable, Identifiable {
        case staticText, dateTime, battery, cpu, memory, network, weather, formatted, provider
        var id: String { rawValue }
        var title: String {
            switch self {
            case .staticText: "Static text"
            case .dateTime: "Date & time"
            case .battery: "Battery"
            case .cpu: "CPU"
            case .memory: "Memory"
            case .network: "Network"
            case .weather: "Weather"
            case .formatted: "Formatted combination"
            case .provider: "Custom provider"
            }
        }
    }

    enum ActionKind: String, CaseIterable, Identifiable {
        case application, file, url, tonic, shortcut
        #if !TONIC_STORE
        case script
        #endif
        var id: String { rawValue }
        var title: String { rawValue.capitalized }
    }

    let existing: CustomMenuBarItem?
    let onSave: (CustomMenuBarItem) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var itemID: UUID
    @State private var name: String
    @State private var symbolName: String
    @State private var sourceKind: SourceKind
    @State private var sourceValue: String
    @State private var actions: [CustomMenuBarSafeAction]
    @State private var actionKind: ActionKind = .url
    @State private var actionValue = "https://"
    @State private var imageBookmark: Data?
    @State private var section: MenuBarSection
    @State private var importsFile = false
    @State private var importsImage = false
    @State private var errorMessage: String?
    @State private var providerManifests: [TonicDataSourceManifest] = []
    @State private var imagePreview: NSImage?
    @State private var providerPreview: TonicDataSourceSnapshot?
    #if !TONIC_STORE
    @State private var buildsScript = false
    #endif

    init(existing: CustomMenuBarItem? = nil, onSave: @escaping (CustomMenuBarItem) -> Void) {
        self.existing = existing; self.onSave = onSave
        _itemID = State(initialValue: existing?.id ?? UUID())
        _name = State(initialValue: existing?.name ?? "Custom Item")
        _symbolName = State(initialValue: existing?.symbolName ?? "sparkles")
        let source = Self.editorSource(existing?.dataSource ?? .staticLabel("Tonic"))
        _sourceKind = State(initialValue: source.kind); _sourceValue = State(initialValue: source.value)
        _actions = State(initialValue: existing?.actions ?? [])
        _imageBookmark = State(initialValue: existing?.imageBookmark)
        _section = State(initialValue: existing?.section ?? .visible)
    }

    private let formatter = CustomItemFormatter()
    private var item: CustomMenuBarItem {
        CustomMenuBarItem(id: itemID, name: name, symbolName: symbolName, imageBookmark: imageBookmark,
                          dataSource: source, actions: actions, section: section)
    }
    private var source: CustomMenuBarDataSource {
        switch sourceKind {
        case .staticText: .staticLabel(sourceValue)
        case .dateTime: .date(format: sourceValue.isEmpty ? "EEE h:mm a" : sourceValue)
        case .battery: .battery
        case .cpu: .cpu
        case .memory: .memory
        case .network: .network
        case .weather: .weather
        case .formatted: .formatted(template: sourceValue)
        case .provider: .provider(sourceValue)
        }
    }
    private var preview: String {
        if sourceKind == .provider { return providerPreview?.label ?? "Loading…" }
        return formatter.format(source, snapshot: WidgetCustomItemDataProvider.shared.snapshot())
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(existing == nil ? "Custom Menu Bar Item" : "Edit Custom Menu Bar Item").font(.title2.bold())
                    Text("Build a safe item using Tonic’s existing data providers.").foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(24)

            Divider()
            HStack(alignment: .top, spacing: 24) {
                Form {
                    Section("Identity") {
                        TextField("Name", text: $name)
                        TextField("SF Symbol", text: $symbolName)
                        Button("Choose image…") { importsImage = true }
                        Picker("Section", selection: $section) {
                            ForEach(MenuBarSection.allCases, id: \.self) { Text($0.displayName).tag($0) }
                        }
                    }
                    Section("Data") {
                        Picker("Source", selection: $sourceKind) {
                            ForEach(SourceKind.allCases) { Text($0.title).tag($0) }
                        }
                        if sourceKind == .staticText || sourceKind == .dateTime || sourceKind == .formatted || sourceKind == .provider {
                            TextField(sourceKind == .formatted ? "Example: {cpu} · {battery}"
                                      : sourceKind == .provider ? "Provider identifier" : "Value", text: $sourceValue)
                            if sourceKind == .provider, !providerManifests.isEmpty {
                                Picker("Available provider", selection: $sourceValue) {
                                    Text("Choose a provider").tag("")
                                    ForEach(providerManifests) { Text($0.displayName).tag($0.id) }
                                }
                            }
                        }
                    }
                    Section("Actions") {
                        ForEach(Array(actions.enumerated()), id: \.offset) { index, action in
                            HStack {
                                Text(actionTitle(action)).lineLimit(1)
                                Spacer()
                                Button(role: .destructive) { actions.remove(at: index) } label: {
                                    Image(systemName: "minus.circle")
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        if actions.count < 5 {
                            HStack {
                                Picker("Action", selection: $actionKind) {
                                    ForEach(ActionKind.allCases) { Text($0.title).tag($0) }
                                }
                                .onChange(of: actionKind) { _, kind in actionValue = defaultActionValue(for: kind) }
                                if actionKind == .file {
                                    Button("Choose…") { importsFile = true }
                                } else if actionKind == .tonic {
                                    Picker("Destination", selection: $actionValue) {
                                        ForEach(CustomTonicDestination.allCases) { Text($0.title).tag($0.rawValue) }
                                    }
                                    Button("Add") { addAction() }
                                } else {
                                    #if !TONIC_STORE
                                    if actionKind == .script {
                                        Button("Review script…") { buildsScript = true }
                                    } else {
                                        TextField(actionPlaceholder, text: $actionValue)
                                        Button("Add") { addAction() }
                                    }
                                    #else
                                    TextField(actionPlaceholder, text: $actionValue)
                                    Button("Add") { addAction() }
                                    #endif
                                }
                            }
                        }
                    }
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red).font(.caption)
                    }
                }
                .formStyle(.grouped)
                .frame(minWidth: 430)

                VStack(spacing: 18) {
                    Text("LIVE PREVIEW").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        if let imagePreview {
                            Image(nsImage: imagePreview).resizable().aspectRatio(contentMode: .fit).frame(width: 18, height: 18)
                        } else {
                            Image(systemName: previewSymbolName)
                        }
                        Text(preview.isEmpty ? name : preview).lineLimit(1)
                    }
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(.black.opacity(0.82), in: Capsule())
                    .foregroundStyle(.white)
                    Text("Nothing is added to the real menu bar until Apply Layout.")
                        .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .frame(width: 240, height: 220)
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 18))
            }
            .padding(24)

            Divider()
            HStack {
                Button("Cancel") { dismiss() }.buttonStyle(.bordered)
                Spacer()
                PrimaryPill(existing == nil ? "Add to Draft" : "Save to Draft") { save() }
            }
            .padding(20)
        }
        .frame(width: 780, height: 650)
        .fileImporter(isPresented: $importsFile, allowedContentTypes: [.item]) { result in
            guard case .success(let url) = result else { return }
            do {
                let bookmark = try url.bookmarkData(options: .withSecurityScope,
                                                    includingResourceValuesForKeys: nil, relativeTo: nil)
                actions.append(.openFile(bookmark: bookmark))
            } catch { errorMessage = error.localizedDescription }
        }
        .fileImporter(isPresented: $importsImage, allowedContentTypes: [.image]) { result in
            guard case .success(let url) = result else { return }
            do {
                imageBookmark = try url.bookmarkData(options: .withSecurityScope,
                                                     includingResourceValuesForKeys: nil, relativeTo: nil)
                if let data = try? Data(contentsOf: url) { imagePreview = NSImage(data: data) }
            } catch { errorMessage = error.localizedDescription }
        }
        #if !TONIC_STORE
        .sheet(isPresented: $buildsScript) {
            ScriptBuilderSheet { script, scheduleInterval in
                CustomItemScriptStore.shared.save(script)
                CustomItemScriptStore.shared.approveReviewedExecution(id: script.id)
                CustomItemScriptStore.shared.setSchedule(scriptID: script.id, interval: scheduleInterval)
                actions.append(.runScript(script.id))
            }
        }
        #endif
        .task {
            providerManifests = await TonicProviderRegistry.shared.manifests()
            loadImagePreviewIfNeeded()
        }
        .task(id: sourceKind.rawValue + ":" + sourceValue) {
            guard sourceKind == .provider, !sourceValue.isEmpty else { providerPreview = nil; return }
            providerPreview = try? await TonicProviderRegistry.shared.snapshot(
                providerID: sourceValue, request: TonicDataSourceRequest(providerID: sourceValue))
        }
    }

    private var actionPlaceholder: String {
        switch actionKind {
        case .application: "Bundle identifier"
        case .file: "File"
        case .url: "https://example.com"
        case .tonic: "Tonic destination"
        case .shortcut: "Shortcut name"
        #if !TONIC_STORE
        case .script: "Reviewed script"
        #endif
        }
    }

    private static func editorSource(_ source: CustomMenuBarDataSource) -> (kind: SourceKind, value: String) {
        switch source {
        case .staticLabel(let value): (.staticText, value)
        case .date(let format): (.dateTime, format)
        case .battery: (.battery, "")
        case .cpu: (.cpu, "")
        case .memory: (.memory, "")
        case .network: (.network, "")
        case .weather: (.weather, "")
        case .formatted(let template): (.formatted, template)
        case .provider(let id): (.provider, id)
        }
    }

    private func loadImagePreviewIfNeeded() {
        guard imagePreview == nil, let imageBookmark else { return }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: imageBookmark, options: [.withSecurityScope],
                                 relativeTo: nil, bookmarkDataIsStale: &stale), !stale else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        if let data = try? Data(contentsOf: url) { imagePreview = NSImage(data: data) }
    }

    private func defaultActionValue(for kind: ActionKind) -> String {
        switch kind {
        case .url: "https://"
        case .tonic: CustomTonicDestination.menuBar.rawValue
        default: ""
        }
    }

    private var previewSymbolName: String {
        if let providerSymbol = providerPreview?.symbolName,
           NSImage(systemSymbolName: providerSymbol, accessibilityDescription: nil) != nil { return providerSymbol }
        return NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) == nil
            ? "questionmark.square.dashed" : symbolName
    }

    private func addAction() {
        let trimmed = actionValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        switch actionKind {
        case .application: actions.append(.openApplication(bundleIdentifier: trimmed))
        case .file: break
        case .url:
            guard let url = URL(string: trimmed) else { errorMessage = "Enter a valid URL."; return }
            actions.append(.openURL(url))
        case .tonic: actions.append(.openTonicDestination(trimmed))
        case .shortcut: actions.append(.runShortcut(name: trimmed))
        #if !TONIC_STORE
        case .script: break
        #endif
        }
        actionValue = actionKind == .url ? "https://" : ""
        errorMessage = nil
    }

    private func save() {
        do {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty, trimmedName.count <= 64 else {
                errorMessage = "Enter a name up to 64 characters."
                return
            }
            if sourceKind == .provider,
               !providerManifests.contains(where: { $0.id == sourceValue }) {
                errorMessage = "Choose an available provider before adding this item."
                return
            }
            try formatter.validate(item, snapshot: WidgetCustomItemDataProvider.shared.snapshot())
            var saved = item; saved.name = trimmedName
            onSave(saved); dismiss()
        } catch { errorMessage = error.localizedDescription }
    }

    private func actionTitle(_ action: CustomMenuBarSafeAction) -> String {
        switch action {
        case .openApplication(let id): "Open app · \(id)"
        case .openFile: "Open selected file"
        case .openURL(let url): "Open · \(url.absoluteString)"
        case .openTonicDestination(let route): "Open Tonic · \(route)"
        case .runShortcut(let name): "Run Shortcut · \(name)"
        #if !TONIC_STORE
        case .runScript: "Run reviewed script"
        #endif
        }
    }
}

#if !TONIC_STORE
private struct ScriptBuilderSheet: View {
    enum SourceKind: String, CaseIterable, Identifiable { case inline, file; var id: String { rawValue } }
    let onSave: (CustomMenuBarScript, TimeInterval?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var sourceKind: SourceKind = .inline
    @State private var inlineCommand = ""
    @State private var fileBookmark: Data?
    @State private var fileName = "No file selected"
    @State private var executable = "/bin/zsh"
    @State private var argumentsText = "-c"
    @State private var workingDirectoryBookmark: Data?
    @State private var workingDirectoryName = "Default"
    @State private var environmentText = ""
    @State private var timeout = 15.0
    @State private var mapsLabel = false
    @State private var runsOnSchedule = false
    @State private var scheduleMinutes = 15.0
    @State private var hasReviewed = false
    @State private var picksFile = false
    @State private var picksDirectory = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Review Script Action").font(.title2.bold())
            Text("Scripts run as your user, never through Tonic’s privileged helper.").foregroundStyle(.secondary)
            Form {
                Picker("Source", selection: $sourceKind) {
                    Text("Inline command").tag(SourceKind.inline); Text("Selected file").tag(SourceKind.file)
                }
                if sourceKind == .inline {
                    TextField("Complete inline command", text: $inlineCommand, axis: .vertical).lineLimit(3...6)
                } else {
                    LabeledContent("Script file", value: fileName)
                    Button("Choose script or executable…") { picksFile = true }
                }
                TextField("Explicit shell or executable", text: $executable)
                TextField("Arguments — one per line", text: $argumentsText, axis: .vertical).lineLimit(2...5)
                LabeledContent("Working directory", value: workingDirectoryName)
                Button("Choose working directory…") { picksDirectory = true }
                TextField("Environment — KEY=value, one per line", text: $environmentText, axis: .vertical).lineLimit(2...5)
                HStack { Text("Timeout"); Slider(value: $timeout, in: 1...300, step: 1); Text("\(Int(timeout))s") }
                Toggle("Map the first sanitized output line to the item label", isOn: $mapsLabel)
                Toggle("Also run on a reviewed schedule", isOn: $runsOnSchedule)
                if runsOnSchedule {
                    HStack {
                        Text("Every")
                        Slider(value: $scheduleMinutes, in: 1...1_440, step: 1)
                        Text("\(Int(scheduleMinutes)) min").monospacedDigit()
                    }
                }
                Section("Execution review") {
                    Text(reviewSummary).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                    Toggle("I reviewed this complete command and approve it for this action", isOn: $hasReviewed)
                }
                if let error { Text(error).foregroundStyle(.red) }
            }
            HStack {
                Button("Cancel") { dismiss() }.buttonStyle(.bordered)
                Spacer()
                PrimaryPill("Save Reviewed Script", isDisabled: !hasReviewed) { save() }
            }
        }
        .padding(24).frame(width: 680, height: 700)
        .fileImporter(isPresented: $picksFile, allowedContentTypes: [.item]) { result in
            capture(result, directory: false)
        }
        .fileImporter(isPresented: $picksDirectory, allowedContentTypes: [.folder]) { result in
            capture(result, directory: true)
        }
    }

    private var arguments: [String] { argumentsText.split(separator: "\n", omittingEmptySubsequences: true).map(String.init) }
    private var environment: [String: String] {
        var result: [String: String] = [:]
        for line in environmentText.split(separator: "\n") {
            guard let split = line.firstIndex(of: "=") else { continue }
            result[String(line[..<split])] = String(line[line.index(after: split)...])
        }
        return result
    }
    private var reviewSummary: String {
        "Executable: \(executable)\nArguments: \(arguments)\nSource: \(sourceKind == .inline ? inlineCommand : fileName)\nDirectory: \(workingDirectoryName)\nEnvironment keys: \(environment.keys.sorted())\nTimeout: \(Int(timeout)) seconds\nConditions: click\(runsOnSchedule ? ", every \(Int(scheduleMinutes)) minutes" : "")"
    }

    private func save() {
        let source: CustomMenuBarScript.Source
        if sourceKind == .inline { source = .inline(inlineCommand) }
        else if let fileBookmark { source = .securityScopedBookmark(fileBookmark) }
        else { error = "Choose a script or executable file."; return }
        let script = CustomMenuBarScript(source: source, executable: executable, arguments: arguments,
                                         workingDirectoryBookmark: workingDirectoryBookmark,
                                         environmentAllowlist: environment, timeoutSeconds: timeout,
                                         mapsFirstOutputLineToLabel: mapsLabel)
        if let validation = CustomItemScriptPolicy().validate(script, unattended: false, reviewApproved: true) {
            error = validation.rawValue; return
        }
        onSave(script, runsOnSchedule ? scheduleMinutes * 60 : nil); dismiss()
    }

    private func capture(_ result: Result<URL, Error>, directory: Bool) {
        guard case .success(let url) = result else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        do {
            let bookmark = try url.bookmarkData(options: .withSecurityScope,
                                                includingResourceValuesForKeys: nil, relativeTo: nil)
            if directory { workingDirectoryBookmark = bookmark; workingDirectoryName = url.lastPathComponent }
            else { fileBookmark = bookmark; fileName = url.lastPathComponent }
        } catch { self.error = error.localizedDescription }
    }
}
#endif
