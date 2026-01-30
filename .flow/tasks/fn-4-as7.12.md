# fn-4-as7.12 Redesign Menu Bar Widgets with native list

## Description
TBD

## Acceptance
# Redesign Menu Bar Widgets with native list

Redesign WidgetCustomizationView to use a native list with drag-reorder.

## Layout Requirements
- List of widgets with toggle
- Drag-to-reorder support
- Inline preview
- No decorative imagery

## Changes Required
- Replace custom dark theme with native background
- Use List with drag modifiers
- Add inline widget preview
- Remove decorative elements

## Acceptance
- [ ] Native list (not custom background)
- [ ] Toggle enables/disables widget
- [ ] Drag-reorder works
- [ ] Inline preview shows current widget state
- [ ] No decorative imagery
- [ ] Light/dark mode both work

## References
- File: Tonic/Tonic/Views/WidgetCustomizationView.swift
- Spec: Section "Screen-by-Screen → Menu Bar Widgets" in epic

## Deps: fn-4-as7.3, fn-4-as7.6


## Done summary
Redesigned WidgetCustomizationView from custom dark-themed grid layout to native List-based interface using DesignTokens and PreferenceList pattern. The view now uses system semantic colors, native controls, and maintains all functionality (toggle, drag-reorder, inline preview, settings).
## Evidence
- Commits: 872c7b90ae7e6f726a6aae84adde68f04871624c
- Tests:
- PRs: