#!/usr/bin/env bash
# Archive SlopeTrack, export a signed App Store IPA and (optionally) upload it to TestFlight.
#
#   tools/testflight.sh            # archive + export IPA → app/build/ios/ipa/
#   tools/testflight.sh --upload   # archive + upload straight to App Store Connect
#
# Signing is automatic for Team 5GDU97KSQU. You need ONE of:
#   (a) Xcode signed in with an Apple ID of that team (Xcode → Settings → Accounts), or
#   (b) an App Store Connect API key:  ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH=/path/AuthKey_XXXX.p8
#       (App Store Connect → Users and Access → Integrations → App Store Connect API, role App Manager)
# With (b) the missing provisioning profile and the App ID are created on the fly
# during export; the archive step itself still signs with the Xcode account, so
# (b) alone only works once Xcode has an account of the team (or use (a)).
# After a change to the PERMISSION_* exports below, clear DerivedData once.
#
# Env: BUILD_NUMBER (default: git commit count),
#      SLOPETRACK_ARCHIVE (dry-run: skip the flutter build and verify/export this archive instead).
set -euo pipefail
cd "$(dirname "$0")/../app"

BUILD_NUMBER="${BUILD_NUMBER:-$(git rev-list --count HEAD)}"
ARCHIVE="${SLOPETRACK_ARCHIVE:-build/ios/archive/Runner.xcarchive}"
EXPORT_DIR=build/ios/ipa
OPTS=ios/ExportOptions.plist
MODE="${1:-}"

# permission_handler_apple (SPM) compiles in only the permissions it can see when
# Xcode evaluates its manifest. A store build must never depend on that
# discovery: without these, every location/motion request answers "denied".
export PERMISSION_LOCATION=1 PERMISSION_LOCATION_WHENINUSE=1 PERMISSION_LOCATION_ALWAYS=1 \
  PERMISSION_SENSORS=1 PERMISSION_NOTIFICATIONS=1
export PERMISSION_HANDLER_INFO_PLIST="$PWD/ios/Runner/Info.plist"

if [[ -z "${SLOPETRACK_ARCHIVE:-}" ]]; then
  # A stale archive from an earlier run would otherwise be exported when the build fails half-way.
  rm -rf "$ARCHIVE"
  echo "▶ archive (build $BUILD_NUMBER)"
  # flutter build ipa also exports; the archive is what we need, the export/upload is done below with xcodebuild.
  flutter build ipa --release --build-number="$BUILD_NUMBER" --export-options-plist="$OPTS"
fi
[[ -d "$ARCHIVE" ]] || { echo "✗ no archive at $ARCHIVE"; exit 1; }

# Never export an archive that does not carry the requested build number.
ARCHIVE_BUILD=$(/usr/libexec/PlistBuddy -c "Print :ApplicationProperties:CFBundleVersion" "$ARCHIVE/Info.plist" 2>/dev/null || true)
if [[ "$ARCHIVE_BUILD" != "$BUILD_NUMBER" ]]; then
  echo "✗ archive CFBundleVersion '${ARCHIVE_BUILD:-?}' != BUILD_NUMBER '$BUILD_NUMBER' — stale or wrong archive at $ARCHIVE"
  exit 1
fi
echo "✓ archive verified: CFBundleVersion $ARCHIVE_BUILD"

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
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration ${AUTH[@]+"${AUTH[@]}"}  # empty-array safe under set -u (bash 3.2)
if [[ "$MODE" == "--upload" ]]; then
  echo "✓ uploaded build $BUILD_NUMBER — App Store Connect processes it in ~10 min (TestFlight → iOS builds)"
else
  echo "✓ IPA in $EXPORT_DIR"
fi
