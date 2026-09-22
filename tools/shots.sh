#!/usr/bin/env bash
# Simulator screenshots of every screen without rebuilding: writes demo.json into
# the app container, relaunches, captures. Usage: tools/shots.sh [build]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/app"
UDID="${UDID:-$(cat /tmp/schwung_sim_udid)}"
BUNDLE=de.torchtechnology.dropline
OUT="$ROOT/.context/shots"
mkdir -p "$OUT"

if [[ "${1:-}" == "build" ]]; then
  (cd "$APP" && flutter build ios --simulator --debug >/dev/null)
  xcrun simctl install "$UDID" "$APP/build/ios/iphonesimulator/Runner.app"
fi
xcrun simctl privacy "$UDID" grant location-always "$BUNDLE" >/dev/null 2>&1 || true
xcrun simctl privacy "$UDID" grant motion "$BUNDLE" >/dev/null 2>&1 || true

shot() { # name json wait
  local name="$1" json="$2" wait="${3:-4}"
  xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
  local dir; dir="$(xcrun simctl get_app_container "$UDID" "$BUNDLE" data)"
  mkdir -p "$dir/Documents"; printf '%s' "$json" > "$dir/Documents/demo.json"
  xcrun simctl launch "$UDID" "$BUNDLE" >/dev/null
  sleep "$wait"
  xcrun simctl io "$UDID" screenshot "$OUT/$name.png" >/dev/null
  echo "$name"
}

D='"DROPLINE_SKIP_ONBOARDING":"1","DROPLINE_DEMO":"1"'
shot heute      "{$D}" 6
shot tage       "{$D,\"DROPLINE_TAB\":\"tage\"}"
shot rangliste  "{$D,\"DROPLINE_TAB\":\"social\"}"
shot tag-detail "{$D,\"DROPLINE_ROUTE\":\"/day/demo-0\"}" 5
shot tagesbilanz "{$D,\"DROPLINE_ROUTE\":\"/summary/demo-0\"}" 5
shot settings   "{$D,\"DROPLINE_ROUTE\":\"settings\"}"
shot account    "{$D,\"DROPLINE_ROUTE\":\"account\"}"
# fresh install → onboarding page 1
xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
xcrun simctl uninstall "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
xcrun simctl install "$UDID" "$APP/build/ios/iphonesimulator/Runner.app"
xcrun simctl launch "$UDID" "$BUNDLE" >/dev/null; sleep 5
xcrun simctl io "$UDID" screenshot "$OUT/onboarding-1.png" >/dev/null; echo onboarding-1
