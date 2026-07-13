# Tonic Provider SDK v1–v2

Tonic providers return display-only snapshots. They cannot submit actions,
helper requests, scripts, entitlements, or arbitrary UI. The host and provider
must negotiate an overlapping `TonicProviderSchemaRange` before launch or any
provider endpoint request.

## Manifest

A provider manifest contains a stable reverse-DNS identifier, display name,
provider version, supported schema range, minimum refresh interval (never below
15 seconds), and declared display capabilities. Providers may return a bounded
label, SF Symbol or reviewed image reference, accessibility text, freshness,
and semantic status.

Version 1 manifests that contain only `schemaVersion` decode as the equivalent
single-version range. A v2 host therefore preserves v1 behavior without an
exact-version launch requirement.

## Remote JSON providers

Both editions support reviewed HTTPS providers. The review shows the exact URL,
refresh interval, private-network policy, response bound, and requested
permissions. Redirects, response bytes, JSON nesting, and node counts are
bounded. Private and reserved addresses are blocked by default. Secrets live in
the data-protection Keychain and provider JSON stores only a reference.

## Executable providers

Only the direct edition loads `.tonicprovider` bundles. Production bundles must
be Developer ID signed, notarized when installed through the marketplace, and
match the catalog’s expected team. The process runs as the current user with a
minimal environment, one bounded line-delimited Codable request and response,
a timeout, overlap prevention, and pause-after-three-failures policy. It never
runs through `TonicHelper`.

Advanced developer mode may approve an unsigned local provider by immutable
executable SHA-256. Editing the executable invalidates that approval.

## Marketplace policy

The signed catalog and revocation list live on GitHub Pages; immutable provider
artifacts live in GitHub Releases. Updates install automatically only when
publisher identity, permissions, capabilities, endpoints, refresh behavior,
and data access remain within the user’s existing approval. Expansion always
requires review. Revocation pauses a release immediately and retains a local
diagnostic and rollback reference.

See `Samples/SystemClock.tonicprovider` for the smallest direct provider.
