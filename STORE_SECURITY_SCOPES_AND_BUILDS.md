# Tonic Store Security, Scopes, Scoped Bookmarks, and Build Matrix

This document describes how Tonic handles sandbox-safe file access in Store builds, how scoped bookmarks are persisted and refreshed, and how to build and test both direct and Store targets.

## 1. Why this exists

Tonic ships in two distribution flavors:

- `Tonic` (direct distribution)
- `TonicStore` (Mac App Store-safe)

The Store target cannot rely on broad machine access assumptions and instead uses a scope-first model:

- user-selected locations
- security-scoped bookmark persistence
- explicit per-operation access lifetime management

The direct target keeps legacy behavior where applicable, including Sparkle update support.

## 2. Target matrix

| Area | `Tonic` (Direct) | `TonicStore` (Store) |
|---|---|---|
| Compile condition | default | `TONIC_STORE` |
| Build flavor | `.direct` | `.store` |
| Requires scope model | No | Yes |
| Sparkle support | Yes | No |
| Update channel | Sparkle/in-app | App Store-managed |
| Scope/bookmark UX | Optional/no-op semantics | Required for full feature coverage |

Reference implementation: `Tonic/Tonic/Utilities/BuildFlavor.swift`.

## 3. Store security model

### 3.1 Entitlements

Store entitlements include:

- `com.apple.security.app-sandbox`
- `com.apple.security.files.user-selected.read-write`

Reference file: `Tonic/Tonic/TonicStore.entitlements`.

### 3.2 Scope domain model

Core types:

- `AccessScopeKind`
- `AccessScopeStatus`
- `ScopeAccessState`
- `ScopeBlockedReason`
- `AccessScope`
- `ScopeAccessEvaluation`
- `ScopeCoverageSummary`
- `ScopeCoverageTier`

Reference file: `Tonic/Tonic/Models/AccessScopeModels.swift`.

### 3.3 Blocked reason taxonomy

The codebase uses typed reasons end-to-end instead of stringly-typed failures:

- `missingScope`
- `staleBookmark`
- `disconnectedScope`
- `sandboxReadDenied`
- `sandboxWriteDenied`
- `macOSProtected`

Each reason has a user-facing remediation message (`ScopeBlockedReason.userMessage`).

## 4. Scoped bookmark lifecycle

`AccessBroker` owns bookmark lifecycle and persistence.

Reference file: `Tonic/Tonic/Services/AccessBroker.swift`.

### 4.1 Add scope

Scopes can be granted from:

- `NSOpenPanel` (`addScopeUsingOpenPanel`)
- startup disk flow (`addStartupDiskScope`)
- drag/drop URL handling (onboarding/dashboard)

Flow:

1. canonicalize path
2. deduplicate existing scope roots
3. create bookmark with `.withSecurityScope`
4. persist scope
5. refresh status

### 4.2 Persist scope

Bookmarks are persisted to app container application support:

- filename: `access_scopes_v1.json`
- directory: `Application Support/Tonic/`

### 4.3 Resolve and revalidate

On load and refresh:

1. resolve bookmark data
2. detect stale bookmark
3. attempt `startAccessingSecurityScopedResource()`
4. check underlying path existence
5. classify status: `active`, `staleBookmark`, `disconnected`, `invalid`

### 4.4 Access wrappers

Access entry points:

- `withAccess(scopeID:)`
- `withAccess(scope:)`
- `withAccess(forPath:)`

`withAccess(forPath:)` behavior:

1. canonicalize path
2. resolve best matching scope
3. enforce scope status
4. open/close security scope around operation

### 4.5 Coverage tier

Coverage tier is derived from active canonical roots:

- `Minimal`
- `Standard` (typically Home + Applications)
- `Full Mac` (startup disk root coverage)

## 5. Scope resolution and path matching

`ScopeResolver` performs:

- canonicalization (tilde expansion, standardization, symlink resolution)
- best ancestor-match scope selection
- protected-path detection for macOS-restricted areas

Reference file: `Tonic/Tonic/Services/ScopeResolver.swift`.

## 6. Scoped file system facade

`ScopedFileSystem` is the single access boundary for feature code.

Reference file: `Tonic/Tonic/Services/ScopedFileSystem.swift`.

It provides:

- scope state evaluation (`accessState(...)`)
- coverage filtering (`filterAuthorizedPaths(...)`)
- scoped read/write wrappers (`withReadAccess`, `withWriteAccess`)
- scoped filesystem operations (read/enumerate/attributes/trash/remove)
- error-to-blocked-reason mapping

Recent hardening includes scoped metadata access APIs:

- `resourceValues(for:keys:)`
- `resourceValues(atPath:keys:)`

Use these for all `URLResourceValues` reads in scan/cleanup pipelines.

## 7. Feature behavior in Store mode

Store mode should never assume global disk visibility.

### 7.1 Scan surfaces

Scan engines run against covered paths and produce blocked subsets with typed reasons.

Areas impacted:

- Smart Scan / SmartCare
- Deep Clean
- Storage Intelligence Hub
- App inventory and uninstall

### 7.2 UI behavior

Expected user-visible states include:

- `Ready`
- `Needs access`
- `Limited by macOS`

CTAs:

- `Grant Access`
- startup-disk scope authorization for full scan
- drag/drop scope grant in onboarding and dashboard

### 7.3 Mutation behavior

Mutation operations should route via scoped wrappers:

- move to trash
- delete
- secure delete
- uninstall app artifacts

When blocked, surface `ScopeBlockedReason`-mapped messages.

## 8. Developer implementation rules

1. No raw file I/O in Store paths after only `canRead/canWrite` checks.
2. Wrap direct metadata reads in `ScopedFileSystem.resourceValues(...)`.
3. Use `ScopedFileSystem` for enumerate/remove/trash/attributes operations.
4. Keep blocked reason propagation typed through service and UI layers.
5. Ensure direct target behavior remains unchanged unless refactor is no-op.

## 9. Build commands (root workspace)

All commands below assume repo root (`/Users/saransh1337/Developer/Projects/TONIC`).

### 9.1 Regenerate project

```bash
xcodegen generate --spec Tonic/project.yml
```

### 9.2 Build direct target

```bash
xcodebuild \
  -project Tonic/Tonic.xcodeproj \
  -scheme Tonic \
  -configuration Debug \
  -destination 'platform=macOS' \
  build CODE_SIGNING_ALLOWED=NO
```

### 9.3 Build Store target

```bash
xcodebuild \
  -project Tonic/Tonic.xcodeproj \
  -scheme TonicStore \
  -configuration Debug \
  -destination 'platform=macOS' \
  build CODE_SIGNING_ALLOWED=NO
```

### 9.4 Release builds

```bash
xcodebuild -project Tonic/Tonic.xcodeproj -scheme Tonic -configuration Release -destination 'platform=macOS' build
xcodebuild -project Tonic/Tonic.xcodeproj -scheme TonicStore -configuration Release -destination 'platform=macOS' build
```

## 10. Test commands

### 10.1 Run full test bundle

```bash
xcodebuild \
  -project Tonic/Tonic.xcodeproj \
  -scheme Tonic \
  -configuration Debug \
  -destination 'platform=macOS' \
  test CODE_SIGNING_ALLOWED=NO
```

### 10.2 Run migration-critical scope/security tests

```bash
xcodebuild \
  -project Tonic/Tonic.xcodeproj \
  -scheme Tonic \
  -configuration Debug \
  -destination 'platform=macOS' \
  test CODE_SIGNING_ALLOWED=NO \
  -only-testing:TonicTests/AccessScopeModelsTests \
  -only-testing:TonicTests/ScopeResolverTests \
  -only-testing:TonicTests/ServiceErrorHandlingTests
```

### 10.3 Validate target matrix for CI

```bash
xcodebuild -project Tonic/Tonic.xcodeproj -scheme Tonic -configuration Debug -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO
xcodebuild -project Tonic/Tonic.xcodeproj -scheme TonicStore -configuration Debug -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO
```

## 11. Troubleshooting

### 11.1 Scope shows stale

- Open Settings -> Permissions
- re-authorize affected scope
- ensure bookmark refresh transitions to `active`

### 11.2 Scope shows disconnected

- reconnect external volume
- or remove and re-add scope

### 11.3 Scan result is partial

- inspect blocked reasons in UI
- add missing scopes (Home/Applications/startup disk)
- verify coverage tier progresses from `Minimal` -> `Standard`/`Full Mac`

### 11.4 Operation fails in Store but not direct

Likely causes:

- operation bypassed scoped wrapper
- path metadata read outside security-scope lifetime
- protected macOS path (`macOSProtected`)

Audit with:

- scoped facade usage (`ScopedFileSystem`)
- blocked reason propagation
- direct `FileManager` or `URL.resourceValues` usage in feature code

## 12. App Review and release references

- App Store review script: `Tonic/APP_STORE_REVIEW_NOTES.md`
- Build matrix config: `Tonic/project.yml`
- Store plist: `Tonic/Tonic/Info-Store.plist`
- Store entitlements: `Tonic/Tonic/TonicStore.entitlements`

