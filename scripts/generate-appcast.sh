#!/bin/bash
set -euo pipefail

ARTIFACTS="${1:?artifact directory required}"
: "${SPARKLE_EDDSA_PRIVATE_KEY:?Sparkle signing key required}"
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TOOL=$(find "$ROOT/Tonic" -type f -path '*Sparkle*/bin/generate_appcast' -perm +111 -print -quit)
[[ -n "$TOOL" ]] || { echo "Sparkle generate_appcast tool not found" >&2; exit 1; }
printf '%s' "$SPARKLE_EDDSA_PRIVATE_KEY" > "$RUNNER_TEMP/sparkle-private-key"
"$TOOL" --ed-key-file "$RUNNER_TEMP/sparkle-private-key" \
  --download-url-prefix "https://github.com/Saransh-Sharma/TONIC/releases/download/" \
  --phased-rollout-interval 86400 "$ARTIFACTS"
[[ -f "$ARTIFACTS/appcast.xml" ]] || { echo "Appcast was not generated" >&2; exit 1; }
