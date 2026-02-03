# fn-5-v8r.3 WidgetStore configuration persistence with migration

## Description
Implement WidgetStore for configuration persistence following Stats Master's Store pattern. Handles UserDefaults persistence with in-memory cache and legacy migration.

## Implementation

Create `Tonic/Tonic/Services/WidgetStore.swift`:

```swift
@Observable
@MainActor
final class WidgetStore {
    static let shared = WidgetStore()

    private let defaults = UserDefaults.standard
    private var cache: [String: Any] = [:]

    func saveConfig(_ config: WidgetConfig)
    func loadConfig(id: UUID) -> WidgetConfig?
    func loadAllConfigs() -> [WidgetConfig]
    func deleteConfig(id: UUID)

    private func migrateLegacyConfig()  // From old WidgetPreferences
}
```

## Acceptance
- [ ] Configs persist to UserDefaults with JSON encoding
- [ ] Legacy configs migrate from WidgetPreferences
- [ ] Migration is atomic (fallback on failure)
- [ ] In-memory cache improves read performance

## Done summary
- Task completed
## Evidence
- Commits:
- Tests:
- PRs:
## References
- Stats Master: `stats-master/Kit/plugins/Store.swift:14-137`
- Tonic current: `Tonic/Tonic/Models/WidgetConfiguration.swift:277-500`
