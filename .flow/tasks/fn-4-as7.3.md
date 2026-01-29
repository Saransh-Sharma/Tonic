# fn-4-as7.3 Create PreferenceList shared component

## Description
TBD

## Acceptance
# Create PreferenceList shared component

Create a grouped list component for settings screens with Label + Control rows.

## Specs
- Grouped List with sections
- Section headers (Typography.caption)
- Row = Label (left) + Control (right)
- Supports: Toggle, Picker, Button, Status indicator

## Acceptance
- [ ] Component supports grouped sections
- [ ] Consistent padding (sm vertical, md horizontal)
- [ ] Toggle, Picker, Button controls work

## Deps: fn-4-as7.1


## Done summary
Created PreferenceList container, PreferenceSection, PreferenceRow and convenience wrappers (Toggle, Picker, Button, Status rows)
## Evidence
- Commits: 1957c3d
- Tests: xcodebuild build
- PRs: