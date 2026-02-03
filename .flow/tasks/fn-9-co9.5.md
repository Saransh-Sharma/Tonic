- [ ] NSUserNotification warnings gone (routed through NotificationManager)
- [ ] NSWorkspace.launchApplication warnings gone (8 instances)
- [ ] NSWorkspace+Launch.swift helper created
- [ ] SMJobBless warnings eliminated (either: helper removed OR SMAppService migration complete)
- [ ] All deprecated API warnings = 0
- [ ] Notifications still appear as before
- [ ] Activity Monitor button still works
- [ ] If helper migrated: install/uninstall flow works across macOS 13+

## Test Commands
```bash
# Verify 0 deprecated API warnings
xcodebuild -project Tonic/Tonic.xcodeproj -scheme Tonic build 2>&1 | grep -E "deprecated.*launchApplication|NSUserNotification|SMJobBless|SMJobRemove|SMJobCopyDictionary" | wc -l
# Must return 0

# Check helper status
find . -name "*Helper*" | grep -v ".flow"
```
