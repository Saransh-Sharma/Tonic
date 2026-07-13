#!/bin/bash
set -euo pipefail

TAG="${1:?release tag required}"
: "${SPARKLE_PUBLIC_ED_KEY:?Sparkle public key required}"
: "${TONIC_ARTIFACT_PUBLIC_KEY:?artifact public key required}"
: "${NOTARY_KEY:?notary API key path or base64 payload required}"
: "${NOTARY_KEY_ID:?notary key id required}"
: "${NOTARY_ISSUER:?notary issuer required}"

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PROJECT="$ROOT/Tonic"
ARTIFACTS="$ROOT/Artifacts"
mkdir -p "$ARTIFACTS"
cd "$PROJECT"
xcodegen generate

xcodebuild -project Tonic.xcodeproj -scheme Tonic -configuration Release \
  -archivePath "$ARTIFACTS/Tonic.xcarchive" archive \
  SPARKLE_PUBLIC_ED_KEY="$SPARKLE_PUBLIC_ED_KEY" TONIC_ARTIFACT_PUBLIC_KEY="$TONIC_ARTIFACT_PUBLIC_KEY"
xcodebuild -exportArchive -archivePath "$ARTIFACTS/Tonic.xcarchive" \
  -exportPath "$ARTIFACTS/DirectExport" -exportOptionsPlist "$ROOT/Config/ExportOptions-DeveloperID.plist"

APP="$ARTIFACTS/DirectExport/Tonic.app"
codesign --verify --deep --strict --verbose=2 "$APP"
codesign --verify --strict --verbose=2 "$APP/Contents/Library/HelperTools/com.saransh.tonic.helper"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP" "$ARTIFACTS/Tonic.zip"
hdiutil create -volname "Tonic" -srcfolder "$APP" -ov -format UDZO "$ARTIFACTS/Tonic.dmg"

if [[ "$NOTARY_KEY" == *"BEGIN PRIVATE KEY"* ]]; then
  printf '%s' "$NOTARY_KEY" > "$RUNNER_TEMP/AuthKey.p8"
else
  printf '%s' "$NOTARY_KEY" | base64 --decode > "$RUNNER_TEMP/AuthKey.p8"
fi
xcrun notarytool submit "$ARTIFACTS/Tonic.dmg" --wait \
  --key "$RUNNER_TEMP/AuthKey.p8" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER"
xcrun stapler staple "$ARTIFACTS/Tonic.dmg"
xcrun stapler validate "$ARTIFACTS/Tonic.dmg"

xcodebuild -project Tonic.xcodeproj -scheme TonicStore -configuration Release \
  -archivePath "$ARTIFACTS/TonicStore.xcarchive" archive \
  TONIC_ARTIFACT_PUBLIC_KEY="$TONIC_ARTIFACT_PUBLIC_KEY"
cd "$ARTIFACTS"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent TonicStore.xcarchive TonicStore.xcarchive.zip
