- [ ] All Codable warnings removed (5 structs)
- [ ] All `String(cString:)` warnings removed (search project-wide)
- [ ] IDs are preserved on decode when present (stable identity maintained)
- [ ] New instances still get generated UUIDs
- [ ] Existing persisted data still decodes correctly
- [ ] Build succeeds

## Test Commands
```bash
# Find all String(cString:) usage
rg "String\(cString:" Tonic/Tonic/ --type swift

# Count Codable warnings
xcodebuild -project Tonic/Tonic.xcodeproj -scheme Tonic build 2>&1 | grep -E "immutable property.*will not be decoded" | wc -l
```
