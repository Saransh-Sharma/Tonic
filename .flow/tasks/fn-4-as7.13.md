# fn-4-as7.13 Redesign Settings with PreferenceList pattern

## Description
TBD

## Acceptance
# Redesign Settings with PreferenceList pattern

Update PreferencesView to use the PreferenceList component consistently.

## Layout Requirements
- Use PreferenceList for all sections
- Sections: General, Appearance, Permissions, Helper, Updates, About
- No cards
- No accent color except focused controls

## Changes Required
- Replace Card components with PreferenceList
- Consolidate all settings in one view
- Ensure consistent padding and spacing
- Remove accent color from non-interactive elements

## Acceptance
- [ ] All settings use PreferenceList
- [ ] No Card components in settings
- [ ] Five sections with proper headers
- [ ] Consistent spacing throughout
- [ ] Accent color only on focused controls
- [ ] Light/dark mode both work

## References
- File: Tonic/Tonic/Views/PreferencesView.swift
- Spec: Section "Screen-by-Screen → Settings" in epic

## Deps: fn-4-as7.3, fn-4-as7.6


## Done summary
TBD

## Evidence
- Commits:
- Tests:
- PRs:
