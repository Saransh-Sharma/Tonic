#!/bin/bash
set -euo pipefail

APP="${1:?usage: audit-store-exclusions.sh /path/to/TonicStore.app}"
BINARY="$APP/Contents/MacOS/TonicStore"
[[ -f "$BINARY" ]] || BINARY="$APP/Contents/MacOS/Tonic"
[[ -f "$BINARY" ]] || { echo "Store executable not found" >&2; exit 2; }

for forbidden in Sparkle.framework com.saransh.tonic.helper Library/LaunchDaemons; do
  if find "$APP" -path "*$forbidden*" -print -quit | grep -q .; then
    echo "Forbidden Store payload: $forbidden" >&2
    exit 1
  fi
done

if nm -gj "$BINARY" 2>/dev/null | grep -E 'CGSGetActiveSpace|CGSMainConnectionID|MRMediaRemote|ForeignMenuProxy|PrivateSpace|TonicHelperClient|TonicExecutableProvider|ScriptExecutionActor|SPUStandardUpdaterController' >/dev/null; then
  echo "Forbidden direct-only symbol found in Store executable" >&2
  exit 1
fi

echo "Store exclusion audit passed"
