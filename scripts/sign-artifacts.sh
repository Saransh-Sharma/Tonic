#!/bin/bash
set -euo pipefail

INPUT="${1:?unsigned envelope required}"
OUTPUT="${2:?signed envelope required}"
: "${TONIC_ARTIFACT_PRIVATE_KEY:?base64-encoded Ed25519 PEM private key required}"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
printf '%s' "$TONIC_ARTIFACT_PRIVATE_KEY" | base64 --decode > "$work/key.pem"
jq -cS '.body' "$INPUT" > "$work/body.json"
openssl pkeyutl -sign -rawin -inkey "$work/key.pem" -in "$work/body.json" -out "$work/signature.bin"
signature=$(base64 < "$work/signature.bin" | tr -d '\n')
jq --arg signature "$signature" '.signature = {algorithm:"ed25519", value:$signature}' "$INPUT" > "$OUTPUT.tmp"
swift Tools/CatalogValidator.swift "$OUTPUT.tmp"
mv "$OUTPUT.tmp" "$OUTPUT"
