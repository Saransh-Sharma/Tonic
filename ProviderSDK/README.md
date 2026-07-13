# Tonic Custom Data-Source SDK

Tonic providers return display-only snapshots for custom menu-bar items. Providers cannot execute actions or invoke the privileged helper.

## Protocol

- Schema version: `1`.
- Transport: one JSON request line on standard input and one JSON snapshot line on standard output.
- Dates use ISO 8601.
- Production `.tonicprovider` executables require a valid Developer ID Application signature.
- Advanced developer mode may approve an unsigned executable by its immutable SHA-256 code hash. Editing the executable invalidates that approval.
- Tonic enforces a launch/response timeout, 256 KiB response limit, one active request, a refresh floor, and a pause after three failures.
- Provider identifiers are 1–128 characters from `A-Z`, `a-z`, `0-9`, `.`, `_`, and `-`; built-in `tonic.*` and reviewed `remote.*` namespaces cannot be replaced by executable bundles.

Bundle layout:

```text
Example.tonicprovider/
├── provider.json
└── provider
```

`provider.json` contains a `TonicExecutableProviderBundleManifest`:

```json
{
  "provider": {
    "id": "com.example.clock",
    "schemaVersion": 1,
    "displayName": "Example Clock",
    "providerVersion": "1.0.0",
    "minimumRefreshSeconds": 60,
    "capabilities": ["label", "accessibilityText", "freshness"]
  },
  "executableRelativePath": "provider"
}
```

The request follows `TonicDataSourceRequest`. The response follows `TonicDataSourceSnapshot`:

```json
{"schemaVersion":1,"requestID":"REQUEST-UUID","label":"09:41","accessibilityText":"The time is 9:41 AM","generatedAt":"2026-07-12T04:11:00Z","expiresAt":"2026-07-12T04:12:00Z","status":"neutral"}
```

Snapshots may contain a sanitized label, SF Symbol name, HTTPS image reference, accessibility text, freshness dates, and semantic status. Unknown fields should be ignored by providers for forward compatibility.

## Remote JSON providers

Both Tonic editions support reviewed `remote.*` providers. Endpoints must use HTTPS. Tonic limits redirects, response bytes, JSON depth, and resolved private/reserved addresses; private-network access is disabled unless the user explicitly enables it. Secrets are stored in the data-protection Keychain and configuration stores only a secret identifier. The shared registry caches snapshots until the reviewed provider refresh floor elapses.

See `Samples/ClockProvider.tonicprovider` for a minimal implementation.
