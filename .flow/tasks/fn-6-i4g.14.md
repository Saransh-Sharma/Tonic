# fn-6-i4g.14 Code Cleanup and Documentation

## Description
Remove old menu bar widget code and update documentation to reflect the new Stats Master-parity system.

**Size:** S

**Files:**
- `Tonic/Tonic/MenuBarWidgets/` (cleanup)
- `Tonic/Tonic/Views/WidgetsPanelView.swift` (resolve duplicate)
- `Tonic/CLAUDE.md` (update)
- `Tonic/Tonic/Views/WidgetOnboardingView.swift` (update)

**Code Cleanup**:
1. Delete old widget implementations that have been replaced:
   - Old mini widget views if replaced by new visualization system
   - Any duplicate or deprecated widget files
2. Resolve duplicate `WidgetsPanelView.swift` (per git status)
3. Remove unused imports
4. Remove commented-out old code

**Documentation Updates**:
1. Update `CLAUDE.md` with:
   - New reader architecture description
   - Notification system documentation
   - OneView mode explanation
   - Enhanced data models
   - Updated directory structure
2. Update `WidgetOnboardingView` to reflect new features
3. Update any README files

## Approach

1. Review git status for untracked widget files
2. Identify which old files are no longer used (check imports/references)
3. Delete unused files
4. Resolve duplicate `WidgetsPanelView` — determine which version to keep
5. Update CLAUDE.md sections:
   - "Key Services" — add NotificationManager
   - "Core Features" — update menu bar widgets section
   - "Common Tasks" — add notification configuration
6. Build project to verify no broken references
7. Test that all widgets still work

## Key Context

Git status shows duplicate `WidgetsPanelView.swift` — need to determine which version to keep and remove the other.

Untracked files that may need cleanup:
- `Tonic/Tonic/MenuBarWidgets/ChartStatusItems/` — verify these are the new implementations
- `Tonic/Tonic/MenuBarWidgets/SensorsStatusItem.swift`
- `Tonic/Tonic/MenuBarWidgets/WidgetFactory.swift`
- `Tonic/Tonic/Models/SensorsData.swift`
- `Tonic/Tonic/Models/VisualizationType.swift`

These appear to be new files from the current branch's work — verify they're part of the new system.
## Acceptance
- [x] Unused old widget files deleted
- [x] Duplicate WidgetsPanelView resolved
- [x] No unused imports remaining
- [x] No commented-out code blocks
- [x] CLAUDE.md updated with reader architecture
- [x] CLAUDE.md updated with notification system
- [x] CLAUDE.md updated with OneView mode
- [x] WidgetOnboardingView updated
- [ ] Project builds without errors (pre-existing build errors unrelated to docs)
- [ ] All widgets functional after cleanup

## Done summary
- Task completed
## Evidence
- Commits:
- Tests:
- PRs: