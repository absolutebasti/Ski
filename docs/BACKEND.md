# SlopeTrack backend (Supabase) — design for v1.5

Principle: **local-first, cloud-second.** The phone remains the source of truth for a day; the backend stores day aggregates (and optionally the raw track as a gzip file in Storage) so users can restore, compare and compete. Nothing in v1 depends on the backend.

## Project
- Supabase project `svzmmpzevmpodcelzvit` (EU, Frankfurt). Not the Torch platform project.
- Auth: **Sign in with Apple** (only provider; satisfies App Review). Anonymous sessions get nothing: every board RPC is `authenticated`-only (0005).
- Keys in the app via `--dart-define-from-file=env/prod.json` (`SUPABASE_URL`, `SUPABASE_ANON_KEY`); `env/` is gitignored.
- CLI config: `supabase/config.toml` (project_id `slopetrack`, exposed schemas `public` + `graphql_public` only, `[functions.delete-account] verify_jwt = true`; `[functions.report-notify] verify_jwt = false` — deployed with `--no-verify-jwt`).

## Applied migrations (snapshot 2026-09-29, live project)
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
| `0009_live_duel.sql` | applied 2026-09-28 | `live_days` (own rows + duel partners), `groups.tz`, `group_board` redefined with live rows, `my_duels`; test in `supabase/tests/0009_live_duel.sql` (rewritten 2026-09-30: fixtures relative to `current_date - 1`, no `ALTER TABLE` / `DISABLE TRIGGER` on `live_days` any more — the second upsert asserts the 20 s throttle, the new value goes in via delete + insert; 7/7 live) |
| `0009b_live_days_cleanup.sql` | applied 2026-09-28 | pg_cron `live-days-cleanup` (05:00 UTC daily): deletes `live_days` rows older than two days |
| `0014_moderation_blocks.sql` | applied 2026-09-29 + verified (34/34 tests, all files) | reports guard (10/day, one per target per day, server timestamps) + pg_net trigger → Edge Function `report-notify`, `reports.handled_at`, inbox view `private.open_reports`; blocks invisible **both ways** in `private.board`/`group_board`/`challenge_board`, block deletes the friendship; grant hygiene (`is_opted_in`, anon on all public tables, `friendships` read-only); `group_members` insert only for the creator; RPC `create_duel`; tests 0007/0008/0013/0014 |
| `0015_limits_tz.sql` | applied 2026-09-30 (8/8 tests live) | `days_guard`: track_path-only updates are free (not counted, `updated_at` untouched), upsert no longer counted twice; `live_days` window check `current_date ± 1` + 20 s throttle (P0005 on UPDATE); cleanup cron also purges `day_write_counters`; `join_group` judges `duel_expired` on `groups.tz` (`private.duel_expired`); RPC `blocked_riders()` (names/avatars for the blocked list); CI `.github/workflows/supabase.yml` (Deno + SQL on PRs touching supabase/**); tests 0006/0010/0015 |
| `0016_public_teaser.sql` | applied 2026-09-30 | `public_board_teaser(p_resort_id, p_season_key)` — the **only anon-callable RPC**: top 10 opted-in riders by points (rank, display_name, avatar_url, value; no user_id), reads `private.board`; client throttles to 1 call/s per query; 0005 T8 allow-lists it |
| `0017_duel_invites.sql` | applied 2026-09-30, block fix re-applied 2026-09-30 (6/6 tests live) | table `duel_invites` (own-row RLS), RPCs `invite_to_duel`, `respond_duel_invite` (accept = `join_group` path incl. `duel_full`/`duel_expired`; accept while a block exists either way → P0002 `rider_not_found`), `my_duel_invites`; guards: not_a_member, self-invite, already_member, blocks both ways; trigger `blocks_decline_invites` (after insert on `blocks`) declines the pair's pending invites, unblocking does not revive them (+ one-off UPDATE for pairs blocked earlier) |
| `0018_resort_aliases.sql` | applied 2026-09-30 (idempotent, re-applied once) | `resort_aliases(alias_id → canonical_id)` (186 pairs), `private.canonical_resort`, canonicalising triggers on `days.resort_id` / `profiles.home_resort_id`, backfill (UPDATE only), `private.board` resolves alias ids |
| free numbers | — | 0011 (SOC-SEASONS), 0012 (BE-TZ); 0015–0019 reserved for the wave-2 packages |

Founder's dashboard check (SQL editor, read-only) — expected: every board RPC `definer = true`, `authenticated = true` only for the client RPCs, `anon = false` everywhere:
```sql
select n.nspname || '.' || p.proname as fn, p.prosecdef as definer,
       has_function_privilege('authenticated', p.oid, 'execute') as authenticated,
       has_function_privilege('anon', p.oid, 'execute') as anon
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname in ('public', 'private') and p.prokind = 'f' order by 1;
```
Founder's dashboard check for 0009b + 0014 (read-only) — expected: two cron jobs (`weekly-challenges`, `live-days-cleanup`), `pg_net` installed, five triggers (`reports_guard`, `reports_notify`, `blocks_unfriend`, `blocks_decline_invites` (0017), `friendships_block_check`), exactly one insert policy on `group_members` (`members insert creator`), no `anon` row at all:
```sql
select jobname, schedule from cron.job order by 1;
select extname from pg_extension where extname in ('pg_net', 'supabase_vault');
select tgname, tgrelid::regclass from pg_trigger where not tgisinternal
  and tgrelid::regclass::text in ('reports', 'blocks', 'friendships') order by 2, 1;
select policyname from pg_policies where tablename = 'group_members' and cmd = 'INSERT';
select table_name, privilege_type from information_schema.role_table_grants
  where table_schema = 'public' and grantee = 'anon';
select name from vault.decrypted_secrets where name like 'report_notify%';  -- both rows once §Reports is set up
```

Full smoke test against the live project without writing anything: `tools/supabase-test.sh --live` (token from the keychain item "Supabase CLI"; each test file is one transaction ending in `rollback`; 71 tests in twelve files as of 2026-09-30). Test files take no table-level locks: no `ALTER TABLE` / `DISABLE TRIGGER` on live tables — fixtures are relative to `current_date` (open: 0015 T4 and 0018 still disable a trigger). Locally with Docker: `tools/supabase-test.sh` (= `supabase start` → `db reset` → `supabase/tests/*.sql`). Edge Function unit tests: `deno test --allow-env supabase/functions/report-notify/`.

## Schema
| Table | Purpose | RLS |
|---|---|---|
| `profiles` | display name, avatar, home resort, `share_leaderboards` opt-in, `country_code` (team, chosen in onboarding) | own row read/write (0006); other riders are reached only through definer RPCs |
| `days` | one row per ski day: the `DayStats` aggregates + resort + season, `country_code` = skied in, `points` (generated), `device_updated_at`, soft delete | owner only |
| `groups`, `group_members` | private day duels: invite code, max 3 members, one date | members read (`private.is_group_member`); creator writes |
| `challenges`, `challenge_progress` | weekly targets, progress per user | read all / own write |
| `blocks` | a block hides **both** riders from each other on every board and profile and deletes their friendship (0014, see "Blocks" below) | own rows; select/insert/delete for `authenticated` |
| `friendships` | one row per pair, `status` pending/accepted (0007) | read either side; writes only via the definer RPCs (0014 revoked the client grants) |
| `reports` | `reporter`, `target_user_id`, `reason` ≤ 200, `report_day` (Vienna), `handled_at` (0006/0014) | insert own only, no client read; max 10 per reporter and day, one per target and day |
| Storage bucket `tracks` | `tracks/<user>/<day>.json.gz` raw points backup | owner only |

## RPCs (client-callable, all `security definer set search_path = public`)
| RPC | Returns | Notes |
|---|---|---|
| `leaderboard(p_resort_id, p_season_key, p_metric, p_limit=100, p_country=null)` | `rank, user_id, display_name, avatar_url, country_code, value, total, last_day, day_count` | opted-in riders, plausible days, blocked pairs (either direction, 0014) removed before ranking; `p_limit` clamped to 1…200; unknown metric raises `bad_metric` (22023); `p_season_key` = season `2025/26`, month `2026-01` or ISO week `2026-W03` |
| `my_rank(p_resort_id, p_season_key, p_metric, p_country=null)` | `rank, total, value` — one row or none | the caller's row from the same ranked set as `leaderboard()`; zero rows = not ranked (opted out or no plausible day in the window). Real since 0005 — `MyRank.total` no longer means "fetched slice" |
| `country_board(p_season_key)` | `country_code, riders, points, drop_m` | one row per team |
| `group_board(p_group_id)` | `user_id, display_name, run_count, drop_m, ski_distance_m, max_speed_ms, avg_ski_speed_ms` | raises 42501 `not_a_member` unless the caller is a member; blocked pairs (either direction) hidden; live rows + `is_live` since 0009 |
| `join_group(p_code)` | the group row | `code_not_found`, `duel_full`, `duel_expired` (0006) |
| `create_duel(p_name, p_day=null, p_tz=null, p_resort_id=null)` | `id, code, name, day, resort_id, created_by, max_members, tz` | 0014: group + creator membership in one transaction, code generated server-side (retries on collision); `p_day` null = today in `p_tz`, must be within yesterday…+7 days else 22023 `bad_day`; unknown `p_tz` → `Europe/Vienna`; empty name → 'Tagesduell'. The 1.0 client path (insert `groups`, then insert yourself into `group_members`) still works — only the creator may insert, and only themselves; everybody else goes through `join_group` |

Metrics: `drop_m`, `ski_distance_m`, `run_count`, `max_speed_ms`, `day_count`, `points`. Plausibility: `days.suspicious` rows are excluded everywhere (0001 thresholds, extended by 0006).

**Team = country.** A rider scores for `coalesce(profiles.country_code, days.country_code)` — the country chosen in onboarding, with the skied-in country as fallback for riders who never chose one. `days.country_code` stays "skied in" (used for the countries medal on the device). Lead decision 2026-09-27; GAMIFICATION §5.

## Blocks (decision 2026-09-29, migration 0014)
A block is **invisible both ways**. Before 0014 the blocker no longer saw the blocked rider, but the blocked rider still saw the blocker on the leaderboard, in a duel and in a challenge — and could keep following them. Now every board and profile RPC (`private.board` → `leaderboard`/`my_rank`, `group_board`, `challenge_board`, `friends_board`, `friends_list`, `rider_profile`) removes the pair for each other, a block deletes the `friendships` row of the pair (pending or accepted), and `add_friend_by_id`/`add_friend_by_code` raise `rider_not_found` while a block exists. Since 0017 a block also declines the pair's pending duel invites, and `invite_to_duel`/`respond_duel_invite` (accept) raise `rider_not_found` across a block. Unblocking restores visibility but **not** the friendship. The block itself stays private: only the blocker reads their `blocks` rows; the other side just stops seeing them. `country_board` is unaffected (aggregates, no names).

## Reports (0006 + 0014)
- Client: insert into `reports` without `.select()`; server sets `created_at`, `report_day` (Europe/Vienna), forces `handled_at = null`. Errors: `rate_limited` (P0005) at the 11th report of a day, `already_reported` (23505) for a second report on the same rider that day, check violation for self-reports, 42501 for a forged `reporter`.
- Notification: `private.reports_notify` (after insert) posts the row via **pg_net** to the Edge Function `report-notify`, which e-mails `hello@torchtechnology.de` through Resend. Configuration is Vault + function secrets — without them the trigger is a silent no-op and the report still lands. Founder setup (once, SQL editor + CLI):
  ```sql
  select vault.create_secret('https://svzmmpzevmpodcelzvit.supabase.co/functions/v1/report-notify', 'report_notify_url');
  select vault.create_secret('<long random string>', 'report_notify_secret');
  ```
  ```sh
  supabase secrets set --project-ref svzmmpzevmpodcelzvit REPORT_NOTIFY_SECRET='<the same string>' RESEND_API_KEY='re_…'
  # optional: REPORT_MAIL_TO (default hello@torchtechnology.de), REPORT_MAIL_FROM (default 'SlopeTrack Meldungen <reports@torchtechnology.de>' — the domain must be verified in Resend)
  ```
  The function is deployed with `verify_jwt = false` (`supabase functions deploy report-notify --no-verify-jwt`; pg_net sends no user JWT) and authenticates the call with the `x-report-secret` header instead. It also accepts the Database-Webhook shape `{ record: … }`, so a dashboard webhook on `reports` INSERT with that header is an equivalent setup. Check queued/failed calls: `select * from net._http_response order by id desc limit 20;`.
- Inbox (SQL editor, as postgres): `select * from private.open_reports;` = unhandled reports of the last 7 days with both display names and the count of reports against the target in 7 days. Close one: `update public.reports set handled_at = now() where id = '<id>';`. Act on the rider: `update public.profiles set display_name = 'Skifahrer' where id = '<target>'` (names) or delete the account via the dashboard (cheating, repeat offenders).

## Definer pattern (binding for every migration after 0005)
1. Client-facing RPCs are `security definer set search_path = public`, enforce visibility themselves (opt-in, membership, blocks) and use `auth.uid()` — never a user-id parameter from the client.
2. Supabase's default privileges hand EXECUTE on every new `public` function to `anon`/`authenticated`. **Each migration revokes and grants its own functions**: `revoke all on function … from public, anon, authenticated; grant execute … to authenticated;`. 0005 only touches the functions that exist up to 0005 (fixed list), so re-running it never clobbers later grants. `anon` gets nothing — since 0014 also no table grant in `public` (new tables: add `revoke all on table … from public, anon` yourself). Trigger functions get no client grant either (they run regardless).
3. Policy helpers live in schema **`private`** (`private.is_group_member(group_id)`, `private.shares_group_with(user_id)`), which PostgREST does not expose — they cannot be called via `/rpc` although policies need EXECUTE for `anon`/`authenticated`. **New policies must reference the `private.*` helpers**; the `public.is_group_member` / `public.shares_group_with` wrappers keep their old signatures for definer RPCs only, ignore their user-id parameters and have no client grant. `public.ensure_weekly_challenges` is cron-only.
4. The ranked set behind `leaderboard()` and `my_rank()` is `private.board(...)`; `private.season_match(...)` is the shared window test. 0011 (all-time) extends `season_match`; the current definitions of `private.board`, `group_board` and `challenge_board` are the ones in **0014** (block test both ways) — redefine them only by copying from there.
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
- **0014 (2026-09-29)**: reports are rate-limited and notified (pg_net → `report-notify` → e-mail), blocks are invisible both ways and end a friendship, `group_members` inserts only for the creator, `create_duel` RPC, anon loses every table grant, `is_opted_in` no longer client-callable. Tests for 0007/0008/0013 added; 0005 T7 adjusted to the two-way semantics.
- **0005 (2026-09-27)**: fixed the launch blocker that `leaderboard`/`country_board`/`group_board` were `security invoker` over an owner-only `days` policy — every rider saw only their own days and was alone on rank 1. Also `my_rank`, `blocks`, clamped limits, `bad_metric`, team country. `deleteAccount` now removes the `auth.users` entry via the Edge Function `delete-account` (`verify_jwt = true`).
