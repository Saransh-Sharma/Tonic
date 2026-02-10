# Tonic Store Edition App Review Notes

## Store safety summary
- Store target: `TonicStore`.
- App Sandbox enabled with user-selected read/write and downloads access.
- No privileged helper, no root escalation flows, and no Sparkle updater path in Store target.
- Updates are App Store-managed in Store build.

## Access model
- Tonic Store Edition uses user-granted scopes (security-scoped bookmarks).
- Users can grant access by choosing folders/disks in onboarding or in Settings > Permissions.
- Access is persisted and revalidated; stale or disconnected scopes are surfaced and re-authorizable.

## Demo script for review
1. Launch `TonicStore`.
2. In onboarding step 6, click **Add Scope** and authorize Home and Applications.
3. Click **Enable Full Mac Scan** and select startup disk (e.g. Macintosh HD).
4. Open Dashboard and verify coverage indicator updates.
5. Run Storage Intelligence Hub scan.
6. Run Smart Scan and verify scoped recommendations plus `Needs access`/limited messaging where applicable.
7. Open Deep Clean and verify category states: Ready / Needs access / Limited by macOS.
8. Execute cleanup preview and show Collector Bin restore flow.

## Reviewer tips
- If a scope becomes stale/disconnected, use Settings > Permissions > Re-authorize.
- Store edition intentionally scopes cleanup to authorized locations.
