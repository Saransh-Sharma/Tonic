# fn-4-as7.10 Redesign App Manager with table layout

## Description
# Improve App Manager grid design

Improve AppInventoryView grid design (keep 4-column grid, NOT changing to table).

## Layout Requirements
- Keep 4-column grid layout
- Add search bar at top
- Add multi-select (Cmd+click) for batch actions
- Improve metadata design (name, size, last used)
- Category sidebar for filtering

## Changes Required
- Add search bar
- Implement Cmd+click multi-select
- Improve metadata card design
- Add category filter sidebar

## Acceptance
- [ ] 4-column grid preserved
- [ ] Search bar filters by name
- [ ] Cmd+click multi-select works
- [ ] Batch Uninstall button on selection
- [ ] Metadata design improved
- [ ] Category filter sidebar works
- [ ] Light/dark mode both work

## References
- File: Tonic/Tonic/Views/AppInventoryView.swift
- Spec: Section "Screen-by-Screen → Apps" in epic

## Deps: fn-4-as7.1, fn-4-as7.6
## Acceptance
# Redesign App Manager with table layout

Redesign AppInventoryView to use a table with category sidebar.

## Layout Requirements
- Left: Category sidebar (Apps, Extensions, etc.)
- Main: Table with columns (App, Size, Last Used, Version, Actions)
- Multi-select for batch uninstall
- Protected apps show lock icon

## Changes Required
- Replace icon grid with Table
- Add category sidebar (or segmented control)
- Add multi-select support
- Add batch Uninstall button
- Show lock icon for protected apps

## Acceptance
- [ ] Table view replaces grid
- [ ] Five columns: App, Size, Last Used, Version, Actions
- [ ] Multi-select works (Shift/Cmd)
- [ ] Batch Uninstall enabled on selection
- [ ] Protected apps disabled with lock icon
- [ ] Light/dark mode both work

## References
- File: Tonic/Tonic/Views/AppInventoryView.swift
- Spec: Section "Screen-by-Screen → Apps" in epic

## Deps: fn-4-as7.5, fn-4-as7.6


## Done summary
Redesigned App Manager to use ActionTable component for a native macOS table experience with multi-select support, batch actions, category sidebar filtering, and improved metadata display.
## Evidence
- Commits: bed332593bcfc464047482c46f7ed839eced7a2f
- Tests: xcodebuild -scheme Tonic -configuration Debug build
- PRs: