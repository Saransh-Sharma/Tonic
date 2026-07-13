# Tonic Roadmap

Wave 4 deliberately leaves the following work outside the flagship-parity release boundary.

## Commerce and distribution

- Replace the current licensing surface with production StoreKit purchase, entitlement, restore, refund, and family-sharing flows.
- Finish the Sparkle direct-install tier, signed delta updates, phased rollout, and rollback policy.
- Localize product UI, permission explanations, onboarding, receipts, helper errors, and release metadata.

## Menu Bar platform depth

- Add a signed provider marketplace, schema negotiation beyond v1, and richer provider diagnostics after the shipped local/remote SDK has field usage.
- Consider automatic Space-specific contexts only if Apple publishes a stable supported Space identity API. Tonic currently ships per-display presentation profiles and manual named contexts without private CGS identifiers.
- Revisit foreign-item menu proxying if Apple provides a capture/activation API compatible with privacy and sandbox policy.
- Expand Top Shelf discovery, recommendations, and contextual group experiences.

## Privileged maintenance

- Add privileged operations only after each receives a fixed-path threat model, signed protocol case, review UI, receipt schema, recovery path, and Store report-only equivalent.
- Complete release-signing QA for helper upgrade/downgrade, stale registration, wrong-client rejection, and uninstall recovery.

## Capture spike outcome

The offscreen foreign-item image-capture spike is not a reliable universal foundation. Status-item windows that macOS moves offscreen may return no usable pixels, stale content, or a width-only representation depending on owner and OS build. Wave 4 therefore treats imagery as optional and ephemeral and falls back in order to the owning app icon, a known SF Symbol, then a labeled placeholder. Saved layout identity never depends on captured pixels; width-only evidence may inform overflow spacing but is not presented as a faithful preview.
