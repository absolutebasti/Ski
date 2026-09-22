# Dropline backend (Supabase) — design for v1.5

Principle: **local-first, cloud-second.** The phone remains the source of truth for a day; the backend stores day aggregates (and optionally the raw track as a gzip file in Storage) so users can restore, compare and compete. Nothing in v1 depends on the backend.

## Project
- New Supabase project `dropline` (EU, Frankfurt). Not the Torch platform project.
- Auth: **Sign in with Apple** (only provider; satisfies App Review) + anonymous sessions for read-only leaderboards.
- Keys in the app via `--dart-define-from-file=env/prod.json` (`SUPABASE_URL`, `SUPABASE_ANON_KEY`); `env/` is gitignored.

## Schema (`supabase/migrations/0001_dropline.sql`)
| Table | Purpose | RLS |
|---|---|---|
| `profiles` | display name, avatar, home resort, `share_leaderboards` opt-in | owner read/write; public read of display_name/avatar for group members and leaderboards |
| `days` | one row per ski day: the `DayStats` aggregates + resort + season, `device_updated_at`, soft delete | owner only |
| `groups`, `group_members` | private day duels: invite code, max 3 members, one resort/date | members read; creator writes |
| `challenges`, `challenge_progress` | weekly targets (e.g. 10 000 hm), progress per user | owner write, participants read |
| Storage bucket `tracks` | `tracks/<user>/<day>.json.gz` raw points backup | owner only |

Views/RPC (SQL, `security invoker`): `leaderboard(resort_id, season_key, metric, limit)` → rank, display_name, value over days of users with `share_leaderboards = true`; `my_rank(...)`; `group_board(group_id)` → per member km, hm, runs, avg ski speed for the group's day. Plausibility: rows with `max_speed_ms > 45`, `drop_m > 15000` or `run_count > 80` are excluded from leaderboards (`suspicious = true`).

## Sync (app side, `lib/data/sync/**`, v1.5)
- Push: after `endDay()` and after `recomputeDay()` → upsert `days` row (id = local uuid v7), then upload the gzip track in the background (Wi-Fi or on demand).
- Pull: on app start and pull-to-refresh → `days` where `updated_at > last_sync` → merge into drift (last-writer-wins on `device_updated_at`; local active day never overwritten).
- Delete: soft on both sides (`deleted_at`).
- Offline: queue in drift (`sync_outbox`), retry with backoff.

## Social features (order)
1. **Tagesduell**: create group → code → friends join → live board for the day (polling every 60 s during recording; Realtime later).
2. **Gebiets-Top-10 der Saison** per metric, with "you are 14 of 312".
3. **Wochen-Challenge**: one target per week, progress vs. friends.
4. Later: follows, kudos, share links (`dropline.app/d/<id>`).

## Migration 0002 (applied 2026-09-22)
`supabase/migrations/0002_social_fixes.sql`: `is_group_member()` security-definer helper used by the groups/group_members read policies (0001's policy compared a column with itself), `join_group(p_code)` RPC (invitees cannot read a group before joining; enforces `max_members`; raises `code_not_found` / `duel_full`), and `leaderboard()` now also accepts month (`YYYY-MM`) and ISO-week (`YYYY-Www`) keys in `p_season_key`. Still open: `MyRank.total` is the fetched slice, not a server-side count; `deleteAccount` removes rows but not the `auth.users` entry (needs an Edge Function).

