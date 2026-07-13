import AppKit
import SwiftUI

struct MenuBarProfilesCard: View {
    @State private var store = MenuBarProfileStore.shared
    @State private var newContextName = ""

    var body: some View {
        SettingsPanel(title: "DISPLAY & CONTEXTS") {
            TonicPreferenceRow(title: "Manual context",
                               description: "Space-like Work, Home, or Recording profiles using supported public APIs only.") {
                Picker("", selection: contextBinding) {
                    Text("Global").tag(UUID?.none)
                    ForEach(store.manualContexts) { Text($0.name).tag(UUID?.some($0.id)) }
                }.labelsHidden().frame(width: 150)
            }
            ForEach(store.manualContexts) { context in
                TonicPreferenceRow(title: context.name, description: "Selectable manually or from a trigger") {
                    Button(role: .destructive) { store.removeContext(id: context.id) } label: { Image(systemName: "trash") }
                        .buttonStyle(.borderless)
                }
            }
            if let contextID = store.selectedManualContextID,
               let context = store.manualContexts.first(where: { $0.id == contextID }) {
                TonicPreferenceRow(title: "\(context.name) Quick Shelf",
                                   description: "Overrides the global presentation only while this context is active") {
                    Picker("Presentation", selection: contextPresentationBinding(context)) {
                        ForEach(QuickShelfPresentation.allCases, id: \.self) { Text($0.title).tag($0) }
                    }.labelsHidden().frame(width: 145)
                }
                TonicPreferenceRow(title: "\(context.name) behavior",
                                   description: "Context overrides remain independent of physical item ordering") {
                    HStack {
                        Toggle("Overflow", isOn: contextOverflowBinding(context)).toggleStyle(.checkbox)
                        Toggle("Hide inactive", isOn: contextInactiveBinding(context)).toggleStyle(.checkbox)
                        Toggle("Hover", isOn: contextHoverBinding(context)).toggleStyle(.checkbox)
                        Toggle("Appearance", isOn: contextAppearanceBinding(context)).toggleStyle(.checkbox)
                    }
                }
            }
            TonicPreferenceRow(title: "New context", description: "Physical foreign-item ordering remains global.") {
                HStack {
                    TextField("Work", text: $newContextName).textFieldStyle(.roundedBorder).frame(width: 110)
                    Button("Add") { addContext() }.buttonStyle(.bordered)
                }
            }
            ForEach(NSScreen.screens.map(DisplayIdentity.init), id: \.self) { display in
                TonicPreferenceRow(title: display.fallbackName,
                                   description: "Per-display Quick Shelf and presentation override") {
                    Picker("", selection: presentationBinding(display)) {
                        ForEach(QuickShelfPresentation.allCases, id: \.self) { Text($0.title).tag($0) }
                    }.labelsHidden().frame(width: 145)
                }
                TonicPreferenceRow(title: "\(display.fallbackName) behavior",
                                   description: "Overflow and inactive-display presentation only") {
                    HStack {
                        Picker("Shelf target", selection: targetBinding(display)) {
                            Text("Active display").tag(QuickShelfDisplayTarget.activeDisplay)
                            Text("This display").tag(QuickShelfDisplayTarget.specific(display))
                        }.labelsHidden().frame(width: 120)
                        Toggle("Overflow", isOn: overflowBinding(display)).toggleStyle(.checkbox)
                        Toggle("Hide inactive", isOn: inactiveBinding(display)).toggleStyle(.checkbox)
                    }
                }
                TonicPreferenceRow(title: "\(display.fallbackName) overrides",
                                   description: "Appearance and reveal behavior remain independent of physical ordering") {
                    HStack {
                        Toggle("Appearance", isOn: appearanceBinding(display)).toggleStyle(.checkbox)
                        Toggle("Hover", isOn: hoverBinding(display)).toggleStyle(.checkbox)
                    }
                }
            }
        }
    }

    private var contextBinding: Binding<UUID?> {
        Binding(get: { store.selectedManualContextID }, set: {
            store.selectContext($0)
            NotificationCenter.default.post(name: .menuBarPresentationContextDidChange, object: nil)
        })
    }

    private func presentationBinding(_ display: DisplayIdentity) -> Binding<QuickShelfPresentation> {
        Binding(get: {
            MenuBarProfileResolver().resolve(profiles: store.profiles, display: display,
                                             manualContextID: nil).quickShelfPresentation ?? .compactStrip
        }, set: { value in
            store.updateValues(scope: .display(display), name: display.fallbackName) { $0.quickShelfPresentation = value }
        })
    }

