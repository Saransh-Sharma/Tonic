# Tonic provider catalog

`catalog-unsigned.json` is the reviewed source envelope. The production workflow
canonicalizes and signs its `body` with the protected Ed25519 key, writes only
the signed result to the Pages artifact, and never exposes the private key to a
pull-request job. The first-party `remote.tonic-release` entry is the end-to-end
remote-provider reference implementation. Its immutable descriptor is published
by the protected provider-release workflow; its bounded display-only snapshot
ships on Pages beside the signed catalog.

Provider release URLs must be immutable GitHub Release assets. Executable
providers also require an expected Developer ID team, notarization, a SHA-256
digest, and an explicit permission set. Store clients see only remote JSON
entries whose supported schema overlaps the host range.

The production repository must have GitHub release immutability enabled. The
provider-release job checks that setting with a protected administration-read
token, uploads assets to a draft, and publishes only after every asset is
attached; publication then makes the tag and assets immutable and generates
GitHub's release attestation.
