# fn-4-as7.6 Refactor SidebarView with grouped navigation

## Description
TBD

## Acceptance
# Refactor SidebarView with grouped navigation

Update SidebarView to use grouped sections for better information architecture.

## New Structure
- Dashboard
- Maintenance (Smart Scan, Clean Up)
- Explore (Disk, Apps, Activity)
- Menu Bar (Widgets)
- Advanced (Developer, Permissions)
- Settings

## Changes Required
- Add section headers to sidebar
- Update NavigationDestination enum if needed
- Update ContentView navigation logic

## Acceptance
- [ ] Sidebar shows grouped sections
- [ ] Section headers are non-selectable
- [ ] Navigation works for all items
- [ ] Active item highlighted

## References
- File: Tonic/Tonic/Views/SidebarView.swift
- File: Tonic/Tonic/Views/ContentView.swift

## Deps: fn-4-as7.1


## Done summary
TBD

## Evidence
- Commits:
- Tests:
- PRs:
