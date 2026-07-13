#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CATALOG="$ROOT/Tonic/Tonic/Localizable.xcstrings"
LOCALES=(es de fr ja zh-Hans)
KEYS=(
  "Recovery Center" "Top Shelf" "Curated catalog" "Support"
  "Automatic Space context" "Per-app window rules" "System Health"
  "Now Playing" "Clipboard" "Next Event" "Quick Notes" "Timers"
  "Files" "Shortcuts" "Provider Cards" "Refresh DNS resolution"
  "Reclaim local Time Machine snapshots" "App and OS" "Provider health"
)

count="$(jq '.strings | length' "$CATALOG")"
if (( count < 500 )); then
  echo "Localization extraction is incomplete: $count catalog keys (expected at least 500)." >&2
  exit 1
fi

for key in "${KEYS[@]}"; do
  for locale in "${LOCALES[@]}"; do
    value="$(jq -r --arg key "$key" --arg locale "$locale" '.strings[$key].localizations[$locale].stringUnit.value // empty' "$CATALOG")"
    if [[ -z "$value" ]]; then
      echo "Missing $locale translation for: $key" >&2
      exit 1
    fi
  done
done

echo "Localization audit passed: $count extracted keys and ${#KEYS[@]} Wave 5 release keys in five translated locales."
