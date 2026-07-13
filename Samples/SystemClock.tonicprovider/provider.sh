#!/bin/bash
set -euo pipefail
IFS= read -r request
[[ ${#request} -le 65536 ]] || exit 2
now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
label=$(date +"%H:%M")
printf '{"schemaVersion":1,"label":"%s","symbolName":"clock","accessibilityText":"Local time %s","generatedAt":"%s","status":"neutral"}\n' "$label" "$label" "$now"
