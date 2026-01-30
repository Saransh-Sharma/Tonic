# fn-4-as7.9 Redesign Disk Analysis with OutlineView

## Description
# Redesign Disk Analysis with hybrid view

Redesign DiskAnalysisView with a segmented control for List/Treemap/Hybrid views.

## Layout Requirements
- Segmented control: [List | Treemap | Hybrid]
- List View: Bar chart rows (Name | size bar | %)
- Treemap: Rectangle sizing by file/folder size
- Hybrid: Bar chart + treemap combination
- Default: Large Files table
- Reveal in Finder always available
- No Pro gating - all views available to all users

## Changes Required
- Add segmented control for view switching
- List = horizontal bar chart rows
- Treemap = proportional rectangles
- Show 3-4 levels deep, drill down for more
- Snappy animations

## Acceptance
- [ ] Segmented control switches views
- [ ] List view shows bar chart rows
- [ ] Treemap view shows proportional rectangles
- [ ] Hybrid view combines both
- [ ] Drill down works for deeper levels
- [ ] Reveal in Finder available on all items
- [ ] Light/dark mode both work
- [ ] No Pro gating - all views available

## References
- File: Tonic/Tonic/Views/DiskAnalysisView.swift
- Spec: Section "Screen-by-Screen → Disk" in epic

## Deps: fn-4-as7.1, fn-4-as7.6
## Acceptance
# Redesign Disk Analysis with OutlineView

Redesign DiskAnalysisView to use native table/outline views with default Large Files table.

## Layout Requirements
- Default: Large Files table (ActionTable)
- Secondary: Directory Browser (OutlineView)
- Tertiary: Treemap (Pro only, never default)
- Reveal in Finder always available

## Changes Required
- Replace current file browser with OutlineView component
- Add segmented control for view switching
- Default to Large Files table
- Keep Treemap as Pro feature

## Acceptance
- [ ] Large Files is default view
- [ ] Directory Browser uses OutlineView
- [ ] View switcher works (table/outline/treemap)
- [ ] Reveal in Finder available on all items
- [ ] Sorting by size works
- [ ] Light/dark mode both work

## References
- File: Tonic/Tonic/Views/DiskAnalysisView.swift
- Spec: Section "Screen-by-Screen → Disk" in epic

## Deps: fn-4-as7.4, fn-4-as7.5, fn-4-as7.6


## Done summary
Redesigned DiskAnalysisView with segmented control for List/Treemap/Hybrid views. List view shows horizontal bar chart rows, Treemap uses squarified algorithm for proportional rectangles, and Hybrid combines both side-by-side. Added Reveal in Finder on all items and updated to DesignTokens styling throughout.
## Evidence
- Commits: 9a00229cca1d2df3efa5bdccd299200500a38887
- Tests: xcodebuild -scheme Tonic -configuration Debug build
- PRs: