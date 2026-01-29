# fn-4-as7.4 Create OutlineView component for disk browser

## Description
TBD

## Acceptance
# Create OutlineView component for disk browser

Create an outline view component for directory browsing with disclosure triangles and sortable columns.

## Specs
- Disclosure triangles for expand/collapse
- Columns: Name | Size | % of parent
- Lazy-loaded children
- Sortable by size

## Acceptance
- [ ] Disclosure triangles work
- [ ] Three columns render correctly
- [ ] Children load on-demand
- [ ] Sort by size works

## Deps: fn-4-as7.1


## Done summary
Created OutlineView component for hierarchical directory browsing with disclosure triangles, three sortable columns (Name, Size, % of parent), lazy-loaded children, and full accessibility support.
## Evidence
- Commits: 9fedeeb4edba359e014127f806024cd3fc58291d
- Tests: xcodebuild -scheme Tonic -configuration Debug build
- PRs: