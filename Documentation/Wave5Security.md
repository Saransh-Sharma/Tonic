# Wave 5 security and edition boundaries

## Signed artifacts

Compatibility rules and the marketplace catalog use canonical JSON envelopes
and Ed25519 signatures. Revision rollback, invalid/expired signatures, malformed
keys, unsupported schemas, and stale compatibility rules fail closed. The cache
stores ETags and the last valid unexpired envelope; checks upload no device,
feature-use, OS, or compatibility telemetry.

## Recovery helper threat model

Every privileged case is a closed enum. The caller cannot provide a filesystem
path, executable, daemon label, environment, or shell command. Volume, service,
cleanup-domain, fan, age, and RPM values are typed and clamped. The helper maps
them to fixed tools and roots, validates reciprocal team and identifiers, caps
request and output sizes, times out operations, stops plans at first failure,
and restores fan Auto after interruption or a missed heartbeat.

System cleanup follows standardized fixed roots, skips symlinks, requires root
ownership, enforces age cutoffs, and caps removals. Document revisions use a
separate fixed root and stale-age policy. The Recovery UI diagnoses first,
reviews the complete plan, confirms each disruptive step, emits step and
aggregate receipts, and re-diagnoses after success.

## Capture and private adapters

Automatic Space binding and foreign-menu proxying compile only into the direct
edition. Each use requires a valid exact-build compatibility rule and runtime
preflight. Space persistence contains only a salted opaque digest, display
association, context name/ID, and validation metadata. Foreign menu content and
pixels remain in memory for one bounded session; secure or ambiguous elements
fall back to the original menu.

## Provider containment

Catalog signatures, artifact SHA-256, expected Developer ID team, notarization,
schema overlap, permissions, endpoints, refresh policy, and Store kind are
validated before activation. Store sources physically exclude executable
providers, script runtime, helper, Sparkle, and private adapters.

## Support diagnostics

Support bundles are local until a user previews categories and chooses a save
location. Deterministic redaction excludes user paths, credentials, email-like
values, URL secrets, clipboard/calendar/note content, file names, scripts and
output, captures, foreign menu text, and raw Space identifiers. Tonic never
uploads a bundle or creates a persistent support identity.
