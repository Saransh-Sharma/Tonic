#!/bin/bash
set -euo pipefail

: "${DEVELOPER_ID_P12:?base64 Developer ID certificate required}"
: "${DEVELOPER_ID_PASSWORD:?certificate password required}"
KEYCHAIN="$RUNNER_TEMP/tonic-signing.keychain-db"
PASSWORD=$(openssl rand -hex 24)
security create-keychain -p "$PASSWORD" "$KEYCHAIN"
security set-keychain-settings -lut 21600 "$KEYCHAIN"
security unlock-keychain -p "$PASSWORD" "$KEYCHAIN"
printf '%s' "$DEVELOPER_ID_P12" | base64 --decode > "$RUNNER_TEMP/tonic-signing.p12"
security import "$RUNNER_TEMP/tonic-signing.p12" -k "$KEYCHAIN" -P "$DEVELOPER_ID_PASSWORD" -T /usr/bin/codesign
security set-key-partition-list -S apple-tool:,apple: -s -k "$PASSWORD" "$KEYCHAIN"
security list-keychains -d user -s "$KEYCHAIN" login.keychain-db
