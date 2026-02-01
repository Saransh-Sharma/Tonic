# fn-6-i4g.33 Tabbed Settings Interface

## Description

Replace current single-page settings with Stats Master's tabbed interface. Stats Master uses a 720x480px window with 180px sidebar for module selection.

## New Files to Create

1. **Tonic/Tonic/Views/Settings/SettingsWindow.swift** - Main NSWindow
2. **Tonic/Tonic/Views/Settings/SettingsSidebar.swift** - Module list sidebar
3. **Tonic/Tonic/Views/Settings/SettingsContainerView.swift** - Tab content container
4. **Tonic/Tonic/Views/Settings/SettingsTab/GeneralSettingsView.swift** - General settings
5. **Tonic/Tonic/Views/Settings/SettingsTab/ModulesSettingsView.swift** - Per-module settings
6. **Tonic/Tonic/Views/Settings/SettingsTab/AppearanceSettingsView.swift** - Appearance
7. **Tonic/Tonic/Views/Settings/SettingsTab/NotificationsSettingsView.swift** - Notifications

## Window Structure

```
┌─────────────────────────────────────────────────────────────────────┐
│ Settings                                          [−] [□] [×]      │
├──────────────┬────────────────────────────────────────────────────────┤
│              │                                                       │
│ General      │ [General Settings Content]                           │
│ Modules      │                                                       │
│ Appearance   │                                                       │
│ Notifications│                                                       │
│              │                                                       │
│              │                                                       │
│              │                                                       │
│              │                                                       │
└──────────────┴────────────────────────────────────────────────────────┘
     180px                        540px
```

## Implementation

### Step 1: Settings Window

```swift
// File: Tonic/Tonic/Views/Settings/SettingsWindow.swift

import SwiftUI

@MainActor
class SettingsWindow: NSWindow {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        self.title = "Settings"
        self.isReleasedWhenClosed = false
        self.center()

        let contentView = SettingsContainerView()
        self.contentViewController = NSHostingController(rootView: contentView)
    }

    func show() {
        self.makeKeyAndOrderFront(nil)
    }
}

// Singleton access
extension SettingsWindow {
    static let shared = SettingsWindow()
}
```

### Step 2: Settings Container

```swift
// File: Tonic/Tonic/Views/Settings/SettingsContainerView.swift

import SwiftUI

enum SettingsTab: String, CaseIterable {
    case general = "General"
    case modules = "Modules"
    case appearance = "Appearance"
    case notifications = "Notifications"

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .modules: return "square.grid.2x2"
        case .appearance: return "paintpalette"
        case .notifications: return "bell"
        }
    }
}

struct SettingsContainerView: View {
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(SettingsTab.allCases, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
                    .tag(tab)
            }
            .navigationSplitViewColumnWidth(min: 150, ideal: 180)
            .frame(minWidth: 150, maxWidth: 200)
        } detail: {
            // Content
            Group {
                switch selectedTab {
                case .general:
                    GeneralSettingsView()
                case .modules:
                    ModulesSettingsView()
                case .appearance:
                    AppearanceSettingsView()
                case .notifications:
                    NotificationsSettingsView()
                }
            }
            .frame(minWidth: 400)
            .padding()
        }
        .frame(minWidth: 600, minHeight: 400)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Text("Settings")
                    .font(.headline)
            }
        }
    }
}
```

### Step 3: General Settings View

```swift
// File: Tonic/Tonic/Views/Settings/SettingsTab/GeneralSettingsView.swift

import SwiftUI

struct GeneralSettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("checkForUpdates") private var checkForUpdates = true
    @AppStorage("unifiedMenuBarMode") private var unifiedMenuBarMode = false

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                Toggle("Unified menu bar mode", isOn: $unifiedMenuBarMode)
                    .help("Show all widgets in a single menu bar item")
            }

            Section("Updates") {
                Toggle("Check for updates automatically", isOn: $checkForUpdates)
            }

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }
}
```

### Step 4: Modules Settings View

```swift
// File: Tonic/Tonic/Views/Settings/SettingsTab/ModulesSettingsView.swift

import SwiftUI

struct ModulesSettingsView: View {
    @State private var selectedModule: WidgetType = .cpu

    var body: some View {
        NavigationSplitView {
            // Module list
            List(WidgetType.allCases, selection: $selectedModule) { module in
                Label(module.displayName, systemImage: module.icon)
                    .tag(module)
            }
            .frame(minWidth: 120)
        } detail: {
            // Module-specific settings
            ModuleSettingsView(module: selectedModule)
        }
    }
}

// Placeholder for per-module settings
struct ModuleSettingsView: View {
    let module: WidgetType

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(module.displayName + " Settings")
                .font(.title2)

            // Widget enabled
            Toggle("Show in menu bar", isOn: bindingForEnabled())

            // Visualization type
            Picker("Visualization", selection: bindingForVisualization()) {
                ForEach(module.compatibleVisualizations, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }

            // Update interval
            Picker("Update interval", selection: bindingForInterval()) {
                Text("1 second").tag(1)
                Text("2 seconds").tag(2)
                Text("5 seconds").tag(5)
                Text("Never").tag(0)
            }

            Spacer()
        }
        .padding()
    }

    private func bindingForEnabled() -> Binding<Bool> {
        Binding {
            WidgetPreferences.shared.isEnabled(module)
        } set: { newValue in
            WidgetPreferences.shared.setEnabled(module, enabled: newValue)
        }
    }

    private func bindingForVisualization() -> Binding<VisualizationType> {
        Binding {
            WidgetPreferences.shared.configuration(for: module).visualizationType
        } set: { newValue in
            WidgetPreferences.shared.setVisualizationType(for: module, type: newValue)
        }
    }

    private func bindingForInterval() -> Binding<Int> {
        Binding {
            WidgetPreferences.shared.updateInterval(for: module)
        } set: { newValue in
            WidgetPreferences.shared.setUpdateInterval(for: module, interval: newValue)
        }
    }
}
```

### Step 5: Open Settings from Menu

```swift
// In TonicApp.swift or wherever menu is defined

Button("Settings...") {
    SettingsWindow.shared.show()
}
```

## Acceptance

- [ ] Settings window opens at 720x480px
- [ ] Sidebar shows 4 tabs: General, Modules, Appearance, Notifications
- [ ] Clicking tabs switches content view
- [ ] Modules tab shows nested split view (modules | settings)
- [ ] General settings include launch at login, unified mode
- [ ] Per-module settings show enabled toggle, visualization, interval
- [ ] Changes apply immediately (via reactive pattern from fn-6-i4g.28)

## Done Summary

Created Stats Master-style tabbed settings interface with 180px sidebar and per-module configuration panels. Replaced single-page settings with organized navigation structure.

## Evidence

- Commits:
- Tests:
- PRs:
