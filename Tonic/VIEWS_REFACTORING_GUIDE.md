# Views Refactoring Guide - T16-T19

## Overview

This guide documents the refactoring strategy for large views in the Tonic app to break them down into smaller, maintainable components following the architecture principles established in the post-redesign quality initiative.

**Target**: Reduce PreferencesView (1515 lines → ~250 lines per section) and MaintenanceView (1022 lines → ~300 lines per view)

## Architecture Principles

### 1. Single Responsibility Principle

Each view should have ONE primary responsibility:
- Display data
- Handle user input
- Manage state
- Present navigation

```swift
// ❌ Bad: Multiple responsibilities
struct ComplexView: View {
    @State var data: Data
    @State var isLoading: Bool
    @State var error: Error?
    // 500 lines managing data, UI, validation, navigation
}

// ✅ Good: Single responsibility
struct DataDisplayView: View {
    let data: Data
    // 100 lines just for display
}
```

### 2. Container/Presenter Pattern

Separate state management from presentation:

```swift
// Container (manages state)
struct UserProfileContainer: View {
    @State private var user: User?
    @State private var isLoading: Bool = false

    var body: some View {
        if let user = user {
            UserProfilePresenter(user: user)
        } else if isLoading {
            ProgressView()
        }
    }
}

// Presenter (displays data)
struct UserProfilePresenter: View {
    let user: User

    var body: some View {
        VStack {
            // 100 lines of UI only
        }
    }
}
```

### 3. Composition Over Inheritance

Use subviews to build complex interfaces:

```swift
struct PreferencesView: View {
    var body: some View {
        List {
            GeneralSection()
            AppearanceSection()
            NotificationSection()
            AdvancedSection()
        }
    }
}

// Each section: ~100-150 lines
struct GeneralSection: View {
    @AppStorage("launchAtLogin") var launchAtLogin = false

    var body: some View {
        Section("General") {
            Toggle("Launch at Login", isOn: $launchAtLogin)
        }
    }
}
```

## Refactoring Patterns

### Pattern 1: Section Extraction

**Current State**: Single 1500-line view with all sections inline

**Target**: Extract each section into a separate component

```swift
// Before: PreferencesView (1515 lines)
struct PreferencesView: View {
    var body: some View {
        List {
            // General settings (200 lines)
            Section("General") { ... }

            // Appearance settings (200 lines)
            Section("Appearance") { ... }

            // Notifications (200 lines)
            Section("Notifications") { ... }

            // Advanced (200 lines)
            Section("Advanced") { ... }
        }
    }
}

// After: Extracted sections
struct PreferencesView: View {
    var body: some View {
        List {
            GeneralPreferencesSection()
            AppearancePreferencesSection()
            NotificationPreferencesSection()
            AdvancedPreferencesSection()
        }
    }
}

// Each new file: ~250 lines
// GeneralPreferencesSection.swift (250 lines)
struct GeneralPreferencesSection: View { ... }

// AppearancePreferencesSection.swift (250 lines)
struct AppearancePreferencesSection: View { ... }

// NotificationPreferencesSection.swift (250 lines)
struct NotificationPreferencesSection: View { ... }

// AdvancedPreferencesSection.swift (250 lines)
struct AdvancedPreferencesSection: View { ... }
```

### Pattern 2: State Extraction

**Current State**: All state in main view

**Target**: Extract state to @Observable model

```swift
// Before: State in view
struct MaintenanceView: View {
    @State var isScanning = false
    @State var progress: Double = 0.0
    @State var scanResults: ScanResult?
    @State var error: TonicError?
    // ... 20 more @State properties
}

// After: Extracted to observable model
@Observable
final class MaintenanceViewModel {
    var isScanning = false
    var progress: Double = 0.0
    var scanResults: ScanResult?
    var error: TonicError?

    func startScan() async { ... }
    func cancelScan() { ... }
}

struct MaintenanceView: View {
    @State private var viewModel = MaintenanceViewModel()

    var body: some View {
        if viewModel.isScanning {
            ScanProgressView(progress: viewModel.progress)
        } else if let error = viewModel.error {
            ErrorView(error: error, action: { await viewModel.startScan() })
        } else {
            ScanResultsView(results: viewModel.scanResults)
        }
    }
}
```

### Pattern 3: Sub-state Extraction

Break state into logical groups:

```swift
// Before: Flat @State properties
struct MaintenanceView: View {
    @State var selectedTab: Int = 0
    @State var scanIsRunning: Bool = false
    @State var scanProgress: Double = 0
    @State var scanResults: ScanResult?
    @State var scanError: TonicError?
    @State var cleanIsRunning: Bool = false
    @State var cleanProgress: Double = 0
    @State var cleanResults: CleanResult?
    // 50 lines of code logic)
}

// After: Grouped into logical units
struct MaintenanceView: View {
    @State private var selectedTab: Int = 0
    @State private var scanState = ScanState()
    @State private var cleanState = CleanState()
}

struct ScanState {
    var isRunning = false
    var progress: Double = 0
    var results: ScanResult?
    var error: TonicError?
}

struct CleanState {
    var isRunning = false
    var progress: Double = 0
    var results: CleanResult?
    var error: TonicError?
}
```

### Pattern 4: View Modifier Extraction

Extract repeated styling:

```swift
// Before: Repeated styling in many places
struct PreferencesView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Title")
                .font(.title2)
                .foregroundColor(.primary)

            Toggle("Option", isOn: $value)
                .padding(16)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            // ... repeated 20 times
        }
    }
}

// After: Extracted modifiers
extension View {
    func preferencesStyle() -> some View {
        self
            .padding(DesignTokens.Spacing.md)
            .background(DesignTokens.Colors.backgroundSecondary)
            .cornerRadius(DesignTokens.CornerRadius.medium)
    }

    func preferencesTitle() -> some View {
        self
            .font(DesignTokens.Typography.h3)
            .foregroundColor(DesignTokens.Colors.textPrimary)
    }
}

struct PreferencesView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Title")
                .preferencesTitle()

            Toggle("Option", isOn: $value)
                .preferencesStyle()
        }
    }
}
```

## Refactoring Checklist

### Before Refactoring
- [ ] Identify total line count
- [ ] Map all @State properties
- [ ] List all computed properties
- [ ] Identify reusable UI patterns
- [ ] Document all error cases
- [ ] List all user actions

### During Refactoring
- [ ] Extract sections into separate files
- [ ] Move state to @Observable models
- [ ] Create custom view modifiers
- [ ] Add error handling with ErrorView
- [ ] Add input validation
- [ ] Add accessibility labels

### After Refactoring
- [ ] Each file < 300 lines
- [ ] All @State in view models
- [ ] All styling via design tokens
- [ ] All errors use TonicError
- [ ] All user input validated
- [ ] Tests pass for all components

## Specific View Targets

### PreferencesView Refactoring (1515 → 4×250)

**Current structure**:
```
PreferencesView (1515 lines)
├── General settings (200 lines)
├── Appearance settings (200 lines)
├── Notifications (200 lines)
├── Advanced settings (200 lines)
└── State/Logic (400 lines)
```

**Target structure**:
```
PreferencesView (150 lines) - Container only
├── GeneralPreferencesSection.swift (250 lines)
├── AppearancePreferencesSection.swift (250 lines)
├── NotificationPreferencesSection.swift (250 lines)
├── AdvancedPreferencesSection.swift (250 lines)
└── PreferencesViewModel.swift (200 lines) - State & logic
```

**Extraction order**:
1. Create PreferencesViewModel.swift with all @State and @Published
2. Extract GeneralPreferencesSection
3. Extract AppearancePreferencesSection
4. Extract NotificationPreferencesSection
5. Extract AdvancedPreferencesSection
6. Simplify PreferencesView to container
7. Add tests for each section
8. Add error handling with ErrorView

### MaintenanceView Refactoring (1022 → 3×300)

**Current structure**:
```
MaintenanceView (1022 lines)
├── Scan Tab UI (350 lines)
├── Clean Tab UI (350 lines)
└── State/Logic (300 lines)
```

**Target structure**:
```
MaintenanceView (150 lines) - Container & tab selector
├── ScanTabView.swift (300 lines)
├── CleanTabView.swift (300 lines)
└── MaintenanceViewModel.swift (250 lines) - State & logic
```

**Extraction order**:
1. Create MaintenanceViewModel.swift
2. Extract ScanTabView (separate file)
3. Extract CleanTabView (separate file)
4. Simplify MaintenanceView
5. Add error handling
6. Add input validation
7. Add tests

## State Management Best Practices

### Use @Observable for Complex State

```swift
@Observable
final class AppState {
    var isLoading = false
    var data: [Item] = []
    var error: TonicError?

    func loadData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            data = try await fetchData()
            error = nil
        } catch let error as TonicError {
            self.error = error
        } catch {
            self.error = .unknown(reason: error.localizedDescription)
        }
    }
}
```

### Use @AppStorage for Preferences

```swift
struct GeneralPreferencesSection: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("checkForUpdates") private var checkForUpdates = true

    var body: some View {
        Section("General") {
            Toggle("Launch at Login", isOn: $launchAtLogin)
            Toggle("Check for Updates", isOn: $checkForUpdates)
        }
    }
}
```

### Use @Environment for Shared Dependencies

```swift
struct AppView: View {
    @State private var errorHandler = ErrorHandler()

    var body: some View {
        ContentView()
            .environment(errorHandler)
    }
}

struct SomeView: View {
    @Environment(ErrorHandler.self) var errorHandler

    func handleError(_ error: TonicError) {
        errorHandler.present(error)
    }
}
```

## Common Refactoring Tasks

### Add Error Handling
```swift
// Before: No error handling
struct ScanView: View {
    var body: some View {
        Button("Start Scan") {
            Task { await startScan() }
        }
    }
}

// After: With error handling
struct ScanView: View {
    @State private var error: TonicError?

    var body: some View {
        VStack {
            Button("Start Scan") {
                Task {
                    do {
                        try await startScan()
                    } catch let err as TonicError {
                        error = err
                    }
                }
            }

            if let error = error {
                ErrorView(error: error, action: { /* retry */ })
            }
        }
    }
}
```

### Add Input Validation
```swift
// Before: No validation
struct NameInput: View {
    @State private var name = ""

    var body: some View {
        TextField("Name", text: $name)
    }
}

// After: With validation
struct NameInput: View {
    @State private var name = ""
    @State private var error: TonicError?

    var body: some View {
        VStack {
            TextField("Name", text: $name)
                .onChange(of: name) { oldVal, newVal in
                    do {
                        try NonemptyValidator(fieldName: "Name").validate(newVal)
                        error = nil
                    } catch let err as TonicError {
                        error = err
                    }
                }

            if let error = error {
                InlineErrorMessage(message: error.errorDescription ?? "", isVisible: true)
            }
        }
    }
}
```

## Performance Considerations

### Use LazyVStack for Large Lists
```swift
// ❌ Renders all 1000 items at once
var body: some View {
    VStack {
        ForEach(items) { item in
            ItemRow(item: item)
        }
    }
}

// ✅ Lazy rendering
var body: some View {
    LazyVStack {
        ForEach(items) { item in
            ItemRow(item: item)
        }
    }
}
```

### Use .id() for List Updates
```swift
// Helps SwiftUI track changes properly
List(items, id: \.id) { item in
    ItemRow(item: item)
}
```

### Avoid Unnecessary Recomputation
```swift
// ❌ Recomputes every render
var body: some View {
    let sorted = items.sorted()  // Computed on every render
    return VStack {
        ForEach(sorted) { ... }
    }
}

// ✅ Cache computed value
@State private var sortedItems: [Item] = []
var body: some View {
    VStack {
        ForEach(sortedItems) { ... }
    }
    .onChange(of: items) { oldVal, newVal in
        sortedItems = newVal.sorted()
    }
}
```

## Testing Refactored Views

```swift
final class GeneralPreferencesSectionTests: XCTestCase {
    func testToggleState() {
        let view = GeneralPreferencesSection()
        // Test toggle behavior
    }

    func testErrorDisplay() {
        // Test error handling in section
    }

    func testAccessibility() {
        // Test accessibility labels
    }
}
```

## Rollout Strategy

1. **Phase 1**: Refactor PreferencesView
   - Extract sections
   - Update tests
   - Deploy

2. **Phase 2**: Refactor MaintenanceView
   - Split tabs
   - Update state management
   - Update tests

3. **Phase 3**: Refactor remaining views
   - DiskAnalysisView
   - AppInventoryView
   - SystemStatusDashboard

## Success Criteria

✅ All view files < 300 lines
✅ All state in @Observable models
✅ All styling via DesignTokens
✅ All errors handled with TonicError
✅ All user input validated
✅ 90%+ test coverage per view
✅ Accessibility audit passing
✅ Performance metrics maintained
✅ No regressions in functionality

## Resources

- [Swift UI State Management](https://developer.apple.com/documentation/swiftui)
- [Observable Pattern](https://developer.apple.com/documentation/observation)
- [View Composition Best Practices](https://developer.apple.com/videos/play/wwdc2022/10055)
- Design tokens: `Tonic/Design/DesignTokens.swift`
- Error handling: `Tonic/Models/TonicError.swift`
- Validation: `Tonic/Design/InputValidation.swift`
