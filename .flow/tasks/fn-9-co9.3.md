- [ ] No "makeIterator unavailable from async contexts" warnings
- [ ] All 8 files updated with `while let enumerator.nextObject()` pattern
- [ ] File scanning behaviors unchanged (test Deep Clean, Hidden Space scanner)
- [ ] Build succeeds

## Test Commands
```bash
xcodebuild -project Tonic/Tonic.xcodeproj -scheme Tonic build 2>&1 | grep -E "makeIterator.*unavailable" | wc -l
```
