#!/usr/bin/env bash
# Archive Dropline, export a signed App Store IPA and (optionally) upload it to TestFlight.
#
#   tools/testflight.sh            # archive + export IPA → app/build/ios/ipa/
#   tools/testflight.sh --upload   # archive + upload straight to App Store Connect
#
# Signing is automatic for Team 5GDU97KSQU. You need ONE of:
#   (a) Xcode signed in with an Apple ID of that team (Xcode → Settings → Accounts), or
#   (b) an App Store Connect API key:  ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH=/path/AuthKey_XXXX.p8
#       (App Store Connect → Users and Access → Integrations → App Store Connect API, role App Manager)
# With (b) the missing provisioning profile and the App ID are created on the fly.
set -euo pipefail
cd "$(dirname "$0")/../app"

BUILD_NUMBER="${BUILD_NUMBER:-$(git rev-list --count HEAD)}"
ARCHIVE=build/ios/archive/Runner.xcarchive
EXPORT_DIR=build/ios/ipa
OPTS=ios/ExportOptions.plist
MODE="${1:-}"

echo "▶ archive (build $BUILD_NUMBER)"
# flutter build ipa also tries to export; the archive is what we need, the export is retried below with the API key.
flutter build ipa --release --build-number="$BUILD_NUMBER" --export-options-plist="$OPTS" \
  ${MAP_TILE_URL:+--dart-define=MAP_TILE_URL="$MAP_TILE_URL"} || true
[[ -d "$ARCHIVE" ]] || { echo "✗ no archive at $ARCHIVE"; exit 1; }

# Export/upload with xcodebuild so an API key can be used without an Xcode account.
TMP_OPTS=$(mktemp -t exportopts).plist
cp "$OPTS" "$TMP_OPTS"
if [[ "$MODE" == "--upload" ]]; then
  /usr/libexec/PlistBuddy -c "Set :destination upload" "$TMP_OPTS"
fi
AUTH=()
if [[ -n "${ASC_KEY_ID:-}" && -n "${ASC_ISSUER_ID:-}" && -n "${ASC_KEY_PATH:-}" ]]; then
  AUTH=(-authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")
fi
echo "▶ export${MODE:+ + upload} via xcodebuild"
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportOptionsPlist "$TMP_OPTS" -exportPath "$EXPORT_DIR" \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration "${AUTH[@]}"
if [[ "$MODE" == "--upload" ]]; then
  echo "✓ uploaded build $BUILD_NUMBER — App Store Connect processes it in ~10 min (TestFlight → iOS builds)"
else
  echo "✓ IPA in $EXPORT_DIR"
fi
