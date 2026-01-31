# fn-6-i4g.13 User Preferences Migration

## Description
Create migration layer to preserve existing user preferences when transitioning to the new menu bar system.

**Size:** M

**Files:**
- `Tonic/Tonic/Models/WidgetConfiguration.swift` (modify - add migration)
- `Tonic/Tonic/Services/WidgetPreferences.swift` (modify - add migration)

**Migration Requirements**:
1. Preserve user's enabled widgets
2. Preserve widget positions
3. Preserve widget display modes
4. Preserve widget colors and customizations
5. Map old config structure to new structure (if changed)
6. Create backup before migration
7. Handle migration failures gracefully

**New Data Model Considerations**:
- If `VisualizationType` wasn't in old config, default to `.mini`
- If new fields added (e.g., unifiedMenuBarMode), use sensible defaults
- Migrate Weather widget config (Tonic exclusive)

## Approach

1. Create `migrateIfNeeded()` method in `WidgetPreferences`
2. Add `migrationVersion` key to UserDefaults
3. On init, check if migration needed
4. If needed:
   - Create backup of existing config
   - Read old config structure
   - Map to new structure
   - Save new config
   - Update migration version
5. If migration fails, log error and fallback to defaults
6. Test with various config versions (empty, partial, full)

## Key Context

Current config key: `"tonic.widget.configs"` stores `[WidgetConfiguration]` encoded as JSON.

Old config format may differ from new format if we change `WidgetConfiguration` struct. Use versioned decoding:

```swift
static func loadConfigsFromUserDefaults() -> [WidgetConfiguration] {
    // Try v2 first, fallback to v1, then defaults
}
```

Reference: `WidgetConfiguration.swift:397-484` for existing multi-version decoding.
## Acceptance
- [ ] migrateIfNeeded() method implemented
- [ ] migrationVersion key added to UserDefaults
- [ ] Migration runs on WidgetPreferences init
- [ ] Backup created before migration
- [ ] Old config mapped to new structure
- [ ] Weather widget config preserved
- [ ] Widget positions preserved
- [ ] Widget customizations preserved
- [ ] Migration failure falls back to defaults
- [ ] Migration logged for debugging
- [ ] Tested with empty config
- [ ] Tested with partial config
- [ ] Tested with full config
## Done summary
TBD

## Evidence
- Commits:
- Tests:
- PRs:
