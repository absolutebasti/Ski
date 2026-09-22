#!/usr/bin/env bash
# Build a signed App Store archive of Schwung and (optionally) upload it to TestFlight.
#
# Usage:
#   tools/testflight.sh                # archive + IPA only (build/ios/ipa/schwung.ipa)
#   tools/testflight.sh --upload       # also upload with an App Store Connect API key
#
# Upload needs three env vars (create the key in App Store Connect → Users and Access → Integrations):
#   ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH (path to AuthKey_XXXX.p8)
# Signing: automatic, Team 5GDU97KSQU (Xcode must be signed in to that team once).
set -euo pipefail
cd "$(dirname "$0")/../app"

BUILD_NUMBER="${BUILD_NUMBER:-$(git rev-list --count HEAD)}"
echo "▶ flutter build ipa (build $BUILD_NUMBER)"
flutter build ipa --release \
  --build-number="$BUILD_NUMBER" \
  --export-method app-store \
  ${MAP_TILE_URL:+--dart-define=MAP_TILE_URL="$MAP_TILE_URL"}

IPA=$(ls build/ios/ipa/*.ipa | head -1)
echo "✓ $IPA"

if [[ "${1:-}" == "--upload" ]]; then
  : "${ASC_KEY_ID:?set ASC_KEY_ID}" "${ASC_ISSUER_ID:?set ASC_ISSUER_ID}" "${ASC_KEY_PATH:?set ASC_KEY_PATH}"
  mkdir -p ~/.appstoreconnect/private_keys
  cp -n "$ASC_KEY_PATH" ~/.appstoreconnect/private_keys/ 2>/dev/null || true
  echo "▶ uploading to TestFlight"
  xcrun altool --upload-app -f "$IPA" -t ios --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
  echo "✓ uploaded — processing takes ~10 min, then it appears under TestFlight → iOS builds"
fi
