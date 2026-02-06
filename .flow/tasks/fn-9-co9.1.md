- [ ] ActionTable.swift warning gone ("redeclaration of associated type 'ID'")
- [ ] Main.storyboard reference removed from project.pbxproj
- [ ] Main.storyboard removed from Resources build phase
- [ ] Main.storyboard file deleted
- [ ] NSMainStoryboardFile key removed from Info.plist
- [ ] Storyboard warning gone
- [ ] App launches and displays UI correctly via SwiftUI lifecycle
- [ ] No startup errors in Console.app

## Done summary
Removed redundant Identifiable conformance warning in ActionTable.swift and fully removed Main.storyboard references (Info.plist, project.pbxproj, and deleted file). The app now launches purely via SwiftUI lifecycle.
## Evidence
- Commits: 2738877be3f9a8cfd1fd5442e6477918d42449e3
- Tests: xcodebuild -project Tonic/Tonic.xcodeproj -scheme Tonic build
- PRs:
## Test Commands
```bash
# Verify storyboard not in project
grep -c "Main.storyboard" Tonic/Tonic.xcodeproj/project.pbxproj
# Should return 0

# Build test
xcodebuild -project Tonic/Tonic.xcodeproj -scheme Tonic build 2>&1 | grep -E "ActionTable.swift|Main.storyboard|warning:|error:"

# Launch test
open Tonic.app && # verify UI appears
```
