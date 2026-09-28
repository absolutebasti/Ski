#!/bin/zsh
# Runs challenge_rpc_test.sql against the live Supabase project through the
# management API. The SQL is one DO block that always raises at the end, so it
# never leaves rows behind. Exit 0 when the message starts with
# CHALLENGE_TEST_OK. If a local stack is preferred: `supabase start` needs
# Docker — without it we go straight to the live project.
set -u
HERE="${0:A:h}"
PROJECT="${SUPABASE_PROJECT_REF:-svzmmpzevmpodcelzvit}"
TOKEN="${SUPABASE_ACCESS_TOKEN:-$(security find-generic-password -s "Supabase CLI" -w 2>/dev/null)}"
if [[ -z "$TOKEN" ]]; then
  echo "challenge_rpc_test: no Supabase access token (keychain 'Supabase CLI' or SUPABASE_ACCESS_TOKEN)"; exit 1
fi
if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
  echo "Docker not available — running against the live project $PROJECT"
fi
python3 - "$TOKEN" "$PROJECT" "$HERE/challenge_rpc_test.sql" <<'PY'
import json, sys, urllib.request, urllib.error
token, project, path = sys.argv[1:4]
sql = open(path).read()
req = urllib.request.Request(
    f"https://api.supabase.com/v1/projects/{project}/database/query",
    data=json.dumps({"query": sql}).encode(),
    headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
    method="POST")
try:
    with urllib.request.urlopen(req, timeout=60) as r:
        body = r.read().decode()
except urllib.error.HTTPError as e:
    body = e.read().decode()
msg = body
try:
    j = json.loads(body)
    msg = j.get("message", body) if isinstance(j, dict) else body
except ValueError:
    pass
print(msg)
sys.exit(0 if "CHALLENGE_TEST_OK" in msg else 1)
PY
