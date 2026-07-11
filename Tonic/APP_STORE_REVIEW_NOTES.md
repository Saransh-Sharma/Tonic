# Tonic Store Edition App Review Notes

## Store safety summary
- Store target: `TonicStore`.
- App Sandbox enabled with user-selected read/write and downloads access.
- No privileged helper, no root escalation flows, and no Sparkle updater path in Store target.
- Updates are App Store-managed in Store build.

## Access model
- Tonic Store Edition uses user-granted scopes (security-scoped bookmarks).
- Users can grant access by choosing folders/disks in onboarding or in Settings > Access.
- Access is persisted and revalidated; stale or disconnected scopes are surfaced and re-authorizable.

## Demo script for review
1. Launch `TonicStore`.
2. Select **Reclaim storage** or **Manage apps**, then try the permission-free preview.
3. On **Enable selected capabilities**, choose a folder or volume. Skipping is supported.
4. Open Home and verify that the live status narrative does not claim access outside the chosen scope.
5. Open Care > Storage and run a scoped scan.
6. Open Care > Smart Care and verify `Needs access`/limited messaging where applicable.
7. Open Settings > Access to add, inspect, or remove an authorized location.
8. Execute a cleanup preview and show the recoverable action receipt where supported.

## Reviewer tips
- If a scope becomes stale/disconnected, use Settings > Access to repair or replace it.
- Store edition intentionally scopes cleanup to authorized locations.
