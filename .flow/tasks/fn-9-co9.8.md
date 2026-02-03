- [ ] xcodebuild clean build reports 0 warnings
- [ ] Build passes successfully
- [ ] App runs without regressions
- [ ] [Optional] Deprecated aliases removed from DesignTokens.swift
- [ ] [Optional] Strict flags considered/enabled
- [ ] CLAUDE.md updated (remove deprecated token references)
- [ ] Design.md updated (use new token names in examples)
- [ ] README.md updated (if Swift 6 settings changed)

## Verification Commands
```bash
# Clean build and capture all output
xcodebuild -project Tonic/Tonic.xcodeproj -scheme Tonic clean build 2>&1 | tee /tmp/final-build.log

# Count ALL warnings (not just "warning:" pattern)
grep -i "warning" /tmp/final-build.log | wc -l
# Should be 0

# Also check build summary
grep -E "warnings generated|BUILD SUCCEEDED" /tmp/final-build.log

# Verify no deprecated token usage in docs
grep -E "headlineSmall|displayLarge|surfaceHovered" CLAUDE.md Tonic/docs/Design.md || echo "Docs clean"
```