    private func targetBinding(_ display: DisplayIdentity) -> Binding<QuickShelfDisplayTarget> {
        Binding(get: { resolved(display).quickShelfTarget ?? .activeDisplay }, set: { value in
            store.updateValues(scope: .display(display), name: display.fallbackName) { $0.quickShelfTarget = value }
        })
    }

    private func overflowBinding(_ display: DisplayIdentity) -> Binding<Bool> {
        Binding(get: { resolved(display).showsOverflow ?? true }, set: { value in
            store.updateValues(scope: .display(display), name: display.fallbackName) { $0.showsOverflow = value }
        })
    }

    private func inactiveBinding(_ display: DisplayIdentity) -> Binding<Bool> {
        Binding(get: { resolved(display).hidesOnInactiveDisplays ?? false }, set: { value in
            store.updateValues(scope: .display(display), name: display.fallbackName) { $0.hidesOnInactiveDisplays = value }
        })
    }

    private func appearanceBinding(_ display: DisplayIdentity) -> Binding<Bool> {
        Binding(get: {
            store.explicitValues(for: .display(display))?.appearance != nil
        }, set: { enabled in
            store.updateValues(scope: .display(display), name: display.fallbackName) {
                $0.appearance = enabled ? MenuBarManagerSettingsStore.shared.settings.styling : nil
            }
        })
    }

    private func hoverBinding(_ display: DisplayIdentity) -> Binding<Bool> {
        Binding(get: { resolved(display).revealBehavior?.showOnHover ?? true }, set: { enabled in
            let settings = MenuBarManagerSettingsStore.shared.settings
            store.updateValues(scope: .display(display), name: display.fallbackName) {
                $0.revealBehavior = MenuBarRevealBehaviorSnapshot(showOnHover: enabled,
                    showOnClickEmptyMenuBar: settings.showOnClickEmptyMenuBar,
                    showOnScroll: settings.showOnScroll, autoRehide: settings.autoRehide,
                    quickShelfPresentation: settings.quickShelfPresentation)
            }
        })
    }

    private func resolved(_ display: DisplayIdentity) -> MenuBarPresentationValues {
        MenuBarProfileResolver().resolve(profiles: store.profiles, display: display, manualContextID: nil)
    }

    private func contextValues(_ context: MenuBarManualContext) -> MenuBarPresentationValues {
        MenuBarProfileResolver().resolve(profiles: store.profiles, display: nil, manualContextID: context.id)
    }

    private func contextPresentationBinding(_ context: MenuBarManualContext) -> Binding<QuickShelfPresentation> {
        Binding(get: { contextValues(context).quickShelfPresentation ?? .compactStrip }, set: { value in
            store.updateValues(scope: .manualContext(context.id), name: context.name) { $0.quickShelfPresentation = value }
        })
    }

    private func contextOverflowBinding(_ context: MenuBarManualContext) -> Binding<Bool> {
        Binding(get: { contextValues(context).showsOverflow ?? true }, set: { value in
            store.updateValues(scope: .manualContext(context.id), name: context.name) { $0.showsOverflow = value }
        })
    }

    private func contextInactiveBinding(_ context: MenuBarManualContext) -> Binding<Bool> {
        Binding(get: { contextValues(context).hidesOnInactiveDisplays ?? false }, set: { value in
            store.updateValues(scope: .manualContext(context.id), name: context.name) { $0.hidesOnInactiveDisplays = value }
        })
    }

    private func contextHoverBinding(_ context: MenuBarManualContext) -> Binding<Bool> {
        Binding(get: { contextValues(context).revealBehavior?.showOnHover ?? true }, set: { enabled in
            let settings = MenuBarManagerSettingsStore.shared.settings
            store.updateValues(scope: .manualContext(context.id), name: context.name) {
                $0.revealBehavior = MenuBarRevealBehaviorSnapshot(showOnHover: enabled,
                    showOnClickEmptyMenuBar: settings.showOnClickEmptyMenuBar,
                    showOnScroll: settings.showOnScroll, autoRehide: settings.autoRehide,
                    quickShelfPresentation: settings.quickShelfPresentation)
            }
        })
    }

    private func contextAppearanceBinding(_ context: MenuBarManualContext) -> Binding<Bool> {
        Binding(get: {
            store.explicitValues(for: .manualContext(context.id))?.appearance != nil
        }, set: { enabled in
            store.updateValues(scope: .manualContext(context.id), name: context.name) {
                $0.appearance = enabled ? MenuBarManagerSettingsStore.shared.settings.styling : nil
            }
        })
    }

    private func addContext() {
        let name = newContextName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let context = store.addContext(name: name); store.selectContext(context.id); newContextName = ""
    }
}
