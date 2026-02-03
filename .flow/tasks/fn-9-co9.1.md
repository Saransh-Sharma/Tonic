- [ ] ActionTable.swift warning gone ("redeclaration of associated type 'ID'")
- [ ] Main.storyboard reference removed from project.pbxproj
- [ ] Main.storyboard removed from Resources build phase
- [ ] Main.storyboard file deleted
- [ ] NSMainStoryboardFile key removed from Info.plist
- [ ] Storyboard warning gone
- [ ] App launches and displays UI correctly via SwiftUI lifecycle
- [ ] No startup errors in Console.app

## Done summary
<!--
Fill this out when marking the task as done. The summary should:
- Describe what was implemented (1-2 sentences)
- Key files changed
- Tests run (if any)
-->

## Evidence
<!--
JSON evidence for what was done. Format:
{"commits": ["sha1", "sha2"], "tests": ["cmd1", "cmd2"], "prs": ["url1", "url2"]}
-->

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
