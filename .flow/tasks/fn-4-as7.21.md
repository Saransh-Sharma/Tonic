# fn-4-as7.21 Create Design Sandbox screen

## Description
TBD

## Acceptance
# Create Design Sandbox screen

Create a screen to view all design components.

## Specs
- Accessible via Settings or Developer Tools
- Shows all components: Card variants, MetricRow, PreferenceList, etc.
- Interactive previews
- Shows component states

## Acceptance
- [ ] Design Sandbox screen exists
- [ ] All Card variants shown
- [ ] MetricRow shown with sample data
- [ ] PreferenceList examples shown
- [ ] Interactive and usable

## Deps: fn-4-as7.2,fn-4-as7.3,fn-4-as7.18


## Done summary
Created a comprehensive Design Sandbox screen accessible from Developer Tools that showcases all design system components in an interactive, tabbed interface. The sandbox displays Card variants (elevated, flat, inset), MetricRow components with sparklines, PreferenceList examples with grouped sections, buttons, status indicators, and miscellaneous UI components with sample data.
## Evidence
- Commits: 3b8b4de8f7d185d7b0d08363953778f514fa83ad
- Tests: xcodebuild -scheme Tonic -configuration Debug build
- PRs: