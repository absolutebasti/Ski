# SlopeTrack backend (Supabase) — design for v1.5

Principle: **local-first, cloud-second.** The phone remains the source of truth for a day; the backend stores day aggregates (and optionally the raw track as a gzip file in Storage) so users can restore, compare and compete. Nothing in v1 depends on the backend.

## Project
- Supabase project `svzmmpzevmpodcelzvit` (EU, Frankfurt). Not the Torch platform project.
- Auth: **Sign in with Apple** (only provider; satisfies App Review). Anonymous sessions get nothing: every board RPC is `authenticated`-only (0005).
- Keys in the app via `--dart-define-from-file=env/prod.json` (`SUPABASE_URL`, `SUPABASE_ANON_KEY`); `env/` is gitignored.
- CLI config: `supabase/config.toml` (project_id `slopetrack`, exposed schemas `public` + `graphql_public` only, `[functions.delete-account] verify_jwt = true`).

## Applied migrations (snapshot 2026-09-28, live project)
Applied via the Management API (`POST /v1/projects/<ref>/database/query`), so `supabase migration list` shows nothing — the dashboard check below is the source of truth.

| Migration | State | What |
|---|---|---|
| `0001_schwung.sql` | applied | tables, RLS, `leaderboard`, `group_board`, bucket `tracks` |
| `0002_social_fixes.sql` | applied | `is_group_member`, `join_group`, month/week keys |
| `0003_challenges_privacy_total.sql` | applied | `ensure_weekly_challenges` + pg_cron `weekly-challenges`, `shares_group_with`, leaderboard `total` |
| `0004_country_teams.sql` | applied | `profiles.country_code`, `days.country_code`, `days.points`, `country_board`, `p_country` |
| `0005_rpc_security.sql` | applied + verified (8/8 smoke tests) | definer RPCs, grants, schema `private`, team country, `my_rank`, `blocks` |
| `0006_integrity.sql` | applied | check constraints, cross-field `suspicious`, `days_guard` (3 days/local date, rate limit), `profiles read own`, `reports`, bucket `avatars`, `join_group` expiry |
| `0006b_rate_limit.sql` | applied 2026-09-28 | `days_guard` rate limit 30 → 200 upserts/hour (a full local history must sync) |
| `0007_friends.sql` | applied | `profiles.friend_code`, `friendships`, `add_friend_by_code`, `accept_friend`, `remove_friend`, `friends_list`, `friends_board` |
| `0008_rider_profile.sql` | applied | `rider_profile(p_user_id)` (visibility: opted-in, friends, duel partners, self) |
| `0010_challenges.sql` | applied | `challenge_participants`, `challenge_board`, `my_challenge_history`, `private.challenge_title`, cron creates bilingual weekly challenges |
| `0013_rangliste.sql` | applied | `add_friend_by_id`, `friends_board`/`friends_list` honour `blocks` + team country, `leaderboard` recreated, `new_friend_code` grants revoked |
| `0009_live_duel.sql` | applied 2026-09-28 | `live_days` (own rows + duel partners), `groups.tz`, `group_board` redefined with live rows, `my_duels`; test in `supabase/tests/0009_live_duel.sql` |
| free numbers | — | 0011 (SOC-SEASONS), 0012 (BE-TZ) |

Founder's dashboard check (SQL editor, read-only) — expected: every board RPC `definer = true`, `authenticated = true` only for the client RPCs, `anon = false` everywhere:
```sql
select n.nspname || '.' || p.proname as fn, p.prosecdef as definer,
       has_function_privilege('authenticated', p.oid, 'execute') as authenticated,
       has_function_privilege('anon', p.oid, 'execute') as anon
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname in ('public', 'private') and p.prokind = 'f' order by 1;
```
Full smoke test against the live project without writing anything: `tools/supabase-test.sh --live` (token from the keychain item "Supabase CLI"; each test file is one transaction ending in `rollback`). Locally with Docker: `tools/supabase-test.sh` (= `supabase start` → `db reset` → `supabase/tests/*.sql`).

## Schema
| Table | Purpose | RLS |
|---|---|---|
| `profiles` | display name, avatar, home resort, `share_leaderboards` opt-in, `country_code` (team, chosen in onboarding) | own row read/write (0006); other riders are reached only through definer RPCs |
| `days` | one row per ski day: the `DayStats` aggregates + resort + season, `country_code` = skied in, `points` (generated), `device_updated_at`, soft delete | owner only |
| `groups`, `group_members` | private day duels: invite code, max 3 members, one date | members read (`private.is_group_member`); creator writes |
| `challenges`, `challenge_progress` | weekly targets, progress per user | read all / own write |
| `blocks` | `user_id` hides `blocked_id` from their own leaderboard and duel board (0005) | own rows; select/insert/delete for `authenticated` |
| Storage bucket `tracks` | `tracks/<user>/<day>.json.gz` raw points backup | owner only |

## RPCs (client-callable, all `security definer set search_path = public`)
| RPC | Returns | Notes |
|---|---|---|
| `leaderboard(p_resort_id, p_season_key, p_metric, p_limit=100, p_country=null)` | `rank, user_id, display_name, avatar_url, country_code, value, total, last_day, day_count` | opted-in riders, plausible days, riders blocked by the caller removed before ranking; `p_limit` clamped to 1…200; unknown metric raises `bad_metric` (22023); `p_season_key` = season `2025/26`, month `2026-01` or ISO week `2026-W03` |
| `my_rank(p_resort_id, p_season_key, p_metric, p_country=null)` | `rank, total, value` — one row or none | the caller's row from the same ranked set as `leaderboard()`; zero rows = not ranked (opted out or no plausible day in the window). Real since 0005 — `MyRank.total` no longer means "fetched slice" |
| `country_board(p_season_key)` | `country_code, riders, points, drop_m` | one row per team |
| `group_board(p_group_id)` | `user_id, display_name, run_count, drop_m, ski_distance_m, max_speed_ms, avg_ski_speed_ms` | raises 42501 `not_a_member` unless the caller is a member; blocked members hidden for the caller |
| `join_group(p_code)` | the group row | `code_not_found`, `duel_full`, `duel_expired` (0006) |

Metrics: `drop_m`, `ski_distance_m`, `run_count`, `max_speed_ms`, `day_count`, `points`. Plausibility: `days.suspicious` rows are excluded everywhere (0001 thresholds, extended by 0006).

**Team = country.** A rider scores for `coalesce(profiles.country_code, days.country_code)` — the country chosen in onboarding, with the skied-in country as fallback for riders who never chose one. `days.country_code` stays "skied in" (used for the countries medal on the device). Lead decision 2026-09-27; GAMIFICATION §5.

## Definer pattern (binding for every migration after 0005)
1. Client-facing RPCs are `security definer set search_path = public`, enforce visibility themselves (opt-in, membership, blocks) and use `auth.uid()` — never a user-id parameter from the client.
2. Supabase's default privileges hand EXECUTE on every new `public` function to `anon`/`authenticated`. **Each migration revokes and grants its own functions**: `revoke all on function … from public, anon, authenticated; grant execute … to authenticated;`. 0005 only touches the functions that exist up to 0005 (fixed list), so re-running it never clobbers later grants. `anon` gets nothing.
3. Policy helpers live in schema **`private`** (`private.is_group_member(group_id)`, `private.shares_group_with(user_id)`), which PostgREST does not expose — they cannot be called via `/rpc` although policies need EXECUTE for `anon`/`authenticated`. **New policies must reference the `private.*` helpers**; the `public.is_group_member` / `public.shares_group_with` wrappers keep their old signatures for definer RPCs only, ignore their user-id parameters and have no client grant. `public.ensure_weekly_challenges` is cron-only.
4. The ranked set behind `leaderboard()` and `my_rank()` is `private.board(...)`; `private.season_match(...)` is the shared window test. 0011 (all-time) extends `season_match`, 0009 redefines `group_board` — nobody else redefines these functions.
5. Migrations are idempotent (`create or replace`, `if not exists`, `drop policy if exists`, guarded `do $$` blocks) and never drop tables or delete rows.

## Sync (app side, `lib/data/sync/**`, v1.5)
- Push: after `endDay()` and after `recomputeDay()` → upsert `days` row (id = local uuid v7), then upload the gzip track in the background (Wi-Fi or on demand).
- Pull: on app start and pull-to-refresh → `days` where `updated_at > last_sync` → merge into drift (last-writer-wins on `device_updated_at`; local active day never overwritten).
- Delete: soft on both sides (`deleted_at`).
- Offline: queue in drift (`sync_outbox`), retry with backoff.

## Social features (order)
1. **Tagesduell**: create group → code → friends join → live board for the day (polling every 60 s during recording; Realtime later).
2. **Gebiets-Top-10 der Saison** per metric, with "you are 14 of 312" (`my_rank`).
3. **Wochen-Challenge**: one target per week, progress vs. friends.
4. Friends, rider profiles, blocks/reports: wave 1 (0007/0008, 0005/0006).

## History
- **0002 (2026-09-22)**: `is_group_member()` helper for the groups/group_members read policies (0001's policy compared a column with itself), `join_group(p_code)` (invitees cannot read a group before joining; enforces `max_members`), month/week keys in `p_season_key`.
- **0003/0004 (2026-09-24/27)**: weekly challenges via pg_cron, profile read narrowed, `total` column, country teams and points.
- **0005 (2026-09-27)**: fixed the launch blocker that `leaderboard`/`country_board`/`group_board` were `security invoker` over an owner-only `days` policy — every rider saw only their own days and was alone on rank 1. Also `my_rank`, `blocks`, clamped limits, `bad_metric`, team country. `deleteAccount` now removes the `auth.users` entry via the Edge Function `delete-account` (`verify_jwt = true`).
