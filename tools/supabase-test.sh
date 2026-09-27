#!/usr/bin/env bash
# Backend smoke test for the SlopeTrack Supabase schema.
#
#   tools/supabase-test.sh           # local: supabase start → migrations → supabase/tests/*.sql
#   tools/supabase-test.sh --keep    # same, but leave the local stack running
#   tools/supabase-test.sh --live    # post the same test files to the live project
#                                    # (Management API, token from the macOS keychain
#                                    # item "Supabase CLI"); every test file is one
#                                    # transaction that ends in ROLLBACK, so nothing
#                                    # is written.
#
# Local mode needs Docker. Without Docker the script prints a notice and exits 0
# so CI/agents can call it unconditionally.
set -euo pipefail
cd "$(dirname "$0")/.."

PROJECT_REF="${SUPABASE_PROJECT_REF:-svzmmpzevmpodcelzvit}"
TESTS=(supabase/tests/*.sql)
MODE="${1:-}"

run_live() {
  local token
  token="$(security find-generic-password -s "Supabase CLI" -w 2>/dev/null || true)"
  if [[ -z "$token" ]]; then
    echo "✗ no Supabase token in the keychain (item \"Supabase CLI\")"; exit 1
  fi
  local f
  for f in "${TESTS[@]}"; do
    echo "▶ $f → live project $PROJECT_REF"
    SUPABASE_TOKEN="$token" python3 - "$PROJECT_REF" "$f" <<'PY'
import json, os, sys, urllib.request
ref, path = sys.argv[1], sys.argv[2]
req = urllib.request.Request(
    f"https://api.supabase.com/v1/projects/{ref}/database/query",
    data=json.dumps({"query": open(path).read()}).encode(),
    headers={"Authorization": f"Bearer {os.environ['SUPABASE_TOKEN']}", "Content-Type": "application/json"},
    method="POST")
try:
    rows = json.loads(urllib.request.urlopen(req, timeout=90).read())
except urllib.error.HTTPError as e:
    print("✗ FAILED:", e.read().decode()[:2000]); sys.exit(1)
for r in rows:
    print("  ok ", r.get("test", r))
print(f"✓ {len(rows)} tests passed")
PY
  done
}

run_local() {
  if ! command -v supabase >/dev/null 2>&1; then
    echo "supabase CLI not installed (brew install supabase/tap/supabase) — skipping"; exit 0
  fi
  if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
    echo "Docker not available — skipping local Supabase test (use --live to test the project instead)"; exit 0
  fi

  echo "▶ supabase start"
  supabase start >/dev/null
  echo "▶ supabase db reset (applies supabase/migrations/*)"
  supabase db reset --local >/dev/null

  local project_id db_url psql_cmd
  project_id="$(sed -n 's/^project_id *= *"\(.*\)"/\1/p' supabase/config.toml)"
  db_url="$(supabase status -o env 2>/dev/null | sed -n 's/^DB_URL="\(.*\)"/\1/p')"
  if command -v psql >/dev/null 2>&1; then
    psql_cmd=(psql -v ON_ERROR_STOP=1 -q -X "$db_url")
  else
    # no local psql: use the one inside the database container
    psql_cmd=(docker exec -i "supabase_db_${project_id}" psql -v ON_ERROR_STOP=1 -q -X -U postgres -d postgres)
  fi

  local f rc=0
  for f in "${TESTS[@]}"; do
    echo "▶ $f"
    if "${psql_cmd[@]}" <"$f"; then
      echo "✓ $f"
    else
      echo "✗ $f FAILED"; rc=1
    fi
  done

  if [[ "$MODE" != "--keep" ]]; then
    supabase stop >/dev/null || true
  fi
  exit "$rc"
}

case "$MODE" in
  --live) run_live ;;
  ""|--keep) run_local ;;
  *) echo "usage: tools/supabase-test.sh [--keep|--live]"; exit 2 ;;
esac
