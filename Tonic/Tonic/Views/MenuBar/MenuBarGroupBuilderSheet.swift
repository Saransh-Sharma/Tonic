import SwiftUI

struct MenuBarGroupBuilderSheet: View {
    let existing: MenuBarItemGroup?
    let items: [MenuBarItemInfo]
    let onSave: (MenuBarItemGroup) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = "New Group"
    @State private var symbolName = "square.grid.2x2"
    @State private var accent = Color.accentColor
    @State private var usesAccent = false
    @State private var isPinned = false
    @State private var presentation: QuickShelfPresentation?
    @State private var selectedKeys = Set<String>()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(existing == nil ? "New Quick Shelf Group" : "Edit Quick Shelf Group").font(.title2.bold())
            Form {
                TextField("Name", text: $name)
                TextField("SF Symbol", text: $symbolName)
                Toggle("Pin as a real Tonic status item after Apply", isOn: $isPinned)
                Picker("Presentation", selection: $presentation) {
                    Text("Use global preference").tag(QuickShelfPresentation?.none)
                    ForEach(QuickShelfPresentation.allCases, id: \.self) { Text($0.title).tag(Optional($0)) }
                }
                Toggle("Accent color", isOn: $usesAccent)
                if usesAccent { ColorPicker("Accent", selection: $accent, supportsOpacity: false) }
                Section("Members") {
                    if items.isEmpty { Text("No foreign menu bar items are currently discoverable.").foregroundStyle(.secondary) }
                    ForEach(items.filter { !$0.isSystemControlled }) { item in
                        Toggle(isOn: memberBinding(item.stableKey)) {
                            HStack {
                                if let icon = item.nsImage { Image(nsImage: icon).resizable().frame(width: 18, height: 18) }
                                Text(item.displayName)
                                Spacer()
                                Text(item.bundleIdentifier ?? item.ownerName).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }.formStyle(.grouped)
            HStack {
                Button("Cancel") { dismiss() }.buttonStyle(.bordered)
                Spacer()
                PrimaryPill("Save to Draft", isDisabled: name.trimmingCharacters(in: .whitespaces).isEmpty) { save() }
            }
        }
        .padding(24).frame(width: 620, height: 650)
        .onAppear(perform: load)
    }

    private func memberBinding(_ key: String) -> Binding<Bool> {
        Binding(get: { selectedKeys.contains(key) }, set: { selected in
            if selected { selectedKeys.insert(key) } else { selectedKeys.remove(key) }
        })
    }
    private func load() {
        guard let existing else { return }
        name = existing.name; symbolName = existing.symbolName; isPinned = existing.isPinned
        presentation = existing.presentationOverride; selectedKeys = Set(existing.itemKeys)
        if let hex = existing.accentHex, let color = Color(menuBarHex: hex) { usesAccent = true; accent = color }
    }
    private func save() {
        onSave(MenuBarItemGroup(id: existing?.id ?? UUID(), name: name.trimmingCharacters(in: .whitespaces),
                                itemKeys: selectedKeys.sorted(), symbolName: symbolName,
                                accentHex: usesAccent ? accent.menuBarHexString : nil,
                                isPinned: isPinned, presentationOverride: presentation))
        dismiss()
    }
}
