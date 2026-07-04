#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HANDOFF_DIR="$ROOT/designer-handoff-2026-06-30"
SCREENSHOT_DIR="$HANDOFF_DIR/screenshots"
BUILD_DIR="$HANDOFF_DIR/.build"
RENDERER="$HANDOFF_DIR/HandoffRenderer.swift"

mkdir -p "$SCREENSHOT_DIR" "$BUILD_DIR"
rm -f "$SCREENSHOT_DIR/manifest.tsv" "$SCREENSHOT_DIR/INDEX.md"

SOURCE_LIST="$BUILD_DIR/app-sources.txt"
find "$ROOT/Tonic/Tonic" -name '*.swift' ! -name 'TonicApp.swift' | sort > "$SOURCE_LIST"

COMMON_FLAGS=(
  -parse-as-library
  -swift-version 5
  -DDEBUG
  -enable-bare-slash-regex
  -enable-experimental-feature DebugDescriptionMacro
)

echo "Compiling Direct handoff renderer"
xcrun swiftc "${COMMON_FLAGS[@]}" "@$SOURCE_LIST" "$RENDERER" -o "$BUILD_DIR/handoff-renderer-direct"

echo "Rendering Direct screenshots"
"$BUILD_DIR/handoff-renderer-direct" "$SCREENSHOT_DIR" direct

echo "Compiling Store handoff renderer"
xcrun swiftc "${COMMON_FLAGS[@]}" -DTONIC_STORE "@$SOURCE_LIST" "$RENDERER" -o "$BUILD_DIR/handoff-renderer-store"

echo "Rendering Store screenshots"
"$BUILD_DIR/handoff-renderer-store" "$SCREENSHOT_DIR" store

png_count="$(find "$SCREENSHOT_DIR" -type f -name '*.png' | wc -l | tr -d ' ')"

{
  printf '# Tonic Screenshot Index\n\n'
  printf 'Generated: 2026-06-30\n\n'
  printf 'Capture policy: hybrid. Most screenshots are deterministic SwiftUI-rendered captures; native-window rows are CGWindow captures of titled NSWindow hosts for macOS shell/window fidelity.\n\n'
  printf 'Data policy: sanitized fixtures for populated app, scan, and dashboard states. Live hardware/menu-bar metrics may vary where noted.\n\n'
  printf 'Total PNGs: %s\n\n' "$png_count"
  printf '| Screenshot ID | Build | Label | Dimensions | Method | Notes |\n'
  printf '|---|---|---|---:|---|---|\n'
  tail -n +2 "$SCREENSHOT_DIR/manifest.tsv" | sort | while IFS=$'\t' read -r path build label dimensions method notes; do
    printf '| `%s` | %s | %s | %s | %s | %s |\n' "$path" "$build" "$label" "$dimensions" "$method" "$notes"
  done
  printf '\n## Verification Notes\n\n'
  printf -- '- Direct and Store variants are included for all renderer-covered surfaces.\n'
  printf -- '- Store screenshots use the `TONIC_STORE` compile path, including authorized-location access wording and Mac App Store update copy.\n'
  printf -- '- Direct screenshots use Full Disk Access wording and Sparkle update copy.\n'
  printf -- '- Populated app inventory, scan results, dashboard recommendations, and widget configuration use sanitized fixture names and paths.\n'
  printf -- '- Menu-bar popovers use current live metric providers where the views require them; values can differ between runs.\n'
} > "$SCREENSHOT_DIR/INDEX.md"

echo "Rendered $png_count PNGs"
echo "Index: $SCREENSHOT_DIR/INDEX.md"
