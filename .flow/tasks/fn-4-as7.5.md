# fn-4-as7.5 Create ActionTable component for multi-select lists

## Description
TBD

## Acceptance
# Create ActionTable component for multi-select lists

Create a table component supporting multi-select, batch actions, and keyboard navigation.

## Specs
- Multi-select with Shift/Cmd modifiers
- Batch action buttons
- Keyboard navigation (arrow keys)
- Context menu support

## Acceptance
- [ ] Multi-select works (Shift/Cmd)
- [ ] Batch actions operate on selection
- [ ] Arrow key navigation works
- [ ] Context menu appears on right-click

## Deps: fn-4-as7.1


## Done summary
Created ActionTable component with multi-select support (Shift/Cmd modifiers), batch action bar, keyboard navigation (arrow keys, Space, Enter), and context menu support for right-click.
## Evidence
- Commits: 2fc206c0a25a8271dd1c5b3c78a2daedb79288a5
- Tests: xcodebuild -scheme Tonic -configuration Debug build
- PRs: