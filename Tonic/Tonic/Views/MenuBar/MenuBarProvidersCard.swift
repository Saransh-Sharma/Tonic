import SwiftUI
import Observation
import UniformTypeIdentifiers

@MainActor
@Observable
private final class MarketplaceViewModel {
    private(set) var entries: [TonicMarketplaceEntry] = []
    private(set) var diagnostics: [TonicProviderDiagnostic] = []
    private(set) var isRefreshing = false
    private(set) var status: String?
    private(set) var pendingEntry: TonicMarketplaceEntry?
    private(set) var pendingPermissionNames: [String] = []
    private(set) var rollbackProviderIDs = Set<String>()
    private var service: TonicMarketplaceService?

    init() {
        guard let trust = TonicArtifactTrustConfiguration() else {
            status = "This build has no release trust root. Marketplace networking is disabled."
            return
        }
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Tonic/Marketplace", isDirectory: true)
        do {
            service = try TonicMarketplaceService(publicKeyData: trust.publicKeyData,
                stateURL: root.appendingPathComponent("state-v1.json"))
        } catch {
            status = "The marketplace trust root is invalid; catalog networking is disabled."
        }
    }

    func refresh() {
        guard let service, let trust = TonicArtifactTrustConfiguration() else { return }
        isRefreshing = true
        Task {
            do {
                await service.load()
                try await service.refresh(from: trust.marketplaceCatalogURL)
                entries = await service.visibleEntries()
                diagnostics = await service.diagnostics()
                rollbackProviderIDs = await service.rollbackProviderIDs()
                status = entries.isEmpty ? "The signed catalog contains no compatible providers." : nil
            } catch {
                entries = await service.visibleEntries()
                diagnostics = await service.diagnostics()
                rollbackProviderIDs = await service.rollbackProviderIDs()
                status = "Catalog refresh failed closed: \(error.localizedDescription)"
            }
            isRefreshing = false
        }
    }

    var isReviewingPermissions: Bool { pendingEntry != nil }

    func install(_ entry: TonicMarketplaceEntry, permissionsApproved: Bool = false) {
        guard let service else { return }
        isRefreshing = true
        Task {
            do {
                let plan = try await service.installPlan(entryID: entry.id)
                guard plan.permissionsToApprove.isEmpty || permissionsApproved else {
                    pendingEntry = entry
                    pendingPermissionNames = plan.permissionsToApprove.map(\.rawValue).sorted()
                    status = nil
                    isRefreshing = false
                    return
                }
                let receipt: TonicProviderInstallReceipt
                switch plan.release.kind {
                case .remoteJSON:
                    receipt = try await service.installRemote(plan)
                case .executableBundle:
                    #if TONIC_STORE
                    throw TonicMarketplaceError.executableUnavailableInStore
                    #else
                    receipt = try await service.installExecutable(plan)
                    #endif
                }
                status = receipt.detail
                diagnostics = await service.diagnostics()
            } catch {
                status = "Provider installation failed: \(error.localizedDescription)"
            }
            isRefreshing = false
        }
    }

    func approvePending() {
        guard let entry = pendingEntry else { return }
        pendingEntry = nil
        pendingPermissionNames = []
        install(entry, permissionsApproved: true)
    }

    func cancelPending() {
        pendingEntry = nil
        pendingPermissionNames = []
    }

    func rollback(_ providerID: String) {
        guard let service else { return }
        isRefreshing = true
        Task {
            if let release = await service.rollback(providerID: providerID) {
                status = "Rolled back \(providerID) to \(release.version)."
            } else {
                status = "Rollback failed closed; the active provider was not replaced."
            }
            diagnostics = await service.diagnostics()
            rollbackProviderIDs = await service.rollbackProviderIDs()
            isRefreshing = false
        }
    }
}

struct MenuBarProvidersCard: View {
    @State private var store = TonicRemoteProviderStore.shared
    @State private var marketplace = MarketplaceViewModel()
    @State private var showsBuilder = false
    @State private var reviewingRemote: TonicRemoteProviderConfiguration?
    #if !TONIC_STORE
    @State private var executableStore = TonicExecutableProviderStore.shared
    @State private var importsExecutableProvider = false
    @State private var developerMode = false
    @State private var pendingProviderURL: URL?
    @State private var pendingApprovalHash: String?
    @State private var executableError: String?
    @State private var reviewingScript: CustomMenuBarScript?
    @State private var reviewingExecutable: TonicExecutableProviderConfiguration?
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.md) {
        SettingsPanel(title: "PROVIDER MARKETPLACE") {
            TonicPreferenceRow(title: "Curated catalog",
                description: "Signed catalog metadata from GitHub Pages; immutable artifacts come from GitHub Releases.") {
                Button("Refresh") { marketplace.refresh() }.buttonStyle(.bordered)
                    .disabled(marketplace.isRefreshing)
            }
            if marketplace.isRefreshing {
                TonicPreferenceRow(title: "Checking signed catalog", description: "No provider launches before signature and compatibility validation.") {
                    ProgressView().controlSize(.small)
                }
            }
            ForEach(marketplace.entries) { entry in
                TonicPreferenceRow(title: entry.providerName,
                    description: entry.localizedDescriptions[Locale.current.language.languageCode?.identifier ?? "en"]
                        ?? entry.localizedDescriptions["en"] ?? "Reviewed Tonic data provider") {
                    HStack {
                        Text(entry.publisherName).font(.caption).foregroundStyle(.secondary)
                        Button("Install") { marketplace.install(entry) }.buttonStyle(.bordered)
                    }
                }
            }
            ForEach(marketplace.diagnostics) { diagnostic in
                TonicPreferenceRow(title: diagnostic.providerID,
                    description: diagnostic.detail) {
                    HStack {
                        StatusChip(diagnostic.state.rawValue, level: diagnostic.state == .healthy ? .success : .warning)
                        if marketplace.rollbackProviderIDs.contains(diagnostic.providerID) {
                            Button("Rollback") { marketplace.rollback(diagnostic.providerID) }
                                .buttonStyle(.bordered)
                        }
                    }
                }
            }
            if let status = marketplace.status {
                TonicPreferenceRow(title: "Marketplace status", description: status, showsDivider: false) {
                    StatusChip("Fail closed", level: .info)
                }
            }
        }

        SettingsPanel(title: "CUSTOM PROVIDERS") {
            TonicPreferenceRow(title: "Remote JSON providers",
                               description: "Reviewed HTTPS data sources with bounded responses and Keychain secrets.") {
                Button("Add Provider…") { showsBuilder = true }.buttonStyle(.bordered)
            }
            ForEach(store.configurations, id: \.manifest.id) { configuration in
                TonicPreferenceRow(title: configuration.manifest.displayName,
                    description: "\(configuration.endpoint.host ?? configuration.endpoint.absoluteString) · \(Int(configuration.refreshInterval))s") {
                    HStack {
                        Button("Review…") { reviewingRemote = configuration }.buttonStyle(.bordered)
                        Button(role: .destructive) { store.remove(id: configuration.manifest.id) } label: { Image(systemName: "trash") }
                            .buttonStyle(.borderless)
                    }
                }
            }
            #if !TONIC_STORE
            TonicPreferenceRow(title: "Executable provider bundles",
                               description: "Developer ID signed .tonicprovider bundles run as your user, never through the helper.") {
                Button("Add Bundle…") { importsExecutableProvider = true }.buttonStyle(.bordered)
            }
            TonicToggleRow(title: "Advanced developer mode",
                           description: "Allows a reviewed unsigned provider by immutable SHA-256 code hash.",
                           isOn: $developerMode)
            ForEach(executableStore.configurations) { configuration in
                TonicPreferenceRow(title: configuration.manifest.displayName,
                    description: "\(configuration.manifest.id) · \(configuration.usesDeveloperMode ? "Hash approved" : "Developer ID")") {
                    HStack {
                        Button("Review…") { reviewingExecutable = configuration }.buttonStyle(.bordered)
                        Button(role: .destructive) { executableStore.remove(id: configuration.id) } label: {
                            Image(systemName: "trash")
                        }.buttonStyle(.borderless)
                    }
                }
            }
            if let executableError {
                TonicPreferenceRow(title: "Provider not added", description: executableError,
                                   showsDivider: false) { EmptyView() }
            }
            ForEach(CustomItemScriptStore.shared.definitions) { script in
                TonicPreferenceRow(title: script.executable,
                    description: script.isPaused ? "Paused after three failures; review required" : "Reviewed custom-item script") {
                    Button(script.isPaused ? "Review & Resume…" : "Review…") { reviewingScript = script }
                        .buttonStyle(.bordered)
                }
            }
            #endif
        }
        }
        .task { marketplace.refresh() }
        .confirmationDialog("Review provider permissions", isPresented: Binding(
            get: { marketplace.isReviewingPermissions },
            set: { if !$0 { marketplace.cancelPending() } }
        )) {
            Button("Approve and Install") { marketplace.approvePending() }
            Button("Cancel", role: .cancel) { marketplace.cancelPending() }
        } message: {
            Text("This provider requests: \(marketplace.pendingPermissionNames.joined(separator: ", ")). Installation remains bound to this signed identity, endpoint set, refresh policy, and permission set.")
        }
        .sheet(isPresented: $showsBuilder) { RemoteProviderBuilderSheet { try store.addReviewed($0) } }
        .sheet(item: $reviewingRemote) { configuration in
            RemoteProviderReviewSheet(configuration: configuration)
        }
        #if !TONIC_STORE
        .fileImporter(isPresented: $importsExecutableProvider, allowedContentTypes: [.item]) { result in
            guard case .success(let url) = result else { return }
            importExecutable(url)
        }
        .confirmationDialog("Approve unsigned provider?", isPresented: Binding(
            get: { pendingApprovalHash != nil }, set: { if !$0 { pendingApprovalHash = nil; pendingProviderURL = nil } }
        )) {
            Button("Approve This Code Hash") { approvePendingProvider() }
            Button("Cancel", role: .cancel) { pendingApprovalHash = nil; pendingProviderURL = nil }
        } message: {
            Text("Only approve a provider you trust. Editing its executable invalidates this approval.\n\nSHA-256: \(pendingApprovalHash ?? "")")
        }
        .sheet(item: $reviewingScript) { script in
            ScriptResumeReviewSheet(script: script,
                scheduleInterval: CustomItemScriptStore.shared.scheduleIntervals[script.id])
        }
        .sheet(item: $reviewingExecutable) { configuration in
            ExecutableProviderReviewSheet(configuration: configuration) {
                await executableStore.resumeAfterReview(id: configuration.id)
            }
        }
        #endif
    }

    #if !TONIC_STORE
    private func importExecutable(_ url: URL) {
        executableError = nil
        Task { @MainActor in
            do { try await executableStore.add(bundleURL: url, advancedDeveloperMode: developerMode) }
            catch TonicExecutableProviderError.approvalRequired(let hash) {
                pendingProviderURL = url; pendingApprovalHash = hash
            } catch { executableError = error.localizedDescription }
        }
    }

    private func approvePendingProvider() {
        guard let url = pendingProviderURL, let hash = pendingApprovalHash else { return }
        TonicProviderApprovalStore.shared.approve(codeHash: hash)
        pendingProviderURL = nil; pendingApprovalHash = nil
        Task { @MainActor in
            do { try await executableStore.add(bundleURL: url, advancedDeveloperMode: true) }
            catch { executableError = error.localizedDescription }
        }
    }
    #endif
}

private struct RemoteProviderReviewSheet: View {
    let configuration: TonicRemoteProviderConfiguration
    @Environment(\.dismiss) private var dismiss
    @State private var approved = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Review Remote Provider").font(.title2.bold())
            Text("Endpoint: \(configuration.endpoint.absoluteString)\nRefresh: \(Int(configuration.refreshInterval)) seconds\nPrivate network: \(configuration.allowsPrivateNetwork ? "allowed" : "blocked")\nMaximum response: 256 KiB")
                .font(.system(.caption, design: .monospaced)).textSelection(.enabled)
            Toggle("I reviewed this endpoint and approve resuming requests", isOn: $approved)
            HStack {
                Button("Cancel") { dismiss() }.buttonStyle(.bordered)
                Spacer()
                PrimaryPill("Resume Provider", isDisabled: !approved) {
                    Task {
                        await TonicProviderRegistry.shared.resumeAfterReview(providerID: configuration.manifest.id)
                        await MainActor.run { dismiss() }
                    }
                }
            }
        }.padding(24).frame(width: 620, height: 360)
    }
}

#if !TONIC_STORE
private struct ExecutableProviderReviewSheet: View {
    let configuration: TonicExecutableProviderConfiguration
    let onResume: () async -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var approved = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Review Executable Provider").font(.title2.bold())
            Text("This process runs as your user and can only return display data to Tonic.")
                .foregroundStyle(.secondary)
            Text("Provider: \(configuration.manifest.id)\nVersion: \(configuration.manifest.providerVersion)\nMinimum refresh: \(Int(configuration.manifest.minimumRefreshSeconds)) seconds\nSHA-256: \(configuration.approvedCodeHash)")
                .font(.system(.caption, design: .monospaced)).textSelection(.enabled)
            Toggle("I reviewed this identity and approve resuming requests", isOn: $approved)
            HStack {
                Button("Cancel") { dismiss() }.buttonStyle(.bordered)
                Spacer()
                PrimaryPill("Resume Provider", isDisabled: !approved) {
                    Task { await onResume(); await MainActor.run { dismiss() } }
                }
            }
        }.padding(24).frame(width: 620, height: 420)
    }
}

private struct ScriptResumeReviewSheet: View {
    let script: CustomMenuBarScript
    let scheduleInterval: TimeInterval?
    @Environment(\.dismiss) private var dismiss
    @State private var approved = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Review Script Execution").font(.title2.bold())
            Text("Review the complete command and every unattended condition before resuming.")
                .foregroundStyle(.secondary)
            ScrollView {
                Text(summary).font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
            }
            Toggle("I reviewed this command and approve its listed conditions", isOn: $approved)
            HStack {
                Button("Cancel") { dismiss() }.buttonStyle(.bordered)
                Spacer()
                PrimaryPill(script.isPaused ? "Resume Script" : "Confirm Review", isDisabled: !approved) {
                    Task { @MainActor in
                        await ScriptExecutionCoordinator.shared.resumeAfterReview(scriptID: script.id)
                        dismiss()
                    }
                }
            }
        }
        .padding(24).frame(width: 640, height: 480)
    }

    private var summary: String {
        let source: String
        switch script.source {
        case .inline(let command): source = command
        case .securityScopedBookmark: source = "User-selected script or executable file"
        }
        return "Executable: \(script.executable)\nArguments: \(script.arguments)\nSource: \(source)\nEnvironment keys: \(script.environmentAllowlist.keys.sorted())\nTimeout: \(Int(script.timeoutSeconds)) seconds\nConditions: click\(scheduleInterval.map { ", every \(Int($0 / 60)) minutes" } ?? "")"
    }
}
#endif

private struct RemoteProviderBuilderSheet: View {
    let onSave: (TonicRemoteProviderConfiguration) throws -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var identifier = ""
    @State private var name = ""
    @State private var endpoint = "https://"
    @State private var interval = 300.0
    @State private var allowsPrivateNetwork = false
    @State private var secret = ""
    @State private var reviewed = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Review Remote Provider").font(.title2.bold())
            Form {
                TextField("Provider identifier", text: $identifier)
                TextField("Display name", text: $name)
                TextField("HTTPS endpoint", text: $endpoint)
                HStack { Text("Refresh interval"); Slider(value: $interval, in: 60...86_400, step: 60); Text("\(Int(interval))s") }
                SecureField("Optional bearer secret", text: $secret)
                Toggle("Allow private-network hosts", isOn: $allowsPrivateNetwork)
                Section("Review") {
                    Text("URL: \(endpoint)\nRefresh: \(Int(interval)) seconds\nPrivate network: \(allowsPrivateNetwork ? "allowed" : "blocked")\nMaximum response: 256 KiB")
                        .font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                    Toggle("I reviewed this endpoint and refresh policy", isOn: $reviewed)
                }
                if let error { Text(error).foregroundStyle(.red) }
            }.formStyle(.grouped)
            HStack {
                Button("Cancel") { dismiss() }.buttonStyle(.bordered)
                Spacer()
                PrimaryPill("Save Provider", isDisabled: !reviewed) { save() }
            }
        }.padding(24).frame(width: 620, height: 600)
    }

    private func save() {
        guard let url = URL(string: endpoint), !identifier.isEmpty, !name.isEmpty else {
            error = "Enter an identifier, name, and valid endpoint."; return
        }
        do {
            let trimmedID = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedID = trimmedID.hasPrefix("remote.") ? trimmedID : "remote.\(trimmedID)"
            let secretID = secret.isEmpty ? nil : normalizedID
            let manifest = TonicDataSourceManifest(id: normalizedID, displayName: name, providerVersion: "remote-1",
                minimumRefreshSeconds: max(60, interval), capabilities: [.label, .symbol, .image, .accessibilityText, .freshness, .semanticStatus])
            guard TonicProviderManifestPolicy.isValid(manifest),
                  TonicRemoteProviderPolicy.validate(url, allowsPrivateNetwork: allowsPrivateNetwork) == nil else {
                error = "Use a simple provider identifier and a permitted HTTPS endpoint."
                return
            }
            if let secretID { try TonicProviderSecretStore().save(Data(secret.utf8), identifier: secretID) }
            do {
                try onSave(TonicRemoteProviderConfiguration(manifest: manifest, endpoint: url,
                    refreshInterval: interval, secretIdentifier: secretID, allowsPrivateNetwork: allowsPrivateNetwork))
            } catch {
                if let secretID { try? TonicProviderSecretStore().delete(identifier: secretID) }
                throw error
            }
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
