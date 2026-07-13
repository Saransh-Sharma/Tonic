#!/bin/bash
set -euo pipefail

: "${SPARKLE_PUBLIC_ED_KEY:?SPARKLE_PUBLIC_ED_KEY is required}"
: "${TONIC_ARTIFACT_PUBLIC_KEY:?TONIC_ARTIFACT_PUBLIC_KEY is required}"

[[ "$SPARKLE_PUBLIC_ED_KEY" != *'$('* ]] || { echo "Unexpanded Sparkle key" >&2; exit 1; }
[[ "$TONIC_ARTIFACT_PUBLIC_KEY" != *'$('* ]] || { echo "Unexpanded artifact key" >&2; exit 1; }

artifact_bytes=$(printf '%s' "$TONIC_ARTIFACT_PUBLIC_KEY" | base64 --decode 2>/dev/null | wc -c | tr -d ' ')
[[ "$artifact_bytes" == "32" ]] || { echo "Artifact Ed25519 public key must decode to 32 bytes" >&2; exit 1; }

echo "Release trust configuration is present"
