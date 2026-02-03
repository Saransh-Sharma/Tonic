- [x] All Codable warnings removed (5 structs)
- [x] All `String(cString:)` warnings removed (search project-wide)
- [x] IDs are preserved on decode when present (stable identity maintained)
- [x] New instances still get generated UUIDs
- [x] Existing persisted data still decodes correctly
- [x] Build succeeds

## Test Commands
```bash
# Find all String(cString:) usage
rg "String\(cString:" Tonic/Tonic/ --type swift

# Count Codable warnings
xcodebuild -project Tonic/Tonic.xcodeproj -scheme Tonic build 2>&1 | grep -E "immutable property.*will not be decoded" | wc -l
```

## Done summary
- Task completed
## Evidence
- Commits:
- Tests:
- PRs: